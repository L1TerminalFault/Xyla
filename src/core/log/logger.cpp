#include "logger.hpp"
#include <QDateTime>
#include <QDir>
#include <QStandardPaths>
#include <chrono>
#include <format>
#include <iostream>

namespace xyla {

Logger &Logger::instance() {
  static Logger instance;
  return instance;
}

void Logger::init(const std::string &logFilePath) {
  if (m_running.load(std::memory_order_relaxed))
    return;

  std::string path = logFilePath;
  if (path.empty()) {
    QString stateDir =
        QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation) +
        "/xyla";
    QDir().mkpath(stateDir);
    path = (stateDir + "/xyla.log").toStdString();
  }

  // Rotate previous log files & keep max 5 .old files)
  namespace fs = std::filesystem;
  if (fs::exists(path)) {
    for (int i = 4; i >= 1; --i) {
      std::string oldPath = std::format("{}.{}", path, i);
      std::string newPath = std::format("{}.{}", path, i + 1);
      if (fs::exists(oldPath)) {
        if (i == 4 && fs::exists(newPath)) {
          fs::remove(newPath); // Delete old max backup
        }
        fs::rename(oldPath, newPath);
      }
    }
    // Move current xyla.log to xyla.log.1
    fs::rename(path, path + ".1");
  }

  m_fileStream.open(path, std::ios::out | std::ios::trunc);

  auto now = std::chrono::system_clock::now();
  auto timeT = std::chrono::system_clock::to_time_t(now);
  std::tm tmBuffer{};
  localtime_r(&timeT, &tmBuffer);

  std::string sessionTime = std::format(
      "{:04d}-{:02d}-{:02d} {:02d}:{:02d}:{:02d}", tmBuffer.tm_year + 1900,
      tmBuffer.tm_mon + 1, tmBuffer.tm_mday, tmBuffer.tm_hour, tmBuffer.tm_min,
      tmBuffer.tm_sec);

  if (m_fileStream.is_open()) {
    m_fileStream << "=========================================================="
                    "============\n";
    m_fileStream << std::format("  XYLA ENGINE SESSION STARTED: {}\n",
                                sessionTime);
    m_fileStream << "  OS: Linux (Arch) | Platform: Qt6 / QML | Build: "
#ifdef NDEBUG
                 << "RELEASE\n";
#else
                 << "DEBUG\n";
#endif
    m_fileStream << "=========================================================="
                    "============\n\n";
    m_fileStream.flush();
  }

  m_running.store(true, std::memory_order_release);
  m_workerThread = std::thread(&Logger::workerLoop, this);

  qInstallMessageHandler(Logger::qtMessageHandler);
}

Logger::~Logger() {
  if (m_running.load(std::memory_order_acquire)) {
    m_running.store(false, std::memory_order_release);
    m_cv.notify_one();
    if (m_workerThread.joinable()) {
      m_workerThread.join();
    }
  }
  if (m_fileStream.is_open()) {
    m_fileStream.flush();
    m_fileStream.close();
  }
}

void Logger::log(LogLevel level, std::string_view category,
                 std::string_view message) {
  if (!m_running.load(std::memory_order_relaxed))
    return;

  auto now = std::chrono::system_clock::now().time_since_epoch();
  int64_t nanos =
      std::chrono::duration_cast<std::chrono::nanoseconds>(now).count();

  {
    std::lock_guard<std::mutex> lock(m_queueMutex);
    m_queue.push_back(
        LogEntry{level, std::string(category), std::string(message), nanos});
  }
  m_cv.notify_one();
}

void Logger::workerLoop() {
  std::deque<LogEntry> localQueue;

  while (m_running.load(std::memory_order_relaxed)) {
    {
      std::unique_lock<std::mutex> lock(m_queueMutex);
      m_cv.wait(lock, [this] {
        return !m_queue.empty() || !m_running.load(std::memory_order_relaxed);
      });

      if (m_queue.empty() && !m_running.load(std::memory_order_relaxed)) {
        break;
      }

      localQueue.swap(m_queue);
    }

    for (const auto &entry : localQueue) {
      writeToFile(entry);
    }
    localQueue.clear();
  }

  // Flush remaining elements on shutdown
  {
    std::lock_guard<std::mutex> lock(m_queueMutex);
    for (const auto &entry : m_queue) {
      writeToFile(entry);
    }
    m_queue.clear();
  }
}

void Logger::writeToFile(const LogEntry &entry) {
  auto nanos = std::chrono::nanoseconds(entry.timestampNs);
  auto tp = std::chrono::time_point<std::chrono::system_clock>(nanos);
  auto timeT = std::chrono::system_clock::to_time_t(tp);
  auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(nanos) % 1000;

  std::tm tmBuffer{};
  localtime_r(&timeT, &tmBuffer);

  std::string timeStr = std::format(
      "{:04d}-{:02d}-{:02d} {:02d}:{:02d}:{:02d}.{:03d}",
      tmBuffer.tm_year + 1900, tmBuffer.tm_mon + 1, tmBuffer.tm_mday,
      tmBuffer.tm_hour, tmBuffer.tm_min, tmBuffer.tm_sec, ms.count());

  // Terminal Output (Colored)
  std::cout << std::format(
      "[{}] {}{}\033[0m [{}] {}\n", timeStr, levelToColor(entry.level),
      levelToString(entry.level), entry.category, entry.message);

  // File Output (Plain Text)
  if (m_fileStream.is_open()) {
    m_fileStream << std::format("[{}] [{}] [{}] {}\n", timeStr,
                                levelToString(entry.level), entry.category,
                                entry.message);
  }
}

const char *Logger::levelToString(LogLevel level) {
  switch (level) {
  case LogLevel::Debug:
    return "DEBUG";
  case LogLevel::Info:
    return "INFO ";
  case LogLevel::Warning:
    return "WARN ";
  case LogLevel::Error:
    return "ERROR";
  case LogLevel::Critical:
    return "CRIT ";
  }
  return "UNKNOWN";
}

const char *Logger::levelToColor(LogLevel level) {
  switch (level) {
  case LogLevel::Debug:
    return "\033[36m"; // Cyan
  case LogLevel::Info:
    return "\033[32m"; // Green
  case LogLevel::Warning:
    return "\033[33m"; // Yellow
  case LogLevel::Error:
    return "\033[31m"; // Red
  case LogLevel::Critical:
    return "\033[35m"; // Magenta
  }
  return "\033[0m";
}

void Logger::qtMessageHandler(QtMsgType type, const QMessageLogContext &context,
                              const QString &msg) {
  LogLevel level = LogLevel::Info;
  switch (type) {
  case QtDebugMsg:
    level = LogLevel::Debug;
    break;
  case QtInfoMsg:
    level = LogLevel::Info;
    break;
  case QtWarningMsg:
    level = LogLevel::Warning;
    break;
  case QtCriticalMsg:
    level = LogLevel::Error;
    break;
  case QtFatalMsg:
    level = LogLevel::Critical;
    break;
  }

  std::string category = context.category ? context.category : "Qt/QML";
  Logger::instance().log(level, category, msg.toStdString());
}

} // namespace xyla
