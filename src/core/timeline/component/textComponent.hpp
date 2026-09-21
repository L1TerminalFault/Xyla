#pragma once

#include "core/animation/AnimationManager.hpp"
#include "core/animation/propertyHandle.hpp"
#include "core/timeline/component/clipComponent.hpp"
#include "core/vector/text/textAnimator.hpp"

#include <QColor>
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <memory>
#include <optional>
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
  float position{0.0f};
  QColor color{Qt::white};

  QJsonObject serialize() const;
  static GradientStop deserialize(const QJsonObject &obj);
};

struct GradientConfig {
  GradientType type{GradientType::None};
  GradientScope scope{GradientScope::WholeText};
  float angleDegrees{0.0f};
  float startX{0.0f};
  float startY{0.0f};
  float endX{1.0f};
  float endY{0.0f};
  float radialRadius{0.5f};
  std::vector<GradientStop> stops;

  QJsonObject serialize() const;
  void deserialize(const QJsonObject &obj);
};

// Sub-range character formatting override
struct RichTextSpan {
  uint32_t startChar{0};
  uint32_t length{0};

  std::optional<QString> fontFamily;
  std::optional<int> fontWeight;
  std::optional<bool> italic;
  std::optional<bool> underline;
  std::optional<bool> strikethrough;

  std::optional<float> fontSize;
  std::optional<QColor> fillColor;
  std::optional<QColor> strokeColor;
  std::optional<float> strokeWidth;
  std::optional<float> tracking;

  QJsonObject serialize() const;
  static RichTextSpan deserialize(const QJsonObject &obj);
};

class TextComponent : public ClipComponent {
public:
  TextComponent();
  TextComponent(const TextComponent &other);
  TextComponent &operator=(const TextComponent &other);
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

  void bindAnimationManager(const QString &clipId,
                            anim::AnimationManager &animMgr) override;

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

  // Content & Fonts (Base defaults)
  QString text{QStringLiteral("Title")};
  QString fontFamily{QStringLiteral("Inter")};
  int fontWeight{400};
  bool italic{false};
  bool underline{false};
  bool strikethrough{false};

  // Alignment
  TextHAlignment horizontalAlignment{TextHAlignment::Center};
  TextVAlignment verticalAlignment{TextVAlignment::Middle};
  StrokePosition strokePosition{StrokePosition::Center};

  // Gradients
  GradientConfig fillGradient;
  GradientConfig strokeGradient;

  // Rich Text Sub-Ranges
  std::vector<RichTextSpan> richTextSpans;

  // Canonical Table Property Handles
  vector::ChannelHandles handles;

  // Polymorphic Single Animator
  std::unique_ptr<vector::ITextAnimator> animator;

private:
  anim::AnimationManager *m_animMgr{nullptr};
};

} // namespace xyla
