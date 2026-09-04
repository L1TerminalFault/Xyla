import QtQuick
import QtQuick.Controls

Item {
    id: root

    property var timelineRoot: null
    property var clipData: null
    property double zoomFactor: 1.0
    readonly property int trackIndex: Number(clipData?.trackIndex ?? 0)

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null

    // Track Kind Classification (Video = 0, Audio = 1)
    readonly property bool isAudioTrack: root.activeTimelineModel ? (root.activeTimelineModel.getTrackKind(root.trackIndex) === 1) : false

    // Linking Properties
    readonly property string linkGroupId: root.clipData?.linkGroupId ?? ""
    readonly property bool isLinked: linkGroupId.length > 0

    // Reactive Lock Properties
    property bool isClipExplicitlyLocked: root.clipData?.isLocked === true
    property bool isTrackLocked: root.activeTimelineModel ? root.activeTimelineModel.isTrackLocked(root.trackIndex) : false
    property bool isGroupLocked: root.activeTimelineModel ? root.activeTimelineModel.isClipOrGroupLocked(root.clipData?.clipId ?? "") : false
    readonly property bool isLocked: isClipExplicitlyLocked || isTrackLocked || isGroupLocked

    // Instant Signal Listeners from C++
    Connections {
        target: root.activeTimelineModel
        function onTrackDataChanged(t) {
            root.isTrackLocked = root.activeTimelineModel ? root.activeTimelineModel.isTrackLocked(root.trackIndex) : false;
            root.isGroupLocked = root.activeTimelineModel ? root.activeTimelineModel.isClipOrGroupLocked(root.clipData?.clipId ?? "") : false;
            if (waveformCanvas)
                waveformCanvas.requestPaint();
        }
        function onClipPropertiesChanged(cid) {
            if (root.clipData) {
                root.isClipExplicitlyLocked = root.activeTimelineModel ? root.activeTimelineModel.isClipLocked(root.clipData.clipId) : false;
                root.isGroupLocked = root.activeTimelineModel ? root.activeTimelineModel.isClipOrGroupLocked(root.clipData.clipId) : false;
            }
        }
    }

    onClipDataChanged: {
        isClipExplicitlyLocked = root.clipData?.isLocked === true;
        isTrackLocked = root.activeTimelineModel ? root.activeTimelineModel.isTrackLocked(root.trackIndex) : false;
        isGroupLocked = root.activeTimelineModel ? root.activeTimelineModel.isClipOrGroupLocked(root.clipData?.clipId ?? "") : false;
        if (waveformCanvas)
            waveformCanvas.requestPaint();
    }

    onIsLockedChanged: {
        if (lockPatternCanvas)
            lockPatternCanvas.requestPaint();
        if (waveformCanvas)
            waveformCanvas.requestPaint();
    }

    onZoomFactorChanged: {
        if (waveformCanvas)
            waveformCanvas.requestPaint();
    }

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

        var totalTracks = root.activeTimelineModel ? root.activeTimelineModel.rowCount() : 1;
        var myKind = root.activeTimelineModel ? root.activeTimelineModel.getTrackKind(root.trackIndex) : -1;

        var minAllowedTrack = 0;
        var maxAllowedTrack = Math.max(0, totalTracks - 1);

        if (root.activeTimelineModel && myKind !== -1) {
            var foundStart = -1;
            var foundEnd = -1;
            for (var t = 0; t < totalTracks; ++t) {
                if (root.activeTimelineModel.getTrackKind(t) === myKind) {
                    if (foundStart === -1)
                        foundStart = t;
                    foundEnd = t;
                }
            }
            if (foundStart !== -1) {
                minAllowedTrack = foundStart;
                maxAllowedTrack = foundEnd;
            }
        }

        return {
            minStart: isFinite(minStart) ? minStart : Number(clipData?.startFrame ?? 0),
            minTrack: isFinite(minTrack) ? minTrack : root.trackIndex,
            maxTrack: isFinite(maxTrack) ? maxTrack : root.trackIndex,
            kindMinTrack: minAllowedTrack,
            kindMaxTrack: maxAllowedTrack
        };
    }

    function resolvePlacementDelta(rawDeltaFrames, trackShift) {
        if (!root.activeTimelineModel || !root.clipData)
            return rawDeltaFrames;

        var movingClips = getMovingClips();
        var selIds = root.activeTimelineModel.selectedClipIds ?? [];
        if (selIds.indexOf(root.clipData.clipId) === -1)
            selIds = [root.clipData.clipId];

        var totalTracks = root.activeTimelineModel.rowCount ? root.activeTimelineModel.rowCount() : 1;

        var minAllowedDelta = -Infinity;
        for (var i = 0; i < movingClips.length; ++i) {
            minAllowedDelta = Math.max(minAllowedDelta, -movingClips[i].startFrame);
        }
        var candidateDelta = Math.max(minAllowedDelta, rawDeltaFrames);

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
                        continue;

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

        var collisions = getGroupCollisions(candidateDelta);
        if (collisions.length === 0) {
            return candidateDelta;
        }

        var bestDelta = 0;
        if (rawDeltaFrames >= 0) {
            var minSnap = Infinity;
            for (var c = 0; c < collisions.length; ++c) {
                var colR = collisions[c];
                var snapR = colR.oStart - colR.movingClip.durationFrames - colR.movingClip.startFrame;
                if (snapR < minSnap)
                    minSnap = snapR;
            }
            bestDelta = Math.max(minAllowedDelta, minSnap);
        } else {
            var maxSnap = -Infinity;
            for (var d = 0; d < collisions.length; ++d) {
                var colL = collisions[d];
                var snapL = colL.oEnd - colL.movingClip.startFrame;
                if (snapL > maxSnap)
                    maxSnap = snapL;
            }
            bestDelta = Math.max(minAllowedDelta, maxSnap);
        }

        var verifyCols = getGroupCollisions(bestDelta);
        if (verifyCols.length === 0) {
            return bestDelta;
        }

        return 0;
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

    // Main Card Body
    Rectangle {
        anchors.fill: parent
        // Video = Royal Blue (#1D5DDB), Audio = Rich Violet (#7C3AED)
        color: root.isLocked ? "#262626" : (root.isAudioTrack ? Qt.rgba(0.486, 0.227, 0.929, 0.28) : Qt.rgba(0.114, 0.365, 0.859, 0.3))
        border.color: (root.isSelected || root.isDragging || root.isTrimmingLeft || root.isTrimmingRight) ? (root.isAudioTrack ? "#A78BFA" : "#3B82F6") : (root.isLocked ? "#383838" : (root.isAudioTrack ? Qt.rgba(0.486, 0.227, 0.929, 0.55) : Qt.rgba(0.114, 0.365, 0.859, 0.5)))
        border.width: 1
        clip: true

        // Diagonal Striped Lock Pattern
        Canvas {
            id: lockPatternCanvas
            anchors.fill: parent
            visible: root.isLocked
            opacity: 0.18
            z: 5

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = "#ffffff";
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                var step = 14;
                for (var x = -height; x < width + height; x += step) {
                    ctx.moveTo(x, height);
                    ctx.lineTo(x + height, 0);
                }
                ctx.stroke();
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        // VIDEO THUMBNAILS (Visible ONLY on Video Tracks)
        Image {
            id: leftThumbnail
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 3
            width: Math.min(height * 1.77, (parent.width - 20) / 2)
            fillMode: Image.PreserveAspectCrop
            visible: !root.isAudioTrack && width > 15
            opacity: root.isLocked ? 0.4 : 1.0
            source: (!root.isAudioTrack && root.clipData) ? ("image://thumbnails/" + root.clipData.assetId + "?time=" + (root.committedSourceInFrame / 30.0) + "&width=160") : ""
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
            visible: !root.isAudioTrack && width > 15 && parent.width > (width * 2 + 30)
            opacity: root.isLocked ? 0.4 : 1.0
            source: (!root.isAudioTrack && root.clipData) ? ("image://thumbnails/" + root.clipData.assetId + "?time=" + ((root.committedSourceInFrame + root.committedDurationFrames) / 30.0) + "&width=160") : ""
            asynchronous: true
            cache: true
        }

        // AUDIO WAVEFORM CANVAS (Visible ONLY on Audio Tracks)
        Canvas {
            id: waveformCanvas
            anchors.fill: parent
            anchors.topMargin: 24
            anchors.bottomMargin: 4
            visible: root.isAudioTrack
            opacity: root.isLocked ? 0.35 : 0.88
            z: 8

            onPaint: {
                if (!root.isAudioTrack || !root.activeTimelineModel || !root.clipData)
                    return;

                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var peaks = root.activeTimelineModel.getClipWaveformPeaks(root.clipData.assetId, Number(root.clipData.sourceInFrame), Number(root.clipData.durationFrames), root.zoomFactor);

                if (!peaks || peaks.length === 0)
                    return;

                var midY = height / 2.0;
                // Neon violet when selected, soft violet when idle
                ctx.strokeStyle = root.isSelected ? "#DDD6FE" : "#C4B5FD";
                ctx.lineWidth = 1.0;
                ctx.beginPath();

                var stepX = width / peaks.length;
                for (var i = 0; i < peaks.length; ++i) {
                    var x = i * stepX;
                    var minY = midY - (peaks[i].max * (midY - 2));
                    var maxY = midY - (peaks[i].min * (midY - 2));
                    ctx.moveTo(x, minY);
                    ctx.lineTo(x, maxY);
                }
                ctx.stroke();
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // Lock Status Badge
        Rectangle {
            id: lockBadge
            visible: root.isLocked
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            width: 18
            height: 18
            radius: 3
            color: "#CC181818"
            border.color: "#444444"
            border.width: 1
            z: 30

            Image {
                anchors.centerIn: parent
                width: 11
                height: 11
                source: "qrc:/assets/icons/lock.svg"
                opacity: 0.9
            }
        }

        // Name Pill (Blue for Video, Violet for Audio)
        Rectangle {
            id: namePill
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.top: parent.top
            anchors.topMargin: 6
            height: 20
            width: Math.min(parent.width - (root.isLocked ? 32 : 12), nameText.implicitWidth + 16)
            color: root.isLocked ? "#383838" : (root.isAudioTrack ? "#7C3AED" : "#1D5DDB")
            radius: 4
            z: 20

            Text {
                id: nameText
                anchors.centerIn: parent
                text: root.clipData?.name ?? "Clip"
                color: root.isLocked ? "#b0b0b0" : "#ffffff"
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                width: parent.width - 12
            }
        }

        // Link Chain Badge
        Rectangle {
            id: linkBadge
            visible: root.isLinked
            anchors.left: namePill.right
            anchors.leftMargin: 4
            anchors.top: parent.top
            anchors.topMargin: 6
            height: 20
            width: 20
            radius: 4
            color: root.isLocked ? "#2d2d2d" : "#181818"
            border.color: root.isLocked ? "#3a3a3a" : "#303030"
            border.width: 1
            z: 20

            Image {
                anchors.centerIn: parent
                width: 11
                height: 11
                source: "qrc:/assets/icons/link.svg"
                opacity: root.isLocked ? 0.5 : 0.9
            }
        }
    }

    MouseArea {
        id: moveMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.isLocked ? Qt.ArrowCursor : (moveMouse.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor)
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startCanvasMouseX: 0
        property real startCanvasMouseY: 0
        property int startClipFrame: 0
        property int startTrackIdx: 0
        property bool didDrag: false
        property bool isRippleMove: false

        property int groupMinTrack: 0
        property int groupMaxTrack: 0
        property int kindMinTrack: 0
        property int kindMaxTrack: 0

        onPressed: function (mouse) {
            if (mouse.button !== Qt.LeftButton) {
                if (mouse.button === Qt.RightButton) {
                    if (!root.isSelected && root.activeTimelineModel && root.clipData) {
                        root.activeTimelineModel.selectClip(root.clipData.clipId, false, false);
                    }
                }
                return;
            }

            if (root.isLocked)
                return;

            didDrag = false;
            var isToggle = (mouse.modifiers & Qt.ControlModifier) !== 0 || (mouse.modifiers & Qt.MetaModifier) !== 0;
            var isRange = (mouse.modifiers & Qt.ShiftModifier) !== 0;
            var hasCtrl = (mouse.modifiers & Qt.ControlModifier) !== 0;
            var hasAlt = (mouse.modifiers & Qt.AltModifier) !== 0;

            isRippleMove = hasCtrl && hasAlt;

            if (root.activeTimelineModel && root.clipData) {
                if (isToggle || isRange || !root.isSelected) {
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
            kindMinTrack = bounds.kindMinTrack;
            kindMaxTrack = bounds.kindMaxTrack;

            if (root.activeTimelineModel) {
                root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, 0, 0);
            }
        }

        onPositionChanged: function (mouse) {
            if (root.isLocked || !root.isDragging || !(mouse.buttons & Qt.LeftButton) || !root.clipData)
                return;
            didDrag = true;

            var pt = mapToItem(root.parent, mouse.x, mouse.y);
            var deltaPx = pt.x - startCanvasMouseX;

            var hoveredTrack = root.timelineRoot ? root.timelineRoot.getTrackAtY(pt.y) : startTrackIdx;
            var rawDeltaTracks = hoveredTrack - startTrackIdx;

            var minAllowedDeltaTracks = Math.max(-groupMinTrack, kindMinTrack - startTrackIdx);
            var maxAllowedDeltaTracks = Math.min(kindMaxTrack - groupMaxTrack, kindMaxTrack - startTrackIdx);
            var deltaTracks = Math.max(minAllowedDeltaTracks, Math.min(maxAllowedDeltaTracks, rawDeltaTracks));
            root.localTrackIndex = startTrackIdx + deltaTracks;

            var rawDeltaFrames = Math.round(deltaPx / root.zoomFactor);

            if (isRippleMove) {
                root.localStartFrame = Math.max(0, startClipFrame + rawDeltaFrames);
            } else {
                var desiredStart = Math.max(0, startClipFrame + rawDeltaFrames);
                var playhead = root.timelineRoot ? Number(root.timelineRoot.playheadFrame ?? -1) : -1;
                var selIds = root.activeTimelineModel?.selectedClipIds ?? [root.clipData.clipId];

                var globalSnapping = root.activeTimelineModel ? root.activeTimelineModel.snappingEnabled : true;
                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                var isSnappingActive = hasShift ? !globalSnapping : globalSnapping;

                var snapResult = (isSnappingActive && root.activeTimelineModel) ? root.activeTimelineModel.querySnap(desiredStart, Number(root.clipData.durationFrames), root.localTrackIndex, playhead, root.zoomFactor, selIds, 8.0) : null;

                var candidateFrame = (snapResult && snapResult.isSnapped) ? Number(snapResult.snappedStart) : desiredStart;
                var candidateDelta = candidateFrame - startClipFrame;

                var deltaFrames = root.resolvePlacementDelta(candidateDelta, deltaTracks);
                root.localStartFrame = startClipFrame + deltaFrames;

                if (snapResult && snapResult.isSnapped && root.timelineRoot) {
                    if (snapResult.snapType === "spacing" && root.timelineRoot.showSpacingGuides) {
                        root.timelineRoot.showSpacingGuides(snapResult.allMatchingGaps);
                    } else if (root.timelineRoot.showSnapLine) {
                        root.timelineRoot.showSnapLine(snapResult.guideFrame);
                    }
                } else if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }
            }

            if (root.activeTimelineModel) {
                root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, root.localStartFrame - startClipFrame, deltaTracks);
            }
        }

        onReleased: function (mouse) {
            if (mouse.button !== Qt.LeftButton || !root.isDragging)
                return;

            root.isDragging = false;
            if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                root.timelineRoot.hideSnapGuides();
            }

            if (!root.activeTimelineModel || !root.clipData)
                return;

            var deltaFrames = Math.round(root.localStartFrame - startClipFrame);
            var deltaTracks = root.localTrackIndex - startTrackIdx;

            if (isRippleMove) {
                var globalDefault = root.activeTimelineModel.globalRippleMode;
                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                var effectiveGlobal = hasShift ? !globalDefault : globalDefault;

                root.activeTimelineModel.rippleMoveClip(root.clipData.clipId, root.localTrackIndex, Math.round(root.localStartFrame), effectiveGlobal);
            } else {
                var selIds = root.activeTimelineModel.selectedClipIds ?? [];
                if (selIds.length > 1) {
                    root.activeTimelineModel.moveClips(selIds, deltaFrames, deltaTracks);
                } else {
                    root.activeTimelineModel.moveClip(root.clipData.clipId, root.trackIndex, root.localTrackIndex, Math.round(root.localStartFrame));
                }
            }

            root.activeTimelineModel.clearGroupDrag();
            isRippleMove = false;
        }

        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                var overlayPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                if (root.timelineRoot && root.timelineRoot.openContextMenu) {
                    root.timelineRoot.openContextMenu(overlayPt.x, overlayPt.y, Number(root.clipData?.startFrame ?? 0), root.trackIndex, root.clipData);
                }
                return;
            }

            var isToggle = (mouse.modifiers & Qt.ControlModifier) !== 0 || (mouse.modifiers & Qt.MetaModifier) !== 0;
            var isRange = (mouse.modifiers & Qt.ShiftModifier) !== 0;

            if (!didDrag && !isToggle && !isRange && root.isSelected && root.activeTimelineModel && root.clipData) {
                root.activeTimelineModel.selectClip(root.clipData.clipId, false, false);
            }
        }
    }

    Rectangle {
        id: leftTrim
        visible: !root.isLocked
        width: 2
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: leftTrimMouse.containsMouse || leftTrimMouse.pressed ? (root.isAudioTrack ? "#C4B5FD" : "#60A5FA") : (root.isAudioTrack ? "#7C3AED" : "#1D5DDB")
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
                if (root.isLocked)
                    return;

                if (!root.isSelected && root.activeTimelineModel && root.clipData) {
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
                if (root.isLocked || !pressed || !root.clipData)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                var deltaPx = pt.x - startCanvasX;
                var deltaFrames = Math.round(deltaPx / root.zoomFactor);

                var desiredStart = startFrame + deltaFrames;
                var playhead = root.timelineRoot ? Number(root.timelineRoot.playheadFrame ?? -1) : -1;
                var selIds = root.activeTimelineModel?.selectedClipIds ?? [root.clipData.clipId];

                var globalSnapping = root.activeTimelineModel ? root.activeTimelineModel.snappingEnabled : true;
                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                var isSnappingActive = hasShift ? !globalSnapping : globalSnapping;

                var snapResult = (isSnappingActive && root.activeTimelineModel) ? root.activeTimelineModel.querySnap(desiredStart, 0, root.trackIndex, playhead, root.zoomFactor, selIds, 8.0) : null;

                var candidateStart = (snapResult && snapResult.isSnapped) ? Number(snapResult.snappedStart) : desiredStart;
                var maxFrame = startFrame + startDur - 1;
                var newStartFrame = Math.max(minBoundaryFrame, Math.min(maxFrame, candidateStart));
                var appliedDelta = newStartFrame - startFrame;

                root.localStartFrame = newStartFrame;
                root.localDurationFrames = startDur - appliedDelta;
                root.localSourceInFrame = startIn + appliedDelta;

                if (snapResult && snapResult.isSnapped && root.timelineRoot && root.timelineRoot.showSnapLine) {
                    root.timelineRoot.showSnapLine(snapResult.guideFrame);
                } else if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }
            }

            onReleased: function () {
                if (root.isLocked)
                    return;
                root.isTrimmingLeft = false;
                if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Math.round(root.localStartFrame), Math.round(root.localDurationFrames), Math.round(root.localSourceInFrame), false);
                }
            }
        }
    }

    Rectangle {
        id: rightTrim
        visible: !root.isLocked
        width: 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: rightTrimMouse.containsMouse || rightTrimMouse.pressed ? (root.isAudioTrack ? "#C4B5FD" : "#60A5FA") : (root.isAudioTrack ? "#7C3AED" : "#1D5DDB")
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
                if (root.isLocked)
                    return;

                if (!root.isSelected && root.activeTimelineModel && root.clipData) {
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
                if (root.isLocked || !pressed || !root.clipData)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                var deltaPx = pt.x - startCanvasX;
                var deltaFrames = Math.round(deltaPx / root.zoomFactor);

                var desiredEnd = startFrame + startDur + deltaFrames;
                var playhead = root.timelineRoot ? Number(root.timelineRoot.playheadFrame ?? -1) : -1;
                var selIds = root.activeTimelineModel?.selectedClipIds ?? [root.clipData.clipId];

                var globalSnapping = root.activeTimelineModel ? root.activeTimelineModel.snappingEnabled : true;
                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                var isSnappingActive = hasShift ? !globalSnapping : globalSnapping;

                var snapResult = (isSnappingActive && root.activeTimelineModel) ? root.activeTimelineModel.querySnap(desiredEnd, 0, root.trackIndex, playhead, root.zoomFactor, selIds, 8.0) : null;

                var candidateEnd = (snapResult && snapResult.isSnapped) ? Number(snapResult.snappedStart) : desiredEnd;
                var newDur = Math.max(1, Math.min(maxAllowedDuration, candidateEnd - startFrame));
                root.localDurationFrames = newDur;

                if (snapResult && snapResult.isSnapped && root.timelineRoot && root.timelineRoot.showSnapLine) {
                    root.timelineRoot.showSnapLine(snapResult.guideFrame);
                } else if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }
            }

            onReleased: function () {
                if (root.isLocked)
                    return;
                root.isTrimmingRight = false;
                if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Number(root.clipData.startFrame), Math.round(root.localDurationFrames), Number(root.clipData.sourceInFrame), false);
                }
            }
        }
    }
}
