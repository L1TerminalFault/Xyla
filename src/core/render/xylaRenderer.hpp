#pragma once

#include "nodeGraph.hpp"
#include <QObject>
#include <memory>
#include <mutex>
#include <unordered_map>
#include <vulkan/vulkan.h>

namespace xyla::render {

struct CachedPipeline {
  VkPipeline pipeline{VK_NULL_HANDLE};
  VkPipelineLayout pipelineLayout{VK_NULL_HANDLE};
  PushConstantLayout pushConstantLayout;
  bool isReady{false};
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
                   VkImageView outputTextureView, uint32_t width,
                   uint32_t height, const QVariantMap &pushConstantValues);

  void updatePushConstants(VkCommandBuffer cmdBuffer, VkPipelineLayout layout,
                           const PushConstantLayout &layoutInfo,
                           const QVariantMap &values);

  [[nodiscard]] bool isInitialized() const noexcept { return m_initialized; }

private:
  XylaRenderer() = default;
  ~XylaRenderer() override;

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

  bool m_initialized{false};
  std::mutex m_renderMutex;

  std::unordered_map<QString, std::shared_ptr<CachedPipeline>> m_pipelineCache;
};

} // namespace xyla::render
