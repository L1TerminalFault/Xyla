import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "qrc:/kddockwidgets/qtquick/views/qml/" as KDDW

KDDW.TitleBarBase {
    id: root

    implicitHeight: 36
    heightWhenVisible: 36
    color: "#0E0E0E"

    // Find enclosing XylaGroup or DockWidget
    readonly property Item parentGroup: {
        var p = parent
        while (p) {
            if (p.hasOwnProperty("hasTopSibling")) return p
            p = p.parent
        }
        return null
    }

    readonly property bool hasTopSibling: parentGroup ? parentGroup.hasTopSibling : false
    readonly property bool hasLeftSibling: parentGroup ? parentGroup.hasLeftSibling : false
    readonly property bool hasRightSibling: parentGroup ? parentGroup.hasRightSibling : false

    // Accurate floating detection covering controller, dockWidget, parentGroup, and FloatingWindow
    readonly property bool isFloating: {
        if (typeof root.floating !== "undefined") return Boolean(root.floating)
        if (typeof root.isFloatingWindow !== "undefined") return Boolean(root.isFloatingWindow)

        // 1. Controller inspection
        if (typeof root.controller !== "undefined" && root.controller) {
            if (typeof root.controller.isFloating === "function") return Boolean(root.controller.isFloating())
            if (typeof root.controller.isFloating !== "undefined") return Boolean(root.controller.isFloating)
            if (typeof root.controller.dockWidget !== "undefined" && root.controller.dockWidget) {
                var cdw = root.controller.dockWidget
                if (typeof cdw.isFloating === "function") return Boolean(cdw.isFloating())
                if (typeof cdw.isFloating !== "undefined") return Boolean(cdw.isFloating)
            }
        }

        // 2. dockWidget property on TitleBarBase
        if (root.dockWidget) {
            if (typeof root.dockWidget.isFloating === "function") return Boolean(root.dockWidget.isFloating())
            if (typeof root.dockWidget.isFloating !== "undefined") return Boolean(root.dockWidget.isFloating)
        }

        // 3. Check enclosing parentGroup / GroupView
        if (parentGroup) {
            if (typeof parentGroup.isFloating === "function") return Boolean(parentGroup.isFloating())
            if (typeof parentGroup.isFloating !== "undefined") return Boolean(parentGroup.isFloating)
            if (parentGroup.groupCpp) {
                if (typeof parentGroup.groupCpp.isFloating === "function") return Boolean(parentGroup.groupCpp.isFloating())
                if (typeof parentGroup.groupCpp.isFloating !== "undefined") return Boolean(parentGroup.groupCpp.isFloating)
            }
        }

        // 4. Window-level detection: if this titlebar is hosted in a FloatingWindow
        if (root.Window && root.Window.window) {
            var win = root.Window.window
            if (typeof win.isFloatingWindow !== "undefined") return Boolean(win.isFloatingWindow)
            if (typeof win.isFloating !== "undefined") return Boolean(win.isFloating)
            var winStr = win.toString()
            if (winStr.indexOf("FloatingWindow") !== -1 || winStr.indexOf("KDDockWidgets") !== -1) {
                return true
            }
        }

        return false
    }

// ============================================================
    // FLOATING TRANSITION SUPPRESSION FLAG
    // Blocks spurious synthetic mouse events from reopening the menu
    // when a window floats or reparents
    // ============================================================
    property bool isFloatingTransition: false

    Timer {
        id: floatingTransitionTimer
        interval: 500
        repeat: false
        onTriggered: root.isFloatingTransition = false
    }

    Connections {
        target: root
        function onIsFloatingChanged() {
            contextMenu.close()
            root.isFloatingTransition = true
            floatingTransitionTimer.restart()
        }
    }

    Component.onCompleted: {
        contextMenu.close()
        root.isFloatingTransition = true
        floatingTransitionTimer.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: "#191919"

        readonly property int cornerRadius: 10

        topLeftRadius: (!root.hasTopSibling && !root.hasLeftSibling) ? cornerRadius : 0
        topRightRadius: (!root.hasTopSibling && !root.hasRightSibling) ? cornerRadius : 0
        bottomLeftRadius: 0
        bottomRightRadius: 0

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#191919"
        }

        // ========================================================
        // TITLE ROW (Tab title representation)
        // ========================================================
        Row {
            id: titleRow
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 4

            Rectangle {
                height: parent.height
                implicitWidth: singleTitleText.implicitWidth + 24
                color: root.isFocused ? "#252526" : "#0d0d0d"
                radius: 8

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Text {
                    id: singleTitleText
                    anchors.centerIn: parent
                    text: root.title
                    color: root.isFocused ? "#ffffff" : "#888888"
                    font.pixelSize: 12
                    font.weight: Font.Medium

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }
        }

        // ========================================================
        // RIGHT-CLICK INTERCEPTOR FOR TITLE ROW ONLY
        // ========================================================
// In TitleBarBase.qml -> titleRowContextMenuArea
      MouseArea {
              id: titleRowContextMenuArea
              anchors.fill: titleRow
              acceptedButtons: Qt.RightButton
              cursorShape: Qt.ArrowCursor

              property bool wasPressedHere: false

              onPressed: function(mouse) {
                  if (mouse.button === Qt.RightButton && !root.isFloatingTransition) {
                      wasPressedHere = true
                      mouse.accepted = true
                  } else {
                      wasPressedHere = false
                  }
              }

              onCanceled: {
                  wasPressedHere = false
              }

              onClicked: function(mouse) {
                  if (mouse.button === Qt.RightButton && wasPressedHere && !root.isFloatingTransition) {
                      wasPressedHere = false
                      mouse.accepted = true
                      var localPos = mapToItem(root, mouse.x, mouse.y)
                      var clampedX = Math.max(4, Math.min(localPos.x, root.width - contextMenu.width - 4))
                      var clampedY = Math.max(4, localPos.y)

                      contextMenu.x = clampedX
                      contextMenu.y = clampedY
                      contextMenu.open()
                  } else {
                      wasPressedHere = false
                  }
              }
          }
          // MouseArea {
          //     id: titleRowContextMenuArea
          //     anchors.fill: titleRow
          //     acceptedButtons: Qt.RightButton
          //     cursorShape: Qt.ArrowCursor
          //
          //     onClicked: function(mouse) {
          //         if (mouse.button === Qt.RightButton) {
          //             var localPos = mapToItem(root, mouse.x, mouse.y)
          //             var clampedX = Math.max(4, Math.min(localPos.x, root.width - contextMenu.width - 4))
          //             var clampedY = Math.max(4, localPos.y)
          //
          //             contextMenu.x = clampedX
          //             contextMenu.y = clampedY
          //             contextMenu.open()
          //         }
          //     }
          // }
      }

      // ============================================================
      // CONTEXT MENU POPUP
      // ============================================================
      Popup {
          id: contextMenu
          parent: root
          modal: false
          focus: true
          closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
          padding: 8

          background: Rectangle {
              id: popupSurface
              anchors.fill: parent
              color: "#181818"
              border.color: "#303030"
              border.width: 1
              radius: 12

              layer.enabled: true
              layer.effect: MultiEffect {
                  shadowEnabled: true
                  shadowColor: "#90000000"
                  shadowBlur: 0.65
                  shadowVerticalOffset: 6
                  shadowHorizontalOffset: 0
              }
          }

          enter: Transition {
              NumberAnimation {
                  property: "opacity"
                  from: 0.0
                  to: 1.0
                  duration: 150
                  easing.type: Easing.OutCubic
              }
              NumberAnimation {
                  property: "scale"
                  from: 0.95
                  to: 1.0
                  duration: 180
                  easing.type: Easing.OutCubic
              }
          }

          exit: Transition {
              NumberAnimation {
                  property: "opacity"
                  from: 1.0
                  to: 0.0
                  duration: 120
                  easing.type: Easing.OutCubic
              }
              NumberAnimation {
                  property: "scale"
                  from: 1.0
                  to: 0.95
                  duration: 120
                  easing.type: Easing.OutCubic
              }
          }

          contentItem: ColumnLayout {
              id: popupLayout
              spacing: 2
              width: 180

              // Toggle Floating / Docking
  // In TitleBarBase.qml -> contextMenu -> ContextMenuRow (Float/Dock action)
// Toggle Floating / Docking
            ContextMenuRow {
                visible: root.floatButtonVisible
                enabled_: root.floatButtonVisible
                iconSource: root.isFloating ? "qrc:/assets/icons/minimize.svg" : "qrc:/assets/icons/maximize.svg"
                text: root.isFloating ? "Dock" : "Float"
                tooltip: root.isFloating ? "Docks window back into main layout" : "Detaches window into floating mode"
                onClicked: {
                    root.isFloatingTransition = true
                    contextMenu.close()
                    floatingTransitionTimer.restart()

                    Qt.callLater(function() {
                        if (root.dockWidget && typeof root.dockWidget.setFloating === "function") {
                            root.dockWidget.setFloating(!root.isFloating)
                            return
                        }
                        root.floatButtonClicked()
                    })
                }
            }
            // ContextMenuRow {
            //     visible: root.floatButtonVisible
            //     enabled_: root.floatButtonVisible
            //     iconSource: root.isFloating ? "qrc:/assets/icons/minimize.svg" : "qrc:/assets/icons/maximize.svg"
            //     text: root.isFloating ? "Dock" : "Float"
            //     tooltip: root.isFloating ? "Docks window back into main layout" : "Detaches window into floating mode"
            //     onClicked: {
            //         contextMenu.close()
            //         contextMenu.visible = false
            //         Qt.callLater(function() {
            //             if (root.dockWidget && typeof root.dockWidget.setFloating === "function") {
            //                 root.dockWidget.setFloating(!root.isFloating)
            //                 return
            //             }
            //             root.floatButtonClicked()
            //         })
            //     }
            // }
            // ContextMenuRow {
            //     visible: root.floatButtonVisible
            //     enabled_: root.floatButtonVisible
            //     iconSource: root.isFloating ? "qrc:/assets/icons/minimize.svg" : "qrc:/assets/icons/maximize.svg"
            //     text: root.isFloating ? "Dock" : "Float"
            //     tooltip: root.isFloating ? "Docks window back into main layout" : "Detaches window into floating mode"
            //     onClicked: {
            //         contextMenu.close()
            //         contextMenu.visible = false
            //         if (root.dockWidget && typeof root.dockWidget.setFloating === "function") {
            //             root.dockWidget.setFloating(!root.isFloating)
            //             return
            //         }
            //         root.floatButtonClicked()
            //     }
            // }

            // Subtle divider between Float and Close actions
            Rectangle {
                visible: root.floatButtonVisible && root.closeButtonEnabled
                Layout.fillWidth: true
                height: 1
                color: "#282828"
                Layout.topMargin: 3
                Layout.bottomMargin: 3
            }

            // Close Action
            ContextMenuRow {
                visible: root.closeButtonEnabled
                enabled_: root.closeButtonEnabled
                iconSource: "qrc:/assets/icons/x.svg"
                text: "Close"
                destructive: true
                tooltip: "Closes this dock window"
                onClicked: {
                    contextMenu.close()
                    contextMenu.visible = false
                    root.closeButtonClicked()
                }
            }
        }

        // ========================================================
        // CONTEXT MENU ROW COMPONENT
        // ========================================================
        component ContextMenuRow: Rectangle {
            id: row
            property string iconSource
            property string text
            property string shortcut: ""
            property bool destructive: false
            property bool showArrow: false
            property bool enabled_: true
            property string tooltip: ""

            signal clicked

            Layout.fillWidth: true
            implicitWidth: rowContent.implicitWidth + 18
            implicitHeight: rowContent.implicitHeight + 12
            radius: 7
            color: rowMouse.containsMouse && row.enabled_ ? "#252525" : "#181818"

            Behavior on color {
                ColorAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: row.enabled_ ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (row.enabled_) {
                        row.clicked()
                    }
                }
            }

            RowLayout {
                id: rowContent
                anchors.fill: parent
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                spacing: 10

                // Icon Container
                Item {
                    id: iconContainer
                    implicitWidth: 16
                    implicitHeight: 16
                    visible: row.iconSource !== ""
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        id: iconImg
                        anchors.fill: parent
                        source: row.iconSource
                        sourceSize: Qt.size(16, 16)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: iconImg
                        source: iconImg
                        colorization: 1.0
                        colorizationColor: row.enabled_
                            ? (row.destructive ? "#e06b6b" : (rowMouse.containsMouse ? "#ffffff" : "#d0d0d0"))
                            : "#555555"
                    }
                }

                // Action Label
                Text {
                    id: titleText
                    text: row.text
                    color: row.enabled_
                        ? (row.destructive ? "#e06b6b" : (rowMouse.containsMouse ? "#ffffff" : "#d0d0d0"))
                        : "#555555"
                    font.pixelSize: 12
                    Layout.minimumWidth: 90
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
