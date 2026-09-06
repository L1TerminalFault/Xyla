#include "shortcutManager.hpp"
#include "core/log/logger.hpp"
#include "core/settings/shortcutData.hpp"
#include "presets/adobePremierePreset.hpp"
#include "presets/avidMediaComposerPreset.hpp"
#include "presets/davinciResolvePreset.hpp"
#include "presets/finalCutProPreset.hpp"
#include "presets/xylaDefaultPreset.hpp"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

namespace xyla {

ShortcutManager::ShortcutManager(QObject *parent) : QObject(parent) {
  buildPresetRegistry();
  loadCustomShortcuts();
  applyPreset(m_activePresetName);
}

void ShortcutManager::buildPresetRegistry() {
  auto catalog = getMasterActionCatalog();
  for (const auto &action : catalog) {
    m_actionOrder.push_back(action.id);
    m_actions[action.id] = action;
  }

  m_presets["Xyla Default"] = presets::getXylaDefaultPreset();
  m_presets["DaVinci Resolve"] = presets::getDaVinciResolvePreset();
  m_presets["Adobe Premiere Pro"] = presets::getAdobePremierePreset();
  m_presets["Apple Final Cut Pro"] = presets::getFinalCutProPreset();
  m_presets["Avid Media Composer"] = presets::getAvidMediaComposerPreset();
}

void ShortcutManager::applyPreset(const QString &presetName) {
  auto it = m_presets.find(presetName);
  if (it != m_presets.end()) {
    for (const auto &[actionId, keySeq] : it->second) {
      if (m_actions.count(actionId)) {
        m_actions[actionId].currentKey = keySeq;
      }
    }
    emit shortcutsChanged();
    emit presetApplied();
  }
}

void ShortcutManager::setActivePresetName(const QString &presetName) {
  if (m_activePresetName != presetName && m_presets.count(presetName)) {
    m_activePresetName = presetName;
    applyPreset(m_activePresetName);
    saveCustomShortcuts();
    emit activePresetNameChanged(m_activePresetName);
  }
}

QString ShortcutManager::getShortcut(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  return (it != m_actions.end()) ? it->second.currentKey : QString();
}

QStringList ShortcutManager::availablePresets() const {
  QStringList list;
  for (const auto &[name, _] : m_presets) {
    list.append(name);
  }
  list.sort();
  return list;
}

QVariantList ShortcutManager::getAllActions() const {
  QVariantList list;
  for (const auto &id : m_actionOrder) {
    if (m_actions.count(id)) {
      list.append(m_actions.at(id).toVariantMap());
    }
  }
  return list;
}

QVariantMap ShortcutManager::shortcutMap() const {
  QVariantMap map;
  for (const auto &[id, action] : m_actions) {
    map[id] = action.currentKey;
  }
  return map;
}

bool ShortcutManager::setKeySequence(const QString &actionId,
                                     const QString &keySequence) {
  auto it = m_actions.find(actionId);
  if (it != m_actions.end()) {
    it->second.currentKey = keySequence;
    m_presets[m_activePresetName][actionId] = keySequence;
    saveCustomShortcuts();
    emit shortcutsChanged();
    emit presetApplied();
    return true;
  }
  return false;
}

bool ShortcutManager::resetActionToDefault(const QString &actionId) {
  auto it = m_actions.find(actionId);
  if (it != m_actions.end()) {
    return setKeySequence(actionId, it->second.defaultKey);
  }
  return false;
}

void ShortcutManager::resetAllToDefault() {
  for (auto &[_, action] : m_actions) {
    action.currentKey = action.defaultKey;
  }
  saveCustomShortcuts();
  emit shortcutsChanged();
  emit presetApplied();
}

bool ShortcutManager::createCustomPreset(const QString &newPresetName,
                                         const QString &basePresetName) {
  if (newPresetName.isEmpty() || m_presets.count(newPresetName))
    return false;

  std::unordered_map<QString, QString> baseKeys;
  if (m_presets.count(basePresetName)) {
    baseKeys = m_presets[basePresetName];
  } else {
    baseKeys = presets::getXylaDefaultPreset();
  }

  m_presets[newPresetName] = baseKeys;
  setActivePresetName(newPresetName);
  emit availablePresetsChanged();
  return true;
}

bool ShortcutManager::deleteCustomPreset(const QString &presetName) {
  if (presetName == "Xyla Default" || presetName == "DaVinci Resolve" ||
      presetName == "Adobe Premiere Pro" ||
      presetName == "Apple Final Cut Pro" ||
      presetName == "Avid Media Composer") {
    return false;
  }

  m_presets.erase(presetName);
  setActivePresetName("Xyla Default");
  emit availablePresetsChanged();
  return true;
}

QString
ShortcutManager::findConflictingAction(const QString &actionId,
                                       const QString &keySequence) const {
  if (keySequence.isEmpty())
    return "";

  for (const auto &[id, action] : m_actions) {
    if (id != actionId &&
        action.currentKey.compare(keySequence, Qt::CaseInsensitive) == 0) {
      return action.name;
    }
  }
  return "";
}

QString ShortcutManager::getCustomShortcutsFilePath() const {
  QString configDir =
      QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
  QDir().mkpath(configDir);
  return configDir + "/shortcuts.json";
}

void ShortcutManager::loadCustomShortcuts() {
  QFile file(getCustomShortcutsFilePath());
  if (!file.open(QIODevice::ReadOnly))
    return;

  QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
  file.close();

  if (!doc.isObject())
    return;

  QJsonObject root = doc.object();
  if (root.contains("activePreset")) {
    m_activePresetName = root["activePreset"].toString();
  }

  if (root.contains("customPresets") && root["customPresets"].isObject()) {
    QJsonObject customPresets = root["customPresets"].toObject();
    for (auto presetIt = customPresets.begin(); presetIt != customPresets.end();
         ++presetIt) {
      QJsonObject mapObj = presetIt.value().toObject();
      std::unordered_map<QString, QString> keyMap;
      for (auto keyIt = mapObj.begin(); keyIt != mapObj.end(); ++keyIt) {
        keyMap[keyIt.key()] = keyIt.value().toString();
      }
      m_presets[presetIt.key()] = keyMap;
    }
  }
}

void ShortcutManager::saveCustomShortcuts() const {
  QFile file(getCustomShortcutsFilePath());
  if (!file.open(QIODevice::WriteOnly)) {
    XYLA_LOG_ERROR("ShortcutManager", "Failed to save shortcuts: " +
                                          file.fileName().toStdString());
    return;
  }

  QJsonObject root;
  root["activePreset"] = m_activePresetName;

  QJsonObject customPresets;
  for (const auto &[name, keyMap] : m_presets) {
    QJsonObject mapObj;
    for (const auto &[actionId, keySeq] : keyMap) {
      mapObj[actionId] = keySeq;
    }
    customPresets[name] = mapObj;
  }
  root["customPresets"] = customPresets;

  file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
  file.close();
}

} // namespace xyla
