import QtQuick 2.15
import "qrc:/kddockwidgets/qtquick/views/qml/" as KDDW

KDDW.DockWidget {
    id: root
    color: "#191919"
    border.color: (dockWidgetCpp && dockWidgetCpp.isFocused) ? "#2555D3" : "#2d2d2d"
    border.width: 1
    radius: 10 // 10px dock window radius
}
