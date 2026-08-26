#pragma once

#include "nodeGraph.hpp"
#include <QImage>
#include <QObject>
#include <atomic>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vector>
#include <vulkan/vulkan.h>

namespace xyla::render {

struct CachedPipeline {
  VkPipeline pipeline{VK_NULL_HANDLE};
  VkPipelineLayout pipelineLayout{VK_NULL_HANDLE};
  VkDescriptorSetLayout descriptorLayout{VK_NULL_HANDLE};
  PushConstantLayout pushConstantLayout;
  std::atomic<bool> isReady{false};
};

struct RingTextureSlot {
  VkImage image{VK_NULL_HANDLE};
  VkDeviceMemory memory{VK_NULL_HANDLE};
  VkImageView view{VK_NULL_HANDLE};
};

class XylaRenderer : public QObject {
  Q_OBJECT

public:
  static XylaRenderer &instance() {
    static XylaRenderer renderer;
    return renderer;
  }

  void initVulkanContext(VkInstance instance, VkPhysicalDevice physicalDevice,
                         VkDevice device, VkQueue computeQueue);

  bool renderFrame(const std::shared_ptr<NodeGraph> &graph,
                   VkImageView inputTextureView, uint32_t width,
                   uint32_t height, const QVariantMap &pushConstantValues);

  void updatePushConstants(VkCommandBuffer cmdBuffer, VkPipelineLayout layout,
                           const PushConstantLayout &layoutInfo,
                           const QVariantMap &values);

  VkImageView uploadTexture(const QImage &image, uint64_t frameIndex);
  void precompileGraph(const std::shared_ptr<NodeGraph> &graph);
  void clearLatestFrame();

  [[nodiscard]] bool isInitialized() const noexcept;
  [[nodiscard]] VkDevice device() const noexcept;
  [[nodiscard]] VkImageView inputImageView(size_t index = 0) const noexcept;
  [[nodiscard]] QImage latestFrameImage() const;

private:
  XylaRenderer() = default;
  ~XylaRenderer() override;

  void ensureInitialized();
  void ensureRingResources(uint32_t width, uint32_t height);
  void ensureOutputResources(uint32_t width, uint32_t height);
  std::shared_ptr<CachedPipeline>
  getOrCreatePipeline(const std::shared_ptr<NodeGraph> &graph);
  bool compilePipelineInternal(const CompiledGraphShader &compiled,
                               CachedPipeline &outPipeline);
  void cleanup();

  VkInstance m_instance{VK_NULL_HANDLE};
  VkPhysicalDevice m_physicalDevice{VK_NULL_HANDLE};
  VkDevice m_device{VK_NULL_HANDLE};
  VkQueue m_computeQueue{VK_NULL_HANDLE};
  VkCommandPool m_commandPool{VK_NULL_HANDLE};
  VkDescriptorPool m_descriptorPool{VK_NULL_HANDLE};
  VkSampler m_defaultSampler{VK_NULL_HANDLE};

  VkCommandBuffer m_renderCmdBuffer{VK_NULL_HANDLE};
  VkCommandBuffer m_uploadCmdBuffer{VK_NULL_HANDLE};
  VkFence m_renderFence{VK_NULL_HANDLE};
  VkFence m_uploadFence{VK_NULL_HANDLE};

  static constexpr size_t kRingBufferSize = 32;
  std::vector<RingTextureSlot> m_ringBuffer;
  uint32_t m_ringWidth{0};
  uint32_t m_ringHeight{0};

  VkImage m_outputImage{VK_NULL_HANDLE};
  VkDeviceMemory m_outputMemory{VK_NULL_HANDLE};
  VkImageView m_outputImageView{VK_NULL_HANDLE};
  uint32_t m_outputWidth{0};
  uint32_t m_outputHeight{0};

  VkBuffer m_stagingBuffer{VK_NULL_HANDLE};
  VkDeviceMemory m_stagingMemory{VK_NULL_HANDLE};

  mutable std::mutex m_imageMutex;
  QImage m_latestQImage;

  std::atomic<bool> m_initialized{false};
  mutable std::mutex m_renderMutex;
  mutable std::mutex m_ringMutex;

  std::unordered_map<QString, std::shared_ptr<CachedPipeline>> m_pipelineCache;
};

} // namespace xyla::render
