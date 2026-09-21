#include "textLayout.hpp"
#include <QFontMetricsF>
#include <QRawFont>

namespace xyla::vector {

TextLayoutResult
TextLayoutEngine::layoutString(const QString &text, const QFont &baseFont,
                               float tracking, float lineSpacing,
                               TextHAlignment hAlign, TextVAlignment vAlign,
                               bool underline, bool strikethrough,
                               const std::vector<RichTextSpan> &spans) {
  TextLayoutResult result;
  if (text.isEmpty())
    return result;

  auto resolveFontForChar = [&](size_t charIdx) -> QFont {
    QFont f = baseFont;
    for (const auto &span : spans) {
      if (charIdx >= span.startChar &&
          charIdx < (span.startChar + span.length)) {
        if (span.fontFamily)
          f.setFamily(*span.fontFamily);
        if (span.fontWeight)
          f.setWeight(static_cast<QFont::Weight>(*span.fontWeight));
        if (span.italic)
          f.setStyle(*span.italic ? QFont::StyleItalic : QFont::StyleNormal);
        if (span.fontSize)
          f.setPixelSize(std::max(1, static_cast<int>(*span.fontSize)));
        break;
      }
    }
    f.setStyleHint(QFont::SansSerif);
    f.setHintingPreference(QFont::PreferFullHinting);
    return f;
  };

  QFont defaultFont = baseFont;
  defaultFont.setStyleHint(QFont::SansSerif);
  defaultFont.setHintingPreference(QFont::PreferFullHinting);

  QFontMetricsF metrics(defaultFont);
  float baseLineHeight = static_cast<float>(metrics.height()) * lineSpacing;
  float trackingOffset =
      tracking * 0.01f * static_cast<float>(defaultFont.pixelSize());

  QStringList lines = text.split(QLatin1Char('\n'));
  float totalBlockHeight = static_cast<float>(lines.size()) * baseLineHeight;

  // 1. First Pass: Compute line widths and max block width
  std::vector<float> lineWidths(lines.size(), 0.0f);
  float maxBlockWidth = 0.0f;
  size_t charScanOffset = 0;

  for (size_t lIdx = 0; lIdx < static_cast<size_t>(lines.size()); ++lIdx) {
    const QString &line = lines[lIdx];
    float w = 0.0f;
    for (int i = 0; i < line.size(); ++i) {
      size_t cIdx = charScanOffset + static_cast<size_t>(i);
      QFont f = resolveFontForChar(cIdx);
      QFontMetricsF cm(f);
      w += static_cast<float>(cm.horizontalAdvance(line[i])) + trackingOffset;
    }
    lineWidths[lIdx] = w;
    maxBlockWidth = std::max(maxBlockWidth, w);
    charScanOffset += line.size() + 1;
  }

  // 2. Vertical Alignment Start
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

  size_t globalCharOffset = 0;
  size_t globalWordIndex = 0;
  float currentY = startY;

  float minX = 1e9f, maxX = -1e9f;
  float minY = 1e9f, maxY = -1e9f;

  // 3. Second Pass: Layout Glyph Clusters
  for (size_t lIdx = 0; lIdx < static_cast<size_t>(lines.size()); ++lIdx) {
    const QString &line = lines[lIdx];
    const float baseLineWidth = lineWidths[lIdx];
    std::vector<float> advances;
    std::vector<QFont> charFonts;
    advances.reserve(line.size());
    charFonts.reserve(line.size());

    int spaceCount = 0;
    for (int i = 0; i < line.size(); ++i) {
      size_t charIdx = globalCharOffset + static_cast<size_t>(i);
      QFont f = resolveFontForChar(charIdx);
      QFontMetricsF cm(f);

      float adv =
          static_cast<float>(cm.horizontalAdvance(line[i])) + trackingOffset;
      advances.push_back(adv);
      charFonts.push_back(std::move(f));
      if (line[i].isSpace())
        spaceCount++;
    }

    // ⚡ Proper Relative Alignment
    float startX = 0.0f;
    float extraSpaceWidth = 0.0f;

    switch (hAlign) {
    case TextHAlignment::Left:
      // All lines align to the left boundary of the centered block
      startX = -maxBlockWidth * 0.5f;
      break;
    case TextHAlignment::Right:
      // All lines align to the right boundary of the centered block
      startX = maxBlockWidth * 0.5f - baseLineWidth;
      break;
    case TextHAlignment::Justify:
      if (lIdx + 1 < static_cast<size_t>(lines.size()) && spaceCount > 0) {
        extraSpaceWidth =
            (maxBlockWidth - baseLineWidth) / static_cast<float>(spaceCount);
      }
      startX = -maxBlockWidth * 0.5f;
      break;
    case TextHAlignment::Center:
    default:
      // Each line centered independently
      startX = -baseLineWidth * 0.5f;
      break;
    }

    float currentX = startX;
    float lineMinX = currentX;
    bool inWord = false;
    float wordStartX = currentX;

    for (int i = 0; i < line.size(); ++i) {
      QChar ch = line[i];
      float advance = advances[i];
      const QFont &f = charFonts[i];
      QFontMetricsF cm(f);

      if (ch.isSpace()) {
        if (inWord) {
          result.wordBounds.push_back(QRectF(wordStartX, currentY - cm.ascent(),
                                             currentX - wordStartX,
                                             baseLineHeight));
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

      QRawFont rawFont = QRawFont::fromFont(f);
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
        painterPath.addText(0.0, 0.0, f, QString(ch));
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
      cluster.rawPath = std::move(painterPath);

      if (underline) {
        float uY = static_cast<float>(cm.underlinePos());
        QPainterPath uLine;
        uLine.addRect(0.0f, uY, advance,
                      std::max(1.0f, static_cast<float>(cm.lineWidth())));
        cluster.decorationLines.push_back(std::move(uLine));
      }
      if (strikethrough) {
        float sY = -static_cast<float>(cm.strikeOutPos());
        QPainterPath sLine;
        sLine.addRect(0.0f, sY, advance,
                      std::max(1.0f, static_cast<float>(cm.lineWidth())));
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
