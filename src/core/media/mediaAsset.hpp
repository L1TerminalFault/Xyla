#pragma once

#include "mediaData.hpp"
#include "xylaAsset.hpp"

namespace xyla {

class MediaAsset : public XylaAsset {
public:
  MediaAsset(QString id, QString name, MediaMetadata metadata)
      : XylaAsset(std::move(id), std::move(name), AssetKind::Media),
        m_metadata(std::move(metadata)) {}

  const MediaMetadata &metadata() const { return m_metadata; }

  QVariantMap toVariantMap() const override {
    QVariantMap map = XylaAsset::toVariantMap();
    map["metadata"] = m_metadata.toVariantMap();
    return map;
  }

private:
  MediaMetadata m_metadata;
};

} // namespace xyla
