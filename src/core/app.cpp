#include "app.hpp"
#include "core/log/logger.hpp"
#include "core/media/decoderRegistry.hpp"
#include "core/media/decoders/vulkanDecoderFactory.hpp"
#include "media/mediaThumbnailProvider.hpp"
#include <QQmlContext>
#include <QUrl>
#include <kddockwidgets/Config.h>
#include <kddockwidgets/qtquick/Platform.h>
#include <memory>

App::App(int &argc, char **argv) {

  // init logger
  xyla::Logger::instance().init();
  XYLA_LOG_INFO("Core", "Xyla Hello World!");

  // if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")) {
  //   qputenv("QT_QPA_PLATFORM", "xcb");
  // }
  // if (qEnvironmentVariableIsEmpty("QT_SCALE_FACTOR")) {
  //   qputenv("QT_SCALE_FACTOR", "1.5");
  // }

  m_qtApp = std::make_unique<QGuiApplication>(argc, argv);
  m_qtApp->setOrganizationName("Xyla");
  m_qtApp->setApplicationName("xyla");

  // Initialize media pool and model
  m_mediaPool = std::make_unique<xyla::MediaPool>();
  m_mediaBinModel = std::make_unique<xyla::MediaBinModel>(m_mediaPool.get());

  // initialize backend models
  m_undoStack = std::make_unique<xyla::XylaUndoStack>();
  m_settingsManager = std::make_unique<xyla::SettingsManager>();
  m_projectManager = std::make_unique<xyla::ProjectManager>();
  m_fileSystemModel = std::make_unique<xyla::FileSystemModel>();
  m_actionManager = std::make_unique<xyla::XylaActionManager>();
  m_menuManager = std::make_unique<xyla::MenuManager>(m_actionManager.get());
  m_layoutController = std::make_unique<WorkspaceLayoutController>();
  m_profileManager = std::make_unique<ProfileManager>();
  m_profileManager->init();

  KDDockWidgets::initFrontend(KDDockWidgets::FrontendType::QtQuick);
  m_qmlEngine = std::make_unique<QQmlApplicationEngine>();

  // Register image provider for thumbnail pipeline ("image://thumbnails/...")
  // Note: QQmlEngine takes ownership of raw provider pointers passed here
  m_qmlEngine->addImageProvider("thumbnails",
                                new xyla::MediaThumbnailProvider());

  KDDockWidgets::QtQuick::Platform::instance()->setQmlEngine(m_qmlEngine.get());

  auto &config = KDDockWidgets::Config::self();
  config.setFlags(config.flags() |
                  KDDockWidgets::Config::Flag_TitleBarHasMinimizeButton);
  config.setSeparatorThickness(4);

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
       false, // Initially disabled until first command pushed
       [this]() { m_undoStack->undo(); }});

  m_actionManager->registerAction({"edit.redo",
                                   {"Redo", "Re-apply last action",
                                    "https://docs.xyla.dev/manual/undo-redo"},
                                   "Ctrl+Y",
                                   "Ctrl+Y",
                                   "qrc:/assets/icons/arrow-right.svg",
                                   false, // Initially disabled
                                   [this]() { m_undoStack->redo(); }});

  // register context properties
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
        }
      },
      Qt::QueuedConnection);

  m_qmlEngine->load(url);

  return m_qtApp->exec();
}
