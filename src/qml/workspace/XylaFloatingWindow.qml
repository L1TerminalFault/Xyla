import QtQuick 2.9
import com.kdab.dockwidgets 2.0
import "qrc:/kddockwidgets/qtquick/views/qml/" as KDDW

Rectangle {
    id: root

    readonly property FloatingWindowView floatingWindowCpp: parent // qmllint disable incompatible-type
    readonly property TitleBarView titleBarCpp: floatingWindowCpp ? floatingWindowCpp.titleBar : null
    readonly property DropAreaView dropAreaCpp: floatingWindowCpp ? floatingWindowCpp.dropArea : null
    readonly property int titleBarHeight: titleBar.heightWhenVisible

    property int margins: 1  // was 4 — tighter border, less "white frame" feel

    anchors.fill: parent

    // --- Xyla theme tokens -------------------------------------------------
    color: "#191919"          // window background
    // border.color: "#1a1a1a"   // outer border
    // border.width: 1
    // -------------------------------------------------------------------

    onTitleBarHeightChanged: {
        if (floatingWindowCpp)
            floatingWindowCpp.geometryUpdated();
    }

    Loader {
        id: titleBar
        readonly property TitleBarView titleBarCpp: root.titleBarCpp
        readonly property int heightWhenVisible: item ? item.heightWhenVisible : 0
        source: Singletons.widgetFactory.titleBarFilename()
        anchors {
            top: parent ? parent.top : undefined
            left: parent ? parent.left : undefined
            right: parent ? parent.right : undefined
            margins: root.margins
        }
    }

    KDDW.DropArea {
        id: dropArea
        dropAreaCpp: root.dropAreaCpp
        anchors {
            left: parent ? parent.left : undefined
            right: parent ? parent.right : undefined
            top: titleBar.bottom
            bottom: parent ? parent.bottom : undefined
            leftMargin: root.margins
            rightMargin: root.margins
            bottomMargin: root.margins
        }
    }

    onDropAreaCppChanged: {
        if (dropAreaCpp) {
            dropAreaCpp.parent = dropArea;
            dropAreaCpp.anchors.fill = dropArea;
        }
    }
}
