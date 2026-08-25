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

    property int headerWidth: 350
    property int minHeaderWidth: 220
    property int maxHeaderWidth: 600

    property double zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real contentWidth: 3600

    readonly property color bgDark: "#1a1a1a"
    readonly property color bgHeader: "#181818"
    readonly property color borderDark: "#2d2d2d"

    function frameToPx(frame) {
        return frame * root.zoomFactor;
    }
    function pxToFrame(px) {
        return Math.max(0, Math.round(px / root.zoomFactor));
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
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                XylaIconButton {
                    iconSource: root.activePlaybackManager && root.activePlaybackManager.isPlaying ? "qrc:/assets/icons/minus.svg" : "qrc:/assets/icons/arrow-right.svg"
                    onClicked: {
                        if (root.activePlaybackManager) {
                            root.activePlaybackManager.togglePlay();
                        }
                    }
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/arrow-left.svg"
                    onClicked: {
                        if (root.activePlaybackManager) {
                            root.activePlaybackManager.stepBackward(1);
                        }
                    }
                }

                XylaIconButton {
                    iconSource: "qrc:/assets/icons/arrow-right.svg"
                    onClicked: {
                        if (root.activePlaybackManager) {
                            root.activePlaybackManager.stepForward(1);
                        }
                    }
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
                    }

                    Item {
                        id: trackLane
                        width: delegateRow.width - root.headerWidth
                        height: parent.height
                        clip: true

                        Connections {
                            target: root.activeTimelineModel ? root.activeTimelineModel : null
                            function onTrackDataChanged(updatedTrackIndex) {
                                if (updatedTrackIndex === delegateRow.trackIdx) {
                                    clipRepeater.refreshClips();
                                }
                            }
                            function onTrackCountChanged() {
                                clipRepeater.refreshClips();
                            }
                        }

                        Item {
                            x: -root.horizontalOffset
                            width: root.contentWidth
                            height: parent.height

                            Rectangle {
                                anchors.fill: parent
                                color: delegateRow.trackIdx % 2 === 0 ? "#151515" : "#121212"
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

                                    var dropFrame = root.pxToFrame(drop.x);
                                    var projFps = root.activeProjectInfo ? root.activeProjectInfo.fps : 30.0;
                                    var assetDuration = mediaPool ? mediaPool.getAssetDurationFrames(rawUrl, projFps) : 150;

                                    root.activeTimelineModel.addClip(rawUrl, assetName, delegateRow.trackIdx, dropFrame, assetDuration, 0);
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

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: false

                            onWheel: function (wheel) {
                                var maxOffset = Math.max(0, root.contentWidth - (delegateRow.width - root.headerWidth));

                                if (wheel.angleDelta.x !== 0) {
                                    var deltaX = -wheel.angleDelta.x;
                                    root.horizontalOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaX));
                                } else if (wheel.modifiers & Qt.ShiftModifier) {
                                    var deltaShift = -wheel.angleDelta.y;
                                    root.horizontalOffset = Math.max(0, Math.min(maxOffset, root.horizontalOffset + deltaShift));
                                } else {
                                    wheel.accepted = false;
                                }
                            }
                        }
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

    // Playhead Line Overlay
    XylaPlayhead {
        currentFrame: root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0
        zoomFactor: root.zoomFactor
        headerWidth: root.headerWidth
        horizontalOffset: root.horizontalOffset
        timelineContainer: root
        y: topToolBar.height
        height: parent.height - y
        x: root.headerWidth + (currentFrame * zoomFactor) - root.horizontalOffset
        z: 200
    }

    // Sidebar Horizontal Resizer
    Item {
        id: sidebarResizer
        width: 8
        x: root.headerWidth - 4
        y: topToolBar.height
        height: parent.height - y
        z: 100

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
