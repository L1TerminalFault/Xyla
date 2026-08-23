#pragma once

#include <QString>
#include <QVariantMap>

namespace xyla {

struct XylaMenuItemData {
  QString menuPath;
  QString actionId;
  bool isSeparator{false};

  QVariantMap toVariantMap() const {
    return {{"menuPath", menuPath},
            {"actionId", actionId},
            {"isSeparator", isSeparator}};
  }
};

} // namespace xyla
