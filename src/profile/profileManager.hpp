#pragma once

#include <QHash>
#include <QObject>
#include <QStandardItemModel>

class ProfileManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(QStandardItemModel *model READ model NOTIFY modelChanged)

public:
  enum ProfileRoles {
    IsCategoryRole = Qt::UserRole + 1,
    WidthRole,
    HeightRole,
    DisplayAspectNumRole,
    DisplayAspectDenRole,
    PixelAspectNumRole,
    PixelAspectDenRole,
    FrameRateNumRole,
    FrameRateDenRole,
    ColorspaceRole,
    ScanningRole,
    FieldOrderRole
  };

  explicit ProfileManager(QObject *parent = nullptr);

  QStandardItemModel *model() const { return m_model; }

  Q_INVOKABLE void init();
  Q_INVOKABLE bool loadProfiles();

signals:
  void modelChanged();

private:
  QString getOrInitProfilePath();
  QStandardItemModel *m_model{nullptr};
};
