#pragma once

#include "../vectorPath.hpp"
#include <QColor>
#include <QRectF>
#include <QString>
#include <vector>

namespace xyla::vector {

struct SvgShape {
  QString id;
  VectorPath path;
  QRectF bounds;
  float opacity{1.0f};
};

class SvgDocument {
public:
  SvgDocument() = default;

  static SvgDocument fromXml(const QString &xmlContent);
  static SvgDocument fromFile(const QString &filePath);

  [[nodiscard]] const std::vector<SvgShape> &shapes() const noexcept {
    return m_shapes;
  }
  [[nodiscard]] std::vector<SvgShape> &shapes() noexcept { return m_shapes; }

  [[nodiscard]] QRectF viewBox() const noexcept { return m_viewBox; }
  void setViewBox(QRectF box) noexcept { m_viewBox = box; }

  [[nodiscard]] bool isValid() const noexcept { return !m_shapes.empty(); }

  void applyTrim(float start, float end, float offset) noexcept;
  void applyStrokeOverride(float width, std::array<float, 4> color) noexcept;
  void applyFillOverride(std::array<float, 4> color) noexcept;

private:
  std::vector<SvgShape> m_shapes;
  QRectF m_viewBox{0.0, 0.0, 1920.0, 1080.0};
};

} // namespace xyla::vector
