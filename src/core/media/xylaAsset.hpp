#pragma once

#include <QString>
#include <QVariantMap>

namespace xyla {

enum class AssetKind { Media, AudioDSPGraph, EffectPreset, Generator };

class XylaAsset {
public:
  XylaAsset(QString id, QString name, AssetKind kind)
      : m_id(std::move(id)), m_name(std::move(name)), m_kind(kind) {};

  virtual ~XylaAsset() = default;

  const QString &id() const { return m_id; }
  const QString &name() const { return m_name; }
  AssetKind kind() const { return m_kind; }

  virtual QVariantMap toVariantMap() const {
    return {{"id", m_id}, {"name", m_name}, {"kind", static_cast<int>(m_kind)}};
  }

private:
  QString m_id;
  QString m_name;
  AssetKind m_kind;
};
} // namespace xyla
