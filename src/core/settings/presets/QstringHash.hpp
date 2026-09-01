#pragma once
#include <QHash>
#include <QString>

namespace xyla {
struct QStringHash {
  std::size_t operator()(const QString &key) const noexcept {
    return static_cast<std::size_t>(qHash(key));
  }
};
} // namespace xyla
