#include "nodeSocket.hpp"

namespace xyla::render {

QString NodeSocket::glslTypeName() const {
  switch (dataType) {
  case SocketDataType::Image:
    return "sampler2D";
  case SocketDataType::Float:
    return "float";
  case SocketDataType::Vec2:
    return "vec2";
  case SocketDataType::Color:
    return "vec4";
  case SocketDataType::Mat4:
    return "mat4";
  case SocketDataType::Int:
    return "int";
  case SocketDataType::Bool:
    return "uint";
  }
  return "float";
}

uint32_t NodeSocket::byteSize() const noexcept {
  switch (dataType) {
  case SocketDataType::Float:
    return 4;
  case SocketDataType::Vec2:
    return 8;
  case SocketDataType::Color:
    return 16;
  case SocketDataType::Mat4:
    return 64;
  case SocketDataType::Int:
    return 4;
  case SocketDataType::Bool:
    return 4;
  case SocketDataType::Image:
    return 0;
  }
  return 4;
}

uint32_t NodeSocket::byteAlignment() const noexcept {
  switch (dataType) {
  case SocketDataType::Float:
    return 4;
  case SocketDataType::Vec2:
    return 8;
  case SocketDataType::Color:
    return 16;
  case SocketDataType::Mat4:
    return 16;
  case SocketDataType::Int:
    return 4;
  case SocketDataType::Bool:
    return 4;
  case SocketDataType::Image:
    return 1;
  }
  return 4;
}

bool NodeSocket::areCompatible(SocketDataType from,
                               SocketDataType to) noexcept {
  if (from == to)
    return true;

  // Strict rules: Images only connect to Images
  if (from == SocketDataType::Image || to == SocketDataType::Image)
    return false;

  // Numerical promotions: Float to Vec2 / Int
  if (from == SocketDataType::Float &&
      (to == SocketDataType::Vec2 || to == SocketDataType::Int))
    return true;

  if (from == SocketDataType::Int && to == SocketDataType::Float)
    return true;

  return false;
}

} // namespace xyla::render
