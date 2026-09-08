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
        { id: "Edit",  name: "Editing", icon: "qrc:/assets/icons/edit.svg",     tooltip: "Timeline editing, clips organization, and tracks arrangement" },
        { id: "Cut",   name: "Cut",     icon: "qrc:/assets/icons/scissors.svg", tooltip: "Quick trimming, ripple edits, and fast assembly" },
        { id: "Color", name: "Color",   icon: "qrc:/assets/icons/palette.svg",  tooltip: "Color correction, grading, scopes, and look adjustments" },
        { id: "Audio", name: "Audio",   icon: "qrc:/assets/icons/audio.svg",    tooltip: "Audio mixing, track levels, effects, and sound cleanup" },
        { id: "View",  name: "View",    icon: "qrc:/assets/icons/maximize.svg", tooltip: "Full video preview playback" }
    ]

    signal workspaceChanged(string newWorkspace, string oldWorkspace)

    // Base background bar
    Rectangle {
        anchors.fill: parent
        color: "#0E0E0E"

        // Bottom 1px divider that separates menu bar from docking area
        // Rectangle {
        //     id: bottomBorder
        //     anchors.bottom: parent.bottom
        //     width: parent.width
        //     height: 1
        //     color: "#2d2d2d"
        //     z: 1
        // }
    }

    // Dynamic measurement: calculates if menu items fit between brand and tabs
    readonly property real availableMenuWidth: root.width - (brandRow.width + 24) - (tabsContainer.width + 24)
    readonly property bool isCompactMode: availableMenuWidth < standardMenuBar.implicitWidth

    // =========================================================================
    // MAIN HORIZONTAL CONTAINER ROW
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // ---------------------------------------------------------------------
        // 1. BRAND LOGO + COMPACT HAMBURGER ICON
        // ---------------------------------------------------------------------
        Row {
            id: brandRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            // Solid blue app icon badge with no text
            Rectangle {
                width: 22
                height: 22
                radius: 6
                color: "#000000" // "#202020"
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
                    onClicked: {
                        icon.restartAnimation();
                        // if (typeof menuManager !== "undefined")
                            // menuManager.triggerAction("app.about")
                    }
                }
            }

            // Compact hamburger icon visible only when space is constrained
            XylaIconButton {
                id: compactMenuBtn
                visible: root.isCompactMode
                iconSource: "qrc:/assets/icons/menu.svg"
                ghost: true
                primary: compactMenuPopup.visible
                tooltip: "Application Menu"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    if (compactMenuPopup.visible) {
                        compactMenuPopup.close()
                    } else {
                        compactMenuPopup.open()
                    }
                }

                XylaMenu {
                    id: compactMenuPopup
                    y: compactMenuBtn.height + 6

                    Instantiator {
                        model: typeof menuManager !== "undefined" ? menuManager.menuTree : []

                        delegate: Loader {
                            id: topMenuLoader
                            property var dataContext: modelData

                            sourceComponent: XylaMenu {
                                id: compactTopSubMenu
                                title: (topMenuLoader.dataContext && topMenuLoader.dataContext.title) ? topMenuLoader.dataContext.title : ""
                                menuIcon: "" // (topMenuLoader.dataContext && topMenuLoader.dataContext.icon) ? topMenuLoader.dataContext.icon : ""
                                menuDescription: (topMenuLoader.dataContext && topMenuLoader.dataContext.description) ? topMenuLoader.dataContext.description : ""

                                Instantiator {
                                    model: (topMenuLoader.dataContext && topMenuLoader.dataContext.items) ? topMenuLoader.dataContext.items : []

                                    delegate: Loader {
                                        id: subItemLoader
                                        property var itemContext: modelData

                                        sourceComponent: {
                                            if (!modelData) return null
                                            if (modelData.isSeparator) return separatorComp
                                            if (modelData.isSubmenu) return submenuComp
                                            return menuItemComp
                                        }

                                        onLoaded: {
                                            if (!item) return
                                            if ("itemData" in item) item.itemData = subItemLoader.itemContext
                                            if ("subMenuData" in item) item.subMenuData = subItemLoader.itemContext
                                        }
                                    }

                                    onObjectAdded: (idx, obj) => {
                                        function attachChild() {
                                            if (!obj.item) return
                                            if (obj.itemContext && obj.itemContext.isSubmenu)
                                                compactTopSubMenu.insertMenu(idx, obj.item)
                                            else
                                                compactTopSubMenu.insertItem(idx, obj.item)
                                        }
                                        if (obj.item) attachChild()
                                        else obj.loaded.connect(attachChild)
                                    }

                                    onObjectRemoved: (idx, obj) => {
                                        if (!obj.item) return
                                        if (obj.itemContext && obj.itemContext.isSubmenu)
                                            compactTopSubMenu.removeMenu(obj.item)
                                        else
                                            compactTopSubMenu.removeItem(obj.item)
                                    }
                                }
                            }

                            onLoaded: {
                                if (item) compactMenuPopup.insertMenu(index, item)
                            }
                        }

                        onObjectRemoved: (idx, obj) => {
                            if (obj.item) compactMenuPopup.removeMenu(obj.item)
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 2. STANDARD HORIZONTAL MENU BAR (File, Edit, View, etc.)
        // ---------------------------------------------------------------------
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
                background: Item {} // Transparent inside custom row

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
                            ColorAnimation { duration: 100; easing.type: Easing.OutCubic }
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

                            delegate: Loader {
                                id: level2Loader
                                property var dataContext: modelData

                                sourceComponent: {
                                    if (!modelData) return null
                                    if (modelData.isSeparator) return separatorComp
                                    if (modelData.isSubmenu) return submenuComp
                                    return menuItemComp
                                }

                                onLoaded: {
                                    if (!item) return
                                    if ("itemData" in item) item.itemData = level2Loader.dataContext
                                    if ("subMenuData" in item) item.subMenuData = level2Loader.dataContext
                                }
                            }

                            onObjectAdded: (index, object) => {
                                function insertChild() {
                                    var childItem = object.item
                                    if (!childItem) return
                                    if (object.dataContext && object.dataContext.isSubmenu)
                                        topMenu.insertMenu(index, childItem)
                                    else
                                        topMenu.insertItem(index, childItem)
                                }
                                if (object.item) insertChild()
                                else object.loaded.connect(insertChild)
                            }

                            onObjectRemoved: (index, object) => {
                                if (!object.item) return
                                if (object.dataContext && object.dataContext.isSubmenu)
                                    topMenu.removeMenu(object.item)
                                else
                                    topMenu.removeItem(object.item)
                            }
                        }
                    }

                    onObjectAdded: (index, object) => standardMenuBar.insertMenu(index, object)
                    onObjectRemoved: (index, object) => standardMenuBar.removeMenu(object)
                }
            }
        }

        // Spacer when in compact mode
        Item {
            Layout.fillWidth: true
            visible: root.isCompactMode
        }

        // ---------------------------------------------------------------------
        // 3. WORKSPACE TABS CONTAINER (Centered pill with bleeding follower)
        // ---------------------------------------------------------------------
        Item {
            id: tabsContainer
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitHeight: 30
            implicitWidth: tabsRow.implicitWidth + 10
            clip: false

            // Floating dark pill container base (fixed height, stays strictly centered)
            Rectangle {
                anchors.fill: parent
                color: "#050505"
                radius: 7
            }

            // --- HORIZONTAL SLIDING FOLLOWER INDICATOR ---
Item {
    id: followerTrack

    anchors.fill: parent
    clip: false
    z: 2

    readonly property Item currentTabItem: {
        for (var i = 0; i < tabsRepeater.count; ++i) {
            var itm = tabsRepeater.itemAt(i)
            if (itm && itm.tabId === root.activeWorkspace)
                return itm
        }
        return null
    }

    property real leftEdge: 4
    property real rightEdge: 54

    property real targetLeft: 4
    property real targetRight: 54

    property real previousLeft: 4
    property real previousRight: 54

    property bool movingRight: true

    function updateIndicator() {
        var item = currentTabItem

        if (!item)
            return

        var newLeft = tabsRow.x + item.x
        var newRight = newLeft + item.width

        previousLeft = leftEdge
        previousRight = rightEdge

        movingRight = newLeft > leftEdge

        targetLeft = newLeft
        targetRight = newRight

        var distance = Math.abs(newRight - rightEdge)

        if (movingRight) {
            stretchRight = newRight
            stretchLeft = newLeft
        } else {
            stretchLeft = newLeft
            stretchRight = newRight
        }
        // Stretch the leading edge well past its destination.
        // This makes the stretching side actually visible.
        // if (movingRight) {
        //     stretchRight = newRight + Math.max(18, Math.min(42, distance * 0.30))
        //     stretchLeft = newLeft
        // } else {
        //     stretchLeft = newLeft - Math.max(18, Math.min(42, distance * 0.30))
        //     stretchRight = newRight
        // }
        //
        indicatorAnimation.restart()
    }

    property real stretchLeft: 4
    property real stretchRight: 54

    Component.onCompleted: {
        var item = currentTabItem

        if (item) {
            leftEdge = tabsRow.x + item.x
            rightEdge = leftEdge + item.width

            targetLeft = leftEdge
            targetRight = rightEdge

            stretchLeft = leftEdge
            stretchRight = rightEdge
        }
    }

    Connections {
        target: root

        function onActiveWorkspaceChanged() {
            followerTrack.updateIndicator()
        }
    }

    Connections {
        target: tabsRepeater

        function onItemAdded() {
            Qt.callLater(followerTrack.updateIndicator)
        }
    }

    Rectangle {
        id: indicatorCapsule

        x: followerTrack.leftEdge
        width: Math.max(1, followerTrack.rightEdge - followerTrack.leftEdge)

        anchors.top: parent.top
        anchors.topMargin: 3

        height: (parent.height - 3)
                + ((root.height - parent.height) / 2)
                + 1

        color: "#191919"

        topLeftRadius: 6
        topRightRadius: 6
        bottomLeftRadius: 0
        bottomRightRadius: 0

        Canvas {
            id: leftCurve

            anchors.right: parent.left
            anchors.bottom: parent.bottom

            width: 12
            height: 12

            onPaint: {
                var ctx = getContext("2d")

                ctx.reset()
                ctx.fillStyle = "#191919"

                ctx.beginPath()

                ctx.moveTo(12, 0)
                ctx.lineTo(12, 12)
                ctx.lineTo(0, 12)

                ctx.arcTo(
                    12, 12,
                    12, 0,
                    12
                )

                ctx.closePath()
                ctx.fill()
            }
        }

        Canvas {
            id: rightCurve

            anchors.left: parent.right
            anchors.bottom: parent.bottom

            width: 12
            height: 12

            onPaint: {
                var ctx = getContext("2d")

                ctx.reset()
                ctx.fillStyle = "#191919"

                ctx.beginPath()

                ctx.moveTo(0, 0)
                ctx.lineTo(0, 12)
                ctx.lineTo(12, 12)

                ctx.arcTo(
                    0, 12,
                    0, 0,
                    12
                )

                ctx.closePath()
                ctx.fill()
            }
        }
    }

    SequentialAnimation {
        id: indicatorAnimation

        // ---------------------------------------------------------
        // PHASE 1:
        // Stretch the side in the direction we're moving.
        // ---------------------------------------------------------
        NumberAnimation {
            target: followerTrack

            property: followerTrack.movingRight
                     ? "rightEdge"
                     : "leftEdge"

            to: followerTrack.movingRight
                ? followerTrack.stretchRight
                : followerTrack.stretchLeft

            duration: 180

            easing.type: Easing.OutCubic
        }

        // ---------------------------------------------------------
        // PHASE 2:
        // Retract the stretched side while the opposite side
        // catches up to the real tab position.
        // ---------------------------------------------------------
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

            // Interactive Tabs Row (1px extra inward padding pushing children inner)
            Row {
                id: tabsRow
                // anchors.left: parent.left
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
                        // Width naturally dictated by content text without artificial min width
                        implicitWidth: tabContent.implicitWidth + 14 // 20

                        readonly property bool isCurrent: root.activeWorkspace === modelData.id
                        readonly property bool isHovered: tabMouse.containsMouse

                        // Hover feedback pill for unselected tabs
                        Rectangle {
                            anchors.fill: parent
                            radius: 6
                            color: (!wsTabItem.isCurrent && wsTabItem.isHovered) ? "#141414" : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }

                        XylaToolTip {
                            visible: false // tabMouse.containsMouse && modelData.name !== ""
                            delay: 1000
                            text: modelData.tooltip
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
                                        ColorAnimation { duration: 150 }
                                    }

                                    // Modern QML effect overlay directly on the Image
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
                                        ColorAnimation { duration: 150 }
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

                            onPressed: (mouse) => {
                                mouse.accepted = true
                            }
                            onClicked: (mouse) => {
                                mouse.accepted = true

                                if (root.activeWorkspace === modelData.id)
                                    return

                                var previousWorkspace = root.activeWorkspace
                                root.activeWorkspace = modelData.id
                                root.workspaceChanged(modelData.id, previousWorkspace)
                            }
                            onDoubleClicked: (mouse) => {
                                mouse.accepted = true
                            }
                            onReleased: (mouse) => {
                                mouse.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MENU ITEM COMPONENTS
    // -------------------------------------------------------------------------
    Component {
        id: menuItemComp
        XylaMenuItem {
            id: itemWrapper
            property var itemData: null
            property string actionIdentifier: itemData ? (itemData.id || "") : ""

            descriptionText: (itemData && itemData.description) ? itemData.description : ""
            itemIcon: (itemData && itemData.icon) ? itemData.icon : ""
            itemShortcut: (itemData && itemData.shortcut) ? itemData.shortcut : ""
            itemIsSubmenu: false

            action: Action {
                text: (itemWrapper.itemData && itemWrapper.itemData.title) ? itemWrapper.itemData.title : ""
                shortcut: (itemWrapper.itemData && itemWrapper.itemData.shortcut) ? itemWrapper.itemData.shortcut : ""
                icon.source: (itemWrapper.itemData && itemWrapper.itemData.icon) ? itemWrapper.itemData.icon : ""
                enabled: (itemWrapper.itemData && itemWrapper.itemData.enabled !== undefined) ? itemWrapper.itemData.enabled : true
                onTriggered: {
                    if (typeof menuManager !== "undefined")
                        menuManager.triggerAction(itemWrapper.actionIdentifier)
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
            icon.source: menuIcon
            enabled: (subMenuData && subMenuData.enabled !== undefined) ? subMenuData.enabled : true
            title: (subMenuData && subMenuData.title) ? subMenuData.title : ""

            Instantiator {
                model: (nestedSubMenu.subMenuData && nestedSubMenu.subMenuData.items) ? nestedSubMenu.subMenuData.items : []

                delegate: Loader {
                    id: level3Loader
                    property var dataContext: modelData

                    sourceComponent: {
                        if (!modelData) return null
                        if (modelData.isSeparator) return separatorComp
                        if (modelData.isSubmenu) return submenuComp
                        return menuItemComp
                    }

                    onLoaded: {
                        if (!item) return
                        if ("itemData" in item) item.itemData = level3Loader.dataContext
                        if ("subMenuData" in item) item.subMenuData = level3Loader.dataContext
                    }
                }

                onObjectAdded: (index, object) => {
                    function insertChild() {
                        var childItem = object.item
                        if (!childItem) return
                        if (object.dataContext && object.dataContext.isSubmenu)
                            nestedSubMenu.insertMenu(index, childItem)
                        else
                            nestedSubMenu.insertItem(index, childItem)
                    }
                    if (object.item) insertChild()
                    else object.loaded.connect(insertChild)
                }

                onObjectRemoved: (index, object) => {
                    if (!object.item) return
                    if (object.dataContext && object.dataContext.isSubmenu)
                        nestedSubMenu.removeMenu(object.item)
                    else
                        nestedSubMenu.removeItem(object.item)
                }
            }
        }
    }

component XIcon: Item {
    id: xIcon

    // anchors.fill: parent
    width: 22
    height: 22

    property color startColor: "#FFFFFF"
    property color endColor: "#FFFFFF"

    property bool initDelay: true

    function restartAnimation() {
        drawAnimation.restart();
    }

    Canvas {
        id: canvas

        // anchors.centerIn: parent
        anchors.fill: parent
        // width: 24
        // height: 24

        property real progress: 0

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            ctx.scale(width / 24, height / 24)

            ctx.lineWidth = 2
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            var gradient = ctx.createLinearGradient(0, 0, 24, 24)
            gradient.addColorStop(0, xIcon.startColor)
            gradient.addColorStop(1, xIcon.endColor)

            ctx.strokeStyle = gradient

            // -------------------------------------------------
            // Exact SVG path:
            // M4 4
            // L15.733 20
            // L20 20
            // L8.267 4
            // L4 4
            // -------------------------------------------------

            var p = Math.min(progress * 1.5, 1.0)

            ctx.beginPath()

            if (p > 0) {
                var d1 = 19.84
                var d2 = 4.267
                var d3 = 19.84
                var d4 = 4.267
                var total = d1 + d2 + d3 + d4
                var distance = p * total

                ctx.moveTo(4, 4)

                if (distance <= d1) {
                    var t = distance / d1

                    ctx.lineTo(
                        4 + (15.733 - 4) * t,
                        4 + (20 - 4) * t
                    )
                } else {
                    ctx.lineTo(15.733, 20)
                    distance -= d1

                    if (distance <= d2) {
                        var t2 = distance / d2

                        ctx.lineTo(
                            15.733 + (20 - 15.733) * t2,
                            20
                        )
                    } else {
                        ctx.lineTo(20, 20)
                        distance -= d2

                        if (distance <= d3) {
                            var t3 = distance / d3

                            ctx.lineTo(
                                20 + (8.267 - 20) * t3,
                                20 + (4 - 20) * t3
                            )
                        } else {
                            ctx.lineTo(8.267, 4)
                            distance -= d3

                            var t4 = Math.min(distance / d4, 1)

                            ctx.lineTo(
                                8.267 + (4 - 8.267) * t4,
                                4
                            )
                        }
                    }
                }

                ctx.stroke()
            }

            // -------------------------------------------------
            // Exact SVG second path:
            // M4 20
            // L10.768 13.232
            // M13.228 10.772
            // L20 4
            // -------------------------------------------------

            var p2 = Math.max(0, Math.min((progress - 0.5) * 2, 1))

            if (p2 > 0) {
                ctx.beginPath()

                // M4 20 L10.768 13.232
                var firstLength = Math.sqrt(
                    Math.pow(10.768 - 4, 2) +
                    Math.pow(13.232 - 20, 2)
                )

                var firstProgress = Math.min(p2 * 2, 1)

                ctx.moveTo(4, 20)

                ctx.lineTo(
                    4 + (10.768 - 4) * firstProgress,
                    20 + (13.232 - 20) * firstProgress
                )

                // M13.228 10.772 L20 4
                if (p2 > 0.5) {
                    var secondProgress = (p2 - 0.5) * 2

                    ctx.moveTo(13.228, 10.772)

                    ctx.lineTo(
                        13.228 + (20 - 13.228) * secondProgress,
                        10.772 + (4 - 10.772) * secondProgress
                    )
                }

                ctx.stroke()
            }
        }

        onProgressChanged: requestPaint()

        Component.onCompleted: requestPaint()

        SequentialAnimation {
            id: drawAnimation
            running: false

            PauseAnimation {
                duration: xIcon.initDelay ? 1500 : 0  // delay in milliseconds
            }

            NumberAnimation {
                target: canvas
                property: "progress"
                from: 0
                to: 1
                duration: 800
                easing.type: Easing.Linear

                onStarted: {
                    canvas.progress = 0
                    canvas.requestPaint()
                    initDelay = false;
                }
            }

            onFinished: {
                xIcon.initDelay = false
            }
        }
    }

    Component.onCompleted: restartAnimation()
}
}
