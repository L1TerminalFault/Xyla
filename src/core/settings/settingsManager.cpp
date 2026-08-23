#include "settingsManager.hpp"
#include "core/log/logger.hpp"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

namespace xyla {

SettingsManager::SettingsManager(QObject *parent) : QObject(parent) { load(); }

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
  obj["theme"] = m_data.theme;
  obj["uiScale"] = m_data.uiScale;
  obj["autoSaveEnabled"] = m_data.autoSaveEnabled;
  obj["autoSaveIntervalMinutes"] = m_data.autoSaveIntervalMinutes;
  obj["maxRecentProjects"] = m_data.maxRecentProjects;
  obj["reopenLastProjectOnStartup"] = m_data.reopenLastProjectOnStartup;

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
