#pragma once

#include <QtLogging>
#include <atomic>
#include <condition_variable>
#include <deque>
#include <fstream>
#include <mutex>
#include <string>
#include <string_view>
#include <thread>

namespace xyla {

enum class LogLevel : uint8_t { Debug = 0, Info, Warning, Error, Critical };

struct LogEntry {
  LogLevel level;
  std::string category;
  std::string message;
  int64_t timestampNs;
};

class Logger {
public:
  static Logger &instance();

  void init(const std::string &logFilePath = "");
  void log(LogLevel level, std::string_view category, std::string_view message);

  static void qtMessageHandler(QtMsgType type,
                               const QMessageLogContext &context,
                               const QString &msg);

  Logger(const Logger &) = delete;
  Logger &operator=(const Logger &) = delete;

private:
  Logger() = default;
  ~Logger();

  void workerLoop();
  void writeToFile(const LogEntry &entry);

  std::mutex m_queueMutex;
  std::condition_variable m_cv;
  std::deque<LogEntry> m_queue;

  std::thread m_workerThread;
  std::atomic<bool> m_running{false};
  std::ofstream m_fileStream;

  static const char *levelToString(LogLevel level);
  static const char *levelToColor(LogLevel level);
};

} // namespace xyla

// Compile-time Macros
#define XYLA_LOG_INFO(cat, msg)                                                \
  ::xyla::Logger::instance().log(::xyla::LogLevel::Info, cat, msg)
#define XYLA_LOG_WARN(cat, msg)                                                \
  ::xyla::Logger::instance().log(::xyla::LogLevel::Warning, cat, msg)
#define XYLA_LOG_ERROR(cat, msg)                                               \
  ::xyla::Logger::instance().log(::xyla::LogLevel::Error, cat, msg)
#define XYLA_LOG_CRIT(cat, msg)                                                \
  ::xyla::Logger::instance().log(::xyla::LogLevel::Critical, cat, msg)

// Completely compiled away in Release builds (NDEBUG)
#if defined(NDEBUG) || defined(QT_NO_DEBUG_OUTPUT)
#define XYLA_LOG_DEBUG(cat, msg)                                               \
  do {                                                                         \
  } while (0)
#else
#define XYLA_LOG_DEBUG(cat, msg)                                               \
  ::xyla::Logger::instance().log(::xyla::LogLevel::Debug, cat, msg)
#endif
