#pragma once

#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <deque>
#include <mutex>
#include <utility>

namespace xyla::concurrency {

enum class QueueMode { FIFO, LIFO, LatestWins };

template <typename T> class XylaWorkQueue {
public:
  explicit XylaWorkQueue(size_t maxCapacity = 8,
                         QueueMode mode = QueueMode::FIFO)
      : m_maxCapacity(maxCapacity > 0 ? maxCapacity : 1), m_mode(mode) {}

  ~XylaWorkQueue() { stop(); }

  XylaWorkQueue(const XylaWorkQueue &) = delete;
  XylaWorkQueue &operator=(const XylaWorkQueue &) = delete;
  XylaWorkQueue(XylaWorkQueue &&) = delete;
  XylaWorkQueue &operator=(XylaWorkQueue &&) = delete;

  // Mode Configuration
  void setMode(QueueMode mode) noexcept {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_mode = mode;
    if (m_mode == QueueMode::LatestWins && m_container.size() > 1) {
      T newest = std::move(m_container.back());
      m_container.clear();
      m_container.push_back(std::move(newest));
    }
  }

  [[nodiscard]] QueueMode mode() const noexcept {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_mode;
  }

  void setCapacity(size_t capacity) noexcept {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_maxCapacity = capacity > 0 ? capacity : 1;
    while (m_container.size() > m_maxCapacity) {
      m_container.pop_front();
    }
  }

  // Push item into queue
  bool push(T item) {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_stopped) {
      return false;
    }

    if (m_mode == QueueMode::LatestWins) {
      m_container.clear();
      m_container.push_back(std::move(item));
    } else {
      while (m_container.size() >= m_maxCapacity) {
        m_container.pop_front();
      }
      m_container.push_back(std::move(item));
    }

    m_cv.notify_one();
    return true;
  }

  // Push with custom key deduplication (replaces existing items with matching
  // key)
  template <typename KeyFunc> bool pushDeduplicated(T item, KeyFunc &&keyFunc) {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_stopped) {
      return false;
    }

    auto key = keyFunc(item);

    if (m_mode == QueueMode::LatestWins) {
      m_container.clear();
      m_container.push_back(std::move(item));
    } else {
      for (auto it = m_container.begin(); it != m_container.end();) {
        if (keyFunc(*it) == key) {
          it = m_container.erase(it);
        } else {
          ++it;
        }
      }

      while (m_container.size() >= m_maxCapacity) {
        m_container.pop_front();
      }
      m_container.push_back(std::move(item));
    }

    m_cv.notify_one();
    return true;
  }

  // Blocking Pop based on active QueueMode
  bool pop(T &outItem) {
    std::unique_lock<std::mutex> lock(m_mutex);
    m_cv.wait(lock, [this]() { return !m_container.empty() || m_stopped; });

    if (m_stopped || m_container.empty()) {
      return false;
    }

    if (m_mode == QueueMode::LIFO || m_mode == QueueMode::LatestWins) {
      outItem = std::move(m_container.back());
      m_container.pop_back();
    } else { // FIFO
      outItem = std::move(m_container.front());
      m_container.pop_front();
    }

    return true;
  }

  // Pop with Timeout
  template <typename Rep, typename Period>
  bool popWait(T &outItem, const std::chrono::duration<Rep, Period> &timeout) {
    std::unique_lock<std::mutex> lock(m_mutex);
    bool acquired = m_cv.wait_for(
        lock, timeout, [this]() { return !m_container.empty() || m_stopped; });

    if (!acquired || m_stopped || m_container.empty()) {
      return false;
    }

    if (m_mode == QueueMode::LIFO || m_mode == QueueMode::LatestWins) {
      outItem = std::move(m_container.back());
      m_container.pop_back();
    } else { // FIFO
      outItem = std::move(m_container.front());
      m_container.pop_front();
    }

    return true;
  }

  // Non-blocking try-pop
  bool tryPop(T &outItem) {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_stopped || m_container.empty()) {
      return false;
    }

    if (m_mode == QueueMode::LIFO || m_mode == QueueMode::LatestWins) {
      outItem = std::move(m_container.back());
      m_container.pop_back();
    } else { // FIFO
      outItem = std::move(m_container.front());
      m_container.pop_front();
    }

    return true;
  }

  void clear() noexcept {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_container.clear();
  }

  void stop() noexcept {
    {
      std::lock_guard<std::mutex> lock(m_mutex);
      m_stopped = true;
      m_container.clear();
    }
    m_cv.notify_all();
  }

  [[nodiscard]] size_t size() const noexcept {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_container.size();
  }

  [[nodiscard]] bool empty() const noexcept {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_container.empty();
  }

  [[nodiscard]] bool isStopped() const noexcept {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_stopped;
  }

private:
  mutable std::mutex m_mutex;
  std::condition_variable m_cv;
  std::deque<T> m_container;
  size_t m_maxCapacity{8};
  QueueMode m_mode{QueueMode::FIFO};
  bool m_stopped{false};
};

} // namespace xyla::concurrency
