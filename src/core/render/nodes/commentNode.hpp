#pragma once
#include "core/render/node.hpp"

namespace xyla::render {

class CommentNode : public Node {
public:
  CommentNode(const QString &id, const QString &name = "Notes")
      : Node(id, name, "CommentNode") {}

  [[nodiscard]] QString text() const { return m_text; }
  void setText(const QString &t) { m_text = t; }

  [[nodiscard]] double width() const { return m_width; }
  [[nodiscard]] double height() const { return m_height; }
  void setDimensions(double w, double h) { m_width = w; m_height = h; }

private:
  QString m_text{"Notes"};
  double m_width{300.0};
  double m_height{200.0};
};

} // namespace xyla::render
