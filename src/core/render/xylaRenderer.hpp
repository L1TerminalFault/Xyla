#pragma once

#include "nodeGraph.hpp"

#include <QObject>
#include <QVariantMap>
#include <atomic>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vector>
#include <vulkan/vulkan.h>

namespace xyla::render {

struct RenderLayer {
  std::shared_ptr<NodeGraph> graph;
  VkImageView yView{VK_NULL_HANDLE};
  VkImageView uvView{VK_NULL_HANDLE};
  VkImageView rgbaView{VK_NULL_HANDLE};
  QVariantMap pushConstantValues;
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
                         VkDevice device, VkQueue computeQueue);

  void ensureInitialized();

  bool renderFrame(const std::vector<RenderLayer> &layers, uint32_t width,
                   uint32_t height);

  bool renderFrame(const std::shared_ptr<NodeGraph> &graph,
                   VkImageView yPlaneView, VkImageView uvPlaneView,
                   uint32_t width, uint32_t height,
                   const QVariantMap &pushConstantValues = {});

  void precompileGraph(const std::shared_ptr<NodeGraph> &graph);

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

  VkImageView createImageViewForImage(VkImage image, VkFormat format);

  [[nodiscard]] OutputSnapshot currentOutputSnapshot() const noexcept;

  [[nodiscard]] VkImage currentOutputVkImage() const noexcept;
  [[nodiscard]] uint32_t currentWidth() const noexcept;
  [[nodiscard]] uint32_t currentHeight() const noexcept;

  [[nodiscard]] bool isInitialized() const noexcept;
  [[nodiscard]] VkPhysicalDevice physicalDevice() const noexcept;
  [[nodiscard]] VkDevice device() const noexcept;

  void cleanup();
  [[nodiscard]] OutputSnapshot currentClipSnapshot() const noexcept;
  bool renderClipFrame(VkImageView yView, VkImageView uvView, uint32_t width,
                       uint32_t height,
                       const std::shared_ptr<NodeGraph> &graph = nullptr,
                       VkImageView rgbaView = VK_NULL_HANDLE);
  bool uploadToExistingRgbaTexture(const uint8_t *rgbaData, int pitch,
                                   uint32_t width, uint32_t height,
                                   VkImage rgbaImage);
  [[nodiscard]] VkQueue computeQueue() const noexcept { return m_computeQueue; }
  [[nodiscard]] VkCommandPool commandPool() const noexcept {
    return m_commandPool;
  }

signals:
  void frameRendered();
  void clipFrameRendered();

private:
  XylaRenderer() = default;
  Q_DISABLE_COPY_MOVE(XylaRenderer)

  void cleanupInternal();

  std::shared_ptr<CachedPipeline>
  getOrCreatePipeline(const std::shared_ptr<NodeGraph> &graph);

  bool compilePipelineInternal(const CompiledGraphShader &compiled,
                               CachedPipeline &outPipeline);

  void updatePushConstants(VkCommandBuffer cmdBuffer, VkPipelineLayout layout,
                           const PushConstantLayout &layoutInfo,
                           const QVariantMap &values);

  struct FrameSlot {
    VkCommandBuffer cmdBuffer{VK_NULL_HANDLE};
    VkFence fence{VK_NULL_HANDLE};
    VkDescriptorPool descriptorPool{VK_NULL_HANDLE};

    VkImage outputImage{VK_NULL_HANDLE};
    VkDeviceMemory outputMemory{VK_NULL_HANDLE};
    VkImageView outputImageView{VK_NULL_HANDLE};

    uint32_t width{0};
    uint32_t height{0};
  };

  void destroySlotResources(FrameSlot &slot);
  void ensureSlotOutputResources(FrameSlot &slot, uint32_t width,
                                 uint32_t height);

  void ensureDummyResources();
  void destroyDummyResources();

  mutable std::mutex m_renderMutex;
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

  FrameSlot m_frameSlots[kMaxInFlightFrames];
  FrameSlot m_clipSlot;
  size_t m_currentFrameSlot{0};

  std::unordered_map<QString, std::shared_ptr<CachedPipeline>> m_pipelineCache;
};

} // namespace xyla::render
