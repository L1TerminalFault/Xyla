#pragma once

#include "core/render/node.hpp"

namespace xyla::render {

enum class AlphaMode : uint8_t { Premultiplied = 0, Straight, IgnoreAlpha };

enum class ColorSpace : uint8_t {
  Linear = 0,
  sRGB,
  Rec709,
  Rec2020,
  LogC3,
  ACEScg
};

enum class OutOfRangeMode : uint8_t { Hold = 0, Black, Loop, Error };

class VideoInNode : public Node {
public:
  inline static const QString StaticTypeName = QStringLiteral("VideoInNode");
  inline static const QString StaticDefaultName = QStringLiteral("Video In");

  explicit VideoInNode(QString id, QString name = StaticDefaultName,
                       QString assetId = {});

  [[nodiscard]] const QString &assetId() const noexcept { return m_assetId; }
  void setAssetId(QString assetId) noexcept { m_assetId = std::move(assetId); }

  [[nodiscard]] AlphaMode alphaMode() const noexcept { return m_alphaMode; }
  void setAlphaMode(AlphaMode mode) noexcept { m_alphaMode = mode; }

  [[nodiscard]] ColorSpace colorSpace() const noexcept { return m_colorSpace; }
  void setColorSpace(ColorSpace cs) noexcept { m_colorSpace = cs; }

  [[nodiscard]] OutOfRangeMode outOfRangeMode() const noexcept {
    return m_outOfRangeMode;
  }
  void setOutOfRangeMode(OutOfRangeMode mode) noexcept {
    m_outOfRangeMode = mode;
  }

  [[nodiscard]] int64_t timeOffset() const noexcept { return m_timeOffset; }
  void setTimeOffset(int64_t offset) noexcept { m_timeOffset = offset; }

  [[nodiscard]] float playbackSpeed() const noexcept { return m_playbackSpeed; }
  void setPlaybackSpeed(float speed) noexcept { m_playbackSpeed = speed; }

  [[nodiscard]] int32_t nativeWidth() const noexcept { return m_nativeWidth; }
  [[nodiscard]] int32_t nativeHeight() const noexcept { return m_nativeHeight; }
  void setNativeDimensions(int32_t width, int32_t height) noexcept {
    m_nativeWidth = width;
    m_nativeHeight = height;
  }

  [[nodiscard]] QString defaultName() const noexcept override {
    return StaticDefaultName;
  }
  [[nodiscard]] QString typeName() const noexcept override {
    return StaticTypeName;
  }
  [[nodiscard]] QString editorCategory() const override {
    return QStringLiteral("Image");
  }
  [[nodiscard]] QString editorIcon() const override {
    return QStringLiteral("movie");
  }

  [[nodiscard]] std::vector<QString> declaredSamplerNames() const override;

  [[nodiscard]] PixelRect computeRegionOfDefinition(
      const std::unordered_map<QString, PixelRect> &inputRods,
      const RenderContext &ctx) const override;

  [[nodiscard]] QString generateGlslUniforms() const override;
  [[nodiscard]] QString
  generateGlslCode(const std::unordered_map<QString, QString> &inputVars,
                   const QString &outputVar) const override;

  [[nodiscard]] QVariantMap
  toVariantMap(FrameIndex currentFrame,
               const anim::AnimationManager *animMgr) const override;

  [[nodiscard]] QJsonObject serialize() const override;
  bool deserialize(const QJsonObject &json) override;

private:
  QString m_assetId;
  AlphaMode m_alphaMode{AlphaMode::Premultiplied};
  ColorSpace m_colorSpace{ColorSpace::Rec709};
  OutOfRangeMode m_outOfRangeMode{OutOfRangeMode::Hold};

  int64_t m_timeOffset{0};
  float m_playbackSpeed{1.0f};

  int32_t m_nativeWidth{1920};
  int32_t m_nativeHeight{1080};
};

} // namespace xyla::render
