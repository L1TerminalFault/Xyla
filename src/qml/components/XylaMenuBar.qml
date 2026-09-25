import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root
    implicitHeight: 38
    implicitWidth: parent ? parent.width : 1280
    width: parent ? parent.width : 1280
    clip: true

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

    property bool isCompactMode: false

    Rectangle {
        anchors.fill: parent
        color: "#0E0E0E"
    }

    property var _barMenus: []
    property var _compactMenus: []

    readonly property var menuTreeNow: menuManager ? menuManager.menuTree : []

    onWidthChanged: root.recomputeCompact()
    
    onIsCompactModeChanged: {
        if (isCompactMode)
            syncMenuHost(compactMenuPopup, root.menuTreeNow, "_compactMenus")
        else if (compactMenuPopup && compactMenuPopup.visible)
            compactMenuPopup.close()
    }
    
    Component.onCompleted: Qt.callLater(root.syncAllMenus)

    Connections {
        target: menuManager
        function onMenuTreeChanged() { 
            if (root) Qt.callLater(root.syncAllMenus) 
        }
    }

    Connections {
        target: (typeof menuManager !== "undefined") ? menuManager : null
        function onMenuTreeChanged() { Qt.callLater(root.syncAllMenus) }
    }

    function entryKind(data) {
        if (!data)
            return "null"
        if (data.isSeparator)
            return "separator"
        if (data.isSubmenu)
            return "submenu"
        return "item"
    }

    function destroySafe(obj) {
        if (!obj)
            return
        try { obj.destroy() } catch (e) {}
    }

    function takeMenuItem(menu, index) {
        if (!menu)
            return null
        if (typeof menu.takeItem === "function")
            return menu.takeItem(index)
        var it = menu.itemAt(index)
        if (it) {
            try { menu.removeItem(it) } catch (e) {}
        }
        return it
    }

    function clearMenuItems(menu) {
        if (!menu)
            return
        var guard = 0
        while (menu.count > 0 && guard < 256) {
            ++guard
            destroySafe(takeMenuItem(menu, menu.count - 1))
        }
    }

    function clearHostMenus(host) {
        if (!host)
            return
        var guard = 0
        while (host.count > 0 && guard < 64) {
            ++guard
            var obj = null
            if (typeof host.takeMenu === "function")
                obj = host.takeMenu(host.count - 1)
            else if (typeof host.takeItem === "function")
                obj = host.takeItem(host.count - 1)
            else {
                var idx = host.count - 1
                obj = (typeof host.menuAt === "function") ? host.menuAt(idx) : null
                if (!obj && typeof host.itemAt === "function")
                    obj = host.itemAt(idx)
                if (obj) {
                    try {
                        if (typeof host.removeMenu === "function")
                            host.removeMenu(obj)
                        else if (typeof host.removeItem === "function")
                            host.removeItem(obj)
                    } catch (e) {}
                }
            }
            destroySafe(obj)
        }
    }

    function applyItemData(visual, data) {
        if (!visual || !data)
            return
        visual.itemData = data
    }

    function addMenuEntry(menu, data) {
        if (!menu || !data)
            return null
        
        var obj = null
        var kind = entryKind(data)
        
        var visualParent = menu.contentItem || menu

        if (kind === "separator") {
            obj = separatorComp.createObject(visualParent)
            if (!obj)
                return null
            menu.addItem(obj)
            return obj
        }
        
        if (kind === "submenu") {
            obj = submenuComp.createObject(visualParent, { subMenuData: data })
            if (!obj)
                return null
            syncMenuItems(obj, data.items || [])
            menu.addMenu(obj)
            return obj
        }
        
        obj = menuItemComp.createObject(visualParent, { itemData: data })
        if (!obj)
            return null
        menu.addItem(obj)
        return obj
    }

    function structureMatches(menu, items) {
        if (!menu || menu.count !== items.length)
            return false
        for (var i = 0; i < items.length; ++i) {
            var vis = menu.itemAt(i)
            if (!vis)
                return false
            var want = entryKind(items[i])
            var have = vis.xylaKind || ""
            if (have && have !== want)
                return false
            if (!have) {
                var looksSub = vis.subMenuData !== undefined || typeof vis.addMenu === "function"
                var looksSep = (vis.itemData === undefined && !looksSub)
                var got = looksSub ? "submenu" : (looksSep ? "separator" : "item")
                if (got !== want)
                    return false
            }
        }
        return true
    }

    function syncMenuItems(menu, items) {
        if (!menu)
            return
        items = items || []
        if (structureMatches(menu, items)) {
            for (var i = 0; i < items.length; ++i) {
                var vis = menu.itemAt(i)
                var data = items[i]
                if (!vis || !data || data.isSeparator)
                    continue
                if (data.isSubmenu) {
                    vis.subMenuData = data
                    syncMenuItems(vis, data.items || [])
                } else {
                    applyItemData(vis, data)
                }
            }
            return
        }
        clearMenuItems(menu)
        for (var j = 0; j < items.length; ++j)
            addMenuEntry(menu, items[j])
    }

    function titlesMatch(menus, tree) {
        if (!menus || menus.length !== tree.length)
            return false
        for (var i = 0; i < tree.length; ++i) {
            if (!menus[i])
                return false
            if ((menus[i].title || "") !== (tree[i].title || ""))
                return false
        }
        return true
    }

    function makeTopMenu(data) {
        var obj = topMenuComp.createObject(menuIncubator, { sourceData: data })
        if (!obj)
            return null
        syncMenuItems(obj, (data && data.items) || [])
        return obj
    }

    function refreshTopMenu(obj, data) {
        if (!obj || !data)
            return
        obj.sourceData = data
        syncMenuItems(obj, data.items || [])
    }

    function syncMenuHost(host, tree, cacheName) {
        if (!host)
            return
        tree = tree || []
        var cache = root[cacheName] || []

        if (titlesMatch(cache, tree) && host.count === cache.length) {
            for (var i = 0; i < tree.length; ++i)
                refreshTopMenu(cache[i], tree[i])
            return
        }

        clearHostMenus(host)
        var next = []
        for (var j = 0; j < tree.length; ++j) {
            var m = makeTopMenu(tree[j])
            if (!m)
                continue
            host.addMenu(m)
            next.push(m)
        }
        root[cacheName] = next
    }

    function syncAllMenus() {
        var tree = root.menuTreeNow || []
        syncMenuHost(standardMenuBar, tree, "_barMenus")
        if (root.isCompactMode)
            syncMenuHost(compactMenuPopup, tree, "_compactMenus")
        Qt.callLater(root.recomputeCompact)
    }

    function recomputeCompact() {
        if (!standardMenuBar)
            return
        var menuNeed = standardMenuBar.implicitWidth
        if (menuNeed <= 1 && standardMenuBar.contentItem)
            menuNeed = standardMenuBar.contentItem.childrenRect.width

        var chrome = brandRow.implicitWidth + tabsContainer.implicitWidth + 32
        var available = Math.max(0, root.width - chrome)

        var compact
        if (root.isCompactMode)
            compact = menuNeed > (available - 24)
        else
            compact = menuNeed > available && menuNeed > 0

        if (root.isCompactMode !== compact)
            root.isCompactMode = compact
    }

    Item {
        id: menuIncubator
        width: 0
        height: 0
        clip: true
        enabled: false
    }

    Component {
        id: topMenuComp
        XylaMenu {
            property var sourceData: null
            title: (sourceData && sourceData.title) || ""
            menuIcon: (sourceData && sourceData.icon) || ""
            menuDescription: (sourceData && sourceData.description) || ""
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        Row {
            id: brandRow
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: false
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

        XylaIconButton {
            id: compactMenuBtn
            visible: root.isCompactMode
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: false
            iconSource: "qrc:/assets/icons/menu.svg"
            ghost: true
            primary: compactMenuPopup.visible
            tooltip: "Application Menu"
            onClicked: {
                if (compactMenuPopup.visible)
                    compactMenuPopup.close()
                else
                    compactMenuPopup.open()
            }
            XylaMenu {
                id: compactMenuPopup
                y: compactMenuBtn.height + 6
            }
        }

        Item {
            id: menuBarWrapper
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: root.isCompactMode ? 0 : -1
            Layout.maximumWidth: root.isCompactMode ? 0 : 100000
            clip: true
            opacity: root.isCompactMode ? 0 : 1
            enabled: !root.isCompactMode

            MenuBar {
                id: standardMenuBar
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                background: Item {}
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                enabled: !root.isCompactMode
                onImplicitWidthChanged: root.recomputeCompact()
                onCountChanged: Qt.callLater(root.recomputeCompact)

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
            }
        }

        Item {
            Layout.fillWidth: root.isCompactMode
            Layout.minimumWidth: 0
            visible: root.isCompactMode
        }

        Item {
            id: tabsContainer
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.fillWidth: false
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
                property real stretchLeft: 4
                property real stretchRight: 54
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
                    if (movingRight) {
                        stretchRight = newRight
                        stretchLeft = newLeft
                    } else {
                        stretchLeft = newLeft
                        stretchRight = newRight
                    }
                    indicatorAnimation.restart()
                }
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
                    height: (parent.height - 3) + ((root.height - parent.height) / 2) + 1
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
                            ctx.arcTo(12, 12, 12, 0, 12)
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
                            ctx.arcTo(0, 12, 0, 0, 12)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                }
                SequentialAnimation {
                    id: indicatorAnimation
                    NumberAnimation {
                        target: followerTrack
                        property: followerTrack.movingRight ? "rightEdge" : "leftEdge"
                        to: followerTrack.movingRight ? followerTrack.stretchRight : followerTrack.stretchLeft
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
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
                                ColorAnimation { duration: 120 }
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
                                        ColorAnimation { duration: 150 }
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
                            onClicked: mouse => {
                                mouse.accepted = true
                                if (root.activeWorkspace === modelData.id)
                                    return
                                var previous = root.activeWorkspace
                                root.activeWorkspace = modelData.id
                                root.workspaceChanged(modelData.id, previous)
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
            text:            itemData ? (itemData.title || "") : ""
            descriptionText: itemData ? (itemData.description || "") : ""
            itemIcon:        itemData ? (itemData.icon || "") : ""
            itemShortcut:    itemData ? (itemData.shortcut || "") : ""
            itemIsSubmenu:   false
            action: Action {
                text:        itemWrapper.text
                shortcut:    itemWrapper.itemShortcut
                icon.source: itemWrapper.itemIcon
                enabled:     (itemWrapper.itemData && itemWrapper.itemData.enabled !== undefined)
                             ? itemWrapper.itemData.enabled : true
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
            property var subMenuData: null
            title:           (subMenuData && subMenuData.title)       ? subMenuData.title       : ""
            menuIcon:        (subMenuData && subMenuData.icon)        ? subMenuData.icon        : ""
            menuDescription: (subMenuData && subMenuData.description) ? subMenuData.description : ""
            enabled:         (subMenuData && subMenuData.enabled !== undefined)
                             ? subMenuData.enabled : true
        }
    }

    component XIcon: Item {
        id: xIcon
        width: 22
        height: 22
        property color startColor: "#FFFFFF"
        property color endColor: "#FFFFFF"
        property bool initDelay: true
        function restartAnimation() {
            drawAnimation.restart()
        }
        Canvas {
            id: canvas
            anchors.fill: parent
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
                var p = Math.min(progress * 1.5, 1.0)
                ctx.beginPath()
                if (p > 0) {
                    var d1 = 19.84, d2 = 4.267, d3 = 19.84, d4 = 4.267
                    var total = d1 + d2 + d3 + d4
                    var distance = p * total
                    ctx.moveTo(4, 4)
                    if (distance <= d1) {
                        var t = distance / d1
                        ctx.lineTo(4 + (15.733 - 4) * t, 4 + (20 - 4) * t)
                    } else {
                        ctx.lineTo(15.733, 20)
                        distance -= d1
                        if (distance <= d2) {
                            var t2 = distance / d2
                            ctx.lineTo(15.733 + (20 - 15.733) * t2, 20)
                        } else {
                            ctx.lineTo(20, 20)
                            distance -= d2
                            if (distance <= d3) {
                                var t3 = distance / d3
                                ctx.lineTo(20 + (8.267 - 20) * t3, 20 + (4 - 20) * t3)
                            } else {
                                ctx.lineTo(8.267, 4)
                                distance -= d3
                                var t4 = Math.min(distance / d4, 1)
                                ctx.lineTo(8.267 + (4 - 8.267) * t4, 4)
                            }
                        }
                    }
                    ctx.stroke()
                }
                var p2 = Math.max(0, Math.min((progress - 0.5) * 2, 1))
                if (p2 > 0) {
                    ctx.beginPath()
                    var firstProgress = Math.min(p2 * 2, 1)
                    ctx.moveTo(4, 20)
                    ctx.lineTo(4 + (10.768 - 4) * firstProgress, 20 + (13.232 - 20) * firstProgress)
                    if (p2 > 0.5) {
                        var secondProgress = (p2 - 0.5) * 2
                        ctx.moveTo(13.228, 10.772)
                        ctx.lineTo(13.228 + (20 - 13.228) * secondProgress, 10.772 + (4 - 10.772) * secondProgress)
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
                        canvas.progress = 0
                        canvas.requestPaint()
                        xIcon.initDelay = false
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
