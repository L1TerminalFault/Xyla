#pragma once

#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <cstdint>
#include <vector>

namespace xyla::anim {

struct AnimChannelInfo {
  QString id;
  QString name;
  QString group;
  QString parent;
  QString color;
  bool isAnimated{false};
  bool hasKeyframeAtPlayhead{false};
  std::vector<int64_t> keyframeFrames;

  [[nodiscard]] QVariantMap toVariantMap() const {
    QVariantList frames;
    frames.reserve(static_cast<qsizetype>(keyframeFrames.size()));
    for (int64_t f : keyframeFrames)
      frames.append(static_cast<double>(f));

    return {{"id", id},
            {"name", name},
            {"group", group},
            {"parent", parent},
            {"color", color},
            {"isAnimated", isAnimated},
            {"hasKeyframe", hasKeyframeAtPlayhead},
            {"keyframes", frames}};
  }
};

} // namespace xyla::anim
