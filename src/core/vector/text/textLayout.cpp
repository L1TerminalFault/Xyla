#include "textLayout.hpp"
#include <QFontMetricsF>
#include <QRawFont>
#include <cmath>

namespace xyla::vector {

TextLayoutResult
TextLayoutEngine::layoutString(const QString &text, const QFont &font,
                               float tracking, float lineSpacing,
                               TextHAlignment hAlign, TextVAlignment vAlign,
                               bool underline, bool strikethrough) {
  TextLayoutResult result;
  if (text.isEmpty())
    return result;

  QFont resolvedFont = font;
  resolvedFont.setStyleHint(QFont::SansSerif);
  resolvedFont.setHintingPreference(QFont::PreferFullHinting);

  QFontMetricsF metrics(resolvedFont);
  float baseLineHeight = static_cast<float>(metrics.height()) * lineSpacing;
  float trackingOffset =
      tracking * 0.01f * static_cast<float>(resolvedFont.pixelSize());

  QStringList lines = text.split('\n');
  float totalBlockHeight = static_cast<float>(lines.size()) * baseLineHeight;

  // --- 1. VERTICAL ALIGNMENT CALCULATION ---
  float startY = 0.0f;
  switch (vAlign) {
  case TextVAlignment::Top:
    startY = static_cast<float>(metrics.ascent());
    break;
  case TextVAlignment::Bottom:
    startY = -totalBlockHeight + static_cast<float>(metrics.ascent()) +
             baseLineHeight;
    break;
  case TextVAlignment::Middle:
  default:
    startY = -totalBlockHeight * 0.5f + static_cast<float>(metrics.ascent());
    break;
  }

  QRawFont rawFont = QRawFont::fromFont(resolvedFont);
  size_t globalCharOffset = 0;
  size_t globalWordIndex = 0;
  float currentY = startY;

  float minX = 1e9f, maxX = -1e9f;
  float minY = 1e9f, maxY = -1e9f;

  for (size_t lIdx = 0; lIdx < static_cast<size_t>(lines.size()); ++lIdx) {
    const QString &line = lines[lIdx];
    std::vector<float> advances;
    advances.reserve(line.size());

    float baseLineWidth = 0.0f;
    int spaceCount = 0;
    for (int i = 0; i < line.size(); ++i) {
      float adv = static_cast<float>(metrics.horizontalAdvance(line[i])) +
                  trackingOffset;
      advances.push_back(adv);
      baseLineWidth += adv;
      if (line[i].isSpace())
        spaceCount++;
    }

    // --- 2. HORIZONTAL ALIGNMENT CALCULATION ---
    float startX = 0.0f;
    float extraSpaceWidth = 0.0f;

    switch (hAlign) {
    case TextHAlignment::Center:
      startX = -baseLineWidth * 0.5f;
      break;
    case TextHAlignment::Right:
      startX = -baseLineWidth;
      break;
    case TextHAlignment::Justify:
      // Distribute space evenly across spaces on non-terminal lines
      if (lIdx + 1 < static_cast<size_t>(lines.size()) && spaceCount > 0) {
        float availableArea = std::max(baseLineWidth, 300.0f);
        extraSpaceWidth =
            (availableArea - baseLineWidth) / static_cast<float>(spaceCount);
      }
      startX = -baseLineWidth * 0.5f;
      break;
    case TextHAlignment::Left:
    default:
      startX = 0.0f;
      break;
    }

    float currentX = startX;
    float lineMinX = currentX;
    bool inWord = false;
    size_t wordStartClusterIdx = result.clusters.size();
    float wordStartX = currentX;

    for (int i = 0; i < line.size(); ++i) {
      QChar ch = line[i];
      float advance = advances[i];

      if (ch.isSpace()) {
        if (inWord) {
          // Close word bounding box
          result.wordBounds.push_back(
              QRectF(wordStartX, currentY - metrics.ascent(),
                     currentX - wordStartX, baseLineHeight));
          inWord = false;
          globalWordIndex++;
        }
        currentX += advance + extraSpaceWidth;
        continue;
      }

      if (!inWord) {
        inWord = true;
        wordStartX = currentX;
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
      cluster.charIndex = globalCharOffset + static_cast<size_t>(i);
      cluster.glyphIndex = glyphIdx;
      cluster.lineIndex = lIdx;
      cluster.wordIndex = globalWordIndex;
      cluster.layoutPosition = {currentX, currentY};
      cluster.advance = {advance, 0.0f};
      cluster.bounds =
          painterPath.boundingRect().translated(currentX, currentY);
      cluster.rawPath = painterPath;

      // --- 3. UNDERLINE & STRIKETHROUGH VECTOR GEOMETRY ---
      float decW = advance;
      float decThickness =
          std::max(1.0f, static_cast<float>(metrics.lineWidth()));

      if (underline) {
        float uY = static_cast<float>(metrics.underlinePos());
        QPainterPath uLine;
        uLine.addRect(0.0f, uY, decW, decThickness);
        cluster.decorationLines.push_back(std::move(uLine));
      }
      if (strikethrough) {
        float sY = -static_cast<float>(metrics.strikeOutPos());
        QPainterPath sLine;
        sLine.addRect(0.0f, sY, decW, decThickness);
        cluster.decorationLines.push_back(std::move(sLine));
      }

      minX = std::min(minX, static_cast<float>(cluster.bounds.left()));
      maxX = std::max(maxX, static_cast<float>(cluster.bounds.right()));
      minY = std::min(minY, static_cast<float>(cluster.bounds.top()));
      maxY = std::max(maxY, static_cast<float>(cluster.bounds.bottom()));

      result.clusters.push_back(std::move(cluster));
      currentX += advance;
    }

    if (inWord) {
      result.wordBounds.push_back(
          QRectF(wordStartX, currentY - metrics.ascent(), currentX - wordStartX,
                 baseLineHeight));
      globalWordIndex++;
    }

    result.lineBounds.push_back(QRectF(lineMinX, currentY - metrics.ascent(),
                                       currentX - lineMinX, baseLineHeight));

    currentY += baseLineHeight;
    globalCharOffset += line.size() + 1;
  }

  if (result.clusters.empty()) {
    result.textBounds = QRectF(0, 0, 0, 0);
  } else {
    result.textBounds = QRectF(minX, minY, maxX - minX, maxY - minY);
  }

  return result;
}

} // namespace xyla::vector
