#pragma once
#include "core/render/node.hpp"

namespace xyla::render {

class BlurNode : public Node {
public:
  BlurNode(const QString &id, const QString &name = "Blur")
      : Node(id, name, "BlurNode") {
    addInput("image_in", "Image", SocketDataType::Image, 0.0f);
    addInput("radius", "Radius", SocketDataType::Float, 5.0f);
    addOutput("image_out", "Image", SocketDataType::Image);
  }
};

} // namespace xyla::render
