#include "textLayout.hpp"
#include <QFontMetricsF>
#include <QRawFont>

namespace xyla::vector {

std::vector<GlyphCluster>
TextLayoutEngine::layoutString(const QString &text, const QFont &font,
                               float tracking, float lineSpacing,
                               TextAlignment alignment) {
  std::vector<GlyphCluster> clusters;
  if (text.isEmpty())
    return clusters;

  QFont resolvedFont = font;
  resolvedFont.setStyleHint(QFont::SansSerif);
  resolvedFont.setHintingPreference(QFont::PreferFullHinting);

  QFontMetricsF metrics(resolvedFont);
  float baseLineHeight = static_cast<float>(metrics.height()) * lineSpacing;
  float trackingOffset =
      tracking * 0.01f * static_cast<float>(resolvedFont.pixelSize());

  QStringList lines = text.split('\n');
  float totalBlockHeight = static_cast<float>(lines.size()) * baseLineHeight;
  float currentY =
      -totalBlockHeight * 0.5f + static_cast<float>(metrics.ascent());

  QRawFont rawFont = QRawFont::fromFont(resolvedFont);

  for (const QString &line : lines) {
    std::vector<float> advances;
    advances.reserve(line.size());

    float lineWidth = 0.0f;
    for (int i = 0; i < line.size(); ++i) {
      float adv = static_cast<float>(metrics.horizontalAdvance(line[i])) +
                  trackingOffset;
      advances.push_back(adv);
      lineWidth += adv;
    }

    float startX = 0.0f;
    if (alignment == TextAlignment::Center) {
      startX = -lineWidth * 0.5f;
    } else if (alignment == TextAlignment::Right) {
      startX = -lineWidth;
    }

    float currentX = startX;
    for (int i = 0; i < line.size(); ++i) {
      QChar ch = line[i];
      if (ch.isSpace()) {
        currentX += advances[i];
        continue;
      }

      QPainterPath painterPath;
      uint32_t glyphIdx = 0;

      if (rawFont.isValid()) {
        quint32 rawIdx = 0;
        int count = 0;
        rawFont.glyphIndexesForChars(&ch, 1, &rawIdx, &count);
        if (count > 0 && rawIdx > 0) {
          glyphIdx = rawIdx;
          painterPath = rawFont.pathForGlyph(rawIdx);
        }
      }

      if (painterPath.isEmpty()) {
        painterPath.addText(0.0, 0.0, resolvedFont, QString(ch));
      }

      GlyphCluster cluster;
      cluster.charIndex = static_cast<size_t>(i);
      cluster.glyphIndex = glyphIdx;
      cluster.layoutPosition = {currentX, currentY};
      cluster.advance = {advances[i], 0.0f};
      cluster.bounds = painterPath.boundingRect();
      cluster.rawPath = painterPath;

      clusters.push_back(std::move(cluster));
      currentX += advances[i];
    }

    currentY += baseLineHeight;
  }

  return clusters;
}

} // namespace xyla::vector
