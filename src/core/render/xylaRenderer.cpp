#include "xylaRenderer.hpp"
#include "core/log/logger.hpp"
#include "shaderCompiler.hpp"
#include <QThreadPool>
#include <QVector2D>
#include <cstring>

namespace xyla::render {

// Default Vulkan NV12 (Y + UV) to RGBA Compute Shader Fallback
static const char *kDefaultPassthroughGlsl = R"(
#version 450
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(binding = 0, rgba8) uniform writeonly image2D u_outputFrame;
layout(binding = 1) uniform sampler2D u_planeY;
layout(binding = 2) uniform sampler2D u_planeUV;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(u_outputFrame);
    if (pos.x >= size.x || pos.y >= size.y) return;

    vec2 uv = (vec2(pos) + vec2(0.5)) / vec2(size);
    float y = texture(u_planeY, uv).r;
    vec2 uvPlane = texture(u_planeUV, uv).rg;

    float c = y - 0.062745;
    float d = uvPlane.r - 0.5;
    float e = uvPlane.g - 0.5;

    float r = clamp(1.164383 * c + 1.596027 * e, 0.0, 1.0);
    float g = clamp(1.164383 * c - 0.391762 * d - 0.812968 * e, 0.0, 1.0);
    float b = clamp(1.164383 * c + 2.017232 * d, 0.0, 1.0);

    imageStore(u_outputFrame, pos, vec4(r, g, b, 1.0));
}
)";

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

  ensureInitialized();
  m_initialized.store(true);
  XYLA_LOG_INFO("XylaRenderer", "GPU compute compositor core ready.");
}

void XylaRenderer::ensureInitialized() {
  if (m_initialized.load())
    return;

  std::lock_guard<std::mutex> lock(m_renderMutex);
  if (m_initialized.load())
    return;

  // Case 1: Vulkan device passed via initVulkanContext()
  if (m_device != VK_NULL_HANDLE) {
    if (m_commandPool == VK_NULL_HANDLE) {
      VkCommandPoolCreateInfo poolInfo{
          VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO};
      poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
      poolInfo.queueFamilyIndex = 0;
      vkCreateCommandPool(m_device, &poolInfo, nullptr, &m_commandPool);

      VkCommandBufferAllocateInfo cmdAlloc{
          VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
      cmdAlloc.commandPool = m_commandPool;
      cmdAlloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
      cmdAlloc.commandBufferCount = 1;
      vkAllocateCommandBuffers(m_device, &cmdAlloc, &m_renderCmdBuffer);

      VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
      fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;
      vkCreateFence(m_device, &fenceInfo, nullptr, &m_renderFence);

      VkDescriptorPoolSize poolSizes[] = {
          {VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 128},
          {VK_DESCRIPTOR_TYPE_STORAGE_IMAGE, 64}};
      VkDescriptorPoolCreateInfo descPoolInfo{
          VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};
      descPoolInfo.flags = VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
      descPoolInfo.maxSets = 64;
      descPoolInfo.poolSizeCount = 2;
      descPoolInfo.pPoolSizes = poolSizes;
      vkCreateDescriptorPool(m_device, &descPoolInfo, nullptr,
                             &m_descriptorPool);

      VkSamplerCreateInfo samplerInfo{VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO};
      samplerInfo.magFilter = VK_FILTER_LINEAR;
      samplerInfo.minFilter = VK_FILTER_LINEAR;
      samplerInfo.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
      samplerInfo.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
      samplerInfo.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
      vkCreateSampler(m_device, &samplerInfo, nullptr, &m_defaultSampler);
    }
    m_initialized.store(true);
    return;
  }

  // Case 2: Standalone Vulkan Engine Boot
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
  cmdAlloc.commandBufferCount = 1;
  vkAllocateCommandBuffers(m_device, &cmdAlloc, &m_renderCmdBuffer);

  VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
  fenceInfo.flags = VK_FENCE_CREATE_SIGNALED_BIT;
  vkCreateFence(m_device, &fenceInfo, nullptr, &m_renderFence);

  VkDescriptorPoolSize poolSizes[] = {
      {VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, 128},
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

VkImageView XylaRenderer::createImageViewForImage(VkImage image,
                                                  VkFormat format) {
  ensureInitialized();
  if (image == VK_NULL_HANDLE || m_device == VK_NULL_HANDLE)
    return VK_NULL_HANDLE;

  VkImageView view = VK_NULL_HANDLE;
  VkImageViewCreateInfo viewInfo{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
  viewInfo.image = image;
  viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
  viewInfo.format = format;
  viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  viewInfo.subresourceRange.levelCount = 1;
  viewInfo.subresourceRange.layerCount = 1;

  if (vkCreateImageView(m_device, &viewInfo, nullptr, &view) == VK_SUCCESS) {
    return view;
  }
  return VK_NULL_HANDLE;
}

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

bool XylaRenderer::allocateAndUploadYuvTextures(
    const uint8_t *yData, int yPitch, const uint8_t *uvData, int uvPitch,
    uint32_t width, uint32_t height, VkImage *outYImage,
    VkDeviceMemory *outYMem, VkImageView *outYView, VkImage *outUVImage,
    VkDeviceMemory *outUVMem, VkImageView *outUVView) {
  ensureInitialized();
  if (!m_initialized.load() || m_device == VK_NULL_HANDLE || !yData ||
      !uvData || width == 0 || height == 0)
    return false;

  std::lock_guard<std::mutex> lock(m_renderMutex);

  auto createPlane = [&](uint32_t w, uint32_t h, VkFormat fmt,
                         const uint8_t *srcData, int pitch, VkImage *img,
                         VkDeviceMemory *mem, VkImageView *view) {
    size_t dataSize =
        static_cast<size_t>(w) * h * (fmt == VK_FORMAT_R8G8_UNORM ? 2 : 1);

    VkImageCreateInfo imgInfo{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
    imgInfo.imageType = VK_IMAGE_TYPE_2D;
    imgInfo.format = fmt;
    imgInfo.extent = {w, h, 1};
    imgInfo.mipLevels = 1;
    imgInfo.arrayLayers = 1;
    imgInfo.samples = VK_SAMPLE_COUNT_1_BIT;
    imgInfo.tiling = VK_IMAGE_TILING_OPTIMAL;
    imgInfo.usage =
        VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    imgInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    imgInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

    vkCreateImage(m_device, &imgInfo, nullptr, img);

    VkMemoryRequirements memReqs;
    vkGetImageMemoryRequirements(m_device, *img, &memReqs);

    VkPhysicalDeviceMemoryProperties memProps;
    vkGetPhysicalDeviceMemoryProperties(m_physicalDevice, &memProps);

    uint32_t devMemType = UINT32_MAX;
    for (uint32_t i = 0; i < memProps.memoryTypeCount; ++i) {
      if ((memReqs.memoryTypeBits & (1 << i)) &&
          (memProps.memoryTypes[i].propertyFlags &
           VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) {
        devMemType = i;
        break;
      }
    }

    VkMemoryAllocateInfo allocInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
    allocInfo.allocationSize = memReqs.size;
    allocInfo.memoryTypeIndex = devMemType;
    vkAllocateMemory(m_device, &allocInfo, nullptr, mem);
    vkBindImageMemory(m_device, *img, *mem, 0);

    VkImageViewCreateInfo viewInfo{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
    viewInfo.image = *img;
    viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
    viewInfo.format = fmt;
    viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    viewInfo.subresourceRange.levelCount = 1;
    viewInfo.subresourceRange.layerCount = 1;
    vkCreateImageView(m_device, &viewInfo, nullptr, view);

    VkBuffer uploadBuf = VK_NULL_HANDLE;
    VkDeviceMemory uploadMem = VK_NULL_HANDLE;

    VkBufferCreateInfo bufInfo{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
    bufInfo.size = dataSize;
    bufInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
    bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    vkCreateBuffer(m_device, &bufInfo, nullptr, &uploadBuf);

    vkGetBufferMemoryRequirements(m_device, uploadBuf, &memReqs);

    uint32_t hostMemType = UINT32_MAX;
    for (uint32_t i = 0; i < memProps.memoryTypeCount; ++i) {
      if ((memReqs.memoryTypeBits & (1 << i)) &&
          (memProps.memoryTypes[i].propertyFlags &
           (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
            VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))) {
        hostMemType = i;
        break;
      }
    }

    allocInfo.allocationSize = memReqs.size;
    allocInfo.memoryTypeIndex = hostMemType;
    vkAllocateMemory(m_device, &allocInfo, nullptr, &uploadMem);
    vkBindBufferMemory(m_device, uploadBuf, uploadMem, 0);

    void *mapped = nullptr;
    vkMapMemory(m_device, uploadMem, 0, dataSize, 0, &mapped);
    if (pitch == static_cast<int>(w * (fmt == VK_FORMAT_R8G8_UNORM ? 2 : 1))) {
      std::memcpy(mapped, srcData, dataSize);
    } else {
      uint8_t *dstRow = static_cast<uint8_t *>(mapped);
      const uint8_t *srcRow = srcData;
      size_t rowBytes = w * (fmt == VK_FORMAT_R8G8_UNORM ? 2 : 1);
      for (uint32_t row = 0; row < h; ++row) {
        std::memcpy(dstRow, srcRow, rowBytes);
        dstRow += rowBytes;
        srcRow += pitch;
      }
    }
    vkUnmapMemory(m_device, uploadMem);

    VkCommandBufferAllocateInfo cmdAlloc{
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
    cmdAlloc.commandPool = m_commandPool;
    cmdAlloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cmdAlloc.commandBufferCount = 1;

    VkCommandBuffer uploadCmdBuffer = VK_NULL_HANDLE;
    vkAllocateCommandBuffers(m_device, &cmdAlloc, &uploadCmdBuffer);

    VkFence uploadFence = VK_NULL_HANDLE;
    VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
    vkCreateFence(m_device, &fenceInfo, nullptr, &uploadFence);

    VkCommandBufferBeginInfo beginInfo{
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkBeginCommandBuffer(uploadCmdBuffer, &beginInfo);

    VkImageMemoryBarrier barrier{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
    barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
    barrier.image = *img;
    barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    barrier.subresourceRange.levelCount = 1;
    barrier.subresourceRange.layerCount = 1;
    barrier.srcAccessMask = 0;
    barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

    vkCmdPipelineBarrier(uploadCmdBuffer, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                         VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0,
                         nullptr, 1, &barrier);

    VkBufferImageCopy copyRegion{};
    copyRegion.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    copyRegion.imageSubresource.layerCount = 1;
    copyRegion.imageExtent = {w, h, 1};
    vkCmdCopyBufferToImage(uploadCmdBuffer, uploadBuf, *img,
                           VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1,
                           &copyRegion);

    barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    barrier.newLayout = VK_IMAGE_LAYOUT_GENERAL;
    barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

    vkCmdPipelineBarrier(uploadCmdBuffer, VK_PIPELINE_STAGE_TRANSFER_BIT,
                         VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0,
                         nullptr, 1, &barrier);

    vkEndCommandBuffer(uploadCmdBuffer);

    VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &uploadCmdBuffer;

    vkQueueSubmit(m_computeQueue, 1, &submitInfo, uploadFence);
    vkWaitForFences(m_device, 1, &uploadFence, VK_TRUE, 1000000000ULL);

    vkDestroyFence(m_device, uploadFence, nullptr);
    vkFreeCommandBuffers(m_device, m_commandPool, 1, &uploadCmdBuffer);
    vkDestroyBuffer(m_device, uploadBuf, nullptr);
    vkFreeMemory(m_device, uploadMem, nullptr);
  };

  createPlane(width, height, VK_FORMAT_R8_UNORM, yData, yPitch, outYImage,
              outYMem, outYView);
  createPlane(width / 2, height / 2, VK_FORMAT_R8G8_UNORM, uvData, uvPitch,
              outUVImage, outUVMem, outUVView);

  return (*outYView != VK_NULL_HANDLE && *outUVView != VK_NULL_HANDLE);
}

bool XylaRenderer::uploadToExistingYuvTextures(const uint8_t *yData, int yPitch,
                                               const uint8_t *uvData,
                                               int uvPitch, uint32_t width,
                                               uint32_t height, VkImage yImage,
                                               VkImage uvImage) {
  ensureInitialized();
  if (!m_initialized.load() || m_device == VK_NULL_HANDLE || !yData ||
      !uvData || width == 0 || height == 0 || yImage == VK_NULL_HANDLE ||
      uvImage == VK_NULL_HANDLE) {
    return false;
  }

  std::lock_guard<std::mutex> lock(m_renderMutex);

  size_t ySize = static_cast<size_t>(width) * height;
  size_t uvSize = static_cast<size_t>(width / 2) * (height / 2) * 2;
  size_t totalSize = ySize + uvSize;

  VkBuffer uploadBuf = VK_NULL_HANDLE;
  VkDeviceMemory uploadMem = VK_NULL_HANDLE;

  VkBufferCreateInfo bufInfo{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
  bufInfo.size = totalSize;
  bufInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
  bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  if (vkCreateBuffer(m_device, &bufInfo, nullptr, &uploadBuf) != VK_SUCCESS)
    return false;

  VkMemoryRequirements memReqs;
  vkGetBufferMemoryRequirements(m_device, uploadBuf, &memReqs);

  VkPhysicalDeviceMemoryProperties memProps;
  vkGetPhysicalDeviceMemoryProperties(m_physicalDevice, &memProps);

  uint32_t hostMemType = UINT32_MAX;
  for (uint32_t i = 0; i < memProps.memoryTypeCount; ++i) {
    if ((memReqs.memoryTypeBits & (1 << i)) &&
        (memProps.memoryTypes[i].propertyFlags &
         (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
          VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))) {
      hostMemType = i;
      break;
    }
  }

  VkMemoryAllocateInfo allocInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
  allocInfo.allocationSize = memReqs.size;
  allocInfo.memoryTypeIndex = hostMemType;
  if (vkAllocateMemory(m_device, &allocInfo, nullptr, &uploadMem) !=
      VK_SUCCESS) {
    vkDestroyBuffer(m_device, uploadBuf, nullptr);
    return false;
  }

  vkBindBufferMemory(m_device, uploadBuf, uploadMem, 0);

  void *mapped = nullptr;
  vkMapMemory(m_device, uploadMem, 0, totalSize, 0, &mapped);
  if (mapped) {
    uint8_t *dstY = static_cast<uint8_t *>(mapped);
    if (yPitch == static_cast<int>(width)) {
      std::memcpy(dstY, yData, ySize);
    } else {
      for (uint32_t r = 0; r < height; ++r) {
        std::memcpy(dstY + r * width, yData + r * yPitch, width);
      }
    }

    uint8_t *dstUV = static_cast<uint8_t *>(mapped) + ySize;
    uint32_t uvRowBytes = width;
    uint32_t uvHeight = height / 2;
    if (uvPitch == static_cast<int>(uvRowBytes)) {
      std::memcpy(dstUV, uvData, uvSize);
    } else {
      for (uint32_t r = 0; r < uvHeight; ++r) {
        std::memcpy(dstUV + r * uvRowBytes, uvData + r * uvPitch, uvRowBytes);
      }
    }
    vkUnmapMemory(m_device, uploadMem);
  }

  VkCommandBufferAllocateInfo cmdAlloc{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
  cmdAlloc.commandPool = m_commandPool;
  cmdAlloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cmdAlloc.commandBufferCount = 1;

  VkCommandBuffer cmdBuffer = VK_NULL_HANDLE;
  vkAllocateCommandBuffers(m_device, &cmdAlloc, &cmdBuffer);

  VkFence fence = VK_NULL_HANDLE;
  VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
  vkCreateFence(m_device, &fenceInfo, nullptr, &fence);

  VkCommandBufferBeginInfo beginInfo{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
  beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
  vkBeginCommandBuffer(cmdBuffer, &beginInfo);

  VkImageMemoryBarrier barriers[2]{};
  barriers[0].sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
  barriers[0].oldLayout = VK_IMAGE_LAYOUT_GENERAL;
  barriers[0].newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barriers[0].srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barriers[0].dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barriers[0].image = yImage;
  barriers[0].subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  barriers[0].subresourceRange.levelCount = 1;
  barriers[0].subresourceRange.layerCount = 1;
  barriers[0].srcAccessMask = VK_ACCESS_SHADER_READ_BIT;
  barriers[0].dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

  barriers[1] = barriers[0];
  barriers[1].image = uvImage;

  vkCmdPipelineBarrier(cmdBuffer, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                       VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0,
                       nullptr, 2, barriers);

  VkBufferImageCopy yCopy{};
  yCopy.bufferOffset = 0;
  yCopy.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  yCopy.imageSubresource.layerCount = 1;
  yCopy.imageExtent = {width, height, 1};
  vkCmdCopyBufferToImage(cmdBuffer, uploadBuf, yImage,
                         VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &yCopy);

  VkBufferImageCopy uvCopy{};
  uvCopy.bufferOffset = ySize;
  uvCopy.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  uvCopy.imageSubresource.layerCount = 1;
  uvCopy.imageExtent = {width / 2, height / 2, 1};
  vkCmdCopyBufferToImage(cmdBuffer, uploadBuf, uvImage,
                         VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &uvCopy);

  barriers[0].oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barriers[0].newLayout = VK_IMAGE_LAYOUT_GENERAL;
  barriers[0].srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
  barriers[0].dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

  barriers[1].oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barriers[1].newLayout = VK_IMAGE_LAYOUT_GENERAL;
  barriers[1].srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
  barriers[1].dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

  vkCmdPipelineBarrier(cmdBuffer, VK_PIPELINE_STAGE_TRANSFER_BIT,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0,
                       nullptr, 2, barriers);

  vkEndCommandBuffer(cmdBuffer);

  VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &cmdBuffer;

  vkQueueSubmit(m_computeQueue, 1, &submitInfo, fence);
  vkWaitForFences(m_device, 1, &fence, VK_TRUE, 1000000000ULL);

  vkDestroyFence(m_device, fence, nullptr);
  vkFreeCommandBuffers(m_device, m_commandPool, 1, &cmdBuffer);
  vkDestroyBuffer(m_device, uploadBuf, nullptr);
  vkFreeMemory(m_device, uploadMem, nullptr);

  return true;
}

VkImageView XylaRenderer::allocateAndUploadTexture(const QImage &image,
                                                   VkImage *outImage,
                                                   VkDeviceMemory *outMemory) {
  ensureInitialized();
  if (!m_initialized.load() || m_device == VK_NULL_HANDLE || image.isNull() ||
      !outImage || !outMemory)
    return VK_NULL_HANDLE;

  std::lock_guard<std::mutex> lock(m_renderMutex);
  QImage rgba = image.convertToFormat(QImage::Format_RGBA8888);
  uint32_t width = static_cast<uint32_t>(rgba.width());
  uint32_t height = static_cast<uint32_t>(rgba.height());
  VkDeviceSize imageSize = width * height * 4;

  VkImageCreateInfo imgInfo{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
  imgInfo.imageType = VK_IMAGE_TYPE_2D;
  imgInfo.format = VK_FORMAT_R8G8B8A8_UNORM;
  imgInfo.extent = {width, height, 1};
  imgInfo.mipLevels = 1;
  imgInfo.arrayLayers = 1;
  imgInfo.samples = VK_SAMPLE_COUNT_1_BIT;
  imgInfo.tiling = VK_IMAGE_TILING_OPTIMAL;
  imgInfo.usage = VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
  imgInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  imgInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;

  vkCreateImage(m_device, &imgInfo, nullptr, outImage);

  VkMemoryRequirements memReqs;
  vkGetImageMemoryRequirements(m_device, *outImage, &memReqs);

  VkPhysicalDeviceMemoryProperties memProps;
  vkGetPhysicalDeviceMemoryProperties(m_physicalDevice, &memProps);

  uint32_t devMemType = UINT32_MAX;
  for (uint32_t i = 0; i < memProps.memoryTypeCount; ++i) {
    if ((memReqs.memoryTypeBits & (1 << i)) &&
        (memProps.memoryTypes[i].propertyFlags &
         VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) {
      devMemType = i;
      break;
    }
  }

  VkMemoryAllocateInfo allocInfo{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
  allocInfo.allocationSize = memReqs.size;
  allocInfo.memoryTypeIndex = devMemType;
  vkAllocateMemory(m_device, &allocInfo, nullptr, outMemory);
  vkBindImageMemory(m_device, *outImage, *outMemory, 0);

  VkImageView view = VK_NULL_HANDLE;
  VkImageViewCreateInfo viewInfo{VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO};
  viewInfo.image = *outImage;
  viewInfo.viewType = VK_IMAGE_VIEW_TYPE_2D;
  viewInfo.format = VK_FORMAT_R8G8B8A8_UNORM;
  viewInfo.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  viewInfo.subresourceRange.levelCount = 1;
  viewInfo.subresourceRange.layerCount = 1;
  vkCreateImageView(m_device, &viewInfo, nullptr, &view);

  VkBuffer uploadBuffer = VK_NULL_HANDLE;
  VkDeviceMemory uploadMemory = VK_NULL_HANDLE;

  VkBufferCreateInfo bufInfo{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
  bufInfo.size = imageSize;
  bufInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
  bufInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  vkCreateBuffer(m_device, &bufInfo, nullptr, &uploadBuffer);

  vkGetBufferMemoryRequirements(m_device, uploadBuffer, &memReqs);

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

  allocInfo.allocationSize = memReqs.size;
  allocInfo.memoryTypeIndex = memTypeIndex;
  vkAllocateMemory(m_device, &allocInfo, nullptr, &uploadMemory);
  vkBindBufferMemory(m_device, uploadBuffer, uploadMemory, 0);

  void *data = nullptr;
  vkMapMemory(m_device, uploadMemory, 0, imageSize, 0, &data);
  std::memcpy(data, rgba.constBits(), imageSize);
  vkUnmapMemory(m_device, uploadMemory);

  VkCommandBufferAllocateInfo cmdAlloc{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
  cmdAlloc.commandPool = m_commandPool;
  cmdAlloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  cmdAlloc.commandBufferCount = 1;

  VkCommandBuffer uploadCmdBuffer = VK_NULL_HANDLE;
  vkAllocateCommandBuffers(m_device, &cmdAlloc, &uploadCmdBuffer);

  VkFence uploadFence = VK_NULL_HANDLE;
  VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
  vkCreateFence(m_device, &fenceInfo, nullptr, &uploadFence);

  VkCommandBufferBeginInfo beginInfo{
      VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
  beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
  vkBeginCommandBuffer(uploadCmdBuffer, &beginInfo);

  VkImageMemoryBarrier barrier{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
  barrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
  barrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.image = *outImage;
  barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  barrier.subresourceRange.levelCount = 1;
  barrier.subresourceRange.layerCount = 1;
  barrier.srcAccessMask = 0;
  barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

  vkCmdPipelineBarrier(uploadCmdBuffer, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
                       VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  VkBufferImageCopy copyRegion{};
  copyRegion.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  copyRegion.imageSubresource.layerCount = 1;
  copyRegion.imageExtent = {width, height, 1};

  vkCmdCopyBufferToImage(uploadCmdBuffer, uploadBuffer, *outImage,
                         VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copyRegion);

  barrier.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
  barrier.newLayout = VK_IMAGE_LAYOUT_GENERAL;
  barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

  vkCmdPipelineBarrier(uploadCmdBuffer, VK_PIPELINE_STAGE_TRANSFER_BIT,
                       VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0, nullptr, 0,
                       nullptr, 1, &barrier);

  vkEndCommandBuffer(uploadCmdBuffer);

  VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &uploadCmdBuffer;

  vkQueueSubmit(m_computeQueue, 1, &submitInfo, uploadFence);
  vkWaitForFences(m_device, 1, &uploadFence, VK_TRUE, 1000000000ULL);

  vkDestroyFence(m_device, uploadFence, nullptr);
  vkFreeCommandBuffers(m_device, m_commandPool, 1, &uploadCmdBuffer);
  vkDestroyBuffer(m_device, uploadBuffer, nullptr);
  vkFreeMemory(m_device, uploadMemory, nullptr);

  return view;
}

void XylaRenderer::precompileGraph(const std::shared_ptr<NodeGraph> &graph) {
  ensureInitialized();
  if (graph) {
    getOrCreatePipeline(graph);
  }
}

std::shared_ptr<CachedPipeline>
XylaRenderer::getOrCreatePipeline(const std::shared_ptr<NodeGraph> &graph) {
  // Fall back to Default Passthrough GLSL if graph is null or glslSource is
  // empty
  QString hash;
  CompiledGraphShader compiled;

  if (graph) {
    compiled = graph->compileFusedShader();
  }

  if (compiled.glslSource.isEmpty()) {
    compiled.glslSource = QString::fromUtf8(kDefaultPassthroughGlsl);
    compiled.pushConstants.totalSizeBytes = 0;
    hash = "DefaultPassthroughNV12Shader";
  } else {
    hash = compiled.glslSource;
  }

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
      emit frameRendered(); // Re-trigger render pass so monitor repaints
    }
  });

  return pipeline;
}

bool XylaRenderer::compilePipelineInternal(const CompiledGraphShader &compiled,
                                           CachedPipeline &outPipeline) {
  if (m_device == VK_NULL_HANDLE)
    return false;

  auto spirv = ShaderCompiler::compileGlslToSpirv(compiled.glslSource,
                                                  "NodeGraphShader");
  if (spirv.empty()) {
    XYLA_LOG_ERROR("XylaRenderer", "Failed to compile GLSL shader to SPIR-V!");
    return false;
  }

  VkShaderModuleCreateInfo moduleInfo{
      VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};
  moduleInfo.codeSize = spirv.size() * sizeof(uint32_t);
  moduleInfo.pCode = spirv.data();

  VkShaderModule shaderModule = VK_NULL_HANDLE;
  if (vkCreateShaderModule(m_device, &moduleInfo, nullptr, &shaderModule) !=
      VK_SUCCESS) {
    return false;
  }

  VkDescriptorSetLayoutBinding bindings[3]{};

  // Binding 0: Output frame
  bindings[0].binding = 0;
  bindings[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
  bindings[0].descriptorCount = 1;
  bindings[0].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;

  // Binding 1: Plane Y (R8_UNORM)
  bindings[1].binding = 1;
  bindings[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
  bindings[1].descriptorCount = 1;
  bindings[1].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;

  // Binding 2: Plane UV (RG8_UNORM)
  bindings[2].binding = 2;
  bindings[2].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
  bindings[2].descriptorCount = 1;
  bindings[2].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;

  VkDescriptorSetLayoutCreateInfo layoutCreateInfo{
      VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};
  layoutCreateInfo.bindingCount = 3;
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

// Dispatches node graph compute shader using persistent command buffer & fence
bool XylaRenderer::renderFrame(const std::shared_ptr<NodeGraph> &graph,
                               VkImageView yPlaneView, VkImageView uvPlaneView,
                               uint32_t width, uint32_t height,
                               const QVariantMap &pushConstantValues) {
  ensureInitialized();
  std::lock_guard<std::mutex> lock(m_renderMutex);
  if (!m_initialized.load() || m_device == VK_NULL_HANDLE ||
      yPlaneView == VK_NULL_HANDLE || uvPlaneView == VK_NULL_HANDLE)
    return false;

  auto cachedPipeline = getOrCreatePipeline(graph);
  if (!cachedPipeline || !cachedPipeline->isReady.load())
    return false;

  ensureOutputResources(width, height);

  // 1. Wait for and reset persistent render fence
  vkWaitForFences(m_device, 1, &m_renderFence, VK_TRUE, UINT64_MAX);
  vkResetFences(m_device, 1, &m_renderFence);

  // 2. Reset persistent render command buffer
  vkResetCommandBuffer(m_renderCmdBuffer, 0);

  // 3. Update Descriptor Set
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

  VkDescriptorImageInfo yImageInfo{};
  yImageInfo.sampler = m_defaultSampler;
  yImageInfo.imageView = yPlaneView;
  yImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

  VkDescriptorImageInfo uvImageInfo{};
  uvImageInfo.sampler = m_defaultSampler;
  uvImageInfo.imageView = uvPlaneView;
  uvImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;

  VkWriteDescriptorSet writeSets[3]{};

  // Binding 0: Storage Output Frame
  writeSets[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
  writeSets[0].dstSet = descriptorSet;
  writeSets[0].dstBinding = 0;
  writeSets[0].descriptorCount = 1;
  writeSets[0].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
  writeSets[0].pImageInfo = &outputImageInfo;

  // Binding 1: Y Plane Sampler
  writeSets[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
  writeSets[1].dstSet = descriptorSet;
  writeSets[1].dstBinding = 1;
  writeSets[1].descriptorCount = 1;
  writeSets[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
  writeSets[1].pImageInfo = &yImageInfo;

  // Binding 2: UV Plane Sampler
  writeSets[2].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
  writeSets[2].dstSet = descriptorSet;
  writeSets[2].dstBinding = 2;
  writeSets[2].descriptorCount = 1;
  writeSets[2].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
  writeSets[2].pImageInfo = &uvImageInfo;

  vkUpdateDescriptorSets(m_device, 3, writeSets, 0, nullptr);

  // 4. Record Render Commands into persistent command buffer
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

  // 5. Submit to Queue with persistent fence
  VkSubmitInfo submitInfo{VK_STRUCTURE_TYPE_SUBMIT_INFO};
  submitInfo.commandBufferCount = 1;
  submitInfo.pCommandBuffers = &m_renderCmdBuffer;

  vkQueueSubmit(m_computeQueue, 1, &submitInfo, m_renderFence);
  vkWaitForFences(m_device, 1, &m_renderFence, VK_TRUE, UINT64_MAX);

  vkFreeDescriptorSets(m_device, m_descriptorPool, 1, &descriptorSet);

  // 6. Zero-Allocation QImage Staging Readback (std::memcpy directly into
  // bits())
  void *mapped = nullptr;
  vkMapMemory(m_device, m_stagingMemory, 0, width * height * 4, 0, &mapped);
  if (mapped) {
    std::lock_guard<std::mutex> imgLock(m_imageMutex);

    if (m_latestQImage.width() != static_cast<int>(width) ||
        m_latestQImage.height() != static_cast<int>(height) ||
        m_latestQImage.format() != QImage::Format_RGBA8888) {
      m_latestQImage = QImage(width, height, QImage::Format_RGBA8888);
    }

    std::memcpy(m_latestQImage.bits(), mapped, width * height * 4);
    vkUnmapMemory(m_device, m_stagingMemory);
  }

  emit frameRendered();
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

void XylaRenderer::clearLatestFrame() {
  std::lock_guard<std::mutex> lock(m_imageMutex);
  m_latestQImage = QImage();
  emit frameRendered();
}

bool XylaRenderer::isInitialized() const noexcept {
  return m_initialized.load();
}

VkDevice XylaRenderer::device() const noexcept { return m_device; }

QImage XylaRenderer::latestFrameImage() const {
  std::lock_guard<std::mutex> lock(m_imageMutex);
  return m_latestQImage;
}

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

  if (m_defaultSampler != VK_NULL_HANDLE) {
    vkDestroySampler(m_device, m_defaultSampler, nullptr);
    m_defaultSampler = VK_NULL_HANDLE;
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
