import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: settingsWindow
    // width: 1300
    // height: 900
    visible: false
    title: "Preferences"
    color: "#0E0E0E"
    property string innerTitle: "Settings"
    property string innerSubTitle: "Preferences" // "Preferences"

    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint | Qt.WindowMinimizeButtonHint | Qt.WindowCloseButtonHint

    // Intercept the close event to stop propagation and hide instead of destroy
    onClosing: function(closeEvent) {
        closeEvent.accepted = true; // Prevents the event from bubbling up to the parent/application quit handler
        settingsWindow.visible = false; // Hide the window safely
    }

    property int selectedPage: 0
    property int activeCategoryIndex: 0

    property var settingsList: []

    Component {
        id: selectComponent
        XylaSelect {
            property var itemData: null

            Layout.preferredWidth: 160
            implicitWidth: 160
            // backgroundColor: "#252525"
            // highlightedColor: "#2f2f2f"
            
            model: itemData ? (itemData.options || []) : []
            tooltip: itemData ? (itemData.label || "") : ""
            currentIndex: (itemData && itemData.value !== undefined && model) 
                          ? Math.max(0, model.indexOf(itemData.value)) 
                          : 0

            onActivated: {
                if (itemData) {
                    itemData.value = model[currentIndex];
                    // itemData.callback();
                }
            }
        }
    }

    Component {
        id: buttonComponent
        XylaTextButton {
            property var itemData: null

            text: itemData ? (itemData.buttonText || "Action") : "Action"
            onClicked: {
                if (itemData && typeof itemData.onClicked === "function") {
                    itemData.onClicked();
                    // itemData.callback();
                }
            }
        }
    }

Component {
        id: inputComponent
        Item {
            width: 250
            height: 32

            property var itemData: null

            TextField {
                anchors.fill: parent

                text: parent.itemData ? (parent.itemData.value || "") : ""
                color: "#ffffff"
                font.pixelSize: 12
                leftPadding: 10
                rightPadding: 10
                selectByMouse: true
                
                background: Rectangle {
                    color: "#181818"
                    border.color: parent.activeFocus ? "#2555D3" : "#2d2d2d"
                    border.width: 1
                    radius: 6
                }

                onEditingFinished: {
                    if (parent.itemData) {
                        parent.itemData.value = text;
                        // parent.itemData.callback();
                    }
                }
            }
        }
    }

    Component {
        id: switchComponent
        StyledSwitch {
            property var itemData: null
            checked: itemData ? Boolean(itemData.value) : false
            onToggled: {
                if (itemData) {
                    itemData.value = checked
                    itemData.callback(checked);
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#0E0E0E"
        border.color: "#0E0E0E"
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

    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        color: "#0E0E0E"
        topLeftRadius: 10
        topRightRadius: 10
        border.color: "#0E0E0E"
        border.width: 1
        visible: false

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
                text: settingsWindow.innerTitle // "Project Settings"
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
        anchors.top: parent.top // titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "#161616"

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 246
                Layout.fillHeight: true
                color: "#141414"

                // Rectangle {
                //     anchors.right: parent.right
                //     anchors.top: parent.top
                //     anchors.bottom: parent.bottom
                //     width: 1
                //     color: "#303030"
                // }

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
        id: preferencesTitle
        text: settingsWindow.innerSubTitle // "Preferences"
        color: "#ffffff"
        font.pixelSize: 24
        font.weight: Font.DemiBold
        Layout.leftMargin: 12
        Layout.bottomMargin: 12

        opacity: 0.0

        Component.onCompleted: {
            fadeInAnimTitle.restart();
        }

        NumberAnimation {
            id: fadeInAnimTitle
            target: preferencesTitle
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

Repeater {
    id: settingsNavRepeater
    model: settingsWindow.settingsList

    delegate: Rectangle {
        id: navItem
        required property var modelData
        required property int index

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 6

        opacity: 0
        scale: 0.82
        transformOrigin: Item.Center
        transform: Translate { id: itemTranslation; y: 20 }

        function playEntry() {
            navItem.opacity = 0
            navItem.scale = 0.82
            itemTranslation.y = 20
            entryAnimation.restart()
        }

function snapToFinal() {
    navItem.opacity = 1.0
    navItem.scale = 1.0
    itemTranslation.y = 0
}

Connections {
    target: settingsWindow
    function onVisibleChanged() {
        if (settingsWindow.visible) navItem.playEntry()
    }
}
Component.onCompleted: {
    if (settingsWindow.visible) navItem.snapToFinal()
}

        SequentialAnimation {
            id: entryAnimation

            PauseAnimation {
                duration: 120 + navItem.index * 55
            }

            ParallelAnimation {
                NumberAnimation {
                    target: navItem
                    property: "opacity"
                    to: 1.0
                    duration: 280
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: navItem
                    property: "scale"
                    to: 1.0
                    duration: 350
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.3
                }

                NumberAnimation {
                    target: itemTranslation
                    property: "y"
                    to: 0
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.5
                }
            }
        }

        color: settingsWindow.selectedPage === index ? "#202020" : navMouse.containsMouse ? "#1D1D1D" : "#141414"

        Behavior on color {
            ColorAnimation { duration: 100 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 11

            Image {
                Layout.preferredWidth: 17
                Layout.preferredHeight: 17
                source: modelData.icon ? "qrc:/assets/icons/" + modelData.icon : "qrc:/assets/icons/settings.svg"
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

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: "#303030"
                        }

                        Text {
                            Layout.leftMargin: 12
                            Layout.topMargin: 8
                            text: "Xyla Preferences"
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

                        visible: false // targetItem !== null && opacity > 0
                        opacity: 0 // targetItem !== null ? 1.0 : 0.0
                        y: pillY
                        height: pillHeight

Component.onCompleted: {
  fadeInAnim.start();
}

SequentialAnimation {
    id: fadeInAnim

    PauseAnimation { duration: 300 }

    NumberAnimation {
        target: selectionPill
        property: "opacity"
        to: 1.0
        duration: 120
        easing.type: Easing.OutCubic
    }
}

                        Connections {
                            target: selectionPill.targetItem
                            ignoreUnknownSignals: true

                            function onScaleChanged() {
                                if (selectionPill.targetItem) selectionPill.updatePosition(selectionPill.targetItem);
                            }
                            function onYChanged() {
                                if (selectionPill.targetItem) selectionPill.updatePosition(selectionPill.targetItem);
                            }
                        }

                        Behavior on opacity { NumberAnimation { duration: 120 } }

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
                            if (!item) return;

                            Qt.callLater(function () {
                                if (!item || !selectionPill.parent) return;

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

                                if (pillAnim.running) pillAnim.stop();

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
                            if (item) selectionPill.updatePosition(item);
                        });
                    }
                }

                Component.onCompleted: {
                    Qt.callLater(function () {
                        var item = settingsNavRepeater.itemAt(0);
                        if (item) selectionPill.updatePosition(item);
                    });
                }
            }

            Item {
                id: pagesContainer
                Layout.fillWidth: true
                Layout.fillHeight: true

                Repeater {
                    model: settingsWindow.settingsList

                    delegate: Flickable {
    required property var modelData
    required property int index
    property int pageIndex: index
    property var pageData: modelData
                        
                        anchors.fill: parent
                        visible: settingsWindow.selectedPage === index
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: width
                        contentHeight: pageColumn.implicitHeight + 64
                        interactive: contentHeight > height

                        ColumnLayout {
                            id: pageColumn
                            width: Math.max(parent.width - anchors.leftMargin * 2, 600)
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.leftMargin: 48
                            anchors.topMargin: 38
                            spacing: 24

Item {
    id: pageTitleContainer
    Layout.fillWidth: true
    Layout.preferredHeight: 38
    Layout.bottomMargin: 8
    clip: true

    property bool isActive: settingsWindow.selectedPage === index

    onIsActiveChanged: {
        if (isActive && settingsWindow.hasPlayedInitialEntry) {
            incomingTitle.text = pageData.name
            incomingTitle.y = 28
            incomingTitle.scale = 0.9
            incomingTitle.opacity = 0.0

            currentTitle.text = pageData.name
            titleSlideAnim.restart()
        }
    }

    Component.onCompleted: {
        if (isActive) {
            currentTitle.text = pageData.name
            currentTitle.y = 0
            currentTitle.scale = 1.0
            currentTitle.opacity = 1.0
            incomingTitle.opacity = 0.0
            incomingTitle.y = 28
            incomingTitle.scale = 0.9
        }
    }

    Text {
        id: currentTitle
        text: pageData.name
        color: "#ffffff"
        font.pixelSize: 28
        font.weight: Font.DemiBold
        y: 0
        scale: 1.0
        opacity: 1.0
        transformOrigin: Item.Left
    }

    Text {
        id: incomingTitle
        text: pageData.name
        color: "#ffffff"
        font.pixelSize: 28
        font.weight: Font.DemiBold
        y: 28
        scale: 0.9
        opacity: 0.0
        transformOrigin: Item.Left
    }

    SequentialAnimation {
        id: titleSlideAnim
        ParallelAnimation {
            NumberAnimation {
                target: currentTitle
                property: "y"
                to: -28
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: currentTitle
                property: "scale"
                to: 0.95
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: currentTitle
                property: "opacity"
                to: 0.0
                duration: 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: incomingTitle
                property: "y"
                to: 0
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
            NumberAnimation {
                target: incomingTitle
                property: "scale"
                to: 1.0
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
            NumberAnimation {
                target: incomingTitle
                property: "opacity"
                to: 1.0
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        ScriptAction {
            script: {
                currentTitle.text = incomingTitle.text
                currentTitle.y = 0
                currentTitle.scale = 1.0
                currentTitle.opacity = 1.0
                incomingTitle.opacity = 0.0
                incomingTitle.y = 28
                incomingTitle.scale = 0.9
            }
        }
    }
}

Repeater {
    model: pageData.sections

    delegate: ColumnLayout {
        id: sectionLayout
        required property var modelData
        required property int index
        property var sectionData: modelData 

        Layout.fillWidth: true
        spacing: 12

        Text {
            id: sectionTitle
            text: sectionData.title
            color: "#a8a8a8"
            font.pixelSize: 13
            font.weight: Font.Medium
            Layout.bottomMargin: 4


    opacity: 0
    scale: 0.82
    transformOrigin: Item.Center
    transform: Translate { id: titleTranslation; y: 20 }

    function playEntry() {
        sectionTitle.opacity = 0
        sectionTitle.scale = 0.82
        titleTranslation.y = 20
        titleAnim.restart()
    }

    function snapToFinal() {
        sectionTitle.opacity = 1.0
        sectionTitle.scale = 1.0
        titleTranslation.y = 0
    }

    Connections {
        target: settingsWindow
        function onVisibleChanged() {
            if (settingsWindow.visible && settingsWindow.selectedPage === pageIndex)
                sectionTitle.playEntry()
        }
        function onSelectedPageChanged() {
            if (settingsWindow.visible && settingsWindow.selectedPage === pageIndex)
                sectionTitle.playEntry()
        }
    }

    Component.onCompleted: {
        if (settingsWindow.visible && settingsWindow.selectedPage === pageIndex)
            sectionTitle.snapToFinal()
    }


            SequentialAnimation {
                id: titleAnim
                PauseAnimation {
                    duration: 120 + (sectionLayout.index * 70)
                }
                ParallelAnimation {
                    NumberAnimation { target: sectionTitle; property: "opacity"; to: 1.0; duration: 280; easing.type: Easing.OutCubic }
                    NumberAnimation { target: sectionTitle; property: "scale"; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                    NumberAnimation { target: titleTranslation; property: "y"; to: 0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                }
            }
        }

        Repeater {
            model: sectionData.items

delegate: SettingCard {
    id: card
    required property var modelData
    required property int index
    property var itemData: modelData 

    title: itemData ? itemData.label : ""
    description: (itemData && itemData.description) ? itemData.description : ""

    opacity: 0
    scale: 0.82
    transformOrigin: Item.Center
    transform: Translate { id: cardTranslation; y: 20 }

    function playEntry() {
        card.opacity = 0
        card.scale = 0.82
        cardTranslation.y = 20
        cardAnim.restart()
    }

Item {
    function playEntry() {
        card.opacity = 0
        card.scale = 0.82
        cardTranslation.y = 20
        cardAnim.restart()
    }

    function snapToFinal() {
        card.opacity = 1.0
        card.scale = 1.0
        cardTranslation.y = 0
    }

    Connections {
        target: settingsWindow
        function onVisibleChanged() {
            if (settingsWindow.visible && settingsWindow.selectedPage === pageIndex)
                playEntry()
        }
        function onSelectedPageChanged() {
            if (settingsWindow.visible && settingsWindow.selectedPage === pageIndex)
                playEntry()
        }
    }

    Component.onCompleted: {
        if (settingsWindow.visible && settingsWindow.selectedPage === pageIndex)
            snapToFinal()
    }

    SequentialAnimation {
        id: cardAnim
        PauseAnimation {
            duration: 120 + (sectionLayout.index * 70) + ((card.index + 1) * 45)
        }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 1.0; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
            NumberAnimation { target: cardTranslation; property: "y"; to: 0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
    }
}

Loader {
        id: controlLoader
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        
        sourceComponent: {
            if (!card.itemData || !card.itemData.type) return null;
            
            switch (card.itemData.type) {
                case "select": return selectComponent;
                case "input": return inputComponent;
                case "toggle":
                case "switch": return switchComponent;
                case "button": return buttonComponent;
                case "custom": return card.itemData.componentData;
                default: return null;
            }
        }

        Binding {
            target: controlLoader.item
            property: "itemData"
            value: card.itemData
            when: controlLoader.status === Loader.Ready
        }
    }
}
        }
    }
}
                        }
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
        color: cardHoverHandler.hovered ? "#1E1E1E" : "#1C1C1C"
        border.color: "#1D1D1D"
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
                
                implicitWidth: children[0] ? children[0].implicitWidth : 0
                implicitHeight: children[0] ? children[0].implicitHeight : 0
                
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
            color: control.checked ? "#11389F" : "#101010"
            border.color: control.checked ? "#11389F" : "#101010"
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
