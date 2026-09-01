#pragma once

#include "shortcutData.hpp"
#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <unordered_map>
#include <vector>

namespace xyla {

class ShortcutManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString activePresetName READ activePresetName WRITE
                 setActivePresetName NOTIFY activePresetNameChanged)
  Q_PROPERTY(QStringList availablePresets READ availablePresets NOTIFY
                 availablePresetsChanged)

  // EXPOSE READ-ONLY MAP BINDING
  Q_PROPERTY(QVariantMap shortcutMap READ shortcutMap NOTIFY shortcutsChanged)

public:
  explicit ShortcutManager(QObject *parent = nullptr);
  ~ShortcutManager() override = default;

  [[nodiscard]] QString activePresetName() const noexcept {
    return m_activePresetName;
  }
  void setActivePresetName(const QString &presetName);
  [[nodiscard]] QStringList availablePresets() const;

  // Property Reader for QML Engine
  [[nodiscard]] QVariantMap shortcutMap() const;

  // QML Invokables
  Q_INVOKABLE QVariantList getAllActions() const;
  Q_INVOKABLE QString getKeySequence(const QString &actionId) const;
  Q_INVOKABLE bool setKeySequence(const QString &actionId,
                                  const QString &keySequence);
  Q_INVOKABLE bool resetActionToDefault(const QString &actionId);
  Q_INVOKABLE void resetAllToDefault();

  Q_INVOKABLE bool
  createCustomPreset(const QString &newPresetName,
                     const QString &basePresetName = "Xyla Default");
  Q_INVOKABLE bool deleteCustomPreset(const QString &presetName);
  Q_INVOKABLE QString findConflictingAction(const QString &actionId,
                                            const QString &keySequence) const;

signals:
  void activePresetNameChanged(const QString &presetName);
  void availablePresetsChanged();
  void shortcutsChanged();

private:
  void buildPresetRegistry();
  void applyPreset(const QString &presetName);

  QString m_activePresetName{"Xyla Default"};
  std::vector<QString> m_actionOrder;
  std::unordered_map<QString, ShortcutAction> m_actions;
  std::unordered_map<QString, std::unordered_map<QString, QString>> m_presets;
};

} // namespace xyla
