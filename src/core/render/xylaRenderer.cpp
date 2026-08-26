#include "xylaRenderer.hpp"
#include "core/log/logger.hpp"
#include "shaderCompiler.hpp"
#include <QThreadPool>
#include <QVector2D>
#include <cstring>

namespace xyla::render {

XylaRenderer::~XylaRenderer() { cleanup(); }

// Initializes Vulkan context and persistent command synchronization handles
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
  poolInfo.queueFamilyIndex = 0;

  if (vkCreateCommandPool(m_device, &poolInfo, nullptr, &m_commandPool) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "Failed to create Vulkan Command Pool.");
    return;
  }

  VkCommandBufferAllocateInfo cmdAlloc{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
  cmdAlloc.commandPool = m_commandPool;
  cmdAlloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cmdAlloc.commandBufferCount = 2;

  VkCommandBuffer cmdBuffers[2] = {VK_NULL_HANDLE, VK_NULL_HANDLE};
  if (vkAllocateCommandBuffers(m_device, &cmdAlloc, cmdBuffers) == VK_SUCCESS) {
    m_renderCmdBuffer = cmdBuffers[0];
    m_uploadCmdBuffer = cmdBuffers[1];
  }

  VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
  vkCreateFence(m_device, &fenceInfo, nullptr, &m_renderFence);
  vkCreateFence(m_device, &fenceInfo, nullptr, &m_uploadFence);

  VkDescriptorPoolSize poolSizes[] = {
      {VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 64},
      {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 64}};
  VkDescriptorPoolCreateInfo descPoolInfo{
      VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
  descPoolInfo.flags = VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
  descPoolInfo.maxSets = 64;
  descPoolInfo.poolSizeCount = 2;
  descPoolInfo.pPoolSizes = poolSizes;

  vkCreateDescriptorPool(m_device, &descPoolInfo, nullptr, &m_descriptorPool);

  VkSamplerCreateInfo samplerInfo{VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO};
  samplerInfo.magFilter = VK_FILTER_LINEAR;
  samplerInfo.minFilter = VK_FILTER_LINEAR;
  samplerInfo.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
  samplerInfo.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
  samplerInfo.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
  vkCreateSampler(m_device, &samplerInfo, nullptr, &m_defaultSampler);

  m_initialized.store(true);
  XYLA_LOG_INFO("XylaRenderer", "GPU compute compositor core ready.");
}

void XylaRenderer::ensureInitialized() {
  if (m_initialized.load())
    return;

  std::lock_guard<std::mutex> lock(m_renderMutex);
  if (m_initialized.load())
    return;

  VkApplicationInfo appInfo{VK_STRUCTURE_TYPE_APPLICATION_INFO};
  appInfo.pApplicationName = "Xyla Engine";
  appInfo.apiVersion = VK_API_VERSION_1_3;

  VkInstanceCreateInfo instInfo{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO};
  instInfo.pApplicationInfo = &appInfo;

  if (vkCreateInstance(&instInfo, nullptr, &m_instance) != VK_SUCCESS)
    return;

  uint32_t deviceCount = 0;
  vkEnumeratePhysicalDevices(m_instance, &deviceCount, nullptr);
  if (deviceCount == 0)
    return;

  std::vector<VkPhysicalDevice> devices(deviceCount);
  vkEnumeratePhysicalDevices(m_instance, &deviceCount, devices.data());
  m_physicalDevice = devices[0];

  float queuePriority = 1.0f;
  VkDeviceQueueCreateInfo queueInfo{VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO};
  queueInfo.queueFamilyIndex = 0;
  queueInfo.queueCount = 1;
  queueInfo.pQueuePriorities = &queuePriority;

  VkDeviceCreateInfo devInfo{VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO};
  devInfo.queueCreateInfoCount = 1;
  devInfo.pQueueCreateInfos = &queueInfo;

  if (vkCreateDevice(m_physicalDevice, &devInfo, nullptr, &m_device) !=
      VK_SUCCESS)
    return;

  vkGetDeviceQueue(m_device, 0, 0, &m_computeQueue);

  VkCommandPoolCreateInfo poolInfo{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO};
  poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
  poolInfo.queueFamilyIndex = 0;
  vkCreateCommandPool(m_device, &poolInfo, nullptr, &m_commandPool);

  VkCommandBufferAllocateInfo cmdAlloc{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
  cmdAlloc.commandPool = m_commandPool;
  cmdAlloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cmdAlloc.commandBufferCount = 2;

  VkCommandBuffer cmdBuffers[2] = {VK_NULL_HANDLE, VK_NULL_HANDLE};
  if (vkAllocateCommandBuffers(m_device, &cmdAlloc, cmdBuffers) == VK_SUCCESS) {
    m_renderCmdBuffer = cmdBuffers[0];
    m_uploadCmdBuffer = cmdBuffers[1];
  }

  VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
  vkCreateFence(m_device, &fenceInfo, nullptr, &m_renderFence);
  vkCreateFence(m_device, &fenceInfo, nullptr, &m_uploadFence);

  VkDescriptorPoolSize poolSizes[] = {
      {VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 64},
      {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 64}};
  VkDescriptorPoolCreateInfo descPoolInfo{
      VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
  descPoolInfo.flags = VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
  descPoolInfo.maxSets = 64;
  descPoolInfo.poolSizeCount = 2;
  descPoolInfo.pPoolSizes = poolSizes;
  vkCreateDescriptorPool(m_device, &descPoolInfo, nullptr, &m_descriptorPool);

  VkSamplerCreateInfo samplerInfo{VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO};
  samplerInfo.magFilter = VK_FILTER_LINEAR;
  samplerInfo.minFilter = VK_FILTER_LINEAR;
  samplerInfo.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
  samplerInfo.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
  samplerInfo.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
  vkCreateSampler(m_device, &samplerInfo, nullptr, &m_defaultSampler);

  m_initialized.store(true);
  XYLA_LOG_INFO("XylaRenderer",
                "Standalone Vulkan compute engine booted on GPU.");
}

// Allocates or resizes persistent 32-slot VRAM input texture ring-buffer
void XylaRenderer::ensureRingResources(uint32_t width, uint32_t height) {
  std::lock_guard<std::mutex> ringLock(m_ringMutex);
  if (m_ringWidth == width && m_ringHeight == height && !m_ringBuffer.empty() &&
      m_ringBuffer[0].image != VK_NULL_HANDLE)
    return;

  for (auto &slot : m_ringBuffer) {
    if (slot.view != VK_NULL_HANDLE) {
      vkDestroyImageView(m_device, slot.view, nullptr);
      vkDestroyImage(m_device, slot.image, nullptr);
      vkFreeMemory(m_device, slot.memory, nullptr);
    }
  }

  m_ringBuffer.assign(kRingBufferSize, RingTextureSlot{});
  m_ringWidth = width;
  m_ringHeight = height;

  VkPhysicalDeviceMemoryProperties memProps;
  vkGetPhysicalDeviceMemoryProperties(m_physicalDevice, &memProps);

  for (size_t i = 0; i < kRingBufferSize; ++i) {
    VkImageCreateInfo imgInfo{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
    imgInfo.imageType = VK_IMAGE_TYPE_2D;
    imgInfo.format = VK_FORMAT_R8G8B8A8_UNORM;
    imgInfo.extent = {width, height, 1};
    imgInfo.mipLevels = 1;
    imgInfo.arrayLayers = 1;
    imgInfo.samples = VK_SAMPLE_COUNT_1_BIT;
    imgInfo.tiling = VK_IMAGE_TILING_OPTIMAL;
    imgInfo.usage =
        VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    imgInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    imgInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

    vkCreateImage(m_device, &imgInfo, nullptr, &m_ringBuffer[i].image);

    VkMemoryRequirements memReqs;
    vkGetImageMemoryRequirements(m_device, m_ringBuffer[i].image, &memReqs);

    uint32_t memTypeIndex = UINT32_MAX;
    for (uint32_t j = 0; j < memProps.memoryTypeCount; ++j) {
      if ((memReqs.memoryTypeBits & (1 << j)) &&
          (memProps.memoryTypes[j].propertyFlags &
           VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) {
        memTypeIndex = j;
        break;
      }
    }

    VkMemoryAllocateInfo allocInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
    allocInfo.allocationSize = memReqs.size;
    allocInfo.memoryTypeIndex = memTypeIndex;
    vkAllocateMemory(m_device, &allocInfo, nullptr, &m_ringBuffer[i].memory);
    vkBindImageMemory(m_device, m_ringBuffer[i].image, m_ringBuffer[i].memory,
                      0);

    VkImageViewCreateInfo viewInfo{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
    viewInfo.image = m_ringBuffer[i].image;
    viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
    viewInfo.format = VK_FORMAT_R8G8B8A8_UNORM;
    viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    viewInfo.subresourceRange.levelCount = 1;
    viewInfo.subresourceRange.layerCount = 1;
    vkCreateImageView(m_device, &viewInfo, nullptr, &m_ringBuffer[i].view);
  }
}

// Resizes VRAM output texture targets
void XylaRenderer::ensureOutputResources(uint32_t width, uint32_t height) {
  if (m_outputWidth == width && m_outputHeight == height &&
      m_outputImage != VK_NULL_HANDLE)
    return;

  if (m_outputImageView != VK_NULL_HANDLE) {
    vkDestroyImageView(m_device, m_outputImageView, nullptr);
    vkDestroyImage(m_device, m_outputImage, nullptr);
    vkFreeMemory(m_device, m_outputMemory, nullptr);
    vkDestroyBuffer(m_device, m_stagingBuffer, nullptr);
    vkFreeMemory(m_device, m_stagingMemory, nullptr);
  }

  m_outputWidth = width;
  m_outputHeight = height;

  VkImageCreateInfo imgInfo{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
  imgInfo.imageType = VK_IMAGE_TYPE_2D;
  imgInfo.format = VK_FORMAT_R8G8B8A8_UNORM;
  imgInfo.extent = {width, height, 1};
  imgInfo.mipLevels = 1;
  imgInfo.arrayLayers = 1;
  imgInfo.samples = VK_SAMPLE_COUNT_1_BIT;
  imgInfo.tiling = VK_IMAGE_TILING_OPTIMAL;
  imgInfo.usage = VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
  imgInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  imgInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

  vkCreateImage(m_device, &imgInfo, nullptr, &m_outputImage);

  VkMemoryRequirements memReqs;
  vkGetImageMemoryRequirements(m_device, m_outputImage, &memReqs);

  VkPhysicalDeviceMemoryProperties memProps;
  vkGetPhysicalDeviceMemoryProperties(m_physicalDevice, &memProps);

  uint32_t memTypeIndex = UINT32_MAX;
  for (uint32_t i = 0; i < memProps.memoryTypeCount; ++i) {
    if ((memReqs.memoryTypeBits & (1 << i)) &&
        (memProps.memoryTypes[i].propertyFlags &
         VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) {
      memTypeIndex = i;
      break;
    }
  }

  VkMemoryAllocateInfo allocInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
  allocInfo.allocationSize = memReqs.size;
  allocInfo.memoryTypeIndex = memTypeIndex;
  vkAllocateMemory(m_device, &allocInfo, nullptr, &m_outputMemory);
  vkBindImageMemory(m_device, m_outputImage, m_outputMemory, 0);

  VkImageViewCreateInfo viewInfo{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
  viewInfo.image = m_outputImage;
  viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
  viewInfo.format = VK_FORMAT_R8G8B8A8_UNORM;
  viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  viewInfo.subresourceRange.levelCount = 1;
  viewInfo.subresourceRange.layerCount = 1;
  vkCreateImageView(m_device, &viewInfo, nullptr, &m_outputImageView);

  VkDeviceSize bufferSize = width * height * 4;
  VkBufferCreateInfo bufInfo{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
  bufInfo.size = bufferSize;
  bufInfo.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
  bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  vkCreateBuffer(m_device, &bufInfo, nullptr, &m_stagingBuffer);

  VkMemoryRequirements bufReqs;
  vkGetBufferMemoryRequirements(m_device, m_stagingBuffer, &bufReqs);

  uint32_t bufMemTypeIndex = UINT32_MAX;
  for (uint32_t i = 0; i < memProps.memoryTypeCount; ++i) {
    if ((bufReqs.memoryTypeBits & (1 << i)) &&
        (memProps.memoryTypes[i].propertyFlags &
         (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
          VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))) {
      bufMemTypeIndex = i;
      break;
    }
  }

  VkMemoryAllocateInfo bufAlloc{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
  bufAlloc.allocationSize = bufReqs.size;
  bufAlloc.memoryTypeIndex = bufMemTypeIndex;
  vkAllocateMemory(m_device, &bufAlloc, nullptr, &m_stagingMemory);
  vkBindBufferMemory(m_device, m_stagingBuffer, m_stagingMemory, 0);
}

// Thread-safe texture upload into VRAM ring-buffer slot without runtime
// allocations
VkImageView XylaRenderer::uploadTexture(const QImage &image,
                                        uint64_t frameIndex) {
  ensureInitialized();
  if (!m_initialized.load() || image.isNull())
    return VK_NULL_HANDLE;

  std::lock_guard<std::mutex> lock(m_renderMutex);
  QImage rgba = image.convertToFormat(QImage::Format_RGBA8888);
  uint32_t width = static_cast<uint32_t>(rgba.width());
  uint32_t height = static_cast<uint32_t>(rgba.height());
  VkDeviceSize imageSize = width * height * 4;

  ensureRingResources(width, height);

  size_t slotIndex = frameIndex % kRingBufferSize;
  RingTextureSlot slot;
  {
    std::lock_guard<std::mutex> ringLock(m_ringMutex);
    slot = m_ringBuffer[slotIndex];
  }

  VkBuffer uploadBuffer = VK_NULL_HANDLE;
  VkDeviceMemory uploadMemory = VK_NULL_HANDLE;

  VkBufferCreateInfo bufInfo{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
  bufInfo.size = imageSize;
  bufInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
  bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  vkCreateBuffer(m_device, &bufInfo, nullptr, &uploadBuffer);

  VkMemoryRequirements memReqs;
  vkGetBufferMemoryRequirements(m_device, uploadBuffer, &memReqs);

  VkPhysicalDeviceMemoryProperties memProps;
  vkGetPhysicalDeviceMemoryProperties(m_physicalDevice, &memProps);

  uint32_t memTypeIndex = UINT32_MAX;
  for (uint32_t i = 0; i < memProps.memoryTypeCount; ++i) {
    if ((memReqs.memoryTypeBits & (1 << i)) &&
        (memProps.memoryTypes[i].propertyFlags &
         (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
          VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))) {
      memTypeIndex = i;
      break;
    }
  }

  VkMemoryAllocateInfo allocInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
  allocInfo.allocationSize = memReqs.size;
  allocInfo.memoryTypeIndex = memTypeIndex;
  vkAllocateMemory(m_device, &allocInfo, nullptr, &uploadMemory);
  vkBindBufferMemory(m_device, uploadBuffer, uploadMemory, 0);

  void *data = nullptr;
  vkMapMemory(m_device, uploadMemory, 0, imageSize, 0, &data);
  std::memcpy(data, rgba.constBits(), imageSize);
  vkUnmapMemory(m_device, uploadMemory);

  if (m_uploadFence != VK_NULL_HANDLE) {
    vkResetFences(m_device, 1, &m_uploadFence);
  }

  vkResetCommandBuffer(m_uploadCmdBuffer, 0);

  VkCommandBufferBeginInfo beginInfo{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
  beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
  vkBeginCommandBuffer(m_uploadCmdBuffer, &beginInfo);

  VkImageMemoryBarrier barrier{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
  barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
  barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.image = slot.image;
  barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  barrier.subresourceRange.levelCount = 1;
  barrier.subresourceRange.layerCount = 1;
  barrier.srcAccessMask = 0;
  barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

  vkCmdPipelineBarrier(m_uploadCmdBuffer, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                       VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  VkBufferImageCopy copyRegion{};
  copyRegion.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  copyRegion.imageSubresource.layerCount = 1;
  copyRegion.imageExtent = {width, height, 1};

  vkCmdCopyBufferToImage(m_uploadCmdBuffer, uploadBuffer, slot.image,
                         VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copyRegion);

  barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.newLayout = VK_IMAGE_LAYOUT_GENERAL;
  barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

  vkCmdPipelineBarrier(m_uploadCmdBuffer, VK_PIPELINE_STAGE_TRANSFER_BIT,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  vkEndCommandBuffer(m_uploadCmdBuffer);

  VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &m_uploadCmdBuffer;

  vkQueueSubmit(m_computeQueue, 1, &submitInfo, m_uploadFence);
  vkWaitForFences(m_device, 1, &m_uploadFence, VK_TRUE, UINT64_MAX);

  vkDestroyBuffer(m_device, uploadBuffer, nullptr);
  vkFreeMemory(m_device, uploadMemory, nullptr);

  return slot.view;
}

// Pre-compiles node graph shader asynchronously
void XylaRenderer::precompileGraph(const std::shared_ptr<NodeGraph> &graph) {
  ensureInitialized();
  if (graph) {
    getOrCreatePipeline(graph);
  }
}

// Dispatches node graph compute shader
bool XylaRenderer::renderFrame(const std::shared_ptr<NodeGraph> &graph,
                               VkImageView inputTextureView, uint32_t width,
                               uint32_t height,
                               const QVariantMap &pushConstantValues) {
  ensureInitialized();
  std::lock_guard<std::mutex> lock(m_renderMutex);
  if (!m_initialized.load() || !graph || inputTextureView == VK_NULL_HANDLE)
    return false;

  auto cachedPipeline = getOrCreatePipeline(graph);
  if (!cachedPipeline || !cachedPipeline->isReady.load())
    return false;

  ensureOutputResources(width, height);

  VkDescriptorSetAllocateInfo setAlloc{
      VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
  setAlloc.descriptorPool = m_descriptorPool;
  setAlloc.descriptorSetCount = 1;
  setAlloc.pSetLayouts = &cachedPipeline->descriptorLayout;

  VkDescriptorSet descriptorSet = VK_NULL_HANDLE;
  if (vkAllocateDescriptorSets(m_device, &setAlloc, &descriptorSet) !=
      VK_SUCCESS)
    return false;

  VkDescriptorImageInfo outputImageInfo{};
  outputImageInfo.imageView = m_outputImageView;
  outputImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

  VkDescriptorImageInfo inputImageInfo{};
  inputImageInfo.sampler = m_defaultSampler;
  inputImageInfo.imageView = inputTextureView;
  inputImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

  VkWriteDescriptorSet writeSets[2]{};

  writeSets[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
  writeSets[0].dstSet = descriptorSet;
  writeSets[0].dstBinding = 0;
  writeSets[0].descriptorCount = 1;
  writeSets[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
  writeSets[0].pImageInfo = &outputImageInfo;

  writeSets[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
  writeSets[1].dstSet = descriptorSet;
  writeSets[1].dstBinding = 1;
  writeSets[1].descriptorCount = 1;
  writeSets[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
  writeSets[1].pImageInfo = &inputImageInfo;

  vkUpdateDescriptorSets(m_device, 2, writeSets, 0, nullptr);

  if (m_renderFence != VK_NULL_HANDLE) {
    vkResetFences(m_device, 1, &m_renderFence);
  }

  vkResetCommandBuffer(m_renderCmdBuffer, 0);

  VkCommandBufferBeginInfo beginInfo{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
  beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
  vkBeginCommandBuffer(m_renderCmdBuffer, &beginInfo);

  VkImageMemoryBarrier barrier{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
  barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
  barrier.newLayout = VK_IMAGE_LAYOUT_GENERAL;
  barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.image = m_outputImage;
  barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  barrier.subresourceRange.levelCount = 1;
  barrier.subresourceRange.layerCount = 1;
  barrier.srcAccessMask = 0;
  barrier.dstAccessMask = VK_ACCESS_SHADER_WRITE_BIT;

  vkCmdPipelineBarrier(m_renderCmdBuffer, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  vkCmdBindPipeline(m_renderCmdBuffer, VK_PIPELINE_BIND_POINT_COMPUTE,
                    cachedPipeline->pipeline);
  vkCmdBindDescriptorSets(m_renderCmdBuffer, VK_PIPELINE_BIND_POINT_COMPUTE,
                          cachedPipeline->pipelineLayout, 0, 1, &descriptorSet,
                          0, nullptr);

  updatePushConstants(m_renderCmdBuffer, cachedPipeline->pipelineLayout,
                      cachedPipeline->pushConstantLayout, pushConstantValues);

  uint32_t groupX = (width + 15) / 16;
  uint32_t groupY = (height + 15) / 16;
  vkCmdDispatch(m_renderCmdBuffer, groupX, groupY, 1);

  barrier.oldLayout = VK_IMAGE_LAYOUT_GENERAL;
  barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
  barrier.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
  vkCmdPipelineBarrier(m_renderCmdBuffer, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                       VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  VkBufferImageCopy copyRegion{};
  copyRegion.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  copyRegion.imageSubresource.layerCount = 1;
  copyRegion.imageExtent = {width, height, 1};
  vkCmdCopyImageToBuffer(m_renderCmdBuffer, m_outputImage,
                         VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, m_stagingBuffer,
                         1, &copyRegion);

  vkEndCommandBuffer(m_renderCmdBuffer);

  VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &m_renderCmdBuffer;

  vkQueueSubmit(m_computeQueue, 1, &submitInfo, m_renderFence);
  vkWaitForFences(m_device, 1, &m_renderFence, VK_TRUE, UINT64_MAX);

  vkFreeDescriptorSets(m_device, m_descriptorPool, 1, &descriptorSet);

  void *mapped = nullptr;
  vkMapMemory(m_device, m_stagingMemory, 0, width * height * 4, 0, &mapped);
  if (mapped) {
    std::lock_guard<std::mutex> imgLock(m_imageMutex);
    m_latestQImage = QImage(static_cast<const uchar *>(mapped), width, height,
                            QImage::Format_RGBA8888)
                         .copy();
    vkUnmapMemory(m_device, m_stagingMemory);
  }

  return true;
}

// Writes dynamic node properties into push constant memory
void XylaRenderer::updatePushConstants(VkCommandBuffer cmdBuffer,
                                       VkPipelineLayout layout,
                                       const PushConstantLayout &layoutInfo,
                                       const QVariantMap &values) {
  if (layoutInfo.totalSizeBytes == 0 || layoutInfo.members.empty())
    return;

  std::vector<uint8_t> buffer(layoutInfo.totalSizeBytes, 0);

  for (const auto &m : layoutInfo.members) {
    uint8_t *dest = buffer.data() + m.offsetBytes;

    if (m.propertyKey == "scale") {
      float defaultScale[2] = {1.0f, 1.0f};
      std::memcpy(dest, defaultScale, sizeof(defaultScale));
    } else if (m.propertyKey == "opacity") {
      float defaultOpacity = 1.0f;
      std::memcpy(dest, &defaultOpacity, sizeof(defaultOpacity));
    }

    QString fullKey = m.nodeId + "_" + m.propertyKey;
    QVariant val;

    if (values.contains(fullKey)) {
      val = values[fullKey];
    } else if (values.contains(m.propertyKey)) {
      val = values[m.propertyKey];
    } else {
      continue;
    }

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
      } else if (val.canConvert<QVector2D>()) {
        QVector2D v = val.value<QVector2D>();
        float vec2[2] = {v.x(), v.y()};
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

// Retrieves pipeline handle from cache
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
    pipeline->isReady.store(ok);
    if (ok) {
      XYLA_LOG_INFO("XylaRenderer",
                    "Fused node graph compute pipeline compiled.");
    }
  });

  return pipeline;
}

// Compiles SPIR-V bytecode into native Vulkan compute pipeline
bool XylaRenderer::compilePipelineInternal(const CompiledGraphShader &compiled,
                                           CachedPipeline &outPipeline) {
  if (m_device == VK_NULL_HANDLE)
    return false;

  auto spirv = ShaderCompiler::compileGlslToSpirv(compiled.glslSource,
                                                  "NodeGraphShader");
  if (spirv.empty())
    return false;

  VkShaderModuleCreateInfo moduleInfo{
      VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
  moduleInfo.codeSize = spirv.size() * sizeof(uint32_t);
  moduleInfo.pCode = spirv.data();

  VkShaderModule shaderModule = VK_NULL_HANDLE;
  if (vkCreateShaderModule(m_device, &moduleInfo, nullptr, &shaderModule) !=
      VK_SUCCESS) {
    return false;
  }

  VkDescriptorSetLayoutBinding bindings[2]{};
  bindings[0].binding = 0;
  bindings[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
  bindings[0].descriptorCount = 1;
  bindings[0].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;

  bindings[1].binding = 1;
  bindings[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
  bindings[1].descriptorCount = 1;
  bindings[1].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;

  VkDescriptorSetLayoutCreateInfo layoutCreateInfo{
      VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
  layoutCreateInfo.bindingCount = 2;
  layoutCreateInfo.pBindings = bindings;

  if (vkCreateDescriptorSetLayout(m_device, &layoutCreateInfo, nullptr,
                                  &outPipeline.descriptorLayout) !=
      VK_SUCCESS) {
    vkDestroyShaderModule(m_device, shaderModule, nullptr);
    return false;
  }

  VkPushConstantRange pushRange{};
  pushRange.stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
  pushRange.offset = 0;
  pushRange.size = compiled.pushConstants.totalSizeBytes;

  VkPipelineLayoutCreateInfo layoutInfo{
      VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
  layoutInfo.setLayoutCount = 1;
  layoutInfo.pSetLayouts = &outPipeline.descriptorLayout;
  if (compiled.pushConstants.totalSizeBytes > 0) {
    layoutInfo.pushConstantRangeCount = 1;
    layoutInfo.pPushConstantRanges = &pushRange;
  }

  if (vkCreatePipelineLayout(m_device, &layoutInfo, nullptr,
                             &outPipeline.pipelineLayout) != VK_SUCCESS) {
    vkDestroyDescriptorSetLayout(m_device, outPipeline.descriptorLayout,
                                 nullptr);
    vkDestroyShaderModule(m_device, shaderModule, nullptr);
    return false;
  }

  VkComputePipelineCreateInfo pipelineInfo{
      VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};
  pipelineInfo.stage.sType =
      VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  pipelineInfo.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT;
  pipelineInfo.stage.module = shaderModule;
  pipelineInfo.stage.pName = "main";
  pipelineInfo.layout = outPipeline.pipelineLayout;

  VkResult res =
      vkCreateComputePipelines(m_device, VK_NULL_HANDLE, 1, &pipelineInfo,
                               nullptr, &outPipeline.pipeline);
  vkDestroyShaderModule(m_device, shaderModule, nullptr);

  if (res != VK_SUCCESS)
    return false;

  outPipeline.isReady.store(true);
  return true;
}

// Clears cached frame image
void XylaRenderer::clearLatestFrame() {
  std::lock_guard<std::mutex> lock(m_imageMutex);
  m_latestQImage = QImage();
}

// Thread-safe query for initialization state
bool XylaRenderer::isInitialized() const noexcept {
  return m_initialized.load();
}

// Returns device handle
VkDevice XylaRenderer::device() const noexcept { return m_device; }

// Returns input image view for requested ring buffer index
VkImageView XylaRenderer::inputImageView(size_t index) const noexcept {
  std::lock_guard<std::mutex> lock(m_ringMutex);
  if (!m_ringBuffer.empty()) {
    size_t slot = index % kRingBufferSize;
    return m_ringBuffer[slot].view;
  }
  return VK_NULL_HANDLE;
}

// Retrieves latest frame image
QImage XylaRenderer::latestFrameImage() const {
  std::lock_guard<std::mutex> lock(m_imageMutex);
  return m_latestQImage;
}

// Destroys Vulkan resources on shutdown
void XylaRenderer::cleanup() {
  std::lock_guard<std::mutex> lock(m_renderMutex);

  for (auto &[hash, cp] : m_pipelineCache) {
    if (cp->pipeline != VK_NULL_HANDLE)
      vkDestroyPipeline(m_device, cp->pipeline, nullptr);
    if (cp->pipelineLayout != VK_NULL_HANDLE)
      vkDestroyPipelineLayout(m_device, cp->pipelineLayout, nullptr);
    if (cp->descriptorLayout != VK_NULL_HANDLE)
      vkDestroyDescriptorSetLayout(m_device, cp->descriptorLayout, nullptr);
  }
  m_pipelineCache.clear();

  if (m_renderFence != VK_NULL_HANDLE) {
    vkDestroyFence(m_device, m_renderFence, nullptr);
    m_renderFence = VK_NULL_HANDLE;
  }

  if (m_uploadFence != VK_NULL_HANDLE) {
    vkDestroyFence(m_device, m_uploadFence, nullptr);
    m_uploadFence = VK_NULL_HANDLE;
  }

  if (m_defaultSampler != VK_NULL_HANDLE) {
    vkDestroySampler(m_device, m_defaultSampler, nullptr);
    m_defaultSampler = VK_NULL_HANDLE;
  }

  {
    std::lock_guard<std::mutex> ringLock(m_ringMutex);
    for (auto &slot : m_ringBuffer) {
      if (slot.view != VK_NULL_HANDLE) {
        vkDestroyImageView(m_device, slot.view, nullptr);
        vkDestroyImage(m_device, slot.image, nullptr);
        vkFreeMemory(m_device, slot.memory, nullptr);
      }
    }
    m_ringBuffer.clear();
  }

  if (m_outputImageView != VK_NULL_HANDLE) {
    vkDestroyImageView(m_device, m_outputImageView, nullptr);
    vkDestroyImage(m_device, m_outputImage, nullptr);
    vkFreeMemory(m_device, m_outputMemory, nullptr);
    vkDestroyBuffer(m_device, m_stagingBuffer, nullptr);
    vkFreeMemory(m_device, m_stagingMemory, nullptr);
  }

  if (m_descriptorPool != VK_NULL_HANDLE) {
    vkDestroyDescriptorPool(m_device, m_descriptorPool, nullptr);
    m_descriptorPool = VK_NULL_HANDLE;
  }

  if (m_commandPool != VK_NULL_HANDLE) {
    vkDestroyCommandPool(m_device, m_commandPool, nullptr);
    m_commandPool = VK_NULL_HANDLE;
  }

  m_initialized.store(false);
}

} // namespace xyla::render
