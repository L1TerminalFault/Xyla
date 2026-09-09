// import QtQuick
// import QtQuick.Controls
// import QtQuick.Layouts
// import QtQuick.Effects
// import Xyla 1.0
// import "../components"
// import "./timeline"
//
// Item {
//     id: root
//
//     property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
//     property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null
//     property var activeProjectManager: typeof projectManager !== "undefined" ? projectManager : null
//     property var activeProject: activeProjectManager?.activeProject ?? null
//     property var activeShortcutManager: typeof shortcutManager !== "undefined" ? shortcutManager : null
//
//     readonly property int trackCount: activeTimelineModel ? activeTimelineModel.trackCount : 0
//     readonly property int playheadFrame: activePlaybackManager ? activePlaybackManager.currentFrame : 0
//
//     property double zoomFactor: activeTimelineModel ? activeTimelineModel.zoomFactor : 1.0
//     property real horizontalOffset: activeTimelineModel ? activeTimelineModel.horizontalOffset : 0.0
//     property real contentWidth: 3600
//
//     readonly property real projectFps: {
//         if (!activeProject)
//             return 30.0;
//         if (typeof activeProject.fps === "number" && activeProject.fps > 0) {
//             return activeProject.fps;
//         }
//         if (activeProject.fpsNumerator && activeProject.fpsDenominator) {
//             return activeProject.fpsNumerator / activeProject.fpsDenominator;
//         }
//         return 30.0;
//     }
//
//     property int headerWidth: 220
//     property int minHeaderWidth: 220
//     property int maxHeaderWidth: 600
//
//     readonly property color bgDark: "#141414"
//     readonly property color bgHeader: "#181818"
//     readonly property color borderDark: "#2d2d2d"
//     readonly property real playheadMargin: 10.0
//
//     // Neutral Gray Tones (Zero blue/tint)
//     readonly property color videoTrackBg: "#141414"
//     readonly property color audioTrackBg: "#222222"
//
//     function getTrackBgColor(trackIdx) {
//         if (!root.activeTimelineModel)
//             return root.videoTrackBg;
//         var kind = root.activeTimelineModel.getTrackKind(trackIdx);
//         return (kind === 1) ? root.audioTrackBg : root.videoTrackBg;
//     }
//
//     property bool isMiddlePanning: false
//
//     readonly property real topShelfHeight: 36
//     readonly property real bottomShelfHeight: 36
//
//     property var trackHeights: []
//     property var trackOffsets: []
//     property real totalTracksHeight: 200
//
//     property real snapGuideFrame: -1
//     property bool isSnapLineVisible: false
//     property var activeSpacingGaps: []
//
//     property int pendingNewTrackKind: 0
//
//     function showSnapLine(frame) {
//         snapGuideFrame = frame;
//         isSnapLineVisible = (frame >= 0);
//         activeSpacingGaps = [];
//     }
//
//     function showSpacingGuides(gapsList) {
//         if (gapsList && gapsList.length > 0) {
//             activeSpacingGaps = gapsList;
//         } else {
//             activeSpacingGaps = [];
//         }
//     }
//
//     function hideSnapGuides() {
//         isSnapLineVisible = false;
//         snapGuideFrame = -1;
//         activeSpacingGaps = [];
//     }
//
//     function updateTrackMetrics() {
//         var count = root.trackCount;
//         var heights = [];
//         var offsets = [];
//         var cumY = topShelfHeight; // Starts after the top + button shelf
//
//         for (var i = 0; i < count; ++i) {
//             var item = trackHeaderColumn.children[i];
//             var h = (item && item.implicitHeight) ? item.implicitHeight : (trackHeights[i] ?? 68);
//             heights.push(h);
//             offsets.push(cumY);
//             cumY += h;
//         }
//         trackHeights = heights;
//         trackOffsets = offsets;
//         totalTracksHeight = cumY + bottomShelfHeight;
//     }
//
//     function getTrackY(t) {
//         if (t < 0 || !trackOffsets || t >= trackOffsets.length)
//             return topShelfHeight + (t * 68);
//         return trackOffsets[t];
//     }
//
//     function getTrackHeight(t) {
//         if (t < 0 || !trackHeights || t >= trackHeights.length)
//             return 68;
//         return trackHeights[t];
//     }
//
//     function getTrackAtY(canvasY) {
//         if (!trackOffsets || trackOffsets.length === 0)
//             return 0;
//         for (var i = trackOffsets.length - 1; i >= 0; --i) {
//             if (canvasY >= trackOffsets[i])
//                 return i;
//         }
//         return 0;
//     }
//
//     function updateContentWidth() {
//         if (!root.activeTimelineModel)
//             return;
//         var maxFrame = 0;
//         var all = root.activeTimelineModel.getAllClips();
//         for (var i = 0; i < all.length; ++i) {
//             var endF = Number(all[i].startFrame) + Number(all[i].durationFrames);
//             if (endF > maxFrame)
//                 maxFrame = endF;
//         }
//         var requiredPx = (maxFrame * root.zoomFactor) + 1000;
//         root.contentWidth = Math.max(3600, requiredPx);
//     }
//
//     function applyZoom(factor, cursorScreenX) {
//         var visibleTimelineX = cursorScreenX - root.headerWidth - root.playheadMargin;
//         var frameAtAnchor = (visibleTimelineX + root.horizontalOffset) / root.zoomFactor;
//
//         var newZoom = Math.max(0.1, Math.min(10.0, root.zoomFactor * factor));
//         var newOffset = (frameAtAnchor * newZoom) - visibleTimelineX;
//         var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
//         var clampedOffset = Math.max(0, Math.min(maxOffset, newOffset));
//
//         if (root.activeTimelineModel) {
//             root.activeTimelineModel.zoomFactor = newZoom;
//             root.activeTimelineModel.horizontalOffset = clampedOffset;
//         }
//         root.updateContentWidth();
//     }
//
//     function frameToPx(frame) {
//         return root.playheadMargin + (frame * root.zoomFactor);
//     }
//
//     function pxToFrame(px) {
//         return Math.max(0, Math.round((px - root.playheadMargin) / root.zoomFactor));
//     }
//
//     function formatTimecode(frame) {
//         var fps = root.projectFps;
//         var totalSec = frame / fps;
//         var hrs = Math.floor(totalSec / 3600);
//         var mins = Math.floor((totalSec % 3600) / 60);
//         var secs = Math.floor(totalSec % 60);
//         var frames = Math.floor(frame % fps);
//
//         function pad(n) {
//             return n < 10 ? "0" + n : n;
//         }
//         return pad(hrs) + ":" + pad(mins) + ":" + pad(secs) + ":" + pad(frames);
//     }
//
//     function openContextMenu(screenX, screenY, frame, trackIdx, clipData) {
//         timelineContextMenu.openAt(screenX, screenY, frame, trackIdx, clipData);
//     }
//
//     Rectangle {
//         anchors.fill: parent
//         color: root.bgDark
//         z: -1
//     }
//
//     Rectangle {
//         id: marqueeRect
//         color: "#253B82F6"
//         border.color: "#3B82F6"
//         border.width: 1
//         visible: false
//         z: 400
//     }
//
//     ColumnLayout {
//         anchors.fill: parent
//         spacing: 0
//
//         // Toolbar
//         Rectangle {
//             id: topToolBar
//             color: "#191919"
//             Layout.fillWidth: true
//             height: 40
//
//             Rectangle {
//                 anchors.left: parent.left
//                 anchors.right: parent.right
//                 anchors.bottom: parent.bottom
//                 height: 1
//                 color: root.borderDark
//             }
//
//             RowLayout {
//                 anchors.left: parent.left
//                 anchors.right: centerControls.left
//                 anchors.verticalCenter: parent.verticalCenter
//                 anchors.leftMargin: 10
//                 anchors.rightMargin: 10
//                 spacing: 6
//             }
//
//             Row {
//                 id: centerControls
//                 anchors.centerIn: parent
//                 spacing: 6
//
//                 Rectangle {
//                     height: 32
//                     width: transportRow.implicitWidth
//                     color: "transparent"
//                     border.color: "#2d2d2d"
//                     border.width: 1
//                     radius: 6
//
//                     Row {
//                         id: transportRow
//                         anchors.verticalCenter: parent.verticalCenter
//
//                         XylaIconButton {
//                             roundLeft: true
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/player-track-prev.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.playFromStart()
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/player-skip-back.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.jumpBackwardSeconds(5.0)
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/chevron-left.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.stepBackward(1)
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             property bool isPlayingForward: root.activePlaybackManager && root.activePlaybackManager.isPlaying && !root.activePlaybackManager.isPlayingReverse
//                             roundLeft: false
//                             roundRight: false
//                             ghost: !isPlayingForward
//                             primary: isPlayingForward
//                             iconSource: isPlayingForward ? "qrc:/assets/icons/player-pause.svg" : "qrc:/assets/icons/player-play.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.togglePlay()
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             property bool isPlayingReverse: root.activePlaybackManager && root.activePlaybackManager.isPlaying && root.activePlaybackManager.isPlayingReverse
//                             roundLeft: false
//                             roundRight: false
//                             ghost: !isPlayingReverse
//                             primary: isPlayingReverse
//                             iconSource: "qrc:/assets/icons/player-play-reverse.svg"
//                             onClicked: {
//                                 if (!root.activePlaybackManager)
//                                     return;
//                                 if (isPlayingReverse)
//                                     root.activePlaybackManager.pause();
//                                 else
//                                     root.activePlaybackManager.playReverse();
//                             }
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/chevron-right.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.stepForward(1)
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: true
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/player-skip-forward.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.jumpForwardSeconds(5.0)
//                         }
//                     }
//                 }
//
//                 Rectangle {
//                     width: 100
//                     height: 32
//                     color: "transparent"
//                     border.color: "#2d2d2d"
//                     border.width: 1
//                     radius: 6
//
//                     Text {
//                         anchors.centerIn: parent
//                         text: root.formatTimecode(root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0)
//                         color: "#ffffff"
//                         font.pixelSize: 11
//                         font.bold: true
//                         font.family: "Monospace"
//                     }
//                 }
//             }
//
//             RowLayout {
//                 anchors.right: parent.right
//                 anchors.left: centerControls.right
//                 anchors.verticalCenter: parent.verticalCenter
//                 anchors.leftMargin: 10
//                 anchors.rightMargin: 10
//                 layoutDirection: Qt.RightToLeft
//                 spacing: 6
//
//                 XylaIconButton {
//                     id: rippleSettingsBtn
//                     ghost: true
//                     iconSource: "qrc:/assets/icons/settings.svg"
//                     Layout.preferredWidth: 28
//                     Layout.preferredHeight: 28
//                     tooltip: "Timeline Settings"
//                     onClicked: ripplePopup.open()
//
//                     XylaTimelineRippleSettingsPopup {
//                         id: ripplePopup
//                         x: rippleSettingsBtn.width - width
//                         y: rippleSettingsBtn.height + 6
//                         timelineModel: root.activeTimelineModel
//                     }
//                 }
//             }
//         }
//
//         XylaTimelineRuler {
//             id: timelineRuler
//             Layout.fillWidth: true
//             headerWidth: root.headerWidth + root.playheadMargin
//             zoomFactor: root.zoomFactor
//             horizontalOffset: root.horizontalOffset
//             contentWidth: root.contentWidth
//             fps: root.projectFps
//             z: 250
//         }
//
//         // Main Timeline Content Area
//         Item {
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//
//             // State A: When Tracks Exist
//             RowLayout {
//                 anchors.fill: parent
//                 spacing: 0
//                 visible: root.trackCount > 0
//
//                 // Left Column: Scrollable Track Headers & Shelves
//                 Item {
//                     Layout.preferredWidth: root.headerWidth
//                     Layout.fillHeight: true
//                     clip: true
//
//                     // Forward Wheel Scrolling on Header to Main Vertical Scroll
//                     WheelHandler {
//                         target: null
//                         acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
//                         onWheel: event => {
//                             var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
//                             var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
//                             trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, trackScrollArea.contentY - pDeltaY));
//                         }
//                     }
//
//                     Item {
//                         id: headerContentItem
//                         width: parent.width
//                         y: -trackScrollArea.contentY
//                         height: root.totalTracksHeight
//
//                         // Top + Video Button Shelf (scrolls out of view when scrolling down)
//                         Rectangle {
//                             id: topVideoShelf
//                             width: parent.width
//                             height: root.topShelfHeight
//                             y: 0
//                             color: topVideoMouse.containsMouse ? "#222222" : "#181818"
//                             border.color: topVideoMouse.containsMouse ? "#3b82f6" : root.borderDark
//                             border.width: 1
//
//                             Behavior on color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//                             Behavior on border.color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//
//                             MouseArea {
//                                 id: topVideoMouse
//                                 anchors.fill: parent
//                                 hoverEnabled: true
//                                 cursorShape: Qt.PointingHandCursor
//                                 onClicked: {
//                                     root.pendingNewTrackKind = 0;
//                                     addTrackModal.open();
//                                 }
//
//                                 Row {
//                                     anchors.centerIn: parent
//                                     spacing: 6
//
//                                     Image {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         width: 14
//                                         height: 14
//                                         source: "qrc:/assets/icons/plus.svg"
//                                         opacity: topVideoMouse.containsMouse ? 1.0 : 0.6
//                                     }
//
//                                     Text {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         text: "Add Video Track"
//                                         color: topVideoMouse.containsMouse ? "#ffffff" : "#888888"
//                                         font.pixelSize: 11
//                                         font.bold: true
//                                     }
//                                 }
//                             }
//                         }
//
//                         // Track Headers Column
//                         Column {
//                             id: trackHeaderColumn
//                             width: parent.width
//                             y: root.topShelfHeight
//
//                             Repeater {
//                                 model: root.activeTimelineModel
//
//                                 XylaTrackHeader {
//                                     width: root.headerWidth
//                                     trackId: model.trackId || ""
//                                     trackName: model.trackName || ""
//                                     trackKind: model.trackKind !== undefined ? model.trackKind : 0
//
//                                     onImplicitHeightChanged: root.updateTrackMetrics()
//                                     onTrackHeightChanged: root.updateTrackMetrics()
//                                     Component.onCompleted: root.updateTrackMetrics()
//                                 }
//                             }
//                         }
//
//                         Rectangle {
//                             id: bottomAudioShelf
//                             width: parent.width
//                             height: root.bottomShelfHeight
//                             y: root.totalTracksHeight - root.bottomShelfHeight
//                             color: bottomAudioMouse.containsMouse ? "#222222" : "#181818"
//                             border.color: bottomAudioMouse.containsMouse ? "#3b82f6" : root.borderDark
//                             border.width: 1
//
//                             Behavior on color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//                             Behavior on border.color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//
//                             MouseArea {
//                                 id: bottomAudioMouse
//                                 anchors.fill: parent
//                                 hoverEnabled: true
//                                 cursorShape: Qt.PointingHandCursor
//                                 onClicked: {
//                                     root.pendingNewTrackKind = 1;
//                                     addTrackModal.open();
//                                 }
//
//                                 Row {
//                                     anchors.centerIn: parent
//                                     spacing: 6
//
//                                     Image {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         width: 14
//                                         height: 14
//                                         source: "qrc:/assets/icons/plus.svg"
//                                         opacity: bottomAudioMouse.containsMouse ? 1.0 : 0.6
//                                     }
//
//                                     Text {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         text: "Add Audio Track"
//                                         color: bottomAudioMouse.containsMouse ? "#ffffff" : "#888888"
//                                         font.pixelSize: 11
//                                         font.bold: true
//                                     }
//                                 }
//                             }
//                         }
//                     }
//                 }
//
//                 // Right Side: Unified 2D Timeline Canvas
//                 Flickable {
//                     id: trackScrollArea
//                     Layout.fillWidth: true
//                     Layout.fillHeight: true
//                     clip: true
//                     boundsBehavior: Flickable.StopAtBounds
//                     contentWidth: root.contentWidth + root.playheadMargin
//                     contentHeight: root.totalTracksHeight
//                     interactive: false
//
//                     // Explicit Dark Backdrop prevents white canvas leaks
//                     Rectangle {
//                         anchors.fill: parent
//                         color: "#121212"
//                         z: 0
//                     }
//
//                     DragHandler {
//                         id: middleDragHandler
//                         target: null
//                         acceptedButtons: Qt.MiddleButton
//                         property real startHorizOffset: 0
//                         property real startContentY: 0
//
//                         onActiveChanged: {
//                             root.isMiddlePanning = active;
//                             if (active) {
//                                 startHorizOffset = root.horizontalOffset;
//                                 startContentY = trackScrollArea.contentY;
//                             }
//                         }
//
//                         onTranslationChanged: {
//                             if (active) {
//                                 var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
//                                 var newOffset = Math.max(0, Math.min(maxOffset, startHorizOffset - translation.x));
//                                 if (root.activeTimelineModel) {
//                                     root.activeTimelineModel.horizontalOffset = newOffset;
//                                 }
//
//                                 var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
//                                 trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, startContentY - translation.y));
//                             }
//                         }
//                     }
//
//                     // Handles both vertical timeline scroll AND Ctrl+Zoom
//                     WheelHandler {
//                         id: wheelHandler
//                         target: null
//                         acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
//                         onWheel: event => {
//                             var cursorX = event.point?.position?.x ?? wheelHandler.point?.position?.x ?? (trackScrollArea.width / 2);
//
//                             if (event.modifiers & Qt.ControlModifier) {
//                                 var factor = event.angleDelta.y > 0 ? 1.35 : 0.74;
//                                 root.applyZoom(factor, cursorX + root.headerWidth);
//                                 return;
//                             }
//
//                             var pDeltaX = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x;
//                             var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
//
//                             var isHorizontal = (Math.abs(pDeltaX) > Math.abs(pDeltaY)) || (event.modifiers & Qt.ShiftModifier);
//
//                             if (isHorizontal) {
//                                 var deltaX = pDeltaX !== 0 ? -pDeltaX : -pDeltaY;
//                                 var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
//                                 var newOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaX));
//                                 if (root.activeTimelineModel) {
//                                     root.activeTimelineModel.horizontalOffset = newOffset;
//                                 }
//                             } else {
//                                 var deltaY = -pDeltaY;
//                                 var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
//                                 trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, trackScrollArea.contentY + deltaY));
//                             }
//                         }
//                     }
//
//                     Item {
//                         id: timelineCanvasViewport
//                         x: root.playheadMargin - root.horizontalOffset
//                         width: root.contentWidth
//                         height: trackScrollArea.contentHeight
//
//                         // 1. Top & Bottom Background Shelf Strips
//                         Rectangle {
//                             width: timelineCanvasViewport.width
//                             height: root.topShelfHeight
//                             y: 0
//                             color: "#161616"
//                             border.color: root.borderDark
//                             border.width: 1
//                         }
//
//                         Rectangle {
//                             width: timelineCanvasViewport.width
//                             height: root.bottomShelfHeight
//                             y: root.totalTracksHeight - root.bottomShelfHeight
//                             color: "#161616"
//                             border.color: root.borderDark
//                             border.width: 1
//                         }
//
//                         // 2. Dynamic Background Track Stripes (Neutral Gray Differentiation)
//                         Column {
//                             y: root.topShelfHeight
//                             width: timelineCanvasViewport.width
//
//                             Repeater {
//                                 model: root.trackCount
//                                 Rectangle {
//                                     width: timelineCanvasViewport.width
//                                     height: root.getTrackHeight(index)
//                                     color: root.getTrackBgColor(index)
//
//                                     Rectangle {
//                                         anchors.left: parent.left
//                                         anchors.right: parent.right
//                                         anchors.bottom: parent.bottom
//                                         height: 1
//                                         color: root.borderDark
//                                     }
//                                 }
//                             }
//                         }
//
//                         // 3. Empty Space Marquee Selection Area
//                         MouseArea {
//                             anchors.fill: parent
//                             z: 1
//                             acceptedButtons: Qt.LeftButton | Qt.RightButton
//
//                             property real startGlobalX: 0
//                             property real startGlobalY: 0
//                             property real startCanvasX: 0
//                             property real startCanvasY: 0
//                             property bool isMarquee: false
//
//                             onPressed: function (mouse) {
//                                 if (mouse.button === Qt.RightButton)
//                                     return;
//
//                                 var globalPt = mapToItem(root, mouse.x, mouse.y);
//                                 startGlobalX = globalPt.x;
//                                 startGlobalY = globalPt.y;
//                                 startCanvasX = mouse.x;
//                                 startCanvasY = mouse.y;
//                                 isMarquee = false;
//                             }
//
//                             onPositionChanged: function (mouse) {
//                                 if (mouse.buttons & Qt.RightButton)
//                                     return;
//
//                                 var globalPt = mapToItem(root, mouse.x, mouse.y);
//                                 var dx = globalPt.x - startGlobalX;
//                                 var dy = globalPt.y - startGlobalY;
//
//                                 if (!isMarquee && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
//                                     isMarquee = true;
//                                     if (root.activeTimelineModel) {
//                                         root.activeTimelineModel.startSelectionBatch();
//                                     }
//                                 }
//
//                                 if (isMarquee) {
//                                     var x1 = Math.min(startGlobalX, globalPt.x);
//                                     var x2 = Math.max(startGlobalX, globalPt.x);
//                                     var y1 = Math.min(startGlobalY, globalPt.y);
//                                     var y2 = Math.max(startGlobalY, globalPt.y);
//
//                                     marqueeRect.x = x1;
//                                     marqueeRect.y = y1;
//                                     marqueeRect.width = x2 - x1;
//                                     marqueeRect.height = y2 - y1;
//                                     marqueeRect.visible = true;
//
//                                     var canvasX1 = Math.min(startCanvasX, mouse.x);
//                                     var canvasX2 = Math.max(startCanvasX, mouse.x);
//                                     var canvasY1 = Math.min(startCanvasY, mouse.y);
//                                     var canvasY2 = Math.max(startCanvasY, mouse.y);
//
//                                     var startF = root.pxToFrame(canvasX1);
//                                     var endF = root.pxToFrame(canvasX2);
//                                     var startT = root.getTrackAtY(canvasY1);
//                                     var endT = root.getTrackAtY(canvasY2);
//
//                                     var isToggle = (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier));
//                                     if (root.activeTimelineModel) {
//                                         root.activeTimelineModel.selectBox(startF, endF, startT, endT, isToggle);
//                                     }
//                                 }
//                             }
//
//                             onReleased: function (mouse) {
//                                 if (mouse.button === Qt.RightButton) {
//                                     var overlayPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
//                                     var targetF = root.pxToFrame(mouse.x);
//                                     var targetT = root.getTrackAtY(mouse.y);
//                                     root.openContextMenu(overlayPt.x, overlayPt.y, targetF, targetT, null);
//                                     return;
//                                 }
//
//                                 if (isMarquee) {
//                                     if (root.activeTimelineModel) {
//                                         root.activeTimelineModel.commitSelectionBatch();
//                                     }
//                                     isMarquee = false;
//                                     marqueeRect.visible = false;
//                                 } else if (root.activeTimelineModel) {
//                                     root.activeTimelineModel.clearSelection();
//                                 }
//                             }
//                         }
//
//                         // 4. Drop Area for Files
//                         DropArea {
//                             anchors.fill: parent
//                             keys: ["xyla/media-asset", "text/uri-list"]
//                             z: 2
//
//                             onEntered: drag => drag.accept(Qt.CopyAction)
//                             onPositionChanged: drag => drag.accept(Qt.CopyAction)
//
//                             onDropped: function (drop) {
//                                 drop.accept(Qt.CopyAction);
//                                 if (!root.activeTimelineModel)
//                                     return;
//                                 var rawUrl = "";
//                                 if (drop.hasUrls && drop.urls && drop.urls.length > 0) {
//                                     rawUrl = drop.urls[0].toString();
//                                 } else if (drop.formats && drop.formats.indexOf("text/uri-list") !== -1) {
//                                     rawUrl = drop.getDataAsString("text/uri-list").trim();
//                                 }
//
//                                 if (!rawUrl || rawUrl.length === 0)
//                                     return;
//                                 var assetName = rawUrl.substring(rawUrl.lastIndexOf('/') + 1);
//                                 if (assetName.length === 0)
//                                     assetName = "Clip";
//
//                                 var realAssetId = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetId(rawUrl) : rawUrl;
//                                 var dropFrame = root.pxToFrame(drop.x);
//                                 var dropTrack = root.getTrackAtY(drop.y);
//                                 var assetDuration = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetDurationFrames(realAssetId, root.projectFps) : 150;
//
//                                 root.activeTimelineModel.addClip(realAssetId, assetName, dropTrack, dropFrame, assetDuration, 0);
//                                 root.updateContentWidth();
//                             }
//                         }
//
//                         // 5. Unified 2D Clips Layer
//                         Item {
//                             id: unifiedClipsLayer
//                             anchors.fill: parent
//                             z: 10
//
//                             Connections {
//                                 target: root.activeTimelineModel ? root.activeTimelineModel : null
//                                 function onTrackDataChanged(trackIndex) {
//                                     clipRepeater.refreshAllClips();
//                                     root.updateContentWidth();
//                                     root.updateTrackMetrics();
//                                 }
//                                 function onTrackCountChanged() {
//                                     clipRepeater.refreshAllClips();
//                                     root.updateContentWidth();
//                                     root.updateTrackMetrics();
//                                 }
//                                 function onClipPropertiesChanged(clipId) {
//                                     clipRepeater.refreshAllClips();
//                                 }
//                                 function onDataChanged(topLeft, bottomRight, roles) {
//                                     clipRepeater.refreshAllClips();
//                                 }
//                             }
//
//                             Repeater {
//                                 id: clipRepeater
//                                 model: []
//
//                                 function refreshAllClips() {
//                                     if (root.activeTimelineModel) {
//                                         model = root.activeTimelineModel.getAllClips();
//                                     } else {
//                                         model = [];
//                                     }
//                                 }
//
//                                 Component.onCompleted: refreshAllClips()
//
//                                 XylaClipCard {
//                                     timelineRoot: root
//                                     clipData: modelData
//                                     zoomFactor: root.zoomFactor
//                                 }
//                             }
//                         }
//
//                         // 6. Visual Snapping & Figma Spacing Guides Layer
//                         Item {
//                             id: snapGuideLayer
//                             anchors.fill: parent
//                             z: 500
//
//                             Rectangle {
//                                 id: snapLine
//                                 visible: root.isSnapLineVisible && root.snapGuideFrame >= 0
//                                 x: Math.round(root.snapGuideFrame * root.zoomFactor)
//                                 width: 1
//                                 height: parent.height
//                                 color: "#2563eb"
//                                 opacity: 0.8
//                                 z: 150
//
//                                 Rectangle {
//                                     anchors.top: parent.top
//                                     anchors.horizontalCenter: parent.horizontalCenter
//                                     width: 3
//                                     height: 3
//                                     radius: 1.5
//                                     color: "#3b82f6"
//                                 }
//                             }
//
//                             Item {
//                                 id: spacingGuide
//                                 visible: root.activeSpacingGaps.length > 0
//                                 anchors.fill: parent
//                                 z: 140
//
//                                 Repeater {
//                                     model: root.activeSpacingGaps
//
//                                     Rectangle {
//                                         id: gapRect
//                                         readonly property bool isActive: modelData.isActive === true
//                                         x: Math.round(Number(modelData.start) * root.zoomFactor)
//                                         width: Math.max(1, Math.round((Number(modelData.end) - Number(modelData.start)) * root.zoomFactor))
//                                         height: parent.height
//                                         color: isActive ? Qt.rgba(0.145, 0.388, 0.922, 0.18) : Qt.rgba(0.145, 0.388, 0.922, 0.10)
//                                         border.color: isActive ? "#3b82f6" : "#2563eb"
//                                         border.width: 1
//
//                                         Rectangle {
//                                             anchors.centerIn: parent
//                                             width: gapBadgeText.implicitWidth + 10
//                                             height: 18
//                                             color: gapRect.isActive ? "#2563eb" : "#1d4ed8"
//                                             radius: 4
//                                             border.color: gapRect.isActive ? "#60a5fa" : "#3b82f6"
//                                             border.width: 1
//
//                                             Text {
//                                                 id: gapBadgeText
//                                                 anchors.centerIn: parent
//                                                 text: (modelData.gapFrames !== undefined ? modelData.gapFrames : "") + "f"
//                                                 color: "#ffffff"
//                                                 font.pixelSize: 10
//                                                 font.bold: true
//                                             }
//                                         }
//                                     }
//                                 }
//                             }
//                         }
//                     }
//                 }
//             }
//
//             // State B: When 0 Tracks Exist
//             Item {
//                 anchors.fill: parent
//                 visible: root.trackCount === 0
//
//                 ColumnLayout {
//                     anchors.centerIn: parent
//                     spacing: 14
//
//                     Image {
//                         Layout.alignment: Qt.AlignHCenter
//                         source: "qrc:/assets/icons/layers.svg"
//                         sourceSize: Qt.size(42, 42)
//                         opacity: 0.35
//                     }
//
//                     ColumnLayout {
//                         Layout.alignment: Qt.AlignHCenter
//                         spacing: 4
//
//                         Text {
//                             Layout.alignment: Qt.AlignHCenter
//                             text: "No Tracks in Timeline"
//                             color: "#ffffff"
//                             font.pixelSize: 15
//                             font.bold: true
//                         }
//
//                         Text {
//                             Layout.alignment: Qt.AlignHCenter
//                             text: "Initialize video and audio tracks to begin editing"
//                             color: "#888888"
//                             font.pixelSize: 12
//                         }
//                     }
//
//                     XylaTextButton {
//                         Layout.alignment: Qt.AlignHCenter
//                         text: "Create Tracks..."
//                         primary: true
//                         onClicked: createTracksModal.open()
//                     }
//                 }
//             }
//         }
//     }
//
//     // Playhead
//     Item {
//         x: root.headerWidth
//         y: topToolBar.height
//         width: parent.width - root.headerWidth
//         height: parent.height - y
//         clip: true
//         z: 200
//         visible: root.trackCount > 0
//
//         XylaPlayhead {
//             id: mainPlayhead
//             timelineRoot: root
//             activeTimelineModel: root.activeTimelineModel
//             currentFrame: root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0
//             zoomFactor: root.zoomFactor
//             horizontalOffset: root.horizontalOffset
//             playheadMargin: root.playheadMargin
//             headerWidth: root.headerWidth
//             height: parent.height
//         }
//     }
//
//     // Sidebar Resizer
//     Item {
//         id: sidebarResizer
//         width: 8
//         x: root.headerWidth - 4
//         y: topToolBar.height
//         height: parent.height - y
//         z: 350
//         visible: root.trackCount > 0
//
//         Rectangle {
//             anchors.centerIn: parent
//             width: resizerMouse.containsMouse || resizerMouse.pressed ? 2 : 1
//             height: parent.height
//             color: resizerMouse.containsMouse || resizerMouse.pressed ? "#2555D3" : "#2d2d2d"
//
//             Behavior on width {
//                 NumberAnimation {
//                     duration: 80
//                 }
//             }
//         }
//
//         MouseArea {
//             id: resizerMouse
//             anchors.fill: parent
//             hoverEnabled: true
//             cursorShape: Qt.SizeHorCursor
//             preventStealing: true
//
//             property int startMouseX: 0
//             property int startWidth: 0
//
//             onPressed: function (mouse) {
//                 var pt = mapToItem(root, mouse.x, mouse.y);
//                 startMouseX = pt.x;
//                 startWidth = root.headerWidth;
//             }
//
//             onPositionChanged: function (mouse) {
//                 if (pressed) {
//                     var pt = mapToItem(root, mouse.x, mouse.y);
//                     var deltaX = pt.x - startMouseX;
//                     var newW = Math.max(root.minHeaderWidth, Math.min(root.maxHeaderWidth, startWidth + deltaX));
//                     root.headerWidth = newW;
//                 }
//             }
//         }
//     }
//
//     // Context Menu
//     XylaTimelineContextMenu {
//         id: timelineContextMenu
//         timelineRoot: root
//         timelineModel: root.activeTimelineModel
//         playbackManager: root.activePlaybackManager
//
//         onDeleteRequested: {
//             if (root.activeTimelineModel) {
//                 root.activeTimelineModel.deleteSelectedClips();
//                 root.updateContentWidth();
//             }
//         }
//
//         onRippleDeleteRequested: {
//             if (root.activeTimelineModel) {
//                 root.activeTimelineModel.deleteSelectedClips();
//                 root.updateContentWidth();
//             }
//         }
//
//         onSplitRequested: function (frame, track) {
//             if (root.activeTimelineModel && root.activePlaybackManager) {
//                 root.activeTimelineModel.cutAtPlayhead(root.activePlaybackManager.currentFrame);
//                 root.updateContentWidth();
//             }
//         }
//
//         onSelectAllRequested: {
//             if (root.activeTimelineModel) {
//                 var all = root.activeTimelineModel.getAllClips();
//                 var ids = [];
//                 for (var i = 0; i < all.length; ++i) {
//                     ids.push(all[i].clipId);
//                 }
//                 root.activeTimelineModel.applyDirectSelection(ids);
//             }
//         }
//     }
//
//     // Modal: Confirm Add Track
//     Popup {
//         id: addTrackModal
//         parent: Overlay.overlay
//         anchors.centerIn: parent
//         width: 320
//         padding: 16
//         modal: true
//         focus: true
//         closePolicy: Popup.CloseOnEscape
//
//         background: Rectangle {
//             color: "#181818"
//             border.color: "#303030"
//             border.width: 1
//             radius: 12
//
//             layer.enabled: true
//             layer.effect: MultiEffect {
//                 shadowEnabled: true
//                 shadowColor: "#90000000"
//                 shadowBlur: 0.75
//                 shadowVerticalOffset: 8
//             }
//         }
//
//         contentItem: ColumnLayout {
//             spacing: 14
//
//             ColumnLayout {
//                 spacing: 4
//                 Text {
//                     text: root.pendingNewTrackKind === 0 ? "Add Video Track" : "Add Audio Track"
//                     color: "#ffffff"
//                     font.pixelSize: 14
//                     font.bold: true
//                 }
//                 Text {
//                     text: root.pendingNewTrackKind === 0 ? "Insert a new video track into the timeline?" : "Append a new audio track into the timeline?"
//                     color: "#888888"
//                     font.pixelSize: 11
//                     wrapMode: Text.WordWrap
//                     Layout.fillWidth: true
//                 }
//             }
//
//             Rectangle {
//                 Layout.fillWidth: true
//                 height: 1
//                 color: "#282828"
//             }
//
//             RowLayout {
//                 Layout.fillWidth: true
//                 spacing: 8
//                 layoutDirection: Qt.RightToLeft
//
//                 XylaTextButton {
//                     text: "Add Track"
//                     primary: true
//                     onClicked: {
//                         if (root.activeTimelineModel) {
//                             if (root.pendingNewTrackKind === 0) {
//                                 if (root.activeTimelineModel.addVideoTrack) {
//                                     root.activeTimelineModel.addVideoTrack();
//                                 }
//                             } else {
//                                 if (root.activeTimelineModel.addAudioTrack) {
//                                     root.activeTimelineModel.addAudioTrack();
//                                 }
//                             }
//                             root.updateTrackMetrics();
//                             root.updateContentWidth();
//                         }
//                         addTrackModal.close();
//                     }
//                 }
//
//                 XylaTextButton {
//                     text: "Cancel"
//                     outline: true
//                     onClicked: addTrackModal.close()
//                 }
//             }
//         }
//     }
//
//     // Modal: Initialize Timeline Tracks Dialog
//     Popup {
//         id: createTracksModal
//         parent: Overlay.overlay
//         anchors.centerIn: parent
//         width: 320
//         padding: 16
//         modal: true
//         focus: true
//         closePolicy: Popup.CloseOnEscape
//
//         background: Rectangle {
//             color: "#181818"
//             border.color: "#303030"
//             border.width: 1
//             radius: 12
//
//             layer.enabled: true
//             layer.effect: MultiEffect {
//                 shadowEnabled: true
//                 shadowColor: "#90000000"
//                 shadowBlur: 0.75
//                 shadowVerticalOffset: 8
//                 shadowHorizontalOffset: 0
//             }
//         }
//
//         enter: Transition {
//             NumberAnimation {
//                 property: "opacity"
//                 from: 0.0
//                 to: 1.0
//                 duration: 150
//                 easing.type: Easing.OutCubic
//             }
//             NumberAnimation {
//                 property: "scale"
//                 from: 0.95
//                 to: 1.0
//                 duration: 180
//                 easing.type: Easing.OutCubic
//             }
//         }
//
//         exit: Transition {
//             NumberAnimation {
//                 property: "opacity"
//                 from: 1.0
//                 to: 0.0
//                 duration: 120
//                 easing.type: Easing.OutCubic
//             }
//             NumberAnimation {
//                 property: "scale"
//                 from: 1.0
//                 to: 0.95
//                 duration: 120
//                 easing.type: Easing.OutCubic
//             }
//         }
//
//         contentItem: ColumnLayout {
//             spacing: 16
//
//             ColumnLayout {
//                 spacing: 4
//                 Text {
//                     text: "Create Timeline Tracks"
//                     color: "#ffffff"
//                     font.pixelSize: 14
//                     font.bold: true
//                 }
//                 Text {
//                     text: "Select initial number of video and audio tracks"
//                     color: "#888888"
//                     font.pixelSize: 11
//                 }
//             }
//
//             Rectangle {
//                 Layout.fillWidth: true
//                 height: 1
//                 color: "#282828"
//             }
//
//             ColumnLayout {
//                 Layout.fillWidth: true
//                 spacing: 10
//
//                 RowLayout {
//                     Layout.fillWidth: true
//                     spacing: 10
//
//                     Text {
//                         text: "Video Tracks"
//                         color: "#cccccc"
//                         font.pixelSize: 12
//                         Layout.fillWidth: true
//                     }
//
//                     XylaFloatInput {
//                         id: videoTrackInput
//                         value: 2
//                         minValue: 0
//                         maxValue: 32
//                         stepSize: 1.0
//                         decimals: 0
//                         Layout.preferredWidth: 80
//                     }
//                 }
//
//                 RowLayout {
//                     Layout.fillWidth: true
//                     spacing: 10
//
//                     Text {
//                         text: "Audio Tracks"
//                         color: "#cccccc"
//                         font.pixelSize: 12
//                         Layout.fillWidth: true
//                     }
//
//                     XylaFloatInput {
//                         id: audioTrackInput
//                         value: 2
//                         minValue: 0
//                         maxValue: 32
//                         stepSize: 1.0
//                         decimals: 0
//                         Layout.preferredWidth: 80
//                     }
//                 }
//             }
//
//             Rectangle {
//                 Layout.fillWidth: true
//                 height: 1
//                 color: "#282828"
//             }
//
//             RowLayout {
//                 Layout.fillWidth: true
//                 spacing: 8
//                 layoutDirection: Qt.RightToLeft
//
//                 XylaTextButton {
//                     text: "Create"
//                     primary: true
//                     onClicked: {
//                         var vCount = Math.max(0, Math.round(videoTrackInput.value));
//                         var aCount = Math.max(0, Math.round(audioTrackInput.value));
//
//                         if (root.activeTimelineModel) {
//                             root.activeTimelineModel.createDefaultTracks(vCount, aCount);
//                             root.updateTrackMetrics();
//                             root.updateContentWidth();
//                         }
//                         createTracksModal.close();
//                     }
//                 }
//
//                 XylaTextButton {
//                     text: "Cancel"
//                     outline: true
//                     onClicked: createTracksModal.close()
//                 }
//             }
//         }
//     }
// }





// NOTE: VERSION TWO

// import QtQuick
// import QtQuick.Controls
// import QtQuick.Layouts
// import QtQuick.Effects
// import Xyla 1.0
// import "../components"
// import "./timeline"
//
// Item {
//     id: root
//
//     property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
//     property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null
//     property var activeProjectManager: typeof projectManager !== "undefined" ? projectManager : null
//     property var activeProject: activeProjectManager?.activeProject ?? null
//     property var activeShortcutManager: typeof shortcutManager !== "undefined" ? shortcutManager : null
//
//     readonly property int trackCount: activeTimelineModel ? activeTimelineModel.trackCount : 0
//     readonly property int playheadFrame: activePlaybackManager ? activePlaybackManager.currentFrame : 0
//
//     property double zoomFactor: activeTimelineModel ? activeTimelineModel.zoomFactor : 1.0
//     property real horizontalOffset: activeTimelineModel ? activeTimelineModel.horizontalOffset : 0.0
//     property real contentWidth: 3600
//
//     readonly property real projectFps: {
//         if (!activeProject)
//             return 30.0;
//         if (typeof activeProject.fps === "number" && activeProject.fps > 0) {
//             return activeProject.fps;
//         }
//         if (activeProject.fpsNumerator && activeProject.fpsDenominator) {
//             return activeProject.fpsNumerator / activeProject.fpsDenominator;
//         }
//         return 30.0;
//     }
//
//     property int headerWidth: 220
//     property int minHeaderWidth: 220
//     property int maxHeaderWidth: 600
//
//     // ADDED: Width reserved for track highlight palettes between header and clip container
//     property int paletteStripWidth: 8
//
//     readonly property color bgDark: "#141414"
//     readonly property color bgHeader: "#181818"
//     readonly property color borderDark: "#2d2d2d"
//     readonly property real playheadMargin: 10.0
//
//     // Neutral Gray Tones (Zero blue/tint)
//     readonly property color videoTrackBg: "#141414"
//     readonly property color audioTrackBg: "#222222"
//
//     function getTrackBgColor(trackIdx) {
//         if (!root.activeTimelineModel)
//             return root.videoTrackBg;
//         var kind = root.activeTimelineModel.getTrackKind(trackIdx);
//         return (kind === 1) ? root.audioTrackBg : root.videoTrackBg;
//     }
//
//     // ADDED: Helper function to determine if the playhead currently sits inside any clip on a given track index
//     function isPlayheadOnClipInTrack(trackIdx) {
//         if (!root.activeTimelineModel)
//             return false;
//         var clips = root.activeTimelineModel.getAllClips();
//         var pf = root.playheadFrame;
//         for (var i = 0; i < clips.length; ++i) {
//             var c = clips[i];
//             if (Number(c.trackIndex) === trackIdx) {
//                 var startF = Number(c.startFrame);
//                 var endF = startF + Number(c.durationFrames);
//                 if (pf >= startF && pf < endF) {
//                     return true;
//                 }
//             }
//         }
//         return false;
//     }
//
//     property bool isMiddlePanning: false
//
//     readonly property real topShelfHeight: 36
//     readonly property real bottomShelfHeight: 36
//
//     property var trackHeights: []
//     property var trackOffsets: []
//     property real totalTracksHeight: 200
//
//     property real snapGuideFrame: -1
//     property bool isSnapLineVisible: false
//     property var activeSpacingGaps: []
//
//     property int pendingNewTrackKind: 0
//
//     function showSnapLine(frame) {
//         snapGuideFrame = frame;
//         isSnapLineVisible = (frame >= 0);
//         activeSpacingGaps = [];
//     }
//
//     function showSpacingGuides(gapsList) {
//         if (gapsList && gapsList.length > 0) {
//             activeSpacingGaps = gapsList;
//         } else {
//             activeSpacingGaps = [];
//         }
//     }
//
//     function hideSnapGuides() {
//         isSnapLineVisible = false;
//         snapGuideFrame = -1;
//         activeSpacingGaps = [];
//     }
//
//     function updateTrackMetrics() {
//         var count = root.trackCount;
//         var heights = [];
//         var offsets = [];
//         var cumY = topShelfHeight; // Starts after the top + button shelf
//
//         for (var i = 0; i < count; ++i) {
//             var item = trackHeaderColumn.children[i];
//             var h = (item && item.implicitHeight) ? item.implicitHeight : (trackHeights[i] ?? 68);
//             heights.push(h);
//             offsets.push(cumY);
//             cumY += h;
//         }
//         trackHeights = heights;
//         trackOffsets = offsets;
//         totalTracksHeight = cumY + bottomShelfHeight;
//     }
//
//     function getTrackY(t) {
//         if (t < 0 || !trackOffsets || t >= trackOffsets.length)
//             return topShelfHeight + (t * 68);
//         return trackOffsets[t];
//     }
//
//     function getTrackHeight(t) {
//         if (t < 0 || !trackHeights || t >= trackHeights.length)
//             return 68;
//         return trackHeights[t];
//     }
//
//     function getTrackAtY(canvasY) {
//         if (!trackOffsets || trackOffsets.length === 0)
//             return 0;
//         for (var i = trackOffsets.length - 1; i >= 0; --i) {
//             if (canvasY >= trackOffsets[i])
//                 return i;
//         }
//         return 0;
//     }
//
//     function updateContentWidth() {
//         if (!root.activeTimelineModel)
//             return;
//         var maxFrame = 0;
//         var all = root.activeTimelineModel.getAllClips();
//         for (var i = 0; i < all.length; ++i) {
//             var endF = Number(all[i].startFrame) + Number(all[i].durationFrames);
//             if (endF > maxFrame)
//                 maxFrame = endF;
//         }
//         var requiredPx = (maxFrame * root.zoomFactor) + 1000;
//         root.contentWidth = Math.max(3600, requiredPx);
//     }
//
//     function applyZoom(factor, cursorScreenX) {
//         var visibleTimelineX = cursorScreenX - (root.headerWidth + root.paletteStripWidth) - root.playheadMargin;
//         var frameAtAnchor = (visibleTimelineX + root.horizontalOffset) / root.zoomFactor;
//
//         var newZoom = Math.max(0.1, Math.min(10.0, root.zoomFactor * factor));
//         var newOffset = (frameAtAnchor * newZoom) - visibleTimelineX;
//         var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
//         var clampedOffset = Math.max(0, Math.min(maxOffset, newOffset));
//
//         if (root.activeTimelineModel) {
//             root.activeTimelineModel.zoomFactor = newZoom;
//             root.activeTimelineModel.horizontalOffset = clampedOffset;
//         }
//         root.updateContentWidth();
//     }
//
//     function frameToPx(frame) {
//         return root.playheadMargin + (frame * root.zoomFactor);
//     }
//
//     function pxToFrame(px) {
//         return Math.max(0, Math.round((px - root.playheadMargin) / root.zoomFactor));
//     }
//
//     function formatTimecode(frame) {
//         var fps = root.projectFps;
//         var totalSec = frame / fps;
//         var hrs = Math.floor(totalSec / 3600);
//         var mins = Math.floor((totalSec % 3600) / 60);
//         var secs = Math.floor(totalSec % 60);
//         var frames = Math.floor(frame % fps);
//
//         function pad(n) {
//             return n < 10 ? "0" + n : n;
//         }
//         return pad(hrs) + ":" + pad(mins) + ":" + pad(secs) + ":" + pad(frames);
//     }
//
//     function openContextMenu(screenX, screenY, frame, trackIdx, clipData) {
//         timelineContextMenu.openAt(screenX, screenY, frame, trackIdx, clipData);
//     }
//
//     Rectangle {
//         anchors.fill: parent
//         color: root.bgDark
//         z: -1
//     }
//
//     Rectangle {
//         id: marqueeRect
//         color: "#253B82F6"
//         border.color: "#3B82F6"
//         border.width: 1
//         visible: false
//         z: 400
//     }
//
//     ColumnLayout {
//         anchors.fill: parent
//         spacing: 0
//
//         // Toolbar
//         Rectangle {
//             id: topToolBar
//             color: "#191919"
//             Layout.fillWidth: true
//             height: 40
//
//             Rectangle {
//                 anchors.left: parent.left
//                 anchors.right: parent.right
//                 anchors.bottom: parent.bottom
//                 height: 1
//                 color: root.borderDark
//             }
//
//             RowLayout {
//                 anchors.left: parent.left
//                 anchors.right: centerControls.left
//                 anchors.verticalCenter: parent.verticalCenter
//                 anchors.leftMargin: 10
//                 anchors.rightMargin: 10
//                 spacing: 6
//             }
//
//             Row {
//                 id: centerControls
//                 anchors.centerIn: parent
//                 spacing: 6
//
//                 Rectangle {
//                     height: 32
//                     width: transportRow.implicitWidth
//                     color: "transparent"
//                     border.color: "#2d2d2d"
//                     border.width: 1
//                     radius: 6
//
//                     Row {
//                         id: transportRow
//                         anchors.verticalCenter: parent.verticalCenter
//
//                         XylaIconButton {
//                             roundLeft: true
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/player-track-prev.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.playFromStart()
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/player-skip-back.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.jumpBackwardSeconds(5.0)
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/chevron-left.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.stepBackward(1)
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             property bool isPlayingForward: root.activePlaybackManager && root.activePlaybackManager.isPlaying && !root.activePlaybackManager.isPlayingReverse
//                             roundLeft: false
//                             roundRight: false
//                             ghost: !isPlayingForward
//                             primary: isPlayingForward
//                             iconSource: isPlayingForward ? "qrc:/assets/icons/player-pause.svg" : "qrc:/assets/icons/player-play.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.togglePlay()
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             property bool isPlayingReverse: root.activePlaybackManager && root.activePlaybackManager.isPlaying && root.activePlaybackManager.isPlayingReverse
//                             roundLeft: false
//                             roundRight: false
//                             ghost: !isPlayingReverse
//                             primary: isPlayingReverse
//                             iconSource: "qrc:/assets/icons/player-play-reverse.svg"
//                             onClicked: {
//                                 if (!root.activePlaybackManager)
//                                     return;
//                                 if (isPlayingReverse)
//                                     root.activePlaybackManager.pause();
//                                 else
//                                     root.activePlaybackManager.playReverse();
//                             }
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/chevron-right.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.stepForward(1)
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: true
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/player-skip-forward.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.jumpForwardSeconds(5.0)
//                         }
//                     }
//                 }
//
//                 Rectangle {
//                     width: 100
//                     height: 32
//                     color: "transparent"
//                     border.color: "#2d2d2d"
//                     border.width: 1
//                     radius: 6
//
//                     Text {
//                         anchors.centerIn: parent
//                         text: root.formatTimecode(root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0)
//                         color: "#ffffff"
//                         font.pixelSize: 11
//                         font.bold: true
//                         font.family: "Monospace"
//                     }
//                 }
//             }
//
//             RowLayout {
//                 anchors.right: parent.right
//                 anchors.left: centerControls.right
//                 anchors.verticalCenter: parent.verticalCenter
//                 anchors.leftMargin: 10
//                 anchors.rightMargin: 10
//                 layoutDirection: Qt.RightToLeft
//                 spacing: 6
//
//                 XylaIconButton {
//                     id: rippleSettingsBtn
//                     ghost: true
//                     iconSource: "qrc:/assets/icons/settings.svg"
//                     Layout.preferredWidth: 28
//                     Layout.preferredHeight: 28
//                     tooltip: "Timeline Settings"
//                     onClicked: ripplePopup.open()
//
//                     XylaTimelineRippleSettingsPopup {
//                         id: ripplePopup
//                         x: rippleSettingsBtn.width - width
//                         y: rippleSettingsBtn.height + 6
//                         timelineModel: root.activeTimelineModel
//                     }
//                 }
//             }
//         }
//
//         XylaTimelineRuler {
//             id: timelineRuler
//             Layout.fillWidth: true
//             // MODIFIED: Included paletteStripWidth in header offset calculation for ruler alignment
//             headerWidth: root.headerWidth + root.paletteStripWidth + root.playheadMargin
//             zoomFactor: root.zoomFactor
//             horizontalOffset: root.horizontalOffset
//             contentWidth: root.contentWidth
//             fps: root.projectFps
//             z: 250
//         }
//
//         // Main Timeline Content Area
//         Item {
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//
//             // State A: When Tracks Exist
//             // RowLayout {
//             Item {
//                 anchors.fill: parent
//                 // spacing: 0
//                 visible: root.trackCount > 0
//
//                 // Left Column: Scrollable Track Headers & Shelves
//                 Item {
//                     x: 0
//                     width: root.headerWidth
//                     height: parent.height
//                     // Layout.preferredWidth: root.headerWidth
//                     // Layout.fillHeight: true
//                     clip: true
//
//                     // Forward Wheel Scrolling on Header to Main Vertical Scroll
//                     WheelHandler {
//                         target: null
//                         acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
//                         onWheel: event => {
//                             var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
//                             var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
//                             trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, trackScrollArea.contentY - pDeltaY));
//                         }
//                     }
//
//                     Item {
//                         id: headerContentItem
//                         width: parent.width
//                         y: -trackScrollArea.contentY
//                         height: root.totalTracksHeight
//
//                         // Top + Video Button Shelf (scrolls out of view when scrolling down)
//                         Rectangle {
//                             id: topVideoShelf
//                             width: parent.width
//                             height: root.topShelfHeight
//                             y: 0
//                             color: topVideoMouse.containsMouse ? "#222222" : "#181818"
//                             border.color: topVideoMouse.containsMouse ? "#3b82f6" : root.borderDark
//                             border.width: 1
//
//                             Behavior on color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//                             Behavior on border.color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//
//                             MouseArea {
//                                 id: topVideoMouse
//                                 anchors.fill: parent
//                                 hoverEnabled: true
//                                 cursorShape: Qt.PointingHandCursor
//                                 onClicked: {
//                                     root.pendingNewTrackKind = 0;
//                                     addTrackModal.open();
//                                 }
//
//                                 Row {
//                                     anchors.centerIn: parent
//                                     spacing: 6
//
//                                     Image {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         width: 14
//                                         height: 14
//                                         source: "qrc:/assets/icons/plus.svg"
//                                         opacity: topVideoMouse.containsMouse ? 1.0 : 0.6
//                                     }
//
//                                     Text {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         text: "Add Video Track"
//                                         color: topVideoMouse.containsMouse ? "#ffffff" : "#888888"
//                                         font.pixelSize: 11
//                                         font.bold: true
//                                     }
//                                 }
//                             }
//                         }
//
//                         // Track Headers Column
//                         Column {
//                             id: trackHeaderColumn
//                             width: parent.width
//                             y: root.topShelfHeight
//
//                             Repeater {
//                                 model: root.activeTimelineModel
//
//                                 XylaTrackHeader {
//                                     width: root.headerWidth
//                                     trackId: model.trackId || ""
//                                     trackName: model.trackName || ""
//                                     trackKind: model.trackKind !== undefined ? model.trackKind : 0
//
//                                     onImplicitHeightChanged: root.updateTrackMetrics()
//                                     onTrackHeightChanged: root.updateTrackMetrics()
//                                     Component.onCompleted: root.updateTrackMetrics()
//                                 }
//                             }
//                         }
//
//                         Rectangle {
//                             id: bottomAudioShelf
//                             width: parent.width
//                             height: root.bottomShelfHeight
//                             y: root.totalTracksHeight - root.bottomShelfHeight
//                             color: bottomAudioMouse.containsMouse ? "#222222" : "#181818"
//                             border.color: bottomAudioMouse.containsMouse ? "#3b82f6" : root.borderDark
//                             border.width: 1
//
//                             Behavior on color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//                             Behavior on border.color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//
//                             MouseArea {
//                                 id: bottomAudioMouse
//                                 anchors.fill: parent
//                                 hoverEnabled: true
//                                 cursorShape: Qt.PointingHandCursor
//                                 onClicked: {
//                                     root.pendingNewTrackKind = 1;
//                                     addTrackModal.open();
//                                 }
//
//                                 Row {
//                                     anchors.centerIn: parent
//                                     spacing: 6
//
//                                     Image {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         width: 14
//                                         height: 14
//                                         source: "qrc:/assets/icons/plus.svg"
//                                         opacity: bottomAudioMouse.containsMouse ? 1.0 : 0.6
//                                     }
//
//                                     Text {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         text: "Add Audio Track"
//                                         color: bottomAudioMouse.containsMouse ? "#ffffff" : "#888888"
//                                         font.pixelSize: 11
//                                         font.bold: true
//                                     }
//                                 }
//                             }
//                         }
//                     }
//                 }
//
//                 // ADDED: Intermediate palette indicator strip between track headers and clip canvas
//                 Item {
//                     id: paletteStripContainer
//                     // Layout.preferredWidth: root.paletteStripWidth
//                     // Layout.fillHeight: true
//                     x: root.headerWidth
//                     width: root.paletteStripWidth
//                     height: parent.height
//                     clip: true
//                     z: 5
//
//                     Item {
//                         id: paletteContentItem
//                         width: parent.width
//                         y: -trackScrollArea.contentY
//                         height: root.totalTracksHeight
//
//                         // Top empty space shelf alignment
//                         Rectangle {
//                             width: parent.width
//                             height: root.topShelfHeight
//                             color: "#181818"
//                             // border.color: root.borderDark
//                             // border.width: 1
//                         }
//
//                         // Track Palettes Repeater
//                         Column {
//                             y: root.topShelfHeight
//                             width: parent.width
//
//                             Repeater {
//                                 model: root.trackCount
//
//                                 Rectangle {
//                                     width: paletteStripContainer.width
//                                     height: root.getTrackHeight(index)
//                                     color: "#181818"
//
//                                     // ADDED: Track status indicator palette that highlights when playhead is over a clip in this track
//                                     Rectangle {
//                                         id: paletteIndicator
//                                         property bool isHighlighted: root.isPlayheadOnClipInTrack(index)
//                                         anchors.centerIn: parent
//                                         width: 4
//                                         height: parent.height - 8
//                                         radius: 2
//                                         color: isHighlighted ? "#3b82f6" : "#2d2d2d"
//
//                                         Behavior on color {
//                                             ColorAnimation {
//                                                 duration: 120
//                                             }
//                                         }
//
//                                         // Glow/Shadow effect on active highlight
//                                         Rectangle {
//                                             anchors.fill: parent
//                                             radius: parent.radius
//                                             color: "#3b82f6"
//                                             opacity: paletteIndicator.isHighlighted ? 0.6 : 0.0
//                                             z: -1
//
//                                             Behavior on opacity {
//                                                 NumberAnimation {
//                                                     duration: 120
//                                                 }
//                                             }
//                                         }
//                                     }
//
//                                     // Rectangle {
//                                     //     anchors.left: parent.left
//                                     //     anchors.right: parent.right
//                                     //     anchors.bottom: parent.bottom
//                                     //     height: 1
//                                     //     color: root.borderDark
//                                     // }
//                                 }
//                             }
//                         }
//
//                         // Bottom empty space shelf alignment
//                         Rectangle {
//                             width: parent.width
//                             height: root.bottomShelfHeight
//                             y: root.totalTracksHeight - root.bottomShelfHeight
//                             color: "#181818"
//                             // border.color: root.borderDark
//                             // border.width: 1
//                         }
//                     }
//                 }
//
//                 // Full-height divider — sits exactly at the boundary between the
//                 // indicator column and the clips view. Not offset by playheadMargin;
//                 // that margin only affects content *inside* trackScrollArea.
//                 Rectangle {
//                     x: root.headerWidth + root.paletteStripWidth
//                     y: 0
//                     width: 1
//                     height: parent.height
//                     color: root.borderDark
//                     z: 10
//                 }
//
//                 // Right Side: Unified 2D Timeline Canvas
//                 Item {
//                     x: root.headerWidth + root.paletteStripWidth
//                     width: parent.width - x
//                     height: parent.height
//                     // Layout.fillWidth: true
//                     // Layout.fillHeight: true
//
//                     // ADDED: Border added to the left side of the main clip container view
//                     // Rectangle {
//                     //     id: clipContainerLeftBorder
//                     //     // Anchor to trackScrollArea instead of parent!
//                     //     anchors.left: anchorLeft.left
//                     //     anchors.top: parent.top
//                     //     anchors.bottom: parent.bottom
//                     //     width: 1
//                     //     color: root.borderDark
//                     //     z: 100
//                     // }
//                     //
//                     // Flickable {
//                     //     id: trackScrollArea
//                     //     anchors.fill: parent
//                     //     clip: true
//                     //     boundsBehavior: Flickable.StopAtBounds
//                     //     contentWidth: root.contentWidth + root.playheadMargin
//                     //     contentHeight: root.totalTracksHeight
//                     //     interactive: false
//                     //
//                     //     // Explicit Dark Backdrop prevents white canvas leaks
//                     //     Rectangle {
//                     //         anchors.fill: parent
//                     //         color: "#121212"
//                     //         z: 0
//                     //     }
//                     //
//                     //     DragHandler {
// Flickable {
//     id: trackScrollArea
//     anchors.fill: parent
//     clip: true
//     boundsBehavior: Flickable.StopAtBounds
//     contentWidth: root.contentWidth + root.playheadMargin
//     contentHeight: root.totalTracksHeight
//     interactive: false
//
//     // Explicit Dark Backdrop prevents white canvas leaks
//     Rectangle {
//         anchors.fill: parent
//         color: "#121212"
//         z: 0
//     }
//
//     // Fill the playhead-margin dead zone with the indicator column's
//     // color so it visually merges with paletteStripContainer instead
//     // of reading as a gap.
//     Rectangle {
//         anchors.left: parent.left
//         anchors.top: parent.top
//         anchors.bottom: parent.bottom
//         width: root.playheadMargin
//         color: "#181818"
//         z: 1
//     }
//
//     DragHandler {
//                             id: middleDragHandler
//                             target: null
//                             acceptedButtons: Qt.MiddleButton
//                             property real startHorizOffset: 0
//                             property real startContentY: 0
//
//                             onActiveChanged: {
//                                 root.isMiddlePanning = active;
//                                 if (active) {
//                                     startHorizOffset = root.horizontalOffset;
//                                     startContentY = trackScrollArea.contentY;
//                                 }
//                             }
//
//                             onTranslationChanged: {
//                                 if (active) {
//                                     var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
//                                     var newOffset = Math.max(0, Math.min(maxOffset, startHorizOffset - translation.x));
//                                     if (root.activeTimelineModel) {
//                                         root.activeTimelineModel.horizontalOffset = newOffset;
//                                     }
//
//                                     var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
//                                     trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, startContentY - translation.y));
//                                 }
//                             }
//                         }
//
//                         // Handles both vertical timeline scroll AND Ctrl+Zoom AND Horizontal Scrolling
//                         WheelHandler {
//                             id: wheelHandler
//                             target: null
//                             acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
//                             onWheel: event => {
//                                 var cursorX = event.point?.position?.x ?? wheelHandler.point?.position?.x ?? (trackScrollArea.width / 2);
//
//                                 if (event.modifiers & Qt.ControlModifier) {
//                                     var factor = event.angleDelta.y > 0 ? 1.35 : 0.74;
//                                     // MODIFIED: Updated cursor X coordinate calculation including paletteStripWidth
//                                     root.applyZoom(factor, cursorX + root.headerWidth + root.paletteStripWidth);
//                                     return;
//                                 }
//
//                                 var pDeltaX = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x;
//                                 var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
//
//                                 // MODIFIED: Fixed horizontal scrolling detection to correctly respond to standard mouse wheel/trackpad horizontal events and Shift key modifier
//                                 var isHorizontal = (Math.abs(pDeltaX) > Math.abs(pDeltaY)) || (event.modifiers & Qt.ShiftModifier);
//
//                                 if (isHorizontal) {
//                                     // MODIFIED: Ensure proper delta sign handling across touchpad and traditional mouse scroll wheels
//                                     var deltaX = (pDeltaX !== 0) ? -pDeltaX : -pDeltaY;
//                                     var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
//                                     var newOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaX));
//                                     if (root.activeTimelineModel) {
//                                         root.activeTimelineModel.horizontalOffset = newOffset;
//                                     }
//                                 } else {
//                                     var deltaY = -pDeltaY;
//                                     var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
//                                     trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, trackScrollArea.contentY + deltaY));
//                                 }
//                             }
//                         }
//
//                         Item {
//                             id: timelineCanvasViewport
//                             x: root.playheadMargin - root.horizontalOffset
//                             width: root.contentWidth
//                             height: trackScrollArea.contentHeight
//
//                             Rectangle {
//                                 width: 4 // timelineCanvasViewport.width
//                                 height: parent.height // root.bottomShelfHeight
//                                 // y: root.totalTracksHeight - root.bottomShelfHeight
//                                 color: "#FFFFF6"
//                                 border.color: "#FFF" // root.borderDark
//                                 border.width: 1
//                             }
//                             // 1. Top & Bottom Background Shelf Strips
//                             Rectangle {
//                                 id: anchorLeft
//                                 width: timelineCanvasViewport.width
//                                 height: root.topShelfHeight
//                                 y: 0
//                                 color: "#161616"
//                                 border.color: root.borderDark
//                                 border.width: 1
//                             }
//
//                             Rectangle {
//                                 width: timelineCanvasViewport.width
//                                 height: root.bottomShelfHeight
//                                 y: root.totalTracksHeight - root.bottomShelfHeight
//                                 color: "#161616"
//                                 border.color: root.borderDark
//                                 border.width: 1
//                             }
//
//                             // 2. Dynamic Background Track Stripes (Neutral Gray Differentiation)
//                             Column {
//                                 y: root.topShelfHeight
//                                 width: timelineCanvasViewport.width
//
//                                 Repeater {
//                                     model: root.trackCount
//                                     Rectangle {
//                                         width: timelineCanvasViewport.width
//                                         height: root.getTrackHeight(index)
//                                         color: root.getTrackBgColor(index)
//
//                                         Rectangle {
//                                             anchors.left: parent.left
//                                             anchors.right: parent.right
//                                             anchors.bottom: parent.bottom
//                                             height: 1
//                                             color: root.borderDark
//                                         }
//                                     }
//                                 }
//                             }
//
//                             // 3. Empty Space Marquee Selection Area
//                             MouseArea {
//                                 anchors.fill: parent
//                                 z: 1
//                                 acceptedButtons: Qt.LeftButton | Qt.RightButton
//
//                                 property real startGlobalX: 0
//                                 property real startGlobalY: 0
//                                 property real startCanvasX: 0
//                                 property real startCanvasY: 0
//                                 property bool isMarquee: false
//
//                                 onPressed: function (mouse) {
//                                     if (mouse.button === Qt.RightButton)
//                                         return;
//
//                                     var globalPt = mapToItem(root, mouse.x, mouse.y);
//                                     startGlobalX = globalPt.x;
//                                     startGlobalY = globalPt.y;
//                                     startCanvasX = mouse.x;
//                                     startCanvasY = mouse.y;
//                                     isMarquee = false;
//                                 }
//
//                                 onPositionChanged: function (mouse) {
//                                     if (mouse.buttons & Qt.RightButton)
//                                         return;
//
//                                     var globalPt = mapToItem(root, mouse.x, mouse.y);
//                                     var dx = globalPt.x - startGlobalX;
//                                     var dy = globalPt.y - startGlobalY;
//
//                                     if (!isMarquee && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
//                                         isMarquee = true;
//                                         if (root.activeTimelineModel) {
//                                             root.activeTimelineModel.startSelectionBatch();
//                                         }
//                                     }
//
//                                     if (isMarquee) {
//                                         var x1 = Math.min(startGlobalX, globalPt.x);
//                                         var x2 = Math.max(startGlobalX, globalPt.x);
//                                         var y1 = Math.min(startGlobalY, globalPt.y);
//                                         var y2 = Math.max(startGlobalY, globalPt.y);
//
//                                         marqueeRect.x = x1;
//                                         marqueeRect.y = y1;
//                                         marqueeRect.width = x2 - x1;
//                                         marqueeRect.height = y2 - y1;
//                                         marqueeRect.visible = true;
//
//                                         var canvasX1 = Math.min(startCanvasX, mouse.x);
//                                         var canvasX2 = Math.max(startCanvasX, mouse.x);
//                                         var canvasY1 = Math.min(startCanvasY, mouse.y);
//                                         var canvasY2 = Math.max(startCanvasY, mouse.y);
//
//                                         var startF = root.pxToFrame(canvasX1);
//                                         var endF = root.pxToFrame(canvasX2);
//                                         var startT = root.getTrackAtY(canvasY1);
//                                         var endT = root.getTrackAtY(canvasY2);
//
//                                         var isToggle = (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier));
//                                         if (root.activeTimelineModel) {
//                                             root.activeTimelineModel.selectBox(startF, endF, startT, endT, isToggle);
//                                         }
//                                     }
//                                 }
//
//                                 onReleased: function (mouse) {
//                                     if (mouse.button === Qt.RightButton) {
//                                         var overlayPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
//                                         var targetF = root.pxToFrame(mouse.x);
//                                         var targetT = root.getTrackAtY(mouse.y);
//                                         root.openContextMenu(overlayPt.x, overlayPt.y, targetF, targetT, null);
//                                         return;
//                                     }
//
//                                     if (isMarquee) {
//                                         if (root.activeTimelineModel) {
//                                             root.activeTimelineModel.commitSelectionBatch();
//                                         }
//                                         isMarquee = false;
//                                         marqueeRect.visible = false;
//                                     } else if (root.activeTimelineModel) {
//                                         root.activeTimelineModel.clearSelection();
//                                     }
//                                 }
//                             }
//
//                             // 4. Drop Area for Files
//                             DropArea {
//                                 anchors.fill: parent
//                                 keys: ["xyla/media-asset", "text/uri-list"]
//                                 z: 2
//
//                                 onEntered: drag => drag.accept(Qt.CopyAction)
//                                 onPositionChanged: drag => drag.accept(Qt.CopyAction)
//
//                                 onDropped: function (drop) {
//                                     drop.accept(Qt.CopyAction);
//                                     if (!root.activeTimelineModel)
//                                         return;
//                                     var rawUrl = "";
//                                     if (drop.hasUrls && drop.urls && drop.urls.length > 0) {
//                                         rawUrl = drop.urls[0].toString();
//                                     } else if (drop.formats && drop.formats.indexOf("text/uri-list") !== -1) {
//                                         rawUrl = drop.getDataAsString("text/uri-list").trim();
//                                     }
//
//                                     if (!rawUrl || rawUrl.length === 0)
//                                         return;
//                                     var assetName = rawUrl.substring(rawUrl.lastIndexOf('/') + 1);
//                                     if (assetName.length === 0)
//                                         assetName = "Clip";
//
//                                     var realAssetId = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetId(rawUrl) : rawUrl;
//                                     var dropFrame = root.pxToFrame(drop.x);
//                                     var dropTrack = root.getTrackAtY(drop.y);
//                                     var assetDuration = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetDurationFrames(realAssetId, root.projectFps) : 150;
//
//                                     root.activeTimelineModel.addClip(realAssetId, assetName, dropTrack, dropFrame, assetDuration, 0);
//                                     root.updateContentWidth();
//                                 }
//                             }
//
//                             // 5. Unified 2D Clips Layer
//                             Item {
//                                 id: unifiedClipsLayer
//                                 anchors.fill: parent
//                                 z: 10
//
//                                 Connections {
//                                     target: root.activeTimelineModel ? root.activeTimelineModel : null
//                                     function onTrackDataChanged(trackIndex) {
//                                         clipRepeater.refreshAllClips();
//                                         root.updateContentWidth();
//                                         root.updateTrackMetrics();
//                                     }
//                                     function onTrackCountChanged() {
//                                         clipRepeater.refreshAllClips();
//                                         root.updateContentWidth();
//                                         root.updateTrackMetrics();
//                                     }
//                                     function onClipPropertiesChanged(clipId) {
//                                         clipRepeater.refreshAllClips();
//                                     }
//                                     function onDataChanged(topLeft, bottomRight, roles) {
//                                         clipRepeater.refreshAllClips();
//                                     }
//                                 }
//
//                                 Repeater {
//                                     id: clipRepeater
//                                     model: []
//
//                                     function refreshAllClips() {
//                                         if (root.activeTimelineModel) {
//                                             model = root.activeTimelineModel.getAllClips();
//                                         } else {
//                                             model = [];
//                                         }
//                                     }
//
//                                     Component.onCompleted: refreshAllClips()
//
//                                     XylaClipCard {
//                                         timelineRoot: root
//                                         clipData: modelData
//                                         zoomFactor: root.zoomFactor
//                                     }
//                                 }
//                             }
//
//                             // 6. Visual Snapping & Figma Spacing Guides Layer
//                             Item {
//                                 id: snapGuideLayer
//                                 anchors.fill: parent
//                                 z: 500
//
//                                 Rectangle {
//                                     id: snapLine
//                                     visible: root.isSnapLineVisible && root.snapGuideFrame >= 0
//                                     x: Math.round(root.snapGuideFrame * root.zoomFactor)
//                                     width: 1
//                                     height: parent.height
//                                     color: "#2563eb"
//                                     opacity: 0.8
//                                     z: 150
//
//                                     Rectangle {
//                                         anchors.top: parent.top
//                                         anchors.horizontalCenter: parent.horizontalCenter
//                                         width: 3
//                                         height: 3
//                                         radius: 1.5
//                                         color: "#3b82f6"
//                                     }
//                                 }
//
//                                 Item {
//                                     id: spacingGuide
//                                     visible: root.activeSpacingGaps.length > 0
//                                     anchors.fill: parent
//                                     z: 140
//
//                                     Repeater {
//                                         model: root.activeSpacingGaps
//
//                                         Rectangle {
//                                             id: gapRect
//                                             readonly property bool isActive: modelData.isActive === true
//                                             x: Math.round(Number(modelData.start) * root.zoomFactor)
//                                             width: Math.max(1, Math.round((Number(modelData.end) - Number(modelData.start)) * root.zoomFactor))
//                                             height: parent.height
//                                             color: isActive ? Qt.rgba(0.145, 0.388, 0.922, 0.18) : Qt.rgba(0.145, 0.388, 0.922, 0.10)
//                                             border.color: isActive ? "#3b82f6" : "#2563eb"
//                                             border.width: 1
//
//                                             Rectangle {
//                                                 anchors.centerIn: parent
//                                                 width: gapBadgeText.implicitWidth + 10
//                                                 height: 18
//                                                 color: gapRect.isActive ? "#2563eb" : "#1d4ed8"
//                                                 radius: 4
//                                                 border.color: gapRect.isActive ? "#60a5fa" : "#3b82f6"
//                                                 border.width: 1
//
//                                                 Text {
//                                                     id: gapBadgeText
//                                                     anchors.centerIn: parent
//                                                     text: (modelData.gapFrames !== undefined ? modelData.gapFrames : "") + "f"
//                                                     color: "#ffffff"
//                                                     font.pixelSize: 10
//                                                     font.bold: true
//                                                 }
//                                             }
//                                         }
//                                     }
//                                 }
//                             }
//                         }
//                     }
//                 }
//             }
//
//             // State B: When 0 Tracks Exist
//             Item {
//                 anchors.fill: parent
//                 visible: root.trackCount === 0
//
//                 ColumnLayout {
//                     anchors.centerIn: parent
//                     spacing: 14
//
//                     Image {
//                         Layout.alignment: Qt.AlignHCenter
//                         source: "qrc:/assets/icons/layers.svg"
//                         sourceSize: Qt.size(42, 42)
//                         opacity: 0.35
//                     }
//
//                     ColumnLayout {
//                         Layout.alignment: Qt.AlignHCenter
//                         spacing: 4
//
//                         Text {
//                             Layout.alignment: Qt.AlignHCenter
//                             text: "No Tracks in Timeline"
//                             color: "#ffffff"
//                             font.pixelSize: 15
//                             font.bold: true
//                         }
//
//                         Text {
//                             Layout.alignment: Qt.AlignHCenter
//                             text: "Initialize video and audio tracks to begin editing"
//                             color: "#888888"
//                             font.pixelSize: 12
//                         }
//                     }
//
//                     XylaTextButton {
//                         Layout.alignment: Qt.AlignHCenter
//                         text: "Create Tracks..."
//                         primary: true
//                         onClicked: createTracksModal.open()
//                     }
//                 }
//             }
//         }
//     }
//
//     // Playhead
//     Item {
//         // MODIFIED: Shifted playhead start position to account for paletteStripWidth
//         x: root.headerWidth + root.paletteStripWidth
//         y: topToolBar.height
//         width: parent.width - (root.headerWidth + root.paletteStripWidth)
//         height: parent.height - y
//         clip: true
//         z: 200
//         visible: root.trackCount > 0
//
//         XylaPlayhead {
//             id: mainPlayhead
//             timelineRoot: root
//             activeTimelineModel: root.activeTimelineModel
//             currentFrame: root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0
//             zoomFactor: root.zoomFactor
//             horizontalOffset: root.horizontalOffset
//             playheadMargin: root.playheadMargin
//             headerWidth: root.headerWidth + root.paletteStripWidth
//             height: parent.height
//         }
//     }
//
//     // Sidebar Resizer
//     Item {
//         id: sidebarResizer
//         width: 8
//         x: root.headerWidth - 4
//         y: topToolBar.height
//         height: parent.height - y
//         z: 350
//         visible: root.trackCount > 0
//
//         Rectangle {
//             anchors.centerIn: parent
//             width: resizerMouse.containsMouse || resizerMouse.pressed ? 2 : 1
//             height: parent.height
//             color: resizerMouse.containsMouse || resizerMouse.pressed ? "#2555D3" : "#2d2d2d"
//
//             Behavior on width {
//                 NumberAnimation {
//                     duration: 80
//                 }
//             }
//         }
//
//         MouseArea {
//             id: resizerMouse
//             anchors.fill: parent
//             hoverEnabled: true
//             cursorShape: Qt.SizeHorCursor
//             preventStealing: true
//
//             property int startMouseX: 0
//             property int startWidth: 0
//
//             onPressed: function (mouse) {
//                 var pt = mapToItem(root, mouse.x, mouse.y);
//                 startMouseX = pt.x;
//                 startWidth = root.headerWidth;
//             }
//
//             onPositionChanged: function (mouse) {
//                 if (pressed) {
//                     var pt = mapToItem(root, mouse.x, mouse.y);
//                     var deltaX = pt.x - startMouseX;
//                     var newW = Math.max(root.minHeaderWidth, Math.min(root.maxHeaderWidth, startWidth + deltaX));
//                     root.headerWidth = newW;
//                 }
//             }
//         }
//     }
//
//     // Context Menu
//     XylaTimelineContextMenu {
//         id: timelineContextMenu
//         timelineRoot: root
//         timelineModel: root.activeTimelineModel
//         playbackManager: root.activePlaybackManager
//
//         onDeleteRequested: {
//             if (root.activeTimelineModel) {
//                 root.activeTimelineModel.deleteSelectedClips();
//                 root.updateContentWidth();
//             }
//         }
//
//         onRippleDeleteRequested: {
//             if (root.activeTimelineModel) {
//                 root.activeTimelineModel.deleteSelectedClips();
//                 root.updateContentWidth();
//             }
//         }
//
//         onSplitRequested: function (frame, track) {
//             if (root.activeTimelineModel && root.activePlaybackManager) {
//                 root.activeTimelineModel.cutAtPlayhead(root.activePlaybackManager.currentFrame);
//                 root.updateContentWidth();
//             }
//         }
//
//         onSelectAllRequested: {
//             if (root.activeTimelineModel) {
//                 var all = root.activeTimelineModel.getAllClips();
//                 var ids = [];
//                 for (var i = 0; i < all.length; ++i) {
//                     ids.push(all[i].clipId);
//                 }
//                 root.activeTimelineModel.applyDirectSelection(ids);
//             }
//         }
//     }
//
//     // Modal: Confirm Add Track
//     Popup {
//         id: addTrackModal
//         parent: Overlay.overlay
//         anchors.centerIn: parent
//         width: 320
//         padding: 16
//         modal: true
//         focus: true
//         closePolicy: Popup.CloseOnEscape
//
//         background: Rectangle {
//             color: "#181818"
//             border.color: "#303030"
//             border.width: 1
//             radius: 12
//
//             layer.enabled: true
//             layer.effect: MultiEffect {
//                 shadowEnabled: true
//                 shadowColor: "#90000000"
//                 shadowBlur: 0.75
//                 shadowVerticalOffset: 8
//             }
//         }
//
//         contentItem: ColumnLayout {
//             spacing: 14
//
//             ColumnLayout {
//                 spacing: 4
//                 Text {
//                     text: root.pendingNewTrackKind === 0 ? "Add Video Track" : "Add Audio Track"
//                     color: "#ffffff"
//                     font.pixelSize: 14
//                     font.bold: true
//                 }
//                 Text {
//                     text: root.pendingNewTrackKind === 0 ? "Insert a new video track into the timeline?" : "Append a new audio track into the timeline?"
//                     color: "#888888"
//                     font.pixelSize: 11
//                     wrapMode: Text.WordWrap
//                     Layout.fillWidth: true
//                 }
//             }
//
//             Rectangle {
//                 Layout.fillWidth: true
//                 height: 1
//                 color: "#282828"
//             }
//
//             RowLayout {
//                 Layout.fillWidth: true
//                 spacing: 8
//                 layoutDirection: Qt.RightToLeft
//
//                 XylaTextButton {
//                     text: "Add Track"
//                     primary: true
//                     onClicked: {
//                         if (root.activeTimelineModel) {
//                             if (root.pendingNewTrackKind === 0) {
//                                 if (root.activeTimelineModel.addVideoTrack) {
//                                     root.activeTimelineModel.addVideoTrack();
//                                 }
//                             } else {
//                                 if (root.activeTimelineModel.addAudioTrack) {
//                                     root.activeTimelineModel.addAudioTrack();
//                                 }
//                             }
//                             root.updateTrackMetrics();
//                             root.updateContentWidth();
//                         }
//                         addTrackModal.close();
//                     }
//                 }
//
//                 XylaTextButton {
//                     text: "Cancel"
//                     outline: true
//                     onClicked: addTrackModal.close()
//                 }
//             }
//         }
//     }
//
//     // Modal: Initialize Timeline Tracks Dialog
//     Popup {
//         id: createTracksModal
//         parent: Overlay.overlay
//         anchors.centerIn: parent
//         width: 320
//         padding: 16
//         modal: true
//         focus: true
//         closePolicy: Popup.CloseOnEscape
//
//         background: Rectangle {
//             color: "#181818"
//             border.color: "#303030"
//             border.width: 1
//             radius: 12
//
//             layer.enabled: true
//             layer.effect: MultiEffect {
//                 shadowEnabled: true
//                 shadowColor: "#90000000"
//                 shadowBlur: 0.75
//                 shadowVerticalOffset: 8
//                 shadowHorizontalOffset: 0
//             }
//         }
//
//         enter: Transition {
//             NumberAnimation {
//                 property: "opacity"
//                 from: 0.0
//                 to: 1.0
//                 duration: 150
//                 easing.type: Easing.OutCubic
//             }
//             NumberAnimation {
//                 property: "scale"
//                 from: 0.95
//                 to: 1.0
//                 duration: 180
//                 easing.type: Easing.OutCubic
//             }
//         }
//
//         exit: Transition {
//             NumberAnimation {
//                 property: "opacity"
//                 from: 1.0
//                 to: 0.0
//                 duration: 120
//                 easing.type: Easing.OutCubic
//             }
//             NumberAnimation {
//                 property: "scale"
//                 from: 1.0
//                 to: 0.95
//                 duration: 120
//                 easing.type: Easing.OutCubic
//             }
//         }
//
//         contentItem: ColumnLayout {
//             spacing: 16
//
//             ColumnLayout {
//                 spacing: 4
//                 Text {
//                     text: "Create Timeline Tracks"
//                     color: "#ffffff"
//                     font.pixelSize: 14
//                     font.bold: true
//                 }
//                 Text {
//                     text: "Select initial number of video and audio tracks"
//                     color: "#888888"
//                     font.pixelSize: 11
//                 }
//             }
//
//             Rectangle {
//                 Layout.fillWidth: true
//                 height: 1
//                 color: "#282828"
//             }
//
//             ColumnLayout {
//                 Layout.fillWidth: true
//                 spacing: 10
//
//                 RowLayout {
//                     Layout.fillWidth: true
//                     spacing: 10
//
//                     Text {
//                         text: "Video Tracks"
//                         color: "#cccccc"
//                         font.pixelSize: 12
//                         Layout.fillWidth: true
//                     }
//
//                     XylaFloatInput {
//                         id: videoTrackInput
//                         value: 2
//                         minValue: 0
//                         maxValue: 32
//                         stepSize: 1.0
//                         decimals: 0
//                         Layout.preferredWidth: 80
//                     }
//                 }
//
//                 RowLayout {
//                     Layout.fillWidth: true
//                     spacing: 10
//
//                     Text {
//                         text: "Audio Tracks"
//                         color: "#cccccc"
//                         font.pixelSize: 12
//                         Layout.fillWidth: true
//                     }
//
//                     XylaFloatInput {
//                         id: audioTrackInput
//                         value: 2
//                         minValue: 0
//                         maxValue: 32
//                         stepSize: 1.0
//                         decimals: 0
//                         Layout.preferredWidth: 80
//                     }
//                 }
//             }
//
//             Rectangle {
//                 Layout.fillWidth: true
//                 height: 1
//                 color: "#282828"
//             }
//
//             RowLayout {
//                 Layout.fillWidth: true
//                 spacing: 8
//                 layoutDirection: Qt.RightToLeft
//
//                 XylaTextButton {
//                     text: "Create"
//                     primary: true
//                     onClicked: {
//                         var vCount = Math.max(0, Math.round(videoTrackInput.value));
//                         var aCount = Math.max(0, Math.round(audioTrackInput.value));
//
//                         if (root.activeTimelineModel) {
//                             root.activeTimelineModel.createDefaultTracks(vCount, aCount);
//                             root.updateTrackMetrics();
//                             root.updateContentWidth();
//                         }
//                         createTracksModal.close();
//                     }
//                 }
//
//                 XylaTextButton {
//                     text: "Cancel"
//                     outline: true
//                     onClicked: createTracksModal.close()
//                 }
//             }
//         }
//     }
// }








// import QtQuick
// import QtQuick.Controls
// import QtQuick.Layouts
// import QtQuick.Effects
// import Xyla 1.0
// import "../components"
// import "./timeline"
//
// Item {
//     id: root
//
//     property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
//     property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null
//     property var activeProjectManager: typeof projectManager !== "undefined" ? projectManager : null
//     property var activeProject: activeProjectManager?.activeProject ?? null
//     property var activeShortcutManager: typeof shortcutManager !== "undefined" ? shortcutManager : null
//
//     readonly property int trackCount: activeTimelineModel ? activeTimelineModel.trackCount : 0
//     readonly property int playheadFrame: activePlaybackManager ? activePlaybackManager.currentFrame : 0
//
//     property double zoomFactor: activeTimelineModel ? activeTimelineModel.zoomFactor : 1.0
//     property real horizontalOffset: activeTimelineModel ? activeTimelineModel.horizontalOffset : 0.0
//     property real contentWidth: 3600
//
//     readonly property real projectFps: {
//         if (!activeProject)
//             return 30.0;
//         if (typeof activeProject.fps === "number" && activeProject.fps > 0) {
//             return activeProject.fps;
//         }
//         if (activeProject.fpsNumerator && activeProject.fpsDenominator) {
//             return activeProject.fpsNumerator / activeProject.fpsDenominator;
//         }
//         return 30.0;
//     }
//
//     property int headerWidth: 220
//     property int minHeaderWidth: 220
//     property int maxHeaderWidth: 600
//
//     readonly property color bgDark: "#141414"
//     readonly property color bgHeader: "#181818"
//     readonly property color borderDark: "#2d2d2d"
//     readonly property real playheadMargin: 10.0
//
//     // Neutral Gray Tones (Zero blue/tint)
//     readonly property color videoTrackBg: "#141414"
//     readonly property color audioTrackBg: "#222222"
//
//     function getTrackBgColor(trackIdx) {
//         if (!root.activeTimelineModel)
//             return root.videoTrackBg;
//         var kind = root.activeTimelineModel.getTrackKind(trackIdx);
//         return (kind === 1) ? root.audioTrackBg : root.videoTrackBg;
//     }
//
//     property bool isMiddlePanning: false
//
//     readonly property real topShelfHeight: 36
//     readonly property real bottomShelfHeight: 36
//
//     property var trackHeights: []
//     property var trackOffsets: []
//     property real totalTracksHeight: 200
//
//     property real snapGuideFrame: -1
//     property bool isSnapLineVisible: false
//     property var activeSpacingGaps: []
//
//     property int pendingNewTrackKind: 0
//
//     function showSnapLine(frame) {
//         snapGuideFrame = frame;
//         isSnapLineVisible = (frame >= 0);
//         activeSpacingGaps = [];
//     }
//
//     function showSpacingGuides(gapsList) {
//         if (gapsList && gapsList.length > 0) {
//             activeSpacingGaps = gapsList;
//         } else {
//             activeSpacingGaps = [];
//         }
//     }
//
//     function hideSnapGuides() {
//         isSnapLineVisible = false;
//         snapGuideFrame = -1;
//         activeSpacingGaps = [];
//     }
//
//     function updateTrackMetrics() {
//         var count = root.trackCount;
//         var heights = [];
//         var offsets = [];
//         var cumY = topShelfHeight; // Starts after the top + button shelf
//
//         for (var i = 0; i < count; ++i) {
//             var item = trackHeaderColumn.children[i];
//             var h = (item && item.implicitHeight) ? item.implicitHeight : (trackHeights[i] ?? 68);
//             heights.push(h);
//             offsets.push(cumY);
//             cumY += h;
//         }
//         trackHeights = heights;
//         trackOffsets = offsets;
//         totalTracksHeight = cumY + bottomShelfHeight;
//     }
//
//     function getTrackY(t) {
//         if (t < 0 || !trackOffsets || t >= trackOffsets.length)
//             return topShelfHeight + (t * 68);
//         return trackOffsets[t];
//     }
//
//     function getTrackHeight(t) {
//         if (t < 0 || !trackHeights || t >= trackHeights.length)
//             return 68;
//         return trackHeights[t];
//     }
//
//     function getTrackAtY(canvasY) {
//         if (!trackOffsets || trackOffsets.length === 0)
//             return 0;
//         for (var i = trackOffsets.length - 1; i >= 0; --i) {
//             if (canvasY >= trackOffsets[i])
//                 return i;
//         }
//         return 0;
//     }
//
//     function updateContentWidth() {
//         if (!root.activeTimelineModel)
//             return;
//         var maxFrame = 0;
//         var all = root.activeTimelineModel.getAllClips();
//         for (var i = 0; i < all.length; ++i) {
//             var endF = Number(all[i].startFrame) + Number(all[i].durationFrames);
//             if (endF > maxFrame)
//                 maxFrame = endF;
//         }
//         var requiredPx = (maxFrame * root.zoomFactor) + 1000;
//         root.contentWidth = Math.max(3600, requiredPx);
//     }
//
//     function applyZoom(factor, cursorScreenX) {
//         var visibleTimelineX = cursorScreenX - root.headerWidth - root.playheadMargin;
//         var frameAtAnchor = (visibleTimelineX + root.horizontalOffset) / root.zoomFactor;
//
//         var newZoom = Math.max(0.1, Math.min(10.0, root.zoomFactor * factor));
//         var newOffset = (frameAtAnchor * newZoom) - visibleTimelineX;
//         var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
//         var clampedOffset = Math.max(0, Math.min(maxOffset, newOffset));
//
//         if (root.activeTimelineModel) {
//             root.activeTimelineModel.zoomFactor = newZoom;
//             root.activeTimelineModel.horizontalOffset = clampedOffset;
//         }
//         root.updateContentWidth();
//     }
//
//     function frameToPx(frame) {
//         return root.playheadMargin + (frame * root.zoomFactor);
//     }
//
//     function pxToFrame(px) {
//         return Math.max(0, Math.round((px - root.playheadMargin) / root.zoomFactor));
//     }
//
//     function formatTimecode(frame) {
//         var fps = root.projectFps;
//         var totalSec = frame / fps;
//         var hrs = Math.floor(totalSec / 3600);
//         var mins = Math.floor((totalSec % 3600) / 60);
//         var secs = Math.floor(totalSec % 60);
//         var frames = Math.floor(frame % fps);
//
//         function pad(n) {
//             return n < 10 ? "0" + n : n;
//         }
//         return pad(hrs) + ":" + pad(mins) + ":" + pad(secs) + ":" + pad(frames);
//     }
//
//     function openContextMenu(screenX, screenY, frame, trackIdx, clipData) {
//         timelineContextMenu.openAt(screenX, screenY, frame, trackIdx, clipData);
//     }
//
//     Rectangle {
//         anchors.fill: parent
//         color: root.bgDark
//         z: -1
//     }
//
//     Rectangle {
//         id: marqueeRect
//         color: "#253B82F6"
//         border.color: "#3B82F6"
//         border.width: 1
//         visible: false
//         z: 400
//     }
//
//     ColumnLayout {
//         anchors.fill: parent
//         spacing: 0
//
//         // Toolbar
//         Rectangle {
//             id: topToolBar
//             color: "#191919"
//             Layout.fillWidth: true
//             height: 40
//
//             Rectangle {
//                 anchors.left: parent.left
//                 anchors.right: parent.right
//                 anchors.bottom: parent.bottom
//                 height: 1
//                 color: root.borderDark
//             }
//
//             RowLayout {
//                 anchors.left: parent.left
//                 anchors.right: centerControls.left
//                 anchors.verticalCenter: parent.verticalCenter
//                 anchors.leftMargin: 10
//                 anchors.rightMargin: 10
//                 spacing: 6
//             }
//
//             Row {
//                 id: centerControls
//                 anchors.centerIn: parent
//                 spacing: 6
//
//                 Rectangle {
//                     height: 32
//                     width: transportRow.implicitWidth
//                     color: "transparent"
//                     border.color: "#2d2d2d"
//                     border.width: 1
//                     radius: 6
//
//                     Row {
//                         id: transportRow
//                         anchors.verticalCenter: parent.verticalCenter
//
//                         XylaIconButton {
//                             roundLeft: true
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/player-track-prev.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.playFromStart()
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/player-skip-back.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.jumpBackwardSeconds(5.0)
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/chevron-left.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.stepBackward(1)
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             property bool isPlayingForward: root.activePlaybackManager && root.activePlaybackManager.isPlaying && !root.activePlaybackManager.isPlayingReverse
//                             roundLeft: false
//                             roundRight: false
//                             ghost: !isPlayingForward
//                             primary: isPlayingForward
//                             iconSource: isPlayingForward ? "qrc:/assets/icons/player-pause.svg" : "qrc:/assets/icons/player-play.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.togglePlay()
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             property bool isPlayingReverse: root.activePlaybackManager && root.activePlaybackManager.isPlaying && root.activePlaybackManager.isPlayingReverse
//                             roundLeft: false
//                             roundRight: false
//                             ghost: !isPlayingReverse
//                             primary: isPlayingReverse
//                             iconSource: "qrc:/assets/icons/player-play-reverse.svg"
//                             onClicked: {
//                                 if (!root.activePlaybackManager)
//                                     return;
//                                 if (isPlayingReverse)
//                                     root.activePlaybackManager.pause();
//                                 else
//                                     root.activePlaybackManager.playReverse();
//                             }
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: false
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/chevron-right.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.stepForward(1)
//                         }
//                         Rectangle {
//                             width: 1
//                             height: 32
//                             color: "#2d2d2d"
//                         }
//                         XylaIconButton {
//                             roundLeft: false
//                             roundRight: true
//                             ghost: true
//                             iconSource: "qrc:/assets/icons/player-skip-forward.svg"
//                             onClicked: if (root.activePlaybackManager)
//                                 root.activePlaybackManager.jumpForwardSeconds(5.0)
//                         }
//                     }
//                 }
//
//                 Rectangle {
//                     width: 100
//                     height: 32
//                     color: "transparent"
//                     border.color: "#2d2d2d"
//                     border.width: 1
//                     radius: 6
//
//                     Text {
//                         anchors.centerIn: parent
//                         text: root.formatTimecode(root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0)
//                         color: "#ffffff"
//                         font.pixelSize: 11
//                         font.bold: true
//                         font.family: "Monospace"
//                     }
//                 }
//             }
//
//             RowLayout {
//                 anchors.right: parent.right
//                 anchors.left: centerControls.right
//                 anchors.verticalCenter: parent.verticalCenter
//                 anchors.leftMargin: 10
//                 anchors.rightMargin: 10
//                 layoutDirection: Qt.RightToLeft
//                 spacing: 6
//
//                 XylaIconButton {
//                     id: rippleSettingsBtn
//                     ghost: true
//                     iconSource: "qrc:/assets/icons/settings.svg"
//                     Layout.preferredWidth: 28
//                     Layout.preferredHeight: 28
//                     tooltip: "Timeline Settings"
//                     onClicked: ripplePopup.open()
//
//                     XylaTimelineRippleSettingsPopup {
//                         id: ripplePopup
//                         x: rippleSettingsBtn.width - width
//                         y: rippleSettingsBtn.height + 6
//                         timelineModel: root.activeTimelineModel
//                     }
//                 }
//             }
//         }
//
//         XylaTimelineRuler {
//             id: timelineRuler
//             Layout.fillWidth: true
//             headerWidth: root.headerWidth + root.playheadMargin
//             zoomFactor: root.zoomFactor
//             horizontalOffset: root.horizontalOffset
//             contentWidth: root.contentWidth
//             fps: root.projectFps
//             z: 250
//         }
//
//         // Main Timeline Content Area
//         Item {
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//
//             // State A: When Tracks Exist
//             RowLayout {
//                 anchors.fill: parent
//                 spacing: 0
//                 visible: root.trackCount > 0
//
//                 // Left Column: Scrollable Track Headers & Shelves
//                 Item {
//                     Layout.preferredWidth: root.headerWidth
//                     Layout.fillHeight: true
//                     clip: true
//
//                     // Forward Wheel Scrolling on Header to Main Vertical Scroll
//                     WheelHandler {
//                         target: null
//                         acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
//                         onWheel: event => {
//                             var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
//                             var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
//                             trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, trackScrollArea.contentY - pDeltaY));
//                         }
//                     }
//
//                     Item {
//                         id: headerContentItem
//                         width: parent.width
//                         y: -trackScrollArea.contentY
//                         height: root.totalTracksHeight
//
//                         // Top + Video Button Shelf (scrolls out of view when scrolling down)
//                         Rectangle {
//                             id: topVideoShelf
//                             width: parent.width
//                             height: root.topShelfHeight
//                             y: 0
//                             color: topVideoMouse.containsMouse ? "#222222" : "#181818"
//                             border.color: topVideoMouse.containsMouse ? "#3b82f6" : root.borderDark
//                             border.width: 1
//
//                             Behavior on color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//                             Behavior on border.color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//
//                             MouseArea {
//                                 id: topVideoMouse
//                                 anchors.fill: parent
//                                 hoverEnabled: true
//                                 cursorShape: Qt.PointingHandCursor
//                                 onClicked: {
//                                     root.pendingNewTrackKind = 0;
//                                     addTrackModal.open();
//                                 }
//
//                                 Row {
//                                     anchors.centerIn: parent
//                                     spacing: 6
//
//                                     Image {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         width: 14
//                                         height: 14
//                                         source: "qrc:/assets/icons/plus.svg"
//                                         opacity: topVideoMouse.containsMouse ? 1.0 : 0.6
//                                     }
//
//                                     Text {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         text: "Add Video Track"
//                                         color: topVideoMouse.containsMouse ? "#ffffff" : "#888888"
//                                         font.pixelSize: 11
//                                         font.bold: true
//                                     }
//                                 }
//                             }
//                         }
//
//                         // Track Headers Column
//                         Column {
//                             id: trackHeaderColumn
//                             width: parent.width
//                             y: root.topShelfHeight
//
//                             Repeater {
//                                 model: root.activeTimelineModel
//
//                                 XylaTrackHeader {
//                                     width: root.headerWidth
//                                     trackId: model.trackId || ""
//                                     trackName: model.trackName || ""
//                                     trackKind: model.trackKind !== undefined ? model.trackKind : 0
//
//                                     onImplicitHeightChanged: root.updateTrackMetrics()
//                                     onTrackHeightChanged: root.updateTrackMetrics()
//                                     Component.onCompleted: root.updateTrackMetrics()
//                                 }
//                             }
//                         }
//
//                         Rectangle {
//                             id: bottomAudioShelf
//                             width: parent.width
//                             height: root.bottomShelfHeight
//                             y: root.totalTracksHeight - root.bottomShelfHeight
//                             color: bottomAudioMouse.containsMouse ? "#222222" : "#181818"
//                             border.color: bottomAudioMouse.containsMouse ? "#3b82f6" : root.borderDark
//                             border.width: 1
//
//                             Behavior on color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//                             Behavior on border.color {
//                                 ColorAnimation {
//                                     duration: 100
//                                 }
//                             }
//
//                             MouseArea {
//                                 id: bottomAudioMouse
//                                 anchors.fill: parent
//                                 hoverEnabled: true
//                                 cursorShape: Qt.PointingHandCursor
//                                 onClicked: {
//                                     root.pendingNewTrackKind = 1;
//                                     addTrackModal.open();
//                                 }
//
//                                 Row {
//                                     anchors.centerIn: parent
//                                     spacing: 6
//
//                                     Image {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         width: 14
//                                         height: 14
//                                         source: "qrc:/assets/icons/plus.svg"
//                                         opacity: bottomAudioMouse.containsMouse ? 1.0 : 0.6
//                                     }
//
//                                     Text {
//                                         anchors.verticalCenter: parent.verticalCenter
//                                         text: "Add Audio Track"
//                                         color: bottomAudioMouse.containsMouse ? "#ffffff" : "#888888"
//                                         font.pixelSize: 11
//                                         font.bold: true
//                                     }
//                                 }
//                             }
//                         }
//                     }
//                 }
//
//                 // Right Side: Unified 2D Timeline Canvas
//                 Flickable {
//                     id: trackScrollArea
//                     Layout.fillWidth: true
//                     Layout.fillHeight: true
//                     clip: true
//                     boundsBehavior: Flickable.StopAtBounds
//                     contentWidth: root.contentWidth + root.playheadMargin
//                     contentHeight: root.totalTracksHeight
//                     interactive: false
//
//                     // Explicit Dark Backdrop prevents white canvas leaks
//                     Rectangle {
//                         anchors.fill: parent
//                         color: "#121212"
//                         z: 0
//                     }
//
//                     DragHandler {
//                         id: middleDragHandler
//                         target: null
//                         acceptedButtons: Qt.MiddleButton
//                         property real startHorizOffset: 0
//                         property real startContentY: 0
//
//                         onActiveChanged: {
//                             root.isMiddlePanning = active;
//                             if (active) {
//                                 startHorizOffset = root.horizontalOffset;
//                                 startContentY = trackScrollArea.contentY;
//                             }
//                         }
//
//                         onTranslationChanged: {
//                             if (active) {
//                                 var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
//                                 var newOffset = Math.max(0, Math.min(maxOffset, startHorizOffset - translation.x));
//                                 if (root.activeTimelineModel) {
//                                     root.activeTimelineModel.horizontalOffset = newOffset;
//                                 }
//
//                                 var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
//                                 trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, startContentY - translation.y));
//                             }
//                         }
//                     }
//
//                     // Handles both vertical timeline scroll AND Ctrl+Zoom
//                     WheelHandler {
//                         id: wheelHandler
//                         target: null
//                         acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
//                         onWheel: event => {
//                             var cursorX = event.point?.position?.x ?? wheelHandler.point?.position?.x ?? (trackScrollArea.width / 2);
//
//                             if (event.modifiers & Qt.ControlModifier) {
//                                 var factor = event.angleDelta.y > 0 ? 1.35 : 0.74;
//                                 root.applyZoom(factor, cursorX + root.headerWidth);
//                                 return;
//                             }
//
//                             var pDeltaX = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x;
//                             var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
//
//                             var isHorizontal = (Math.abs(pDeltaX) > Math.abs(pDeltaY)) || (event.modifiers & Qt.ShiftModifier);
//
//                             if (isHorizontal) {
//                                 var deltaX = pDeltaX !== 0 ? -pDeltaX : -pDeltaY;
//                                 var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
//                                 var newOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaX));
//                                 if (root.activeTimelineModel) {
//                                     root.activeTimelineModel.horizontalOffset = newOffset;
//                                 }
//                             } else {
//                                 var deltaY = -pDeltaY;
//                                 var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
//                                 trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, trackScrollArea.contentY + deltaY));
//                             }
//                         }
//                     }
//
//                     Item {
//                         id: timelineCanvasViewport
//                         x: root.playheadMargin - root.horizontalOffset
//                         width: root.contentWidth
//                         height: trackScrollArea.contentHeight
//
//                         // 1. Top & Bottom Background Shelf Strips
//                         Rectangle {
//                             width: timelineCanvasViewport.width
//                             height: root.topShelfHeight
//                             y: 0
//                             color: "#161616"
//                             border.color: root.borderDark
//                             border.width: 1
//                         }
//
//                         Rectangle {
//                             width: timelineCanvasViewport.width
//                             height: root.bottomShelfHeight
//                             y: root.totalTracksHeight - root.bottomShelfHeight
//                             color: "#161616"
//                             border.color: root.borderDark
//                             border.width: 1
//                         }
//
//                         // 2. Dynamic Background Track Stripes (Neutral Gray Differentiation)
//                         Column {
//                             y: root.topShelfHeight
//                             width: timelineCanvasViewport.width
//
//                             Repeater {
//                                 model: root.trackCount
//                                 Rectangle {
//                                     width: timelineCanvasViewport.width
//                                     height: root.getTrackHeight(index)
//                                     color: root.getTrackBgColor(index)
//
//                                     Rectangle {
//                                         anchors.left: parent.left
//                                         anchors.right: parent.right
//                                         anchors.bottom: parent.bottom
//                                         height: 1
//                                         color: root.borderDark
//                                     }
//                                 }
//                             }
//                         }
//
//                         // 3. Empty Space Marquee Selection Area
//                         MouseArea {
//                             anchors.fill: parent
//                             z: 1
//                             acceptedButtons: Qt.LeftButton | Qt.RightButton
//
//                             property real startGlobalX: 0
//                             property real startGlobalY: 0
//                             property real startCanvasX: 0
//                             property real startCanvasY: 0
//                             property bool isMarquee: false
//
//                             onPressed: function (mouse) {
//                                 if (mouse.button === Qt.RightButton)
//                                     return;
//
//                                 var globalPt = mapToItem(root, mouse.x, mouse.y);
//                                 startGlobalX = globalPt.x;
//                                 startGlobalY = globalPt.y;
//                                 startCanvasX = mouse.x;
//                                 startCanvasY = mouse.y;
//                                 isMarquee = false;
//                             }
//
//                             onPositionChanged: function (mouse) {
//                                 if (mouse.buttons & Qt.RightButton)
//                                     return;
//
//                                 var globalPt = mapToItem(root, mouse.x, mouse.y);
//                                 var dx = globalPt.x - startGlobalX;
//                                 var dy = globalPt.y - startGlobalY;
//
//                                 if (!isMarquee && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
//                                     isMarquee = true;
//                                     if (root.activeTimelineModel) {
//                                         root.activeTimelineModel.startSelectionBatch();
//                                     }
//                                 }
//
//                                 if (isMarquee) {
//                                     var x1 = Math.min(startGlobalX, globalPt.x);
//                                     var x2 = Math.max(startGlobalX, globalPt.x);
//                                     var y1 = Math.min(startGlobalY, globalPt.y);
//                                     var y2 = Math.max(startGlobalY, globalPt.y);
//
//                                     marqueeRect.x = x1;
//                                     marqueeRect.y = y1;
//                                     marqueeRect.width = x2 - x1;
//                                     marqueeRect.height = y2 - y1;
//                                     marqueeRect.visible = true;
//
//                                     var canvasX1 = Math.min(startCanvasX, mouse.x);
//                                     var canvasX2 = Math.max(startCanvasX, mouse.x);
//                                     var canvasY1 = Math.min(startCanvasY, mouse.y);
//                                     var canvasY2 = Math.max(startCanvasY, mouse.y);
//
//                                     var startF = root.pxToFrame(canvasX1);
//                                     var endF = root.pxToFrame(canvasX2);
//                                     var startT = root.getTrackAtY(canvasY1);
//                                     var endT = root.getTrackAtY(canvasY2);
//
//                                     var isToggle = (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier));
//                                     if (root.activeTimelineModel) {
//                                         root.activeTimelineModel.selectBox(startF, endF, startT, endT, isToggle);
//                                     }
//                                 }
//                             }
//
//                             onReleased: function (mouse) {
//                                 if (mouse.button === Qt.RightButton) {
//                                     var overlayPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
//                                     var targetF = root.pxToFrame(mouse.x);
//                                     var targetT = root.getTrackAtY(mouse.y);
//                                     root.openContextMenu(overlayPt.x, overlayPt.y, targetF, targetT, null);
//                                     return;
//                                 }
//
//                                 if (isMarquee) {
//                                     if (root.activeTimelineModel) {
//                                         root.activeTimelineModel.commitSelectionBatch();
//                                     }
//                                     isMarquee = false;
//                                     marqueeRect.visible = false;
//                                 } else if (root.activeTimelineModel) {
//                                     root.activeTimelineModel.clearSelection();
//                                 }
//                             }
//                         }
//
//                         // 4. Drop Area for Files
//                         DropArea {
//                             anchors.fill: parent
//                             keys: ["xyla/media-asset", "text/uri-list"]
//                             z: 2
//
//                             onEntered: drag => drag.accept(Qt.CopyAction)
//                             onPositionChanged: drag => drag.accept(Qt.CopyAction)
//
//                             onDropped: function (drop) {
//                                 drop.accept(Qt.CopyAction);
//                                 if (!root.activeTimelineModel)
//                                     return;
//                                 var rawUrl = "";
//                                 if (drop.hasUrls && drop.urls && drop.urls.length > 0) {
//                                     rawUrl = drop.urls[0].toString();
//                                 } else if (drop.formats && drop.formats.indexOf("text/uri-list") !== -1) {
//                                     rawUrl = drop.getDataAsString("text/uri-list").trim();
//                                 }
//
//                                 if (!rawUrl || rawUrl.length === 0)
//                                     return;
//                                 var assetName = rawUrl.substring(rawUrl.lastIndexOf('/') + 1);
//                                 if (assetName.length === 0)
//                                     assetName = "Clip";
//
//                                 var realAssetId = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetId(rawUrl) : rawUrl;
//                                 var dropFrame = root.pxToFrame(drop.x);
//                                 var dropTrack = root.getTrackAtY(drop.y);
//                                 var assetDuration = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetDurationFrames(realAssetId, root.projectFps) : 150;
//
//                                 root.activeTimelineModel.addClip(realAssetId, assetName, dropTrack, dropFrame, assetDuration, 0);
//                                 root.updateContentWidth();
//                             }
//                         }
//
//                         // 5. Unified 2D Clips Layer
//                         Item {
//                             id: unifiedClipsLayer
//                             anchors.fill: parent
//                             z: 10
//
//                             Connections {
//                                 target: root.activeTimelineModel ? root.activeTimelineModel : null
//                                 function onTrackDataChanged(trackIndex) {
//                                     clipRepeater.refreshAllClips();
//                                     root.updateContentWidth();
//                                     root.updateTrackMetrics();
//                                 }
//                                 function onTrackCountChanged() {
//                                     clipRepeater.refreshAllClips();
//                                     root.updateContentWidth();
//                                     root.updateTrackMetrics();
//                                 }
//                                 function onClipPropertiesChanged(clipId) {
//                                     clipRepeater.refreshAllClips();
//                                 }
//                                 function onDataChanged(topLeft, bottomRight, roles) {
//                                     clipRepeater.refreshAllClips();
//                                 }
//                             }
//
//                             Repeater {
//                                 id: clipRepeater
//                                 model: []
//
//                                 function refreshAllClips() {
//                                     if (root.activeTimelineModel) {
//                                         model = root.activeTimelineModel.getAllClips();
//                                     } else {
//                                         model = [];
//                                     }
//                                 }
//
//                                 Component.onCompleted: refreshAllClips()
//
//                                 XylaClipCard {
//                                     timelineRoot: root
//                                     clipData: modelData
//                                     zoomFactor: root.zoomFactor
//                                 }
//                             }
//                         }
//
//                         // 6. Visual Snapping & Figma Spacing Guides Layer
//                         Item {
//                             id: snapGuideLayer
//                             anchors.fill: parent
//                             z: 500
//
//                             Rectangle {
//                                 id: snapLine
//                                 visible: root.isSnapLineVisible && root.snapGuideFrame >= 0
//                                 x: Math.round(root.snapGuideFrame * root.zoomFactor)
//                                 width: 1
//                                 height: parent.height
//                                 color: "#2563eb"
//                                 opacity: 0.8
//                                 z: 150
//
//                                 Rectangle {
//                                     anchors.top: parent.top
//                                     anchors.horizontalCenter: parent.horizontalCenter
//                                     width: 3
//                                     height: 3
//                                     radius: 1.5
//                                     color: "#3b82f6"
//                                 }
//                             }
//
//                             Item {
//                                 id: spacingGuide
//                                 visible: root.activeSpacingGaps.length > 0
//                                 anchors.fill: parent
//                                 z: 140
//
//                                 Repeater {
//                                     model: root.activeSpacingGaps
//
//                                     Rectangle {
//                                         id: gapRect
//                                         readonly property bool isActive: modelData.isActive === true
//                                         x: Math.round(Number(modelData.start) * root.zoomFactor)
//                                         width: Math.max(1, Math.round((Number(modelData.end) - Number(modelData.start)) * root.zoomFactor))
//                                         height: parent.height
//                                         color: isActive ? Qt.rgba(0.145, 0.388, 0.922, 0.18) : Qt.rgba(0.145, 0.388, 0.922, 0.10)
//                                         border.color: isActive ? "#3b82f6" : "#2563eb"
//                                         border.width: 1
//
//                                         Rectangle {
//                                             anchors.centerIn: parent
//                                             width: gapBadgeText.implicitWidth + 10
//                                             height: 18
//                                             color: gapRect.isActive ? "#2563eb" : "#1d4ed8"
//                                             radius: 4
//                                             border.color: gapRect.isActive ? "#60a5fa" : "#3b82f6"
//                                             border.width: 1
//
//                                             Text {
//                                                 id: gapBadgeText
//                                                 anchors.centerIn: parent
//                                                 text: (modelData.gapFrames !== undefined ? modelData.gapFrames : "") + "f"
//                                                 color: "#ffffff"
//                                                 font.pixelSize: 10
//                                                 font.bold: true
//                                             }
//                                         }
//                                     }
//                                 }
//                             }
//                         }
//                     }
//                 }
//             }
//
//             // State B: When 0 Tracks Exist
//             Item {
//                 anchors.fill: parent
//                 visible: root.trackCount === 0
//
//                 ColumnLayout {
//                     anchors.centerIn: parent
//                     spacing: 14
//
//                     Image {
//                         Layout.alignment: Qt.AlignHCenter
//                         source: "qrc:/assets/icons/layers.svg"
//                         sourceSize: Qt.size(42, 42)
//                         opacity: 0.35
//                     }
//
//                     ColumnLayout {
//                         Layout.alignment: Qt.AlignHCenter
//                         spacing: 4
//
//                         Text {
//                             Layout.alignment: Qt.AlignHCenter
//                             text: "No Tracks in Timeline"
//                             color: "#ffffff"
//                             font.pixelSize: 15
//                             font.bold: true
//                         }
//
//                         Text {
//                             Layout.alignment: Qt.AlignHCenter
//                             text: "Initialize video and audio tracks to begin editing"
//                             color: "#888888"
//                             font.pixelSize: 12
//                         }
//                     }
//
//                     XylaTextButton {
//                         Layout.alignment: Qt.AlignHCenter
//                         text: "Create Tracks..."
//                         primary: true
//                         onClicked: createTracksModal.open()
//                     }
//                 }
//             }
//         }
//     }
//
//     // Playhead
//     Item {
//         x: root.headerWidth
//         y: topToolBar.height
//         width: parent.width - root.headerWidth
//         height: parent.height - y
//         clip: true
//         z: 200
//         visible: root.trackCount > 0
//
//         XylaPlayhead {
//             id: mainPlayhead
//             timelineRoot: root
//             activeTimelineModel: root.activeTimelineModel
//             currentFrame: root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0
//             zoomFactor: root.zoomFactor
//             horizontalOffset: root.horizontalOffset
//             playheadMargin: root.playheadMargin
//             headerWidth: root.headerWidth
//             height: parent.height
//         }
//     }
//
//     // Sidebar Resizer
//     Item {
//         id: sidebarResizer
//         width: 8
//         x: root.headerWidth - 4
//         y: topToolBar.height
//         height: parent.height - y
//         z: 350
//         visible: root.trackCount > 0
//
//         Rectangle {
//             anchors.centerIn: parent
//             width: resizerMouse.containsMouse || resizerMouse.pressed ? 2 : 1
//             height: parent.height
//             color: resizerMouse.containsMouse || resizerMouse.pressed ? "#2555D3" : "#2d2d2d"
//
//             Behavior on width {
//                 NumberAnimation {
//                     duration: 80
//                 }
//             }
//         }
//
//         MouseArea {
//             id: resizerMouse
//             anchors.fill: parent
//             hoverEnabled: true
//             cursorShape: Qt.SizeHorCursor
//             preventStealing: true
//
//             property int startMouseX: 0
//             property int startWidth: 0
//
//             onPressed: function (mouse) {
//                 var pt = mapToItem(root, mouse.x, mouse.y);
//                 startMouseX = pt.x;
//                 startWidth = root.headerWidth;
//             }
//
//             onPositionChanged: function (mouse) {
//                 if (pressed) {
//                     var pt = mapToItem(root, mouse.x, mouse.y);
//                     var deltaX = pt.x - startMouseX;
//                     var newW = Math.max(root.minHeaderWidth, Math.min(root.maxHeaderWidth, startWidth + deltaX));
//                     root.headerWidth = newW;
//                 }
//             }
//         }
//     }
//
//     // Context Menu
//     XylaTimelineContextMenu {
//         id: timelineContextMenu
//         timelineRoot: root
//         timelineModel: root.activeTimelineModel
//         playbackManager: root.activePlaybackManager
//
//         onDeleteRequested: {
//             if (root.activeTimelineModel) {
//                 root.activeTimelineModel.deleteSelectedClips();
//                 root.updateContentWidth();
//             }
//         }
//
//         onRippleDeleteRequested: {
//             if (root.activeTimelineModel) {
//                 root.activeTimelineModel.deleteSelectedClips();
//                 root.updateContentWidth();
//             }
//         }
//
//         onSplitRequested: function (frame, track) {
//             if (root.activeTimelineModel && root.activePlaybackManager) {
//                 root.activeTimelineModel.cutAtPlayhead(root.activePlaybackManager.currentFrame);
//                 root.updateContentWidth();
//             }
//         }
//
//         onSelectAllRequested: {
//             if (root.activeTimelineModel) {
//                 var all = root.activeTimelineModel.getAllClips();
//                 var ids = [];
//                 for (var i = 0; i < all.length; ++i) {
//                     ids.push(all[i].clipId);
//                 }
//                 root.activeTimelineModel.applyDirectSelection(ids);
//             }
//         }
//     }
//
//     // Modal: Confirm Add Track
//     Popup {
//         id: addTrackModal
//         parent: Overlay.overlay
//         anchors.centerIn: parent
//         width: 320
//         padding: 16
//         modal: true
//         focus: true
//         closePolicy: Popup.CloseOnEscape
//
//         background: Rectangle {
//             color: "#181818"
//             border.color: "#303030"
//             border.width: 1
//             radius: 12
//
//             layer.enabled: true
//             layer.effect: MultiEffect {
//                 shadowEnabled: true
//                 shadowColor: "#90000000"
//                 shadowBlur: 0.75
//                 shadowVerticalOffset: 8
//             }
//         }
//
//         contentItem: ColumnLayout {
//             spacing: 14
//
//             ColumnLayout {
//                 spacing: 4
//                 Text {
//                     text: root.pendingNewTrackKind === 0 ? "Add Video Track" : "Add Audio Track"
//                     color: "#ffffff"
//                     font.pixelSize: 14
//                     font.bold: true
//                 }
//                 Text {
//                     text: root.pendingNewTrackKind === 0 ? "Insert a new video track into the timeline?" : "Append a new audio track into the timeline?"
//                     color: "#888888"
//                     font.pixelSize: 11
//                     wrapMode: Text.WordWrap
//                     Layout.fillWidth: true
//                 }
//             }
//
//             Rectangle {
//                 Layout.fillWidth: true
//                 height: 1
//                 color: "#282828"
//             }
//
//             RowLayout {
//                 Layout.fillWidth: true
//                 spacing: 8
//                 layoutDirection: Qt.RightToLeft
//
//                 XylaTextButton {
//                     text: "Add Track"
//                     primary: true
//                     onClicked: {
//                         if (root.activeTimelineModel) {
//                             if (root.pendingNewTrackKind === 0) {
//                                 if (root.activeTimelineModel.addVideoTrack) {
//                                     root.activeTimelineModel.addVideoTrack();
//                                 }
//                             } else {
//                                 if (root.activeTimelineModel.addAudioTrack) {
//                                     root.activeTimelineModel.addAudioTrack();
//                                 }
//                             }
//                             root.updateTrackMetrics();
//                             root.updateContentWidth();
//                         }
//                         addTrackModal.close();
//                     }
//                 }
//
//                 XylaTextButton {
//                     text: "Cancel"
//                     outline: true
//                     onClicked: addTrackModal.close()
//                 }
//             }
//         }
//     }
//
//     // Modal: Initialize Timeline Tracks Dialog
//     Popup {
//         id: createTracksModal
//         parent: Overlay.overlay
//         anchors.centerIn: parent
//         width: 320
//         padding: 16
//         modal: true
//         focus: true
//         closePolicy: Popup.CloseOnEscape
//
//         background: Rectangle {
//             color: "#181818"
//             border.color: "#303030"
//             border.width: 1
//             radius: 12
//
//             layer.enabled: true
//             layer.effect: MultiEffect {
//                 shadowEnabled: true
//                 shadowColor: "#90000000"
//                 shadowBlur: 0.75
//                 shadowVerticalOffset: 8
//                 shadowHorizontalOffset: 0
//             }
//         }
//
//         enter: Transition {
//             NumberAnimation {
//                 property: "opacity"
//                 from: 0.0
//                 to: 1.0
//                 duration: 150
//                 easing.type: Easing.OutCubic
//             }
//             NumberAnimation {
//                 property: "scale"
//                 from: 0.95
//                 to: 1.0
//                 duration: 180
//                 easing.type: Easing.OutCubic
//             }
//         }
//
//         exit: Transition {
//             NumberAnimation {
//                 property: "opacity"
//                 from: 1.0
//                 to: 0.0
//                 duration: 120
//                 easing.type: Easing.OutCubic
//             }
//             NumberAnimation {
//                 property: "scale"
//                 from: 1.0
//                 to: 0.95
//                 duration: 120
//                 easing.type: Easing.OutCubic
//             }
//         }
//
//         contentItem: ColumnLayout {
//             spacing: 16
//
//             ColumnLayout {
//                 spacing: 4
//                 Text {
//                     text: "Create Timeline Tracks"
//                     color: "#ffffff"
//                     font.pixelSize: 14
//                     font.bold: true
//                 }
//                 Text {
//                     text: "Select initial number of video and audio tracks"
//                     color: "#888888"
//                     font.pixelSize: 11
//                 }
//             }
//
//             Rectangle {
//                 Layout.fillWidth: true
//                 height: 1
//                 color: "#282828"
//             }
//
//             ColumnLayout {
//                 Layout.fillWidth: true
//                 spacing: 10
//
//                 RowLayout {
//                     Layout.fillWidth: true
//                     spacing: 10
//
//                     Text {
//                         text: "Video Tracks"
//                         color: "#cccccc"
//                         font.pixelSize: 12
//                         Layout.fillWidth: true
//                     }
//
//                     XylaFloatInput {
//                         id: videoTrackInput
//                         value: 2
//                         minValue: 0
//                         maxValue: 32
//                         stepSize: 1.0
//                         decimals: 0
//                         Layout.preferredWidth: 80
//                     }
//                 }
//
//                 RowLayout {
//                     Layout.fillWidth: true
//                     spacing: 10
//
//                     Text {
//                         text: "Audio Tracks"
//                         color: "#cccccc"
//                         font.pixelSize: 12
//                         Layout.fillWidth: true
//                     }
//
//                     XylaFloatInput {
//                         id: audioTrackInput
//                         value: 2
//                         minValue: 0
//                         maxValue: 32
//                         stepSize: 1.0
//                         decimals: 0
//                         Layout.preferredWidth: 80
//                     }
//                 }
//             }
//
//             Rectangle {
//                 Layout.fillWidth: true
//                 height: 1
//                 color: "#282828"
//             }
//
//             RowLayout {
//                 Layout.fillWidth: true
//                 spacing: 8
//                 layoutDirection: Qt.RightToLeft
//
//                 XylaTextButton {
//                     text: "Create"
//                     primary: true
//                     onClicked: {
//                         var vCount = Math.max(0, Math.round(videoTrackInput.value));
//                         var aCount = Math.max(0, Math.round(audioTrackInput.value));
//
//                         if (root.activeTimelineModel) {
//                             root.activeTimelineModel.createDefaultTracks(vCount, aCount);
//                             root.updateTrackMetrics();
//                             root.updateContentWidth();
//                         }
//                         createTracksModal.close();
//                     }
//                 }
//
//                 XylaTextButton {
//                     text: "Cancel"
//                     outline: true
//                     onClicked: createTracksModal.close()
//                 }
//             }
//         }
//     }
// }






import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Xyla 1.0
import "../components"
import "./timeline"

Item {
    id: root

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null
    property var activeProjectManager: typeof projectManager !== "undefined" ? projectManager : null
    property var activeProject: activeProjectManager?.activeProject ?? null
    property var activeShortcutManager: typeof shortcutManager !== "undefined" ? shortcutManager : null

    readonly property int trackCount: activeTimelineModel ? activeTimelineModel.trackCount : 0
    readonly property int playheadFrame: activePlaybackManager ? activePlaybackManager.currentFrame : 0

    property double zoomFactor: activeTimelineModel ? activeTimelineModel.zoomFactor : 1.0
    property real horizontalOffset: activeTimelineModel ? activeTimelineModel.horizontalOffset : 0.0
    property real contentWidth: 3600

    readonly property real projectFps: {
        if (!activeProject)
            return 30.0;
        if (typeof activeProject.fps === "number" && activeProject.fps > 0) {
            return activeProject.fps;
        }
        if (activeProject.fpsNumerator && activeProject.fpsDenominator) {
            return activeProject.fpsNumerator / activeProject.fpsDenominator;
        }
        return 30.0;
    }

    property int headerWidth: 220
    property int minHeaderWidth: 220
    property int maxHeaderWidth: 600

    // ADDED: Width reserved for track highlight palettes between header and clip container
    property int paletteStripWidth: 8

    readonly property color bgDark: "#141414"
    readonly property color bgHeader: "#181818"
    readonly property color borderDark: "#2d2d2d"
    readonly property real playheadMargin: 0.0

    // Neutral Gray Tones (Zero blue/tint)
    readonly property color videoTrackBg: "#141414"
    readonly property color audioTrackBg: "#222222"

    function getTrackBgColor(trackIdx) {
        if (!root.activeTimelineModel)
            return root.videoTrackBg;
        var kind = root.activeTimelineModel.getTrackKind(trackIdx);
        return (kind === 1) ? root.audioTrackBg : root.videoTrackBg;
    }

    // ADDED: Helper function to determine if the playhead currently sits inside any clip on a given track index
    function isPlayheadOnClipInTrack(trackIdx) {
        if (!root.activeTimelineModel)
            return false;
        var clips = root.activeTimelineModel.getAllClips();
        var pf = root.playheadFrame;
        for (var i = 0; i < clips.length; ++i) {
            var c = clips[i];
            if (Number(c.trackIndex) === trackIdx) {
                var startF = Number(c.startFrame);
                var endF = startF + Number(c.durationFrames);
                if (pf >= startF && pf < endF) {
                    return true;
                }
            }
        }
        return false;
    }

    property bool isMiddlePanning: false

    readonly property real topShelfHeight: 36
    readonly property real bottomShelfHeight: 36

    property var trackHeights: []
    property var trackOffsets: []
    property real totalTracksHeight: 200

    property real snapGuideFrame: -1
    property bool isSnapLineVisible: false
    property var activeSpacingGaps: []

    property int pendingNewTrackKind: 0

    function showSnapLine(frame) {
        snapGuideFrame = frame;
        isSnapLineVisible = (frame >= 0);
        activeSpacingGaps = [];
    }

    function showSpacingGuides(gapsList) {
        if (gapsList && gapsList.length > 0) {
            activeSpacingGaps = gapsList;
        } else {
            activeSpacingGaps = [];
        }
    }

    function hideSnapGuides() {
        isSnapLineVisible = false;
        snapGuideFrame = -1;
        activeSpacingGaps = [];
    }

    function updateTrackMetrics() {
        var count = root.trackCount;
        var heights = [];
        var offsets = [];
        var cumY = topShelfHeight; // Starts after the top + button shelf

        for (var i = 0; i < count; ++i) {
            var item = trackHeaderColumn.children[i];
            var h = (item && item.implicitHeight) ? item.implicitHeight : (trackHeights[i] ?? 68);
            heights.push(h);
            offsets.push(cumY);
            cumY += h;
        }
        trackHeights = heights;
        trackOffsets = offsets;
        totalTracksHeight = cumY + bottomShelfHeight;
    }

    function getTrackY(t) {
        if (t < 0 || !trackOffsets || t >= trackOffsets.length)
            return topShelfHeight + (t * 68);
        return trackOffsets[t];
    }

    function getTrackHeight(t) {
        if (t < 0 || !trackHeights || t >= trackHeights.length)
            return 68;
        return trackHeights[t];
    }

    function getTrackAtY(canvasY) {
        if (!trackOffsets || trackOffsets.length === 0)
            return 0;
        for (var i = trackOffsets.length - 1; i >= 0; --i) {
            if (canvasY >= trackOffsets[i])
                return i;
        }
        return 0;
    }

    function updateContentWidth() {
        if (!root.activeTimelineModel)
            return;
        var maxFrame = 0;
        var all = root.activeTimelineModel.getAllClips();
        for (var i = 0; i < all.length; ++i) {
            var endF = Number(all[i].startFrame) + Number(all[i].durationFrames);
            if (endF > maxFrame)
                maxFrame = endF;
        }
        var requiredPx = (maxFrame * root.zoomFactor) + 1000;
        root.contentWidth = Math.max(3600, requiredPx);
    }

    function applyZoom(factor, cursorScreenX) {
        var visibleTimelineX = cursorScreenX - (root.headerWidth + root.paletteStripWidth) - root.playheadMargin;
        var frameAtAnchor = (visibleTimelineX + root.horizontalOffset) / root.zoomFactor;

        var newZoom = Math.max(0.1, Math.min(10.0, root.zoomFactor * factor));
        var newOffset = (frameAtAnchor * newZoom) - visibleTimelineX;
        var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
        var clampedOffset = Math.max(0, Math.min(maxOffset, newOffset));

        if (root.activeTimelineModel) {
            root.activeTimelineModel.zoomFactor = newZoom;
            root.activeTimelineModel.horizontalOffset = clampedOffset;
        }
        root.updateContentWidth();
    }

    function frameToPx(frame) {
        return root.playheadMargin + (frame * root.zoomFactor);
    }

    function pxToFrame(px) {
        return Math.max(0, Math.round((px - root.playheadMargin) / root.zoomFactor));
    }

    function formatTimecode(frame) {
        var fps = root.projectFps;
        var totalSec = frame / fps;
        var hrs = Math.floor(totalSec / 3600);
        var mins = Math.floor((totalSec % 3600) / 60);
        var secs = Math.floor(totalSec % 60);
        var frames = Math.floor(frame % fps);

        function pad(n) {
            return n < 10 ? "0" + n : n;
        }
        return pad(hrs) + ":" + pad(mins) + ":" + pad(secs) + ":" + pad(frames);
    }

    function openContextMenu(screenX, screenY, frame, trackIdx, clipData) {
        timelineContextMenu.openAt(screenX, screenY, frame, trackIdx, clipData);
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgDark
        z: -1
    }

    Rectangle {
        id: marqueeRect
        color: "#253B82F6"
        border.color: "#3B82F6"
        border.width: 1
        visible: false
        z: 400
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Toolbar
        Rectangle {
            id: topToolBar
            color: "#191919"
            Layout.fillWidth: true
            height: 40

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: root.borderDark
            }

            RowLayout {
                anchors.left: parent.left
                anchors.right: centerControls.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6
            }

            Row {
                id: centerControls
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    height: 32
                    width: transportRow.implicitWidth
                    color: "transparent"
                    border.color: "#2d2d2d"
                    border.width: 1
                    radius: 6

                    Row {
                        id: transportRow
                        anchors.verticalCenter: parent.verticalCenter

                        XylaIconButton {
                            roundLeft: true
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/player-track-prev.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.playFromStart()
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            roundLeft: false
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/player-skip-back.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.jumpBackwardSeconds(5.0)
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            roundLeft: false
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/chevron-left.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.stepBackward(1)
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            property bool isPlayingForward: root.activePlaybackManager && root.activePlaybackManager.isPlaying && !root.activePlaybackManager.isPlayingReverse
                            roundLeft: false
                            roundRight: false
                            ghost: !isPlayingForward
                            primary: isPlayingForward
                            iconSource: isPlayingForward ? "qrc:/assets/icons/player-pause.svg" : "qrc:/assets/icons/player-play.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.togglePlay()
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            property bool isPlayingReverse: root.activePlaybackManager && root.activePlaybackManager.isPlaying && root.activePlaybackManager.isPlayingReverse
                            roundLeft: false
                            roundRight: false
                            ghost: !isPlayingReverse
                            primary: isPlayingReverse
                            iconSource: "qrc:/assets/icons/player-play-reverse.svg"
                            onClicked: {
                                if (!root.activePlaybackManager)
                                    return;
                                if (isPlayingReverse)
                                    root.activePlaybackManager.pause();
                                else
                                    root.activePlaybackManager.playReverse();
                            }
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            roundLeft: false
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/chevron-right.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.stepForward(1)
                        }
                        Rectangle {
                            width: 1
                            height: 32
                            color: "#2d2d2d"
                        }
                        XylaIconButton {
                            roundLeft: false
                            roundRight: true
                            ghost: true
                            iconSource: "qrc:/assets/icons/player-skip-forward.svg"
                            onClicked: if (root.activePlaybackManager)
                                root.activePlaybackManager.jumpForwardSeconds(5.0)
                        }
                    }
                }

                Rectangle {
                    width: 100
                    height: 32
                    color: "transparent"
                    border.color: "#2d2d2d"
                    border.width: 1
                    radius: 6

                    Text {
                        anchors.centerIn: parent
                        text: root.formatTimecode(root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0)
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Monospace"
                    }
                }
            }

            RowLayout {
                anchors.right: parent.right
                anchors.left: centerControls.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                layoutDirection: Qt.RightToLeft
                spacing: 6

                XylaIconButton {
                    id: rippleSettingsBtn
                    ghost: true
                    iconSource: "qrc:/assets/icons/settings.svg"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    tooltip: "Timeline Settings"
                    onClicked: ripplePopup.open()

                    XylaTimelineRippleSettingsPopup {
                        id: ripplePopup
                        x: rippleSettingsBtn.width - width
                        y: rippleSettingsBtn.height + 6
                        timelineModel: root.activeTimelineModel
                    }
                }
            }
        }

        XylaTimelineRuler {
            id: timelineRuler
            Layout.fillWidth: true
            // MODIFIED: Included paletteStripWidth in header offset calculation for ruler alignment
            headerWidth: root.headerWidth + root.paletteStripWidth + root.playheadMargin
            zoomFactor: root.zoomFactor
            horizontalOffset: root.horizontalOffset
            contentWidth: root.contentWidth
            fps: root.projectFps
            z: 250
        }

        // Main Timeline Content Area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // State A: When Tracks Exist
            RowLayout {
                anchors.fill: parent
                spacing: 0
                visible: root.trackCount > 0

                // Left Column: Scrollable Track Headers & Shelves
                Item {
                    Layout.preferredWidth: root.headerWidth
                    Layout.fillHeight: true
                    clip: true

                    // Forward Wheel Scrolling on Header to Main Vertical Scroll
                    WheelHandler {
                        target: null
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;
                            var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
                            trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, trackScrollArea.contentY - pDeltaY));
                        }
                    }

                    Item {
                        id: headerContentItem
                        width: parent.width
                        y: -trackScrollArea.contentY
                        height: root.totalTracksHeight

                        // Top + Video Button Shelf (scrolls out of view when scrolling down)
                        Rectangle {
                            id: topVideoShelf
                            width: parent.width
                            height: root.topShelfHeight
                            y: 0
                            color: topVideoMouse.containsMouse ? "#222222" : "#181818"
                            border.color: topVideoMouse.containsMouse ? "#3b82f6" : root.borderDark
                            border.width: 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            MouseArea {
                                id: topVideoMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.pendingNewTrackKind = 0;
                                    addTrackModal.open();
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 14
                                        height: 14
                                        source: "qrc:/assets/icons/plus.svg"
                                        opacity: topVideoMouse.containsMouse ? 1.0 : 0.6
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Add Video Track"
                                        color: topVideoMouse.containsMouse ? "#ffffff" : "#888888"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        // Track Headers Column
                        Column {
                            id: trackHeaderColumn
                            width: parent.width
                            y: root.topShelfHeight

                            Repeater {
                                model: root.activeTimelineModel

                                XylaTrackHeader {
                                    width: root.headerWidth
                                    trackId: model.trackId || ""
                                    trackName: model.trackName || ""
                                    trackKind: model.trackKind !== undefined ? model.trackKind : 0

                                    onImplicitHeightChanged: root.updateTrackMetrics()
                                    onTrackHeightChanged: root.updateTrackMetrics()
                                    Component.onCompleted: root.updateTrackMetrics()
                                }
                            }
                        }

                        Rectangle {
                            id: bottomAudioShelf
                            width: parent.width
                            height: root.bottomShelfHeight
                            y: root.totalTracksHeight - root.bottomShelfHeight
                            color: bottomAudioMouse.containsMouse ? "#222222" : "#181818"
                            border.color: bottomAudioMouse.containsMouse ? "#3b82f6" : root.borderDark
                            border.width: 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            MouseArea {
                                id: bottomAudioMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.pendingNewTrackKind = 1;
                                    addTrackModal.open();
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 14
                                        height: 14
                                        source: "qrc:/assets/icons/plus.svg"
                                        opacity: bottomAudioMouse.containsMouse ? 1.0 : 0.6
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Add Audio Track"
                                        color: bottomAudioMouse.containsMouse ? "#ffffff" : "#888888"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }

                // ADDED: Intermediate palette indicator strip between track headers and clip canvas
                Item {
                    id: paletteStripContainer
                    Layout.preferredWidth: root.paletteStripWidth
                    Layout.fillHeight: true
                    clip: true
                    z: 5

                    Item {
                        id: paletteContentItem
                        width: parent.width
                        y: -trackScrollArea.contentY
                        height: root.totalTracksHeight

                        // Top empty space shelf alignment
                        Rectangle {
                            width: parent.width
                            height: root.topShelfHeight
                            color: "#181818"
                            // border.color: root.borderDark
                            // border.width: 1
                        }

                        // Track Palettes Repeater
                        Column {
                            y: root.topShelfHeight
                            width: parent.width

                            Repeater {
                                model: root.trackCount

                                Rectangle {
                                    width: paletteStripContainer.width
                                    height: root.getTrackHeight(index)
                                    color: "#181818"

                                    // ADDED: Track status indicator palette that highlights when playhead is over a clip in this track
                                    Rectangle {
                                        id: paletteIndicator
                                        property bool isHighlighted: root.isPlayheadOnClipInTrack(index)
                                        anchors.centerIn: parent
                                        width: 4
                                        height: parent.height - 8
                                        radius: 2
                                        color: isHighlighted ? "#3b82f6" : "#2d2d2d"

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }

                                        // Glow/Shadow effect on active highlight
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "#3b82f6"
                                            opacity: paletteIndicator.isHighlighted ? 0.6 : 0.0
                                            z: -1

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 120
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 1
                                        color: root.borderDark
                                    }
                                }
                            }
                        }

                        // Bottom empty space shelf alignment
                        Rectangle {
                            width: parent.width
                            height: root.bottomShelfHeight
                            y: root.totalTracksHeight - root.bottomShelfHeight
                            color: "#181818"
                            // border.color: root.borderDark
                            // border.width: 1
                        }
                    }
                }

                // Right Side: Unified 2D Timeline Canvas
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // ADDED: Border added to the left side of the main clip container view
                    Rectangle {
                        id: clipContainerLeftBorder
                        // Anchor to trackScrollArea instead of parent!
                        anchors.left: parent.left // anchorLeft.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 1
                        color: root.borderDark
                        z: 100
                    }

                    Flickable {
                        id: trackScrollArea
                        anchors.fill: parent
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: root.contentWidth + root.playheadMargin
                        contentHeight: root.totalTracksHeight
                        interactive: false

                        // Explicit Dark Backdrop prevents white canvas leaks
                        Rectangle {
                            anchors.fill: parent
                            color: "#121212"
                            z: 0
                        }

                        DragHandler {
                            id: middleDragHandler
                            target: null
                            acceptedButtons: Qt.MiddleButton
                            property real startHorizOffset: 0
                            property real startContentY: 0

                            onActiveChanged: {
                                root.isMiddlePanning = active;
                                if (active) {
                                    startHorizOffset = root.horizontalOffset;
                                    startContentY = trackScrollArea.contentY;
                                }
                            }

                            onTranslationChanged: {
                                if (active) {
                                    var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
                                    var newOffset = Math.max(0, Math.min(maxOffset, startHorizOffset - translation.x));
                                    if (root.activeTimelineModel) {
                                        root.activeTimelineModel.horizontalOffset = newOffset;
                                    }

                                    var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
                                    trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, startContentY - translation.y));
                                }
                            }
                        }

                        // Handles both vertical timeline scroll AND Ctrl+Zoom AND Horizontal Scrolling
                        WheelHandler {
                            id: wheelHandler
                            target: null
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                var cursorX = event.point?.position?.x ?? wheelHandler.point?.position?.x ?? (trackScrollArea.width / 2);

                                if (event.modifiers & Qt.ControlModifier) {
                                    var factor = event.angleDelta.y > 0 ? 1.35 : 0.74;
                                    // MODIFIED: Updated cursor X coordinate calculation including paletteStripWidth
                                    root.applyZoom(factor, cursorX + root.headerWidth + root.paletteStripWidth);
                                    return;
                                }

                                var pDeltaX = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x;
                                var pDeltaY = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y;

                                // MODIFIED: Fixed horizontal scrolling detection to correctly respond to standard mouse wheel/trackpad horizontal events and Shift key modifier
                                var isHorizontal = (Math.abs(pDeltaX) > Math.abs(pDeltaY)) || (event.modifiers & Qt.ShiftModifier);

                                if (isHorizontal) {
                                    // MODIFIED: Ensure proper delta sign handling across touchpad and traditional mouse scroll wheels
                                    var deltaX = (pDeltaX !== 0) ? -pDeltaX : -pDeltaY;
                                    var maxOffset = Math.max(0, root.contentWidth - (trackScrollArea.width - root.playheadMargin));
                                    var newOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaX));
                                    if (root.activeTimelineModel) {
                                        root.activeTimelineModel.horizontalOffset = newOffset;
                                    }
                                } else {
                                    var deltaY = -pDeltaY;
                                    var maxContentY = Math.max(0, trackScrollArea.contentHeight - trackScrollArea.height);
                                    trackScrollArea.contentY = Math.max(0, Math.min(maxContentY, trackScrollArea.contentY + deltaY));
                                }
                            }
                        }

                        Item {
                            id: timelineCanvasViewport
                            x: root.playheadMargin - root.horizontalOffset
                            width: root.contentWidth
                            height: trackScrollArea.contentHeight

                            Rectangle {
                                width: 4 // timelineCanvasViewport.width
                                height: parent.height // root.bottomShelfHeight
                                // y: root.totalTracksHeight - root.bottomShelfHeight
                                color: "#FFFFF6"
                                border.color: "#FFF" // root.borderDark
                                border.width: 1
                            }
                            // 1. Top & Bottom Background Shelf Strips
                            Rectangle {
                                id: anchorLeft
                                width: timelineCanvasViewport.width
                                height: root.topShelfHeight
                                y: 0
                                color: "#161616"
                                border.color: root.borderDark
                                border.width: 1
                            }

                            Rectangle {
                                width: timelineCanvasViewport.width
                                height: root.bottomShelfHeight
                                y: root.totalTracksHeight - root.bottomShelfHeight
                                color: "#161616"
                                border.color: root.borderDark
                                border.width: 1
                            }

                            // 2. Dynamic Background Track Stripes (Neutral Gray Differentiation)
                            Column {
                                y: root.topShelfHeight
                                width: timelineCanvasViewport.width

                                Repeater {
                                    model: root.trackCount
                                    Rectangle {
                                        width: timelineCanvasViewport.width
                                        height: root.getTrackHeight(index)
                                        color: root.getTrackBgColor(index)

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 1
                                            color: root.borderDark
                                        }
                                    }
                                }
                            }

                            // 3. Empty Space Marquee Selection Area
                            MouseArea {
                                anchors.fill: parent
                                z: 1
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                property real startGlobalX: 0
                                property real startGlobalY: 0
                                property real startCanvasX: 0
                                property real startCanvasY: 0
                                property bool isMarquee: false

                                onPressed: function (mouse) {
                                    if (mouse.button === Qt.RightButton)
                                        return;

                                    var globalPt = mapToItem(root, mouse.x, mouse.y);
                                    startGlobalX = globalPt.x;
                                    startGlobalY = globalPt.y;
                                    startCanvasX = mouse.x;
                                    startCanvasY = mouse.y;
                                    isMarquee = false;
                                }

                                onPositionChanged: function (mouse) {
                                    if (mouse.buttons & Qt.RightButton)
                                        return;

                                    var globalPt = mapToItem(root, mouse.x, mouse.y);
                                    var dx = globalPt.x - startGlobalX;
                                    var dy = globalPt.y - startGlobalY;

                                    if (!isMarquee && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
                                        isMarquee = true;
                                        if (root.activeTimelineModel) {
                                            root.activeTimelineModel.startSelectionBatch();
                                        }
                                    }

                                    if (isMarquee) {
                                        var x1 = Math.min(startGlobalX, globalPt.x);
                                        var x2 = Math.max(startGlobalX, globalPt.x);
                                        var y1 = Math.min(startGlobalY, globalPt.y);
                                        var y2 = Math.max(startGlobalY, globalPt.y);

                                        marqueeRect.x = x1;
                                        marqueeRect.y = y1;
                                        marqueeRect.width = x2 - x1;
                                        marqueeRect.height = y2 - y1;
                                        marqueeRect.visible = true;

                                        var canvasX1 = Math.min(startCanvasX, mouse.x);
                                        var canvasX2 = Math.max(startCanvasX, mouse.x);
                                        var canvasY1 = Math.min(startCanvasY, mouse.y);
                                        var canvasY2 = Math.max(startCanvasY, mouse.y);

                                        var startF = root.pxToFrame(canvasX1);
                                        var endF = root.pxToFrame(canvasX2);
                                        var startT = root.getTrackAtY(canvasY1);
                                        var endT = root.getTrackAtY(canvasY2);

                                        var isToggle = (mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier));
                                        if (root.activeTimelineModel) {
                                            root.activeTimelineModel.selectBox(startF, endF, startT, endT, isToggle);
                                        }
                                    }
                                }

                                onReleased: function (mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        var overlayPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                        var targetF = root.pxToFrame(mouse.x);
                                        var targetT = root.getTrackAtY(mouse.y);
                                        root.openContextMenu(overlayPt.x, overlayPt.y, targetF, targetT, null);
                                        return;
                                    }

                                    if (isMarquee) {
                                        if (root.activeTimelineModel) {
                                            root.activeTimelineModel.commitSelectionBatch();
                                        }
                                        isMarquee = false;
                                        marqueeRect.visible = false;
                                    } else if (root.activeTimelineModel) {
                                        root.activeTimelineModel.clearSelection();
                                    }
                                }
                            }

                            // 4. Drop Area for Files
                            DropArea {
                                anchors.fill: parent
                                keys: ["xyla/media-asset", "text/uri-list"]
                                z: 2

                                onEntered: drag => drag.accept(Qt.CopyAction)
                                onPositionChanged: drag => drag.accept(Qt.CopyAction)

                                onDropped: function (drop) {
                                    drop.accept(Qt.CopyAction);
                                    if (!root.activeTimelineModel)
                                        return;
                                    var rawUrl = "";
                                    if (drop.hasUrls && drop.urls && drop.urls.length > 0) {
                                        rawUrl = drop.urls[0].toString();
                                    } else if (drop.formats && drop.formats.indexOf("text/uri-list") !== -1) {
                                        rawUrl = drop.getDataAsString("text/uri-list").trim();
                                    }

                                    if (!rawUrl || rawUrl.length === 0)
                                        return;
                                    var assetName = rawUrl.substring(rawUrl.lastIndexOf('/') + 1);
                                    if (assetName.length === 0)
                                        assetName = "Clip";

                                    var realAssetId = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetId(rawUrl) : rawUrl;
                                    var dropFrame = root.pxToFrame(drop.x);
                                    var dropTrack = root.getTrackAtY(drop.y);
                                    var assetDuration = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetDurationFrames(realAssetId, root.projectFps) : 150;

                                    root.activeTimelineModel.addClip(realAssetId, assetName, dropTrack, dropFrame, assetDuration, 0);
                                    root.updateContentWidth();
                                }
                            }

                            // 5. Unified 2D Clips Layer
                            Item {
                                id: unifiedClipsLayer
                                anchors.fill: parent
                                z: 10

                                Connections {
                                    target: root.activeTimelineModel ? root.activeTimelineModel : null
                                    function onTrackDataChanged(trackIndex) {
                                        clipRepeater.refreshAllClips();
                                        root.updateContentWidth();
                                        root.updateTrackMetrics();
                                    }
                                    function onTrackCountChanged() {
                                        clipRepeater.refreshAllClips();
                                        root.updateContentWidth();
                                        root.updateTrackMetrics();
                                    }
                                    function onClipPropertiesChanged(clipId) {
                                        clipRepeater.refreshAllClips();
                                    }
                                    function onDataChanged(topLeft, bottomRight, roles) {
                                        clipRepeater.refreshAllClips();
                                    }
                                }

                                Repeater {
                                    id: clipRepeater
                                    model: []

                                    function refreshAllClips() {
                                        if (root.activeTimelineModel) {
                                            model = root.activeTimelineModel.getAllClips();
                                        } else {
                                            model = [];
                                        }
                                    }

                                    Component.onCompleted: refreshAllClips()

                                    XylaClipCard {
                                        timelineRoot: root
                                        clipData: modelData
                                        zoomFactor: root.zoomFactor
                                    }
                                }
                            }

                            // 6. Visual Snapping & Figma Spacing Guides Layer
                            Item {
                                id: snapGuideLayer
                                anchors.fill: parent
                                z: 500

                                Rectangle {
                                    id: snapLine
                                    visible: root.isSnapLineVisible && root.snapGuideFrame >= 0
                                    x: Math.round(root.snapGuideFrame * root.zoomFactor)
                                    width: 1
                                    height: parent.height
                                    color: "#2563eb"
                                    opacity: 0.8
                                    z: 150

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 3
                                        height: 3
                                        radius: 1.5
                                        color: "#3b82f6"
                                    }
                                }

                                Item {
                                    id: spacingGuide
                                    visible: root.activeSpacingGaps.length > 0
                                    anchors.fill: parent
                                    z: 140

                                    Repeater {
                                        model: root.activeSpacingGaps

                                        Rectangle {
                                            id: gapRect
                                            readonly property bool isActive: modelData.isActive === true
                                            x: Math.round(Number(modelData.start) * root.zoomFactor)
                                            width: Math.max(1, Math.round((Number(modelData.end) - Number(modelData.start)) * root.zoomFactor))
                                            height: parent.height
                                            color: isActive ? Qt.rgba(0.145, 0.388, 0.922, 0.18) : Qt.rgba(0.145, 0.388, 0.922, 0.10)
                                            border.color: isActive ? "#3b82f6" : "#2563eb"
                                            border.width: 1

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: gapBadgeText.implicitWidth + 10
                                                height: 18
                                                color: gapRect.isActive ? "#2563eb" : "#1d4ed8"
                                                radius: 4
                                                border.color: gapRect.isActive ? "#60a5fa" : "#3b82f6"
                                                border.width: 1

                                                Text {
                                                    id: gapBadgeText
                                                    anchors.centerIn: parent
                                                    text: (modelData.gapFrames !== undefined ? modelData.gapFrames : "") + "f"
                                                    color: "#ffffff"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Full-height divider: sits exactly at the boundary between
                // the indicator column and the clips view. A direct sibling
                // of the Left Column / Right Side Item (not nested inside
                // the Flickable), so it is never offset by playheadMargin
                // and never scrolls with the content.
                Rectangle {
                    x: root.headerWidth + root.paletteStripWidth
                    y: 0
                    width: 1
                    height: parent.height
                    color: root.borderDark
                    z: 100
                }
            }

            // State B: When 0 Tracks Exist
            Item {
                anchors.fill: parent
                visible: root.trackCount === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 14

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        source: "qrc:/assets/icons/layers.svg"
                        sourceSize: Qt.size(42, 42)
                        opacity: 0.35
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "No Tracks in Timeline"
                            color: "#ffffff"
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Initialize video and audio tracks to begin editing"
                            color: "#888888"
                            font.pixelSize: 12
                        }
                    }

                    XylaTextButton {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Create Tracks..."
                        primary: true
                        onClicked: createTracksModal.open()
                    }
                }
            }
        }
    }

    // Playhead
    Item {
        // MODIFIED: Shifted playhead start position to account for paletteStripWidth
        x: root.headerWidth + root.paletteStripWidth
        y: topToolBar.height
        width: parent.width - (root.headerWidth + root.paletteStripWidth)
        height: parent.height - y
        clip: true
        z: 200
        visible: root.trackCount > 0

        XylaPlayhead {
            id: mainPlayhead
            timelineRoot: root
            activeTimelineModel: root.activeTimelineModel
            currentFrame: root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0
            zoomFactor: root.zoomFactor
            horizontalOffset: root.horizontalOffset
            playheadMargin: root.playheadMargin
            headerWidth: root.headerWidth + root.paletteStripWidth
            height: parent.height
        }
    }

    // Sidebar Resizer
    Item {
        id: sidebarResizer
        width: 8
        x: root.headerWidth - 4
        y: topToolBar.height
        height: parent.height - y
        z: 350
        visible: root.trackCount > 0

        Rectangle {
            anchors.centerIn: parent
            width: resizerMouse.containsMouse || resizerMouse.pressed ? 2 : 1
            height: parent.height
            color: resizerMouse.containsMouse || resizerMouse.pressed ? "#2555D3" : "#2d2d2d"

            Behavior on width {
                NumberAnimation {
                    duration: 80
                }
            }
        }

        MouseArea {
            id: resizerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            property int startMouseX: 0
            property int startWidth: 0

            onPressed: function (mouse) {
                var pt = mapToItem(root, mouse.x, mouse.y);
                startMouseX = pt.x;
                startWidth = root.headerWidth;
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var pt = mapToItem(root, mouse.x, mouse.y);
                    var deltaX = pt.x - startMouseX;
                    var newW = Math.max(root.minHeaderWidth, Math.min(root.maxHeaderWidth, startWidth + deltaX));
                    root.headerWidth = newW;
                }
            }
        }
    }

    // Context Menu
    XylaTimelineContextMenu {
        id: timelineContextMenu
        timelineRoot: root
        timelineModel: root.activeTimelineModel
        playbackManager: root.activePlaybackManager

        onDeleteRequested: {
            if (root.activeTimelineModel) {
                root.activeTimelineModel.deleteSelectedClips();
                root.updateContentWidth();
            }
        }

        onRippleDeleteRequested: {
            if (root.activeTimelineModel) {
                root.activeTimelineModel.deleteSelectedClips();
                root.updateContentWidth();
            }
        }

        onSplitRequested: function (frame, track) {
            if (root.activeTimelineModel && root.activePlaybackManager) {
                root.activeTimelineModel.cutAtPlayhead(root.activePlaybackManager.currentFrame);
                root.updateContentWidth();
            }
        }

        onSelectAllRequested: {
            if (root.activeTimelineModel) {
                var all = root.activeTimelineModel.getAllClips();
                var ids = [];
                for (var i = 0; i < all.length; ++i) {
                    ids.push(all[i].clipId);
                }
                root.activeTimelineModel.applyDirectSelection(ids);
            }
        }
    }

    // Modal: Confirm Add Track
    Popup {
        id: addTrackModal
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 320
        padding: 16
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        background: Rectangle {
            color: "#181818"
            border.color: "#303030"
            border.width: 1
            radius: 12

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.75
                shadowVerticalOffset: 8
            }
        }

        contentItem: ColumnLayout {
            spacing: 14

            ColumnLayout {
                spacing: 4
                Text {
                    text: root.pendingNewTrackKind === 0 ? "Add Video Track" : "Add Audio Track"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: root.pendingNewTrackKind === 0 ? "Insert a new video track into the timeline?" : "Append a new audio track into the timeline?"
                    color: "#888888"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#282828"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                layoutDirection: Qt.RightToLeft

                XylaTextButton {
                    text: "Add Track"
                    primary: true
                    onClicked: {
                        if (root.activeTimelineModel) {
                            if (root.pendingNewTrackKind === 0) {
                                if (root.activeTimelineModel.addVideoTrack) {
                                    root.activeTimelineModel.addVideoTrack();
                                }
                            } else {
                                if (root.activeTimelineModel.addAudioTrack) {
                                    root.activeTimelineModel.addAudioTrack();
                                }
                            }
                            root.updateTrackMetrics();
                            root.updateContentWidth();
                        }
                        addTrackModal.close();
                    }
                }

                XylaTextButton {
                    text: "Cancel"
                    outline: true
                    onClicked: addTrackModal.close()
                }
            }
        }
    }

    // Modal: Initialize Timeline Tracks Dialog
    Popup {
        id: createTracksModal
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 320
        padding: 16
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        background: Rectangle {
            color: "#181818"
            border.color: "#303030"
            border.width: 1
            radius: 12

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#90000000"
                shadowBlur: 0.75
                shadowVerticalOffset: 8
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
            spacing: 16

            ColumnLayout {
                spacing: 4
                Text {
                    text: "Create Timeline Tracks"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                }
                Text {
                    text: "Select initial number of video and audio tracks"
                    color: "#888888"
                    font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#282828"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Video Tracks"
                        color: "#cccccc"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }

                    XylaFloatInput {
                        id: videoTrackInput
                        value: 2
                        minValue: 0
                        maxValue: 32
                        stepSize: 1.0
                        decimals: 0
                        Layout.preferredWidth: 80
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Audio Tracks"
                        color: "#cccccc"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }

                    XylaFloatInput {
                        id: audioTrackInput
                        value: 2
                        minValue: 0
                        maxValue: 32
                        stepSize: 1.0
                        decimals: 0
                        Layout.preferredWidth: 80
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#282828"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                layoutDirection: Qt.RightToLeft

                XylaTextButton {
                    text: "Create"
                    primary: true
                    onClicked: {
                        var vCount = Math.max(0, Math.round(videoTrackInput.value));
                        var aCount = Math.max(0, Math.round(audioTrackInput.value));

                        if (root.activeTimelineModel) {
                            root.activeTimelineModel.createDefaultTracks(vCount, aCount);
                            root.updateTrackMetrics();
                            root.updateContentWidth();
                        }
                        createTracksModal.close();
                    }
                }

                XylaTextButton {
                    text: "Cancel"
                    outline: true
                    onClicked: createTracksModal.close()
                }
            }
        }
    }
}
