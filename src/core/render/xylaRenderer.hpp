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

  // Single-pass Vulkan device context handshake with Qt Quick Scene Graph
  void initVulkanContext(VkInstance instance, VkPhysicalDevice physicalDevice,
                         VkDevice device, VkQueue computeQueue);

  void ensureInitialized();

  // Pure GPU Compute Compositing Passes
  bool renderFrame(const std::vector<RenderLayer> &layers, uint32_t width,
                   uint32_t height);

  bool renderFrame(const std::shared_ptr<NodeGraph> &graph,
                   VkImageView yPlaneView, VkImageView uvPlaneView,
                   uint32_t width, uint32_t height,
                   const QVariantMap &pushConstantValues = {});

  void precompileGraph(const std::shared_ptr<NodeGraph> &graph);

  // VRAM Texture Allocations & Uploads
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

  VkImageView createImageViewForImage(VkImage image, VkFormat format);

  // Atomic Snapshot Read (Prevents torn image/dimension state in QML surface)
  [[nodiscard]] OutputSnapshot currentOutputSnapshot() const noexcept;

  // GPU Handles & Context Status
  [[nodiscard]] VkImage currentOutputVkImage() const noexcept;
  [[nodiscard]] uint32_t currentWidth() const noexcept;
  [[nodiscard]] uint32_t currentHeight() const noexcept;

  [[nodiscard]] bool isInitialized() const noexcept;
  [[nodiscard]] VkPhysicalDevice physicalDevice() const noexcept;
  [[nodiscard]] VkDevice device() const noexcept;

  void cleanup();

signals:
  void frameRendered();

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

  mutable std::mutex m_renderMutex;
  std::atomic<bool> m_initialized{false};

  VkInstance m_instance{VK_NULL_HANDLE};
  VkPhysicalDevice m_physicalDevice{VK_NULL_HANDLE};
  VkDevice m_device{VK_NULL_HANDLE};
  VkQueue m_computeQueue{VK_NULL_HANDLE};
  VkCommandPool m_commandPool{VK_NULL_HANDLE};
  VkSampler m_defaultSampler{VK_NULL_HANDLE};

  FrameSlot m_frameSlots[kMaxInFlightFrames];
  size_t m_currentFrameSlot{0};

  std::unordered_map<QString, std::shared_ptr<CachedPipeline>> m_pipelineCache;
};

} // namespace xyla::render
