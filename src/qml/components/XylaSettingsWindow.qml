import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects

Window {
    id: settingsWindow

    width: 1040
    height: 720
    minimumWidth: 860
    minimumHeight: 620
    visible: false
    title: "Settings"
    color: "#121212"

    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint | Qt.WindowMinimizeButtonHint | Qt.WindowCloseButtonHint

    property bool showHiddenFiles: true
    property bool showFileExtensions: true
    property bool confirmDelete: true
    property bool rememberLastFolder: true
    property bool breadcrumbCollapse: true
    property bool smoothAnimations: true
    property bool useCompactRows: false

    property string theme: "Dark"
    property string defaultView: "Grid"
    property string sortMode: "Name"
    property string startupLocation: "Home"
    property int selectedPage: 0

    Rectangle {
        anchors.fill: parent
        color: "#121212"

        Rectangle {
            anchors.fill: parent
            color: "#121212"
            border.color: "#202020"
            border.width: 1
            radius: 10
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: "#ffffff"
            opacity: 0.08
        }
    }

    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        color: "#181818"

        topLeftRadius: 10
        topRightRadius: 10

        border.color: "#202020"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 8
            spacing: 10

            Image {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: "qrc:/assets/icons/settings.svg"
                sourceSize: Qt.size(18, 18)
                opacity: 0.92
            }

            Text {
                text: "Settings"
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Item {
                Layout.fillWidth: true
            }

            XylaIconButton {
                id: closeBtn

                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 2

                tooltip: "Close"
                ghost: true
                iconSource: "qrc:/assets/icons/x.svg"

                onClicked: settingsWindow.close()
            }
        }
    }

    Rectangle {
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "#202020"

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 246
                Layout.fillHeight: true
                color: "#1d1d1d"

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: "#303030"
                }

                Item {
                    anchors.fill: parent

                    ColumnLayout {
                        id: settingsNavColumn

                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 18
                        anchors.bottomMargin: 16
                        spacing: 4

                        Text {
                            text: "Settings"
                            color: "#ffffff"
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                            Layout.leftMargin: 12
                            Layout.bottomMargin: 12
                        }

                        Repeater {
                            id: settingsNavRepeater
                            model: [
                                {
                                    name: "System",
                                    icon: "qrc:/assets/icons/settings.svg"
                                },
                                {
                                    name: "Appearance",
                                    icon: "qrc:/assets/icons/image.svg"
                                },
                                {
                                    name: "Files & Folders",
                                    icon: "qrc:/assets/icons/folder.svg"
                                },
                                {
                                    name: "Behavior",
                                    icon: "qrc:/assets/icons/sliders.svg"
                                }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: 6

                                color: settingsWindow.selectedPage === index ? "#2b2b2b" : navMouse.containsMouse ? "#252525" : "#1d1d1d"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 100
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    spacing: 11

                                    Image {
                                        Layout.preferredWidth: 17
                                        Layout.preferredHeight: 17
                                        source: modelData.icon
                                        sourceSize: Qt.size(17, 17)
                                        opacity: settingsWindow.selectedPage === index ? 1.0 : 0.72
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: settingsWindow.selectedPage === index ? "#ffffff" : "#d0d0d0"
                                        font.pixelSize: 13
                                        font.weight: settingsWindow.selectedPage === index ? Font.Medium : Font.Normal
                                    }
                                }

                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWindow.selectedPage = index
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: "#303030"
                        }

                        Text {
                            Layout.leftMargin: 12
                            Layout.topMargin: 8
                            text: "Xyla File Manager"
                            color: "#777777"
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        id: selectionPill
                        width: 3
                        radius: 1.5
                        color: "#0078d4"
                        x: 12
                        z: 10

                        property Item targetItem: null
                        property real baseHeight: 16
                        property real pillY: 0
                        property real pillHeight: baseHeight

                        visible: targetItem !== null
                        opacity: targetItem !== null ? 1.0 : 0.0

                        y: pillY
                        height: pillHeight

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }

                        SequentialAnimation {
                            id: pillAnim

                            property real startY: 0
                            property real targetY: 0
                            property real startHeight: selectionPill.baseHeight
                            property real distance: 0
                            property bool movingDown: true

                            onStarted: {
                                distance = Math.abs(targetY - startY);
                                movingDown = targetY > startY;
                            }

                            ParallelAnimation {
                                NumberAnimation {
                                    target: selectionPill
                                    property: "pillY"
                                    from: pillAnim.startY
                                    to: pillAnim.movingDown ? pillAnim.startY : pillAnim.targetY
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: selectionPill
                                    property: "pillHeight"
                                    from: pillAnim.startHeight
                                    to: selectionPill.baseHeight + pillAnim.distance
                                    duration: 140
                                    easing.type: Easing.OutCubic
                                }
                            }

                            ParallelAnimation {
                                NumberAnimation {
                                    target: selectionPill
                                    property: "pillY"
                                    from: pillAnim.movingDown ? pillAnim.startY : pillAnim.targetY
                                    to: pillAnim.targetY
                                    duration: 40
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: selectionPill
                                    property: "pillHeight"
                                    from: selectionPill.baseHeight + pillAnim.distance
                                    to: selectionPill.baseHeight
                                    duration: 40
                                    easing.type: Easing.OutCubic
                                }
                            }

                            onFinished: {
                                selectionPill.pillY = targetY;
                                selectionPill.pillHeight = selectionPill.baseHeight;
                            }
                        }

                        function updatePosition(item) {
                            if (!item)
                                return;

                            Qt.callLater(function () {
                                if (!item || !selectionPill.parent)
                                    return;

                                var p = item.mapToItem(selectionPill.parent, 0, 0);
                                var newY = p.y + (item.height - selectionPill.baseHeight) / 2;

                                if (targetItem === null) {
                                    targetItem = item;
                                    pillY = newY;
                                    pillHeight = baseHeight;
                                    return;
                                }

                                if (targetItem === item) {
                                    pillY = newY;
                                    return;
                                }

                                var currentY = pillY;
                                var currentHeight = pillHeight;

                                if (pillAnim.running)
                                    pillAnim.stop();

                                pillAnim.startY = currentY;
                                pillAnim.targetY = newY;
                                pillAnim.startHeight = currentHeight;

                                targetItem = item;
                                pillAnim.start();
                            });
                        }
                    }
                }

                Connections {
                    target: settingsWindow

                    function onSelectedPageChanged() {
                        Qt.callLater(function () {
                            var item = settingsNavRepeater.itemAt(settingsWindow.selectedPage);
                            if (item)
                                selectionPill.updatePosition(item);
                        });
                    }
                }

                Component.onCompleted: {
                    Qt.callLater(function () {
                        var item = settingsNavRepeater.itemAt(0);
                        if (item)
                            selectionPill.updatePosition(item);
                    });
                }
            }

            Item {
                id: pagesContainer
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    anchors.fill: parent
                    visible: settingsWindow.selectedPage === 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: systemColumn.implicitHeight + 64
                    interactive: false

                    ColumnLayout {
                        id: systemColumn
                        width: Math.max(parent.width - anchors.leftMargin * 2, 600)
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: 48
                        anchors.topMargin: 38
                        spacing: 18

                        Text {
                            text: "System"
                            color: "#ffffff"
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "General file manager preferences"
                            color: "#a8a8a8"
                            font.pixelSize: 12
                        }

SettingCard {
    id: presetPalette
    title: "Default location"
    description: "Choose where Xyla opens when you start a new window."

    // Local property safely scoped to the SettingCard container
    property bool isCustom: {
        var presets = ["Home", "Desktop", "Documents", "Downloads", "Pictures", "Music", "Videos"];
        return !presets.includes(fileSystemModel.fileManagerSettings.startupLocation);
    }
    property int lastPresetIndex: {
        var presets = ["Home", "Desktop", "Documents", "Downloads", "Pictures", "Music", "Videos"];
        var index = presets.indexOf(fileSystemModel.fileManagerSettings.startupLocation);
        return index >= 0 ? index : 0;
    }
    property bool userClickedCustom: false

    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            // Dropdown visible ONLY when NOT in custom mode
            XylaSelect {
                id: locationSelect
                Layout.preferredWidth: 140
                visible: !presetPalette.isCustom
                backgroundColor: "#252525"
                highlightedColor: "#2f2f2f"
                
                model: ["Home", "Desktop", "Documents", "Downloads", "Pictures", "Music", "Videos", "Custom"]
                tooltip: "Select Default Location"

                currentIndex: {
                    var presetIndex = model.indexOf(fileSystemModel.fileManagerSettings.startupLocation);
                    return presetIndex !== -1 ? presetIndex : presetPalette.lastPresetIndex;
                }

                onActivated: {
                    var selected = model[currentIndex];

                    if (selected !== "Custom") {
                        presetPalette.lastPresetIndex = currentIndex;
                        fileSystemModel.fileManagerSettings.startupLocation = selected;
                    } else {
                        presetPalette.userClickedCustom = true;
                        presetPalette.isCustom = true;
                        customPathInput.forceActiveFocus();
                    }
                }
            }

            // Text input visible ONLY when in custom mode
            TextField {
                id: customPathInput
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                visible: presetPalette.isCustom
                
                placeholderText: "Enter absolute path (e.g., /home/user/Projects)"
                placeholderTextColor: "#555555"
                color: "#ffffff"
                font.pixelSize: 12
                leftPadding: 10
                rightPadding: 10
                selectByMouse: true
                
                // text: presetPalette.isCustom ? fileSystemModel.fileManagerSettings.startupLocation : ""
                text: presetPalette.isCustom && !presetPalette.userClickedCustom ? fileSystemModel.fileManagerSettings.startupLocation : ""

                onEditingFinished: {
                    if (text.trim() !== "") {
                        fileSystemModel.fileManagerSettings.startupLocation = text.trim();
                    } else {
                        fileSystemModel.fileManagerSettings.startupLocation = "Home";
                        presetPalette.userClickedCustom = false;
                        presetPalette.isCustom = false;
                    }
                }

                background: Rectangle {
                    color: "#181818"
                    border.color: customPathInput.activeFocus ? "#2555D3" : "#2d2d2d"
                    border.width: 1
                    radius: 6
                }
            }


                XylaIconButton {
                    ghost: true
                    visible: presetPalette.isCustom
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    tooltip: "Switch to preset locations"
                    iconSource: "qrc:/assets/icons/clear.svg"
                    onClicked: {
                        fileSystemModel.fileManagerSettings.startupLocation = "Home";
                        presetPalette.userClickedCustom = false;
                        presetPalette.isCustom = false;
                    }
                }
        }
    }
}
                        // SettingCard {
                        //     title: "Default location"
                        //     description: "Choose where Xyla opens when you start a new window."
                        //
                        //     XylaSelect {
                        //         Layout.preferredWidth: 140
                        //         backgroundColor: "#252525"
                        //         highlightedColor: "#2f2f2f"
                        //         model: ["Home", "Desktop", "Documents", "Downloads", "Pictures", "Music", "Videos"]
                        //         tooltip: "Select Default Location"
                        //
                        //         currentIndex: model.indexOf(fileSystemModel.fileManagerSettings.startupLocation)
                        //
                        //         onActivated: {
                        //             fileSystemModel.fileManagerSettings.startupLocation = model[currentIndex];
                        //         }
                        //     }
                        // }

                        SettingCard {
                            title: "Default view"
                            description: "Choose how files are displayed when opening a folder."

                            XylaSelect {
                                Layout.preferredWidth: 140

                                backgroundColor: "#252525"
                                highlightedColor: "#2f2f2f"

                                model: ["Grid", "List"]
                                tooltip: "Select Default View"

                                currentIndex: model.indexOf(fileSystemModel.fileManagerSettings.defaultView)

                                onActivated: {
                                    fileSystemModel.fileManagerSettings.defaultView = model[currentIndex];
                                }
                            }
                        }

                        SettingCard {
                            title: "Remember last folder"
                            description: "Restore the last location when reopening Xyla."

                            StyledSwitch {
                                checked: fileSystemModel.fileManagerSettings.rememberLastFolder
                                onToggled: fileSystemModel.fileManagerSettings.rememberLastFolder = checked
                            }
                        }

                        SettingCard {
                            title: "Confirm before deleting"
                            description: "Ask before moving files or folders to the trash."

                            StyledSwitch {
                                checked: fileSystemModel.fileManagerSettings.confirmDelete
                                onToggled: fileSystemModel.fileManagerSettings.confirmDelete = checked
                            }
                        }
                    }
                }

                Flickable {
                    anchors.fill: parent
                    visible: settingsWindow.selectedPage === 1
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: appearanceColumn.implicitHeight + 64

                    ColumnLayout {
                        id: appearanceColumn
                        width: Math.max(parent.width - anchors.leftMargin * 2, 600)
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: 48
                        anchors.topMargin: 38
                        spacing: 18

                        Text {
                            text: "Appearance"
                            color: "#ffffff"
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "Personalize how Xyla looks and behaves."
                            color: "#a8a8a8"
                            font.pixelSize: 12
                        }

                        // SettingCard {
                        //     title: "App theme"
                        //     description: "Choose the color mode used by the application."
                        //
                        //     XylaSelect {
                        //         Layout.preferredWidth: 140
                        //         backgroundColor: "#252525"
                        //         model: ["Dark", "Light", "Use system setting"]
                        //         onCurrentTextChanged: settingsWindow.theme = currentText
                        //     }
                        // }

                        SettingCard {
                            title: "Smooth animations"
                            description: "Use Fluent-style transitions for navigation and menus."

                            StyledSwitch {
                                checked: fileSystemModel.fileManagerSettings.smoothAnimations
                                onToggled: fileSystemModel.fileManagerSettings.smoothAnimations = checked
                            }
                        }
                    }
                }

                Flickable {
                    anchors.fill: parent
                    visible: settingsWindow.selectedPage === 2
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: filesColumn.implicitHeight + 64

                    ColumnLayout {
                        id: filesColumn
                        width: Math.max(parent.width - anchors.leftMargin * 2, 600)
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: 48
                        anchors.topMargin: 38
                        spacing: 18

                        Text {
                            text: "Files & Folders"
                            color: "#ffffff"
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "Control what is shown and how folders are handled."
                            color: "#a8a8a8"
                            font.pixelSize: 12
                        }

                        SettingCard {
                            title: "Show hidden files"
                            description: "Display hidden and system items in file views."

                            StyledSwitch {
                                checked: fileSystemModel.fileManagerSettings.showHiddenFiles
                                onToggled: fileSystemModel.fileManagerSettings.showHiddenFiles = checked
                            }
                        }

                        SettingCard {
                            title: "Show file extensions"
                            description: "Always display extensions such as .txt, .png and .cpp."

                            StyledSwitch {
                                checked: fileSystemModel.fileManagerSettings.showFileExtensions
                                onToggled: fileSystemModel.fileManagerSettings.showFileExtensions = checked
                            }
                        }

                        SettingCard {
                            title: "Sort folders by"
                            description: "Choose the default sorting field for file lists."

                            XylaSelect {
                                Layout.preferredWidth: 140

                                backgroundColor: "#252525"
                                highlightedColor: "#2f2f2f"
                                tooltip: "Select Default Sort"

                                model: ["Name", "Date Modified", "Size", "Type"]

                                currentIndex: model.indexOf(fileSystemModel.fileManagerSettings.sortMode)

                                onActivated: {
                                    fileSystemModel.fileManagerSettings.sortMode = model[currentIndex];
                                }
                            }
                        }
                    }
                }

                Flickable {
                    anchors.fill: parent
                    visible: settingsWindow.selectedPage === 3
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: behaviorColumn.implicitHeight + 64

                    ColumnLayout {
                        id: behaviorColumn
                        width: Math.max(parent.width - anchors.leftMargin * 2, 600)
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: 48
                        anchors.topMargin: 38
                        spacing: 18

                        Text {
                            text: "Behavior"
                            color: "#ffffff"
                            font.pixelSize: 28
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "Fine-tune interaction and navigation behavior."
                            color: "#a8a8a8"
                            font.pixelSize: 12
                        }

                        SettingCard {
                            title: "Open folders with double-click"
                            description: "Require a double-click to open folders from the file view."

                            StyledSwitch {
                                checked: fileSystemModel.fileManagerSettings.openFoldersWithDoubleClick
                                onToggled: fileSystemModel.fileManagerSettings.openFoldersWithDoubleClick = checked
                            }
                        }

                        SettingCard {
                            title: "Show tooltips"
                            description: "Display helpful descriptions when hovering over controls."

                            StyledSwitch {
                                checked: fileSystemModel.fileManagerSettings.showTooltips
                                onToggled: fileSystemModel.fileManagerSettings.showTooltips = checked
                            }
                        }

                        // SettingCard {
                        //     title: "Reset settings"
                        //     description: "Restore Xyla's interface preferences to their defaults."
                        //
                        //     StyledButton {
                        //         text: "Reset"
                        //         onClicked: resetConfirm.open()
                        //     }
                        // }
                    }
                }
            }
        }
    }

    Popup {
        id: resetConfirm

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 390
        padding: 20
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 12
            color: "#181818"
            border.color: "#303030"
            border.width: 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.65
                shadowVerticalOffset: 6
            }
        }

        contentItem: ColumnLayout {
            spacing: 14

            Text {
                text: "Reset settings?"
                color: "#ffffff"
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: "This will restore Xyla's interface preferences to their default values."
                color: "#a8a8a8"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                StyledButton {
                    text: "Cancel"
                    onClicked: resetConfirm.close()
                }

                StyledButton {
                    text: "Reset"
                    accent: true
                    onClicked: {
                        settingsWindow.showHiddenFiles = true;
                        settingsWindow.showFileExtensions = true;
                        settingsWindow.confirmDelete = true;
                        settingsWindow.rememberLastFolder = true;
                        settingsWindow.breadcrumbCollapse = true;
                        settingsWindow.smoothAnimations = true;
                        settingsWindow.useCompactRows = false;
                        settingsWindow.theme = "Dark";
                        settingsWindow.defaultView = "Grid";
                        settingsWindow.sortMode = "Name";
                        settingsWindow.startupLocation = "Home";
                        resetConfirm.close();
                    }
                }
            }
        }
    }

    component SettingCard: Rectangle {
        property string title: ""
        property string description: ""
        default property alias control: controlSlot.children

        Layout.fillWidth: true
        implicitHeight: 72
        radius: 8
        color: cardHoverHandler.hovered ? "#292929" : "#252525"
        border.color: "#333333"
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        HoverHandler {
            id: cardHoverHandler
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: title
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    Layout.fillWidth: true
                    text: description
                    color: "#969696"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }

            Item {
                id: controlSlot
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    component StyledSwitch: Switch {
        id: control

        implicitWidth: 44
        implicitHeight: 24

        indicator: Rectangle {
            implicitWidth: 44
            implicitHeight: 24
            x: control.leftPadding
            y: parent.height / 2 - height / 2
            radius: 12
            color: control.checked ? "#11389F" : "#3a3a3a"
            border.color: control.checked ? "#11389F" : "#555555"
            border.width: control.checked ? 0 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                y: 3
                x: control.checked ? parent.width - width - 3 : 3
                color: "#ffffff"

                Behavior on x {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        contentItem: Item {}
    }

    component StyledButton: Button {
        id: button

        property bool accent: false

        implicitWidth: Math.max(84, contentItem.implicitWidth + 28)
        implicitHeight: 34

        contentItem: Text {
            text: button.text
            color: button.accent ? "#ffffff" : "#eeeeee"
            font.pixelSize: 12
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 6
            color: button.accent ? (button.pressed ? "#0e2d80" : button.hovered ? "#1644bf" : "#11389F") : (button.pressed ? "#383838" : button.hovered ? "#303030" : "#292929")
            border.color: button.accent ? "#11389F" : "#454545"
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 90
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            selectedPage = 0;
            Qt.callLater(function () {
                var item = settingsNavRepeater.itemAt(0);
                if (item)
                    selectionPill.updatePosition(item);
            });
        }
    }
}
