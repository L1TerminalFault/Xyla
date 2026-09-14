#pragma once
#include "core/render/node.hpp"

namespace xyla::render {

class RerouteNode : public Node {
public:
  RerouteNode(const QString &id, const QString &name = "Reroute")
      : Node(id, name, "Reroute") {
    // Uses Image or Generic if SocketDataType has it (e.g. SocketDataType::Image)
    addInput("in", "In", SocketDataType::Image, 0.0f);
    addOutput("out", "Out", SocketDataType::Image);
  }
};

} // namespace xyla::render
