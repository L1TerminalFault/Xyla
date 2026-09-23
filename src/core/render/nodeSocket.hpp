#pragma once

#include <QString>
#include <array>
#include <cstdint>
#include <qcontainerfwd.h>
#include <qlist.h>
#include <variant>

namespace xyla::render {

using Vec2Val = std::array<float, 2>;
using ColorVal = std::array<float, 4>;
using SocketValue = std::variant<std::monostate, float, double, Vec2Val,
                                 ColorVal, int32_t, bool, QString>;

enum class SocketDataType : uint8_t { Float, Vec2, Color, Int, Bool, Image };

enum class SocketKind : uint8_t { Input, Output };

struct NodeSocket {
  QString id;
  QString name;
  SocketDataType dataType{SocketDataType::Float};
  SocketKind kind{SocketKind::Input};
  SocketValue defaultValue{};

  float minValue{0.0f};
  float maxValue{1.0f};
  float stepSize{0.01f};
  QString unit;
  QStringList enumOptions;
  [[nodiscard]] bool isEnum() const noexcept { return !enumOptions.isEmpty(); }
  [[nodiscard]] static bool areCompatible(SocketDataType src,
                                          SocketDataType dst) noexcept {
    return src == dst;
  }

  [[nodiscard]] uint32_t byteSize() const noexcept {
    switch (dataType) {
    case SocketDataType::Float:
      return 4;
    case SocketDataType::Int:
      return 4;
    case SocketDataType::Bool:
      return 4;
    case SocketDataType::Vec2:
      return 8;
    case SocketDataType::Color:
      return 16;
    case SocketDataType::Image:
      return 0;
    }
    return 0;
  }

  [[nodiscard]] uint32_t byteAlignment() const noexcept {
    switch (dataType) {
    case SocketDataType::Float:
      return 4;
    case SocketDataType::Int:
      return 4;
    case SocketDataType::Bool:
      return 4;
    case SocketDataType::Vec2:
      return 8;
    case SocketDataType::Color:
      return 16;
    case SocketDataType::Image:
      return 0;
    }
    return 4;
  }

  [[nodiscard]] const char *glslTypeName() const noexcept {
    switch (dataType) {
    case SocketDataType::Float:
      return "float";
    case SocketDataType::Int:
      return "int";
    case SocketDataType::Bool:
      return "uint";
    case SocketDataType::Vec2:
      return "vec2";
    case SocketDataType::Color:
      return "vec4";
    case SocketDataType::Image:
      return "sampler2D";
    }
    return "float";
  }
};

struct NodeLink {
  QString fromNodeId;
  QString fromSocketId;
  QString toNodeId;
  QString toSocketId;

  [[nodiscard]] bool operator==(const NodeLink &other) const noexcept {
    return fromNodeId == other.fromNodeId &&
           fromSocketId == other.fromSocketId && toNodeId == other.toNodeId &&
           toSocketId == other.toSocketId;
  }
};

} // namespace xyla::render
