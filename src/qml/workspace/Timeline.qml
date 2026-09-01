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
    property var activeProjectInfo: typeof projectInfo !== "undefined" ? projectInfo : null
    property var activeShortcutManager: typeof shortcutManager !== "undefined" ? shortcutManager : null

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

    // Middle-Mouse 2D Pan State
    property bool isMiddlePanning: false

    function updateContentWidth() {
        if (!root.activeTimelineModel)
            return;
        var maxFrame = 0;
        var trackCount = root.activeTimelineModel.rowCount();
        for (var i = 0; i < trackCount; ++i) {
            var clips = root.activeTimelineModel.getClipsForTrack(i);
            for (var j = 0; j < clips.length; ++j) {
                var c = clips[j];
                var endF = Number(c.startFrame) + Number(c.durationFrames);
                if (endF > maxFrame)
                    maxFrame = endF;
            }
        }
        var requiredPx = (maxFrame * root.zoomFactor) + 1000;
        root.contentWidth = Math.max(3600, requiredPx);
    }

    function frameToPx(frame) {
        return root.playheadMargin + (frame * root.zoomFactor);
    }
    function pxToFrame(px) {
        return Math.max(0, Math.round((px - root.playheadMargin) / root.zoomFactor));
    }

    // Cursor-centered zoom helper
    function zoomAroundCursor(factor, cursorScreenX) {
        var visibleTimelineX = cursorScreenX - root.headerWidth - root.playheadMargin;
        var frameAtCursor = (visibleTimelineX + root.horizontalOffset) / root.zoomFactor;

        var newZoom = Math.max(0.1, Math.min(10.0, root.zoomFactor * factor));
        root.zoomFactor = newZoom;

        // Re-adjust horizontal offset to keep the frame directly under the cursor
        var newOffset = (frameAtCursor * newZoom) - visibleTimelineX;
        var maxOffset = Math.max(0, root.contentWidth - (trackListView.width - root.headerWidth));
        root.horizontalOffset = Math.max(0, Math.min(maxOffset, newOffset));
        root.updateContentWidth();
    }

    function formatTimecode(frame) {
        var fps = root.activeProjectInfo ? root.activeProjectInfo.fps : 30.0;
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

    Shortcut {
        sequence: (root.activeShortcutManager && root.activeShortcutManager.shortcutMap["playback.togglePlay"]) || "Space"
        onActivated: if (root.activePlaybackManager)
            root.activePlaybackManager.togglePlay()
    }
    Shortcut {
        sequence: (root.activeShortcutManager && root.activeShortcutManager.shortcutMap["timeline.zoomIn"]) || "="
        onActivated: root.zoomAroundCursor(1.25, trackListView.width / 2)
    }
    Shortcut {
        sequence: (root.activeShortcutManager && root.activeShortcutManager.shortcutMap["timeline.zoomOut"]) || "-"
        onActivated: root.zoomAroundCursor(0.8, trackListView.width / 2)
    }
    Shortcut {
        sequence: (root.activeShortcutManager && root.activeShortcutManager.shortcutMap["timeline.zoomFit"]) || "Shift+Z"
        onActivated: {
            root.horizontalOffset = 0.0;
            root.zoomFactor = 1.0;
            root.updateContentWidth();
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

        // Top Tools Bar
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
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/player-track-prev.svg"
                    onClicked: if (root.activePlaybackManager)
                        root.activePlaybackManager.playFromStart()
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/player-skip-back.svg"
                    onClicked: if (root.activePlaybackManager)
                        root.activePlaybackManager.jumpBackwardSeconds(5.0)
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/chevron-left.svg"
                    onClicked: if (root.activePlaybackManager)
                        root.activePlaybackManager.stepBackward(1)
                }

                XylaIconButton {
                    iconSource: root.activePlaybackManager && root.activePlaybackManager.isPlaying && !root.activePlaybackManager.isPlayingReverse ? "qrc:/assets/icons/player-pause.svg" : "qrc:/assets/icons/player-play.svg"
                    primary: root.activePlaybackManager && root.activePlaybackManager.isPlaying && !root.activePlaybackManager.isPlayingReverse
                    onClicked: if (root.activePlaybackManager)
                        root.activePlaybackManager.togglePlay()
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/player-play-reverse.svg"
                    primary: root.activePlaybackManager && root.activePlaybackManager.isPlaying && root.activePlaybackManager.isPlayingReverse
                    onClicked: {
                        if (root.activePlaybackManager) {
                            if (root.activePlaybackManager.isPlaying && root.activePlaybackManager.isPlayingReverse) {
                                root.activePlaybackManager.pause();
                            } else {
                                root.activePlaybackManager.playReverse();
                            }
                        }
                    }
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/chevron-right.svg"
                    onClicked: if (root.activePlaybackManager)
                        root.activePlaybackManager.stepForward(1)
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/player-skip-forward.svg"
                    onClicked: if (root.activePlaybackManager)
                        root.activePlaybackManager.jumpForwardSeconds(5.0)
                }

                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 26
                    color: "#121212"
                    border.color: root.borderDark
                    border.width: 1
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: root.formatTimecode(root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0)
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Monospace"
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }

        // Timeline Ruler Bar
        XylaTimelineRuler {
            id: timelineRuler
            Layout.fillWidth: true
            headerWidth: root.headerWidth + root.playheadMargin
            zoomFactor: root.zoomFactor
            horizontalOffset: root.horizontalOffset
            contentWidth: root.contentWidth
            fps: root.activeProjectInfo ? root.activeProjectInfo.fps : 30.0
            z: 250
        }

        // Track List Lanes Area
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
                                    clipRepeater.refreshClips();
                                    root.updateContentWidth();
                                }
                            }
                            function onTrackCountChanged() {
                                clipRepeater.refreshClips();
                                root.updateContentWidth();
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
                                    var projFps = root.activeProjectInfo ? root.activeProjectInfo.fps : 30.0;
                                    var assetDuration = (typeof mediaPool !== "undefined" && mediaPool) ? mediaPool.getAssetDurationFrames(realAssetId, projFps) : 150;

                                    root.activeTimelineModel.addClip(realAssetId, assetName, delegateRow.trackIdx, dropFrame, assetDuration, 0);
                                    root.updateContentWidth();
                                }
                            }

                            Repeater {
                                id: clipRepeater
                                z: 10
                                model: []

                                function refreshClips() {
                                    if (root.activeTimelineModel) {
                                        model = root.activeTimelineModel.getClipsForTrack(delegateRow.trackIdx);
                                    } else {
                                        model = [];
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

            // Global 2D Middle-Mouse Pan & Zoom Wheel Handler over the track area
            MouseArea {
                id: globalTrackPanArea
                x: root.headerWidth
                width: parent.width - root.headerWidth
                height: parent.height
                z: 5 // Sits behind clip cards (z: 10) so clip drags work, but catches empty space & middle click

                acceptedButtons: Qt.MiddleButton
                hoverEnabled: false
                cursorShape: root.isMiddlePanning ? Qt.ClosedHandCursor : Qt.ArrowCursor

                property real startMouseX: 0
                property real startMouseY: 0
                property real startHorizOffset: 0
                property real startContentY: 0

                onPressed: function (mouse) {
                    if (mouse.button === Qt.MiddleButton) {
                        root.isMiddlePanning = true;
                        startMouseX = mouse.x;
                        startMouseY = mouse.y;
                        startHorizOffset = root.horizontalOffset;
                        startContentY = trackListView.contentY;
                    }
                }

                onPositionChanged: function (mouse) {
                    if (root.isMiddlePanning) {
                        // 1. Horizontal Time Pan
                        var dx = startMouseX - mouse.x;
                        var maxOffset = Math.max(0, root.contentWidth - (trackListView.width - root.headerWidth));
                        root.horizontalOffset = Math.max(0, Math.min(maxOffset, startHorizOffset + dx));

                        // 2. Vertical Track Pan
                        var dy = startMouseY - mouse.y;
                        var maxContentY = Math.max(0, trackListView.contentHeight - trackListView.height);
                        trackListView.contentY = Math.max(0, Math.min(maxContentY, startContentY + dy));
                    }
                }

                onReleased: function (mouse) {
                    if (mouse.button === Qt.MiddleButton) {
                        root.isMiddlePanning = false;
                    }
                }

                onWheel: function (wheel) {
                    if (wheel.modifiers & Qt.ControlModifier) {
                        // Cursor-centered zoom
                        var factor = wheel.angleDelta.y > 0 ? 1.15 : 0.85;
                        root.zoomAroundCursor(factor, wheel.x + root.headerWidth);
                    } else if (wheel.modifiers & Qt.ShiftModifier || wheel.angleDelta.x !== 0) {
                        // Horizontal scroll
                        var deltaX = wheel.angleDelta.x !== 0 ? -wheel.angleDelta.x : -wheel.angleDelta.y;
                        var maxOffset = Math.max(0, root.contentWidth - (trackListView.width - root.headerWidth));
                        root.horizontalOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaX));
                    } else {
                        // Vertical track scroll
                        var deltaY = -wheel.angleDelta.y;
                        var maxContentY = Math.max(0, trackListView.contentHeight - trackListView.height);
                        trackListView.contentY = Math.max(0, Math.min(maxContentY, trackListView.contentY + deltaY));
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

    // Clipped Right-Side Container for Playhead
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

    // Sidebar Horizontal Resizer
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
}
