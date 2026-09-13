import QtQuick
import QtQuick.Controls
import Xyla.Render 1.0
import "./sections"

Item {
    id: root

    enum Mode {
        Timeline,
        Clip
    }

    property int mode: BaseMonitor.Mode.Timeline
    property bool showFooter: true
    property string activeDockId: mode === BaseMonitor.Mode.Timeline ? "ProjectmonitorPanel" : "ClipmonitorPanel"

    readonly property bool isClipMode: root.mode === BaseMonitor.Mode.Clip

    readonly property bool isCurrentlyPlaying: {
        if (isClipMode) {
            return (typeof clipMonitorController !== "undefined" && clipMonitorController) ? Boolean(clipMonitorController.isPlaying) : false;
        } else {
            return (typeof playbackManager !== "undefined" && playbackManager) ? Boolean(playbackManager.isPlaying) : false;
        }
    }

    readonly property int currentFrame: {
        if (isClipMode) {
            return (typeof clipMonitorController !== "undefined" && clipMonitorController && clipMonitorController.currentFrame !== undefined) ? clipMonitorController.currentFrame : 0;
        } else {
            return (typeof playbackManager !== "undefined" && playbackManager && playbackManager.currentFrame !== undefined) ? playbackManager.currentFrame : 0;
        }
    }

    readonly property int totalFrames: {
        if (isClipMode) {
            return (typeof clipMonitorController !== "undefined" && clipMonitorController && clipMonitorController.totalFrames !== undefined) ? clipMonitorController.totalFrames : 0;
        } else {
            if (typeof timelineModel !== "undefined" && timelineModel && timelineModel.durationFrames !== undefined) {
                return timelineModel.durationFrames;
            } else if (typeof projectManager !== "undefined" && projectManager && projectManager.activeProject) {
                return projectManager.activeProject.durationFrames || 0;
            }
            return 0;
        }
    }

    readonly property real activeFps: {
        if (isClipMode) {
            return (typeof clipMonitorController !== "undefined" && clipMonitorController && clipMonitorController.fps > 0) ? clipMonitorController.fps : 30.0;
        } else {
            return (typeof timelineModel !== "undefined" && timelineModel && timelineModel.fps > 0) ? timelineModel.fps : 30.0;
        }
    }

    function doSeek(frame) {
        if (isClipMode) {
            if (typeof clipMonitorController !== "undefined" && clipMonitorController) {
                clipMonitorController.seekFrame(frame);
            }
        } else {
            if (typeof playbackManager !== "undefined" && playbackManager) {
                playbackManager.scrubToFrame(frame);
            }
        }
    }

    function doStepBackward() {
        if (isClipMode) {
            if (typeof clipMonitorController !== "undefined" && clipMonitorController)
                clipMonitorController.stepBackward();
        } else {
            if (typeof playbackManager !== "undefined" && playbackManager)
                playbackManager.stepBackward();
        }
    }

    function doTogglePlay() {
        if (isClipMode) {
            if (typeof clipMonitorController !== "undefined" && clipMonitorController)
                clipMonitorController.togglePlay();
        } else {
            if (typeof playbackManager !== "undefined" && playbackManager)
                playbackManager.togglePlay();
        }
    }

    function doStepForward() {
        if (isClipMode) {
            if (typeof clipMonitorController !== "undefined" && clipMonitorController)
                clipMonitorController.stepForward();
        } else {
            if (typeof playbackManager !== "undefined" && playbackManager)
                playbackManager.stepForward();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#101012"
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered && typeof layoutController !== "undefined" && layoutController) {
                layoutController.setActiveDockId(root.activeDockId);
            }
        }
    }

    XylaVideoSurface {
        id: videoSurface
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: monitorFooter.top
        visible: !root.isClipMode || (typeof clipMonitorController !== "undefined" && clipMonitorController && clipMonitorController.hasVideo)

        surfaceType: root.mode === BaseMonitor.Mode.Timeline ? 0 : 1

        Connections {
            target: (!root.isClipMode && typeof timelineCompositor !== "undefined") ? timelineCompositor : null
            function onFrameComposited() {
                videoSurface.onFrameComposited();
            }
        }

        Connections {
            target: (root.isClipMode && typeof clipMonitorController !== "undefined") ? clipMonitorController : null
            function onFrameComposited() {
                videoSurface.onFrameComposited();
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: monitorFooter.top
        color: "#141416"
        visible: root.isClipMode && typeof clipMonitorController !== "undefined" && clipMonitorController && !clipMonitorController.hasVideo && clipMonitorController.hasAudio

        Text {
            anchors.centerIn: parent
            text: "Audio Clip Preview"
            color: "#666666"
            font.pixelSize: 14
        }
    }

    MonitorFooter {
        id: monitorFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.showFooter

        isCurrentlyPlaying: root.isCurrentlyPlaying
        currentFrame: root.currentFrame
        totalFrames: root.totalFrames
        activeFps: root.activeFps

        onSeekRequested: function (frame) {
            root.doSeek(frame);
        }
        onStepBackward: root.doStepBackward()
        onTogglePlay: root.doTogglePlay()
        onStepForward: root.doStepForward()

        onInsertRequested: {
            if (typeof timelineModel !== "undefined" && timelineModel && typeof clipMonitorController !== "undefined" && clipMonitorController) {
                timelineModel.insertClip(clipMonitorController.currentAssetId, monitorFooter.inPoint, monitorFooter.outPoint);
            }
        }

        onOverwriteRequested: {
            if (typeof timelineModel !== "undefined" && timelineModel && typeof clipMonitorController !== "undefined" && clipMonitorController) {
                timelineModel.overwriteClip(clipMonitorController.currentAssetId, monitorFooter.inPoint, monitorFooter.outPoint);
            }
        }
    }
}
