#pragma once

#include "core/render/nodeGraph.hpp"
#include <QImage>

#pragma Q_MOC_INCLUDE(<QImage>)

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
  VkPipeline pipeline{VK_NULL_HANDLE};
  VkPipelineLayout pipelineLayout{VK_NULL_HANDLE};
  VkDescriptorSetLayout descriptorLayout{VK_NULL_HANDLE};
  PushConstantLayout pushConstantLayout;
  std::atomic<bool> isReady{false};
};

class XylaRenderer : public QObject {
  Q_OBJECT

public:
  static XylaRenderer &instance() {
    static XylaRenderer instance;
    return instance;
  }

  void initVulkanContext(VkInstance instance, VkPhysicalDevice physicalDevice,
                         VkDevice device, VkQueue computeQueue);
  void ensureInitialized();

  [[nodiscard]] bool isInitialized() const noexcept;
  [[nodiscard]] VkDevice device() const noexcept;

  void precompileGraph(const std::shared_ptr<NodeGraph> &graph);

  VkImageView allocateAndUploadTexture(const QImage &image, VkImage *outImage,
                                       VkDeviceMemory *outMemory);

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

  // Single clip render (for backwards compatibility)
  bool renderFrame(const std::shared_ptr<NodeGraph> &graph,
                   VkImageView yPlaneView, VkImageView uvPlaneView,
                   uint32_t width, uint32_t height,
                   const QVariantMap &pushConstantValues);

  // Multi-track composited render
  bool renderFrame(const std::vector<RenderLayer> &layers, uint32_t width,
                   uint32_t height);

  [[nodiscard]] QImage latestFrameImage() const;
  void clearLatestFrame();

  void cleanup();

signals:
  void frameRendered();

private:
  XylaRenderer() = default;
  ~XylaRenderer() override;

  XylaRenderer(const XylaRenderer &) = delete;
  XylaRenderer &operator=(const XylaRenderer &) = delete;

  std::shared_ptr<CachedPipeline>
  getOrCreatePipeline(const std::shared_ptr<NodeGraph> &graph);
  bool compilePipelineInternal(const CompiledGraphShader &compiled,
                               CachedPipeline &outPipeline);
  void ensureOutputResources(uint32_t width, uint32_t height);
  void updatePushConstants(VkCommandBuffer cmdBuffer, VkPipelineLayout layout,
                           const PushConstantLayout &layoutInfo,
                           const QVariantMap &values);

  mutable std::mutex m_renderMutex;
  mutable std::mutex m_imageMutex;

  VkInstance m_instance{VK_NULL_HANDLE};
  VkPhysicalDevice m_physicalDevice{VK_NULL_HANDLE};
  VkDevice m_device{VK_NULL_HANDLE};
  VkQueue m_computeQueue{VK_NULL_HANDLE};

  VkCommandPool m_commandPool{VK_NULL_HANDLE};
  VkCommandBuffer m_renderCmdBuffer{VK_NULL_HANDLE};
  VkFence m_renderFence{VK_NULL_HANDLE};

  VkDescriptorPool m_descriptorPool{VK_NULL_HANDLE};
  VkSampler m_defaultSampler{VK_NULL_HANDLE};

  VkImage m_outputImage{VK_NULL_HANDLE};
  VkDeviceMemory m_outputMemory{VK_NULL_HANDLE};
  VkImageView m_outputImageView{VK_NULL_HANDLE};

  VkBuffer m_stagingBuffer{VK_NULL_HANDLE};
  VkDeviceMemory m_stagingMemory{VK_NULL_HANDLE};

  uint32_t m_outputWidth{0};
  uint32_t m_outputHeight{0};

  QImage m_latestQImage;
  std::atomic<bool> m_initialized{false};

  std::unordered_map<QString, std::shared_ptr<CachedPipeline>> m_pipelineCache;
};

} // namespace xyla::render
