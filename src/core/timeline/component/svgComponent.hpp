#pragma once

#include "clipComponent.hpp"
#include "core/animation/animProperty.hpp"
#include "core/vector/svg/svgDocument.hpp"
#include <QString>

namespace xyla {

class SvgComponent : public ClipComponent {
public:
  SvgComponent();

  [[nodiscard]] std::unique_ptr<ClipComponent> clone() const override;

  [[nodiscard]] ComponentKind kind() const noexcept override {
    return ComponentKind::VideoModifier;
  }

  [[nodiscard]] QString componentId() const noexcept override {
    return QStringLiteral("svg");
  }

  [[nodiscard]] QString displayName() const override {
    return QStringLiteral("Vector Graphic");
  }

  [[nodiscard]] anim::AnimProperty *
  findProperty(const QString &propertyId) override;
  [[nodiscard]] const anim::AnimProperty *
  findProperty(const QString &propertyId) const override;

  void
  collectChannelInfo(const QString &clipId, int64_t clipStartFrame,
                     int64_t relPlayheadFrame,
                     std::vector<anim::AnimChannelInfo> &out) const override;

  [[nodiscard]] QJsonObject serialize() const override;
  void deserialize(const QJsonObject &obj) override;

  void setSourcePath(const QString &path);
  [[nodiscard]] const QString &sourcePath() const noexcept {
    return m_sourcePath;
  }
  [[nodiscard]] const vector::SvgDocument &document() const noexcept {
    return m_document;
  }

  anim::AnimProperty trimStart{0.0f};
  anim::AnimProperty trimEnd{1.0f};
  anim::AnimProperty trimOffset{0.0f};

  anim::AnimProperty strokeWidthOverride{-1.0f};

private:
  QString m_sourcePath;
  vector::SvgDocument m_document;
};

} // namespace xyla
