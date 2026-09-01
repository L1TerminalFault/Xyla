#pragma once

#include "core/actions/xylaActionManager.hpp"
#include "core/actions/xylaMenuItemData.hpp"
#include <QObject>
#include <QVariantList>
#include <vector>

namespace xyla {

class MenuManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(QVariantList menuTree READ menuTree NOTIFY menuTreeChanged)

public:
  explicit MenuManager(XylaActionManager *actionManager,
                       QObject *parent = nullptr);
  ~MenuManager() override = default;

  void registerMenuItem(const QString &menuPath, const XylaActionData &action);
  void registerSeparator(const QString &menuPath);

  Q_INVOKABLE void triggerAction(const QString &actionId);

  QVariantList menuTree() const { return m_cachedMenuTree; }

public slots:
  void rebuildMenuTree();

signals:
  void menuTreeChanged();

  void requestNewProject();
  void requestOpenProject();
  void requestSaveProject();
  void requestUndo();
  void requestRedo();
  void requestPreferences();
  void requestKeyboardShortcuts();

private:
  void setupDefaultActions();

  XylaActionManager *m_actionManager{nullptr};
  std::vector<XylaMenuItemData> m_menuStructure;
  QVariantList m_cachedMenuTree;
};

} // namespace xyla
