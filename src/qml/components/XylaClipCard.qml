import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var clipData: null
    property double zoomFactor: 1.0
    property int trackIndex: 0

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null

    property string activeSelectedId: activeTimelineModel?.selectedClipId ?? ""
    property bool isSelected: clipData && activeSelectedId !== "" && clipData.clipId === activeSelectedId

    property real localStartFrame: Number(clipData?.startFrame ?? 0)
    property real localDurationFrames: Number(clipData?.durationFrames ?? 30)
    property real localSourceInFrame: Number(clipData?.sourceInFrame ?? 0)
    property int localTrackIndex: root.trackIndex
    property int startTrackIndex: 0

    property real committedSourceInFrame: Number(clipData?.sourceInFrame ?? 0)
    property real committedDurationFrames: Number(clipData?.durationFrames ?? 30)

    readonly property real totalSourceDuration: Number(clipData?.sourceDurationFrames ?? Infinity)

    property bool isDragging: false
    property bool isTrimmingLeft: false
    property bool isTrimmingRight: false

    readonly property real currentTrackHeight: root.parent ? root.parent.height : 48

    x: ((isDragging || isTrimmingLeft) ? localStartFrame : Number(clipData?.startFrame ?? 0)) * root.zoomFactor
    width: ((isTrimmingLeft || isTrimmingRight) ? localDurationFrames : Math.max(20, Number(clipData?.durationFrames ?? 100))) * root.zoomFactor
    height: parent ? Math.max(30, parent.height - 8) : 40

    y: isDragging ? (4 + (localTrackIndex - startTrackIndex) * currentTrackHeight) : 4
    z: isDragging ? 9999 : 190

    Behavior on y {
        enabled: root.isDragging
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutCubic
        }
    }

    onIsDraggingChanged: {
        var p = parent;
        while (p) {
            if (p.trackIdx !== undefined) {
                p.z = isDragging ? 9999 : 0;
                break;
            }
            p = p.parent;
        }
    }

    function selectThisClip() {
        if (!root.activeTimelineModel || !root.clipData)
            return;
        if (typeof root.activeTimelineModel.selectClip === "function") {
            root.activeTimelineModel.selectClip(root.clipData.clipId);
        } else {
            root.activeTimelineModel.selectedClipId = root.clipData.clipId;
        }
    }

    function getTrackBounds(targetTrack, fromStartFrame, duration) {
        var minF = 0;
        var maxF = Infinity;
        if (!root.activeTimelineModel)
            return {
                min: minF,
                max: maxF
            };

        var clips = root.activeTimelineModel.getClipsForTrack(targetTrack);
        for (var i = 0; i < clips.length; ++i) {
            var c = clips[i];
            if (c.clipId === root.clipData?.clipId)
                continue;
            var cStart = Number(c.startFrame);
            var cEnd = cStart + Number(c.durationFrames);

            if (cEnd <= fromStartFrame) {
                minF = Math.max(minF, cEnd);
            } else if (cStart >= fromStartFrame + duration) {
                maxF = Math.min(maxF, cStart - duration);
            }
        }
        return {
            min: minF,
            max: maxF
        };
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.114, 0.365, 0.859, 0.3)
        border.color: (root.isSelected || root.isDragging || root.isTrimmingLeft || root.isTrimmingRight) ? "#3B82F6" : Qt.rgba(0.114, 0.365, 0.859, 0.5)
        border.width: 1
        radius: 0
        clip: true

        Image {
            id: leftThumbnail
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 3
            width: Math.min(height * 1.77, (parent.width - 20) / 2)
            fillMode: Image.PreserveAspectCrop
            visible: width > 15
            source: root.clipData ? ("image://thumbnails/" + root.clipData.assetId + "?time=" + (root.committedSourceInFrame / 30.0) + "&width=160") : ""
            asynchronous: true
            cache: true
        }

        Image {
            id: rightThumbnail
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 3
            width: Math.min(height * 1.77, (parent.width - 20) / 2)
            fillMode: Image.PreserveAspectCrop
            visible: width > 15 && parent.width > (width * 2 + 30)
            source: root.clipData ? ("image://thumbnails/" + root.clipData.assetId + "?time=" + ((root.committedSourceInFrame + root.committedDurationFrames) / 30.0) + "&width=160") : ""
            asynchronous: true
            cache: true
        }

        Rectangle {
            id: namePill
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 6
            height: 20
            width: Math.min(parent.width - 12, nameText.implicitWidth + 16)
            color: "#1D5DDB"
            radius: 4
            z: 20

            Text {
                id: nameText
                anchors.centerIn: parent
                text: root.clipData?.name ?? "Clip"
                color: "#ffffff"
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                width: parent.width - 12
            }
        }
    }

    MouseArea {
        id: moveMouse
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        hoverEnabled: true
        cursorShape: moveMouse.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: true

        property real startMouseGlobalX: 0
        property real startMouseGlobalY: 0
        property int startClipFrame: 0
        property int clipDuration: 0

        onPressed: function (mouse) {
            root.selectThisClip();
            root.isDragging = true;

            if (!root.clipData)
                return;
            var globalPt = mapToItem(null, mouse.x, mouse.y);
            startMouseGlobalX = globalPt.x;
            startMouseGlobalY = globalPt.y;

            startClipFrame = Number(root.clipData.startFrame);
            clipDuration = Number(root.clipData.durationFrames);
            root.startTrackIndex = root.trackIndex;
            root.localStartFrame = startClipFrame;
            root.localTrackIndex = root.trackIndex;
        }

        onPositionChanged: function (mouse) {
            if (!pressed || !root.clipData)
                return;
            var globalPt = mapToItem(null, mouse.x, mouse.y);

            var deltaPy = globalPt.y - startMouseGlobalY;
            var deltaTracks = Math.round(deltaPy / root.currentTrackHeight);
            var maxTrack = root.activeTimelineModel?.rowCount ? Math.max(0, root.activeTimelineModel.rowCount() - 1) : 10;
            var targetTrack = Math.max(0, Math.min(maxTrack, root.startTrackIndex + deltaTracks));
            root.localTrackIndex = targetTrack;

            var deltaPx = globalPt.x - startMouseGlobalX;
            var deltaFrames = Math.round(deltaPx / root.zoomFactor);
            var targetStart = startClipFrame + deltaFrames;

            var bounds = root.getTrackBounds(targetTrack, startClipFrame, clipDuration);
            root.localStartFrame = Math.max(bounds.min, Math.min(bounds.max, targetStart));
        }

        onReleased: function () {
            root.isDragging = false;
            if (root.activeTimelineModel && root.clipData) {
                root.activeTimelineModel.moveClip(root.clipData.clipId, root.trackIndex, root.localTrackIndex, Math.round(root.localStartFrame));
            }
        }
    }

    Rectangle {
        id: leftTrim
        width: 2
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: leftTrimMouse.containsMouse || leftTrimMouse.pressed ? "#60A5FA" : "#1D5DDB"
        z: 100

        MouseArea {
            id: leftTrimMouse
            anchors.fill: parent
            anchors.leftMargin: -3
            anchors.rightMargin: -3
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            property real startMouseGlobalX: 0
            property int startFrame: 0
            property int startDur: 0
            property int startIn: 0
            property int leftNeighborEnd: 0

            onPressed: function (mouse) {
                root.selectThisClip();
                root.isTrimmingLeft = true;

                if (!root.clipData)
                    return;
                var globalPt = mapToItem(null, mouse.x, mouse.y);
                startMouseGlobalX = globalPt.x;
                startFrame = Number(root.clipData.startFrame);
                startDur = Number(root.clipData.durationFrames);
                startIn = Number(root.clipData.sourceInFrame);

                root.localStartFrame = startFrame;
                root.localDurationFrames = startDur;
                root.localSourceInFrame = startIn;

                leftNeighborEnd = root.getTrackBounds(root.trackIndex, startFrame, startDur).min;
            }

            onPositionChanged: function (mouse) {
                if (!pressed || !root.clipData)
                    return;
                var globalPt = mapToItem(null, mouse.x, mouse.y);
                var deltaPx = globalPt.x - startMouseGlobalX;
                var deltaFrames = Math.round(deltaPx / root.zoomFactor);

                var maxAllowedDelta = startDur - 1;
                var minAllowedDelta = -Math.min(startFrame - leftNeighborEnd, startIn);
                var clampedDelta = Math.max(minAllowedDelta, Math.min(maxAllowedDelta, deltaFrames));

                root.localStartFrame = startFrame + clampedDelta;
                root.localDurationFrames = startDur - clampedDelta;
                root.localSourceInFrame = startIn + clampedDelta;
            }

            onReleased: function () {
                root.isTrimmingLeft = false;
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Math.round(root.localStartFrame), Math.round(root.localDurationFrames), Math.round(root.localSourceInFrame), false);
                }
            }
        }
    }

    Rectangle {
        id: rightTrim
        width: 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: rightTrimMouse.containsMouse || rightTrimMouse.pressed ? "#60A5FA" : "#1D5DDB"
        z: 100

        MouseArea {
            id: rightTrimMouse
            anchors.fill: parent
            anchors.leftMargin: -3
            anchors.rightMargin: -3
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            property real startMouseGlobalX: 0
            property int startDur: 0
            property int startIn: 0
            property int maxAllowedRight: Infinity

            onPressed: function (mouse) {
                root.selectThisClip();
                root.isTrimmingRight = true;

                if (!root.clipData)
                    return;
                var globalPt = mapToItem(null, mouse.x, mouse.y);
                startMouseGlobalX = globalPt.x;
                startDur = Number(root.clipData.durationFrames);
                startIn = Number(root.clipData.sourceInFrame);
                root.localDurationFrames = startDur;

                var trackBounds = root.getTrackBounds(root.trackIndex, Number(root.clipData.startFrame), startDur);
                maxAllowedRight = isFinite(trackBounds.max) ? (trackBounds.max + startDur - Number(root.clipData.startFrame)) : Infinity;
            }

            onPositionChanged: function (mouse) {
                if (!pressed || !root.clipData)
                    return;
                var globalPt = mapToItem(null, mouse.x, mouse.y);
                var deltaPx = globalPt.x - startMouseGlobalX;
                var deltaFrames = Math.round(deltaPx / root.zoomFactor);

                var maxSourceAvail = isFinite(root.totalSourceDuration) ? (root.totalSourceDuration - startIn) : Infinity;
                var hardMax = Math.min(maxSourceAvail, maxAllowedRight);
                var newDur = Math.max(1, Math.min(hardMax, startDur + deltaFrames));

                root.localDurationFrames = newDur;
            }

            onReleased: function () {
                root.isTrimmingRight = false;
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Number(root.clipData.startFrame), Math.round(root.localDurationFrames), Number(root.clipData.sourceInFrame), false);
                }
            }
        }
    }
}
