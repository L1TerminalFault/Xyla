#pragma once

#include <QUrl>
#include <kddockwidgets/qtquick/ViewFactory.h>

namespace xyla {

class XylaViewFactory : public KDDockWidgets::QtQuick::ViewFactory {
public:
  ~XylaViewFactory() override = default;

  QUrl titleBarFilename() const override {
    return QUrl("qrc:/Xyla/src/qml/workspace/XylaTitleBar.qml");
  }

  QUrl tabbarFilename() const override {
    return QUrl("qrc:/Xyla/src/qml/workspace/XylaTabBar.qml");
  }

  QUrl separatorFilename() const override {
    return QUrl("qrc:/Xyla/src/qml/workspace/XylaSeparator.qml");
  }

  QUrl dockwidgetFilename() const override {
    return QUrl("qrc:/Xyla/src/qml/workspace/XylaDockWidget.qml");
  }

  QUrl groupFilename() const override {
    return QUrl("qrc:/Xyla/src/qml/workspace/XylaGroup.qml");
  }
};

} // namespace xyla
