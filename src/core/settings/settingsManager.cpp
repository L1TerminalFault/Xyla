#include "settingsManager.hpp"
#include "core/log/logger.hpp"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

namespace xyla {

// NOTE: Exposing the main settings pool for other settings flows
SettingsManager *g_settingsManager = nullptr;

SettingsManager::SettingsManager(QObject *parent) : QObject(parent) {
  if (!g_settingsManager) {
    g_settingsManager = this;
  }
  load();
}

SettingsManager::~SettingsManager() {
  if (g_settingsManager == this) {
    g_settingsManager = nullptr;
  }
}

QString SettingsManager::getSettingsFilePath() const {
  QString configDir =
      QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
  QDir().mkpath(configDir);
  return configDir + "/settings.json";
}

void SettingsManager::load() {
  QString path = getSettingsFilePath();
  QFile file(path);

  if (!file.exists()) {
    XYLA_LOG_INFO("Settings", "No settings file found. Writing defaults to " +
                                  path.toStdString());
    save();
    return;
  }

  if (!file.open(QIODevice::ReadOnly)) {
    XYLA_LOG_WARN("Settings", "Failed to open settings file for reading: " +
                                  path.toStdString());
    return;
  }

  QByteArray data = file.readAll();
  file.close();

  QJsonDocument doc = QJsonDocument::fromJson(data);
  if (!doc.isObject()) {
    XYLA_LOG_WARN("Settings", "Settings file corrupt. Restoring defaults.");
    save();
    return;
  }

  QJsonObject obj = doc.object();
  XylaSettingsData loadedData;

  // NOTE: General Main Settings fields start here
  if (obj.contains("theme"))
    loadedData.theme = obj["theme"].toString(m_data.theme);
  if (obj.contains("uiScale"))
    loadedData.uiScale = obj["uiScale"].toDouble(m_data.uiScale);
  if (obj.contains("autoSaveEnabled"))
    loadedData.autoSaveEnabled =
        obj["autoSaveEnabled"].toBool(m_data.autoSaveEnabled);
  if (obj.contains("autoSaveIntervalMinutes"))
    loadedData.autoSaveIntervalMinutes =
        obj["autoSaveIntervalMinutes"].toInt(m_data.autoSaveIntervalMinutes);
  if (obj.contains("maxRecentProjects"))
    loadedData.maxRecentProjects =
        obj["maxRecentProjects"].toInt(m_data.maxRecentProjects);
  if (obj.contains("reopenLastProjectOnStartup"))
    loadedData.reopenLastProjectOnStartup =
        obj["reopenLastProjectOnStartup"].toBool(
            m_data.reopenLastProjectOnStartup);
  // NOTE: General Main Settings fields end here

  // NOTE: File Manager Settings fields start here
  if (obj.contains("startupLocation"))
    loadedData.startupLocation =
        obj["startupLocation"].toString(m_data.startupLocation);
  if (obj.contains("defaultView"))
    loadedData.defaultView = obj["defaultView"].toString(m_data.defaultView);
  if (obj.contains("rememberLastFolder"))
    loadedData.rememberLastFolder =
        obj["rememberLastFolder"].toBool(m_data.rememberLastFolder);
  if (obj.contains("confirmDelete"))
    loadedData.confirmDelete =
        obj["confirmDelete"].toBool(m_data.confirmDelete);
  if (obj.contains("smoothAnimations"))
    loadedData.smoothAnimations =
        obj["smoothAnimations"].toBool(m_data.smoothAnimations);
  if (obj.contains("showHiddenFiles"))
    loadedData.showHiddenFiles =
        obj["showHiddenFiles"].toBool(m_data.showHiddenFiles);
  if (obj.contains("showFileExtensions"))
    loadedData.showFileExtensions =
        obj["showFileExtensions"].toBool(m_data.showFileExtensions);
  if (obj.contains("sortMode"))
    loadedData.sortMode = obj["sortMode"].toString(m_data.sortMode);
  if (obj.contains("openFoldersWithDoubleClick"))
    loadedData.openFoldersWithDoubleClick =
        obj["openFoldersWithDoubleClick"].toBool(
            m_data.openFoldersWithDoubleClick);
  if (obj.contains("showTooltips"))
    loadedData.showTooltips = obj["showTooltips"].toBool(m_data.showTooltips);
  // NOTE: File Manager Settings fields end here

  // NOTE: Timeline Settings fields start here
  if (obj.contains("zoomAnchorMode")) {
    int modeInt =
        obj["zoomAnchorMode"].toInt(static_cast<int>(m_data.zoomAnchorMode));
    if (modeInt >= 0 && modeInt <= static_cast<int>(ZoomAnchor::CenterOfView)) {
      loadedData.zoomAnchorMode = static_cast<ZoomAnchor::Mode>(modeInt);
    }
  }
  // NOTE: Timeline Settings fields end here

  // NOTE: Media Panel Settings fields start here
  if (obj.contains("mediaPanelSortMode"))
    loadedData.mediaPanelSortMode =
        obj["mediaPanelSortMode"].toString(m_data.mediaPanelSortMode);
  if (obj.contains("mediaPanelShowFileExtensions"))
    loadedData.mediaPanelShowFileExtensions =
        obj["mediaPanelShowFileExtensions"].toBool(
            m_data.mediaPanelShowFileExtensions);
  if (obj.contains("mediaPanelDefaultView"))
    loadedData.mediaPanelDefaultView =
        obj["mediaPanelDefaultView"].toString(m_data.mediaPanelDefaultView);
  if (obj.contains("mediaPanelHoverScrub"))
    loadedData.mediaPanelHoverScrub =
        obj["mediaPanelHoverScrub"].toBool(m_data.mediaPanelHoverScrub);
  if (obj.contains("mediaPanelShowWaveforms"))
    loadedData.mediaPanelShowWaveforms =
        obj["mediaPanelShowWaveforms"].toBool(m_data.mediaPanelShowWaveforms);
  if (obj.contains("mediaPanelShowTooltips"))
    loadedData.mediaPanelShowTooltips =
        obj["mediaPanelShowTooltips"].toBool(m_data.mediaPanelShowTooltips);
  // NOTE: Media Panel Settings fields end here

  m_data = loadedData;
  XYLA_LOG_INFO("Settings",
                "Settings successfully loaded from " + path.toStdString());
}

void SettingsManager::save() const {
  QString path = getSettingsFilePath();
  QFile file(path);

  if (!file.open(QIODevice::WriteOnly)) {
    XYLA_LOG_ERROR("Settings", "Failed to open settings file for writing: " +
                                   path.toStdString());
    return;
  }

  QJsonObject obj;

  // NOTE: General Main Settings fields start here
  obj["theme"] = m_data.theme;
  obj["uiScale"] = m_data.uiScale;
  obj["autoSaveEnabled"] = m_data.autoSaveEnabled;
  obj["autoSaveIntervalMinutes"] = m_data.autoSaveIntervalMinutes;
  obj["maxRecentProjects"] = m_data.maxRecentProjects;
  obj["reopenLastProjectOnStartup"] = m_data.reopenLastProjectOnStartup;
  // NOTE: General Main Settings fields end here

  // NOTE: File Manager Settings fields start here
  obj["startupLocation"] = m_data.startupLocation;
  obj["defaultView"] = m_data.defaultView;
  obj["rememberLastFolder"] = m_data.rememberLastFolder;
  obj["confirmDelete"] = m_data.confirmDelete;
  obj["smoothAnimations"] = m_data.smoothAnimations;
  obj["showHiddenFiles"] = m_data.showHiddenFiles;
  obj["showFileExtensions"] = m_data.showFileExtensions;
  obj["sortMode"] = m_data.sortMode;
  obj["openFoldersWithDoubleClick"] = m_data.openFoldersWithDoubleClick;
  obj["showTooltips"] = m_data.showTooltips;
  // NOTE: File Manager Settings fields end here
  // NOTE: Timeline Settings fields start here
  obj["zoomAnchorMode"] = static_cast<int>(m_data.zoomAnchorMode);
  // NOTE: Timeline Settings fields end here

  // NOTE: Media Panel Settings fields start here
  obj["mediaPanelSortMode"] = m_data.mediaPanelSortMode;
  obj["mediaPanelShowFileExtensions"] = m_data.mediaPanelShowFileExtensions;
  obj["mediaPanelDefaultView"] = m_data.mediaPanelDefaultView;
  obj["mediaPanelHoverScrub"] = m_data.mediaPanelHoverScrub;
  obj["mediaPanelShowWaveforms"] = m_data.mediaPanelShowWaveforms;
  obj["mediaPanelShowTooltips"] = m_data.mediaPanelShowTooltips;
  // NOTE: Media Panel Settings fields end here

  QJsonDocument doc(obj);
  file.write(doc.toJson(QJsonDocument::Indented));
  file.close();

  XYLA_LOG_INFO("Settings", "Settings saved to " + path.toStdString());
}

void SettingsManager::updateData(const XylaSettingsData &newData) {
  if (m_data == newData)
    return;

  bool themeChangedFlag = (m_data.theme != newData.theme);
  bool uiScaleChangedFlag = (!qFuzzyCompare(m_data.uiScale, newData.uiScale));
  bool autoSaveEnabledChangedFlag =
      (m_data.autoSaveEnabled != newData.autoSaveEnabled);
  bool autoSaveIntervalChangedFlag =
      (m_data.autoSaveIntervalMinutes != newData.autoSaveIntervalMinutes);
  bool maxRecentChangedFlag =
      (m_data.maxRecentProjects != newData.maxRecentProjects);
  bool reopenStartupChangedFlag =
      (m_data.reopenLastProjectOnStartup != newData.reopenLastProjectOnStartup);
  bool zoomAnchorChangedFlag =
      (m_data.zoomAnchorMode != newData.zoomAnchorMode);
  m_data = newData;
  save();

  emit settingsChanged(m_data);
  if (themeChangedFlag)
    emit themeChanged();
  if (uiScaleChangedFlag)
    emit uiScaleChanged();
  if (autoSaveEnabledChangedFlag)
    emit autoSaveEnabledChanged();
  if (autoSaveIntervalChangedFlag)
    emit autoSaveIntervalMinutesChanged();
  if (maxRecentChangedFlag)
    emit maxRecentProjectsChanged();
  if (reopenStartupChangedFlag)
    emit reopenLastProjectOnStartupChanged();
  if (zoomAnchorChangedFlag)
    emit zoomAnchorModeChanged();
}

void SettingsManager::setZoomAnchorMode(ZoomAnchor::Mode mode) {
  if (m_data.zoomAnchorMode != mode) {
    m_data.zoomAnchorMode = mode;
    emit zoomAnchorModeChanged();
    emit settingsChanged(m_data);
    save();
  }
}

void SettingsManager::setTheme(const QString &theme) {
  if (m_data.theme != theme) {
    m_data.theme = theme;
    emit themeChanged();
    emit settingsChanged(m_data);
    save();
  }
}

void SettingsManager::setUiScale(double scale) {
  if (!qFuzzyCompare(m_data.uiScale, scale)) {
    m_data.uiScale = scale;
    emit uiScaleChanged();
    emit settingsChanged(m_data);
    save();
  }
}

void SettingsManager::setAutoSaveEnabled(bool enabled) {
  if (m_data.autoSaveEnabled != enabled) {
    m_data.autoSaveEnabled = enabled;
    emit autoSaveEnabledChanged();
    emit settingsChanged(m_data);
    save();
  }
}

void SettingsManager::setAutoSaveIntervalMinutes(int minutes) {
  if (m_data.autoSaveIntervalMinutes != minutes) {
    m_data.autoSaveIntervalMinutes = minutes;
    emit autoSaveIntervalMinutesChanged();
    emit settingsChanged(m_data);
    save();
  }
}

void SettingsManager::setMaxRecentProjects(int max) {
  if (m_data.maxRecentProjects != max) {
    m_data.maxRecentProjects = max;
    emit maxRecentProjectsChanged();
    emit settingsChanged(m_data);
    save();
  }
}

void SettingsManager::setReopenLastProjectOnStartup(bool enable) {
  if (m_data.reopenLastProjectOnStartup != enable) {
    m_data.reopenLastProjectOnStartup = enable;
    emit reopenLastProjectOnStartupChanged();
    emit settingsChanged(m_data);
    save();
  }
}

} // namespace xyla
