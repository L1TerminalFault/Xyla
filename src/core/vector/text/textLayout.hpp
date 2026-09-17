#pragma once

#include "../vectorPath.hpp"
#include <QFont>
#include <QPainterPath>
#include <QRectF>
#include <QString>
#include <vector>

namespace xyla::vector {

enum class TextAlignment : uint8_t { Left = 0, Center, Right, Justify };

struct GlyphCluster {
  size_t charIndex{0};
  uint32_t glyphIndex{0};
  Vec2 layoutPosition{0.0f, 0.0f};
  Vec2 advance{0.0f, 0.0f};
  QRectF bounds;
  QPainterPath rawPath;
  VectorPath outline;
};

class TextLayoutEngine {
public:
  TextLayoutEngine() = default;

  static std::vector<GlyphCluster>
  layoutString(const QString &text, const QFont &font, float tracking = 0.0f,
               float lineSpacing = 1.2f,
               TextAlignment alignment = TextAlignment::Center);
};

} // namespace xyla::vector
