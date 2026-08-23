import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

MenuItem {
    id: control
    implicitHeight: 32

    // Pull text string out of the action payload and bind it to the core MenuItem property
    text: control.action ? control.action.text : ""

    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding

    property string descriptionText: ""

    ToolTip.visible: control.hovered && control.descriptionText !== ""
    ToolTip.delay: 500
    ToolTip.text: control.descriptionText

    contentItem: RowLayout {
        spacing: 10

        anchors.top: parent.top
        anchors.bottom: parent.bottom

        implicitWidth: iconContainer.visibleWidth + titleText.implicitWidth + shortcutText.implicitWidth + (spacing * 2)

        // Vector Asset Layout Frame
        Item {
            id: iconContainer
            implicitWidth: 16
            implicitHeight: 16
            property int visibleWidth: visible ? 16 : 0
            visible: !!(control.action && control.action.icon.source.toString())
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: iconImg
                anchors.fill: parent
                source: (control.action && control.action.icon.source) ? control.action.icon.source : ""
                sourceSize.width: 16
                sourceSize.height: 16
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: false
            }

            MultiEffect {
                source: iconImg
                anchors.fill: iconImg
                colorization: 1.0
                colorizationColor: control.highlighted ? "#ffffff" : "#a0a0a0"
            }
        }

        // Title Text
        Text {
            id: titleText
            // FIX: Bind straight to control.text which now safely mirrors the action payload text string
            text: control.text
            color: control.enabled ? (control.highlighted ? "#ffffff" : "#d0d0d0") : "#555555"
            font.pixelSize: 12

            Layout.minimumWidth: 120
            Layout.fillWidth: true

            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        // Key Binding Label
        Text {
            id: shortcutText
            text: (control.action && control.action.shortcut) ? control.action.shortcut : ""
            color: "#666666"
            font.pixelSize: 11
            visible: text !== ""

            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
        }
    }

    leftPadding: 12
    rightPadding: 12

    background: Rectangle {
        color: control.highlighted ? "#2555D3" : "#181818"
        radius: 4

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
    }
}
