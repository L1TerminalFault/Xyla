#include "app.hpp"
#include "core/log/logger.hpp"
#include "core/media/decoderRegistry.hpp"
#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "core/media/mediaPool.hpp"
#include "core/render/framePrefetcher.hpp"
#include "core/render/videoFrameCache.hpp"
#include "core/render/xylaRenderer.hpp"
#include "core/render/xylaVideoSurface.hpp"
#include "core/timeline/playback/playbackManager.hpp"
#include "core/timeline/timelineCompositor.hpp"
#include "media/mediaThumbnailProvider.hpp"
#include "ui/models/timelineModel.hpp"
#include "workspace/xylaViewFactory.hpp"

#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QStyleHints>
#include <QUrl>
#include <QVulkanInstance>
#include <kddockwidgets/Config.h>
#include <kddockwidgets/qtquick/Platform.h>
#include <memory>
#include <qcoreapplication.h>
#include <qobject.h>

App::App(int &argc, char **argv) {
  xyla::Logger::instance().init();
  XYLA_LOG_INFO("Core", "Xyla Engine Initializing...");

  // Expand VRAM Cache ceiling to 4.5GB for high GPU saturation (e.g. RTX 3060
  // 6GB)
  xyla::render::VideoFrameCache::instance().setMaxVramMB(4500);

  // Initialize background lookahead prefetcher
  xyla::render::FramePrefetcher::instance().start();

  m_qtApp = std::make_unique<QGuiApplication>(argc, argv);
  m_qtApp->setOrganizationName("Xyla");
  m_qtApp->setApplicationName("xyla");
  QGuiApplication::styleHints()->setColorScheme(Qt::ColorScheme::Dark);

  m_mediaPool = std::make_unique<xyla::MediaPool>();
  m_mediaBinModel = std::make_unique<xyla::MediaBinModel>(m_mediaPool.get());

  m_undoStack = std::make_unique<xyla::XylaUndoStack>();
  m_settingsManager = std::make_unique<xyla::SettingsManager>();
  m_projectManager = std::make_unique<xyla::ProjectManager>();
  m_projectManager->setMediaPool(m_mediaPool.get());

  QObject::connect(m_mediaPool.get(), &xyla::MediaPool::assetImported,
                   m_projectManager.get(),
                   [this](const QString &, std::shared_ptr<xyla::XylaAsset>) {
                     m_projectManager->setHasUnsavedChanges(true);
                   });
  m_fileSystemModel = std::make_unique<xyla::FileSystemModel>();
  m_actionManager = std::make_unique<xyla::XylaActionManager>();
  m_menuManager = std::make_unique<xyla::MenuManager>(m_actionManager.get());
  m_layoutController = std::make_unique<WorkspaceLayoutController>();
  m_profileManager = std::make_unique<ProfileManager>();
  m_profileManager->init();

  m_playbackManager = std::make_unique<xyla::PlaybackManager>(
      m_projectManager.get(), m_mediaPool.get());

  m_timelineModel = std::make_unique<xyla::TimelineModel>(
      m_projectManager.get(), m_mediaPool.get(), m_undoStack.get());

  m_timelineCompositor = std::make_unique<xyla::TimelineCompositor>(
      m_playbackManager.get(), m_timelineModel.get(), m_mediaPool.get());

  qmlRegisterType<xyla::XylaVideoSurface>("Xyla.Render", 1, 0,
                                          "XylaVideoSurface");

  KDDockWidgets::initFrontend(KDDockWidgets::FrontendType::QtQuick);
  m_qmlEngine = std::make_unique<QQmlApplicationEngine>();

  m_qmlEngine->addImageProvider("thumbnails",
                                new xyla::MediaThumbnailProvider());

  KDDockWidgets::QtQuick::Platform::instance()->setQmlEngine(m_qmlEngine.get());

  auto &config = KDDockWidgets::Config::self();
  config.setFlags(config.flags() |
                  KDDockWidgets::Config::Flag_TitleBarHasMinimizeButton);
  config.setSeparatorThickness(4);
  config.setViewFactory(new xyla::XylaViewFactory());

  connect(m_undoStack.get(), &xyla::XylaUndoStack::canUndoChanged, this,
          [this](bool canUndo) {
            m_actionManager->setEnabled("edit.undo", canUndo);
          });

  connect(m_undoStack.get(), &xyla::XylaUndoStack::canRedoChanged, this,
          [this](bool canRedo) {
            m_actionManager->setEnabled("edit.redo", canRedo);
          });

  m_actionManager->registerAction(
      {"edit.undo",
       {"Undo", "Revert last action", "https://docs.xyla.dev/manual/undo-redo"},
       "Ctrl+Z",
       "Ctrl+Z",
       "qrc:/assets/icons/arrow-left.svg",
       false,
       [this]() { m_undoStack->undo(); }});

  m_actionManager->registerAction({"edit.redo",
                                   {"Redo", "Re-apply last action",
                                    "https://docs.xyla.dev/manual/undo-redo"},
                                   "Ctrl+Y",
                                   "Ctrl+Y",
                                   "qrc:/assets/icons/arrow-right.svg",
                                   false,
                                   [this]() { m_undoStack->redo(); }});

  QQmlContext *rootContext = m_qmlEngine->rootContext();
  if (rootContext) {
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
  }

  qmlRegisterUncreatableType<xyla::RecentProjectsModel>(
      "Xyla.Core", 1, 0, "RecentProjectsModel",
      "RecentProjectsModel is provided by ProjectManager.recentProjects");

  xyla::DecoderRegistry::instance().registerFactory(
      std::make_unique<xyla::VulkanDecoderFactory>());
}

int App::run() {
  const QUrl url(QStringLiteral("qrc:/Xyla/src/qml/main.qml"));

  QObject::connect(
      m_qmlEngine.get(), &QQmlApplicationEngine::objectCreated, m_qtApp.get(),
      [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
          QCoreApplication::exit(-1);
          return;
        }

        auto *window = qobject_cast<QQuickWindow *>(obj);
        if (window) {
          QObject::connect(
              window, &QQuickWindow::sceneGraphInitialized, window,
              [window]() {
                QSGRendererInterface *rif = window->rendererInterface();
                if (rif && rif->graphicsApi() == QSGRendererInterface::Vulkan) {
                  auto *inst = static_cast<QVulkanInstance *>(rif->getResource(
                      window, QSGRendererInterface::VulkanInstanceResource));
                  auto *physDev =
                      static_cast<VkPhysicalDevice *>(rif->getResource(
                          window,
                          QSGRendererInterface::PhysicalDeviceResource));
                  auto *dev = static_cast<VkDevice *>(rif->getResource(
                      window, QSGRendererInterface::DeviceResource));
                  auto *queue = static_cast<VkQueue *>(rif->getResource(
                      window, QSGRendererInterface::CommandQueueResource));

                  if (inst && physDev && dev && queue) {
                    xyla::render::XylaRenderer::instance().initVulkanContext(
                        inst->vkInstance(), *physDev, *dev, *queue);
                  }
                }
              },
              Qt::DirectConnection);
        }
      },
      Qt::QueuedConnection);

  m_qmlEngine->load(url);

  return m_qtApp->exec();
}
