#pragma once

#include "core/timeline/component/transformComponent.hpp"
#include "nodeGraph.hpp"

#include <QObject>
#include <QVariantMap>
#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vector>
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_core.h>

namespace xyla::render {

static constexpr uint32_t MAX_DESCRIPTOR_SETS_PER_FRAME = 256;
static constexpr uint32_t FRAME_COMBINED_SAMPLER_BUDGET = 1024;
static constexpr uint32_t FRAME_STORAGE_IMAGE_BUDGET = 256;
static constexpr uint32_t FRAME_STORAGE_BUFFER_BUDGET = 256;
static constexpr VkFormat CANVAS_FORMAT = VK_FORMAT_R8G8B8A8_UNORM;

struct RenderLayer {
  std::shared_ptr<NodeGraph> graph;
  VkImageView yView{VK_NULL_HANDLE};
  VkImageView uvView{VK_NULL_HANDLE};
  VkImageView rgbaView{VK_NULL_HANDLE};
  const anim::AnimationManager *animMgr{nullptr};
  FrameIndex frame{0};
  // intrinsic
  TransformHandles transformHandles;
};

struct CachedPipeline {
  VkDescriptorSetLayout descriptorLayout{VK_NULL_HANDLE};
  VkPipelineLayout pipelineLayout{VK_NULL_HANDLE};
  VkPipeline pipeline{VK_NULL_HANDLE};
  PushConstantLayout pushConstantLayout;
  std::atomic<bool> isReady{false};
};

struct OutputSnapshot {
  VkImage image{VK_NULL_HANDLE};
  uint32_t width{0};
  uint32_t height{0};
};

class XylaRenderer : public QObject {
  Q_OBJECT

public:
  static constexpr size_t kMaxInFlightFrames = 3;

  static XylaRenderer &instance();
  ~XylaRenderer() override;

  void initVulkanContext(VkInstance instance, VkPhysicalDevice physicalDevice,
                         VkDevice device, VkQueue computeQueue,
                         uint32_t queueFamilyIndex, uint32_t queueIndex);
  void ensureInitialized_NoLock();

  // Multi-layer Rendering (RenderContext & Full-Res Overload)
  bool renderFrame(const std::vector<RenderLayer> &layers,
                   const RenderContext &ctx);
  bool renderFrame(const std::vector<RenderLayer> &layers, uint32_t width,
                   uint32_t height);
  bool renderFrame(const std::shared_ptr<NodeGraph> &graph,
                   VkImageView yPlaneView, VkImageView uvPlaneView,
                   uint32_t width, uint32_t height,
                   const QVariantMap &overrideValues = {});

  // Single Clip Rendering (RenderContext & Full-Res Overload)
  bool renderClipFrame(VkImageView yView, VkImageView uvView,
                       const RenderContext &ctx,
                       const std::shared_ptr<NodeGraph> &graph = nullptr,
                       VkImageView rgbaView = VK_NULL_HANDLE);
  bool renderClipFrame(VkImageView yView, VkImageView uvView, uint32_t width,
                       uint32_t height,
                       const std::shared_ptr<NodeGraph> &graph = nullptr,
                       VkImageView rgbaView = VK_NULL_HANDLE);

  void precompileGraph(const std::shared_ptr<NodeGraph> &graph);

  // Texture Allocation & Uploads
  bool allocateAndUploadYuvTextures(const uint8_t *yData, int yPitch,
                                    const uint8_t *uvData, int uvPitch,
                                    uint32_t width, uint32_t height,
                                    VkImage *outYImage, VkDeviceMemory *outYMem,
                                    VkImageView *outYView, VkImage *outUVImage,
                                    VkDeviceMemory *outUVMem,
                                    VkImageView *outUVView);

  bool uploadToExistingYuvTextures(const uint8_t *yData, int yPitch,
                                   const uint8_t *uvData, int uvPitch,
                                   uint32_t width, uint32_t height,
                                   VkImage yImage, VkImage uvImage);

  bool allocateRgbaTexture(uint32_t width, uint32_t height, VkImage *outImage,
                           VkDeviceMemory *outMem, VkImageView *outView);

  bool uploadToExistingRgbaTexture(const uint8_t *rgbaData, int pitch,
                                   uint32_t width, uint32_t height,
                                   VkImage rgbaImage);

  VkImageView createImageViewForImage(VkImage image, VkFormat format);

  [[nodiscard]] OutputSnapshot currentOutputSnapshot() const noexcept;
  [[nodiscard]] OutputSnapshot currentClipSnapshot() const noexcept;
  [[nodiscard]] VkImage currentOutputVkImage() const noexcept;
  [[nodiscard]] uint32_t currentWidth() const noexcept;
  [[nodiscard]] uint32_t currentHeight() const noexcept;

  [[nodiscard]] bool isInitialized() const noexcept;
  [[nodiscard]] VkPhysicalDevice physicalDevice() const noexcept;
  [[nodiscard]] VkDevice device() const noexcept;
  [[nodiscard]] VkQueue computeQueue() const noexcept { return m_computeQueue; }
  [[nodiscard]] VkCommandPool commandPool() const noexcept {
    return m_commandPool;
  }

  void cleanup();

signals:
  void frameRendered();
  void clipFrameRendered();
  void vulkanContextReady();

private:
  mutable std::mutex m_queueMutex;
  XylaRenderer() = default;
  Q_DISABLE_COPY_MOVE(XylaRenderer)

  size_t getFormatBytesPerPixel(VkFormat format) const;

  template <typename F>
  bool allocateAndBindResource(const VkMemoryRequirements &memReqs,
                               VkMemoryPropertyFlags properties,
                               VkDeviceMemory &outMemory, F &&bindCallback);
  void cleanupInternal();
  VkPhysicalDeviceMemoryProperties m_deviceMemoryProperties{};
  // Core Memory Helpers
  uint32_t findMemoryType(uint32_t typeFilter,
                          VkMemoryPropertyFlags properties) const;

  bool createBuffer(VkDeviceSize size, VkBufferUsageFlags usage,
                    VkMemoryPropertyFlags properties, VkBuffer &outBuffer,
                    VkDeviceMemory &outMemory);

  bool createImage(uint32_t width, uint32_t height, VkFormat format,
                   VkImageTiling tiling, VkImageUsageFlags usage,
                   VkMemoryPropertyFlags properties, VkImage &outImage,
                   VkDeviceMemory &outMemory);

  bool uploadPixelsToImage(VkImage image, uint32_t width, uint32_t height,
                           VkFormat format, const uint8_t *srcData, int pitch);

  std::shared_ptr<CachedPipeline>
  getOrCreatePipeline(const std::shared_ptr<NodeGraph> &graph);

  bool compilePipelineInternal(const CompiledGraphShader &compiled,
                               CachedPipeline &outPipeline);

  void uploadParametersToBuffer(uint8_t *destBuffer,
                                const PushConstantLayout &layoutInfo,
                                const RenderLayer &layer);
  struct FrameSlot {
    VkCommandBuffer cmdBuffer{VK_NULL_HANDLE};
    VkFence fence{VK_NULL_HANDLE};
    VkDescriptorPool descriptorPool{VK_NULL_HANDLE};

    VkImage outputImage{VK_NULL_HANDLE};
    VkDeviceMemory outputMemory{VK_NULL_HANDLE};
    VkImageView outputImageView{VK_NULL_HANDLE};

    VkBuffer paramBuffer{VK_NULL_HANDLE};
    VkDeviceMemory paramMemory{VK_NULL_HANDLE};
    uint8_t *mappedParamData{nullptr};
    size_t paramBufferSize{0};

    uint32_t width{0};
    uint32_t height{0};
  };

  void destroySlotResources(FrameSlot &slot);
  bool ensureSlotOutputResources(FrameSlot &slot, uint32_t width,
                                 uint32_t height);
  bool ensureSlotParamBuffer(FrameSlot &slot, size_t requiredSize);
  void destroySlotParamBuffer(FrameSlot &slot);

  bool ensureDummyResources();
  void destroyDummyResources();

  mutable std::recursive_mutex m_renderMutex;
  std::atomic<bool> m_initialized{false};

  VkInstance m_instance{VK_NULL_HANDLE};
  VkPhysicalDevice m_physicalDevice{VK_NULL_HANDLE};
  VkDevice m_device{VK_NULL_HANDLE};
  VkQueue m_computeQueue{VK_NULL_HANDLE};
  VkCommandPool m_commandPool{VK_NULL_HANDLE};
  VkSampler m_defaultSampler{VK_NULL_HANDLE};

  VkImage m_dummyImage{VK_NULL_HANDLE};
  VkDeviceMemory m_dummyMemory{VK_NULL_HANDLE};
  VkImageView m_dummyView{VK_NULL_HANDLE};

  VkBuffer m_dummyParamBuffer{VK_NULL_HANDLE};
  VkDeviceMemory m_dummyParamMemory{VK_NULL_HANDLE};

  FrameSlot m_frameSlots[kMaxInFlightFrames];
  FrameSlot m_clipSlot;
  size_t m_currentFrameSlot{0};

  uint32_t m_queueFamilyIndex = UINT32_MAX;
  uint32_t m_queueIndex = UINT32_MAX;

  std::unordered_map<uint64_t, std::shared_ptr<CachedPipeline>> m_pipelineCache;
};

} // namespace xyla::render
