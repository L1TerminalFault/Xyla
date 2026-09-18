#pragma once

#include "core/animation/animProperty.hpp"
#include "core/timeline/component/clipComponent.hpp"
#include "core/vector/text/textAnimator.hpp"
#include <QColor>
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <vector>

namespace xyla {

enum class StrokePosition : int { Center = 0, Outer = 1, Inner = 2 };

enum class TextHAlignment : int {
  Left = 0,
  Center = 1,
  Right = 2,
  Justify = 3
};

enum class TextVAlignment : int { Top = 0, Middle = 1, Bottom = 2 };

enum class GradientType : int { None = 0, Linear = 1, Radial = 2 };

enum class GradientScope : int {
  WholeText = 0,
  PerLine = 1,
  PerWord = 2,
  PerCharacter = 3
};

struct GradientStop {
  float position{0.0f}; // 0.0 -> 1.0
  QColor color{Qt::white};

  QJsonObject serialize() const;
  static GradientStop deserialize(const QJsonObject &obj);
};

struct GradientConfig {
  GradientType type{GradientType::None};
  GradientScope scope{GradientScope::WholeText};
  float angleDegrees{0.0f}; // 0 = Left->Right, 90 = Top->Bottom
  float startX{0.0f};       // Normalized coordinates or focal offsets
  float startY{0.0f};
  float endX{1.0f};
  float endY{0.0f};
  float radialRadius{0.5f};
  std::vector<GradientStop> stops;

  QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);
};

class TextComponent : public ClipComponent {
public:
  TextComponent();
  ~TextComponent() override = default;

  [[nodiscard]] std::unique_ptr<ClipComponent> clone() const override;
  [[nodiscard]] ComponentKind kind() const noexcept override {
    return ComponentKind::GeneratorText;
  }
  [[nodiscard]] QString componentId() const noexcept override {
    return QStringLiteral("text");
  }
  [[nodiscard]] QString displayName() const override {
    return QStringLiteral("Text & Title");
  }

  bool setProperty(const QString &propertyId, const QVariant &value,
                   FrameIndex localFrame) override;

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

  // --- Content & Font Core ---
  QString text{QStringLiteral("Title")};
  QString fontFamily{QStringLiteral("Inter")};
  int fontWeight{400}; // 100 to 900 (400 = Regular, 700 = Bold)
  bool italic{false};
  bool underline{false};
  bool strikethrough{false};

  // --- Alignment ---
  TextHAlignment horizontalAlignment{TextHAlignment::Center};
  TextVAlignment verticalAlignment{TextVAlignment::Middle};

  // --- Animatable Typography Properties ---
  anim::AnimProperty fontSize{72.0f};
  anim::AnimProperty tracking{0.0f};
  anim::AnimProperty lineSpacing{1.2f};

  // --- Solid Fill & Gradient Fill ---
  anim::AnimProperty fillRed{1.0f};
  anim::AnimProperty fillGreen{1.0f};
  anim::AnimProperty fillBlue{1.0f};
  anim::AnimProperty fillAlpha{1.0f};
  GradientConfig fillGradient;

  // --- Stroke & Trim Paths ---
  StrokePosition strokePosition{StrokePosition::Center};
  anim::AnimProperty strokeWidth{0.0f};
  anim::AnimProperty strokeRed{0.0f};
  anim::AnimProperty strokeGreen{0.0f};
  anim::AnimProperty strokeBlue{0.0f};
  anim::AnimProperty strokeAlpha{1.0f};
  GradientConfig strokeGradient;

  anim::AnimProperty trimStart{0.0f};
  anim::AnimProperty trimEnd{1.0f};
  anim::AnimProperty trimOffset{0.0f};

  std::vector<vector::TextAnimator> animators;
};

} // namespace xyla
