#pragma once

#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <cstdint>
#include <qcoreapplication.h>
#include <vector>

namespace xyla::anim {

struct KeyframeDetail {
  int64_t frame{0};
  float value{0.0f};
  int interpolation{1}; // 0: Hold, 1: Linear, 2: Bezier
  float inX{0.33f};
  float inY{0.0f};
  float outX{0.33f};
  float outY{0.0f};

  [[nodiscard]] QVariantMap toVariantMap() const {
    return {
        {"frame", static_cast<double>(frame)},
        {"value", static_cast<double>(value)},
        {"interp", interpolation},
        {"inX", static_cast<double>(inX)},
        {"inY", static_cast<double>(inY)},
        {"outX", static_cast<double>(outX)},
        {"outY", static_cast<double>(outY)},
    };
  }
};

struct AnimChannelInfo {
  QString scopeId;
  QString id;
  QString name;
  QString group;
  QString parent;
  QString color;
  bool isAnimated{false};
  bool hasKeyframeAtPlayhead{false};
  std::vector<int64_t> keyframeFrames;
  std::vector<KeyframeDetail> details;

  [[nodiscard]] QVariantMap toVariantMap() const {
    QVariantList frames;
    frames.reserve(static_cast<qsizetype>(keyframeFrames.size()));
    for (int64_t f : keyframeFrames)
      frames.append(static_cast<double>(f));

    QVariantList detailList;
    detailList.reserve(static_cast<qsizetype>(details.size()));
    for (const auto &d : details)
      detailList.append(d.toVariantMap());

    return {{"clipId", scopeId},
            {"id", id},
            {"name", name},
            {"group", group},
            {"parent", parent},
            {"color", color},
            {"isAnimated", isAnimated},
            {"hasKeyframe", hasKeyframeAtPlayhead},
            {"keyframes", frames},
            {"details", detailList}};
  }
};
;

} // namespace xyla::anim
