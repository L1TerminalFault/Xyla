#pragma once

#include <QString>
#include <array>
#include <cstdint>
#include <variant>

namespace xyla::render {

enum class SocketDataType : uint8_t {
  Image,
  Float,
  Vec2,
  Color,
  Mat4,
  Int,
  Bool
};

enum class SocketKind : uint8_t { Input, Output };

using Vec2Val = std::array<float, 2>;
using ColorVal = std::array<float, 4>;

using SocketValue = std::variant<std::monostate, float, Vec2Val, ColorVal,
                                 int32_t, bool, QString>;

struct NodeSocket {
  QString id;
  QString name;
  SocketDataType dataType;
  SocketKind kind;

  SocketValue defaultValue;

  int16_t frameOffset{0};

  [[nodiscard]] constexpr const char *glslTypeName() const noexcept {
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
      return "bool";
    }
    return "float";
  }
};

} // namespace xyla::render
