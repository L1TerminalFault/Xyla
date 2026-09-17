#include "svgDocument.hpp"
#include <QFile>
#include <QRegularExpression>
#include <QXmlStreamReader>

namespace xyla::vector {

namespace {

QPainterPath parseSvgPathData(const QString &d) {
  QPainterPath path;
  if (d.isEmpty())
    return path;

  static const QRegularExpression tokenRe(
      "([a-df-z])|([-+]?(?:[0-9]*\\.[0-9]+|[0-9]+)(?:[eE][-+]?[0-9]+)?)",
      QRegularExpression::CaseInsensitiveOption);

  auto it = tokenRe.globalMatch(d);
  QChar currentCmd = 'M';
  QPointF currentPt(0.0, 0.0);
  QPointF lastControl(0.0, 0.0);
  QPointF subpathStart(0.0, 0.0);

  auto getNextNumber = [&it]() -> float {
    if (it.hasNext()) {
      auto m = it.next();
      QString str = m.captured(0);
      if (!str.isEmpty() &&
          (str[0].isLetter() && str[0] != 'e' && str[0] != 'E')) {
        return 0.0f;
      }
      return str.toFloat();
    }
    return 0.0f;
  };

  while (it.hasNext()) {
    auto match = it.next();
    QString token = match.captured(0);
    if (token.isEmpty())
      continue;

    if (token[0].isLetter() && token[0] != 'e' && token[0] != 'E') {
      currentCmd = token[0];
    } else {
      float val = token.toFloat();
      bool isRel = currentCmd.isLower();
      QChar upperCmd = currentCmd.toUpper();

      switch (upperCmd.toLatin1()) {
      case 'M': {
        float x = val;
        float y = getNextNumber();
        QPointF p = isRel ? (currentPt + QPointF(x, y)) : QPointF(x, y);
        path.moveTo(p);
        currentPt = p;
        subpathStart = p;
        lastControl = p;
        currentCmd = isRel ? 'l' : 'L';
        break;
      }
      case 'L': {
        float x = val;
        float y = getNextNumber();
        QPointF p = isRel ? (currentPt + QPointF(x, y)) : QPointF(x, y);
        path.lineTo(p);
        currentPt = p;
        lastControl = p;
        break;
      }
      case 'H': {
        float x = val;
        QPointF p = isRel ? QPointF(currentPt.x() + x, currentPt.y())
                          : QPointF(x, currentPt.y());
        path.lineTo(p);
        currentPt = p;
        lastControl = p;
        break;
      }
      case 'V': {
        float y = val;
        QPointF p = isRel ? QPointF(currentPt.x(), currentPt.y() + y)
                          : QPointF(currentPt.x(), y);
        path.lineTo(p);
        currentPt = p;
        lastControl = p;
        break;
      }
      case 'C': {
        float x1 = val;
        float y1 = getNextNumber();
        float x2 = getNextNumber();
        float y2 = getNextNumber();
        float x = getNextNumber();
        float y = getNextNumber();

        QPointF cp1 = isRel ? (currentPt + QPointF(x1, y1)) : QPointF(x1, y1);
        QPointF cp2 = isRel ? (currentPt + QPointF(x2, y2)) : QPointF(x2, y2);
        QPointF endPt = isRel ? (currentPt + QPointF(x, y)) : QPointF(x, y);

        path.cubicTo(cp1, cp2, endPt);
        lastControl = cp2;
        currentPt = endPt;
        break;
      }
      case 'S': {
        float x2 = val;
        float y2 = getNextNumber();
        float x = getNextNumber();
        float y = getNextNumber();

        QPointF cp1 = currentPt * 2.0 - lastControl;
        QPointF cp2 = isRel ? (currentPt + QPointF(x2, y2)) : QPointF(x2, y2);
        QPointF endPt = isRel ? (currentPt + QPointF(x, y)) : QPointF(x, y);

        path.cubicTo(cp1, cp2, endPt);
        lastControl = cp2;
        currentPt = endPt;
        break;
      }
      case 'Q': {
        float x1 = val;
        float y1 = getNextNumber();
        float x = getNextNumber();
        float y = getNextNumber();

        QPointF cp = isRel ? (currentPt + QPointF(x1, y1)) : QPointF(x1, y1);
        QPointF endPt = isRel ? (currentPt + QPointF(x, y)) : QPointF(x, y);

        path.quadTo(cp, endPt);
        lastControl = cp;
        currentPt = endPt;
        break;
      }
      case 'Z':
        path.closeSubpath();
        currentPt = subpathStart;
        lastControl = subpathStart;
        break;
      }
    }

    if (currentCmd.toUpper() == 'Z') {
      path.closeSubpath();
      currentPt = subpathStart;
      lastControl = subpathStart;
    }
  }

  return path;
}

std::array<float, 4> parseColor(const QString &colorStr,
                                const std::array<float, 4> &defaultCol) {
  if (colorStr.isEmpty() || colorStr == "none") {
    return {0.0f, 0.0f, 0.0f, 0.0f};
  }
  QColor c(colorStr);
  if (c.isValid()) {
    return {static_cast<float>(c.redF()), static_cast<float>(c.greenF()),
            static_cast<float>(c.blueF()), static_cast<float>(c.alphaF())};
  }
  return defaultCol;
}

} // namespace

SvgDocument SvgDocument::fromXml(const QString &xmlContent) {
  SvgDocument doc;
  QXmlStreamReader xml(xmlContent);

  while (!xml.atEnd() && !xml.hasError()) {
    auto token = xml.readNext();
    if (token != QXmlStreamReader::StartElement)
      continue;

    QStringView name = xml.name();
    auto attrs = xml.attributes();

    if (name == u"svg") {
      if (attrs.hasAttribute("viewBox")) {
        QString vb = attrs.value("viewBox").toString();
        auto parts = vb.split(QRegularExpression("[ ,]+"), Qt::SkipEmptyParts);
        if (parts.size() >= 4) {
          doc.setViewBox(QRectF(parts[0].toDouble(), parts[1].toDouble(),
                                parts[2].toDouble(), parts[3].toDouble()));
        }
      }
      continue;
    }

    QPainterPath painterPath;
    if (name == u"path") {
      painterPath = parseSvgPathData(attrs.value("d").toString());
    } else if (name == u"rect") {
      float x = attrs.value("x").toFloat();
      float y = attrs.value("y").toFloat();
      float w = attrs.value("width").toFloat();
      float h = attrs.value("height").toFloat();
      painterPath.addRect(x, y, w, h);
    } else if (name == u"circle") {
      float cx = attrs.value("cx").toFloat();
      float cy = attrs.value("cy").toFloat();
      float r = attrs.value("r").toFloat();
      painterPath.addEllipse(QPointF(cx, cy), r, r);
    } else if (name == u"ellipse") {
      float cx = attrs.value("cx").toFloat();
      float cy = attrs.value("cy").toFloat();
      float rx = attrs.value("rx").toFloat();
      float ry = attrs.value("ry").toFloat();
      painterPath.addEllipse(QPointF(cx, cy), rx, ry);
    } else if (name == u"line") {
      float x1 = attrs.value("x1").toFloat();
      float y1 = attrs.value("y1").toFloat();
      float x2 = attrs.value("x2").toFloat();
      float y2 = attrs.value("y2").toFloat();
      painterPath.moveTo(x1, y1);
      painterPath.lineTo(x2, y2);
    }

    if (!painterPath.isEmpty()) {
      SvgShape shape;
      shape.id = attrs.value("id").toString();
      shape.bounds = painterPath.boundingRect();
      shape.path = VectorPath::fromPainterPath(painterPath);

      std::array<float, 4> defaultFill = {0.0f, 0.0f, 0.0f, 1.0f};
      std::array<float, 4> defaultStroke = {0.0f, 0.0f, 0.0f, 0.0f};

      shape.path.setFillColor(
          parseColor(attrs.value("fill").toString(), defaultFill));

      StrokeStyle stroke;
      stroke.color =
          parseColor(attrs.value("stroke").toString(), defaultStroke);
      if (attrs.hasAttribute("stroke-width")) {
        stroke.width = attrs.value("stroke-width").toFloat();
      }
      shape.path.setStroke(stroke);

      if (attrs.hasAttribute("opacity")) {
        shape.opacity = attrs.value("opacity").toFloat();
      }

      doc.m_shapes.push_back(std::move(shape));
    }
  }

  return doc;
}

SvgDocument SvgDocument::fromFile(const QString &filePath) {
  QFile file(filePath);
  if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
    return SvgDocument();

  return fromXml(QString::fromUtf8(file.readAll()));
}

void SvgDocument::applyTrim(float start, float end, float offset) noexcept {
  for (auto &shape : m_shapes) {
    shape.path.stroke().trimStart = start;
    shape.path.stroke().trimEnd = end;
    shape.path.stroke().trimOffset = offset;
  }
}

void SvgDocument::applyStrokeOverride(float width,
                                      std::array<float, 4> color) noexcept {
  for (auto &shape : m_shapes) {
    shape.path.stroke().width = width;
    shape.path.stroke().color = color;
  }
}

void SvgDocument::applyFillOverride(std::array<float, 4> color) noexcept {
  for (auto &shape : m_shapes) {
    shape.path.setFillColor(color);
  }
}

} // namespace xyla::vector
