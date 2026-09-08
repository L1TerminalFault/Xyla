#include "propertyDescriptor.hpp"
#include "core/timeline/timelineClip.hpp"

namespace xyla::anim {

const std::vector<PropertyDescriptor> &propertyRegistry() {
  static const std::vector<PropertyDescriptor> registry = {
      // ── Transform ──────────────────────────────────────────────
      {"positionX", "X", "Transform", "Position", "#EF4444",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.transform().posX; }},
      {"positionY", "Y", "Transform", "Position", "#22C55E",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.transform().posY; }},

      {"scaleX", "X", "Transform", "Scale", "#3B82F6",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.transform().scaleX; }},
      {"scaleY", "Y", "Transform", "Scale", "#3B82F6",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.transform().scaleY; }},

      {"rotation", "Rotation", "Transform", "", "#EAB308",
       PropertyCategory::Transform,
       [](TimelineClip &c) { return &c.transform().rotation; }},

      {"opacity", "Opacity", "Compositing", "", "#A855F7",
       PropertyCategory::Compositing,
       [](TimelineClip &c) { return &c.transform().opacity; }},

      // ── Color ──────────────────────────────────────────────────
      {"liftR", "R", "Color", "Lift", "#F87171", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().liftR; }},
      {"liftG", "G", "Color", "Lift", "#4ADE80", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().liftG; }},
      {"liftB", "B", "Color", "Lift", "#60A5FA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().liftB; }},

      {"gammaR", "R", "Color", "Gamma", "#F87171", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().gammaR; }},
      {"gammaG", "G", "Color", "Gamma", "#4ADE80", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().gammaG; }},
      {"gammaB", "B", "Color", "Gamma", "#60A5FA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().gammaB; }},

      {"gainR", "R", "Color", "Gain", "#F87171", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().gainR; }},
      {"gainG", "G", "Color", "Gain", "#4ADE80", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().gainG; }},
      {"gainB", "B", "Color", "Gain", "#60A5FA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().gainB; }},

      {"offsetR", "R", "Color", "Offset", "#F87171", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().offsetR; }},
      {"offsetG", "G", "Color", "Offset", "#4ADE80", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().offsetG; }},
      {"offsetB", "B", "Color", "Offset", "#60A5FA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().offsetB; }},

      {"temperature", "Temperature", "Color", "", "#F59E0B",
       PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().temperature; }},
      {"tint", "Tint", "Color", "", "#EC4899", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().tint; }},
      {"contrast", "Contrast", "Color", "", "#A78BFA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().contrast; }},
      {"pivot", "Pivot", "Color", "", "#A78BFA", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().pivot; }},
      {"midDetail", "Mid Detail", "Color", "", "#A78BFA",
       PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().midDetail; }},
      {"colorBoost", "Color Boost", "Color", "", "#A78BFA",
       PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().colorBoost; }},
      {"shadows", "Shadows", "Color", "", "#64748B", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().shadows; }},
      {"highlights", "Highlights", "Color", "", "#F8FAFC",
       PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().highlights; }},
      {"saturation", "Saturation", "Color", "", "#F472B6",
       PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().saturation; }},
      {"hue", "Hue", "Color", "", "#C084FC", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().hue; }},
      {"lumMix", "Lum Mix", "Color", "", "#94A3B8", PropertyCategory::Color,
       [](TimelineClip &c) { return &c.color().lumMix; }},

      // ── Audio ──────────────────────────────────────────────────
      {"volume", "Volume", "Audio", "", "#06B6D4", PropertyCategory::Audio,
       [](TimelineClip &c) { return &c.audio().volume; }},
      {"pan", "Pan", "Audio", "", "#F97316", PropertyCategory::Audio,
       [](TimelineClip &c) { return &c.audio().pan; }},
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
