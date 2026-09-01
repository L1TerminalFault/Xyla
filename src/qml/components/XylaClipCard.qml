import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var timelineRoot: null
    property var clipData: null
    property double zoomFactor: 1.0
    readonly property int trackIndex: Number(clipData?.trackIndex ?? 0)

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null

    readonly property bool isSelected: root.activeTimelineModel ? (root.activeTimelineModel.selectedClipIds?.indexOf(root.clipData?.clipId ?? "") !== -1) : false

    readonly property bool isGroupFollower: root.isSelected && !root.isDragging && (root.activeTimelineModel?.groupDragLeaderId ?? "") !== ""
    readonly property int groupDeltaFrames: isGroupFollower ? (root.activeTimelineModel?.groupDragDeltaFrames ?? 0) : 0
    readonly property int groupDeltaTracks: isGroupFollower ? (root.activeTimelineModel?.groupDragDeltaTracks ?? 0) : 0

    property real localStartFrame: Number(clipData?.startFrame ?? 0)
    property real localDurationFrames: Number(clipData?.durationFrames ?? 30)
    property real localSourceInFrame: Number(clipData?.sourceInFrame ?? 0)
    property int localTrackIndex: root.trackIndex

    property real committedSourceInFrame: Number(clipData?.sourceInFrame ?? 0)
    property real committedDurationFrames: Number(clipData?.durationFrames ?? 30)
    readonly property real totalSourceDuration: Number(clipData?.sourceDurationFrames ?? Infinity)

    property bool isDragging: false
    property bool isTrimmingLeft: false
    property bool isTrimmingRight: false

    // Dynamic 2D Position & Height
    x: ((isDragging || isTrimmingLeft) ? localStartFrame : (Number(clipData?.startFrame ?? 0) + groupDeltaFrames)) * root.zoomFactor
    y: (root.timelineRoot ? root.timelineRoot.getTrackY(isDragging ? localTrackIndex : (root.trackIndex + groupDeltaTracks)) : (root.trackIndex * 68)) + 4
    width: ((isTrimmingLeft || isTrimmingRight) ? localDurationFrames : Math.max(20, Number(clipData?.durationFrames ?? 100))) * root.zoomFactor
    height: (root.timelineRoot ? root.timelineRoot.getTrackHeight(isDragging ? localTrackIndex : (root.trackIndex + groupDeltaTracks)) : 68) - 8

    z: (isDragging || isGroupFollower) ? 100 : 10

    function getSelectionGroupBounds() {
        var minStart = Number(clipData?.startFrame ?? 0);
        var minTrack = root.trackIndex;
        var maxTrack = root.trackIndex;
        if (!root.activeTimelineModel || root.activeTimelineModel.selectedClipIds.length <= 1) {
            return {
                minStart: minStart,
                minTrack: minTrack,
                maxTrack: maxTrack
            };
        }

        var selIds = root.activeTimelineModel.selectedClipIds;
        var totalTracks = root.activeTimelineModel.rowCount();

        for (var t = 0; t < totalTracks; ++t) {
            var clips = root.activeTimelineModel.getClipsForTrack(t);
            for (var i = 0; i < clips.length; ++i) {
                var c = clips[i];
                if (selIds.indexOf(c.clipId) !== -1) {
                    var s = Number(c.startFrame);
                    if (s < minStart)
                        minStart = s;
                    if (t < minTrack)
                        minTrack = t;
                    if (t > maxTrack)
                        maxTrack = t;
                }
            }
        }
        return {
            minStart: minStart,
            minTrack: minTrack,
            maxTrack: maxTrack
        };
    }

    function calculateGroupLimits(trackShift) {
        var minDeltaF = -Infinity;
        var maxDeltaF = Infinity;
        if (!root.activeTimelineModel)
            return {
                minDelta: -localStartFrame,
                maxDelta: Infinity
            };

        var selIds = root.activeTimelineModel.selectedClipIds ?? [];
        if (selIds.length === 0)
            selIds = [root.clipData?.clipId];

        var totalTracks = root.activeTimelineModel.rowCount();

        for (var t = 0; t < totalTracks; ++t) {
            var destTrack = t + trackShift;
            if (destTrack < 0 || destTrack >= totalTracks)
                continue;
            var clipsOnSrc = root.activeTimelineModel.getClipsForTrack(t);
            var clipsOnDest = root.activeTimelineModel.getClipsForTrack(destTrack);

            for (var i = 0; i < clipsOnSrc.length; ++i) {
                var c = clipsOnSrc[i];
                if (selIds.indexOf(c.clipId) === -1)
                    continue;
                var cStart = Number(c.startFrame);
                var cEnd = cStart + Number(c.durationFrames);

                minDeltaF = Math.max(minDeltaF, -cStart);

                for (var j = 0; j < clipsOnDest.length; ++j) {
                    var other = clipsOnDest[j];
                    if (selIds.indexOf(other.clipId) !== -1)
                        continue;
                    var otherStart = Number(other.startFrame);
                    var otherEnd = otherStart + Number(other.durationFrames);

                    if (otherEnd <= cStart) {
                        minDeltaF = Math.max(minDeltaF, otherEnd - cStart);
                    }
                    if (otherStart >= cEnd) {
                        maxDeltaF = Math.min(maxDeltaF, otherStart - cEnd);
                    }
                }
            }
        }
        return {
            minDelta: isFinite(minDeltaF) ? minDeltaF : -localStartFrame,
            maxDelta: isFinite(maxDeltaF) ? maxDeltaF : Infinity
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
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: moveMouse.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        preventStealing: true

        property real startCanvasMouseX: 0
        property real startCanvasMouseY: 0
        property int startClipFrame: 0
        property int startTrackIdx: 0
        property bool didDrag: false

        property int groupMinTrack: 0
        property int groupMaxTrack: 0

        onPressed: function (mouse) {
            didDrag = false;
            var isToggle = (mouse.modifiers & Qt.ControlModifier) || (mouse.modifiers & Qt.MetaModifier);
            var isRange = (mouse.modifiers & Qt.ShiftModifier);

            if (isToggle || isRange || !root.isSelected) {
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.selectClip(root.clipData.clipId, isToggle, isRange);
                }
            }

            root.isDragging = true;
            if (!root.clipData)
                return;
            var pt = mapToItem(root.parent, mouse.x, mouse.y);
            startCanvasMouseX = pt.x;
            startCanvasMouseY = pt.y;

            startClipFrame = Number(root.clipData.startFrame);
            startTrackIdx = root.trackIndex;
            root.localStartFrame = startClipFrame;
            root.localTrackIndex = root.trackIndex;

            var bounds = root.getSelectionGroupBounds();
            groupMinTrack = bounds.minTrack;
            groupMaxTrack = bounds.maxTrack;

            if (root.isSelected && root.activeTimelineModel) {
                root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, 0, 0);
            }
        }

        onPositionChanged: function (mouse) {
            if (!pressed || !root.clipData)
                return;
            didDrag = true;

            var pt = mapToItem(root.parent, mouse.x, mouse.y);
            var deltaPx = pt.x - startCanvasMouseX;

            var totalTracks = root.activeTimelineModel?.rowCount ? root.activeTimelineModel.rowCount() : 1;
            var maxTrackIndex = Math.max(0, totalTracks - 1);

            // Dynamic track hit-testing from hovered Y
            var hoveredTrack = root.timelineRoot ? root.timelineRoot.getTrackAtY(pt.y) : startTrackIdx;
            var rawDeltaTracks = hoveredTrack - startTrackIdx;
            var minAllowedDeltaTracks = -groupMinTrack;
            var maxAllowedDeltaTracks = maxTrackIndex - groupMaxTrack;
            var deltaTracks = Math.max(minAllowedDeltaTracks, Math.min(maxAllowedDeltaTracks, rawDeltaTracks));
            root.localTrackIndex = startTrackIdx + deltaTracks;

            // Horizontal Frame delta
            var rawDeltaFrames = Math.round(deltaPx / root.zoomFactor);
            var groupLimits = root.calculateGroupLimits(deltaTracks);
            var deltaFrames = Math.max(groupLimits.minDelta, Math.min(groupLimits.maxDelta, rawDeltaFrames));
            root.localStartFrame = startClipFrame + deltaFrames;

            if (root.isSelected && root.activeTimelineModel && root.activeTimelineModel.groupDragLeaderId === root.clipData.clipId) {
                root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, deltaFrames, deltaTracks);
            }
        }

        onReleased: function () {
            root.isDragging = false;
            if (!root.activeTimelineModel || !root.clipData)
                return;
            var deltaFrames = Math.round(root.localStartFrame - startClipFrame);
            var deltaTracks = root.localTrackIndex - startTrackIdx;

            if (root.activeTimelineModel.selectedClipIds.length > 1) {
                root.activeTimelineModel.moveClips(root.activeTimelineModel.selectedClipIds, deltaFrames, deltaTracks);
            } else {
                root.activeTimelineModel.moveClip(root.clipData.clipId, root.trackIndex, root.localTrackIndex, Math.round(root.localStartFrame));
            }

            root.activeTimelineModel.clearGroupDrag();
        }

        onClicked: function (mouse) {
            var isToggle = (mouse.modifiers & Qt.ControlModifier) || (mouse.modifiers & Qt.MetaModifier);
            var isRange = (mouse.modifiers & Qt.ShiftModifier);

            if (!didDrag && !isToggle && !isRange && root.isSelected && root.activeTimelineModel && root.clipData) {
                root.activeTimelineModel.selectClip(root.clipData.clipId, false, false);
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

            property real startCanvasX: 0
            property int startFrame: 0
            property int startDur: 0
            property int startIn: 0
            property int maxGrowLeft: 0

            onPressed: function (mouse) {
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.selectClip(root.clipData.clipId, false, false);
                }
                root.isTrimmingLeft = true;

                if (!root.clipData)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                startCanvasX = pt.x;

                startFrame = Number(root.clipData.startFrame);
                startDur = Number(root.clipData.durationFrames);
                startIn = Number(root.clipData.sourceInFrame);

                root.localStartFrame = startFrame;
                root.localDurationFrames = startDur;
                root.localSourceInFrame = startIn;

                var limits = root.calculateGroupLimits(0);
                maxGrowLeft = Math.min(startFrame - (startFrame + limits.minDelta), startIn);
            }

            onPositionChanged: function (mouse) {
                if (!pressed || !root.clipData)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                var deltaPx = pt.x - startCanvasX;
                var deltaFrames = Math.round(deltaPx / root.zoomFactor);

                var maxShrinkRight = startDur - 1;
                var clampedDelta = Math.max(-maxGrowLeft, Math.min(maxShrinkRight, deltaFrames));

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

            property real startCanvasX: 0
            property int startFrame: 0
            property int startDur: 0
            property int startIn: 0
            property int maxAllowedDuration: 0

            onPressed: function (mouse) {
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.selectClip(root.clipData.clipId, false, false);
                }
                root.isTrimmingRight = true;

                if (!root.clipData)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                startCanvasX = pt.x;

                startFrame = Number(root.clipData.startFrame);
                startDur = Number(root.clipData.durationFrames);
                startIn = Number(root.clipData.sourceInFrame);
                root.localDurationFrames = startDur;

                var maxFromSource = isFinite(root.totalSourceDuration) ? (root.totalSourceDuration - startIn) : Infinity;
                var limits = root.calculateGroupLimits(0);
                var maxFromNeighbor = isFinite(limits.maxDelta) ? (startDur + limits.maxDelta) : Infinity;

                maxAllowedDuration = Math.min(maxFromSource, maxFromNeighbor);
            }

            onPositionChanged: function (mouse) {
                if (!pressed || !root.clipData)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                var deltaPx = pt.x - startCanvasX;
                var deltaFrames = Math.round(deltaPx / root.zoomFactor);

                var newDur = Math.max(1, Math.min(maxAllowedDuration, startDur + deltaFrames));
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
