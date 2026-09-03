#include "timelineClip.hpp"
#include <qjsonobject.h>

namespace xyla {
QJsonObject TimelineClip::serialize() const {
  QJsonObject obj;
  obj["clipId"] = m_clipId;
  obj["assetId"] = m_assetId;
  obj["name"] = m_name;
  obj["startFrame"] = static_cast<qint64>(m_startFrame);
  obj["durationFrames"] = static_cast<qint64>(m_durationFrames);
  obj["sourceInFrame"] = static_cast<qint64>(m_sourceInFrame);
  obj["trackIndex"] = m_trackIndex;
  obj["speed"] = m_speed;
  obj["isMuted"] = m_isMuted;
  obj["isLocked"] = m_isLocked;
  obj["linkGroupId"] = m_linkGroupId;
  obj["blendMode"] = m_blendMode;

  // Inspector Transforms
  obj["positionX"] = m_positionX;
  obj["positionY"] = m_positionY;
  obj["scaleX"] = m_scaleX;
  obj["scaleY"] = m_scaleY;
  obj["opacity"] = m_opacity;

  return obj;
}

TimelineClip TimelineClip::deserialize(const QJsonObject &obj) {
  QString clipId = obj.value("clipId").toString();
  QString assetId = obj.value("assetId").toString();
  QString name = obj.value("name").toString("Clip");
  FrameIndex startFrame =
      static_cast<FrameIndex>(obj.value("startFrame").toInteger(0));
  FrameIndex durationFrames =
      static_cast<FrameIndex>(obj.value("durationFrames").toInteger(30));
  FrameIndex sourceInFrame =
      static_cast<FrameIndex>(obj.value("sourceInFrame").toInteger(0));
  int trackIndex = obj.value("trackIndex").toInt(0);

  TimelineClip clip(clipId, assetId, name, startFrame, durationFrames,
                    sourceInFrame, trackIndex);

  clip.setSpeed(obj.value("speed").toDouble(1.0));
  clip.setMuted(obj.value("isMuted").toBool(false));
  clip.setLocked(obj.value("isLocked").toBool(false));
  clip.setLinkGroupId(obj.value("linkGroupId").toString());
  clip.setBlendMode(obj.value("blendMode").toInt(0));

  clip.setTransform(
      obj.value("positionX").toDouble(0.0),
      obj.value("positionY").toDouble(0.0), obj.value("scaleX").toDouble(1.0),
      obj.value("scaleY").toDouble(1.0), obj.value("opacity").toDouble(1.0));

  return clip;
}
} // namespace xyla
