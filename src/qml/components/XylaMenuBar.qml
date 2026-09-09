// import QtQuick
// import QtQuick.Controls
// import QtQuick.Layouts
// import Qt5Compat.GraphicalEffects
//
// Item {
//     id: root
//     implicitHeight: 38
//     width: parent ? parent.width : 1280
//
//     property string activeWorkspace: "Edit"
//     readonly property var workspaceProfiles: [
//         {
//             id: "Edit",
//             name: "Editing",
//             icon: "qrc:/assets/icons/edit.svg",
//             tooltip: "Timeline editing, clips organization, and tracks arrangement"
//         },
//         {
//             id: "Cut",
//             name: "Cut",
//             icon: "qrc:/assets/icons/scissors.svg",
//             tooltip: "Quick trimming, ripple edits, and fast assembly"
//         },
//         {
//             id: "Color",
//             name: "Color",
//             icon: "qrc:/assets/icons/palette.svg",
//             tooltip: "Color correction, grading, scopes, and look adjustments"
//         },
//         {
//             id: "Audio",
//             name: "Audio",
//             icon: "qrc:/assets/icons/audio.svg",
//             tooltip: "Audio mixing, track levels, effects, and sound cleanup"
//         },
//         {
//             id: "View",
//             name: "View",
//             icon: "qrc:/assets/icons/maximize.svg",
//             tooltip: "Full video preview playback"
//         }
//     ]
//
//     signal workspaceChanged(string newWorkspace, string oldWorkspace)
//
//     Rectangle {
//         anchors.fill: parent
//         color: "#0E0E0E"
//     }
//
//     readonly property real availableMenuWidth: root.width - (brandRow.width + 24) - (tabsContainer.width + 24)
//     readonly property bool isCompactMode: availableMenuWidth < standardMenuBar.implicitWidth
//
//     RowLayout {
//         anchors.fill: parent
//         anchors.leftMargin: 8
//         anchors.rightMargin: 8
//         spacing: 8
//
//         Row {
//             id: brandRow
//             Layout.alignment: Qt.AlignVCenter
//             spacing: 6
//
//             Rectangle {
//                 width: 22
//                 height: 22
//                 radius: 6
//                 color: "#000000"
//                 anchors.verticalCenter: parent.verticalCenter
//
//                 XIcon {
//                     id: icon
//                     anchors.centerIn: parent
//                     width: 14
//                     height: 14
//                 }
//
//                 MouseArea {
//                     anchors.fill: parent
//                     cursorShape: Qt.PointingHandCursor
//                     onClicked: icon.restartAnimation()
//                 }
//             }
//         }
//
//             // SAFE RESTORED FEATURE: Compact hamburger icon layer
//             XylaIconButton {
//                 id: compactMenuBtn
//                 visible: root.isCompactMode
//                 iconSource: "qrc:/assets/icons/menu.svg"
//                 ghost: true
//                 primary: compactMenuPopup.visible
//                 tooltip: "Application Menu"
//                 anchors.verticalCenter: parent.verticalCenter
//                 onClicked: {
//                     if (compactMenuPopup.visible) compactMenuPopup.close()
//                     else compactMenuPopup.open()
//                 }
//
//                 XylaMenu {
//                     id: compactMenuPopup
//                     y: compactMenuBtn.height + 6
//
//                     Instantiator {
//                         model: typeof menuManager !== "undefined" ? menuManager.menuTree : []
//                         delegate: XylaMenu {
//                             id: compactTopSubMenu
//                             title: modelData.title || ""
//                             menuIcon: ""
//                             menuDescription: modelData.description || ""
//
//                             Instantiator {
//                                 model: modelData.items || []
//                                 delegate: QtObject {
//                                     id: compactSubItemFactory
//                                     property var itemData: modelData
//                                     property var createdVisualItem: {
//                                         if (!itemData) return null;
//                                         if (itemData.isSeparator) return separatorComp.createObject(compactTopSubMenu);
//                                         if (itemData.isSubmenu) return submenuComp.createObject(compactTopSubMenu, { subMenuData: itemData });
//                                         return menuItemComp.createObject(compactTopSubMenu, { itemData: itemData });
//                                     }
//                                     Component.onDestruction: {
//                                         if (createdVisualItem) {
//                                             if (itemData && itemData.isSubmenu) compactTopSubMenu.removeMenu(createdVisualItem);
//                                             else compactTopSubMenu.removeItem(createdVisualItem);
//                                             createdVisualItem.destroy();
//                                         }
//                                     }
//                                 }
//                                 onObjectAdded: (idx, obj) => {
//                                     if (!obj.createdVisualItem) return;
//                                     if (obj.itemData && obj.itemData.isSubmenu) compactTopSubMenu.insertMenu(idx, obj.createdVisualItem);
//                                     else compactTopSubMenu.insertItem(idx, obj.createdVisualItem);
//                                 }
//                                 onObjectRemoved: (idx, obj) => {
//                                     if (!obj.createdVisualItem) return;
//                                     if (obj.itemData && obj.itemData.isSubmenu) compactTopSubMenu.removeMenu(obj.createdVisualItem);
//                                     else compactTopSubMenu.removeItem(obj.createdVisualItem);
//                                 }
//                             }
//                         }
//                         onObjectAdded: (index, object) => compactMenuPopup.insertMenu(index, object)
//                         onObjectRemoved: (index, object) => compactMenuPopup.removeMenu(object)
//                     }
//                 }
//             }
//
//         Item {
//             id: menuBarWrapper
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//             visible: !root.isCompactMode
//             clip: true
//
//             MenuBar {
//                 id: standardMenuBar
//                 anchors.left: parent.left
//                 anchors.verticalCenter: parent.verticalCenter
//                 background: Item {}
//
//                 leftPadding: 0
//                 rightPadding: 0
//                 topPadding: 0
//                 bottomPadding: 0
//
//                 delegate: MenuBarItem {
//                     id: menuBarItem
//                     implicitHeight: 28
//
//                     contentItem: Row {
//                         spacing: 5
//                         anchors.centerIn: parent
//                         leftPadding: 6
//                         rightPadding: 6
//
//                         Image {
//                             anchors.verticalCenter: parent.verticalCenter
//                             width: 14
//                             height: 14
//                             fillMode: Image.PreserveAspectFit
//                             source: (menuBarItem.menu && menuBarItem.menu.menuIcon) ? menuBarItem.menu.menuIcon : ""
//                             visible: source !== "" && status === Image.Ready
//                         }
//
//                         Text {
//                             anchors.verticalCenter: parent.verticalCenter
//                             text: menuBarItem.text
//                             color: menuBarItem.enabled ? (menuBarItem.highlighted ? "#ffffff" : "#cccccc") : "#555555"
//                             font.pixelSize: 12
//                             font.weight: Font.Normal
//                         }
//                     }
//
//                     background: Rectangle {
//                         anchors.fill: parent
//                         radius: 5
//                         color: menuBarItem.highlighted ? "#262626" : "transparent"
//
//                         Behavior on color {
//                             ColorAnimation {
//                                 duration: 100
//                                 easing.type: Easing.OutCubic
//                             }
//                         }
//                     }
//                 }
//
// Instantiator {
//     model: typeof menuManager !== "undefined" ? menuManager.menuTree : []
//
//     delegate: XylaMenu {
//         id: topMenu
//         title:           modelData.title || ""
//         menuIcon:        (modelData && modelData.icon)        ? modelData.icon        : ""
//         menuDescription: (modelData && modelData.description) ? modelData.description : ""
//
//         Instantiator {
//             model: modelData.items || []
//
//             delegate: QtObject {
//                 property var itemData: modelData
//                 property var visual: null
//
//                 Component.onCompleted: {
//                     if (!itemData) return
//                     if (itemData.isSeparator)
//                         visual = separatorComp.createObject(null)
//                     else if (itemData.isSubmenu)
//                         visual = submenuComp.createObject(null, { subMenuData: itemData })
//                     else
//                         visual = menuItemComp.createObject(null, { itemData: itemData })
//                 }
//
//                 Component.onDestruction: {
//                     if (visual) {
//                         if (itemData && itemData.isSubmenu)
//                             topMenu.removeMenu(visual)
//                         else
//                             topMenu.removeItem(visual)
//                         visual.destroy()
//                     }
//                 }
//             }
//
//             onObjectAdded: (idx, obj) => {
//                 if (!obj.visual) return
//                 if (obj.itemData && obj.itemData.isSubmenu)
//                     topMenu.insertMenu(idx, obj.visual)
//                 else
//                     topMenu.insertItem(idx, obj.visual)
//             }
//         }
//     }
//
//     onObjectAdded:   (index, object) => standardMenuBar.insertMenu(index, object)
//     onObjectRemoved: (index, object) => standardMenuBar.removeMenu(object)
// }
//             }
//         }
//
//         Item {
//             Layout.fillWidth: true
//             visible: root.isCompactMode
//         }
//
//         Item {
//             id: tabsContainer
//             Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
//             implicitHeight: 30
//             implicitWidth: tabsRow.implicitWidth + 10
//             clip: false
//
//             Rectangle {
//                 anchors.fill: parent
//                 color: "#050505"
//                 radius: 7
//             }
//
//             Item {
//                 id: followerTrack
//                 anchors.fill: parent
//                 clip: false
//                 z: 2
//
//                 readonly property Item currentTabItem: {
//                     for (var i = 0; i < tabsRepeater.count; ++i) {
//                         var itm = tabsRepeater.itemAt(i);
//                         if (itm && itm.tabId === root.activeWorkspace)
//                             return itm;
//                     }
//                     return null;
//                 }
//
//                 property real leftEdge: 4
//                 property real rightEdge: 54
//                 property real targetLeft: 4
//                 property real targetRight: 54
//                 property real previousLeft: 4
//                 property real previousRight: 54
//                 property bool movingRight: true
//
//                 // RESTORED FEATURES FROM PREV: Custom stretch coordinates
//                 property real stretchLeft: 4
//                 property real stretchRight: 54
//
//                 function updateIndicator() {
//                     var item = currentTabItem;
//                     if (!item)
//                         return;
//
//                     var newLeft = tabsRow.x + item.x;
//                     var newRight = newLeft + item.width;
//
//                     previousLeft = leftEdge;
//                     previousRight = rightEdge;
//                     movingRight = newLeft > leftEdge;
//                     targetLeft = newLeft;
//                     targetRight = newRight;
//
//                     // RESTORED FEATURES FROM PREV: Stretch phase destination calculation
//                     if (movingRight) {
//                         stretchRight = newRight;
//                         stretchLeft = newLeft;
//                     } else {
//                         stretchLeft = newLeft;
//                         stretchRight = newRight;
//                     }
//
//                     indicatorAnimation.restart();
//                 }
//
//                 Component.onCompleted: {
//                     var item = currentTabItem;
//                     if (item) {
//                         leftEdge = tabsRow.x + item.x;
//                         rightEdge = leftEdge + item.width;
//                         targetLeft = leftEdge;
//                         targetRight = rightEdge;
//
//                         // RESTORED FEATURES FROM PREV: Complete initialization paths
//                         stretchLeft = leftEdge;
//                         stretchRight = rightEdge;
//                     }
//                 }
//
//                 Connections {
//                     target: root
//                     function onActiveWorkspaceChanged() {
//                         followerTrack.updateIndicator();
//                     }
//                 }
//
//                 Connections {
//                     target: tabsRepeater
//                     function onItemAdded() {
//                         Qt.callLater(followerTrack.updateIndicator);
//                     }
//                 }
//
//                 Rectangle {
//                     id: indicatorCapsule
//                     x: followerTrack.leftEdge
//                     width: Math.max(1, followerTrack.rightEdge - followerTrack.leftEdge)
//                     anchors.top: parent.top
//                     anchors.topMargin: 3
//                     height: (parent.height - 3) + ((root.height - parent.height) / 2) + 1
//                     color: "#191919"
//                     topLeftRadius: 6
//                     topRightRadius: 6
//
//                     // RESTORED STYLES FROM PREV: Flat base configuration
//                     bottomLeftRadius: 0
//                     bottomRightRadius: 0
//
//                     // RESTORED STYLES FROM PREV: Left Bleeding Corner Curve
//                     Canvas {
//                         id: leftCurve
//                         anchors.right: parent.left
//                         anchors.bottom: parent.bottom
//                         width: 12
//                         height: 12
//                         onPaint: {
//                             var ctx = getContext("2d");
//                             ctx.reset();
//                             ctx.fillStyle = "#191919";
//                             ctx.beginPath();
//                             ctx.moveTo(12, 0);
//                             ctx.lineTo(12, 12);
//                             ctx.lineTo(0, 12);
//                             ctx.arcTo(12, 12, 12, 0, 12);
//                             ctx.closePath();
//                             ctx.fill();
//                         }
//                     }
//
//                     // RESTORED STYLES FROM PREV: Right Bleeding Corner Curve
//                     Canvas {
//                         id: rightCurve
//                         anchors.left: parent.right
//                         anchors.bottom: parent.bottom
//                         width: 12
//                         height: 12
//                         onPaint: {
//                             var ctx = getContext("2d");
//                             ctx.reset();
//                             ctx.fillStyle = "#191919";
//                             ctx.beginPath();
//                             ctx.moveTo(0, 0);
//                             ctx.lineTo(0, 12);
//                             ctx.lineTo(12, 12);
//                             ctx.arcTo(0, 12, 0, 0, 12);
//                             ctx.closePath();
//                             ctx.fill();
//                         }
//                     }
//                 }
//
//                 SequentialAnimation {
//                     id: indicatorAnimation
//
//                     // PHASE 1: Stretch only the leading edge side we are moving towards
//                     NumberAnimation {
//                         target: followerTrack
//                         property: followerTrack.movingRight ? "rightEdge" : "leftEdge"
//                         to: followerTrack.movingRight ? followerTrack.stretchRight : followerTrack.stretchLeft
//                         duration: 180
//                         easing.type: Easing.OutCubic
//                     }
//
//                     // PHASE 2: Retract the trailing side while snapping both positions back to the true layout target
//                     ParallelAnimation {
//                         NumberAnimation {
//                             target: followerTrack
//                             property: "leftEdge"
//                             to: followerTrack.targetLeft
//                             duration: 220
//                             easing.type: Easing.OutCubic
//                         }
//                         NumberAnimation {
//                             target: followerTrack
//                             property: "rightEdge"
//                             to: followerTrack.targetRight
//                             duration: 220
//                             easing.type: Easing.OutCubic
//                         }
//                     }
//                 }
//             }
//
//             Row {
//                 id: tabsRow
//                 anchors.leftMargin: 8
//                 anchors.rightMargin: 8
//                 anchors.top: parent.top
//                 anchors.bottom: parent.bottom
//                 anchors.topMargin: 3
//                 anchors.bottomMargin: 3
//                 anchors.horizontalCenter: parent.horizontalCenter
//                 spacing: 6
//                 z: 3
//
//                 Repeater {
//                     id: tabsRepeater
//                     model: root.workspaceProfiles
//
//                     Item {
//                         id: wsTabItem
//                         property string tabId: modelData.id
//                         anchors.top: parent.top
//                         anchors.bottom: parent.bottom
//                         implicitWidth: tabContent.implicitWidth + 14
//
//                         readonly property bool isCurrent: root.activeWorkspace === modelData.id
//                         readonly property bool isHovered: tabMouse.containsMouse
//
//                         Rectangle {
//                             anchors.fill: parent
//                             radius: 6
//                             color: (!wsTabItem.isCurrent && wsTabItem.isHovered) ? "#141414" : "transparent"
//
//                             Behavior on color {
//                                 ColorAnimation {
//                                     duration: 120
//                                 }
//                             }
//                         }
//
//                         Item {
//                             id: tabContent
//                             implicitWidth: tabRow.implicitWidth
//                             implicitHeight: tabRow.implicitHeight
//                             anchors.centerIn: parent
//
//                             Row {
//                                 id: tabRow
//                                 spacing: 6
//
//                                 Image {
//                                     id: tabIcon
//                                     anchors.verticalCenter: parent.verticalCenter
//                                     height: 14
//                                     width: height
//                                     source: modelData.icon || ""
//                                     fillMode: Image.PreserveAspectFit
//                                     visible: source.toString().length > 0
//
//                                     property color iconColor: wsTabItem.isCurrent ? "#ffffff" : (wsTabItem.isHovered ? "#e0e0e0" : "#888888")
//
//                                     Behavior on iconColor {
//                                         ColorAnimation {
//                                             duration: 150
//                                         }
//                                     }
//
//                                     layer.enabled: true
//                                     layer.effect: ColorOverlay {
//                                         color: tabIcon.iconColor
//                                     }
//                                 }
//
//                                 Text {
//                                     id: tabLabel
//                                     anchors.verticalCenter: parent.verticalCenter
//                                     text: modelData.name
//                                     color: wsTabItem.isCurrent ? "#ffffff" : (wsTabItem.isHovered ? "#e0e0e0" : "#888888")
//                                     font.pixelSize: 11
//
//                                     Behavior on color {
//                                         ColorAnimation {
//                                             duration: 150
//                                         }
//                                     }
//                                 }
//                             }
//                         }
//
//                         MouseArea {
//                             id: tabMouse
//                             anchors.fill: parent
//                             hoverEnabled: true
//                             cursorShape: Qt.PointingHandCursor
//                             z: 1000
//
//                             onClicked: mouse => {
//                                 mouse.accepted = true;
//                                 if (root.activeWorkspace === modelData.id)
//                                     return;
//                                 var previous = root.activeWorkspace;
//                                 root.activeWorkspace = modelData.id;
//                                 root.workspaceChanged(modelData.id, previous);
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//     }
//
// // ─── Shared components (keep these) ───────────────────────────────────────
// Component {
//     id: menuItemComp
//     XylaMenuItem {
//         id: itemWrapper
//         property var itemData: null
//         property string actionIdentifier: itemData ? (itemData.id || "") : ""
//
//         text:            itemData ? (itemData.title || "") : ""
//         descriptionText: itemData ? (itemData.description || "") : ""
//         itemIcon:        itemData ? (itemData.icon || "") : ""
//         itemShortcut:    itemData ? (itemData.shortcut || "") : ""
//         itemIsSubmenu:   false
//
//         action: Action {
//             text:     itemWrapper.text
//             shortcut: itemWrapper.itemShortcut
//             icon.source: itemWrapper.itemIcon
//             enabled:  (itemWrapper.itemData && itemWrapper.itemData.enabled !== undefined)
//                       ? itemWrapper.itemData.enabled : true
//             onTriggered: {
//                 if (typeof menuManager !== "undefined")
//                     menuManager.triggerAction(itemWrapper.actionIdentifier)
//             }
//         }
//     }
// }
//
// Component {
//     id: separatorComp
//     XylaMenuSeparator {}
// }
//
// // ─── Recursive submenu component ──────────────────────────────────────────
// Component {
//     id: submenuComp
//     XylaMenu {
//         id: nestedSubMenu
//         property var subMenuData: null
//
//         title:           (subMenuData && subMenuData.title)       ? subMenuData.title       : ""
//         menuIcon:        (subMenuData && subMenuData.icon)        ? subMenuData.icon        : ""
//         menuDescription: (subMenuData && subMenuData.description) ? subMenuData.description : ""
//         enabled:         (subMenuData && subMenuData.enabled !== undefined)
//                          ? subMenuData.enabled : true
//
//         Instantiator {
//             model: (nestedSubMenu.subMenuData && nestedSubMenu.subMenuData.items)
//                    ? nestedSubMenu.subMenuData.items : []
//
//             // Pure data object – never put visual items here
//             delegate: QtObject {
//                 id: factory
//                 property var itemData: modelData
//                 property var visual: null          // the real MenuItem / Menu / Separator
//
//                 Component.onCompleted: {
//                     if (!itemData) return
//
//                     if (itemData.isSeparator) {
//                         visual = separatorComp.createObject(null)
//                     } else if (itemData.isSubmenu) {
//                         visual = submenuComp.createObject(null, { subMenuData: itemData })
//                     } else {
//                         visual = menuItemComp.createObject(null, { itemData: itemData })
//                     }
//                 }
//
//                 Component.onDestruction: {
//                     if (visual) {
//                         // Remove from parent Menu first (safe even if already gone)
//                         if (itemData && itemData.isSubmenu)
//                             nestedSubMenu.removeMenu(visual)
//                         else
//                             nestedSubMenu.removeItem(visual)
//                         visual.destroy()
//                         visual = null
//                     }
//                 }
//             }
//
//             onObjectAdded: (index, obj) => {
//                 if (!obj.visual) return
//                 if (obj.itemData && obj.itemData.isSubmenu)
//                     nestedSubMenu.insertMenu(index, obj.visual)
//                 else
//                     nestedSubMenu.insertItem(index, obj.visual)
//             }
//
//             onObjectRemoved: (index, obj) => {
//                 // destruction handler already cleans up
//             }
//         }
//     }
// }
//
//     component XIcon: Item {
//         id: xIcon
//         width: 22
//         height: 22
//
//         // RESTORED PROPERTIES FROM PREV
//         property color startColor: "#FFFFFF"
//         property color endColor: "#FFFFFF"
//         property bool initDelay: true
//
//         function restartAnimation() {
//             drawAnimation.restart();
//         }
//
//         Canvas {
//             id: canvas
//             anchors.fill: parent
//             property real progress: 0
//
//             onPaint: {
//                 var ctx = getContext("2d");
//                 ctx.reset();
//                 ctx.scale(width / 24, height / 24);
//                 ctx.lineWidth = 2;
//                 ctx.lineCap = "round";
//                 ctx.lineJoin = "round";
//
//                 // RESTORED STYLES FROM PREV: Linear Gradient Processing
//                 var gradient = ctx.createLinearGradient(0, 0, 24, 24);
//                 gradient.addColorStop(0, xIcon.startColor);
//                 gradient.addColorStop(1, xIcon.endColor);
//                 ctx.strokeStyle = gradient;
//
//                 var p = Math.min(progress * 1.5, 1.0);
//                 ctx.beginPath();
//                 if (p > 0) {
//                     var d1 = 19.84, d2 = 4.267, d3 = 19.84, d4 = 4.267;
//                     var total = d1 + d2 + d3 + d4;
//                     var distance = p * total;
//                     ctx.moveTo(4, 4);
//                     if (distance <= d1) {
//                         var t = distance / d1;
//                         ctx.lineTo(4 + (15.733 - 4) * t, 4 + (20 - 4) * t);
//                     } else {
//                         ctx.lineTo(15.733, 20);
//                         distance -= d1;
//                         if (distance <= d2) {
//                             var t2 = distance / d2;
//                             ctx.lineTo(15.733 + (20 - 15.733) * t2, 20);
//                         } else {
//                             ctx.lineTo(20, 20);
//                             distance -= d2;
//                             if (distance <= d3) {
//                                 var t3 = distance / d3;
//                                 ctx.lineTo(20 + (8.267 - 20) * t3, 20 + (4 - 20) * t3);
//                             } else {
//                                 ctx.lineTo(8.267, 4);
//                                 distance -= d3;
//                                 var t4 = Math.min(distance / d4, 1);
//                                 ctx.lineTo(8.267 + (4 - 8.267) * t4, 4);
//                             }
//                         }
//                     }
//                     ctx.stroke();
//                 }
//
//                 var p2 = Math.max(0, Math.min((progress - 0.5) * 2, 1));
//                 if (p2 > 0) {
//                     ctx.beginPath();
//                     var firstProgress = Math.min(p2 * 2, 1);
//                     ctx.moveTo(4, 20);
//                     ctx.lineTo(4 + (10.768 - 4) * firstProgress, 20 + (13.232 - 20) * firstProgress);
//
//                     if (p2 > 0.5) {
//                         var secondProgress = (p2 - 0.5) * 2;
//                         ctx.moveTo(13.228, 10.772);
//                         ctx.lineTo(13.228 + (20 - 13.228) * secondProgress, 10.772 + (4 - 10.772) * secondProgress);
//                     }
//                     ctx.stroke();
//                 }
//             }
//
//             onProgressChanged: requestPaint()
//             Component.onCompleted: requestPaint()
//
//             SequentialAnimation {
//                 id: drawAnimation
//                 running: false
//
//                 // RESTORED STYLES FROM PREV: Initial Animation Pause Action Rule
//                 PauseAnimation {
//                     duration: xIcon.initDelay ? 1500 : 0
//                 }
//
//                 NumberAnimation {
//                     target: canvas
//                     property: "progress"
//                     from: 0
//                     to: 1
//                     duration: 800
//                     easing.type: Easing.Linear
//                     onStarted: {
//                         canvas.progress = 0;
//                         canvas.requestPaint();
//                         xIcon.initDelay = false;
//                     }
//                 }
//
//                 onFinished: {
//                     xIcon.initDelay = false;
//                 }
//             }
//         }
//
//         Component.onCompleted: restartAnimation()
//     }
// }
// WARN: Previous version


import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root
    implicitHeight: 38
    width: parent ? parent.width : 1280

    property string activeWorkspace: "Edit"
    signal workspaceChanged(string newWorkspace, string oldWorkspace)

    readonly property real availableMenuWidth: root.width - (brandRow.width + 24) - (tabsContainer.width + 24)
    readonly property bool isCompactMode: availableMenuWidth < standardMenuBar.implicitWidth
    // =========================================================================
    //  CENTRAL MENU DATA – only place you ever need to edit
    // =========================================================================
    readonly property var menuData: [
        {
            title: "File",
            items: [
                {
                    id: "file.new",
                    title: "New Project",
                    shortcut: "Ctrl+N",
                    icon: "qrc:/assets/icons/folder-plus.svg"
                },
                {
                    id: "file.open",
                    title: "Open Project",
                    shortcut: "Ctrl+O",
                    icon: "qrc:/assets/icons/folder-open.svg"
                },
                {
                    id: "file.open_recent",
                    title: "Open Recent",
                    icon: "qrc:/assets/icons/folder-open-recent.svg"
                },
                {
                    id: "file.close_project",
                    title: "Close Project",
                    shortcut: "Ctrl+W",
                    icon: "qrc:/assets/icons/folder-x.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "file.save",
                    title: "Save Project",
                    shortcut: "Ctrl+S",
                    icon: "qrc:/assets/icons/drive.svg"
                },
                {
                    id: "file.save_as",
                    title: "Save As",
                    shortcut: "Ctrl+Shift+S",
                    icon: "qrc:/assets/icons/drive-cog.svg"
                },
                {
                    id: "file.revert_to_saved",
                    title: "Revert to Saved",
                    icon: "qrc:/assets/icons/history.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "file.import",
                    title: "Import",
                    shortcut: "Ctrl+I",
                    icon: "qrc:/assets/icons/file-import.svg"
                },
                {
                    type: "submenu",
                    title: "Export",
                    icon: "qrc:/assets/icons/file-export.svg",
                    items: [
                        {
                            id: "file.timeline",
                            title: "Timeline",
                            icon: "qrc:/assets/icons/timeline.svg"
                        },
                        {
                            id: "file.frame",
                            title: "Frame",
                            icon: "qrc:/assets/icons/frame.svg"
                        },
                        {
                            id: "file.audio",
                            title: "Audio",
                            icon: "qrc:/assets/icons/audio.svg"
                        },
                        {
                            type: "separator"
                        },
                        {
                            id: "file.otio",
                            title: "OTIO"
                        },
                        {
                            id: "file.fcpxml",
                            title: "FCPXML"
                        },
                        {
                            id: "file.aaf",
                            title: "AAF"
                        },
                        {
                            id: "file.edl",
                            title: "EDL"
                        },
                        {
                            type: "separator"
                        },
                        {
                            id: "file.export.omf",
                            title: "OMF"
                        },
                        {
                            id: "file.export.png_sequence",
                            title: "PNG Sequence",
                            icon: "qrc:/assets/icons/png.svg"
                        },
                        {
                            id: "file.export.tiff_sequence",
                            title: "TIFF Sequence"
                        },
                        {
                            id: "file.export.exr_sequence",
                            title: "OpenEXR Sequence"
                        },
                        {
                            id: "file.export.markers_csv",
                            title: "Markers as CSV",
                            icon: "qrc:/assets/icons/csv.svg"
                        },
                        {
                            type: "separator"
                        },
                        {
                            id: "file.subtitles",
                            title: "Subtitles",
                            icon: "qrc:/assets/icons/subtitles.svg"
                        }
                    ]
                },
                {
                    id: "file.render",
                    title: "Render",
                    shortcut: "Ctrl+M",
                    icon: "qrc:/assets/icons/player-play.svg"
                },
                {
                    type: "separator"
                },
                {
                    type: "submenu",
                    title: "Project",
                    icon: "qrc:/assets/icons/app.svg",
                    items: [
                        {
                            id: "file.project_settings",
                            title: "Project Settings",
                            icon: "qrc:/assets/icons/settings.svg"
                        },
                        {
                            id: "file.project_metadata",
                            title: "Project Metadata",
                            icon: "qrc:/assets/icons/edit.svg"
                        }
                    ]
                },
                {
                    type: "separator"
                },
                {
                    id: "file.quit",
                    title: "Quit",
                    shortcut: "Ctrl+Q",
                    icon: "qrc:/assets/icons/x.svg"
                }
            ]
        },
        {
            title: "Edit",
            items: [
                {
                    id: "edit.undo",
                    title: "Undo",
                    shortcut: "Ctrl+Z",
                    icon: "qrc:/assets/icons/arrow-left.svg"
                },
                {
                    id: "edit.redo",
                    title: "Redo",
                    shortcut: "Ctrl+Y",
                    icon: "qrc:/assets/icons/arrow-right.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "edit.cut",
                    title: "Cut",
                    shortcut: "Ctrl+X",
                    icon: "qrc:/assets/icons/scissors.svg"
                },
                {
                    id: "edit.copy",
                    title: "Copy",
                    shortcut: "Ctrl+C",
                    icon: "qrc:/assets/icons/copy.svg"
                },
                {
                    id: "edit.paste",
                    title: "Paste",
                    shortcut: "Ctrl+V",
                    icon: "qrc:/assets/icons/clipboard.svg"
                },
                {
                    id: "edit.paste_insert",
                    title: "Paste Insert",
                    shortcut: "Ctrl+Shift+V",
                    icon: "qrc:/assets/icons/clipboard-plus.svg"
                },
                {
                    id: "edit.paste_overwrite",
                    title: "Paste Overwrite",
                    shortcut: "Ctrl+Alt+V",
                    icon: "qrc:/assets/icons/clipboard-check.svg"
                },
                {
                    id: "edit.duplicate",
                    title: "Duplicate",
                    shortcut: "Ctrl+D",
                    icon: "qrc:/assets/icons/copy-plus.svg"
                },
                {
                    id: "edit.delete",
                    title: "Delete",
                    shortcut: "Delete",
                    icon: "qrc:/assets/icons/trash.svg"
                },
                {
                    id: "edit.ripple_delete",
                    title: "Ripple Delete",
                    shortcut: "Shift+Delete",
                    icon: "qrc:/assets/icons/trash-x.svg"
                },
                {
                    type: "separator"
                },
                {
                    type: "submenu",
                    title: "Select",
                    icon: "qrc:/assets/icons/select-all.svg",
                    items: [
                        {
                            id: "edit.select_all",
                            title: "Select All",
                            shortcut: "Ctrl+A",
                            icon: "qrc:/assets/icons/select-all.svg"
                        },
                        {
                            id: "edit.deselect_all",
                            title: "Deselect All",
                            shortcut: "Ctrl+Shift+A",
                            icon: "qrc:/assets/icons/deselect-all.svg"
                        },
                        {
                            id: "edit.invert_selection",
                            title: "Invert Selection",
                            icon: "qrc:/assets/icons/invert.svg"
                        },
                        {
                            id: "edit.filter_selection",
                            title: "Filter Selection",
                            icon: "qrc:/assets/icons/filter.svg"
                        },
                        {
                            id: "edit.select_tracks",
                            title: "Select Tracks",
                            icon: "qrc:/assets/icons/stack.svg"
                        }
                    ]
                },
                {
                    type: "separator"
                },
                {
                    id: "edit.find",
                    title: "Find...",
                    shortcut: "Ctrl+F",
                    icon: "qrc:/assets/icons/search.svg"
                },
                {
                    id: "edit.find_replace",
                    title: "Find and Replace...",
                    shortcut: "Ctrl+H",
                    icon: "qrc:/assets/icons/replace.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "edit.shortcuts",
                    title: "Keyboard Shortcuts...",
                    shortcut: "Ctrl+Alt+K",
                    icon: "qrc:/assets/icons/keyboard.svg"
                },
                {
                    id: "edit.preferences",
                    title: "Preferences...",
                    shortcut: "Ctrl+,",
                    icon: "qrc:/assets/icons/settings.svg"
                }
            ]
        },
        {
            title: "View",
            items: [
                {
                    id: "view.fullscreen",
                    title: "Fullscreen Window",
                    shortcut: "F11",
                    icon: "qrc:/assets/icons/maximize.svg"
                },

                // Panels submenu
                {
                    type: "submenu",
                    title: "Panels",
                    items: [
                        {
                            id: "view.toggle_timeline",
                            title: "Toggle Timeline",
                            icon: "qrc:/assets/icons/timeline.svg"
                        },
                        {
                            id: "view.toggle_project",
                            title: "Toggle Project Panel",
                            icon: "qrc:/assets/icons/folder.svg"
                        },
                        {
                            id: "view.toggle_effects",
                            title: "Toggle Effects Panel",
                            icon: "qrc:/assets/icons/effect.svg"
                        },
                        {
                            id: "view.toggle_properties",
                            title: "Toggle Properties Panel",
                            icon: "qrc:/assets/icons/sliders.svg"
                        },
                        {
                            id: "view.toggle_audio",
                            title: "Toggle Audio Panel",
                            icon: "qrc:/assets/icons/music.svg"
                        },
                        {
                            id: "view.toggle_color",
                            title: "Toggle Color Panel",
                            icon: "qrc:/assets/icons/palette.svg"
                        },
                        {
                            id: "view.toggle_metadata",
                            title: "Toggle Metadata Panel",
                            icon: "qrc:/assets/icons/info.svg"
                        }
                    ]
                },
                {
                    type: "separator"
                },

                // Zoom submenu
                {
                    type: "submenu",
                    title: "Zoom",
                    items: [
                        {
                            id: "view.zoom_in",
                            title: "Zoom In",
                            shortcut: "Ctrl+=",
                            icon: "qrc:/assets/icons/zoom-in.svg"
                        },
                        {
                            id: "view.zoom_out",
                            title: "Zoom Out",
                            shortcut: "Ctrl+-",
                            icon: "qrc:/assets/icons/zoom-out.svg"
                        },
                        {
                            id: "view.zoom_fit",
                            title: "Zoom to Fit",
                            shortcut: "Shift+Z",
                            icon: "qrc:/assets/icons/zoom-fit.svg"
                        },
                        {
                            id: "view.zoom_selection",
                            title: "Zoom to Selection",
                            icon: "qrc:/assets/icons/focus.svg"
                        }
                    ]
                },
                {
                    id: "view.reset_view",
                    title: "Reset View",
                    icon: "qrc:/assets/icons/refresh.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "view.load_workspace",
                    title: "Load Workspace Layout...",
                    icon: "qrc:/assets/icons/layout-grid.svg"
                },
                {
                    id: "view.save_workspace",
                    title: "Save Workspace Layout...",
                    icon: "qrc:/assets/icons/layout-grid-add.svg"
                },
                {
                    id: "view.manage_layouts",
                    title: "Manage Layout Presets...",
                    icon: "qrc:/assets/icons/layout-board.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "view.theme_settings",
                    title: "Theme Settings...",
                    icon: "qrc:/assets/icons/palette.svg"
                },
                {
                    id: "view.goto_timecode",
                    title: "Go to Timecode...",
                    shortcut: "Ctrl+G",
                    icon: "qrc:/assets/icons/clock.svg"
                },

                // Overlays submenu
                {
                    type: "submenu",
                    title: "Overlays",
                    icon: "qrc:/assets/icons/app.svg",
                    items: [
                        {
                            id: "view.show_grid",
                            title: "Show Grid",
                            icon: "qrc:/assets/icons/grid-dots.svg"
                        },
                        {
                            id: "view.show_rulers",
                            title: "Show Rulers",
                            icon: "qrc:/assets/icons/ruler.svg"
                        },
                        {
                            id: "view.show_safe_areas",
                            title: "Show Safe Areas",
                            icon: "qrc:/assets/icons/box.svg"
                        },
                        {
                            id: "view.show_markers",
                            title: "Show Markers",
                            icon: "qrc:/assets/icons/bookmark.svg"
                        },
                        {
                            id: "view.show_waveforms",
                            title: "Show Waveforms",
                            icon: "qrc:/assets/icons/wave-sine.svg"
                        },
                        {
                            id: "view.show_thumbnails",
                            title: "Show Thumbnails",
                            icon: "qrc:/assets/icons/photo.svg"
                        },
                        {
                            id: "view.show_keyframes",
                            title: "Show Keyframes",
                            icon: "qrc:/assets/icons/keyframe.svg"
                        }
                    ]
                }
            ]
        },
        {
            title: "Clip",
            items: [
                // Add Clip submenu
                {
                    type: "submenu",
                    title: "Add Clip",
                    items: [
                        {
                            id: "clip.add_video",
                            title: "Video Clip",
                            icon: "qrc:/assets/icons/video.svg"
                        },
                        {
                            id: "clip.add_audio",
                            title: "Audio Clip",
                            icon: "qrc:/assets/icons/music.svg"
                        },
                        {
                            id: "clip.add_image",
                            title: "Image",
                            icon: "qrc:/assets/icons/photo.svg"
                        },
                        {
                            id: "clip.add_text",
                            title: "Text",
                            icon: "qrc:/assets/icons/text.svg"
                        },
                        {
                            id: "clip.add_vector",
                            title: "Vector",
                            icon: "qrc:/assets/icons/vector.svg"
                        },
                        {
                            id: "clip.add_subtitle",
                            title: "Subtitle",
                            icon: "qrc:/assets/icons/subtitles.svg"
                        },
                        {
                            id: "clip.add_adjustment",
                            title: "Adjustment Clip",
                            icon: "qrc:/assets/icons/effects.svg"
                        },
                        {
                            id: "clip.add_color_matte",
                            title: "Color Matte",
                            icon: "qrc:/assets/icons/square.svg"
                        },
                        {
                            id: "clip.add_title_template",
                            title: "Title Template",
                            icon: "qrc:/assets/icons/typography.svg"
                        },
                        {
                            id: "clip.add_lower_third",
                            title: "Lower Third",
                            icon: "qrc:/assets/icons/text-caption.svg"
                        },
                        {
                            id: "clip.add_overlay",
                            title: "Overlay",
                            icon: "qrc:/assets/icons/layers-linked.svg"
                        }
                    ]
                },
                {
                    type: "separator"
                },
                {
                    id: "clip.add_effect",
                    title: "Add Effect...",
                    icon: "qrc:/assets/icons/adjustments.svg"
                },
                {
                    id: "clip.add_transition",
                    title: "Add Transition...",
                    icon: "qrc:/assets/icons/transition.svg"
                },
                {
                    id: "clip.add_keyframe",
                    title: "Add Keyframe",
                    icon: "qrc:/assets/icons/keyframe.svg"
                },
                {
                    type: "separator"
                },

                // Trim submenu
                {
                    type: "submenu",
                    title: "Trim",
                    items: [
                        {
                            id: "clip.split",
                            title: "Split Clip",
                            shortcut: "Ctrl+K",
                            icon: "qrc:/assets/icons/cut.svg"
                        },
                        {
                            id: "clip.split_sample",
                            title: "Split at Sample Level",
                            shortcut: "S",
                            icon: "qrc:/assets/icons/cut.svg"
                        },
                        {
                            id: "clip.slice",
                            title: "Slice Clip",
                            icon: "qrc:/assets/icons/scissors.svg"
                        },
                        {
                            id: "clip.trim_start",
                            title: "Trim Start",
                            shortcut: "Q",
                            icon: "qrc:/assets/icons/bracket-left.svg"
                        },
                        {
                            id: "clip.trim_end",
                            title: "Trim End",
                            shortcut: "W",
                            icon: "qrc:/assets/icons/bracket-right.svg"
                        },
                        {
                            id: "clip.ripple_trim",
                            title: "Ripple Trim",
                            icon: "qrc:/assets/icons/resize.svg"
                        },
                        {
                            id: "clip.roll_trim",
                            title: "Roll Trim",
                            icon: "qrc:/assets/icons/arrows-horizontal.svg"
                        },
                        {
                            id: "clip.slip_trim",
                            title: "Slip Trim",
                            icon: "qrc:/assets/icons/arrows-move-horizontal.svg"
                        },
                        {
                            id: "clip.slide_trim",
                            title: "Slide Trim",
                            icon: "qrc:/assets/icons/arrows-move.svg"
                        },
                        {
                            id: "clip.extend_to_playhead",
                            title: "Extend to Playhead",
                            shortcut: "E",
                            icon: "qrc:/assets/icons/arrow-right.svg"
                        },
                        {
                            id: "clip.shrink_to_playhead",
                            title: "Shrink to Playhead",
                            icon: "qrc:/assets/icons/arrow-left.svg"
                        },
                        {
                            id: "clip.snap_to_playhead",
                            title: "Snap to Playhead",
                            icon: "qrc:/assets/icons/magnet.svg"
                        }
                    ]
                },
                {
                    type: "separator"
                },
                {
                    id: "clip.transcode",
                    title: "Transcode Clip...",
                    icon: "qrc:/assets/icons/refresh.svg"
                },
                {
                    id: "clip.replace_clip",
                    title: "Replace Clip...",
                    icon: "qrc:/assets/icons/replace.svg"
                },
                {
                    id: "clip.replace_source",
                    title: "Replace Source...",
                    icon: "qrc:/assets/icons/link.svg"
                },
                {
                    id: "clip.reconnect_clip",
                    title: "Reconnect Clip...",
                    icon: "qrc:/assets/icons/link.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "clip.open_in_asset_manager",
                    title: "Open Clip in Asset Manager",
                    icon: "qrc:/assets/icons/folder-search.svg"
                },
                {
                    id: "clip.open_in_new_timeline",
                    title: "Open Clip in New Timeline",
                    icon: "qrc:/assets/icons/timeline.svg"
                },
                {
                    id: "clip.open_in_source_monitor",
                    title: "Open in Source Monitor",
                    icon: "qrc:/assets/icons/player-play.svg"
                },
                {
                    id: "clip.replace_selected",
                    title: "Replace Selected Clips",
                    icon: "qrc:/assets/icons/replace.svg"
                },
                {
                    id: "clip.ripple_replace",
                    title: "Ripple Replace Clip Occurrences",
                    icon: "qrc:/assets/icons/replace-all.svg"
                },
                {
                    type: "separator"
                },

                // Select submenu
                {
                    type: "submenu",
                    title: "Select",
                    items: [
                        {
                            id: "clip.select_all_occurrences",
                            title: "Select All Occurrences",
                            icon: "qrc:/assets/icons/select-all.svg"
                        },
                        {
                            id: "clip.select_matching",
                            title: "Select Matching",
                            icon: "qrc:/assets/icons/filter.svg"
                        },
                        {
                            id: "clip.checker_deselect",
                            title: "Checker Deselect",
                            icon: "qrc:/assets/icons/grid-dots.svg"
                        },
                        {
                            id: "clip.select_first",
                            title: "Select First",
                            icon: "qrc:/assets/icons/player-skip-back.svg"
                        },
                        {
                            id: "clip.select_last",
                            title: "Select Last",
                            icon: "qrc:/assets/icons/player-skip-forward.svg"
                        },
                        {
                            id: "clip.select_first_and_last",
                            title: "Select First and Last",
                            icon: "qrc:/assets/icons/arrows-left-right.svg"
                        },
                        {
                            id: "clip.select_previous",
                            title: "Select Previous",
                            icon: "qrc:/assets/icons/chevron-left.svg"
                        },
                        {
                            id: "clip.select_next",
                            title: "Select Next",
                            icon: "qrc:/assets/icons/chevron-right.svg"
                        },
                        {
                            id: "clip.select_left_edge",
                            title: "Select Left Edge",
                            icon: "qrc:/assets/icons/bracket-left.svg"
                        },
                        {
                            id: "clip.select_right_edge",
                            title: "Select Right Edge",
                            icon: "qrc:/assets/icons/bracket-right.svg"
                        }
                    ]
                },
                {
                    type: "separator"
                },
                {
                    id: "clip.properties",
                    title: "Clip Properties...",
                    shortcut: "Alt+Enter",
                    icon: "qrc:/assets/icons/info-circle.svg"
                },
                {
                    id: "clip.rename",
                    title: "Rename Clip...",
                    shortcut: "F2",
                    icon: "qrc:/assets/icons/edit.svg"
                },
                {
                    id: "clip.duplicate",
                    title: "Duplicate Clip",
                    icon: "qrc:/assets/icons/copy-plus.svg"
                },
                {
                    id: "clip.delete",
                    title: "Delete Clip",
                    shortcut: "Delete",
                    icon: "qrc:/assets/icons/trash.svg"
                },
                {
                    type: "separator"
                },

                // Time submenu
                {
                    type: "submenu",
                    title: "Time",
                    items: [
                        {
                            id: "clip.reverse",
                            title: "Reverse Clip",
                            icon: "qrc:/assets/icons/arrow-back-up.svg"
                        },
                        {
                            id: "clip.freeze_frame",
                            title: "Freeze Frame",
                            icon: "qrc:/assets/icons/snowflake.svg"
                        },
                        {
                            id: "clip.speed_duration",
                            title: "Speed/Duration...",
                            shortcut: "Ctrl+R",
                            icon: "qrc:/assets/icons/gauge.svg"
                        },
                        {
                            id: "clip.time_remapping",
                            title: "Time Remapping",
                            icon: "qrc:/assets/icons/clock.svg"
                        }
                    ]
                },
                {
                    type: "separator"
                },

                // Nesting submenu
                {
                    type: "submenu",
                    title: "Nesting",
                    items: [
                        {
                            id: "clip.nest_sequence",
                            title: "Nest Sequence",
                            icon: "qrc:/assets/icons/folder-plus.svg"
                        },
                        {
                            id: "clip.unnest_sequence",
                            title: "Unnest Sequence",
                            icon: "qrc:/assets/icons/folder-minus.svg"
                        }
                    ]
                }
            ]
        },
        {
            title: "Timeline",
            items: [
                {
                    type: "submenu",
                    title: "Tracks",
                    items: [
                        {
                            id: "timeline.add_track",
                            title: "Add Track",
                            icon: "qrc:/assets/icons/plus.svg"
                        },
                        {
                            id: "timeline.add_video_track",
                            title: "Add Video Track",
                            icon: "qrc:/assets/icons/video-plus.svg"
                        },
                        {
                            id: "timeline.add_audio_track",
                            title: "Add Audio Track",
                            icon: "qrc:/assets/icons/music-plus.svg"
                        },
                        {
                            id: "timeline.delete_track",
                            title: "Delete Track",
                            icon: "qrc:/assets/icons/trash.svg"
                        },
                        {
                            id: "timeline.delete_video_track",
                            title: "Delete Video Track",
                            icon: "qrc:/assets/icons/video-minus.svg"
                        },
                        {
                            id: "timeline.delete_audio_track",
                            title: "Delete Audio Track",
                            icon: "qrc:/assets/icons/music-minus.svg"
                        },
                        {
                            id: "timeline.move_track_up",
                            title: "Move Track Up",
                            icon: "qrc:/assets/icons/arrow-up.svg"
                        },
                        {
                            id: "timeline.move_track_down",
                            title: "Move Track Down",
                            icon: "qrc:/assets/icons/arrow-down.svg"
                        },
                        {
                            id: "timeline.merge_tracks",
                            title: "Merge Tracks",
                            icon: "qrc:/assets/icons/git-merge.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Track State",
                    items: [
                        {
                            id: "timeline.lock_track",
                            title: "Lock Track",
                            icon: "qrc:/assets/icons/lock.svg"
                        },
                        {
                            id: "timeline.unlock_track",
                            title: "Unlock Track",
                            icon: "qrc:/assets/icons/lock-open.svg"
                        },
                        {
                            id: "timeline.mute_track",
                            title: "Mute Track",
                            icon: "qrc:/assets/icons/volume-off.svg"
                        },
                        {
                            id: "timeline.unmute_track",
                            title: "Unmute Track",
                            icon: "qrc:/assets/icons/volume.svg"
                        },
                        {
                            id: "timeline.solo_track",
                            title: "Solo Track",
                            icon: "qrc:/assets/icons/headphones.svg"
                        },
                        {
                            id: "timeline.unsolo_track",
                            title: "Unsolo Track",
                            icon: "qrc:/assets/icons/headphones-off.svg"
                        },
                        {
                            id: "timeline.set_track_color",
                            title: "Set Track Color...",
                            icon: "qrc:/assets/icons/palette.svg"
                        },
                        {
                            id: "timeline.set_track_name",
                            title: "Set Track Name...",
                            icon: "qrc:/assets/icons/edit.svg"
                        },
                        {
                            id: "timeline.sync_tracks",
                            title: "Sync Tracks",
                            icon: "qrc:/assets/icons/clock.svg"
                        },
                        {
                            id: "timeline.toggle_track_linking",
                            title: "Toggle Track Linking",
                            icon: "qrc:/assets/icons/link.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Gaps",
                    items: [
                        {
                            id: "timeline.insert_gap",
                            title: "Insert Gap",
                            icon: "qrc:/assets/icons/layout-gap.svg"
                        },
                        {
                            id: "timeline.delete_gap",
                            title: "Delete Gap",
                            icon: "qrc:/assets/icons/trash.svg"
                        },
                        {
                            id: "timeline.ripple_delete_gap",
                            title: "Ripple Delete Gap",
                            icon: "qrc:/assets/icons/trash-x.svg"
                        },
                        {
                            id: "timeline.close_gap",
                            title: "Close Gap",
                            icon: "qrc:/assets/icons/arrows-horizontal.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Snapping",
                    items: [
                        {
                            id: "timeline.snap_grid",
                            title: "Snap to Grid",
                            icon: "qrc:/assets/icons/grid-dots.svg"
                        },
                        {
                            id: "timeline.snap_frames",
                            title: "Snap to Frames",
                            icon: "qrc:/assets/icons/frame.svg"
                        },
                        {
                            id: "timeline.snap_markers",
                            title: "Snap to Markers",
                            icon: "qrc:/assets/icons/bookmark.svg"
                        },
                        {
                            id: "timeline.snap_clips",
                            title: "Snap to Clips",
                            icon: "qrc:/assets/icons/magnet.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "In-Out",
                    items: [
                        {
                            id: "timeline.set_in",
                            title: "Set In Point",
                            shortcut: "I",
                            icon: "qrc:/assets/icons/bracket-left.svg"
                        },
                        {
                            id: "timeline.set_out",
                            title: "Set Out Point",
                            shortcut: "O",
                            icon: "qrc:/assets/icons/bracket-right.svg"
                        },
                        {
                            id: "timeline.clear_in",
                            title: "Clear In Point",
                            shortcut: "Alt+I",
                            icon: "qrc:/assets/icons/bracket-left-off.svg"
                        },
                        {
                            id: "timeline.clear_out",
                            title: "Clear Out Point",
                            shortcut: "Alt+O",
                            icon: "qrc:/assets/icons/bracket-right-off.svg"
                        },
                        {
                            id: "timeline.clear_in_out",
                            title: "Clear In/Out Points",
                            shortcut: "Alt+X",
                            icon: "qrc:/assets/icons/clear-all.svg"
                        },
                        {
                            id: "timeline.goto_in",
                            title: "Go to In Point",
                            shortcut: "Shift+I",
                            icon: "qrc:/assets/icons/player-skip-back.svg"
                        },
                        {
                            id: "timeline.goto_out",
                            title: "Go to Out Point",
                            shortcut: "Shift+O",
                            icon: "qrc:/assets/icons/player-skip-forward.svg"
                        },
                        {
                            id: "timeline.select_in_out",
                            title: "Select In/Out Range",
                            icon: "qrc:/assets/icons/select.svg"
                        },
                        {
                            id: "timeline.ripple_select_in_out",
                            title: "Ripple Select In/Out Range",
                            icon: "qrc:/assets/icons/select-all.svg"
                        },
                        {
                            id: "timeline.zoom_in_out",
                            title: "Zoom to In/Out Points",
                            icon: "qrc:/assets/icons/zoom-fit.svg"
                        }
                    ]
                }
            ]
        },
        {
            title: "Effects",
            items: [
                {
                    type: "submenu",
                    title: "Color",
                    items: [
                        {
                            id: "effects.color_correction",
                            title: "Color Correction",
                            icon: "qrc:/assets/icons/color-filter.svg"
                        },
                        {
                            id: "effects.lut",
                            title: "Apply LUT...",
                            icon: "qrc:/assets/icons/palette.svg"
                        },
                        {
                            id: "effects.hdr_tools",
                            title: "HDR Tools",
                            icon: "qrc:/assets/icons/sun.svg"
                        },
                        {
                            id: "effects.scopes",
                            title: "Scopes",
                            icon: "qrc:/assets/icons/chart-line.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Video",
                    items: [
                        {
                            id: "effects.keyer",
                            title: "Keyer",
                            icon: "qrc:/assets/icons/eyedropper.svg"
                        },
                        {
                            id: "effects.spill_suppressor",
                            title: "Spill Suppressor",
                            icon: "qrc:/assets/icons/droplet-off.svg"
                        },
                        {
                            id: "effects.tracker",
                            title: "Tracker",
                            icon: "qrc:/assets/icons/target.svg"
                        },
                        {
                            id: "effects.stabilizer",
                            title: "Stabilizer",
                            icon: "qrc:/assets/icons/anchor.svg"
                        },
                        {
                            id: "effects.transform",
                            title: "Transform",
                            icon: "qrc:/assets/icons/transform.svg"
                        },
                        {
                            id: "effects.crop",
                            title: "Crop",
                            icon: "qrc:/assets/icons/crop.svg"
                        },
                        {
                            id: "effects.blur",
                            title: "Blur",
                            icon: "qrc:/assets/icons/blur.svg"
                        },
                        {
                            id: "effects.sharpen",
                            title: "Sharpen",
                            icon: "qrc:/assets/icons/adjustments.svg"
                        },
                        {
                            id: "effects.glow",
                            title: "Glow",
                            icon: "qrc:/assets/icons/sparkles.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Transitions",
                    items: [
                        {
                            id: "effects.fade",
                            title: "Fade",
                            icon: "qrc:/assets/icons/transition.svg"
                        },
                        {
                            id: "effects.wipe",
                            title: "Wipe",
                            icon: "qrc:/assets/icons/rectangle.svg"
                        },
                        {
                            id: "effects.slide",
                            title: "Slide",
                            icon: "qrc:/assets/icons/arrows-right-left.svg"
                        },
                        {
                            id: "effects.push",
                            title: "Push",
                            icon: "qrc:/assets/icons/arrows-left-right.svg"
                        },
                        {
                            id: "effects.cross_dissolve",
                            title: "Cross Dissolve",
                            icon: "qrc:/assets/icons/transition.svg"
                        },
                        {
                            id: "effects.dip_to_black",
                            title: "Dip to Black",
                            icon: "qrc:/assets/icons/moon.svg"
                        },
                        {
                            id: "effects.dip_to_white",
                            title: "Dip to White",
                            icon: "qrc:/assets/icons/sun.svg"
                        },
                        {
                            id: "effects.film_dissolve",
                            title: "Film Dissolve",
                            icon: "qrc:/assets/icons/camera.svg"
                        },
                        {
                            id: "effects.audio_transition",
                            title: "Audio Transition",
                            icon: "qrc:/assets/icons/wave-sine.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Audio",
                    items: [
                        {
                            id: "effects.audio_fade_in",
                            title: "Audio Fade In",
                            icon: "qrc:/assets/icons/volume.svg"
                        },
                        {
                            id: "effects.audio_fade_out",
                            title: "Audio Fade Out",
                            icon: "qrc:/assets/icons/volume-off.svg"
                        },
                        {
                            id: "effects.audio_crossfade",
                            title: "Audio Crossfade",
                            icon: "qrc:/assets/icons/arrows-left-right.svg"
                        },
                        {
                            id: "effects.audio_ducking",
                            title: "Audio Ducking",
                            icon: "qrc:/assets/icons/wave-square.svg"
                        },
                        {
                            id: "effects.noise_reduction",
                            title: "Noise Reduction",
                            icon: "qrc:/assets/icons/noise.svg"
                        },
                        {
                            id: "effects.eq",
                            title: "EQ",
                            icon: "qrc:/assets/icons/sliders.svg"
                        },
                        {
                            id: "effects.compressor",
                            title: "Compressor",
                            icon: "qrc:/assets/icons/compress.svg"
                        },
                        {
                            id: "effects.limiter",
                            title: "Limiter",
                            icon: "qrc:/assets/icons/gauge.svg"
                        },
                        {
                            id: "effects.reverb",
                            title: "Reverb",
                            icon: "qrc:/assets/icons/wave-triangle.svg"
                        },
                        {
                            id: "effects.delay",
                            title: "Delay",
                            icon: "qrc:/assets/icons/history.svg"
                        },
                        {
                            id: "effects.chorus",
                            title: "Chorus",
                            icon: "qrc:/assets/icons/waves.svg"
                        },
                        {
                            id: "effects.flanger",
                            title: "Flanger",
                            icon: "qrc:/assets/icons/wave-sine.svg"
                        },
                        {
                            id: "effects.phaser",
                            title: "Phaser",
                            icon: "qrc:/assets/icons/rotate.svg"
                        },
                        {
                            id: "effects.distortion",
                            title: "Distortion",
                            icon: "qrc:/assets/icons/alert-triangle.svg"
                        },
                        {
                            id: "effects.pitch_shift",
                            title: "Pitch Shift",
                            icon: "qrc:/assets/icons/music-note.svg"
                        },
                        {
                            id: "effects.time_stretch",
                            title: "Time Stretch",
                            icon: "qrc:/assets/icons/resize.svg"
                        },
                        {
                            id: "effects.vocal_remover",
                            title: "Vocal Remover",
                            icon: "qrc:/assets/icons/microphone-off.svg"
                        },
                        {
                            id: "effects.panning",
                            title: "Panning",
                            icon: "qrc:/assets/icons/arrows-left-right.svg"
                        },
                        {
                            id: "effects.stereo_width",
                            title: "Stereo Width",
                            icon: "qrc:/assets/icons/rectangle-wide.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Advanced",
                    items: [
                        {
                            id: "effects.keyframe_animation",
                            title: "Keyframe Animation",
                            icon: "qrc:/assets/icons/keyframe.svg"
                        },
                        {
                            id: "effects.motion_blur",
                            title: "Motion Blur",
                            icon: "qrc:/assets/icons/blur.svg"
                        },
                        {
                            id: "effects.optical_flow",
                            title: "Optical Flow",
                            icon: "qrc:/assets/icons/activity.svg"
                        },
                        {
                            id: "effects.neural_enhance",
                            title: "Neural Enhance",
                            icon: "qrc:/assets/icons/brain.svg"
                        },
                        {
                            id: "effects.noise",
                            title: "Noise",
                            icon: "qrc:/assets/icons/noise.svg"
                        },
                        {
                            id: "effects.grain",
                            title: "Film Grain",
                            icon: "qrc:/assets/icons/grain.svg"
                        },
                        {
                            id: "effects.vignette",
                            title: "Vignette",
                            icon: "qrc:/assets/icons/circle.svg"
                        },
                        {
                            id: "effects.chromatic_aberration",
                            title: "Chromatic Aberration",
                            icon: "qrc:/assets/icons/rainbow.svg"
                        },
                        {
                            id: "effects.lens_distortion",
                            title: "Lens Distortion",
                            icon: "qrc:/assets/icons/lens.svg"
                        },
                        {
                            id: "effects.depth_of_field",
                            title: "Depth of Field",
                            icon: "qrc:/assets/icons/focus.svg"
                        },
                        {
                            id: "effects.color_grading",
                            title: "Color Grading",
                            icon: "qrc:/assets/icons/palette.svg"
                        },
                        {
                            id: "effects.look_table",
                            title: "Look Table",
                            icon: "qrc:/assets/icons/table.svg"
                        },
                        {
                            id: "effects.custom_shader",
                            title: "Custom Shader...",
                            icon: "qrc:/assets/icons/code.svg"
                        }
                    ]
                }
            ]
        },
        {
            title: "Title & Graphics",
            items: [
                {
                    id: "title.new",
                    title: "New Title",
                    icon: "qrc:/assets/icons/typography.svg"
                },
                {
                    id: "title.edit",
                    title: "Edit Title",
                    icon: "qrc:/assets/icons/edit.svg"
                },
                {
                    id: "title.duplicate",
                    title: "Duplicate Title",
                    icon: "qrc:/assets/icons/copy-plus.svg"
                },
                {
                    id: "title.delete",
                    title: "Delete Title",
                    icon: "qrc:/assets/icons/trash.svg"
                },
                {
                    id: "title.import_template",
                    title: "Import Title Template...",
                    icon: "qrc:/assets/icons/file-import.svg"
                },
                {
                    id: "title.export_template",
                    title: "Export Title Template...",
                    icon: "qrc:/assets/icons/file-export.svg"
                },
                {
                    type: "separator"
                },
                {
                    type: "submenu",
                    title: "Layers",
                    items: [
                        {
                            id: "title.add_text_layer",
                            title: "Add Text Layer",
                            icon: "qrc:/assets/icons/text-plus.svg"
                        },
                        {
                            id: "title.add_shape_layer",
                            title: "Add Shape Layer",
                            icon: "qrc:/assets/icons/shape.svg"
                        },
                        {
                            id: "title.add_image_layer",
                            title: "Add Image Layer",
                            icon: "qrc:/assets/icons/photo.svg"
                        },
                        {
                            id: "title.add_vector_layer",
                            title: "Add Vector Layer",
                            icon: "qrc:/assets/icons/vector.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Arrange",
                    items: [
                        {
                            id: "title.bring_to_front",
                            title: "Bring to Front",
                            icon: "qrc:/assets/icons/layers-intersect.svg"
                        },
                        {
                            id: "title.send_to_back",
                            title: "Send to Back",
                            icon: "qrc:/assets/icons/layers-subtract.svg"
                        },
                        {
                            id: "title.bring_forward",
                            title: "Bring Forward",
                            icon: "qrc:/assets/icons/arrow-up.svg"
                        },
                        {
                            id: "title.send_backward",
                            title: "Send Backward",
                            icon: "qrc:/assets/icons/arrow-down.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Align",
                    items: [
                        {
                            id: "title.align_left",
                            title: "Align Left",
                            icon: "qrc:/assets/icons/align-left.svg"
                        },
                        {
                            id: "title.align_right",
                            title: "Align Right",
                            icon: "qrc:/assets/icons/align-right.svg"
                        },
                        {
                            id: "title.align_center",
                            title: "Align Center",
                            icon: "qrc:/assets/icons/align-center.svg"
                        },
                        {
                            id: "title.align_top",
                            title: "Align Top",
                            icon: "qrc:/assets/icons/align-top.svg"
                        },
                        {
                            id: "title.align_bottom",
                            title: "Align Bottom",
                            icon: "qrc:/assets/icons/align-bottom.svg"
                        },
                        {
                            id: "title.align_middle",
                            title: "Align Middle",
                            icon: "qrc:/assets/icons/align-middle.svg"
                        },
                        {
                            id: "title.distribute_horizontal",
                            title: "Distribute Horizontal",
                            icon: "qrc:/assets/icons/distribute-horizontal.svg"
                        },
                        {
                            id: "title.distribute_vertical",
                            title: "Distribute Vertical",
                            icon: "qrc:/assets/icons/distribute-vertical.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Match",
                    items: [
                        {
                            id: "title.match_position",
                            title: "Match Position",
                            icon: "qrc:/assets/icons/arrows-move.svg"
                        },
                        {
                            id: "title.match_scale",
                            title: "Match Scale",
                            icon: "qrc:/assets/icons/resize.svg"
                        },
                        {
                            id: "title.match_rotation",
                            title: "Match Rotation",
                            icon: "qrc:/assets/icons/rotate.svg"
                        },
                        {
                            id: "title.match_opacity",
                            title: "Match Opacity",
                            icon: "qrc:/assets/icons/droplet.svg"
                        }
                    ]
                },
                {
                    type: "submenu",
                    title: "Layer Ops",
                    items: [
                        {
                            id: "title.group_layers",
                            title: "Group Layers",
                            shortcut: "Ctrl+G",
                            icon: "qrc:/assets/icons/folder-plus.svg"
                        },
                        {
                            id: "title.ungroup_layers",
                            title: "Ungroup Layers",
                            shortcut: "Ctrl+Shift+G",
                            icon: "qrc:/assets/icons/folder-minus.svg"
                        },
                        {
                            id: "title.lock_layer",
                            title: "Lock Layer",
                            icon: "qrc:/assets/icons/lock.svg"
                        },
                        {
                            id: "title.unlock_layer",
                            title: "Unlock Layer",
                            icon: "qrc:/assets/icons/lock-open.svg"
                        },
                        {
                            id: "title.hide_layer",
                            title: "Hide Layer",
                            icon: "qrc:/assets/icons/eye-off.svg"
                        },
                        {
                            id: "title.show_layer",
                            title: "Show Layer",
                            icon: "qrc:/assets/icons/eye.svg"
                        }
                    ]
                }
            ]
        },
        {
            title: "Audio",
            items: [
                {
                    id: "audio.gain",
                    title: "Audio Gain...",
                    shortcut: "G",
                    icon: "qrc:/assets/icons/volume.svg"
                },
                {
                    id: "audio.normalize",
                    title: "Normalize Audio",
                    icon: "qrc:/assets/icons/wave-sine.svg"
                },
                {
                    id: "audio.levels",
                    title: "Audio Levels...",
                    icon: "qrc:/assets/icons/sliders.svg"
                },
                {
                    id: "audio.pan",
                    title: "Audio Pan",
                    icon: "qrc:/assets/icons/arrows-left-right.svg"
                },
                {
                    id: "audio.balance",
                    title: "Audio Balance",
                    icon: "qrc:/assets/icons/balance.svg"
                },
                {
                    id: "audio.track_color",
                    title: "Audio Track Color...",
                    icon: "qrc:/assets/icons/palette.svg"
                },
                {
                    id: "audio.render",
                    title: "Render Audio",
                    icon: "qrc:/assets/icons/player-play.svg"
                },
                {
                    id: "audio.replace",
                    title: "Replace Audio...",
                    icon: "qrc:/assets/icons/replace.svg"
                },
                {
                    id: "audio.sync",
                    title: "Sync Audio",
                    icon: "qrc:/assets/icons/clock.svg"
                },
                {
                    id: "audio.scene_detection",
                    title: "Audio Scene Detection",
                    icon: "qrc:/assets/icons/activity.svg"
                }
            ]
        },
        {
            title: "Color",
            items: [
                {
                    id: "color.primary",
                    title: "Primary Correction",
                    icon: "qrc:/assets/icons/color-filter.svg"
                },
                {
                    id: "color.secondary",
                    title: "Secondary Correction",
                    icon: "qrc:/assets/icons/color-swatch.svg"
                },
                {
                    id: "color.wheels",
                    title: "Color Wheels",
                    icon: "qrc:/assets/icons/palette.svg"
                },
                {
                    id: "color.curves",
                    title: "Color Curves",
                    icon: "qrc:/assets/icons/chart-line.svg"
                },
                {
                    id: "color.lut",
                    title: "Color LUT...",
                    icon: "qrc:/assets/icons/table.svg"
                },
                {
                    id: "color.keyer",
                    title: "Color Keyer",
                    icon: "qrc:/assets/icons/eyedropper.svg"
                },
                {
                    id: "color.qualifier",
                    title: "Color Qualifier",
                    icon: "qrc:/assets/icons/filter.svg"
                },
                {
                    id: "color.window",
                    title: "Color Window",
                    icon: "qrc:/assets/icons/square.svg"
                },
                {
                    id: "color.power_window",
                    title: "Power Window",
                    icon: "qrc:/assets/icons/octagon.svg"
                },
                {
                    id: "color.tracker",
                    title: "Color Tracker",
                    icon: "qrc:/assets/icons/target.svg"
                },
                {
                    id: "color.stabilizer",
                    title: "Color Stabilizer",
                    icon: "qrc:/assets/icons/anchor.svg"
                },
                {
                    id: "color.render",
                    title: "Render Color Cache",
                    icon: "qrc:/assets/icons/player-play.svg"
                },
                {
                    id: "color.snapshot",
                    title: "Take Color Snapshot",
                    icon: "qrc:/assets/icons/camera.svg"
                },
                {
                    id: "color.match",
                    title: "Color Match",
                    icon: "qrc:/assets/icons/arrows-left-right.svg"
                },
                {
                    type: "separator"
                },
                {
                    type: "submenu",
                    title: "Adjustments",
                    items: [
                        {
                            id: "color.balance",
                            title: "Color Balance",
                            icon: "qrc:/assets/icons/balance.svg"
                        },
                        {
                            id: "color.temperature",
                            title: "Temperature",
                            icon: "qrc:/assets/icons/thermometer.svg"
                        },
                        {
                            id: "color.tint",
                            title: "Tint",
                            icon: "qrc:/assets/icons/droplet.svg"
                        },
                        {
                            id: "color.saturation",
                            title: "Saturation",
                            icon: "qrc:/assets/icons/sun.svg"
                        },
                        {
                            id: "color.contrast",
                            title: "Contrast",
                            icon: "qrc:/assets/icons/contrast.svg"
                        },
                        {
                            id: "color.shadows",
                            title: "Shadows",
                            icon: "qrc:/assets/icons/moon.svg"
                        },
                        {
                            id: "color.midtones",
                            title: "Midtones",
                            icon: "qrc:/assets/icons/circle-half.svg"
                        },
                        {
                            id: "color.highlights",
                            title: "Highlights",
                            icon: "qrc:/assets/icons/sun.svg"
                        },
                        {
                            id: "color.log",
                            title: "Log Controls",
                            icon: "qrc:/assets/icons/chart-dots.svg"
                        },
                        {
                            id: "color.hdr",
                            title: "HDR Controls",
                            icon: "qrc:/assets/icons/sparkles.svg"
                        }
                    ]
                }
            ]
        },
        {
            title: "Review",
            items: [
                {
                    id: "review.add_marker",
                    title: "Add Marker",
                    shortcut: "M",
                    icon: "qrc:/assets/icons/bookmark.svg"
                },
                {
                    id: "review.delete_marker",
                    title: "Delete Marker",
                    icon: "qrc:/assets/icons/bookmark-off.svg"
                },
                {
                    id: "review.goto_marker",
                    title: "Go to Marker",
                    icon: "qrc:/assets/icons/map-pin.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "review.add_comment",
                    title: "Add Comment",
                    icon: "qrc:/assets/icons/message.svg"
                },
                {
                    id: "review.add_note",
                    title: "Add Note",
                    icon: "qrc:/assets/icons/note.svg"
                },
                {
                    id: "review.add_todo",
                    title: "Add To-Do",
                    icon: "qrc:/assets/icons/checklist.svg"
                },
                {
                    id: "review.submit_feedback",
                    title: "Submit Feedback",
                    icon: "qrc:/assets/icons/send.svg"
                },
                {
                    id: "review.export_feedback",
                    title: "Export Feedback...",
                    icon: "qrc:/assets/icons/file-export.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "review.mode",
                    title: "Review Mode",
                    icon: "qrc:/assets/icons/eye.svg"
                },
                {
                    id: "review.comparison_view",
                    title: "Comparison View",
                    icon: "qrc:/assets/icons/columns.svg"
                },
                {
                    id: "review.split_view",
                    title: "Split View",
                    icon: "qrc:/assets/icons/layout-split.svg"
                }
            ]
        },
        {
            title: "Tools",
            items: [
                {
                    id: "tools.selection",
                    title: "Selection Tool",
                    shortcut: "V",
                    icon: "qrc:/assets/icons/cursor.svg"
                },
                {
                    id: "tools.razor",
                    title: "Razor Tool",
                    shortcut: "C",
                    icon: "qrc:/assets/icons/cut.svg"
                },
                {
                    id: "tools.roll",
                    title: "Roll Tool",
                    shortcut: "N",
                    icon: "qrc:/assets/icons/arrows-horizontal.svg"
                },
                {
                    id: "tools.ripple",
                    title: "Ripple Tool",
                    shortcut: "B",
                    icon: "qrc:/assets/icons/resize.svg"
                },
                {
                    id: "tools.slip",
                    title: "Slip Tool",
                    shortcut: "Y",
                    icon: "qrc:/assets/icons/arrows-move-horizontal.svg"
                },
                {
                    id: "tools.slide",
                    title: "Slide Tool",
                    shortcut: "U",
                    icon: "qrc:/assets/icons/arrows-move.svg"
                },
                {
                    id: "tools.pen",
                    title: "Pen Tool",
                    shortcut: "P",
                    icon: "qrc:/assets/icons/pen.svg"
                },
                {
                    id: "tools.hand",
                    title: "Hand Tool",
                    shortcut: "H",
                    icon: "qrc:/assets/icons/hand-stop.svg"
                },
                {
                    id: "tools.zoom",
                    title: "Zoom Tool",
                    shortcut: "Z",
                    icon: "qrc:/assets/icons/zoom-in.svg"
                },
                {
                    id: "tools.crop",
                    title: "Crop Tool",
                    icon: "qrc:/assets/icons/crop.svg"
                },
                {
                    id: "tools.mask",
                    title: "Mask Tool",
                    icon: "qrc:/assets/icons/mask.svg"
                },
                {
                    id: "tools.text",
                    title: "Text Tool",
                    shortcut: "T",
                    icon: "qrc:/assets/icons/text-size.svg"
                }
            ]
        },
        {
            title: "Window",
            items: [
                {
                    id: "window.new",
                    title: "New Window",
                    shortcut: "Ctrl+Shift+N",
                    icon: "qrc:/assets/icons/window.svg"
                },
                {
                    id: "window.close",
                    title: "Close Window",
                    shortcut: "Ctrl+Shift+W",
                    icon: "qrc:/assets/icons/x.svg"
                },
                {
                    id: "window.toggle_dock",
                    title: "Toggle Dock",
                    icon: "qrc:/assets/icons/layout-sidebar.svg"
                },
                {
                    id: "window.reset_layout",
                    title: "Reset Window Layout",
                    icon: "qrc:/assets/icons/layout-grid.svg"
                },
                {
                    id: "window.fullscreen",
                    title: "Fullscreen Window",
                    shortcut: "F11",
                    icon: "qrc:/assets/icons/maximize.svg"
                },
                {
                    id: "window.minimize",
                    title: "Minimize Window",
                    icon: "qrc:/assets/icons/minus.svg"
                },
                {
                    id: "window.maximize",
                    title: "Maximize Window",
                    icon: "qrc:/assets/icons/maximize.svg"
                }
            ]
        },
        {
            title: "Help",
            items: [
                {
                    id: "help.documentation",
                    title: "Documentation",
                    shortcut: "F1",
                    icon: "qrc:/assets/icons/book.svg"
                },
                {
                    id: "help.tutorials",
                    title: "Tutorials",
                    icon: "qrc:/assets/icons/video.svg"
                },
                {
                    id: "help.shortcuts",
                    title: "Keyboard Shortcuts Help",
                    icon: "qrc:/assets/icons/keyboard.svg"
                },
                {
                    id: "help.community",
                    title: "Community Forums",
                    icon: "qrc:/assets/icons/users.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "help.report_issue",
                    title: "Report Issue",
                    icon: "qrc:/assets/icons/bug.svg"
                },
                {
                    id: "help.feature_request",
                    title: "Feature Request",
                    icon: "qrc:/assets/icons/bulb.svg"
                },
                {
                    id: "help.check_updates",
                    title: "Check for Updates",
                    icon: "qrc:/assets/icons/refresh.svg"
                },
                {
                    type: "separator"
                },
                {
                    id: "help.about",
                    title: "About Xyla",
                    icon: "qrc:/assets/icons/info-circle.svg"
                },
                {
                    id: "help.system_info",
                    title: "System Info",
                    icon: "qrc:/assets/icons/cpu.svg"
                }
            ]
        }
    // Add more menus here later (View, Clip, etc.)
    ]

    // =========================================================================
    //  WORKSPACE TABS DATA
    // =========================================================================
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

Component {
    id: menuItemComp
    XylaMenuItem {
        property var itemData: null
        text: itemData ? itemData.title || "" : ""
        itemIcon: itemData ? itemData.icon || "" : ""
        itemShortcut: itemData ? itemData.shortcut || "" : ""
        onTriggered: if (typeof menuManager !== "undefined" && itemData) 
                         menuManager.triggerAction(itemData.id)
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
        title: subMenuData ? subMenuData.title || "" : ""
        menuIcon: subMenuData ? subMenuData.icon || "" : ""
    }
}

// 3. One-time builder (called only once)
function buildMenus(targetMenuBar, isCompact) {
    if (!targetMenuBar || root.menusBuilt) return

    for (var i = 0; i < root.menuData.length; ++i) {
        var menuInfo = root.menuData[i]

        var menu = submenuComp.createObject(targetMenuBar, {
            subMenuData: { title: menuInfo.title, icon: menuInfo.icon || "" }
        })

        if (isCompact)
            targetMenuBar.addMenu(menu)
        else
            targetMenuBar.addMenu(menu)

        // populate children
        populateMenu(menu, menuInfo.items || [])
    }
}

function populateMenu(menu, items) {
    for (var i = 0; i < items.length; ++i) {
        var data = items[i]
        if (!data) continue

        if (data.type === "separator") {
            menu.addItem(separatorComp.createObject(menu))
        } else if (data.type === "submenu") {
            var sub = submenuComp.createObject(menu, { subMenuData: data })
            menu.addMenu(sub)
            populateMenu(sub, data.items || [])
        } else {
            menu.addItem(menuItemComp.createObject(menu, { itemData: data }))
        }
    }
  }

    // Component {
    //     id: separatorComp
    //     XylaMenuSeparator {}
    // }

    // Component {
    //     id: submenuComp
    //     XylaMenu {
    //         property var subMenuData: null
    //         title: subMenuData ? subMenuData.title || "" : ""
    //         menuIcon: subMenuData ? subMenuData.icon || "" : ""
    //     }
    // }

    // 3. One-time builder (called only once)
    // function buildMenus(targetMenuBar, isCompact) {
    //     if (!targetMenuBar || root.menusBuilt)
    //         return;
    //     for (var i = 0; i < root.menuData.length; ++i) {
    //         var menuInfo = root.menuData[i];
    //
    //         var menu = submenuComp.createObject(targetMenuBar, {
    //             subMenuData: {
    //                 title: menuInfo.title,
    //                 icon: menuInfo.icon || ""
    //             }
    //         });
    //
    //         if (isCompact)
    //             targetMenuBar.addMenu(menu);
    //         else
    //             targetMenuBar.addMenu(menu);
    //
    //         // populate children
    //         populateMenu(menu, menuInfo.items || []);
    //     }
    // }

    // function populateMenu(menu, items) {
    //     for (var i = 0; i < items.length; ++i) {
    //         var data = items[i];
    //         if (!data)
    //             continue;
    //         if (data.type === "separator") {
    //             menu.addItem(separatorComp.createObject(menu));
    //         } else if (data.type === "submenu") {
    //             var sub = submenuComp.createObject(menu, {
    //                 subMenuData: data
    //             });
    //             menu.addMenu(sub);
    //             populateMenu(sub, data.items || []);
    //         } else {
    //             menu.addItem(menuItemComp.createObject(menu, {
    //                 itemData: data
    //             }));
    //         }
    //     }
    // }

    property bool menusBuilt: false

    // =========================================================================
    //  BACKGROUND
    // =========================================================================
    Rectangle {
        anchors.fill: parent
        color: "#0E0E0E"
    }

    // readonly property real availableMenuWidth: root.width - (brandRow.width + 24) - (tabsContainer.width + 24)
    // readonly property bool isCompactMode: availableMenuWidth < 520

    // =========================================================================
    //  MAIN LAYOUT
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 8

        // -----------------------------------------------------------------
        // Brand + Compact hamburger
        // -----------------------------------------------------------------
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

            XylaIconButton {
                id: compactMenuBtn
                visible: root.isCompactMode
                iconSource: "qrc:/assets/icons/menu.svg"
                ghost: true
                primary: compactMenuPopup.visible
                tooltip: "Application Menu"
                Layout.alignment: Qt.AlignVCenter

                onClicked: {
                    if (compactMenuPopup.visible)
                        compactMenuPopup.close();
                    else
                        compactMenuPopup.open();
                }

                XylaMenu {
                    id: compactMenuPopup
                    y: compactMenuBtn.height + 6

                    Component.onCompleted: {
                        buildMenus(compactMenuPopup, true);
                    }
                }
            }
        }

        // -----------------------------------------------------------------
        // Standard Menu Bar
        // -----------------------------------------------------------------
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

                // Exact original MenuBarItem style
                Component.onCompleted: {
                    buildMenus(standardMenuBar, false);
                    root.menusBuilt = true;
                }
            }
        }

        // Spacer when compact
        Item {
            Layout.fillWidth: true
            visible: root.isCompactMode
        }

        // -----------------------------------------------------------------
        // Workspace Tabs (exact original style)
        // -----------------------------------------------------------------
        Item {
            id: tabsContainer
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitHeight: 30
            implicitWidth: tabsRow.implicitWidth + 16
            clip: false

            Rectangle {
                anchors.fill: parent
                color: "#050505"
                radius: 7
            }

            // Sliding indicator
            Item {
                id: followerTrack
                anchors.fill: parent
                z: 2

                property real leftEdge: 4
                property real rightEdge: 54
                property real targetLeft: 4
                property real targetRight: 54
                property bool movingRight: true
                property real stretchLeft: 4
                property real stretchRight: 54

                readonly property Item currentTabItem: {
                    for (var i = 0; i < tabsRepeater.count; ++i) {
                        var itm = tabsRepeater.itemAt(i);
                        if (itm && itm.tabId === root.activeWorkspace)
                            return itm;
                    }
                    return null;
                }

                function updateIndicator() {
                    var item = currentTabItem;
                    if (!item)
                        return;
                    var newLeft = tabsRow.x + item.x;
                    var newRight = newLeft + item.width;
                    movingRight = newLeft > leftEdge;
                    targetLeft = newLeft;
                    targetRight = newRight;
                    if (movingRight) {
                        stretchRight = newRight;
                        stretchLeft = newLeft;
                    } else {
                        stretchLeft = newLeft;
                        stretchRight = newRight;
                    }
                    indicatorAnimation.restart();
                }

                Component.onCompleted: updateIndicator()

                Connections {
                    target: root
                    function onActiveWorkspaceChanged() {
                        followerTrack.updateIndicator();
                    }
                }

                Rectangle {
                    id: indicatorCapsule
                    x: followerTrack.leftEdge
                    width: Math.max(1, followerTrack.rightEdge - followerTrack.leftEdge)
                    anchors.top: parent.top
                    anchors.topMargin: 3
                    height: parent.height - 3 + ((root.height - parent.height) / 2) + 1
                    color: "#191919"
                    topLeftRadius: 6
                    topRightRadius: 6
                    bottomLeftRadius: 0
                    bottomRightRadius: 0

                    Canvas {
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
                    Canvas {
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
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 3
                anchors.bottomMargin: 3
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
                        implicitWidth: tabContent.implicitWidth + 28

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
                            anchors.centerIn: parent
                            implicitWidth: tabRow.implicitWidth
                            implicitHeight: tabRow.implicitHeight

                            Row {
                                id: tabRow
                                spacing: 6

                                Image {
                                    id: tabIcon
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
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
                            onClicked: {
                                if (root.activeWorkspace === modelData.id)
                                    return;
                                var prev = root.activeWorkspace;
                                root.activeWorkspace = modelData.id;
                                root.workspaceChanged(modelData.id, prev);
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    //  X logo (exact original)
    // =========================================================================
    component XIcon: Item {
        id: xIcon
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
            anchors.fill: parent
            property real progress: 0

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.scale(width / 24, height / 24);
                ctx.lineWidth = 2;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

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
                onFinished: xIcon.initDelay = false
            }
        }
        Component.onCompleted: restartAnimation()
    }
}
