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

    function getMovingClips() {
        if (!root.activeTimelineModel || !root.clipData)
            return [];
        var selIds = root.activeTimelineModel.selectedClipIds ?? [];
        if (selIds.indexOf(root.clipData.clipId) === -1 || selIds.length <= 1) {
            return [
                {
                    clipId: root.clipData.clipId,
                    trackIndex: root.trackIndex,
                    startFrame: Number(root.clipData.startFrame),
                    durationFrames: Number(root.clipData.durationFrames)
                }
            ];
        }

        var list = [];
        var totalTracks = root.activeTimelineModel.rowCount();
        for (var t = 0; t < totalTracks; ++t) {
            var clips = root.activeTimelineModel.getClipsForTrack(t);
            for (var i = 0; i < clips.length; ++i) {
                var c = clips[i];
                if (selIds.indexOf(c.clipId) !== -1) {
                    list.push({
                        clipId: c.clipId,
                        trackIndex: t,
                        startFrame: Number(c.startFrame),
                        durationFrames: Number(c.durationFrames)
                    });
                }
            }
        }
        return list;
    }

    function getSelectionGroupBounds() {
        var moving = getMovingClips();
        var minStart = Infinity;
        var minTrack = Infinity;
        var maxTrack = -Infinity;

        for (var i = 0; i < moving.length; ++i) {
            var c = moving[i];
            if (c.startFrame < minStart)
                minStart = c.startFrame;
            if (c.trackIndex < minTrack)
                minTrack = c.trackIndex;
            if (c.trackIndex > maxTrack)
                maxTrack = c.trackIndex;
        }

        return {
            minStart: isFinite(minStart) ? minStart : Number(clipData?.startFrame ?? 0),
            minTrack: isFinite(minTrack) ? minTrack : root.trackIndex,
            maxTrack: isFinite(maxTrack) ? maxTrack : root.trackIndex
        };
    }

    // Comprehensive Group-Aware Collision & Jump Resolver
    function resolvePlacementDelta(rawDeltaFrames, trackShift) {
        if (!root.activeTimelineModel || !root.clipData)
            return rawDeltaFrames;

        var movingClips = getMovingClips();
        var selIds = root.activeTimelineModel.selectedClipIds ?? [];
        if (selIds.indexOf(root.clipData.clipId) === -1)
            selIds = [root.clipData.clipId];

        var totalTracks = root.activeTimelineModel.rowCount ? root.activeTimelineModel.rowCount() : 1;

        // 1. Global limit so no clip in the group goes below frame 0
        var minAllowedDelta = -Infinity;
        for (var i = 0; i < movingClips.length; ++i) {
            minAllowedDelta = Math.max(minAllowedDelta, -movingClips[i].startFrame);
        }
        var candidateDelta = Math.max(minAllowedDelta, rawDeltaFrames);

        // Helper: Check collisions across ALL moving clips on their respective destination tracks
        function getGroupCollisions(delta) {
            var cols = [];
            for (var m = 0; m < movingClips.length; ++m) {
                var mc = movingClips[m];
                var dTrack = mc.trackIndex + trackShift;
                if (dTrack < 0 || dTrack >= totalTracks)
                    continue;

                var cStart = mc.startFrame + delta;
                var cEnd = cStart + mc.durationFrames;

                var trackClips = root.activeTimelineModel.getClipsForTrack(dTrack);
                for (var j = 0; j < trackClips.length; ++j) {
                    var obst = trackClips[j];
                    if (selIds.indexOf(obst.clipId) !== -1)
                        continue; // ignore clips in the moving selection

                    var oStart = Number(obst.startFrame);
                    var oEnd = oStart + Number(obst.durationFrames);

                    if (cStart < oEnd && cEnd > oStart) {
                        cols.push({
                            movingClip: mc,
                            obstacle: obst,
                            oStart: oStart,
                            oEnd: oEnd
                        });
                    }
                }
            }
            return cols;
        }

        // 2. If no clip in the group collides at the candidate position -> Clean Jump!
        var collisions = getGroupCollisions(candidateDelta);
        if (collisions.length === 0) {
            return candidateDelta;
        }

        // 3. If there are collisions, clamp the group flush against the blocking obstacle
        var bestDelta = 0;
        if (rawDeltaFrames >= 0) {
            // Dragging right -> snap before the earliest blocking obstacle
            var minSnap = Infinity;
            for (var c = 0; c < collisions.length; ++c) {
                var colR = collisions[c];
                var snapR = colR.oStart - colR.movingClip.durationFrames - colR.movingClip.startFrame;
                if (snapR < minSnap)
                    minSnap = snapR;
            }
            bestDelta = Math.max(minAllowedDelta, minSnap);
        } else {
            // Dragging left -> snap after the latest blocking obstacle
            var maxSnap = -Infinity;
            for (var d = 0; d < collisions.length; ++d) {
                var colL = collisions[d];
                var snapL = colL.oEnd - colL.movingClip.startFrame;
                if (snapL > maxSnap)
                    maxSnap = snapL;
            }
            bestDelta = Math.max(minAllowedDelta, maxSnap);
        }

        // 4. Verify that the snapped position is completely safe for all clips
        var verifyCols = getGroupCollisions(bestDelta);
        if (verifyCols.length === 0) {
            return bestDelta;
        }

        return 0; // Return to origin if no fit in the obstacle gap
    }

    function getImmediateNeighborBounds(trackIdx, currentStart, currentDur) {
        var minFrame = 0;
        var maxFrame = Infinity;
        if (!root.activeTimelineModel)
            return {
                minFrame: 0,
                maxFrame: Infinity
            };

        var clips = root.activeTimelineModel.getClipsForTrack(trackIdx);
        var myId = root.clipData?.clipId ?? "";

        for (var i = 0; i < clips.length; ++i) {
            var c = clips[i];
            if (c.clipId === myId)
                continue;
            var cStart = Number(c.startFrame);
            var cEnd = cStart + Number(c.durationFrames);

            if (cEnd <= currentStart && cEnd > minFrame) {
                minFrame = cEnd;
            }
            if (cStart >= (currentStart + currentDur) && cStart < maxFrame) {
                maxFrame = cStart;
            }
        }
        return {
            minFrame: minFrame,
            maxFrame: maxFrame
        };
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.114, 0.365, 0.859, 0.3)
        border.color: (root.isSelected || root.isDragging || root.isTrimmingLeft || root.isTrimmingRight) ? "#3B82F6" : Qt.rgba(0.114, 0.365, 0.859, 0.5)
        border.width: 1
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
        property bool isRippleMove: false

        property int groupMinTrack: 0
        property int groupMaxTrack: 0

        onPressed: function (mouse) {
            didDrag = false;
            var isToggle = (mouse.modifiers & Qt.ControlModifier) !== 0 || (mouse.modifiers & Qt.MetaModifier) !== 0;
            var isRange = (mouse.modifiers & Qt.ShiftModifier) !== 0;
            var hasCtrl = (mouse.modifiers & Qt.ControlModifier) !== 0;
            var hasAlt = (mouse.modifiers & Qt.AltModifier) !== 0;

            isRippleMove = hasCtrl && hasAlt;

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

            var hoveredTrack = root.timelineRoot ? root.timelineRoot.getTrackAtY(pt.y) : startTrackIdx;
            var rawDeltaTracks = hoveredTrack - startTrackIdx;
            var minAllowedDeltaTracks = -groupMinTrack;
            var maxAllowedDeltaTracks = maxTrackIndex - groupMaxTrack;
            var deltaTracks = Math.max(minAllowedDeltaTracks, Math.min(maxAllowedDeltaTracks, rawDeltaTracks));
            root.localTrackIndex = startTrackIdx + deltaTracks;

            var rawDeltaFrames = Math.round(deltaPx / root.zoomFactor);

            if (isRippleMove) {
                root.localStartFrame = Math.max(0, startClipFrame + rawDeltaFrames);
            } else {
                var deltaFrames = root.resolvePlacementDelta(rawDeltaFrames, deltaTracks);
                root.localStartFrame = startClipFrame + deltaFrames;
            }

            if (root.isSelected && root.activeTimelineModel && root.activeTimelineModel.groupDragLeaderId === root.clipData.clipId) {
                root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, root.localStartFrame - startClipFrame, deltaTracks);
            }
        }

        onReleased: function (mouse) {
            root.isDragging = false;
            if (!root.activeTimelineModel || !root.clipData)
                return;

            var deltaFrames = Math.round(root.localStartFrame - startClipFrame);
            var deltaTracks = root.localTrackIndex - startTrackIdx;

            if (isRippleMove) {
                var globalDefault = root.activeTimelineModel.globalRippleMode;
                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                var effectiveGlobal = hasShift ? !globalDefault : globalDefault;

                root.activeTimelineModel.rippleMoveClip(root.clipData.clipId, root.localTrackIndex, Math.round(root.localStartFrame), effectiveGlobal);
            } else if (root.activeTimelineModel.selectedClipIds.length > 1) {
                root.activeTimelineModel.moveClips(root.activeTimelineModel.selectedClipIds, deltaFrames, deltaTracks);
            } else {
                root.activeTimelineModel.moveClip(root.clipData.clipId, root.trackIndex, root.localTrackIndex, Math.round(root.localStartFrame));
            }

            root.activeTimelineModel.clearGroupDrag();
            isRippleMove = false;
        }

        onClicked: function (mouse) {
            var isToggle = (mouse.modifiers & Qt.ControlModifier) !== 0 || (mouse.modifiers & Qt.MetaModifier) !== 0;
            var isRange = (mouse.modifiers & Qt.ShiftModifier) !== 0;

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
            property int minBoundaryFrame: 0

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

                var bounds = root.getImmediateNeighborBounds(root.trackIndex, startFrame, startDur);
                minBoundaryFrame = Math.max(bounds.minFrame, startFrame - startIn);
            }

            onPositionChanged: function (mouse) {
                if (!pressed || !root.clipData)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                var deltaPx = pt.x - startCanvasX;
                var deltaFrames = Math.round(deltaPx / root.zoomFactor);

                var maxFrame = startFrame + startDur - 1;
                var newStartFrame = Math.max(minBoundaryFrame, Math.min(maxFrame, startFrame + deltaFrames));
                var appliedDelta = newStartFrame - startFrame;

                root.localStartFrame = newStartFrame;
                root.localDurationFrames = startDur - appliedDelta;
                root.localSourceInFrame = startIn + appliedDelta;
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
                var bounds = root.getImmediateNeighborBounds(root.trackIndex, startFrame, startDur);
                var maxFromNeighbor = bounds.maxFrame - startFrame;

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
