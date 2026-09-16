#include "propertyDescriptor.hpp"
#include "core/timeline/timelineClip.hpp"

namespace xyla::anim {

const std::vector<PropertyDescriptor> &propertyRegistry() {
  static const std::vector<PropertyDescriptor> registry = {
      // Transform
      {"positionX", "X", "Transform", "Position", "#EF4444",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.getTransform().posX; }},
      {"positionY", "Y", "Transform", "Position", "#22C55E",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.getTransform().posY; }},
      {"scale", "Scale", "Transform", "", "#3B82F6",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.getTransform().scaleX; }},
      {"scaleX", "X", "Transform", "Scale", "#3B82F6",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.getTransform().scaleX; }},
      {"scaleY", "Y", "Transform", "Scale", "#3B82F6",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.getTransform().scaleY; }},
      {"rotation", "Rotation", "Transform", "", "#EAB308",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.getTransform().rotation; }},
      {"opacity", "Opacity", "Compositing", "", "#A855F7",
       PropertyCategory::Compositing,
       [](TimelineClip &c) { return &c.getTransform().opacity; }},

      // Color Primary
      {"liftR", "R", "Color", "Lift", "#F87171", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().liftR; }},
      {"liftG", "G", "Color", "Lift", "#4ADE80", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().liftG; }},
      {"liftB", "B", "Color", "Lift", "#60A5FA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().liftB; }},
      {"gammaR", "R", "Color", "Gamma", "#F87171", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().gammaR; }},
      {"gammaG", "G", "Color", "Gamma", "#4ADE80", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().gammaG; }},
      {"gammaB", "B", "Color", "Gamma", "#60A5FA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().gammaB; }},
      {"gainR", "R", "Color", "Gain", "#F87171", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().gainR; }},
      {"gainG", "G", "Color", "Gain", "#4ADE80", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().gainG; }},
      {"gainB", "B", "Color", "Gain", "#60A5FA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().gainB; }},
      {"offsetR", "R", "Color", "Offset", "#F87171", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().offsetR; }},
      {"offsetG", "G", "Color", "Offset", "#4ADE80", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().offsetG; }},
      {"offsetB", "B", "Color", "Offset", "#60A5FA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().offsetB; }},

      // Color Adjustments
      {"temperature", "Temperature", "Color", "", "#F59E0B",
       PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().temperature; }},
      {"tint", "Tint", "Color", "", "#EC4899", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().tint; }},
      {"contrast", "Contrast", "Color", "", "#A78BFA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().contrast; }},
      {"pivot", "Pivot", "Color", "", "#A78BFA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().pivot; }},
      {"midDetail", "Mid Detail", "Color", "", "#A78BFA",
       PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().midDetail; }},
      {"colorBoost", "Color Boost", "Color", "", "#A78BFA",
       PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().colorBoost; }},
      {"shadows", "Shadows", "Color", "", "#64748B", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().shadows; }},
      {"highlights", "Highlights", "Color", "", "#F8FAFC",
       PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().highlights; }},
      {"saturation", "Saturation", "Color", "", "#F472B6",
       PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().saturation; }},
      {"hue", "Hue", "Color", "", "#C084FC", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().hue; }},
      {"lumMix", "Lum Mix", "Color", "", "#94A3B8", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.getColor().lumMix; }},

      // Audio
      {"volume", "Volume", "Audio", "", "#06B6D4", PropertyCategory::Audio,
       [](TimelineClip &c) { return &c.getAudio().volume; }},
      {"pan", "Pan", "Audio", "", "#F97316", PropertyCategory::Audio,
       [](TimelineClip &c) { return &c.getAudio().pan; }},
  };
  return registry;
}

const PropertyDescriptor *findPropertyDescriptor(const QString &id) {
  for (const auto &desc : propertyRegistry()) {
    if (desc.id == id)
      return &desc;
  }
  return nullptr;
}

} // namespace xyla::anim
