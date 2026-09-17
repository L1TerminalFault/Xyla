#pragma once

#include "clipComponent.hpp"
#include "core/animation/animProperty.hpp"
#include "core/vector/text/textAnimator.hpp"
#include "core/vector/text/textLayout.hpp"
#include <QString>
#include <vector>

namespace xyla {

enum class StrokePosition { Center = 0, Outer = 1, Inner = 2 };

class TextComponent : public ClipComponent {
public:
  TextComponent();

  bool setProperty(const QString &propertyId, const QVariant &value,
                   FrameIndex localFrame) override;

  [[nodiscard]] std::unique_ptr<ClipComponent> clone() const override;

  [[nodiscard]] ComponentKind kind() const noexcept override {
    return ComponentKind::GeneratorText;
  }

  [[nodiscard]] QString componentId() const noexcept override {
    return QStringLiteral("text");
  }

  [[nodiscard]] QString displayName() const override {
    return QStringLiteral("Title & Text");
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

  QString text{QStringLiteral("Sample Title")};
  QString fontFamily{QStringLiteral("Inter")};
  vector::TextAlignment alignment{vector::TextAlignment::Center};

  anim::AnimProperty fontSize{72.0f};
  anim::AnimProperty tracking{0.0f};
  anim::AnimProperty lineSpacing{1.2f};

  anim::AnimProperty fillRed{1.0f};
  anim::AnimProperty fillGreen{1.0f};
  anim::AnimProperty fillBlue{1.0f};
  anim::AnimProperty fillAlpha{1.0f};

  // --- STROKE PROPERTIES ---
  StrokePosition strokePosition{StrokePosition::Center}; // <--- NEW PROPERTY
  anim::AnimProperty strokeWidth{0.0f};
  anim::AnimProperty strokeRed{0.0f};
  anim::AnimProperty strokeGreen{0.0f};
  anim::AnimProperty strokeBlue{0.0f};
  anim::AnimProperty strokeAlpha{1.0f};

  anim::AnimProperty trimStart{0.0f};
  anim::AnimProperty trimEnd{1.0f};
  anim::AnimProperty trimOffset{0.0f};

  std::vector<vector::TextAnimator> animators;
};

} // namespace xyla
