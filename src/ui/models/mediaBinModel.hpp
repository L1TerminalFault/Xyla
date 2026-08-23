#pragma once

#include "core/media/mediaAsset.hpp"
#include "core/media/mediaPool.hpp"
#include <QAbstractListModel>
#include <vector>

namespace xyla {

struct BinItem {
  QString id;
  QString name;
  QString path;
  double durationSec{0.0};
  QString resolution;
};

class MediaBinModel : public QAbstractListModel {
  Q_OBJECT

public:
  enum Roles {
    IdRole = Qt::UserRole + 1,
    NameRole,
    PathRole,
    DurationRole,
    ResolutionRole
  };

  explicit MediaBinModel(MediaPool *pool, QObject *parent = nullptr);
  ~MediaBinModel() override = default;

  [[nodiscard]] int
  rowCount(const QModelIndex &parent = QModelIndex()) const override;
  [[nodiscard]] QVariant data(const QModelIndex &index,
                              int role = Qt::DisplayRole) const override;
  [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

public slots:
  void onAssetImported(const QString &binId,
                       std::shared_ptr<xyla::MediaAsset> asset);

private:
  MediaPool *m_pool{nullptr};
  std::vector<BinItem> m_items;
};

} // namespace xyla
