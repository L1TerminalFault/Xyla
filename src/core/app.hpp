#pragma once

#include "core/media/mediaPool.hpp"
#include "core/media/thumbnailGenerator.hpp"
#include "core/settings/settingsManager.hpp"
#include "core/timeline/playback/playbackManager.hpp"
#include "core/timeline/timelineCompositor.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "profile/profileManager.hpp"
#include "project/fileSystemManager.hpp"
#include "project/projectManager.hpp"
#include "ui/menu/xylaMenuManager.hpp"
#include "ui/models/mediaBinModel.hpp"
#include "ui/models/timelineModel.hpp"
#include "ui/workspaceLayoutController.hpp"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <memory>

class App : public QObject {
  Q_OBJECT
public:
  App(int &argc, char **argv);
  ~App() = default;

  App(const App &) = delete;
  App &operator=(const App &) = delete;
  App(App &&) = delete;
  App &operator=(App &&) = delete;

  [[nodiscard]] int run();

private:
  std::unique_ptr<QGuiApplication> m_qtApp;

  std::unique_ptr<xyla::MediaPool> m_mediaPool;
  std::unique_ptr<xyla::MediaBinModel> m_mediaBinModel;
  std::unique_ptr<xyla::XylaUndoStack> m_undoStack;
  std::unique_ptr<xyla::SettingsManager> m_settingsManager;
  std::unique_ptr<xyla::ProjectManager> m_projectManager;
  std::unique_ptr<xyla::PlaybackManager> m_playbackManager;
  std::unique_ptr<xyla::TimelineModel> m_timelineModel;
  std::unique_ptr<ProfileManager> m_profileManager;
  std::unique_ptr<xyla::FileSystemModel> m_fileSystemModel;
  std::unique_ptr<xyla::XylaActionManager> m_actionManager;
  std::unique_ptr<xyla::MenuManager> m_menuManager;
  std::unique_ptr<WorkspaceLayoutController> m_layoutController;
  std::unique_ptr<xyla::TimelineCompositor> m_timelineCompositor;

  std::unique_ptr<QQmlApplicationEngine> m_qmlEngine;
};
