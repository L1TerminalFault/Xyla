#pragma once

#include "animChannel.hpp"
#include "animProperty.hpp"

#include <QString>
#include <functional>
#include <vector>

namespace xyla {

class TimelineClip;

namespace anim {

enum class PropertyCategory : uint8_t {
  Transform = 0,
  Compositing,
  Color,
  Audio
};

struct PropertyDescriptor {
  QString id;
  QString name;
  QString group;
  QString parent;
  QString color;
  PropertyCategory category{PropertyCategory::Transform};

  using Accessor = std::function<AnimProperty *(TimelineClip &)>;
  Accessor accessor;
};

[[nodiscard]] const std::vector<PropertyDescriptor> &propertyRegistry();
[[nodiscard]] const PropertyDescriptor *
findPropertyDescriptor(const QString &id);

} // namespace anim
} // namespace xyla
