#pragma once

#include "xylaSettingsData.hpp"
#include <QObject>

namespace xyla {

class SettingsManager;

extern SettingsManager *g_settingsManager;

class SettingsManager : public QObject {
  Q_OBJECT

  Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)
  Q_PROPERTY(double uiScale READ uiScale WRITE setUiScale NOTIFY uiScaleChanged)
  Q_PROPERTY(bool autoSaveEnabled READ autoSaveEnabled WRITE setAutoSaveEnabled
                 NOTIFY autoSaveEnabledChanged)
  Q_PROPERTY(
      int autoSaveIntervalMinutes READ autoSaveIntervalMinutes WRITE
          setAutoSaveIntervalMinutes NOTIFY autoSaveIntervalMinutesChanged)
  Q_PROPERTY(int maxRecentProjects READ maxRecentProjects WRITE
                 setMaxRecentProjects NOTIFY maxRecentProjectsChanged)
  Q_PROPERTY(bool reopenLastProjectOnStartup READ reopenLastProjectOnStartup
                 WRITE setReopenLastProjectOnStartup NOTIFY
                     reopenLastProjectOnStartupChanged)

  // NOTE: Timeline Settings
  Q_PROPERTY(xyla::ZoomAnchor::Mode zoomAnchorMode READ zoomAnchorMode WRITE
                 setZoomAnchorMode NOTIFY zoomAnchorModeChanged)

public:
  explicit SettingsManager(QObject *parent = nullptr);
  ~SettingsManager() override;

  void load();
  void save() const;

  [[nodiscard]] const XylaSettingsData &data() const { return m_data; }
  void updateData(const XylaSettingsData &newData);

  [[nodiscard]] QString theme() const { return m_data.theme; }
  [[nodiscard]] double uiScale() const { return m_data.uiScale; }
  [[nodiscard]] bool autoSaveEnabled() const { return m_data.autoSaveEnabled; }
  [[nodiscard]] int autoSaveIntervalMinutes() const {
    return m_data.autoSaveIntervalMinutes;
  }
  [[nodiscard]] int maxRecentProjects() const {
    return m_data.maxRecentProjects;
  }
  [[nodiscard]] bool reopenLastProjectOnStartup() const {
    return m_data.reopenLastProjectOnStartup;
  }
  [[nodiscard]] ZoomAnchor::Mode zoomAnchorMode() const {
    return m_data.zoomAnchorMode;
  }

  void setTheme(const QString &theme);
  void setUiScale(double scale);
  void setAutoSaveEnabled(bool enabled);
  void setAutoSaveIntervalMinutes(int minutes);
  void setMaxRecentProjects(int max);
  void setReopenLastProjectOnStartup(bool enable);
  void setZoomAnchorMode(ZoomAnchor::Mode mode);

signals:
  void settingsChanged(const xyla::XylaSettingsData &data);
  void themeChanged();
  void uiScaleChanged();
  void autoSaveEnabledChanged();
  void autoSaveIntervalMinutesChanged();
  void maxRecentProjectsChanged();
  void reopenLastProjectOnStartupChanged();
  void zoomAnchorModeChanged();

private:
  QString getSettingsFilePath() const;

  XylaSettingsData m_data;
};

} // namespace xyla
