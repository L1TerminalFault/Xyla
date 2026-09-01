#include "shortcutManager.hpp"
#include "presets/adobePremierePreset.hpp"
#include "presets/avidMediaComposerPreset.hpp"
#include "presets/davinciResolvePreset.hpp"
#include "presets/finalCutProPreset.hpp"
#include "presets/xylaDefaultPreset.hpp"

#include <algorithm>

namespace xyla {

ShortcutManager::ShortcutManager(QObject *parent) : QObject(parent) {
  buildPresetRegistry();
  applyPreset("Xyla Default");
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
  }
}

void ShortcutManager::setActivePresetName(const QString &presetName) {
  if (m_activePresetName != presetName && m_presets.count(presetName)) {
    m_activePresetName = presetName;
    applyPreset(m_activePresetName);
    emit activePresetNameChanged(m_activePresetName);
  }
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

QString ShortcutManager::getKeySequence(const QString &actionId) const {
  auto it = m_actions.find(actionId);
  if (it != m_actions.end()) {
    return it->second.currentKey;
  }
  return "";
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
    emit shortcutsChanged();
    return true;
  }
  return false;
}

bool ShortcutManager::resetActionToDefault(const QString &actionId) {
  auto it = m_actions.find(actionId);
  if (it != m_actions.end()) {
    it->second.currentKey = it->second.defaultKey;
    m_presets[m_activePresetName][actionId] = it->second.defaultKey;
    emit shortcutsChanged();
    return true;
  }
  return false;
}

void ShortcutManager::resetAllToDefault() {
  for (auto &[_, action] : m_actions) {
    action.currentKey = action.defaultKey;
  }
  emit shortcutsChanged();
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

} // namespace xyla
