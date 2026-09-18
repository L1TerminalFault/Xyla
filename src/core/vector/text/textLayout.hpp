#pragma once

#include "core/timeline/component/textComponent.hpp"
#include <QFont>
#include <QPainterPath>
#include <QRectF>
#include <QString>
#include <vector>

namespace xyla::vector {

struct GlyphCluster {
  size_t charIndex{0};
  uint32_t glyphIndex{0};
  size_t lineIndex{0};
  size_t wordIndex{0};

  Vec2 layoutPosition{0.0f, 0.0f};
  Vec2 advance{0.0f, 0.0f};
  QRectF bounds;
  QPainterPath rawPath;

  // Decorations associated with this cluster
  std::vector<QPainterPath> decorationLines;
};

struct TextLayoutResult {
  std::vector<GlyphCluster> clusters;
  QRectF textBounds;
  std::vector<QRectF> lineBounds;
  std::vector<QRectF> wordBounds;
};

class TextLayoutEngine {
public:
  static TextLayoutResult layoutString(const QString &text, const QFont &font,
                                       float tracking, float lineSpacing,
                                       TextHAlignment hAlign,
                                       TextVAlignment vAlign, bool underline,
                                       bool strikethrough);
};

} // namespace xyla::vector
