#include "xylaRenderer.hpp"
#include "core/log/logger.hpp"
#include <QThreadPool>
#include <cstring>

namespace xyla::render {

XylaRenderer::~XylaRenderer() { cleanup(); }

void XylaRenderer::initVulkanContext(VkInstance instance,
                                     VkPhysicalDevice physicalDevice,
                                     VkDevice device, VkQueue computeQueue) {
  std::lock_guard<std::mutex> lock(m_renderMutex);

  m_instance = instance;
  m_physicalDevice = physicalDevice;
  m_device = device;
  m_computeQueue = computeQueue;

  if (m_device == VK_NULL_HANDLE)
    return;

  VkCommandPoolCreateInfo poolInfo{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO};
  poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
  poolInfo.queueFamilyIndex = 0; // Compute Queue Family

  if (vkCreateCommandPool(m_device, &poolInfo, nullptr, &m_commandPool) ==
      VK_SUCCESS) {
    m_initialized = true;
    XYLA_LOG_INFO("XylaRenderer",
                  "Master Vulkan GPU Compositor Context initialized.");
  } else {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "Failed to create Vulkan Command Pool for compute rendering.");
  }
}

bool XylaRenderer::renderFrame(const std::shared_ptr<NodeGraph> &graph,
                               VkImageView outputTextureView, uint32_t width,
                               uint32_t height,
                               const QVariantMap &pushConstantValues) {
  std::lock_guard<std::mutex> lock(m_renderMutex);
  if (!m_initialized || !graph)
    return false;

  auto cachedPipeline = getOrCreatePipeline(graph);
  if (!cachedPipeline || !cachedPipeline->isReady) {
    return false; // Pipeline is compiling asynchronously in background thread
  }

  VkCommandBufferAllocateInfo allocInfo{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
  allocInfo.commandPool = m_commandPool;
  allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  allocInfo.commandBufferCount = 1;

  VkCommandBuffer cmdBuffer = VK_NULL_HANDLE;
  if (vkAllocateCommandBuffers(m_device, &allocInfo, &cmdBuffer) !=
      VK_SUCCESS) {
    return false;
  }

  VkCommandBufferBeginInfo beginInfo{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
  beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
  vkBeginCommandBuffer(cmdBuffer, &beginInfo);

  vkCmdBindPipeline(cmdBuffer, VK_PIPELINE_BIND_POINT_COMPUTE,
                    cachedPipeline->pipeline);

  updatePushConstants(cmdBuffer, cachedPipeline->pipelineLayout,
                      cachedPipeline->pushConstantLayout, pushConstantValues);

  uint32_t groupX = (width + 15) / 16;
  uint32_t groupY = (height + 15) / 16;
  vkCmdDispatch(cmdBuffer, groupX, groupY, 1);

  vkEndCommandBuffer(cmdBuffer);

  VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &cmdBuffer;

  VkFence fence = VK_NULL_HANDLE;
  VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
  vkCreateFence(m_device, &fenceInfo, nullptr, &fence);

  vkQueueSubmit(m_computeQueue, 1, &submitInfo, fence);
  vkWaitForFences(m_device, 1, &fence, VK_TRUE, UINT64_MAX);

  vkDestroyFence(m_device, fence, nullptr);
  vkFreeCommandBuffers(m_device, m_commandPool, 1, &cmdBuffer);

  return true;
}

void XylaRenderer::updatePushConstants(VkCommandBuffer cmdBuffer,
                                       VkPipelineLayout layout,
                                       const PushConstantLayout &layoutInfo,
                                       const QVariantMap &values) {
  if (layoutInfo.totalSizeBytes == 0 || layoutInfo.members.empty())
    return;

  std::vector<uint8_t> buffer(layoutInfo.totalSizeBytes, 0);

  for (const auto &m : layoutInfo.members) {
    QString key = m.nodeId + "_" + m.propertyKey;
    if (!values.contains(key))
      continue;

    QVariant val = values[key];
    uint8_t *dest = buffer.data() + m.offsetBytes;

    switch (m.dataType) {
    case SocketDataType::Float: {
      float f = val.toFloat();
      std::memcpy(dest, &f, sizeof(float));
      break;
    }
    case SocketDataType::Vec2: {
      QVariantList list = val.toList();
      if (list.size() >= 2) {
        float vec2[2] = {list[0].toFloat(), list[1].toFloat()};
        std::memcpy(dest, vec2, sizeof(vec2));
      }
      break;
    }
    case SocketDataType::Color: {
      QVariantList list = val.toList();
      if (list.size() >= 4) {
        float col[4] = {list[0].toFloat(), list[1].toFloat(), list[2].toFloat(),
                        list[3].toFloat()};
        std::memcpy(dest, col, sizeof(col));
      }
      break;
    }
    case SocketDataType::Int: {
      int i = val.toInt();
      std::memcpy(dest, &i, sizeof(int));
      break;
    }
    case SocketDataType::Bool: {
      uint32_t b = val.toBool() ? 1 : 0;
      std::memcpy(dest, &b, sizeof(uint32_t));
      break;
    }
    default:
      break;
    }
  }

  vkCmdPushConstants(cmdBuffer, layout, VK_SHADER_STAGE_COMPUTE_BIT, 0,
                     layoutInfo.totalSizeBytes, buffer.data());
}

std::shared_ptr<CachedPipeline>
XylaRenderer::getOrCreatePipeline(const std::shared_ptr<NodeGraph> &graph) {
  auto compiled = graph->compileFusedShader();
  if (compiled.glslSource.isEmpty())
    return nullptr;

  QString hash = compiled.glslSource;
  auto it = m_pipelineCache.find(hash);
  if (it != m_pipelineCache.end()) {
    return it->second;
  }

  auto pipeline = std::make_shared<CachedPipeline>();
  pipeline->pushConstantLayout = compiled.pushConstants;
  m_pipelineCache[hash] = pipeline;

  QThreadPool::globalInstance()->start([this, compiled, pipeline]() {
    bool ok = compilePipelineInternal(compiled, *pipeline);
    pipeline->isReady = ok;
    if (ok) {
      XYLA_LOG_INFO(
          "XylaRenderer",
          "Compiled new Vulkan Compute Pipeline for fused node graph.");
    }
  });

  return pipeline;
}

bool XylaRenderer::compilePipelineInternal(const CompiledGraphShader &compiled,
                                           CachedPipeline &outPipeline) {
  if (m_device == VK_NULL_HANDLE)
    return false;

  VkPushConstantRange pushRange{};
  pushRange.stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
  pushRange.offset = 0;
  pushRange.size = compiled.pushConstants.totalSizeBytes;

  VkPipelineLayoutCreateInfo layoutInfo{
      VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
  if (compiled.pushConstants.totalSizeBytes > 0) {
    layoutInfo.pushConstantRangeCount = 1;
    layoutInfo.pPushConstantRanges = &pushRange;
  }

  if (vkCreatePipelineLayout(m_device, &layoutInfo, nullptr,
                             &outPipeline.pipelineLayout) != VK_SUCCESS) {
    return false;
  }

  outPipeline.isReady = true;
  return true;
}

void XylaRenderer::cleanup() {
  std::lock_guard<std::mutex> lock(m_renderMutex);

  for (auto &[hash, cp] : m_pipelineCache) {
    if (cp->pipeline != VK_NULL_HANDLE) {
      vkDestroyPipeline(m_device, cp->pipeline, nullptr);
    }
    if (cp->pipelineLayout != VK_NULL_HANDLE) {
      vkDestroyPipelineLayout(m_device, cp->pipelineLayout, nullptr);
    }
  }
  m_pipelineCache.clear();

  if (m_commandPool != VK_NULL_HANDLE) {
    vkDestroyCommandPool(m_device, m_commandPool, nullptr);
    m_commandPool = VK_NULL_HANDLE;
  }

  m_initialized = false;
}

} // namespace xyla::render
