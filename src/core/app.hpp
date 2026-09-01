#pragma once

#include "core/settings/shortcutManager.hpp"
#include <memory>
#include <string>

// Qt Forward Declarations
class QGuiApplication;
class QQmlApplicationEngine;
class QQuickWindow;

// Global Subsystem Forward Declarations
class WorkspaceLayoutController;
class ProfileManager;

namespace xyla {

enum class ErrorCode {
  None = 0,
  EnvironmentSetupFailed,
  QtAppInitFailed,
  SubsystemAllocationFailed,
  QmlEngineLoadFailed,
  GPUInitializationFailed
};

class MediaPool;
class MediaBinModel;
class XylaUndoStack;
class SettingsManager;
class ProjectManager;
class FileSystemModel;
class XylaActionManager;
class MenuManager;
class PlaybackManager;
class TimelineModel;
class TimelineCompositor;
class XylaAsset;

namespace render {
class XylaRenderer;
class VideoFrameCache;
class FramePrefetcher;
} // namespace render

class App {
public:
  // Phase 1: Trivial constructor (Zero allocations, zero failure points)
  App() noexcept;

  // Non-copyable, non-movable application lifecycle owner
  App(const App &) = delete;
  App &operator=(const App &) = delete;
  App(App &&) = delete;
  App &operator=(App &&) = delete;

  ~App();

  // Phase 2: Explicit boot pipeline returning ErrorCode enum
  [[nodiscard]] ErrorCode init(int &argc, char **argv);

  // Enters Qt event loop (Only called if init() returns ErrorCode::None)
  int run();

private:
  // Internal Boot Phase Helpers
  [[nodiscard]] ErrorCode setupEnvironment();
  [[nodiscard]] ErrorCode initQtApplication(int &argc, char **argv);
  [[nodiscard]] ErrorCode initCoreSubsystems();
  [[nodiscard]] ErrorCode setupUIEngine();
  [[nodiscard]] ErrorCode bindVulkanDevice(QQuickWindow *window);
  void startBackgroundServices() noexcept;

  // Qt Core
  std::unique_ptr<QGuiApplication> m_qtApp;
  std::unique_ptr<QQmlApplicationEngine> m_qmlEngine;

  // Core Managers & Models
  std::unique_ptr<MediaPool> m_mediaPool;
  std::unique_ptr<MediaBinModel> m_mediaBinModel;
  std::unique_ptr<XylaUndoStack> m_undoStack;
  std::unique_ptr<SettingsManager> m_settingsManager;
  std::unique_ptr<ProjectManager> m_projectManager;
  std::unique_ptr<FileSystemModel> m_fileSystemModel;
  std::unique_ptr<XylaActionManager> m_actionManager;
  std::unique_ptr<MenuManager> m_menuManager;
  std::unique_ptr<WorkspaceLayoutController> m_layoutController;
  std::unique_ptr<ProfileManager> m_profileManager;
  std::unique_ptr<PlaybackManager> m_playbackManager;
  std::unique_ptr<TimelineModel> m_timelineModel;
  std::unique_ptr<TimelineCompositor> m_timelineCompositor;
  std::unique_ptr<ShortcutManager> m_shortcutManager;

  bool m_initialized{false};
};

} // namespace xyla
