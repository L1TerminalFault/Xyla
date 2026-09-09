#pragma once

#include <QObject>
#include <QFileSystemWatcher>
#include <QDir>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDirIterator>
#include <QDebug>
#include <QUrl>
#include <QFile>
#include <QMetaObject>
#include <QDateTime>

// BUG: Currently NOT stable (Crashes)

namespace xyla {

class QmlHotReloader : public QObject {
    Q_OBJECT

public:
    explicit QmlHotReloader(QQmlApplicationEngine *engine, QUrl rootUrl,
                             QString sourceDir, QObject *parent = nullptr)
        : QObject(parent), m_engine(engine), m_rootUrl(std::move(rootUrl)),
          m_sourceDir(std::move(sourceDir)) {

        log("=== QmlHotReloader constructing ===");
        log(QStringLiteral("  engine ptr        : %1").arg(reinterpret_cast<quintptr>(engine), 0, 16));
        log(QStringLiteral("  rootUrl           : %1").arg(m_rootUrl.toString()));
        log(QStringLiteral("  sourceDir (raw)   : %1").arg(m_sourceDir));
        log(QStringLiteral("  sourceDir (abs)   : %1").arg(QDir(m_sourceDir).absolutePath()));
        log(QStringLiteral("  cwd at construct  : %1").arg(QDir::currentPath()));
        log(QStringLiteral("  sourceDir exists? : %1").arg(QDir(m_sourceDir).exists() ? "YES" : "NO"));

#if defined(Q_OS_LINUX)
        {
            QFile limitFile("/proc/sys/fs/inotify/max_user_watches");
            if (limitFile.open(QIODevice::ReadOnly)) {
                log(QStringLiteral("  inotify max_user_watches: %1")
                        .arg(QString::fromUtf8(limitFile.readAll()).trimmed()));
            } else {
                log("  inotify max_user_watches: <could not read /proc/sys/fs/inotify/max_user_watches>");
            }
        }
#endif

        if (m_engine) {
            connect(m_engine, &QQmlApplicationEngine::warnings,
                    this, &QmlHotReloader::onEngineWarnings);
            connect(m_engine, &QQmlApplicationEngine::objectCreated,
                    this, &QmlHotReloader::onObjectCreated);
        }

        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &QmlHotReloader::onFileChanged);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &QmlHotReloader::onDirectoryChanged);

        m_currentRoots = m_engine ? m_engine->rootObjects() : QList<QObject *>();
        log(QStringLiteral("  initial rootObjects() count: %1").arg(m_currentRoots.size()));
        for (int i = 0; i < m_currentRoots.size(); ++i) {
            QObject *o = m_currentRoots.at(i);
            log(QStringLiteral("    [%1] %2 (objectName=\"%3\")")
                    .arg(i)
                    .arg(o ? o->metaObject()->className() : "nullptr")
                    .arg(o ? o->objectName() : QString()));
        }

        watchDirectory();
        log("=== QmlHotReloader construction complete ===");
    }

    Q_INVOKABLE void clearAndReload() {
        log("=== clearAndReload() called ===");

        if (!m_engine) {
            log("  ABORT: m_engine is null.");
            return;
        }

        log(QStringLiteral("  rootObjects() BEFORE clear: %1").arg(m_engine->rootObjects().size()));
        log("  calling m_engine->clearComponentCache() ...");
        m_engine->clearComponentCache();
        log("  clearComponentCache() returned.");

        const QList<QObject *> staleRoots = m_currentRoots;
        log(QStringLiteral("  staleRoots tracked: %1").arg(staleRoots.size()));

        log(QStringLiteral("  calling m_engine->load(%1) ...").arg(m_rootUrl.toString()));
        m_engine->load(m_rootUrl);
        log("  load() call returned (async errors, if any, arrive via warnings()/objectCreated() above/below).");

        QList<QObject *> allRoots = m_engine->rootObjects();
        log(QStringLiteral("  rootObjects() AFTER load: %1").arg(allRoots.size()));

        m_currentRoots.clear();
        for (QObject *obj : allRoots) {
            if (!staleRoots.contains(obj))
                m_currentRoots.append(obj);
        }
        log(QStringLiteral("  new roots identified: %1").arg(m_currentRoots.size()));
        for (int i = 0; i < m_currentRoots.size(); ++i) {
            QObject *o = m_currentRoots.at(i);
            log(QStringLiteral("    new[%1] %2").arg(i).arg(o ? o->metaObject()->className() : "nullptr"));
        }

        for (QObject *obj : staleRoots) {
            if (obj) {
                log(QStringLiteral("  scheduling deleteLater() for stale root: %1")
                        .arg(obj->metaObject()->className()));
                obj->deleteLater();
            }
        }

        if (m_currentRoots.isEmpty()) {
            qWarning().noquote() << "[HotReloader] *** RELOAD PRODUCED ZERO ROOT OBJECTS ***"
                                  << "— this almost always means the reloaded QML file failed to "
                                     "compile/instantiate. Check the warnings() output logged above "
                                     "this line for the exact file/line/error.";
        }

        log("=== clearAndReload() finished ===");
        emit reloadTriggered();
    }

signals:
    void reloadTriggered();

private slots:
    void watchDirectory() {
        log("--- watchDirectory() start ---");
        QStringList pathsToWatch;

        if (!QDir(m_sourceDir).exists()) {
            qWarning().noquote() << "[HotReloader] Source directory does not exist:" << m_sourceDir;
            log("--- watchDirectory() aborted: source dir missing ---");
            return;
        }

        pathsToWatch << m_sourceDir;
        QDirIterator dirIt(m_sourceDir, QDir::Dirs | QDir::NoDotAndDotDot,
                            QDirIterator::Subdirectories);
        int dirCount = 0;
        while (dirIt.hasNext()) {
            const QString d = dirIt.next();
            pathsToWatch << d;
            ++dirCount;
        }

        QDirIterator fileIt(m_sourceDir, QStringList() << "*.qml", QDir::Files,
                             QDirIterator::Subdirectories);
        QStringList qmlFiles;
        while (fileIt.hasNext())
            qmlFiles << fileIt.next();
        pathsToWatch << qmlFiles;

        log(QStringLiteral("  subdirectories found : %1").arg(dirCount));
        log(QStringLiteral("  qml files found      : %1").arg(qmlFiles.size()));
        for (const QString &f : qmlFiles)
            log(QStringLiteral("    qml: %1").arg(f));

        if (!m_watcher.files().isEmpty()) {
            log(QStringLiteral("  removing %1 previously watched files").arg(m_watcher.files().size()));
            m_watcher.removePaths(m_watcher.files());
        }
        if (!m_watcher.directories().isEmpty()) {
            log(QStringLiteral("  removing %1 previously watched directories").arg(m_watcher.directories().size()));
            m_watcher.removePaths(m_watcher.directories());
        }

        log(QStringLiteral("  requesting addPaths() for %1 total paths").arg(pathsToWatch.size()));
        const QStringList failed = m_watcher.addPaths(pathsToWatch);

        log(QStringLiteral("  RESULT: now watching %1 files, %2 directories")
                .arg(m_watcher.files().size())
                .arg(m_watcher.directories().size()));

        if (!failed.isEmpty()) {
            qWarning().noquote() << "[HotReloader]" << failed.size() << "path(s) FAILED to watch:";
            for (const QString &f : failed)
                qWarning().noquote() << "    FAILED:" << f;
        } else {
            log("  no addPaths() failures reported.");
        }
        log("--- watchDirectory() end ---");
    }

    void onDirectoryChanged(const QString &path) {
        log(QStringLiteral(">>> directoryChanged signal fired for: %1").arg(path));
        watchDirectory();
        clearAndReload();
    }

    void onFileChanged(const QString &path) {
        log(QStringLiteral(">>> fileChanged signal fired for: %1").arg(path));
        log(QStringLiteral("    still in watcher.files()? %1")
                .arg(m_watcher.files().contains(path) ? "YES" : "NO (watch was dropped, re-adding)"));

        if (!m_watcher.files().contains(path)) {
            const bool added = m_watcher.addPath(path);
            log(QStringLiteral("    re-add addPath() result: %1").arg(added ? "OK" : "FAILED"));
        }

        clearAndReload();
    }

    void onEngineWarnings(const QList<QQmlError> &warnings) {
        for (const QQmlError &err : warnings) {
            qWarning().noquote() << "[HotReloader][QML ERROR]" << err.toString();
        }
    }

    void onObjectCreated(QObject *object, const QUrl &url) {
        log(QStringLiteral(">>> engine objectCreated: url=%1 object=%2")
                .arg(url.toString())
                .arg(object ? object->metaObject()->className() : "nullptr (CREATION FAILED)"));
    }

private:
    static void log(const QString &msg) {
        // qDebug().noquote() << QStringLiteral("[HotReloader %1] %2")
        //                            .arg(QDateTime::currentDateTime().toString("HH:mm:ss.zzz"), msg);
    }

    QQmlApplicationEngine *m_engine{nullptr};
    QUrl m_rootUrl;
    QFileSystemWatcher m_watcher;
    QString m_sourceDir;
    QList<QObject *> m_currentRoots;
};

} // namespace xyla
