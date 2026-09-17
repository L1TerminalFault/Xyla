import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var timelineRoot: null
    property var clipData: null
    property double zoomFactor: 1.0

    readonly property int trackIndex: Number(clipData?.trackIndex ?? 0)
    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null

    readonly property bool isTextClip: {
        if (!clipData)
            return false;
        if (clipData.isTextClip !== undefined && clipData.isTextClip !== null)
            return Boolean(clipData.isTextClip);
        if (clipData.assetId && (clipData.assetId.indexOf("asset_title_") !== -1 || clipData.assetId.indexOf("title") !== -1))
            return true;
        if (clipData.name && clipData.name.indexOf("Title") !== -1)
            return true;
        return false;
    }

    readonly property bool isAudioTrack: {
        if (root.clipData) {
            if (root.clipData.isAudio !== undefined)
                return Boolean(root.clipData.isAudio);
            if (root.clipData.trackKind !== undefined)
                return Number(root.clipData.trackKind) === 1;
        }
        if (root.activeTimelineModel && root.trackIndex >= 0) {
            return root.activeTimelineModel.getTrackKind(root.trackIndex) === 1;
        }
        return false;
    }

    readonly property string linkGroupId: root.clipData?.linkGroupId ?? ""
    readonly property bool isLinked: linkGroupId.length > 0

    property bool isClipExplicitlyLocked: root.clipData?.isLocked === true
    property bool isTrackLocked: root.activeTimelineModel ? root.activeTimelineModel.isTrackLocked(root.trackIndex) : false
    property bool isGroupLocked: root.activeTimelineModel ? root.activeTimelineModel.isClipOrGroupLocked(root.clipData?.clipId ?? "") : false
    readonly property bool isLocked: isClipExplicitlyLocked || isTrackLocked || isGroupLocked

    readonly property bool showWaveforms: root.timelineRoot?.showAudioWaveforms ?? true
    readonly property int thumbnailMode: root.timelineRoot?.thumbnailMode ?? 1

    readonly property real vpLeft: root.timelineRoot ? Number(root.timelineRoot.horizontalOffset || 0) : 0
    readonly property real vpWidth: root.timelineRoot ? Math.max(100, Number(root.timelineRoot.width || 1920) - Number(root.timelineRoot.headerWidth || 220) - Number(root.timelineRoot.paletteStripWidth || 0)) : 1920
    readonly property real vpRight: vpLeft + vpWidth

    readonly property bool isClipInView: {
        if (root.isDragging || root.isTrimmingLeft || root.isTrimmingRight)
            return true;
        return (root.x + root.width >= root.vpLeft - 100) && (root.x <= root.vpRight + 100);
    }
    visible: isClipInView

    readonly property real visClipLeft: Math.max(0, root.vpLeft - root.x - 100)
    readonly property real visClipRight: Math.min(root.width, root.vpRight - root.x + 100)
    readonly property real visClipWidth: Math.max(0, visClipRight - visClipLeft)

    property var _cachedPeaks: null
    property string _peaksKey: ""

    function pixelBucket(w) {
        var px = Math.max(1, Math.floor(w));
        return Math.max(1, Math.round(px / 8) * 8);
    }

    function peaksCacheKey(startF, durF, pixelW) {
        if (!clipData)
            return "";
        return String(clipData.assetId) + "|" + Math.round(startF) + "|" + Math.round(durF) + "|" + pixelBucket(pixelW);
    }

    function ensurePeaks(pixelW, startF, durF) {
        if (!isAudioTrack || !activeTimelineModel || !clipData || !showWaveforms || pixelW < 2 || durF < 1)
            return null;

        var targetPx = pixelBucket(pixelW);
        var sFrame = Math.max(0, Math.floor(startF));
        var dFrames = Math.max(1, Math.ceil(durF));
        var key = peaksCacheKey(sFrame, dFrames, targetPx);
        if (key.length && key === _peaksKey && _cachedPeaks && _cachedPeaks.length)
            return _cachedPeaks;

        _cachedPeaks = activeTimelineModel.getClipWaveformPeaks(clipData.assetId, sFrame, dFrames, targetPx);
        _peaksKey = key;
        return _cachedPeaks;
    }

    function invalidatePeaks() {
        _cachedPeaks = null;
        _peaksKey = "";
    }

    Connections {
        target: root.activeTimelineModel
        function onTrackDataChanged(t) {
            root.isTrackLocked = root.activeTimelineModel ? root.activeTimelineModel.isTrackLocked(root.trackIndex) : false;
            root.isGroupLocked = root.activeTimelineModel ? root.activeTimelineModel.isClipOrGroupLocked(root.clipData?.clipId ?? "") : false;
        }
        function onClipPropertiesChanged(cid) {
            if (root.clipData && cid === root.clipData.clipId) {
                root.isClipExplicitlyLocked = root.activeTimelineModel ? root.activeTimelineModel.isClipLocked(root.clipData.clipId) : false;
                root.isGroupLocked = root.activeTimelineModel ? root.activeTimelineModel.isClipOrGroupLocked(root.clipData.clipId) : false;
            }
        }
    }

    onClipDataChanged: {
        isClipExplicitlyLocked = root.clipData?.isLocked === true;
        isTrackLocked = root.activeTimelineModel ? root.activeTimelineModel.isTrackLocked(root.trackIndex) : false;
        isGroupLocked = root.activeTimelineModel ? root.activeTimelineModel.isClipOrGroupLocked(root.clipData?.clipId ?? "") : false;

        invalidatePeaks();
        if (waveformCanvas.visible)
            waveformCanvas.requestPaint();
    }

    onIsLockedChanged: {
        if (lockPatternCanvas && lockPatternCanvas.visible)
            lockPatternCanvas.requestPaint();
        if (waveformCanvas && waveformCanvas.visible)
            waveformCanvas.requestPaint();
    }

    readonly property bool isSelected: root.activeTimelineModel ? (root.activeTimelineModel.selectedClipIds?.indexOf(root.clipData?.clipId ?? "") !== -1) : false
    readonly property bool isGroupFollower: root.isSelected && !root.isDragging && (root.activeTimelineModel?.groupDragLeaderId ?? "") !== ""
    readonly property int groupDeltaFrames: isGroupFollower ? (root.activeTimelineModel?.groupDragDeltaFrames ?? 0) : 0
    readonly property int groupDeltaTracks: isGroupFollower ? (root.activeTimelineModel?.groupDragDeltaTracks ?? 0) : 0

    readonly property bool isLeaderKind: {
        var leaderId = root.activeTimelineModel?.groupDragLeaderId ?? "";
        if (!leaderId || leaderId === root.clipData?.clipId)
            return true;
        var totalTracks = root.activeTimelineModel ? root.activeTimelineModel.rowCount() : 0;
        for (var t = 0; t < totalTracks; ++t) {
            var clips = root.activeTimelineModel.getClipsForTrack(t);
            for (var i = 0; i < clips.length; ++i) {
                if (clips[i].clipId === leaderId) {
                    return root.activeTimelineModel.getTrackKind(t) === root.activeTimelineModel.getTrackKind(root.trackIndex);
                }
            }
        }
        return true;
    }
    readonly property int effectiveGroupDeltaTracks: isGroupFollower ? (isLeaderKind ? groupDeltaTracks : -groupDeltaTracks) : 0

    property real localStartFrame: Number(clipData?.startFrame ?? 0)
    property real localDurationFrames: Number(clipData?.durationFrames ?? 30)
    property real localSourceInFrame: Number(clipData?.sourceInFrame ?? 0)
    property int localTrackIndex: root.trackIndex
    property real committedSourceInFrame: Number(clipData?.sourceInFrame ?? 0)
    property real committedDurationFrames: Number(clipData?.durationFrames ?? 30)

    readonly property real totalSourceDuration: {
        if (!clipData || root.isTextClip)
            return Infinity;
        if (clipData.sourceDurationFrames !== undefined && clipData.sourceDurationFrames !== null && Number(clipData.sourceDurationFrames) > 0)
            return Number(clipData.sourceDurationFrames);
        if (activeTimelineModel && clipData.assetId) {
            var d = activeTimelineModel.getAssetDuration(clipData.assetId);
            if (d > 0)
                return d;
        }
        return Infinity;
    }

    property bool isDragging: false
    property bool isTrimmingLeft: false
    property bool isTrimmingRight: false

    x: ((isDragging || isTrimmingLeft) ? localStartFrame : (Number(clipData?.startFrame ?? 0) + groupDeltaFrames)) * root.zoomFactor
    y: (root.timelineRoot ? root.timelineRoot.getTrackY(isDragging ? localTrackIndex : (root.trackIndex + effectiveGroupDeltaTracks)) : (root.trackIndex * 68)) + 4
    width: ((isTrimmingLeft || isTrimmingRight) ? localDurationFrames : Math.max(20, Number(clipData?.durationFrames ?? 100))) * root.zoomFactor
    height: (root.timelineRoot ? root.timelineRoot.getTrackHeight(isDragging ? localTrackIndex : (root.trackIndex + effectiveGroupDeltaTracks)) : 68) - 8
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
        var minStart = Infinity, minTrack = Infinity, maxTrack = -Infinity;
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
        return {
            minStart: isFinite(minStart) ? minStart : Number(clipData?.startFrame ?? 0),
            minTrack: isFinite(minTrack) ? minTrack : root.trackIndex,
            maxTrack: isFinite(maxTrack) ? maxTrack : root.trackIndex,
            kindMinTrack: 0,
            kindMaxTrack: Math.max(0, totalTracks - 1)
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
        for (var i = 0; i < movingClips.length; ++i)
            minAllowedDelta = Math.max(minAllowedDelta, -movingClips[i].startFrame);
        var candidateDelta = Math.max(minAllowedDelta, rawDeltaFrames);

        function getGroupCollisions(delta) {
            var cols = [];
            for (var m = 0; m < movingClips.length; ++m) {
                var mc = movingClips[m];
                var isThisAudio = root.activeTimelineModel.getTrackKind(mc.trackIndex) === 1;
                var dTrack = mc.trackIndex + (isThisAudio ? -trackShift : trackShift);
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
                    if (cStart < oEnd && cEnd > oStart)
                        cols.push({
                            movingClip: mc,
                            obstacle: obst,
                            oStart: oStart,
                            oEnd: oEnd
                        });
                }
            }
            return cols;
        }

        var collisions = getGroupCollisions(candidateDelta);
        if (collisions.length === 0)
            return candidateDelta;

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
        if (getGroupCollisions(bestDelta).length === 0)
            return bestDelta;
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
            if (cEnd <= currentStart && cEnd > minFrame)
                minFrame = cEnd;
            if (cStart >= (currentStart + currentDur) && cStart < maxFrame)
                maxFrame = cStart;
        }
        return {
            minFrame: minFrame,
            maxFrame: maxFrame
        };
    }

    Rectangle {
        id: cardContainer
        anchors.fill: parent
        color: root.isLocked ? "#262626" : (root.isAudioTrack ? Qt.rgba(0.486, 0.227, 0.929, 0.28) : (root.isTextClip ? Qt.rgba(0.96, 0.62, 0.04, 0.28) : Qt.rgba(0.114, 0.365, 0.859, 0.3)))
        border.color: (root.isSelected || root.isDragging || root.isTrimmingLeft || root.isTrimmingRight) ? (root.isAudioTrack ? "#A78BFA" : (root.isTextClip ? "#FBBF24" : "#3B82F6")) : (root.isLocked ? "#383838" : (root.isAudioTrack ? Qt.rgba(0.486, 0.227, 0.929, 0.55) : (root.isTextClip ? Qt.rgba(0.96, 0.62, 0.04, 0.55) : Qt.rgba(0.114, 0.365, 0.859, 0.5))))
        border.width: 1
        clip: true

        Rectangle {
            id: titleHeaderBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 20
            color: root.isLocked ? "#2d2d2d" : (root.isAudioTrack ? "#6D28D9" : (root.isTextClip ? "#D97706" : "#1D4ED8"))
            z: 25

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Qt.rgba(0, 0, 0, 0.35)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 4

                Text {
                    id: headerText
                    Layout.fillWidth: true
                    text: root.clipData?.name ?? (root.isTextClip ? "Title" : "Clip")
                    color: root.isLocked ? "#a3a3a3" : "#ffffff"
                    font.pixelSize: 10
                    font.bold: true
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Image {
                    visible: root.isLinked
                    source: "qrc:/assets/icons/link.svg"
                    sourceSize: Qt.size(10, 10)
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    opacity: root.isLocked ? 0.45 : 0.85
                    Layout.alignment: Qt.AlignVCenter
                }

                Image {
                    visible: root.isLocked
                    source: "qrc:/assets/icons/lock.svg"
                    sourceSize: Qt.size(10, 10)
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    opacity: 0.9
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        Item {
            id: contentArea
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: titleHeaderBar.bottom
            anchors.bottom: parent.bottom
            clip: true

            Canvas {
                id: lockPatternCanvas
                x: root.visClipLeft
                y: 0
                width: Math.max(2, root.visClipWidth)
                height: parent.height
                visible: root.isLocked && root.isClipInView && width >= 2
                opacity: 0.18
                renderTarget: Canvas.Image
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
                onXChanged: requestPaint()
                Component.onCompleted: requestPaint()
            }

            Item {
                anchors.fill: parent
                visible: !root.isAudioTrack && !root.isTextClip && root.thumbnailMode === 1 && root.isClipInView

                Image {
                    id: leftThumbnail
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: Math.min(height * 1.77, (parent.width - 8) / 2)
                    fillMode: Image.PreserveAspectCrop
                    visible: width > 15
                    opacity: root.isLocked ? 0.4 : 1.0
                    source: (visible && root.clipData) ? ("image://thumbnails/" + root.clipData.assetId + "?time=" + (root.committedSourceInFrame / 30.0) + "&width=160") : ""
                    asynchronous: true
                    cache: true
                    onStatusChanged: if (leftThumbnail.status === Image.Error)
                        source = ""
                }

                Image {
                    id: rightThumbnail
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: Math.min(height * 1.77, (parent.width - 8) / 2)
                    fillMode: Image.PreserveAspectCrop
                    visible: width > 15 && parent.width > (width * 2 + 10)
                    opacity: root.isLocked ? 0.4 : 1.0
                    source: (visible && root.clipData) ? ("image://thumbnails/" + root.clipData.assetId + "?time=" + ((root.committedSourceInFrame + root.committedDurationFrames) / 30.0) + "&width=160") : ""
                    asynchronous: true
                    cache: true
                    onStatusChanged: if (rightThumbnail.status === Image.Error)
                        source = ""
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 1
                visible: !root.isAudioTrack && !root.isTextClip && root.thumbnailMode === 2 && root.isClipInView
                clip: true

                readonly property real thumbW: Math.max(16, contentArea.height * 1.77)
                readonly property int count: Math.ceil(parent.width / (thumbW + spacing))

                Repeater {
                    model: parent.visible ? parent.count : 0

                    Image {
                        width: parent.thumbW
                        height: contentArea.height - 4
                        fillMode: Image.PreserveAspectCrop
                        opacity: root.isLocked ? 0.4 : 1.0
                        source: root.clipData ? ("image://thumbnails/" + root.clipData.assetId + "?time=" + ((root.committedSourceInFrame + (index * (root.committedDurationFrames / Math.max(1, parent.count)))) / 30.0) + "&width=160") : ""
                        asynchronous: true
                        cache: true
                    }
                }
            }

            Canvas {
                id: waveformCanvas
                x: root.visClipLeft
                y: 0
                width: Math.max(2, root.visClipWidth)
                height: Math.max(2, parent.height)
                visible: root.isAudioTrack && root.showWaveforms && root.isClipInView && width >= 2
                opacity: root.isLocked ? 0.35 : 0.88
                renderTarget: Canvas.Image
                z: 8

                onPaint: {
                    if (!root.isAudioTrack || !root.clipData || !root.showWaveforms || width < 2 || height < 2)
                        return;
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var sourceIn = Number(root.isTrimmingLeft ? root.localSourceInFrame : (root.clipData?.sourceInFrame ?? 0));
                    var totalDur = Number(root.isTrimmingLeft || root.isTrimmingRight ? root.localDurationFrames : (root.clipData?.durationFrames ?? 30));

                    var frameOffset = root.visClipLeft / Math.max(0.001, root.zoomFactor);
                    var visibleDurFrames = width / Math.max(0.001, root.zoomFactor);

                    var startF = Math.max(0, sourceIn + frameOffset);
                    var durF = Math.min(visibleDurFrames, Math.max(1, totalDur - frameOffset));

                    var peaks = root.ensurePeaks(width, startF, durF);
                    if (!peaks || peaks.length === 0)
                        return;

                    var midY = height * 0.5;
                    var amp = midY - 2;
                    var n = peaks.length;
                    var stepX = width / n;

                    ctx.strokeStyle = root.isSelected ? Qt.rgba(0.87, 0.84, 1.0, 0.25) : Qt.rgba(0.77, 0.71, 0.99, 0.2);
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.moveTo(0, midY);
                    ctx.lineTo(width, midY);
                    ctx.stroke();

                    ctx.strokeStyle = root.isSelected ? "#DDD6FE" : "#C4B5FD";
                    ctx.lineWidth = Math.max(1, Math.min(3, Math.floor(stepX)));
                    ctx.beginPath();
                    for (var i = 0; i < n; ++i) {
                        var p = peaks[i];
                        if (!p)
                            continue;
                        var x = Math.floor(i * stepX) + 0.5;
                        var yTop = midY - (p.max !== undefined ? p.max : 0) * amp;
                        var yBottom = midY - (p.min !== undefined ? p.min : 0) * amp;
                        if (Math.abs(yBottom - yTop) < 1.5) {
                            yTop = midY - 0.75;
                            yBottom = midY + 0.75;
                        }
                        ctx.moveTo(x, yTop);
                        ctx.lineTo(x, yBottom);
                    }
                    ctx.stroke();
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onXChanged: requestPaint()

                Connections {
                    target: root
                    function onZoomFactorChanged() {
                        root.invalidatePeaks();
                        waveformCanvas.requestPaint();
                    }
                    function onLocalSourceInFrameChanged() {
                        root.invalidatePeaks();
                        waveformCanvas.requestPaint();
                    }
                    function onLocalDurationFramesChanged() {
                        root.invalidatePeaks();
                        waveformCanvas.requestPaint();
                    }
                    function onShowWaveformsChanged() {
                        if (root.showWaveforms)
                            waveformCanvas.requestPaint();
                    }
                }
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
                    if (!root.isSelected && root.activeTimelineModel && root.clipData)
                        root.activeTimelineModel.selectClip(root.clipData.clipId, false, false);
                }
                return;
            }
            if (root.isLocked)
                return;
            didDrag = false;
            var isToggle = (mouse.modifiers & Qt.ControlModifier) !== 0 || (mouse.modifiers & Qt.MetaModifier) !== 0;
            var isRange = (mouse.modifiers & Qt.ShiftModifier) !== 0;
            isRippleMove = (mouse.modifiers & Qt.ControlModifier) !== 0 && (mouse.modifiers & Qt.AltModifier) !== 0;
            if (root.activeTimelineModel && root.clipData) {
                if (isToggle || isRange || !root.isSelected)
                    root.activeTimelineModel.selectClip(root.clipData.clipId, isToggle, isRange);
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
            if (root.activeTimelineModel)
                root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, 0, 0);
        }

        onPositionChanged: function (mouse) {
            if (root.isLocked || !root.isDragging || !(mouse.buttons & Qt.LeftButton) || !root.clipData)
                return;
            didDrag = true;
            var pt = mapToItem(root.parent, mouse.x, mouse.y);
            var deltaPx = pt.x - startCanvasMouseX;
            var hoveredTrack = root.timelineRoot ? root.timelineRoot.getTrackAtY(pt.y) : startTrackIdx;
            var totalTracks = root.activeTimelineModel ? root.activeTimelineModel.rowCount() : 1;
            var deltaTracks = Math.max(-startTrackIdx, Math.min(totalTracks - 1 - startTrackIdx, hoveredTrack - startTrackIdx));
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
                var deltaFrames = root.resolvePlacementDelta(candidateFrame - startClipFrame, deltaTracks);
                root.localStartFrame = startClipFrame + deltaFrames;
                if (snapResult && snapResult.isSnapped && root.timelineRoot) {
                    if (snapResult.snapType === "spacing" && root.timelineRoot.showSpacingGuides)
                        root.timelineRoot.showSpacingGuides(snapResult.allMatchingGaps);
                    else if (root.timelineRoot.showSnapLine)
                        root.timelineRoot.showSnapLine(snapResult.guideFrame);
                } else if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }
            }
            if (root.activeTimelineModel)
                root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, root.localStartFrame - startClipFrame, deltaTracks);
        }

        onReleased: function (mouse) {
            if (mouse.button !== Qt.LeftButton || !root.isDragging)
                return;
            root.isDragging = false;
            if (root.timelineRoot && root.timelineRoot.hideSnapGuides)
                root.timelineRoot.hideSnapGuides();
            if (!root.activeTimelineModel || !root.clipData)
                return;
            var deltaFrames = Math.round(root.localStartFrame - startClipFrame);
            var deltaTracks = root.localTrackIndex - startTrackIdx;
            if (isRippleMove) {
                var globalDefault = root.activeTimelineModel.globalRippleMode;
                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                root.activeTimelineModel.rippleMoveClip(root.clipData.clipId, root.localTrackIndex, Math.round(root.localStartFrame), hasShift ? !globalDefault : globalDefault);
            } else {
                var selIds = root.activeTimelineModel.selectedClipIds ?? [];
                if (selIds.length > 1)
                    root.activeTimelineModel.moveClips(selIds, deltaFrames, deltaTracks);
                else
                    root.activeTimelineModel.moveClip(root.clipData.clipId, root.trackIndex, root.localTrackIndex, Math.round(root.localStartFrame));
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

    // =========================================================================
    // LEFT TRIM (Fixed for Text Clips)
    // =========================================================================
    Rectangle {
        id: leftTrim
        visible: !root.isLocked
        width: 3
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: leftTrimMouse.containsMouse || leftTrimMouse.pressed ? (root.isAudioTrack ? "#C4B5FD" : (root.isTextClip ? "#FCD34D" : "#60A5FA")) : (root.isAudioTrack ? "#7C3AED" : (root.isTextClip ? "#D97706" : "#1D5DDB"))
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
                if (!root.isSelected && root.activeTimelineModel && root.clipData)
                    root.activeTimelineModel.selectClip(root.clipData.clipId, false, false);
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
                // Text clips are infinite generators: bound ONLY by the preceding clip (bounds.minFrame)
                minBoundaryFrame = root.isTextClip ? bounds.minFrame : Math.max(bounds.minFrame, startFrame - startIn);
            }
            onPositionChanged: function (mouse) {
                if (root.isLocked || !pressed || !root.clipData)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                var deltaFrames = Math.round((pt.x - startCanvasX) / root.zoomFactor);
                var desiredStart = startFrame + deltaFrames;
                var playhead = root.timelineRoot ? Number(root.timelineRoot.playheadFrame ?? -1) : -1;
                var selIds = root.activeTimelineModel?.selectedClipIds ?? [root.clipData.clipId];
                var globalSnapping = root.activeTimelineModel ? root.activeTimelineModel.snappingEnabled : true;
                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                var isSnappingActive = hasShift ? !globalSnapping : globalSnapping;
                var snapResult = (isSnappingActive && root.activeTimelineModel) ? root.activeTimelineModel.querySnap(desiredStart, 0, root.trackIndex, playhead, root.zoomFactor, selIds, 8.0) : null;
                var candidateStart = (snapResult && snapResult.isSnapped) ? Number(snapResult.snappedStart) : desiredStart;
                var newStartFrame = Math.max(minBoundaryFrame, Math.min(startFrame + startDur - 1, candidateStart));
                var appliedDelta = newStartFrame - startFrame;
                root.localStartFrame = newStartFrame;
                root.localDurationFrames = startDur - appliedDelta;

                // Text clips have no media tape: sourceInFrame stays 0 to prevent C++ negative frame errors
                root.localSourceInFrame = root.isTextClip ? 0 : (startIn + appliedDelta);

                if (snapResult && snapResult.isSnapped && root.timelineRoot && root.timelineRoot.showSnapLine)
                    root.timelineRoot.showSnapLine(snapResult.guideFrame);
                else if (root.timelineRoot && root.timelineRoot.hideSnapGuides)
                    root.timelineRoot.hideSnapGuides();
            }
            onReleased: function () {
                if (root.isLocked)
                    return;
                root.isTrimmingLeft = false;
                if (root.timelineRoot && root.timelineRoot.hideSnapGuides)
                    root.timelineRoot.hideSnapGuides();
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Math.round(root.localStartFrame), Math.round(root.localDurationFrames), root.isTextClip ? 0 : Math.round(root.localSourceInFrame), false);
                }
            }
        }
    }

    // =========================================================================
    // RIGHT TRIM (Fixed for Text Clips: Infinite Source Duration)
    // =========================================================================
    Rectangle {
        id: rightTrim
        visible: !root.isLocked
        width: 3
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: rightTrimMouse.containsMouse || rightTrimMouse.pressed ? (root.isAudioTrack ? "#C4B5FD" : (root.isTextClip ? "#FCD34D" : "#60A5FA")) : (root.isAudioTrack ? "#7C3AED" : (root.isTextClip ? "#D97706" : "#1D5DDB"))
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
            property real maxAllowedDuration: 0
            onPressed: function (mouse) {
                if (root.isLocked)
                    return;
                if (!root.isSelected && root.activeTimelineModel && root.clipData)
                    root.activeTimelineModel.selectClip(root.clipData.clipId, false, false);
                root.isTrimmingRight = true;
                if (!root.clipData)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                startCanvasX = pt.x;
                startFrame = Number(root.clipData.startFrame);
                startDur = Number(root.clipData.durationFrames);
                startIn = Number(root.clipData.sourceInFrame);
                root.localDurationFrames = startDur;

                var bounds = root.getImmediateNeighborBounds(root.trackIndex, startFrame, startDur);
                var maxFromNeighbor = bounds.maxFrame - startFrame;

                // Text clips are infinite: max duration is bounded only by the next neighbor clip
                if (root.isTextClip || !isFinite(root.totalSourceDuration)) {
                    maxAllowedDuration = maxFromNeighbor;
                } else {
                    var maxFromSource = root.totalSourceDuration - startIn;
                    maxAllowedDuration = Math.min(maxFromSource, maxFromNeighbor);
                }
            }
            onPositionChanged: function (mouse) {
                if (root.isLocked || !pressed || !root.clipData)
                    return;
                var pt = mapToItem(root.parent, mouse.x, mouse.y);
                var deltaFrames = Math.round((pt.x - startCanvasX) / root.zoomFactor);
                var desiredEnd = startFrame + startDur + deltaFrames;
                var playhead = root.timelineRoot ? Number(root.timelineRoot.playheadFrame ?? -1) : -1;
                var selIds = root.activeTimelineModel?.selectedClipIds ?? [root.clipData.clipId];
                var globalSnapping = root.activeTimelineModel ? root.activeTimelineModel.snappingEnabled : true;
                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                var isSnappingActive = hasShift ? !globalSnapping : globalSnapping;
                var snapResult = (isSnappingActive && root.activeTimelineModel) ? root.activeTimelineModel.querySnap(desiredEnd, 0, root.trackIndex, playhead, root.zoomFactor, selIds, 8.0) : null;
                var candidateEnd = (snapResult && snapResult.isSnapped) ? Number(snapResult.snappedStart) : desiredEnd;
                root.localDurationFrames = Math.max(1, Math.min(maxAllowedDuration, candidateEnd - startFrame));
                if (snapResult && snapResult.isSnapped && root.timelineRoot && root.timelineRoot.showSnapLine)
                    root.timelineRoot.showSnapLine(snapResult.guideFrame);
                else if (root.timelineRoot && root.timelineRoot.hideSnapGuides)
                    root.timelineRoot.hideSnapGuides();
            }
            onReleased: function () {
                if (root.isLocked)
                    return;
                root.isTrimmingRight = false;
                if (root.timelineRoot && root.timelineRoot.hideSnapGuides)
                    root.timelineRoot.hideSnapGuides();
                if (root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Number(root.clipData.startFrame), Math.round(root.localDurationFrames), root.isTextClip ? 0 : Number(root.clipData.sourceInFrame), false);
                }
            }
        }
    }
}
