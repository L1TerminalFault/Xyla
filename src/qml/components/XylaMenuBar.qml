import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root
    implicitHeight: 38
    width: parent ? parent.width : 1280

    property string activeWorkspace: "Edit"
    readonly property var workspaceProfiles: [
        {
            id: "Edit",
            name: "Editing",
            icon: "qrc:/assets/icons/edit.svg",
            tooltip: "Timeline editing, clips organization, and tracks arrangement"
        },
        {
            id: "Cut",
            name: "Cut",
            icon: "qrc:/assets/icons/scissors.svg",
            tooltip: "Quick trimming, ripple edits, and fast assembly"
        },
        {
            id: "Color",
            name: "Color",
            icon: "qrc:/assets/icons/palette.svg",
            tooltip: "Color correction, grading, scopes, and look adjustments"
        },
        {
            id: "Audio",
            name: "Audio",
            icon: "qrc:/assets/icons/audio.svg",
            tooltip: "Audio mixing, track levels, effects, and sound cleanup"
        },
        {
            id: "View",
            name: "View",
            icon: "qrc:/assets/icons/maximize.svg",
            tooltip: "Full video preview playback"
        }
    ]

    signal workspaceChanged(string newWorkspace, string oldWorkspace)

    Rectangle {
        anchors.fill: parent
        color: "#0E0E0E"
    }

    readonly property real availableMenuWidth: root.width - (brandRow.width + 24) - (tabsContainer.width + 24)
    readonly property bool isCompactMode: availableMenuWidth < standardMenuBar.implicitWidth

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Row {
            id: brandRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            Rectangle {
                width: 22
                height: 22
                radius: 6
                color: "#000000"
                anchors.verticalCenter: parent.verticalCenter

                XIcon {
                    id: icon
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: icon.restartAnimation()
                }
            }
        }

            // SAFE RESTORED FEATURE: Compact hamburger icon layer
            XylaIconButton {
                id: compactMenuBtn
                visible: root.isCompactMode
                iconSource: "qrc:/assets/icons/menu.svg"
                ghost: true
                primary: compactMenuPopup.visible
                tooltip: "Application Menu"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    if (compactMenuPopup.visible) compactMenuPopup.close()
                    else compactMenuPopup.open()
                }

                XylaMenu {
                    id: compactMenuPopup
                    y: compactMenuBtn.height + 6

                    Instantiator {
                        model: typeof menuManager !== "undefined" ? menuManager.menuTree : []
                        delegate: XylaMenu {
                            id: compactTopSubMenu
                            title: modelData.title || ""
                            menuIcon: ""
                            menuDescription: modelData.description || ""

                            Instantiator {
                                model: modelData.items || []
                                delegate: QtObject {
                                    id: compactSubItemFactory
                                    property var itemData: modelData
                                    property var createdVisualItem: {
                                        if (!itemData) return null;
                                        if (itemData.isSeparator) return separatorComp.createObject(compactTopSubMenu);
                                        if (itemData.isSubmenu) return submenuComp.createObject(compactTopSubMenu, { subMenuData: itemData });
                                        return menuItemComp.createObject(compactTopSubMenu, { itemData: itemData });
                                    }
                                    Component.onDestruction: {
                                        if (createdVisualItem) {
                                            if (itemData && itemData.isSubmenu) compactTopSubMenu.removeMenu(createdVisualItem);
                                            else compactTopSubMenu.removeItem(createdVisualItem);
                                            createdVisualItem.destroy();
                                        }
                                    }
                                }
                                onObjectAdded: (idx, obj) => {
                                    if (!obj.createdVisualItem) return;
                                    if (obj.itemData && obj.itemData.isSubmenu) compactTopSubMenu.insertMenu(idx, obj.createdVisualItem);
                                    else compactTopSubMenu.insertItem(idx, obj.createdVisualItem);
                                }
                                onObjectRemoved: (idx, obj) => {
                                    if (!obj.createdVisualItem) return;
                                    if (obj.itemData && obj.itemData.isSubmenu) compactTopSubMenu.removeMenu(obj.createdVisualItem);
                                    else compactTopSubMenu.removeItem(obj.createdVisualItem);
                                }
                            }
                        }
                        onObjectAdded: (index, object) => compactMenuPopup.insertMenu(index, object)
                        onObjectRemoved: (index, object) => compactMenuPopup.removeMenu(object)
                    }
                }
            }

        Item {
            id: menuBarWrapper
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.isCompactMode
            clip: true

            MenuBar {
                id: standardMenuBar
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                background: Item {}

                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0

                delegate: MenuBarItem {
                    id: menuBarItem
                    implicitHeight: 28

                    contentItem: Row {
                        spacing: 5
                        anchors.centerIn: parent
                        leftPadding: 6
                        rightPadding: 6

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            fillMode: Image.PreserveAspectFit
                            source: (menuBarItem.menu && menuBarItem.menu.menuIcon) ? menuBarItem.menu.menuIcon : ""
                            visible: source !== "" && status === Image.Ready
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: menuBarItem.text
                            color: menuBarItem.enabled ? (menuBarItem.highlighted ? "#ffffff" : "#cccccc") : "#555555"
                            font.pixelSize: 12
                            font.weight: Font.Normal
                        }
                    }

                    background: Rectangle {
                        anchors.fill: parent
                        radius: 5
                        color: menuBarItem.highlighted ? "#262626" : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                Instantiator {
                    model: typeof menuManager !== "undefined" ? menuManager.menuTree : []

                    delegate: XylaMenu {
                        id: topMenu
                        title: modelData.title || ""
                        menuIcon: (modelData && modelData.icon) ? modelData.icon : ""
                        menuDescription: (modelData && modelData.description) ? modelData.description : ""

                        Instantiator {
                            model: modelData.items || []

                            delegate: QtObject {
                                id: itemFactory
                                property var itemData: modelData
                                property var createdVisualItem: {
                                    if (!itemData)
                                        return null;
                                    if (itemData.isSeparator) {
                                        return separatorComp.createObject(topMenu);
                                    } else if (itemData.isSubmenu) {
                                        return submenuComp.createObject(topMenu, {
                                            subMenuData: itemData
                                        });
                                    } else {
                                        return menuItemComp.createObject(topMenu, {
                                            itemData: itemData
                                        });
                                    }
                                }

                                Component.onDestruction: {
                                    if (createdVisualItem) {
                                        if (itemData && itemData.isSubmenu)
                                            topMenu.removeMenu(createdVisualItem);
                                        else
                                            topMenu.removeItem(createdVisualItem);
                                        createdVisualItem.destroy();
                                    }
                                }
                            }

                            onObjectAdded: (idx, obj) => {
                                if (!obj.createdVisualItem)
                                    return;
                                if (obj.itemData && obj.itemData.isSubmenu)
                                    topMenu.insertMenu(idx, obj.createdVisualItem);
                                else
                                    topMenu.insertItem(idx, obj.createdVisualItem);
                            }

                            onObjectRemoved: (idx, obj) => {
                                if (!obj.createdVisualItem)
                                    return;
                                if (obj.itemData && obj.itemData.isSubmenu)
                                    topMenu.removeMenu(obj.createdVisualItem);
                                else
                                    topMenu.removeItem(obj.createdVisualItem);
                            }
                        }
                    }

                    onObjectAdded: (index, object) => standardMenuBar.insertMenu(index, object)
                    onObjectRemoved: (index, object) => standardMenuBar.removeMenu(object)
                }
            }
        }

        Item {
            Layout.fillWidth: true
            visible: root.isCompactMode
        }

        Item {
            id: tabsContainer
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitHeight: 30
            implicitWidth: tabsRow.implicitWidth + 10
            clip: false

            Rectangle {
                anchors.fill: parent
                color: "#050505"
                radius: 7
            }

            Item {
                id: followerTrack
                anchors.fill: parent
                clip: false
                z: 2

                readonly property Item currentTabItem: {
                    for (var i = 0; i < tabsRepeater.count; ++i) {
                        var itm = tabsRepeater.itemAt(i);
                        if (itm && itm.tabId === root.activeWorkspace)
                            return itm;
                    }
                    return null;
                }

                property real leftEdge: 4
                property real rightEdge: 54
                property real targetLeft: 4
                property real targetRight: 54
                property real previousLeft: 4
                property real previousRight: 54
                property bool movingRight: true

                // RESTORED FEATURES FROM PREV: Custom stretch coordinates 
                property real stretchLeft: 4
                property real stretchRight: 54

                function updateIndicator() {
                    var item = currentTabItem;
                    if (!item)
                        return;

                    var newLeft = tabsRow.x + item.x;
                    var newRight = newLeft + item.width;

                    previousLeft = leftEdge;
                    previousRight = rightEdge;
                    movingRight = newLeft > leftEdge;
                    targetLeft = newLeft;
                    targetRight = newRight;

                    // RESTORED FEATURES FROM PREV: Stretch phase destination calculation
                    if (movingRight) {
                        stretchRight = newRight;
                        stretchLeft = newLeft;
                    } else {
                        stretchLeft = newLeft;
                        stretchRight = newRight;
                    }

                    indicatorAnimation.restart();
                }

                Component.onCompleted: {
                    var item = currentTabItem;
                    if (item) {
                        leftEdge = tabsRow.x + item.x;
                        rightEdge = leftEdge + item.width;
                        targetLeft = leftEdge;
                        targetRight = rightEdge;

                        // RESTORED FEATURES FROM PREV: Complete initialization paths
                        stretchLeft = leftEdge;
                        stretchRight = rightEdge;
                    }
                }

                Connections {
                    target: root
                    function onActiveWorkspaceChanged() {
                        followerTrack.updateIndicator();
                    }
                }

                Connections {
                    target: tabsRepeater
                    function onItemAdded() {
                        Qt.callLater(followerTrack.updateIndicator);
                    }
                }

                Rectangle {
                    id: indicatorCapsule
                    x: followerTrack.leftEdge
                    width: Math.max(1, followerTrack.rightEdge - followerTrack.leftEdge)
                    anchors.top: parent.top
                    anchors.topMargin: 3
                    height: (parent.height - 3) + ((root.height - parent.height) / 2) + 1
                    color: "#191919"
                    topLeftRadius: 6
                    topRightRadius: 6

                    // RESTORED STYLES FROM PREV: Flat base configuration
                    bottomLeftRadius: 0
                    bottomRightRadius: 0

                    // RESTORED STYLES FROM PREV: Left Bleeding Corner Curve
                    Canvas {
                        id: leftCurve
                        anchors.right: parent.left
                        anchors.bottom: parent.bottom
                        width: 12
                        height: 12
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.fillStyle = "#191919";
                            ctx.beginPath();
                            ctx.moveTo(12, 0);
                            ctx.lineTo(12, 12);
                            ctx.lineTo(0, 12);
                            ctx.arcTo(12, 12, 12, 0, 12);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }

                    // RESTORED STYLES FROM PREV: Right Bleeding Corner Curve
                    Canvas {
                        id: rightCurve
                        anchors.left: parent.right
                        anchors.bottom: parent.bottom
                        width: 12
                        height: 12
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            ctx.fillStyle = "#191919";
                            ctx.beginPath();
                            ctx.moveTo(0, 0);
                            ctx.lineTo(0, 12);
                            ctx.lineTo(12, 12);
                            ctx.arcTo(0, 12, 0, 0, 12);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }

                SequentialAnimation {
                    id: indicatorAnimation

                    // PHASE 1: Stretch only the leading edge side we are moving towards
                    NumberAnimation {
                        target: followerTrack
                        property: followerTrack.movingRight ? "rightEdge" : "leftEdge"
                        to: followerTrack.movingRight ? followerTrack.stretchRight : followerTrack.stretchLeft
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                    // PHASE 2: Retract the trailing side while snapping both positions back to the true layout target
                    ParallelAnimation {
                        NumberAnimation {
                            target: followerTrack
                            property: "leftEdge"
                            to: followerTrack.targetLeft
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: followerTrack
                            property: "rightEdge"
                            to: followerTrack.targetRight
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Row {
                id: tabsRow
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 3
                anchors.bottomMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                z: 3

                Repeater {
                    id: tabsRepeater
                    model: root.workspaceProfiles

                    Item {
                        id: wsTabItem
                        property string tabId: modelData.id
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        implicitWidth: tabContent.implicitWidth + 14

                        readonly property bool isCurrent: root.activeWorkspace === modelData.id
                        readonly property bool isHovered: tabMouse.containsMouse

                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: (!wsTabItem.isCurrent && wsTabItem.isHovered) ? "#141414" : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }

                        Item {
                            id: tabContent
                            implicitWidth: tabRow.implicitWidth
                            implicitHeight: tabRow.implicitHeight
                            anchors.centerIn: parent

                            Row {
                                id: tabRow
                                spacing: 6

                                Image {
                                    id: tabIcon
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 14
                                    width: height
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: source.toString().length > 0

                                    property color iconColor: wsTabItem.isCurrent ? "#ffffff" : (wsTabItem.isHovered ? "#e0e0e0" : "#888888")

                                    Behavior on iconColor {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }

                                    layer.enabled: true
                                    layer.effect: ColorOverlay {
                                        color: tabIcon.iconColor
                                    }
                                }

                                Text {
                                    id: tabLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: wsTabItem.isCurrent ? "#ffffff" : (wsTabItem.isHovered ? "#e0e0e0" : "#888888")
                                    font.pixelSize: 11

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 1000

                            onClicked: mouse => {
                                mouse.accepted = true;
                                if (root.activeWorkspace === modelData.id)
                                    return;
                                var previous = root.activeWorkspace;
                                root.activeWorkspace = modelData.id;
                                root.workspaceChanged(modelData.id, previous);
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: menuItemComp
        XylaMenuItem {
            id: itemWrapper
            property var itemData: null
            property string actionIdentifier: itemData ? (itemData.id || "") : ""

            text: itemData ? (itemData.title || "") : ""
            descriptionText: itemData ? (itemData.description || "") : ""
            itemIcon: itemData ? (itemData.icon || "") : ""
            itemShortcut: itemData ? (itemData.shortcut || "") : ""
            itemIsSubmenu: false

            action: Action {
                text: itemWrapper.text
                shortcut: itemWrapper.itemShortcut
                icon.source: itemWrapper.itemIcon
                enabled: (itemWrapper.itemData && itemWrapper.itemData.enabled !== undefined) ? itemWrapper.itemData.enabled : true
                onTriggered: {
                    if (typeof menuManager !== "undefined")
                        menuManager.triggerAction(itemWrapper.actionIdentifier);
                }
            }
        }
    }

    Component {
        id: separatorComp
        XylaMenuSeparator {}
    }

    Component {
        id: submenuComp
        XylaMenu {
            id: nestedSubMenu
            property var subMenuData: null

            menuIcon: (subMenuData && subMenuData.icon) ? subMenuData.icon : ""
            menuDescription: (subMenuData && subMenuData.description) ? subMenuData.description : ""
            title: (subMenuData && subMenuData.title) ? subMenuData.title : ""
            enabled: (subMenuData && subMenuData.enabled !== undefined) ? subMenuData.enabled : true

            Instantiator {
                model: (nestedSubMenu.subMenuData && nestedSubMenu.subMenuData.items) ? nestedSubMenu.subMenuData.items : []

                delegate: QtObject {
                    id: subItemFactory
                    property var itemData: modelData
                    property var createdVisualItem: {
                        if (!itemData)
                            return null;
                        if (itemData.isSeparator) {
                            return separatorComp.createObject(nestedSubMenu);
                        } else if (itemData.isSubmenu) {
                            return submenuComp.createObject(nestedSubMenu, {
                                subMenuData: itemData
                            });
                        } else {
                            return menuItemComp.createObject(nestedSubMenu, {
                                itemData: itemData
                            });
                        }
                    }

                    Component.onDestruction: {
                        if (createdVisualItem) {
                            if (itemData && itemData.isSubmenu)
                                nestedSubMenu.removeMenu(createdVisualItem);
                            else
                                nestedSubMenu.removeItem(createdVisualItem);
                            createdVisualItem.destroy();
                        }
                    }
                }

                onObjectAdded: (index, object) => {
                    if (!object.createdVisualItem)
                        return;
                    if (object.itemData && object.itemData.isSubmenu)
                        nestedSubMenu.insertMenu(index, object.createdVisualItem);
                    else
                        nestedSubMenu.insertItem(index, object.createdVisualItem);
                }

                onObjectRemoved: (index, object) => {
                    if (!object.createdVisualItem)
                        return;
                    if (object.itemData && object.itemData.isSubmenu)
                        nestedSubMenu.removeMenu(object.createdVisualItem);
                    else
                        nestedSubMenu.removeItem(object.createdVisualItem);
                }
            }
        }
    }

    component XIcon: Item {
        id: xIcon
        width: 22
        height: 22

        // RESTORED PROPERTIES FROM PREV
        property color startColor: "#FFFFFF"
        property color endColor: "#FFFFFF"
        property bool initDelay: true

        function restartAnimation() {
            drawAnimation.restart();
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            property real progress: 0

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.scale(width / 24, height / 24);
                ctx.lineWidth = 2;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                // RESTORED STYLES FROM PREV: Linear Gradient Processing
                var gradient = ctx.createLinearGradient(0, 0, 24, 24);
                gradient.addColorStop(0, xIcon.startColor);
                gradient.addColorStop(1, xIcon.endColor);
                ctx.strokeStyle = gradient;

                var p = Math.min(progress * 1.5, 1.0);
                ctx.beginPath();
                if (p > 0) {
                    var d1 = 19.84, d2 = 4.267, d3 = 19.84, d4 = 4.267;
                    var total = d1 + d2 + d3 + d4;
                    var distance = p * total;
                    ctx.moveTo(4, 4);
                    if (distance <= d1) {
                        var t = distance / d1;
                        ctx.lineTo(4 + (15.733 - 4) * t, 4 + (20 - 4) * t);
                    } else {
                        ctx.lineTo(15.733, 20);
                        distance -= d1;
                        if (distance <= d2) {
                            var t2 = distance / d2;
                            ctx.lineTo(15.733 + (20 - 15.733) * t2, 20);
                        } else {
                            ctx.lineTo(20, 20);
                            distance -= d2;
                            if (distance <= d3) {
                                var t3 = distance / d3;
                                ctx.lineTo(20 + (8.267 - 20) * t3, 20 + (4 - 20) * t3);
                            } else {
                                ctx.lineTo(8.267, 4);
                                distance -= d3;
                                var t4 = Math.min(distance / d4, 1);
                                ctx.lineTo(8.267 + (4 - 8.267) * t4, 4);
                            }
                        }
                    }
                    ctx.stroke();
                }

                var p2 = Math.max(0, Math.min((progress - 0.5) * 2, 1));
                if (p2 > 0) {
                    ctx.beginPath();
                    var firstProgress = Math.min(p2 * 2, 1);
                    ctx.moveTo(4, 20);
                    ctx.lineTo(4 + (10.768 - 4) * firstProgress, 20 + (13.232 - 20) * firstProgress);

                    if (p2 > 0.5) {
                        var secondProgress = (p2 - 0.5) * 2;
                        ctx.moveTo(13.228, 10.772);
                        ctx.lineTo(13.228 + (20 - 13.228) * secondProgress, 10.772 + (4 - 10.772) * secondProgress);
                    }
                    ctx.stroke();
                }
            }

            onProgressChanged: requestPaint()
            Component.onCompleted: requestPaint()

            SequentialAnimation {
                id: drawAnimation
                running: false

                // RESTORED STYLES FROM PREV: Initial Animation Pause Action Rule
                PauseAnimation {
                    duration: xIcon.initDelay ? 1500 : 0
                }

                NumberAnimation {
                    target: canvas
                    property: "progress"
                    from: 0
                    to: 1
                    duration: 800
                    easing.type: Easing.Linear
                    onStarted: {
                        canvas.progress = 0;
                        canvas.requestPaint();
                        xIcon.initDelay = false;
                    }
                }

                onFinished: {
                    xIcon.initDelay = false;
                }
            }
        }

        Component.onCompleted: restartAnimation()
    }
}
