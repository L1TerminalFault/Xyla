#pragma once

#include <chrono>
#include <cstdio>
#include <string_view>

namespace xyla::profiler {

class ScopeTimer {
public:
  using Clock = std::chrono::high_resolution_clock;

  explicit ScopeTimer(std::string_view tag, double thresholdMs = 0.0)
      : m_tag(tag), m_thresholdMs(thresholdMs), m_start(Clock::now()) {}

  ~ScopeTimer() {
    double elapsed = elapsedMs();
    if (elapsed >= m_thresholdMs) {
      std::printf("[PROFILE] %-32s : %7.2f ms\n", m_tag.data(), elapsed);
      std::fflush(stdout);
    }
  }

  [[nodiscard]] double elapsedMs() const noexcept {
    auto now = Clock::now();
    return std::chrono::duration<double, std::milli>(now - m_start).count();
  }

private:
  std::string_view m_tag;
  double m_thresholdMs{0.0};
  Clock::time_point m_start;
};

} // namespace xyla::profiler
