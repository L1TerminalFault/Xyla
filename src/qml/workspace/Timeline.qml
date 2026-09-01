import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    readonly property real projectFps: {
        if (!activeProject) return 30.0
        if (typeof activeProject.fps === "number" && activeProject.fps > 0) {
            return activeProject.fps
        }
        if (activeProject.fpsNumerator && activeProject.fpsDenominator) {
            return activeProject.fpsNumerator / activeProject.fpsDenominator
        }
        return 30.0
    }

    property int headerWidth: 220
    property int minHeaderWidth: 220
    property int maxHeaderWidth: 600

    property double zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real contentWidth: 3600

    readonly property color bgDark: "#1a1a1a"
    readonly property color bgHeader: "#181818"
    readonly property color borderDark: "#2d2d2d"
    readonly property real playheadMargin: 10.0

    property bool isMiddlePanning: false

    function updateContentWidth() {
        if (!root.activeTimelineModel) return
        var maxFrame = 0
        var trackCount = root.activeTimelineModel.rowCount()
        for (var i = 0; i < trackCount; ++i) {
            var clips = root.activeTimelineModel.getClipsForTrack(i)
            for (var j = 0; j < clips.length; ++j) {
                var c = clips[j]
                var endF = Number(c.startFrame) + Number(c.durationFrames)
                if (endF > maxFrame) maxFrame = endF
            }
        }
        var requiredPx = (maxFrame * root.zoomFactor) + 1000
        root.contentWidth = Math.max(3600, requiredPx)
    }

    function applyZoom(factor, cursorScreenX) {
        var anchorMouse = settingsManager ? settingsManager.MousePosition : 0
        var anchorPlayhead = settingsManager ? settingsManager.Playhead : 1
        var anchorCenter = settingsManager ? settingsManager.CenterOfView : 2

        var anchorMode = (typeof settingsManager !== "undefined" && settingsManager) ? settingsManager.zoomAnchorMode : anchorMouse
        var anchorScreenX = cursorScreenX

        if (anchorMode === anchorPlayhead) {
            var currentFrame = root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0
            var playheadPx = root.frameToPx(currentFrame)
            anchorScreenX = playheadPx - root.horizontalOffset + root.headerWidth
        } else if (anchorMode === anchorCenter) {
            anchorScreenX = root.headerWidth + ((trackListView.width - root.headerWidth) / 2)
        }

        var visibleTimelineX = anchorScreenX - root.headerWidth - root.playheadMargin
        var frameAtAnchor = (visibleTimelineX + root.horizontalOffset) / root.zoomFactor

        var newZoom = Math.max(0.1, Math.min(10.0, root.zoomFactor * factor))
        root.zoomFactor = newZoom

        var newOffset = (frameAtAnchor * newZoom) - visibleTimelineX
        var maxOffset = Math.max(0, root.contentWidth - (trackListView.width - root.headerWidth))
        root.horizontalOffset = Math.max(0, Math.min(maxOffset, newOffset))
        root.updateContentWidth()
    }

    function frameToPx(frame) {
        return root.playheadMargin + (frame * root.zoomFactor)
    }

    function pxToFrame(px) {
        return Math.max(0, Math.round((px - root.playheadMargin) / root.zoomFactor))
    }

    function zoomAroundCursor(factor, cursorScreenX) {
        var visibleTimelineX = cursorScreenX - root.headerWidth - root.playheadMargin
        var frameAtCursor = (visibleTimelineX + root.horizontalOffset) / root.zoomFactor

        var newZoom = Math.max(0.1, Math.min(10.0, root.zoomFactor * factor))
        root.zoomFactor = newZoom

        var newOffset = (frameAtCursor * newZoom) - visibleTimelineX
        var maxOffset = Math.max(0, root.contentWidth - (trackListView.width - root.headerWidth))
        root.horizontalOffset = Math.max(0, Math.min(maxOffset, newOffset))
        root.updateContentWidth()
    }

    function formatTimecode(frame) {
        var fps = root.projectFps
        var totalSec = frame / fps
        var hrs = Math.floor(totalSec / 3600)
        var mins = Math.floor((totalSec % 3600) / 60)
        var secs = Math.floor(totalSec % 60)
        var frames = Math.floor(frame % fps)

        function pad(n) { return n < 10 ? "0" + n : n }
        return pad(hrs) + ":" + pad(mins) + ":" + pad(secs) + ":" + pad(frames)
    }

    Shortcut {
        sequence: root.activeShortcutManager?.shortcutMap["timeline.zoomIn"] ?? "="
        onActivated: root.applyZoom(1.25, trackListView.width / 2)
    }
    Shortcut {
        sequence: root.activeShortcutManager?.shortcutMap["timeline.zoomOut"] ?? "-"
        onActivated: root.applyZoom(0.8, trackListView.width / 2)
    }
    Shortcut {
        sequence: root.activeShortcutManager?.shortcutMap["playback.togglePlay"] ?? "Space"
        onActivated: root.activePlaybackManager?.togglePlay()
    }
    Shortcut {
        sequence: root.activeShortcutManager?.shortcutMap["timeline.zoomFit"] ?? "Shift+Z"
        onActivated: {
            root.horizontalOffset = 0.0
            root.zoomFactor = 1.0
            root.updateContentWidth()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgDark
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: topToolBar
            color: root.bgDark
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
                            onClicked: if (root.activePlaybackManager) root.activePlaybackManager.playFromStart()
                        }

                        Rectangle { width: 1; height: 32; color: "#2d2d2d" }

                        XylaIconButton {
                            roundLeft: false
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/player-skip-back.svg"
                            onClicked: if (root.activePlaybackManager) root.activePlaybackManager.jumpBackwardSeconds(5.0)
                        }

                        Rectangle { width: 1; height: 32; color: "#2d2d2d" }

                        XylaIconButton {
                            roundLeft: false
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/chevron-left.svg"
                            onClicked: if (root.activePlaybackManager) root.activePlaybackManager.stepBackward(1)
                        }

                        Rectangle { width: 1; height: 32; color: "#2d2d2d" }

                        XylaIconButton {
                            property bool isPlayingForward: root.activePlaybackManager && root.activePlaybackManager.isPlaying && !root.activePlaybackManager.isPlayingReverse
                            roundLeft: false
                            roundRight: false
                            ghost: !isPlayingForward
                            primary: isPlayingForward
                            iconSource: isPlayingForward ? "qrc:/assets/icons/player-pause.svg" : "qrc:/assets/icons/player-play.svg"
                            onClicked: if (root.activePlaybackManager) root.activePlaybackManager.togglePlay()
                        }

                        Rectangle { width: 1; height: 32; color: "#2d2d2d" }

                        XylaIconButton {
                            property bool isPlayingReverse: root.activePlaybackManager && root.activePlaybackManager.isPlaying && root.activePlaybackManager.isPlayingReverse
                            roundLeft: false
                            roundRight: false
                            ghost: !isPlayingReverse
                            primary: isPlayingReverse
                            iconSource: "qrc:/assets/icons/player-play-reverse.svg"
                            onClicked: {
                                if (!root.activePlaybackManager) return
                                if (isPlayingReverse) root.activePlaybackManager.pause()
                                else root.activePlaybackManager.playReverse()
                            }
                        }

                        Rectangle { width: 1; height: 32; color: "#2d2d2d" }

                        XylaIconButton {
                            roundLeft: false
                            roundRight: false
                            ghost: true
                            iconSource: "qrc:/assets/icons/chevron-right.svg"
                            onClicked: if (root.activePlaybackManager) root.activePlaybackManager.stepForward(1)
                        }

                        Rectangle { width: 1; height: 32; color: "#2d2d2d" }

                        XylaIconButton {
                            roundLeft: false
                            roundRight: true
                            ghost: true
                            iconSource: "qrc:/assets/icons/player-skip-forward.svg"
                            onClicked: if (root.activePlaybackManager) root.activePlaybackManager.jumpForwardSeconds(5.0)
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
            }
        }

        XylaTimelineRuler {
            id: timelineRuler
            Layout.fillWidth: true
            headerWidth: root.headerWidth + root.playheadMargin
            zoomFactor: root.zoomFactor
            horizontalOffset: root.horizontalOffset
            contentWidth: root.contentWidth
            fps: root.projectFps
            z: 250
        }

        ListView {
            id: trackListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            boundsBehavior: Flickable.StopAtBounds
            model: root.activeTimelineModel

            delegate: Item {
                id: delegateRow
                width: trackListView.width
                height: trackHeader.implicitHeight
                clip: false

                readonly property int trackIdx: index

                Row {
                    anchors.fill: parent
                    spacing: 0

                    XylaTrackHeader {
                        id: trackHeader
                        width: root.headerWidth
                        trackId: model.trackId || ""
                        trackName: model.trackName || ""
                        trackKind: model.trackKind !== undefined ? model.trackKind : 0
                        z: 300
                    }

                    Item {
                        id: trackLane
                        width: delegateRow.width - root.headerWidth - root.playheadMargin
                        height: parent.height
                        clip: false

                        Connections {
                            target: root.activeTimelineModel ? root.activeTimelineModel : null
                            function onTrackDataChanged(updatedTrackIndex) {
                                if (updatedTrackIndex === delegateRow.trackIdx) {
                                    clipRepeater.refreshClips()
                                    root.updateContentWidth()
                                }
                            }
                            function onTrackCountChanged() {
                                clipRepeater.refreshClips()
                                root.updateContentWidth()
                            }
                        }

                        Item {
                            x: root.playheadMargin - root.horizontalOffset
                            width: root.contentWidth
                            height: parent.height
                            clip: false
                            z: 10

                            Rectangle {
                                anchors.fill: parent
                                color: "#151515"
                                z: 0

                                Rectangle {
                                    height: 1
                                    color: root.borderDark
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                keys: ["xyla/media-asset", "text/uri-list"]
                                z: 1

                                onEntered: drag => drag.accept(Qt.CopyAction)
                                onPositionChanged: drag => drag.accept(Qt.CopyAction)

                                onDropped: function (drop) {
                                    drop.accept(Qt.CopyAction)
                                    if (!root.activeTimelineModel) return

                                    var rawUrl = ""
                                    if (drop.hasUrls && drop.urls && drop.urls.length > 0) {
                                        rawUrl = drop.urls[0].toString()
                                    } else if (drop.formats && drop.formats.indexOf("text/uri-list") !== -1) {
                                        rawUrl = drop.getDataAsString("text/uri-list").trim()
                                    }

                                    if (!rawUrl || rawUrl.length === 0) return

                                    var assetName = rawUrl.substring(rawUrl.lastIndexOf('/') + 1)
                                    if (assetName.length === 0) assetName = "Clip"

                                    var realAssetId = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetId(rawUrl) : rawUrl
                                    var dropFrame = root.pxToFrame(drop.x)
                                    var assetDuration = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetDurationFrames(realAssetId, root.projectFps) : 150

                                    root.activeTimelineModel.addClip(realAssetId, assetName, delegateRow.trackIdx, dropFrame, assetDuration, 0)
                                    root.updateContentWidth()
                                }
                            }

                            Repeater {
                                id: clipRepeater
                                z: 10
                                model: []

                                function refreshClips() {
                                    if (root.activeTimelineModel) {
                                        model = root.activeTimelineModel.getClipsForTrack(delegateRow.trackIdx)
                                    } else {
                                        model = []
                                    }
                                }

                                Component.onCompleted: refreshClips()

                                XylaClipCard {
                                    clipData: modelData
                                    zoomFactor: root.zoomFactor
                                    trackIndex: delegateRow.trackIdx
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: globalTrackPanArea
                x: root.headerWidth
                width: parent.width - root.headerWidth
                height: parent.height
                z: 5

                acceptedButtons: Qt.MiddleButton
                hoverEnabled: false
                cursorShape: root.isMiddlePanning ? Qt.ClosedHandCursor : Qt.ArrowCursor

                property real startMouseX: 0
                property real startMouseY: 0
                property real startHorizOffset: 0
                property real startContentY: 0

                onPressed: function (mouse) {
                    if (mouse.button === Qt.MiddleButton) {
                        root.isMiddlePanning = true
                        startMouseX = mouse.x
                        startMouseY = mouse.y
                        startHorizOffset = root.horizontalOffset
                        startContentY = trackListView.contentY
                    }
                }

                onPositionChanged: function (mouse) {
                    if (root.isMiddlePanning) {
                        var dx = startMouseX - mouse.x
                        var maxOffset = Math.max(0, root.contentWidth - (trackListView.width - root.headerWidth))
                        root.horizontalOffset = Math.max(0, Math.min(maxOffset, startHorizOffset + dx))

                        var dy = startMouseY - mouse.y
                        var maxContentY = Math.max(0, trackListView.contentHeight - trackListView.height)
                        trackListView.contentY = Math.max(0, Math.min(maxContentY, startContentY + dy))
                    }
                }

                onReleased: function (mouse) {
                    if (mouse.button === Qt.MiddleButton) {
                        root.isMiddlePanning = false
                    }
                }

                onWheel: function (wheel) {
                    if (wheel.modifiers & Qt.ControlModifier) {
                        var factor = wheel.angleDelta.y > 0 ? 1.15 : 0.85
                        root.applyZoom(factor, wheel.x + root.headerWidth)
                    } else if (wheel.modifiers & Qt.ShiftModifier || wheel.angleDelta.x !== 0) {
                        var deltaX = wheel.angleDelta.x !== 0 ? -wheel.angleDelta.x : -wheel.angleDelta.y
                        var maxOffset = Math.max(0, root.contentWidth - (trackListView.width - root.headerWidth))
                        root.horizontalOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaX))
                    } else {
                        var deltaY = -wheel.angleDelta.y
                        var maxContentY = Math.max(0, trackListView.contentHeight - trackListView.height)
                        trackListView.contentY = Math.max(0, Math.min(maxContentY, trackListView.contentY + deltaY))
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "No Tracks Available\n(Create or open a project)"
                horizontalAlignment: Text.AlignHCenter
                color: "#555555"
                font.pixelSize: 13
                visible: trackListView.count === 0
            }
        }
    }

    Item {
        x: root.headerWidth
        y: topToolBar.height
        width: parent.width - root.headerWidth
        height: parent.height - y
        clip: true
        z: 200

        XylaPlayhead {
            id: mainPlayhead
            currentFrame: root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0
            zoomFactor: root.zoomFactor
            horizontalOffset: root.horizontalOffset
            playheadMargin: root.playheadMargin
            headerWidth: root.headerWidth
            height: parent.height
        }
    }

    Item {
        id: sidebarResizer
        width: 8
        x: root.headerWidth - 4
        y: topToolBar.height
        height: parent.height - y
        z: 350

        Rectangle {
            anchors.centerIn: parent
            width: resizerMouse.containsMouse || resizerMouse.pressed ? 2 : 1
            height: parent.height
            color: resizerMouse.containsMouse || resizerMouse.pressed ? "#2555D3" : "#2d2d2d"

            Behavior on width {
                NumberAnimation { duration: 80 }
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
                var pt = mapToItem(root, mouse.x, mouse.y)
                startMouseX = pt.x
                startWidth = root.headerWidth
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var pt = mapToItem(root, mouse.x, mouse.y)
                    var deltaX = pt.x - startMouseX
                    var newW = Math.max(root.minHeaderWidth, Math.min(root.maxHeaderWidth, startWidth + deltaX))
                    root.headerWidth = newW
                }
            }
        }
    }
}
