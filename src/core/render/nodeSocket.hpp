#pragma once

#include <QString>
#include <QVariant>
#include <array>
#include <cstdint>
#include <variant>

namespace xyla::render {

enum class SocketDataType : uint8_t {
  Image = 0,
  Float = 1,
  Vec2 = 2,
  Color = 3,
  Mat4 = 4,
  Int = 5,
  Bool = 6
};

enum class SocketKind : uint8_t { Input = 0, Output = 1 };

using Vec2Val = std::array<float, 2>;
using ColorVal = std::array<float, 4>;

using SocketValue = std::variant<std::monostate, float, double, Vec2Val,
                                 ColorVal, int32_t, bool, QString>;

struct NodeSocket {
  QString id;
  QString name;
  SocketDataType dataType;
  SocketKind kind;
  SocketValue defaultValue;
  int32_t frameOffset{0};

  [[nodiscard]] QString glslTypeName() const;
  [[nodiscard]] uint32_t byteSize() const noexcept;
  [[nodiscard]] uint32_t byteAlignment() const noexcept;
  [[nodiscard]] static bool areCompatible(SocketDataType from,
                                          SocketDataType to) noexcept;
};

struct NodeLink {
  QString fromNodeId;
  QString fromSocketId;
  QString toNodeId;
  QString toSocketId;

  bool operator==(const NodeLink &other) const {
    return fromNodeId == other.fromNodeId &&
           fromSocketId == other.fromSocketId && toNodeId == other.toNodeId &&
           toSocketId == other.toSocketId;
  }
};

} // namespace xyla::render
