#include "app.hpp"
#include "core/actions/xylaActionManager.hpp"
#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "core/media/iDecoder.hpp"
#include "core/media/mediaPool.hpp"
#include "core/render/framePrefetcher.hpp"
#include "core/render/videoFrameCache.hpp"
#include "core/render/xylaRenderer.hpp"
#include "core/render/xylaVideoSurface.hpp"
#include "core/settings/settingsManager.hpp"
#include "core/timeline/playback/playbackManager.hpp"
#include "core/timeline/timelineCompositor.hpp"
#include "core/undo/xylaUndoStack.hpp"
#include "media/mediaThumbnailProvider.hpp"
#include "profile/profileManager.hpp"
#include "project/fileSystemManager.hpp"
#include "project/projectManager.hpp"
#include "project/recentProjectModel.hpp"
#include "ui/menu/xylaMenuManager.hpp"
#include "ui/models/mediaBinModel.hpp"
#include "ui/models/timelineModel.hpp"
#include "ui/workspaceLayoutController.hpp"
#include "workspace/xylaViewFactory.hpp"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickGraphicsDevice>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QStyleHints>
#include <QUrl>
#include <QVulkanInstance>
#include <kddockwidgets/Config.h>
#include <kddockwidgets/qtquick/Platform.h>
#include <memory>

namespace xyla {

App::App() noexcept = default;

App::~App() {
  render::FramePrefetcher::instance().stop();

  if (m_qmlEngine) {
    m_qmlEngine.reset();
  }

  render::XylaRenderer::instance().cleanup();
  render::VideoFrameCache::instance().clear();

  m_timelineCompositor.reset();
  m_timelineModel.reset();
  m_playbackManager.reset();
  m_profileManager.reset();
  m_layoutController.reset();
  m_menuManager.reset();
  m_actionManager.reset();
  m_fileSystemModel.reset();
  m_projectManager.reset();
  m_settingsManager.reset();
  m_undoStack.reset();
  m_mediaBinModel.reset();
  m_mediaPool.reset();
}

ErrorCode App::init(int &argc, char **argv) {
  if (m_initialized) {
    return ErrorCode::None;
  }

  ErrorCode err = setupEnvironment();
  if (err != ErrorCode::None)
    return err;

  err = initQtApplication(argc, argv);
  if (err != ErrorCode::None)
    return err;

  err = initCoreSubsystems();
  if (err != ErrorCode::None)
    return err;

  err = setupUIEngine();
  if (err != ErrorCode::None)
    return err;

  m_initialized = true;
  return ErrorCode::None;
}

ErrorCode App::setupEnvironment() {
  qputenv("DRI_PRIME", "1");
  qputenv("MESA_VK_DEVICE_SELECT", "10de:*");
  qputenv("QML_ENABLE_DISK_CACHE", "1");

  if (QFile::exists("/usr/share/vulkan/icd.d/nvidia_icd.json")) {
    qputenv("VK_DRIVER_FILES", "/usr/share/vulkan/icd.d/nvidia_icd.json");
  }

  QQuickWindow::setGraphicsApi(QSGRendererInterface::GraphicsApi::Vulkan);
  return ErrorCode::None;
}

ErrorCode App::initQtApplication(int &argc, char **argv) {
  try {
    m_qtApp = std::make_unique<QGuiApplication>(argc, argv);
    m_qtApp->setOrganizationName("Xyla");
    m_qtApp->setApplicationName("xyla");
    QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Dark);
  } catch (...) {
    return ErrorCode::QtAppInitFailed;
  }

  return ErrorCode::None;
}

ErrorCode App::initCoreSubsystems() {
  try {
    render::VideoFrameCache::instance().setMaxVramMB(4500);

    render::XylaRenderer::instance().ensureInitialized();

    DecoderRegistry::instance().registerFactory(
        std::make_unique<VulkanDecoderFactory>());

    m_mediaPool = std::make_unique<MediaPool>();
    m_mediaBinModel = std::make_unique<MediaBinModel>(m_mediaPool.get());
    m_undoStack = std::make_unique<XylaUndoStack>();
    m_settingsManager = std::make_unique<SettingsManager>();
    m_projectManager = std::make_unique<ProjectManager>();
    m_projectManager->setMediaPool(m_mediaPool.get());
    m_shortcutManager = std::make_unique<ShortcutManager>();

    QObject::connect(m_mediaPool.get(), &MediaPool::assetImported,
                     m_projectManager.get(),
                     [this](const QString &, std::shared_ptr<XylaAsset>) {
                       m_projectManager->setHasUnsavedChanges(true);
                     });

    m_fileSystemModel = std::make_unique<FileSystemModel>();
    m_actionManager = std::make_unique<XylaActionManager>();
    m_menuManager = std::make_unique<MenuManager>(m_actionManager.get());
    m_layoutController = std::make_unique<WorkspaceLayoutController>();

    m_profileManager = std::make_unique<ProfileManager>();
    m_profileManager->init();

    m_playbackManager = std::make_unique<PlaybackManager>(
        m_projectManager.get(), m_mediaPool.get());

    m_timelineModel = std::make_unique<TimelineModel>(
        m_projectManager.get(), m_mediaPool.get(), m_undoStack.get());

    m_timelineCompositor = std::make_unique<TimelineCompositor>(
        m_playbackManager.get(), m_timelineModel.get(), m_mediaPool.get());

  } catch (...) {
    return ErrorCode::SubsystemAllocationFailed;
  }

  return ErrorCode::None;
}

ErrorCode App::setupUIEngine() {
  try {
    qmlRegisterType<XylaVideoSurface>("Xyla.Render", 1, 0, "XylaVideoSurface");

    qmlRegisterUncreatableType<RecentProjectsModel>(
        "Xyla.Core", 1, 0, "RecentProjectsModel",
        "RecentProjectsModel is provided by ProjectManager.recentProjects");

    KDDockWidgets::initFrontend(KDDockWidgets::FrontendType::QtQuick);
    m_qmlEngine = std::make_unique<QQmlApplicationEngine>();
    m_qmlEngine->addImageProvider(
        "thumbnails", new MediaThumbnailProvider(m_mediaPool.get()));
    KDDockWidgets::QtQuick::Platform::instance()->setQmlEngine(
        m_qmlEngine.get());

    auto &config = KDDockWidgets::Config::self();
    config.setFlags(config.flags() |
                    KDDockWidgets::Config::Flag_TitleBarHasMinimizeButton |
                    KDDockWidgets::Config::Flag_HideTitleBarWhenTabsVisible);
    config.setSeparatorThickness(4);
    config.setViewFactory(new XylaViewFactory());

    QObject::connect(m_undoStack.get(), &XylaUndoStack::canUndoChanged,
                     m_actionManager.get(), [this](bool canUndo) {
                       m_actionManager->setEnabled("edit.undo", canUndo);
                     });

    QObject::connect(m_undoStack.get(), &XylaUndoStack::canRedoChanged,
                     m_actionManager.get(), [this](bool canRedo) {
                       m_actionManager->setEnabled("edit.redo", canRedo);
                     });

    QObject::connect(m_actionManager.get(), &XylaActionManager::actionTriggered,
                     m_undoStack.get(), [this](const QString &actionId) {
                       if (actionId == "edit.undo" && m_undoStack) {
                         m_undoStack->undo();
                       } else if (actionId == "edit.redo" && m_undoStack) {
                         m_undoStack->redo();
                       }
                     });

    QQmlContext *rootContext = m_qmlEngine->rootContext();
    if (!rootContext) {
      return ErrorCode::QmlEngineLoadFailed;
    }

    rootContext->setContextProperty("mediaPool", m_mediaPool.get());
    rootContext->setContextProperty("mediaBinModel", m_mediaBinModel.get());
    rootContext->setContextProperty("settingsManager", m_settingsManager.get());
    rootContext->setContextProperty("projectManager", m_projectManager.get());
    rootContext->setContextProperty("fileSystemModel", m_fileSystemModel.get());
    rootContext->setContextProperty("actionManager", m_actionManager.get());
    rootContext->setContextProperty("menuManager", m_menuManager.get());
    rootContext->setContextProperty("layoutController",
                                    m_layoutController.get());
    rootContext->setContextProperty("profileManager", m_profileManager.get());
    rootContext->setContextProperty("playbackManager", m_playbackManager.get());
    rootContext->setContextProperty("timelineModel", m_timelineModel.get());
    rootContext->setContextProperty("timelineCompositor",
                                    m_timelineCompositor.get());
    rootContext->setContextProperty("shortcutManager", m_shortcutManager.get());

  } catch (...) {
    return ErrorCode::QmlEngineLoadFailed;
  }

  return ErrorCode::None;
}

ErrorCode App::bindVulkanDevice(QQuickWindow *window) {
  if (!window) {
    return ErrorCode::GPUInitializationFailed;
  }

  QSGRendererInterface *rif = window->rendererInterface();
  if (!rif || rif->graphicsApi() != QSGRendererInterface::Vulkan) {
    return ErrorCode::GPUInitializationFailed;
  }

  auto *inst = static_cast<QVulkanInstance *>(
      rif->getResource(window, QSGRendererInterface::VulkanInstanceResource));
  auto *physDev = static_cast<VkPhysicalDevice *>(
      rif->getResource(window, QSGRendererInterface::PhysicalDeviceResource));
  auto *dev = static_cast<VkDevice *>(
      rif->getResource(window, QSGRendererInterface::DeviceResource));
  auto *queue = static_cast<VkQueue *>(
      rif->getResource(window, QSGRendererInterface::CommandQueueResource));

  if (!inst || !physDev || !dev || !queue) {
    return ErrorCode::GPUInitializationFailed;
  }

  render::XylaRenderer::instance().initVulkanContext(inst->vkInstance(),
                                                     *physDev, *dev, *queue);

  return ErrorCode::None;
}

void App::startBackgroundServices() noexcept {
  render::FramePrefetcher::instance().start();
}

int App::run() {
  if (!m_initialized) {
    return -1;
  }

  startBackgroundServices();

  const QUrl url(QStringLiteral("qrc:/Xyla/src/qml/main.qml"));
  m_qmlEngine->load(url);

  return m_qtApp->exec();
}

} // namespace xyla
