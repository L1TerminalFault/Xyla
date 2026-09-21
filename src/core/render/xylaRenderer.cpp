#include "xylaRenderer.hpp"
#include "core/log/logger.hpp"
#include "shaderCompiler.hpp"

#include <QColor>
#include <QDebug>
#include <QJSValue>
#include <QPointF>
#include <QVector2D>
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <iterator>
#include <mutex>
#include <qhash.h>
#include <type_traits>
#include <vulkan/vulkan_core.h>

namespace xyla::render {

static const char *kDefaultPassthroughGlsl = R"(
#version 450
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(binding = 0, rgba16f) uniform image2D u_outputFrame;
layout(binding = 1) uniform sampler2D u_planeY;
layout(binding = 2) uniform sampler2D u_planeUV;
layout(binding = 3) uniform sampler2D u_sourceRgba;

layout(binding = 4, std430) readonly buffer GraphParameters {
    float dummy;
} u_params;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(u_outputFrame);
    if (pos.x >= size.x || pos.y >= size.y) return;

    vec2 uv = (vec2(pos) + vec2(0.5)) / vec2(size);
    
    vec4 srcColor;
    ivec2 rgbaSize = textureSize(u_sourceRgba, 0);
    if (rgbaSize.x > 1 && rgbaSize.y > 1) {
        srcColor = texture(u_sourceRgba, uv);
    } else {
        float y = texture(u_planeY, uv).r;
        vec2 uvPlane = texture(u_planeUV, uv).rg;

        float c = y - 0.0627451;
        float d = uvPlane.r - 0.5;
        float e = uvPlane.g - 0.5;

        float r = clamp(1.164383 * c + 1.596027 * e, 0.0, 1.0);
        float g = clamp(1.164383 * c - 0.391762 * d - 0.812968 * e, 0.0, 1.0);
        float b = clamp(1.164383 * c + 2.017232 * d, 0.0, 1.0);
        srcColor = vec4(r, g, b, 1.0);
    }

    vec4 dstColor = imageLoad(u_outputFrame, pos);

    float outAlpha = srcColor.a + dstColor.a * (1.0 - srcColor.a);
    vec3 outRgb = (outAlpha > 0.0001) 
        ? (srcColor.rgb * srcColor.a + dstColor.rgb * dstColor.a * (1.0 - srcColor.a)) / outAlpha 
        : vec3(0.0);

    imageStore(u_outputFrame, pos, vec4(outRgb, max(outAlpha, 1.0)));
}
)";

XylaRenderer &XylaRenderer::instance() {
  static XylaRenderer renderer;
  return renderer;
}

XylaRenderer::~XylaRenderer() { cleanup(); }

void XylaRenderer::initVulkanContext(VkInstance instance,
                                     VkPhysicalDevice physicalDevice,
                                     VkDevice device, VkQueue computeQueue,
                                     uint32_t queueFamilyIndex,
                                     uint32_t queueIndex) {
  std::lock_guard<std::recursive_mutex> lock(m_renderMutex);

  XYLA_LOG_DEBUG("XylaRenderer",
                 std::format("initVulkanContext called: dev={:#x}, queue={:#x}",
                             reinterpret_cast<uintptr_t>(device),
                             reinterpret_cast<uintptr_t>(computeQueue)));

  if (device == VK_NULL_HANDLE || physicalDevice == VK_NULL_HANDLE ||
      instance == VK_NULL_HANDLE) {
    XYLA_LOG_WARN("XylaRenderer",
                  "initVulkanContext: Null handle passed (dev/phys/inst).");
    m_initialized.store(false);
    return;
  }

  if (m_device == device && m_initialized.load()) {
    XYLA_LOG_INFO("XylaRenderer",
                  "initVulkanContext: Device already initialized, skipping.");
    return;
  }

  if (m_device != VK_NULL_HANDLE && m_device != device) {
    XYLA_LOG_INFO(
        "XylaRenderer",
        "initVulkanContext: Device changed, cleaning up old context.");
    cleanupInternal();
  }

  m_instance = instance;
  m_physicalDevice = physicalDevice;
  m_device = device;
  m_computeQueue = computeQueue;
  m_queueFamilyIndex = queueFamilyIndex;
  m_queueIndex = queueIndex;

  vkGetPhysicalDeviceMemoryProperties(m_physicalDevice,
                                      &m_deviceMemoryProperties);

  m_initialized.store(false);
  ensureInitialized_NoLock();

  XYLA_LOG_DEBUG("XylaRenderer",
                 std::format("initVulkanContext complete. isInitialized={}",
                             m_initialized.load()));

  if (m_initialized.load()) {
    emit vulkanContextReady();
  }
}

uint32_t XylaRenderer::findMemoryType(uint32_t typeFilter,
                                      VkMemoryPropertyFlags properties) const {
  if (m_deviceMemoryProperties.memoryTypeCount == 0) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "findMemoryType called before memory properties cache was populated.");
    return UINT32_MAX;
  }
  for (uint32_t i = 0; i < m_deviceMemoryProperties.memoryTypeCount; ++i) {
    if ((typeFilter & (1 << i)) &&
        (m_deviceMemoryProperties.memoryTypes[i].propertyFlags & properties) ==
            properties) {
      return i;
    }
  }
  return UINT32_MAX;
}

template <typename F>
bool XylaRenderer::allocateAndBindResource(const VkMemoryRequirements &memReqs,
                                           VkMemoryPropertyFlags properties,
                                           VkDeviceMemory &outMemory,
                                           F &&bindCallback) {
  outMemory = VK_NULL_HANDLE;

  uint32_t memType = findMemoryType(memReqs.memoryTypeBits, properties);
  if (memType == UINT32_MAX) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "allocateAndBindResource: Failed to find suitable memory type index.");
    return false;
  }

  VkMemoryAllocateInfo allocInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
  allocInfo.allocationSize = memReqs.size;
  allocInfo.memoryTypeIndex = memType;

  if (vkAllocateMemory(m_device, &allocInfo, nullptr, &outMemory) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "allocateAndBindResource: Hardware VRAM allocation failed.");
    return false;
  }

  if (bindCallback(outMemory) != VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "allocateAndBindResource: Resource binding "
                                   "failed. Unwinding allocation.");
    vkFreeMemory(m_device, outMemory, nullptr);
    outMemory = VK_NULL_HANDLE;
    return false;
  }

  return true;
}

bool XylaRenderer::createBuffer(VkDeviceSize size, VkBufferUsageFlags usage,
                                VkMemoryPropertyFlags properties,
                                VkBuffer &outBuffer,
                                VkDeviceMemory &outMemory) {
  outBuffer = VK_NULL_HANDLE;
  outMemory = VK_NULL_HANDLE;

  if (size <= 0) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "createBuffer failed: Requested buffer size is 0 or negative.");
    return false;
  }

  VkBufferCreateInfo bufInfo{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
  bufInfo.size = size;
  bufInfo.usage = usage;
  bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

  if (vkCreateBuffer(m_device, &bufInfo, nullptr, &outBuffer) != VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "createBuffer: Failed to create raw Vulkan buffer handle.");
    return false;
  }

  VkMemoryRequirements memReqs;
  vkGetBufferMemoryRequirements(m_device, outBuffer, &memReqs);

  auto bindFunc = [this, outBuffer](VkDeviceMemory memory) {
    return vkBindBufferMemory(m_device, outBuffer, memory, 0);
  };

  if (!allocateAndBindResource(memReqs, properties, outMemory, bindFunc)) {
    vkDestroyBuffer(m_device, outBuffer, nullptr);
    outBuffer = VK_NULL_HANDLE;
    return false;
  }

  return true;
}

bool XylaRenderer::createImage(uint32_t width, uint32_t height, VkFormat format,
                               VkImageTiling tiling, VkImageUsageFlags usage,
                               VkMemoryPropertyFlags properties,
                               VkImage &outImage, VkDeviceMemory &outMemory) {
  outImage = VK_NULL_HANDLE;
  outMemory = VK_NULL_HANDLE;

  if (width == 0 || height == 0) {
    XYLA_LOG_ERROR("XylaRenderer", "createImage failed: Width or height is 0.");
    return false;
  }

  VkImageCreateInfo imgInfo{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
  imgInfo.imageType = VK_IMAGE_TYPE_2D;
  imgInfo.format = format;
  imgInfo.extent.width = width;
  imgInfo.extent.height = height;
  imgInfo.extent.depth = 1;
  imgInfo.mipLevels = 1;
  imgInfo.arrayLayers = 1;
  imgInfo.samples = VK_SAMPLE_COUNT_1_BIT;
  imgInfo.tiling = tiling;
  imgInfo.usage = usage;
  imgInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  imgInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

  if (vkCreateImage(m_device, &imgInfo, nullptr, &outImage) != VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "createImage unable to create image");
    return false;
  }

  VkMemoryRequirements memReqs;
  vkGetImageMemoryRequirements(m_device, outImage, &memReqs);

  auto bindFunc = [this, outImage](VkDeviceMemory memory) {
    return vkBindImageMemory(m_device, outImage, memory, 0);
  };

  if (!allocateAndBindResource(memReqs, properties, outMemory, bindFunc)) {
    vkDestroyImage(m_device, outImage, nullptr);
    outImage = VK_NULL_HANDLE;
    return false;
  }

  return true;
}

size_t XylaRenderer::getFormatBytesPerPixel(VkFormat format) const {
  switch (format) {
  case VK_FORMAT_R8_UNORM:
    return 1;
  case VK_FORMAT_R8G8_UNORM:
    return 2;
  case VK_FORMAT_R8G8B8A8_UNORM:
  case VK_FORMAT_B8G8R8A8_UNORM:
    return 4;
  case VK_FORMAT_R16G16B16A16_SFLOAT:
    return 8;
  case VK_FORMAT_R32G32B32A32_SFLOAT:
    return 16;
  default:
    XYLA_LOG_ERROR("XylaRenderer",
                   "getFormatBytesPerPixel: Unsupported format passed!");
    return 0;
  }
}

bool XylaRenderer::uploadPixelsToImage(VkImage image, uint32_t width,
                                       uint32_t height, VkFormat format,
                                       const uint8_t *srcData, int pitch) {
  if (image == VK_NULL_HANDLE || !srcData || width == 0 || height == 0 ||
      pitch <= 0) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "uploadPixelsToImage: Invalid input parameters or pitch.");
    return false;
  }

  const size_t bytesPerPixel = getFormatBytesPerPixel(format);
  if (bytesPerPixel == 0) {
    return false;
  }

  const size_t sourceRowBytes = static_cast<size_t>(pitch);
  const size_t packedRowBytes = width * bytesPerPixel;
  const size_t totalSize = packedRowBytes * height;

  VkBuffer stagingBuffer = VK_NULL_HANDLE;
  VkDeviceMemory stagingMemory = VK_NULL_HANDLE;

  if (!createBuffer(totalSize, VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                        VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                    stagingBuffer, stagingMemory)) {
    return false;
  }

  void *mapped = nullptr;
  if (vkMapMemory(m_device, stagingMemory, 0, totalSize, 0, &mapped) !=
          VK_SUCCESS ||
      !mapped) {
    XYLA_LOG_ERROR("XylaRenderer", "uploadPixelsToImage: Failed to map staging "
                                   "memory to CPU address space.");
    vkDestroyBuffer(m_device, stagingBuffer, nullptr);
    vkFreeMemory(m_device, stagingMemory, nullptr);
    return false;
  }

  if (sourceRowBytes == packedRowBytes) {
    std::memcpy(mapped, srcData, totalSize);
  } else {
    uint8_t *dstRow = static_cast<uint8_t *>(mapped);
    const uint8_t *srcRow = srcData;
    for (uint32_t r = 0; r < height; ++r) {
      std::memcpy(dstRow, srcRow, packedRowBytes);
      dstRow += packedRowBytes;
      srcRow += sourceRowBytes;
    }
  }
  vkUnmapMemory(m_device, stagingMemory);

  VkCommandBufferAllocateInfo cmdAlloc{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
  cmdAlloc.commandPool = m_commandPool;
  cmdAlloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cmdAlloc.commandBufferCount = 1;

  VkCommandBuffer cmdBuffer = VK_NULL_HANDLE;
  if (vkAllocateCommandBuffers(m_device, &cmdAlloc, &cmdBuffer) != VK_SUCCESS ||
      cmdBuffer == VK_NULL_HANDLE) {
    XYLA_LOG_ERROR("XylaRenderer", "uploadPixelsToImage: Failed to allocate "
                                   "transient transfer command buffer.");
    vkDestroyBuffer(m_device, stagingBuffer, nullptr);
    vkFreeMemory(m_device, stagingMemory, nullptr);
    return false;
  }

  VkFence fence = VK_NULL_HANDLE;
  VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
  if (vkCreateFence(m_device, &fenceInfo, nullptr, &fence) != VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "uploadPixelsToImage: Failed to create synchronization fence.");
    vkFreeCommandBuffers(m_device, m_commandPool, 1, &cmdBuffer);
    vkDestroyBuffer(m_device, stagingBuffer, nullptr);
    vkFreeMemory(m_device, stagingMemory, nullptr);
    return false;
  }

  VkCommandBufferBeginInfo beginInfo{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
  beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
  if (vkBeginCommandBuffer(cmdBuffer, &beginInfo) != VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "uploadPixelsToImage: Failed to begin command buffer recording.");
    vkDestroyFence(m_device, fence, nullptr);
    vkFreeCommandBuffers(m_device, m_commandPool, 1, &cmdBuffer);
    vkDestroyBuffer(m_device, stagingBuffer, nullptr);
    vkFreeMemory(m_device, stagingMemory, nullptr);
    return false;
  }

  VkImageMemoryBarrier barrier{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
  barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
  barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.image = image;
  barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  barrier.subresourceRange.baseMipLevel = 0;
  barrier.subresourceRange.levelCount = 1;
  barrier.subresourceRange.baseArrayLayer = 0;
  barrier.subresourceRange.layerCount = 1;
  barrier.srcAccessMask = 0;
  barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

  vkCmdPipelineBarrier(cmdBuffer, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                       VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  VkBufferImageCopy copyRegion{};
  copyRegion.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  copyRegion.imageSubresource.layerCount = 1;
  copyRegion.imageExtent = {width, height, 1};

  vkCmdCopyBufferToImage(cmdBuffer, stagingBuffer, image,
                         VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copyRegion);

  barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.newLayout = VK_IMAGE_LAYOUT_GENERAL;
  barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

  vkCmdPipelineBarrier(cmdBuffer, VK_PIPELINE_STAGE_TRANSFER_BIT,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  if (vkEndCommandBuffer(cmdBuffer) != VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "uploadPixelsToImage: Failed to end command buffer recording.");
    vkDestroyFence(m_device, fence, nullptr);
    vkFreeCommandBuffers(m_device, m_commandPool, 1, &cmdBuffer);
    vkDestroyBuffer(m_device, stagingBuffer, nullptr);
    vkFreeMemory(m_device, stagingMemory, nullptr);
    return false;
  }

  VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &cmdBuffer;

  if (vkQueueSubmit(m_computeQueue, 1, &submitInfo, fence) != VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "uploadPixelsToImage: Failed to submit "
                                   "transfer workload to hardware queue.");
    vkDestroyFence(m_device, fence, nullptr);
    vkFreeCommandBuffers(m_device, m_commandPool, 1, &cmdBuffer);
    vkDestroyBuffer(m_device, stagingBuffer, nullptr);
    vkFreeMemory(m_device, stagingMemory, nullptr);
    return false;
  }

  if (vkWaitForFences(m_device, 1, &fence, VK_TRUE, UINT64_MAX) != VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "uploadPixelsToImage: GPU device hang or "
                                   "timeout waiting for transfer sync.");
  }

  vkDestroyFence(m_device, fence, nullptr);
  vkFreeCommandBuffers(m_device, m_commandPool, 1, &cmdBuffer);
  vkDestroyBuffer(m_device, stagingBuffer, nullptr);
  vkFreeMemory(m_device, stagingMemory, nullptr);

  return true;
}

bool XylaRenderer::ensureDummyResources() {
  if (m_device == VK_NULL_HANDLE) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "ensureDummyResources failed: Device handle is null.");
    return false;
  }

  if (m_dummyImage != VK_NULL_HANDLE) {
    return true;
  }

  if (!createImage(1, 1, CANVAS_FORMAT, VK_IMAGE_TILING_OPTIMAL,
                   VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                   VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, m_dummyImage,
                   m_dummyMemory)) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "ensureDummyResources: Failed to create dummy fallback image.");
    return false;
  }

  const uint16_t blackPixelRGBA16F[4] = {0, 0, 0,
                                         0x3C00}; // 1.0 Alpha in half-float
  if (!uploadPixelsToImage(m_dummyImage, 1, 1, CANVAS_FORMAT,
                           reinterpret_cast<const uint8_t *>(blackPixelRGBA16F),
                           sizeof(blackPixelRGBA16F))) {
    XYLA_LOG_ERROR("XylaRenderer", "ensureDummyResources: Failed to upload "
                                   "black pixel payload to dummy image.");
    vkFreeMemory(m_device, m_dummyMemory, nullptr);
    vkDestroyImage(m_device, m_dummyImage, nullptr);
    m_dummyMemory = VK_NULL_HANDLE;
    m_dummyImage = VK_NULL_HANDLE;
    return false;
  }

  VkImageViewCreateInfo viewInfo{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
  viewInfo.image = m_dummyImage;
  viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
  viewInfo.format = CANVAS_FORMAT;
  viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  viewInfo.subresourceRange.baseMipLevel = 0;
  viewInfo.subresourceRange.levelCount = 1;
  viewInfo.subresourceRange.baseArrayLayer = 0;
  viewInfo.subresourceRange.layerCount = 1;

  if (vkCreateImageView(m_device, &viewInfo, nullptr, &m_dummyView) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "ensureDummyResources: Failed to create dummy image view.");
    vkFreeMemory(m_device, m_dummyMemory, nullptr);
    vkDestroyImage(m_device, m_dummyImage, nullptr);
    m_dummyMemory = VK_NULL_HANDLE;
    m_dummyImage = VK_NULL_HANDLE;
    return false;
  }

  if (m_dummyParamBuffer == VK_NULL_HANDLE) {
    const VkDeviceSize DUMMY_PARAM_BUFFER_SIZE = 256;

    if (!createBuffer(DUMMY_PARAM_BUFFER_SIZE,
                      VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                      VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                          VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                      m_dummyParamBuffer, m_dummyParamMemory)) {
      XYLA_LOG_ERROR(
          "XylaRenderer",
          "ensureDummyResources: Failed to allocate dummy parameter buffer.");

      vkDestroyImageView(m_device, m_dummyView, nullptr);
      vkFreeMemory(m_device, m_dummyMemory, nullptr);
      vkDestroyImage(m_device, m_dummyImage, nullptr);
      m_dummyView = VK_NULL_HANDLE;
      m_dummyMemory = VK_NULL_HANDLE;
      m_dummyImage = VK_NULL_HANDLE;
      return false;
    }

    void *mapped = nullptr;
    if (vkMapMemory(m_device, m_dummyParamMemory, 0, DUMMY_PARAM_BUFFER_SIZE, 0,
                    &mapped) == VK_SUCCESS) {
      if (mapped) {
        std::memset(mapped, 0, static_cast<size_t>(DUMMY_PARAM_BUFFER_SIZE));
        vkUnmapMemory(m_device, m_dummyParamMemory);
      }
    } else {
      XYLA_LOG_ERROR(
          "XylaRenderer",
          "ensureDummyResources: Failed to map dummy parameter buffer memory.");
      vkDestroyBuffer(m_device, m_dummyParamBuffer, nullptr);
      vkFreeMemory(m_device, m_dummyParamMemory, nullptr);
      vkDestroyImageView(m_device, m_dummyView, nullptr);
      vkFreeMemory(m_device, m_dummyMemory, nullptr);
      vkDestroyImage(m_device, m_dummyImage, nullptr);

      m_dummyParamBuffer = VK_NULL_HANDLE;
      m_dummyParamMemory = VK_NULL_HANDLE;
      m_dummyView = VK_NULL_HANDLE;
      m_dummyMemory = VK_NULL_HANDLE;
      m_dummyImage = VK_NULL_HANDLE;
      return false;
    }
  }

  return true;
}

void XylaRenderer::destroyDummyResources() {
  if (m_device != VK_NULL_HANDLE) {
    if (m_dummyParamBuffer != VK_NULL_HANDLE) {
      vkDestroyBuffer(m_device, m_dummyParamBuffer, nullptr);
    }
    if (m_dummyParamMemory != VK_NULL_HANDLE) {
      vkFreeMemory(m_device, m_dummyParamMemory, nullptr);
    }
    if (m_dummyView != VK_NULL_HANDLE) {
      vkDestroyImageView(m_device, m_dummyView, nullptr);
    }
    if (m_dummyImage != VK_NULL_HANDLE) {
      vkDestroyImage(m_device, m_dummyImage, nullptr);
    }
    if (m_dummyMemory != VK_NULL_HANDLE) {
      vkFreeMemory(m_device, m_dummyMemory, nullptr);
    }
  } else {
    XYLA_LOG_WARN("XylaRenderer",
                  "destroyDummyResources: Device handle is null during "
                  "teardown. Clearing member variables only.");
  }

  m_dummyParamBuffer = VK_NULL_HANDLE;
  m_dummyParamMemory = VK_NULL_HANDLE;
  m_dummyView = VK_NULL_HANDLE;
  m_dummyImage = VK_NULL_HANDLE;
  m_dummyMemory = VK_NULL_HANDLE;
}

void XylaRenderer::ensureInitialized_NoLock() {
  if (m_initialized.load(std::memory_order_acquire)) {
    return;
  }

  if (m_device == VK_NULL_HANDLE) {
    XYLA_LOG_WARN("XylaRenderer", "ensureInitialized: Device handle is null.");
    return;
  }

  if (m_queueFamilyIndex == UINT32_MAX) {
    XYLA_LOG_ERROR("XylaRenderer", "queueFamilyIndex uninitialized when "
                                   "ensureInitialized_NoLock was called");
    return;
  }
  VkCommandPoolCreateInfo poolInfo{
      .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
      .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
      .queueFamilyIndex = m_queueFamilyIndex};

  if (vkCreateCommandPool(m_device, &poolInfo, nullptr, &m_commandPool) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "Failed to create Vulkan command pool.");
    return;
  }

  VkFenceCreateInfo fenceInfo{.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
                              .flags = VK_FENCE_CREATE_SIGNALED_BIT};

  VkDescriptorPoolSize poolSizes[] = {
      {.type = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
       .descriptorCount = FRAME_COMBINED_SAMPLER_BUDGET},
      {.type = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,
       .descriptorCount = FRAME_STORAGE_IMAGE_BUDGET},
      {.type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
       .descriptorCount = FRAME_STORAGE_BUFFER_BUDGET}};

  VkDescriptorPoolCreateInfo descPoolInfo{
      .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
      .flags = 0,
      .maxSets = MAX_DESCRIPTOR_SETS_PER_FRAME,
      .poolSizeCount = static_cast<uint32_t>(std::size(poolSizes)),
      .pPoolSizes = poolSizes};

  auto allocateSlotResources =
      [this](auto &slot, const VkFenceCreateInfo &fenceInfo,
             const VkDescriptorPoolCreateInfo &descPoolInfo) -> bool {
    VkCommandBufferAllocateInfo cmdAlloc{
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = m_commandPool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1};

    if (vkAllocateCommandBuffers(m_device, &cmdAlloc, &slot.cmdBuffer) !=
        VK_SUCCESS) {
      XYLA_LOG_ERROR("XylaRenderer", "Unable to allocate command buffer");
      return false;
    }
    if (vkCreateFence(m_device, &fenceInfo, nullptr, &slot.fence) !=
        VK_SUCCESS) {
      XYLA_LOG_ERROR("XylaRenderer", "Unable to create fence");
      return false;
    }
    if (vkCreateDescriptorPool(m_device, &descPoolInfo, nullptr,
                               &slot.descriptorPool) != VK_SUCCESS) {
      XYLA_LOG_ERROR("XylaRenderer", "Unable to create descriptor pool");
      return false;
    }
    return true;
  };

  for (size_t i = 0; i < kMaxInFlightFrames; ++i) {
    if (!allocateSlotResources(m_frameSlots[i], fenceInfo, descPoolInfo)) {
      cleanupInternal();
      return;
    }
  }

  if (!allocateSlotResources(m_clipSlot, fenceInfo, descPoolInfo)) {
    cleanupInternal();
    return;
  }

  VkSamplerCreateInfo samplerInfo{
      .sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO,
      .magFilter = VK_FILTER_LINEAR,
      .minFilter = VK_FILTER_LINEAR,
      .addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
      .addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE,
      .addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE};

  if (vkCreateSampler(m_device, &samplerInfo, nullptr, &m_defaultSampler) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "unable to create sampler");
    cleanupInternal();
    return;
  };

  if (!ensureDummyResources()) {
    XYLA_LOG_ERROR("XylaRenderer", "Unable to create dummy resources");
    cleanupInternal();
    return;
  };

  m_initialized.store(true, std::memory_order_release);
  XYLA_LOG_INFO("XylaRenderer", "Vulkan resources initialized successfully.");
}

VkImageView XylaRenderer::createImageViewForImage(VkImage image,
                                                  VkFormat format) {
  if (image == VK_NULL_HANDLE || m_device == VK_NULL_HANDLE) {
    return VK_NULL_HANDLE;
  }

  VkImageView view = VK_NULL_HANDLE;
  VkImageViewCreateInfo viewInfo{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
  viewInfo.image = image;
  viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
  viewInfo.format = format;
  viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  viewInfo.subresourceRange.baseMipLevel = 0;
  viewInfo.subresourceRange.levelCount = 1;
  viewInfo.subresourceRange.baseArrayLayer = 0;
  viewInfo.subresourceRange.layerCount = 1;

  if (vkCreateImageView(m_device, &viewInfo, nullptr, &view) == VK_SUCCESS) {
    return view;
  }

  XYLA_LOG_ERROR("XylaRenderer", "createImageViewForImage: Driver failed to "
                                 "allocate VkImageView wrapper.");
  return VK_NULL_HANDLE;
}

bool XylaRenderer::ensureSlotParamBuffer(FrameSlot &slot, size_t requiredSize) {
  if (m_device == VK_NULL_HANDLE) {
    return false;
  }

  size_t targetSize = std::max<size_t>(256, requiredSize);

  if (slot.paramBuffer != VK_NULL_HANDLE &&
      slot.paramBufferSize >= targetSize) {
    return true;
  }

  destroySlotParamBuffer(slot);

  slot.paramBufferSize = targetSize;

  if (!createBuffer(targetSize, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                        VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                    slot.paramBuffer, slot.paramMemory)) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "ensureSlotParamBuffer: Failed to allocate hardware parameter buffer.");
    slot.paramBufferSize = 0;
    slot.mappedParamData = nullptr;
    return false;
  }

  VkResult res = vkMapMemory(m_device, slot.paramMemory, 0, targetSize, 0,
                             reinterpret_cast<void **>(&slot.mappedParamData));
  if (res != VK_SUCCESS || !slot.mappedParamData) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "ensureSlotParamBuffer: Host mapping allocation failed.");
    vkDestroyBuffer(m_device, slot.paramBuffer, nullptr);
    vkFreeMemory(m_device, slot.paramMemory, nullptr);
    slot.paramBuffer = VK_NULL_HANDLE;
    slot.paramMemory = VK_NULL_HANDLE;
    slot.mappedParamData = nullptr;
    slot.paramBufferSize = 0;
    return false;
  }

  return true;
}

void XylaRenderer::destroySlotParamBuffer(FrameSlot &slot) {
  if (m_device == VK_NULL_HANDLE)
    return;

  if (slot.mappedParamData && slot.paramMemory != VK_NULL_HANDLE) {
    vkUnmapMemory(m_device, slot.paramMemory);
    slot.mappedParamData = nullptr;
  }
  if (slot.paramBuffer != VK_NULL_HANDLE) {
    vkDestroyBuffer(m_device, slot.paramBuffer, nullptr);
    slot.paramBuffer = VK_NULL_HANDLE;
  }
  if (slot.paramMemory != VK_NULL_HANDLE) {
    vkFreeMemory(m_device, slot.paramMemory, nullptr);
    slot.paramMemory = VK_NULL_HANDLE;
  }
  slot.paramBufferSize = 0;
}

void XylaRenderer::destroySlotResources(FrameSlot &slot) {
  if (m_device == VK_NULL_HANDLE)
    return;

  destroySlotParamBuffer(slot);

  if (slot.outputImageView != VK_NULL_HANDLE) {
    vkDestroyImageView(m_device, slot.outputImageView, nullptr);
    slot.outputImageView = VK_NULL_HANDLE;
  }
  if (slot.outputImage != VK_NULL_HANDLE) {
    vkDestroyImage(m_device, slot.outputImage, nullptr);
    slot.outputImage = VK_NULL_HANDLE;
  }
  if (slot.outputMemory != VK_NULL_HANDLE) {
    vkFreeMemory(m_device, slot.outputMemory, nullptr);
    slot.outputMemory = VK_NULL_HANDLE;
  }
  slot.width = 0;
  slot.height = 0;
}

bool XylaRenderer::ensureSlotOutputResources(FrameSlot &slot, uint32_t width,
                                             uint32_t height) {
  if (m_device == VK_NULL_HANDLE) {
    return false;
  }

  if (slot.width == width && slot.height == height &&
      slot.outputImage != VK_NULL_HANDLE) {
    return true;
  }

  destroySlotResources(slot);

  slot.width = width;
  slot.height = height;

  VkImageUsageFlags usage =
      VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT |
      VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;

  if (!createImage(width, height, CANVAS_FORMAT, VK_IMAGE_TILING_OPTIMAL, usage,
                   VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, slot.outputImage,
                   slot.outputMemory)) {
    XYLA_LOG_ERROR("XylaRenderer", "ensureSlotOutputResources: Failed to "
                                   "recreate slot output image canvas.");
    slot.width = 0;
    slot.height = 0;
    return false;
  }

  slot.outputImageView =
      createImageViewForImage(slot.outputImage, CANVAS_FORMAT);
  if (slot.outputImageView == VK_NULL_HANDLE) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "ensureSlotOutputResources: Failed to create slot output "
                   "image view canvas wrapper.");
    vkFreeMemory(m_device, slot.outputMemory, nullptr);
    vkDestroyImage(m_device, slot.outputImage, nullptr);
    slot.outputMemory = VK_NULL_HANDLE;
    slot.outputImage = VK_NULL_HANDLE;
    slot.width = 0;
    slot.height = 0;
    return false;
  }

  return true;
}

bool XylaRenderer::allocateRgbaTexture(uint32_t width, uint32_t height,
                                       VkImage *outImage,
                                       VkDeviceMemory *outMem,
                                       VkImageView *outView) {
  if (!outImage || !outMem || !outView || width == 0 || height == 0) {
    XYLA_LOG_ERROR("XylaRenderer", "allocateRgbaTexture failed: Invalid "
                                   "dimension or null output pointers.");
    if (outImage)
      *outImage = VK_NULL_HANDLE;
    if (outMem)
      *outMem = VK_NULL_HANDLE;
    if (outView)
      *outView = VK_NULL_HANDLE;
    return false;
  }

  *outImage = VK_NULL_HANDLE;
  *outMem = VK_NULL_HANDLE;
  *outView = VK_NULL_HANDLE;

  if (!m_initialized.load(std::memory_order_acquire)) {
    std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
    if (!m_initialized.load(std::memory_order_acquire)) {
      ensureInitialized_NoLock();
      if (!m_initialized.load(std::memory_order_acquire)) {
        XYLA_LOG_ERROR(
            "XylaRenderer",
            "allocateRgbaTexture aborted: Renderer initialization failed.");
        return false;
      }
    }
  }

  VkImageUsageFlags usage =
      VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_SAMPLED_BIT |
      VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT |
      VK_IMAGE_USAGE_TRANSFER_SRC_BIT;

  // Source RGBA textures ingested from CPU buffers use VK_FORMAT_R8G8B8A8_UNORM
  if (!createImage(width, height, CANVAS_FORMAT, VK_IMAGE_TILING_OPTIMAL, usage,
                   VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, *outImage, *outMem)) {
    XYLA_LOG_ERROR("XylaRenderer", "allocateRgbaTexture: Failed to allocate "
                                   "hardware image primitive components.");
    *outImage = VK_NULL_HANDLE;
    *outMem = VK_NULL_HANDLE;
    return false;
  }

  *outView = createImageViewForImage(*outImage, CANVAS_FORMAT);
  if (*outView == VK_NULL_HANDLE) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "allocateRgbaTexture: Failed to allocate view wrapper. "
                   "Unwinding allocations to prevent memory leaks.");

    vkFreeMemory(m_device, *outMem, nullptr);
    vkDestroyImage(m_device, *outImage, nullptr);

    *outImage = VK_NULL_HANDLE;
    *outMem = VK_NULL_HANDLE;
    *outView = VK_NULL_HANDLE;
    return false;
  }

  return true;
}

bool XylaRenderer::uploadToExistingRgbaTexture(const uint8_t *rgbaData,
                                               int pitch, uint32_t width,
                                               uint32_t height,
                                               VkImage rgbaImage) {
  if (rgbaImage == VK_NULL_HANDLE || !rgbaData || width == 0 || height == 0 ||
      pitch <= 0) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "uploadToExistingRgbaTexture failed: Invalid parameter "
                   "bounds or null pointers.");
    return false;
  }

  if (!m_initialized.load(std::memory_order_acquire)) {
    std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
    if (!m_initialized.load(std::memory_order_acquire)) {
      ensureInitialized_NoLock();
      if (!m_initialized.load(std::memory_order_acquire)) {
        XYLA_LOG_ERROR("XylaRenderer", "uploadToExistingRgbaTexture aborted: "
                                       "Renderer initialization failed.");
        return false;
      }
    }
  }

  return uploadPixelsToImage(rgbaImage, width, height, VK_FORMAT_R8G8B8A8_UNORM,
                             rgbaData, pitch);
}

bool XylaRenderer::uploadToExistingYuvTextures(const uint8_t *yData, int yPitch,
                                               const uint8_t *uvData,
                                               int uvPitch, uint32_t width,
                                               uint32_t height, VkImage yImage,
                                               VkImage uvImage) {
  if (yImage == VK_NULL_HANDLE || uvImage == VK_NULL_HANDLE || !yData ||
      !uvData || width == 0 || height == 0 || yPitch <= 0 || uvPitch <= 0) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "uploadToExistingYuvTextures failed: Invalid parameter "
                   "bounds or null pointers.");
    return false;
  }

  if (!m_initialized.load(std::memory_order_acquire)) {
    std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
    if (!m_initialized.load(std::memory_order_acquire)) {
      ensureInitialized_NoLock();
      if (!m_initialized.load(std::memory_order_acquire)) {
        XYLA_LOG_ERROR("XylaRenderer", "uploadToExistingYuvTextures aborted: "
                                       "Renderer initialization failed.");
        return false;
      }
    }
  }

  bool okY = uploadPixelsToImage(yImage, width, height, VK_FORMAT_R8_UNORM,
                                 yData, yPitch);

  bool okUV = uploadPixelsToImage(uvImage, width / 2, height / 2,
                                  VK_FORMAT_R8G8_UNORM, uvData, uvPitch);

  return okY && okUV;
}

bool XylaRenderer::allocateAndUploadYuvTextures(
    const uint8_t *yData, int yPitch, const uint8_t *uvData, int uvPitch,
    uint32_t width, uint32_t height, VkImage *outYImage,
    VkDeviceMemory *outYMem, VkImageView *outYView, VkImage *outUVImage,
    VkDeviceMemory *outUVMem, VkImageView *outUVView) {

  if (!outYImage || !outYMem || !outYView || !outUVImage || !outUVMem ||
      !outUVView || !yData || !uvData || width == 0 || height == 0 ||
      yPitch <= 0 || uvPitch <= 0) {
    XYLA_LOG_ERROR("XylaRenderer", "allocateAndUploadYuvTextures failed: "
                                   "Invalid bounds or null pointers.");
    return false;
  }

  *outYImage = VK_NULL_HANDLE;
  *outYMem = VK_NULL_HANDLE;
  *outYView = VK_NULL_HANDLE;
  *outUVImage = VK_NULL_HANDLE;
  *outUVMem = VK_NULL_HANDLE;
  *outUVView = VK_NULL_HANDLE;

  if (!m_initialized.load(std::memory_order_acquire)) {
    std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
    if (!m_initialized.load(std::memory_order_acquire)) {
      ensureInitialized_NoLock();
      if (!m_initialized.load(std::memory_order_acquire)) {
        XYLA_LOG_ERROR(
            "XylaRenderer",
            "allocateAndUploadYuvTextures aborted: Initialization failed.");
        return false;
      }
    }
  }

  VkImageUsageFlags usage =
      VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;

  if (!createImage(width, height, VK_FORMAT_R8_UNORM, VK_IMAGE_TILING_OPTIMAL,
                   usage, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, *outYImage,
                   *outYMem)) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "allocateAndUploadYuvTextures: Failed to create Y image primitive.");
    return false;
  }

  *outYView = createImageViewForImage(*outYImage, VK_FORMAT_R8_UNORM);
  if (*outYView == VK_NULL_HANDLE) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "allocateAndUploadYuvTextures: Failed to create Y image view wrapper.");
    vkFreeMemory(m_device, *outYMem, nullptr);
    vkDestroyImage(m_device, *outYImage, nullptr);
    *outYImage = VK_NULL_HANDLE;
    *outYMem = VK_NULL_HANDLE;
    return false;
  }

  if (!createImage(
          width / 2, height / 2, VK_FORMAT_R8G8_UNORM, VK_IMAGE_TILING_OPTIMAL,
          usage, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT, *outUVImage, *outUVMem)) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "allocateAndUploadYuvTextures: Failed to create UV image primitive.");

    vkDestroyImageView(m_device, *outYView, nullptr);
    vkFreeMemory(m_device, *outYMem, nullptr);
    vkDestroyImage(m_device, *outYImage, nullptr);
    *outYImage = VK_NULL_HANDLE;
    *outYMem = VK_NULL_HANDLE;
    *outYView = VK_NULL_HANDLE;
    return false;
  }

  *outUVView = createImageViewForImage(*outUVImage, VK_FORMAT_R8G8_UNORM);
  if (*outUVView == VK_NULL_HANDLE) {
    XYLA_LOG_ERROR("XylaRenderer", "allocateAndUploadYuvTextures: Failed to "
                                   "create UV image view wrapper.");

    vkFreeMemory(m_device, *outUVMem, nullptr);
    vkDestroyImage(m_device, *outUVImage, nullptr);
    vkDestroyImageView(m_device, *outYView, nullptr);
    vkFreeMemory(m_device, *outYMem, nullptr);
    vkDestroyImage(m_device, *outYImage, nullptr);
    *outYImage = VK_NULL_HANDLE;
    *outYMem = VK_NULL_HANDLE;
    *outYView = VK_NULL_HANDLE;
    *outUVImage = VK_NULL_HANDLE;
    *outUVMem = VK_NULL_HANDLE;
    return false;
  }

  bool okY = uploadPixelsToImage(*outYImage, width, height, VK_FORMAT_R8_UNORM,
                                 yData, yPitch);
  bool okUV = uploadPixelsToImage(*outUVImage, width / 2, height / 2,
                                  VK_FORMAT_R8G8_UNORM, uvData, uvPitch);

  if (!okY || !okUV) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "allocateAndUploadYuvTextures: Pixel payload upload failed.");

    vkDestroyImageView(m_device, *outUVView, nullptr);
    vkFreeMemory(m_device, *outUVMem, nullptr);
    vkDestroyImage(m_device, *outUVImage, nullptr);
    vkDestroyImageView(m_device, *outYView, nullptr);
    vkFreeMemory(m_device, *outYMem, nullptr);
    vkDestroyImage(m_device, *outYImage, nullptr);

    *outYImage = VK_NULL_HANDLE;
    *outYMem = VK_NULL_HANDLE;
    *outYView = VK_NULL_HANDLE;
    *outUVImage = VK_NULL_HANDLE;
    *outUVMem = VK_NULL_HANDLE;
    *outUVView = VK_NULL_HANDLE;
    return false;
  }

  return true;
}

void XylaRenderer::precompileGraph(const std::shared_ptr<NodeGraph> &graph) {
  if (!m_initialized.load(std::memory_order_acquire)) {
    std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
    if (!m_initialized.load(std::memory_order_acquire)) {
      ensureInitialized_NoLock();
      if (!m_initialized.load(std::memory_order_acquire)) {
        XYLA_LOG_ERROR(
            "XylaRenderer",
            "precompileGraph aborted: Renderer initialization failed.");
        return;
      }
    }
  }

  if (graph) {
    auto pipeline = getOrCreatePipeline(graph);
    if (pipeline) {
      XYLA_LOG_INFO("XylaRenderer", "precompileGraph: Successfully warmed "
                                    "pipeline cache for node graph.");
    } else {
      XYLA_LOG_WARN("XylaRenderer", "precompileGraph: Failed to precompile "
                                    "pipeline layout for node graph.");
    }
  }
}

std::shared_ptr<CachedPipeline>
XylaRenderer::getOrCreatePipeline(const std::shared_ptr<NodeGraph> &graph) {
  if (!graph) {
    return nullptr;
  }

  CompiledGraphShader compiled = graph->compileFusedShader();
  if (compiled.glslSource.isEmpty()) {
    XYLA_LOG_ERROR("XylaRenderer",
                   "getOrCreatePipeline: Fused shader compilation returned an "
                   "empty GLSL source string.");
    return nullptr;
  }

  const uint64_t hashKey = static_cast<uint64_t>(qHash(compiled.glslSource));

  auto it = m_pipelineCache.find(hashKey);
  if (it != m_pipelineCache.end()) {
    return it->second;
  }
  auto pipeline = std::make_shared<CachedPipeline>();
  pipeline->pushConstantLayout = compiled.pushConstants;

  bool ok = compilePipelineInternal(compiled, *pipeline);
  if (!ok) {
    return nullptr;
  }

  pipeline->isReady.store(true, std::memory_order_release);
  m_pipelineCache[hashKey] = pipeline;
  return pipeline;
}

bool XylaRenderer::compilePipelineInternal(const CompiledGraphShader &compiled,
                                           CachedPipeline &outPipeline) {
  if (m_device == VK_NULL_HANDLE) {
    return false;
  }

  outPipeline.pipeline = VK_NULL_HANDLE;
  outPipeline.pipelineLayout = VK_NULL_HANDLE;
  outPipeline.descriptorLayout = VK_NULL_HANDLE;

  auto spirv = ShaderCompiler::compileGlslToSpirv(compiled.glslSource,
                                                  "NodeGraphShader");
  if (spirv.empty()) {
    XYLA_LOG_ERROR("XylaRenderer", "compilePipelineInternal: GLSL to SPIR-V "
                                   "compilation returned empty bytecode.");
    return false;
  }

  VkShaderModuleCreateInfo moduleInfo{
      VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
  moduleInfo.codeSize = spirv.size() * sizeof(uint32_t);
  moduleInfo.pCode = spirv.data();

  VkShaderModule shaderModule = VK_NULL_HANDLE;
  if (vkCreateShaderModule(m_device, &moduleInfo, nullptr, &shaderModule) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "compilePipelineInternal: Failed to create VkShaderModule handle.");
    return false;
  }

  VkDescriptorSetLayoutBinding bindings[5]{};
  for (int i = 0; i < 5; ++i) {
    bindings[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
    bindings[i].pImmutableSamplers = nullptr;
  }

  bindings[0].binding = 0;
  bindings[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
  bindings[0].descriptorCount = 1;

  bindings[1].binding = 1;
  bindings[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
  bindings[1].descriptorCount = 1;

  bindings[2].binding = 2;
  bindings[2].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
  bindings[2].descriptorCount = 1;

  bindings[3].binding = 3;
  bindings[3].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
  bindings[3].descriptorCount = 1;

  bindings[4].binding = 4;
  bindings[4].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
  bindings[4].descriptorCount = 1;

  VkDescriptorSetLayoutCreateInfo layoutCreateInfo{
      VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
  layoutCreateInfo.bindingCount = 5;
  layoutCreateInfo.pBindings = bindings;

  if (vkCreateDescriptorSetLayout(m_device, &layoutCreateInfo, nullptr,
                                  &outPipeline.descriptorLayout) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "compilePipelineInternal: Failed to create descriptor set layout.");
    vkDestroyShaderModule(m_device, shaderModule, nullptr);
    outPipeline.descriptorLayout = VK_NULL_HANDLE;
    return false;
  }

  VkPushConstantRange pushConstantRange{};
  pushConstantRange.stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
  pushConstantRange.offset = 0;
  pushConstantRange.size =
      static_cast<uint32_t>(compiled.pushConstants.totalSizeBytes);

  VkPipelineLayoutCreateInfo layoutInfo{
      VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
  layoutInfo.setLayoutCount = 1;
  layoutInfo.pSetLayouts = &outPipeline.descriptorLayout;
  layoutInfo.pushConstantRangeCount =
      (compiled.pushConstants.totalSizeBytes > 0) ? 1 : 0;
  layoutInfo.pPushConstantRanges = (compiled.pushConstants.totalSizeBytes > 0)
                                       ? &pushConstantRange
                                       : nullptr;

  if (vkCreatePipelineLayout(m_device, &layoutInfo, nullptr,
                             &outPipeline.pipelineLayout) != VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "compilePipelineInternal: Failed to create pipeline layout handle.");
    vkDestroyDescriptorSetLayout(m_device, outPipeline.descriptorLayout,
                                 nullptr);
    vkDestroyShaderModule(m_device, shaderModule, nullptr);
    outPipeline.descriptorLayout = VK_NULL_HANDLE;
    outPipeline.pipelineLayout = VK_NULL_HANDLE;
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

  if (res != VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "compilePipelineInternal: Failed to create "
                                   "compute hardware pipeline object.");
    vkDestroyPipelineLayout(m_device, outPipeline.pipelineLayout, nullptr);
    vkDestroyDescriptorSetLayout(m_device, outPipeline.descriptorLayout,
                                 nullptr);
    outPipeline.pipelineLayout = VK_NULL_HANDLE;
    outPipeline.descriptorLayout = VK_NULL_HANDLE;
    outPipeline.pipeline = VK_NULL_HANDLE;
    return false;
  }

  return true;
}

void XylaRenderer::uploadParametersToBuffer(
    uint8_t *destBuffer, const PushConstantLayout &layoutInfo,
    const RenderLayer &layer) {
  if (!destBuffer || layoutInfo.members.empty()) {
    return;
  }

  const auto *animMgr = layer.animMgr;
  const FrameIndex frame = layer.frame;

  for (const auto &m : layoutInfo.members) {
    uint8_t *dest = destBuffer + m.offsetBytes;
    bool parameterHandled = false;

    // 1. Check if this is an Intrinsic Clip Transform channel
    anim::PropertyHandle handle;
    if (m.nodeId == "clip") {
      if (m.propertyKey == "posX") {
        handle = layer.transformHandles
                     .channels[static_cast<size_t>(TransformPropertyId::PosX)];
      } else if (m.propertyKey == "posY") {
        handle = layer.transformHandles
                     .channels[static_cast<size_t>(TransformPropertyId::PosY)];
      } else if (m.propertyKey == "scaleX") {
        handle =
            layer.transformHandles
                .channels[static_cast<size_t>(TransformPropertyId::ScaleX)];
      } else if (m.propertyKey == "scaleY") {
        handle =
            layer.transformHandles
                .channels[static_cast<size_t>(TransformPropertyId::ScaleY)];
      } else if (m.propertyKey == "rotation") {
        handle =
            layer.transformHandles
                .channels[static_cast<size_t>(TransformPropertyId::Rotation)];
      } else if (m.propertyKey == "opacity") {
        handle =
            layer.transformHandles
                .channels[static_cast<size_t>(TransformPropertyId::Opacity)];
      }
    } else if (layer.graph) {
      // 2. Otherwise resolve from the specific Node inside the NodeGraph
      auto node = layer.graph->findNode(m.nodeId);
      if (node) {
        handle = node->propertyHandle(m.propertyKey);
      }
    }

    // 3. Evaluate value from AnimationPropertyTable via handle
    if (animMgr && handle.isValid()) {
      if (m.dataType == SocketDataType::Float) {
        *reinterpret_cast<float *>(dest) =
            animMgr->evaluateFloat(handle, frame);
        parameterHandled = true;
      } else if (m.dataType == SocketDataType::Int) {
        *reinterpret_cast<int32_t *>(dest) =
            animMgr->evaluateValue(handle, frame).toInt();
        parameterHandled = true;
      } else if (m.dataType == SocketDataType::Bool) {
        *reinterpret_cast<uint32_t *>(dest) =
            animMgr->evaluateValue(handle, frame).toBool() ? 1 : 0;
        parameterHandled = true;
      }
    }

    // 4. Default Fallback (writes 0.0 for pos, 1.0 for scale/opacity)
    if (!parameterHandled) {
      std::visit(
          [dest](auto &&arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, float>)
              *reinterpret_cast<float *>(dest) = arg;
            else if constexpr (std::is_same_v<T, double>)
              *reinterpret_cast<float *>(dest) = static_cast<float>(arg);
            else if constexpr (std::is_same_v<T, int32_t> ||
                               std::is_same_v<T, int>)
              *reinterpret_cast<int32_t *>(dest) = static_cast<int32_t>(arg);
            else if constexpr (std::is_same_v<T, bool>)
              *reinterpret_cast<uint32_t *>(dest) = arg ? 1 : 0;
          },
          m.defaultValue);
    }
  }
}

bool XylaRenderer::renderFrame(const std::vector<RenderLayer> &layers,
                               const RenderContext &ctx) {
  const uint32_t effWidth = ctx.effectiveWidth();
  const uint32_t effHeight = ctx.effectiveHeight();
  static constexpr uint32_t MAX_XYLA_CANVAS_DIMENSION = 16384;
  if (effWidth > MAX_XYLA_CANVAS_DIMENSION ||
      effHeight > MAX_XYLA_CANVAS_DIMENSION) {
    XYLA_LOG_ERROR("XylaRenderer", "renderFrame aborted: Target dimensions "
                                   "exceed maximum supported limits.");
    return false;
  }
  if (!m_initialized.load(std::memory_order_acquire)) {
    std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
    if (!m_initialized.load(std::memory_order_acquire)) {
      ensureInitialized_NoLock();
      if (!m_initialized.load(std::memory_order_acquire)) {
        XYLA_LOG_ERROR("XylaRenderer",
                       "renderFrame aborted: Renderer initialization failed.");
        return false;
      }
    }
  }

  const uint32_t targetSlotIndex =
      (m_currentFrameSlot + 1) % kMaxInFlightFrames;
  auto &slot = m_frameSlots[targetSlotIndex];

  if (vkWaitForFences(m_device, 1, &slot.fence, VK_TRUE, UINT64_MAX) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "renderFrame: Failed or timed out waiting for slot execution fence.");
    return false;
  }

  if (vkResetFences(m_device, 1, &slot.fence) != VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "renderFrame: Failed to reset active slot execution fence primitive.");
    return false;
  }
  if (slot.descriptorPool != VK_NULL_HANDLE) {
    vkResetDescriptorPool(m_device, slot.descriptorPool, 0);
  }

  vkResetCommandBuffer(slot.cmdBuffer, 0);

  if (!ensureSlotOutputResources(slot, effWidth, effHeight)) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "renderFrame aborted: Failed to sync slot output resources.");
    return false;
  }

  VkCommandBufferBeginInfo beginInfo{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
  beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

  if (vkBeginCommandBuffer(slot.cmdBuffer, &beginInfo) != VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "renderFrame: Failed to begin command "
                                   "buffer recording for active frame slot.");
    return false;
  }

  VkImageMemoryBarrier barrier{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
  barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
  barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.image = slot.outputImage;
  barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  barrier.subresourceRange.baseMipLevel = 0;
  barrier.subresourceRange.levelCount = 1;
  barrier.subresourceRange.baseArrayLayer = 0;
  barrier.subresourceRange.layerCount = 1;
  barrier.srcAccessMask = 0;
  barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

  vkCmdPipelineBarrier(slot.cmdBuffer, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                       VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  // Clear canvas to opaque black to prevent any transparency showing through
  VkClearColorValue clearColor = {{0.0f, 0.0f, 0.0f, 1.0f}};
  VkImageSubresourceRange clearRange{VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
  vkCmdClearColorImage(slot.cmdBuffer, slot.outputImage,
                       VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &clearColor, 1,
                       &clearRange);

  barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.newLayout = VK_IMAGE_LAYOUT_GENERAL;
  barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
  barrier.dstAccessMask =
      VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;

  vkCmdPipelineBarrier(slot.cmdBuffer, VK_PIPELINE_STAGE_TRANSFER_BIT,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  for (size_t i = 0; i < layers.size(); ++i) {
    const auto &layer = layers[i];
    bool hasYuv =
        (layer.yView != VK_NULL_HANDLE && layer.uvView != VK_NULL_HANDLE);
    bool hasRgba = (layer.rgbaView != VK_NULL_HANDLE);
    if (!hasYuv && !hasRgba)
      continue;

    if (!layer.graph)
      continue;

    auto cachedPipeline = getOrCreatePipeline(layer.graph);
    if (!cachedPipeline || !cachedPipeline->isReady.load() ||
        cachedPipeline->pipeline == VK_NULL_HANDLE) {
      XYLA_LOG_WARN(
          "XylaRenderer",
          std::format("renderFrame: Skipping layer %zu due to an uncompiled or "
                      "invalid pipeline handle.",
                      i));
      continue;
    }

    if (!ensureSlotParamBuffer(
            slot, cachedPipeline->pushConstantLayout.totalSizeBytes)) {
      XYLA_LOG_ERROR("XylaRenderer",
                     std::format("renderFrame aborted: Param buffer allocation "
                                 "failed on layer %zu.",
                                 i));
      return false;
    }

    if (slot.mappedParamData) {
      uploadParametersToBuffer(slot.mappedParamData,
                               cachedPipeline->pushConstantLayout, layer);
    }

    VkDescriptorSetAllocateInfo setAlloc{
        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
    setAlloc.descriptorPool = slot.descriptorPool;
    setAlloc.descriptorSetCount = 1;
    setAlloc.pSetLayouts = &cachedPipeline->descriptorLayout;

    VkDescriptorSet descriptorSet = VK_NULL_HANDLE;

    if (vkAllocateDescriptorSets(m_device, &setAlloc, &descriptorSet) !=
        VK_SUCCESS) {
      XYLA_LOG_WARN(
          "XylaRenderer",
          std::format(
              "renderFrame: Failed to allocate descriptor set for layer %zu.",
              i));
      continue;
    }

    VkDescriptorImageInfo outputImageInfo{};
    outputImageInfo.imageView = slot.outputImageView;
    outputImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

    VkDescriptorImageInfo yImageInfo{};
    yImageInfo.sampler = m_defaultSampler;
    yImageInfo.imageView =
        (layer.yView != VK_NULL_HANDLE) ? layer.yView : m_dummyView;
    yImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

    VkDescriptorImageInfo uvImageInfo{};
    uvImageInfo.sampler = m_defaultSampler;
    uvImageInfo.imageView =
        (layer.uvView != VK_NULL_HANDLE) ? layer.uvView : m_dummyView;
    uvImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

    VkDescriptorImageInfo rgbaImageInfo{};
    rgbaImageInfo.sampler = m_defaultSampler;
    rgbaImageInfo.imageView =
        (layer.rgbaView != VK_NULL_HANDLE) ? layer.rgbaView : m_dummyView;
    rgbaImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

    VkDescriptorBufferInfo paramBufferInfo{};
    paramBufferInfo.buffer = (slot.paramBuffer != VK_NULL_HANDLE)
                                 ? slot.paramBuffer
                                 : m_dummyParamBuffer;
    paramBufferInfo.offset = 0;
    paramBufferInfo.range = VK_WHOLE_SIZE;

    VkWriteDescriptorSet writeSets[5]{};

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
    writeSets[1].pImageInfo = &yImageInfo;

    writeSets[2].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writeSets[2].dstSet = descriptorSet;
    writeSets[2].dstBinding = 2;
    writeSets[2].descriptorCount = 1;
    writeSets[2].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writeSets[2].pImageInfo = &uvImageInfo;

    writeSets[3].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writeSets[3].dstSet = descriptorSet;
    writeSets[3].dstBinding = 3;
    writeSets[3].descriptorCount = 1;
    writeSets[3].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writeSets[3].pImageInfo = &rgbaImageInfo;

    writeSets[4].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writeSets[4].dstSet = descriptorSet;
    writeSets[4].dstBinding = 4;
    writeSets[4].descriptorCount = 1;
    writeSets[4].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    writeSets[4].pBufferInfo = &paramBufferInfo;

    vkUpdateDescriptorSets(m_device, 5, writeSets, 0, nullptr);

    vkCmdBindPipeline(slot.cmdBuffer, VK_PIPELINE_BIND_POINT_COMPUTE,
                      cachedPipeline->pipeline);
    vkCmdBindDescriptorSets(slot.cmdBuffer, VK_PIPELINE_BIND_POINT_COMPUTE,
                            cachedPipeline->pipelineLayout, 0, 1,
                            &descriptorSet, 0, nullptr);

    uint32_t groupX = (effWidth + 15) / 16;
    uint32_t groupY = (effHeight + 15) / 16;
    vkCmdDispatch(slot.cmdBuffer, groupX, groupY, 1);

    if (i + 1 < layers.size()) {
      VkImageMemoryBarrier computeBarrier{
          VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
      computeBarrier.oldLayout = VK_IMAGE_LAYOUT_GENERAL;
      computeBarrier.newLayout = VK_IMAGE_LAYOUT_GENERAL;
      computeBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
      computeBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
      computeBarrier.image = slot.outputImage;
      computeBarrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
      computeBarrier.subresourceRange.baseMipLevel = 0;
      computeBarrier.subresourceRange.levelCount = 1;
      computeBarrier.subresourceRange.baseArrayLayer = 0;
      computeBarrier.subresourceRange.layerCount = 1;
      computeBarrier.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
      computeBarrier.dstAccessMask =
          VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;

      vkCmdPipelineBarrier(slot.cmdBuffer, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                           VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr,
                           0, nullptr, 1, &computeBarrier);
    }
  }

  barrier.oldLayout = VK_IMAGE_LAYOUT_GENERAL;
  barrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
  barrier.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

  vkCmdPipelineBarrier(slot.cmdBuffer, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                       VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  if (vkEndCommandBuffer(slot.cmdBuffer) != VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "renderFrame: Failed to end layout command recording context.");
    return false;
  }

  VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &slot.cmdBuffer;

  if (vkQueueSubmit(m_computeQueue, 1, &submitInfo, slot.fence) != VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "renderFrame: Critical hardware workload submission failed.");
    return false;
  }

  if (vkWaitForFences(m_device, 1, &slot.fence, VK_TRUE, UINT64_MAX) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "renderFrame: Timeout or driver hang "
                                   "encountered during fence processing wait.");
    return false;
  }

  m_currentFrameSlot = targetSlotIndex;

  emit frameRendered();
  return true;
}

bool XylaRenderer::renderFrame(const std::vector<RenderLayer> &layers,
                               uint32_t width, uint32_t height) {
  RenderContext ctx{.width = width, .height = height, .qualityScale = 1.0f};
  return renderFrame(layers, ctx);
}

bool XylaRenderer::renderFrame(const std::shared_ptr<NodeGraph> &graph,
                               VkImageView yPlaneView, VkImageView uvPlaneView,
                               uint32_t width, uint32_t height,
                               const QVariantMap &overrideValues) {
  RenderLayer layer;
  layer.graph = graph;
  layer.yView = yPlaneView;
  layer.uvView = uvPlaneView;
  layer.rgbaView = VK_NULL_HANDLE;
  return renderFrame(std::vector<RenderLayer>{layer}, width, height);
}

bool XylaRenderer::renderClipFrame(VkImageView yView, VkImageView uvView,
                                   const RenderContext &ctx,
                                   const std::shared_ptr<NodeGraph> &graph,
                                   VkImageView rgbaView) {
  const uint32_t effWidth = ctx.effectiveWidth();
  const uint32_t effHeight = ctx.effectiveHeight();

  static constexpr uint32_t MAX_XYLA_CANVAS_DIMENSION = 16384;
  if (effWidth > MAX_XYLA_CANVAS_DIMENSION ||
      effHeight > MAX_XYLA_CANVAS_DIMENSION) {
    XYLA_LOG_ERROR("XylaRenderer", "renderClipFrame aborted: Target dimensions "
                                   "exceed maximum supported limits.");
    return false;
  }

  if (!m_initialized.load(std::memory_order_acquire)) {
    std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
    if (!m_initialized.load(std::memory_order_acquire)) {
      ensureInitialized_NoLock();
      if (!m_initialized.load(std::memory_order_acquire)) {
        XYLA_LOG_ERROR(
            "XylaRenderer",
            "renderClipFrame aborted: Renderer initialization failed.");
        return false;
      }
    }
  }

  bool hasYuv = (yView != VK_NULL_HANDLE && uvView != VK_NULL_HANDLE);
  bool hasRgba = (rgbaView != VK_NULL_HANDLE);
  if (!hasYuv && !hasRgba) {
    XYLA_LOG_WARN("XylaRenderer", "renderClipFrame: Aborted due to missing "
                                  "valid YUV or RGBA source views.");
    return false;
  }

  if (m_clipSlot.fence == VK_NULL_HANDLE) {
    VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
    fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;

    if (vkCreateFence(m_device, &fenceInfo, nullptr, &m_clipSlot.fence) !=
        VK_SUCCESS) {
      XYLA_LOG_ERROR("XylaRenderer",
                     "renderClipFrame: Failed to allocate hardware "
                     "synchronization fence for clip slot.");
      m_clipSlot.fence = VK_NULL_HANDLE;
      return false;
    }
  }

  if (m_clipSlot.cmdBuffer == VK_NULL_HANDLE) {
    VkCommandBufferAllocateInfo clipCmdAlloc{
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
    clipCmdAlloc.commandPool = m_commandPool;
    clipCmdAlloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    clipCmdAlloc.commandBufferCount = 1;

    if (vkAllocateCommandBuffers(m_device, &clipCmdAlloc,
                                 &m_clipSlot.cmdBuffer) != VK_SUCCESS ||
        m_clipSlot.cmdBuffer == VK_NULL_HANDLE) {
      XYLA_LOG_ERROR(
          "XylaRenderer",
          "renderClipFrame: Failed to allocate clip command buffer context.");
      return false;
    }
  }

  if (m_clipSlot.descriptorPool == VK_NULL_HANDLE) {
    VkDescriptorPoolSize poolSizes[] = {
        {VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 256},
        {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 64},
        {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 64}};

    VkDescriptorPoolCreateInfo descPoolInfo{
        VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
    descPoolInfo.flags = 0;
    descPoolInfo.maxSets = 64;
    descPoolInfo.poolSizeCount = 3;
    descPoolInfo.pPoolSizes = poolSizes;

    if (vkCreateDescriptorPool(m_device, &descPoolInfo, nullptr,
                               &m_clipSlot.descriptorPool) != VK_SUCCESS) {
      XYLA_LOG_ERROR(
          "XylaRenderer",
          "renderClipFrame: Failed to allocate clip descriptor pool wrapper.");
      return false;
    }
  }

  if (vkWaitForFences(m_device, 1, &m_clipSlot.fence, VK_TRUE, UINT64_MAX) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "renderClipFrame: Failed or timed out waiting for clip sync fence.");
    return false;
  }
  if (vkResetFences(m_device, 1, &m_clipSlot.fence) != VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "renderClipFrame: Failed to reset clip "
                                   "synchronization fence primitive.");
    return false;
  }

  vkResetDescriptorPool(m_device, m_clipSlot.descriptorPool, 0);
  if (vkResetCommandBuffer(m_clipSlot.cmdBuffer, 0) != VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "renderClipFrame: Failed to recycle command buffer state layout.");
    return false;
  }

  if (!ensureSlotOutputResources(m_clipSlot, effWidth, effHeight)) {
    XYLA_LOG_ERROR("XylaRenderer", "renderClipFrame aborted: Failed to adjust "
                                   "clip slot output resource dimensions.");
    return false;
  }

  VkCommandBufferBeginInfo beginInfo{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
  beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
  if (vkBeginCommandBuffer(m_clipSlot.cmdBuffer, &beginInfo) != VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "renderClipFrame: Failed to open command buffer recording gateway.");
    return false;
  }

  VkImageMemoryBarrier barrier{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
  barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
  barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.image = m_clipSlot.outputImage;
  barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  barrier.subresourceRange.baseMipLevel = 0;
  barrier.subresourceRange.levelCount = 1;
  barrier.subresourceRange.baseArrayLayer = 0;
  barrier.subresourceRange.layerCount = 1;
  barrier.srcAccessMask = 0;
  barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

  vkCmdPipelineBarrier(m_clipSlot.cmdBuffer, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                       VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  // Clear canvas before running compute shader to wipe dirty VRAM pages
  VkClearColorValue clearColor = {{0.0f, 0.0f, 0.0f, 1.0f}};
  VkImageSubresourceRange clearRange{VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
  vkCmdClearColorImage(m_clipSlot.cmdBuffer, m_clipSlot.outputImage,
                       VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &clearColor, 1,
                       &clearRange);

  barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.newLayout = VK_IMAGE_LAYOUT_GENERAL;
  barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
  barrier.dstAccessMask =
      VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;

  vkCmdPipelineBarrier(m_clipSlot.cmdBuffer, VK_PIPELINE_STAGE_TRANSFER_BIT,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  std::shared_ptr<CachedPipeline> cachedPipeline = nullptr;
  if (graph) {
    cachedPipeline = getOrCreatePipeline(graph);
  } else {
    static constexpr uint64_t PASSTHROUGH_PIPELINE_HASH_KEY =
        0xFFFFFFFFFFFFFFFFULL;

    auto it = m_pipelineCache.find(PASSTHROUGH_PIPELINE_HASH_KEY);
    if (it != m_pipelineCache.end()) {
      cachedPipeline = it->second;
    } else {
      CompiledGraphShader defaultShader;
      defaultShader.glslSource = QString::fromUtf8(kDefaultPassthroughGlsl);

      auto p = std::make_shared<CachedPipeline>();
      if (compilePipelineInternal(defaultShader, *p)) {
        p->isReady.store(true, std::memory_order_release);
        m_pipelineCache[PASSTHROUGH_PIPELINE_HASH_KEY] = p;
        cachedPipeline = p;
      } else {
        XYLA_LOG_ERROR("XylaRenderer",
                       "renderClipFrame: Core fallback passthrough shader "
                       "failed compilation layout mapping.");
        vkEndCommandBuffer(m_clipSlot.cmdBuffer);
        return false;
      }
    }
  }

  if (cachedPipeline &&
      cachedPipeline->isReady.load(std::memory_order_acquire) &&
      cachedPipeline->pipeline != VK_NULL_HANDLE) {

    if (!ensureSlotParamBuffer(
            m_clipSlot, cachedPipeline->pushConstantLayout.totalSizeBytes)) {
      XYLA_LOG_ERROR("XylaRenderer", "renderClipFrame: Failed to sync metadata "
                                     "layout parameters for active clip.");
      vkEndCommandBuffer(m_clipSlot.cmdBuffer);
      return false;
    }

    if (m_clipSlot.mappedParamData && graph) {
      RenderLayer clipLayer;
      clipLayer.graph = graph;
      clipLayer.animMgr = nullptr;
      clipLayer.frame = ctx.frame;
      clipLayer.yView = yView;
      clipLayer.uvView = uvView;
      clipLayer.rgbaView = rgbaView;
      uploadParametersToBuffer(m_clipSlot.mappedParamData,
                               cachedPipeline->pushConstantLayout, clipLayer);
    }

    VkDescriptorSetAllocateInfo setAlloc{
        VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
    setAlloc.descriptorPool = m_clipSlot.descriptorPool;
    setAlloc.descriptorSetCount = 1;
    setAlloc.pSetLayouts = &cachedPipeline->descriptorLayout;

    VkDescriptorSet descriptorSet = VK_NULL_HANDLE;
    if (vkAllocateDescriptorSets(m_device, &setAlloc, &descriptorSet) !=
            VK_SUCCESS ||
        descriptorSet == VK_NULL_HANDLE) {
      XYLA_LOG_ERROR("XylaRenderer", "renderClipFrame: Failed to allocate "
                                     "active clip descriptor set components.");
      vkEndCommandBuffer(m_clipSlot.cmdBuffer);
      return false;
    }

    VkDescriptorImageInfo outputImageInfo{};
    outputImageInfo.imageView = m_clipSlot.outputImageView;
    outputImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

    VkDescriptorImageInfo yImageInfo{};
    yImageInfo.sampler = m_defaultSampler;
    yImageInfo.imageView = (yView != VK_NULL_HANDLE) ? yView : m_dummyView;
    yImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

    VkDescriptorImageInfo uvImageInfo{};
    uvImageInfo.sampler = m_defaultSampler;
    uvImageInfo.imageView = (uvView != VK_NULL_HANDLE) ? uvView : m_dummyView;
    uvImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

    VkDescriptorImageInfo rgbaImageInfo{};
    rgbaImageInfo.sampler = m_defaultSampler;
    rgbaImageInfo.imageView =
        (rgbaView != VK_NULL_HANDLE) ? rgbaView : m_dummyView;
    rgbaImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

    VkDescriptorBufferInfo paramBufferInfo{};
    paramBufferInfo.buffer = (m_clipSlot.paramBuffer != VK_NULL_HANDLE)
                                 ? m_clipSlot.paramBuffer
                                 : m_dummyParamBuffer;
    paramBufferInfo.offset = 0;
    paramBufferInfo.range = VK_WHOLE_SIZE;

    VkWriteDescriptorSet writeSets[5]{};
    for (int k = 0; k < 5; ++k) {
      writeSets[k].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
      writeSets[k].dstSet = descriptorSet;
      writeSets[k].dstBinding = k;
      writeSets[k].descriptorCount = 1;
    }

    writeSets[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
    writeSets[0].pImageInfo = &outputImageInfo;

    writeSets[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writeSets[1].pImageInfo = &yImageInfo;

    writeSets[2].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writeSets[2].pImageInfo = &uvImageInfo;

    writeSets[3].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writeSets[3].pImageInfo = &rgbaImageInfo;

    writeSets[4].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    writeSets[4].pBufferInfo = &paramBufferInfo;

    vkUpdateDescriptorSets(m_device, 5, writeSets, 0, nullptr);

    vkCmdBindPipeline(m_clipSlot.cmdBuffer, VK_PIPELINE_BIND_POINT_COMPUTE,
                      cachedPipeline->pipeline);
    vkCmdBindDescriptorSets(
        m_clipSlot.cmdBuffer, VK_PIPELINE_BIND_POINT_COMPUTE,
        cachedPipeline->pipelineLayout, 0, 1, &descriptorSet, 0, nullptr);

    uint32_t groupX = (effWidth + 15) / 16;
    uint32_t groupY = (effHeight + 15) / 16;
    vkCmdDispatch(m_clipSlot.cmdBuffer, groupX, groupY, 1);
  } else {
    XYLA_LOG_ERROR("XylaRenderer",
                   "renderClipFrame aborted: Active pipeline tracking pointer "
                   "state is invalid or uncompiled.");
    vkEndCommandBuffer(m_clipSlot.cmdBuffer);
    return false;
  }

  barrier.oldLayout = VK_IMAGE_LAYOUT_GENERAL;
  barrier.newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
  barrier.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

  vkCmdPipelineBarrier(m_clipSlot.cmdBuffer,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                       VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  if (vkEndCommandBuffer(m_clipSlot.cmdBuffer) != VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "renderClipFrame: Failed to finalize clip command buffer recording.");
    return false;
  }

  VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &m_clipSlot.cmdBuffer;

  if (vkQueueSubmit(m_computeQueue, 1, &submitInfo, m_clipSlot.fence) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR(
        "XylaRenderer",
        "renderClipFrame: Critical clip workload submission failed.");
    return false;
  }

  if (vkWaitForFences(m_device, 1, &m_clipSlot.fence, VK_TRUE, UINT64_MAX) !=
      VK_SUCCESS) {
    XYLA_LOG_ERROR("XylaRenderer", "renderClipFrame: Timeout or driver hang "
                                   "encountered waiting for clip fence sync.");
    return false;
  }

  emit clipFrameRendered();
  return true;
}

bool XylaRenderer::renderClipFrame(VkImageView yView, VkImageView uvView,
                                   uint32_t width, uint32_t height,
                                   const std::shared_ptr<NodeGraph> &graph,
                                   VkImageView rgbaView) {
  RenderContext ctx{.width = width, .height = height, .qualityScale = 1.0f};
  return renderClipFrame(yView, uvView, ctx, graph, rgbaView);
}

OutputSnapshot XylaRenderer::currentOutputSnapshot() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
  const auto &slot = m_frameSlots[m_currentFrameSlot];
  return {slot.outputImage, slot.width, slot.height};
}

OutputSnapshot XylaRenderer::currentClipSnapshot() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
  return {m_clipSlot.outputImage, m_clipSlot.width, m_clipSlot.height};
}

VkImage XylaRenderer::currentOutputVkImage() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
  return m_frameSlots[m_currentFrameSlot].outputImage;
}

uint32_t XylaRenderer::currentWidth() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
  return m_frameSlots[m_currentFrameSlot].width;
}

uint32_t XylaRenderer::currentHeight() const noexcept {
  std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
  return m_frameSlots[m_currentFrameSlot].height;
}

bool XylaRenderer::isInitialized() const noexcept {
  return m_initialized.load();
}

VkDevice XylaRenderer::device() const noexcept { return m_device; }

VkPhysicalDevice XylaRenderer::physicalDevice() const noexcept {
  return m_physicalDevice;
}

void XylaRenderer::cleanupInternal() {
  destroyDummyResources();

  if (m_device != VK_NULL_HANDLE) {
    for (auto &[hash, cp] : m_pipelineCache) {
      if (cp) {
        if (cp->pipeline != VK_NULL_HANDLE)
          vkDestroyPipeline(m_device, cp->pipeline, nullptr);
        if (cp->pipelineLayout != VK_NULL_HANDLE)
          vkDestroyPipelineLayout(m_device, cp->pipelineLayout, nullptr);
        if (cp->descriptorLayout != VK_NULL_HANDLE)
          vkDestroyDescriptorSetLayout(m_device, cp->descriptorLayout, nullptr);
      }
    }
  }
  m_pipelineCache.clear();

  for (size_t i = 0; i < kMaxInFlightFrames; ++i) {
    auto &slot = m_frameSlots[i];
    if (m_device != VK_NULL_HANDLE) {
      if (slot.fence != VK_NULL_HANDLE) {
        vkWaitForFences(m_device, 1, &slot.fence, VK_TRUE, UINT64_MAX);
        vkDestroyFence(m_device, slot.fence, nullptr);
      }
      if (slot.descriptorPool != VK_NULL_HANDLE) {
        vkDestroyDescriptorPool(m_device, slot.descriptorPool, nullptr);
      }
    }
    slot.fence = VK_NULL_HANDLE;
    slot.descriptorPool = VK_NULL_HANDLE;
    destroySlotResources(slot);
  }

  if (m_clipSlot.fence != VK_NULL_HANDLE && m_device != VK_NULL_HANDLE) {
    vkWaitForFences(m_device, 1, &m_clipSlot.fence, VK_TRUE, UINT64_MAX);
    vkDestroyFence(m_device, m_clipSlot.fence, nullptr);
    m_clipSlot.fence = VK_NULL_HANDLE;
  }
  if (m_clipSlot.descriptorPool != VK_NULL_HANDLE &&
      m_device != VK_NULL_HANDLE) {
    vkDestroyDescriptorPool(m_device, m_clipSlot.descriptorPool, nullptr);
    m_clipSlot.descriptorPool = VK_NULL_HANDLE;
  }
  destroySlotResources(m_clipSlot);

  if (m_defaultSampler != VK_NULL_HANDLE && m_device != VK_NULL_HANDLE) {
    vkDestroySampler(m_device, m_defaultSampler, nullptr);
    m_defaultSampler = VK_NULL_HANDLE;
  }

  if (m_commandPool != VK_NULL_HANDLE && m_device != VK_NULL_HANDLE) {
    vkDestroyCommandPool(m_device, m_commandPool, nullptr);
    m_commandPool = VK_NULL_HANDLE;
  }

  // Nullify device handles so any subsequent cleanup calls safely no-op
  m_device = VK_NULL_HANDLE;
  m_physicalDevice = VK_NULL_HANDLE;
  m_instance = VK_NULL_HANDLE;
  m_computeQueue = VK_NULL_HANDLE;

  m_initialized.store(false, std::memory_order_release);
}

void XylaRenderer::cleanup() {
  std::lock_guard<std::recursive_mutex> lock(m_renderMutex);
  cleanupInternal();
}

} // namespace xyla::render
