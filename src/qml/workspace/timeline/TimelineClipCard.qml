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
    readonly property bool isLinked: linkGroupId.length > 0 || (getLinkedPartner() !== null)

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

    Component.onCompleted: {
        // console.log("[dragDebug] XylaClipCard DEBUG BUILD loaded, clipId=" + (root.clipData ? root.clipData.clipId : "null") + " trackCount=" + root.totalTrackCount());
    }

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

    // =========================================================================
    // TRACK KIND GUARDS (Blocks Video <-> Audio Cross-Dragging)
    // =========================================================================

    // Authoritative track-count lookup. The model exposes a `trackCount`
    // property (same one timeline.qml binds to for root.trackCount) — not a
    // callable `rowCount()`. The old code probed `rowCount ? rowCount() : 1`,
    // which silently fell back to 1 whenever `rowCount` wasn't an invokable
    // on this model, making every track index above 0 look "out of range"
    // and permanently rejecting every placement test. Always use trackCount.
    function totalTrackCount() {
        if (!root.activeTimelineModel)
            return 0;
        if (typeof root.activeTimelineModel.trackCount === "number")
            return root.activeTimelineModel.trackCount;
        if (root.activeTimelineModel.rowCount)
            return root.activeTimelineModel.rowCount();
        return 1;
    }

    function getClipTrackKind() {
        // Authoritative: ask the model for the kind of the track this clip
        // is actually sitting on right now. This MUST agree with
        // getTrackKind(root.trackIndex), or every "is this track compatible
        // with me" check below becomes self-inconsistent and blocks all
        // movement, including staying on your own track. Only fall back to
        // the clip payload's own fields if the model isn't available yet.
        if (root.activeTimelineModel && root.trackIndex >= 0) {
            return root.activeTimelineModel.getTrackKind(root.trackIndex);
        }
        if (root.clipData) {
            if (root.clipData.isAudio !== undefined)
                return root.clipData.isAudio ? 1 : 0;
            if (root.clipData.trackKind !== undefined)
                return Number(root.clipData.trackKind);
        }
        return 0;
    }

    function isTrackCompatible(targetTrackIdx) {
        if (!root.activeTimelineModel || targetTrackIdx < 0)
            return false;
        // Your own current track is always compatible with you by
        // definition — never let a stale/short track count reject the
        // no-op case of "hovering over the track you're already on".
        if (targetTrackIdx === root.trackIndex)
            return true;
        var total = root.totalTrackCount();
        if (targetTrackIdx >= total)
            return false;
        return root.activeTimelineModel.getTrackKind(targetTrackIdx) === getClipTrackKind();
    }

    function clampToCompatibleTrack(desiredTrackIdx) {
        if (!root.activeTimelineModel)
            return root.trackIndex;
        var myKind = getClipTrackKind();
        var total = root.totalTrackCount();
        var clamped = Math.max(0, Math.min(total - 1, desiredTrackIdx));
        if (root.activeTimelineModel.getTrackKind(clamped) === myKind)
            return clamped;

        var bestTrack = root.trackIndex;
        var minDiff = 999999;
        for (var t = 0; t < total; ++t) {
            if (root.activeTimelineModel.getTrackKind(t) === myKind) {
                var diff = Math.abs(t - desiredTrackIdx);
                if (diff < minDiff) {
                    minDiff = diff;
                    bestTrack = t;
                }
            }
        }
        return bestTrack;
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
        var totalTracks = root.totalTrackCount();
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

    property real dragPointerOffsetX: 0
    property real dragPointerOffsetY: 0

    property real dragStartFrame: 0
    property int dragStartTrack: 0

    property real lastValidDragFrame: 0
    property int lastValidDragTrack: 0

    property bool dragHasValidPlacement: true

    x: ((isDragging || isTrimmingLeft)
        ? localStartFrame
        : (Number(clipData?.startFrame ?? 0) + groupDeltaFrames)) * root.zoomFactor

    y: (
        root.timelineRoot
            ? root.timelineRoot.getTrackY(
                  isDragging
                      ? localTrackIndex
                      : (root.trackIndex + effectiveGroupDeltaTracks)
              )
            : (
                  (isDragging ? localTrackIndex : root.trackIndex) * 68
              )
    ) + 4

    width: ((isTrimmingLeft || isTrimmingRight) ? localDurationFrames : Math.max(20, Number(clipData?.durationFrames ?? 100))) * root.zoomFactor
    height: (root.timelineRoot ? root.timelineRoot.getTrackHeight(isDragging ? localTrackIndex : (root.trackIndex + effectiveGroupDeltaTracks)) : 68) - 8
    z: (isDragging || isGroupFollower) ? 100 : 10

    // =========================================================================
    // Find Linked Partner Clip (e.g. Video linked to Audio)
    // =========================================================================
    function getLinkedPartner() {
        if (!root.activeTimelineModel || !root.clipData)
            return null;

        var myId = root.clipData.clipId;
        var myTrack = (root.clipData.trackIndex !== undefined) ? root.clipData.trackIndex : root.trackIndex;
        var myKind = root.activeTimelineModel.getTrackKind(myTrack);

        var all = root.activeTimelineModel.getAllClips();
        var selIds = root.activeTimelineModel.selectedClipIds ?? [];

        // Check 2 selected clips (Video + Audio pair)
        if (selIds.length === 2 && selIds.indexOf(myId) !== -1) {
            var partnerId = (selIds[0] === myId) ? selIds[1] : selIds[0];
            for (var i = 0; i < all.length; ++i) {
                if (all[i].clipId === partnerId) {
                    var pTrack = (all[i].trackIndex !== undefined) ? all[i].trackIndex : 0;
                    var pKind = root.activeTimelineModel.getTrackKind(pTrack);
if (pKind !== myKind) {
    return {
        clipId: all[i].clipId,
        trackIndex: pTrack,
        trackKind: pKind,
        startFrame: Number(all[i].startFrame),
        durationFrames: Number(all[i].durationFrames),
        sourceInFrame: Number(all[i].sourceInFrame ?? 0)
    };
}
                }
            }
        }

        // Check explicit link ID
        var lid = root.clipData.linkedClipId || root.clipData.linkedId || root.clipData.linkId || "";
        if (lid && lid.length > 0) {
for (var j = 0; j < all.length; ++j) {
    if (all[j].clipId === lid) {
        var pTrack2 = (all[j].trackIndex !== undefined) ? all[j].trackIndex : 0;
        return {
            clipId: all[j].clipId,
            trackIndex: pTrack2,
            trackKind: root.activeTimelineModel.getTrackKind(pTrack2),
            startFrame: Number(all[j].startFrame),
            durationFrames: Number(all[j].durationFrames),
            sourceInFrame: Number(all[j].sourceInFrame ?? 0)
        };
    }
}
        }

        return null;
    }

    // =========================================================================
    // Automatically include Linked Clips in getMovingClips()
    // =========================================================================
    function getMovingClips() {
        if (!root.activeTimelineModel || !root.clipData)
            return [];

        var selIds = (root.activeTimelineModel.selectedClipIds ? root.activeTimelineModel.selectedClipIds.slice() : []);
        if (selIds.indexOf(root.clipData.clipId) === -1) {
            selIds.push(root.clipData.clipId);
        }

        var lid = root.clipData.linkedClipId || root.clipData.linkedId || root.clipData.linkId || "";
        if (lid && lid.length > 0 && selIds.indexOf(lid) === -1) {
            selIds.push(lid);
        }

        var list = [];
        var total = root.totalTrackCount();
        for (var t = 0; t < total; ++t) {
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

    // =========================================================================
    // HARDENED COLLISION & PLACEMENT RESOLVER (Per-Axis Decoupled Sliding)
    // =========================================================================
    function resolveHardenedPlacement(rawDesiredStart, targetTrackIdx) {
        if (!root.activeTimelineModel || !root.clipData)
            return { valid: true, frame: rawDesiredStart, track: targetTrackIdx };

        var originFrame = (typeof moveMouse !== "undefined" && moveMouse.startClipFrame !== undefined)
            ? moveMouse.startClipFrame
            : Number(root.clipData.startFrame ?? 0);
        var originTrack = (typeof moveMouse !== "undefined" && moveMouse.startTrackIdx !== undefined)
            ? moveMouse.startTrackIdx
            : root.trackIndex;

        var selIds = root.activeTimelineModel.selectedClipIds ?? [];
        var isMulti = selIds.length > 1 && selIds.indexOf(root.clipData.clipId) !== -1;

        // ---------------------------------------------------------------------
        // PATH A: SINGLE CLIP MODE (PER-AXIS INDEPENDENT COLLISION)
        // ---------------------------------------------------------------------
        if (!isMulti) {
            var myId = root.clipData.clipId;
            var myDur = Number(root.clipData.durationFrames);
            var totalTracks = root.totalTrackCount();

            function testSinglePlacement(desiredFrame, trkIdx) {
                if (trkIdx < 0 || trkIdx >= totalTracks || !isTrackCompatible(trkIdx)) {
                    // console.log("[dragDebug] testSinglePlacement REJECTED: trkIdx=" + trkIdx + " totalTracks=" + totalTracks + " inRange=" + (trkIdx >= 0 && trkIdx < totalTracks) + " isTrackCompatible=" + (trkIdx >= 0 && trkIdx < totalTracks ? isTrackCompatible(trkIdx) : "n/a") + " myKind=" + getClipTrackKind() + " targetKind=" + (root.activeTimelineModel && trkIdx >= 0 && trkIdx < totalTracks ? root.activeTimelineModel.getTrackKind(trkIdx) : "n/a"));
                    return { valid: false, frame: lastValidDragFrame };
                }

                var candStart = Math.max(0, desiredFrame);
                var candEnd = candStart + myDur;
                var trackClips = root.activeTimelineModel.getClipsForTrack(trkIdx);

                var obstacles = [];
                for (var i = 0; i < trackClips.length; ++i) {
                    var obst = trackClips[i];
                    if (obst.clipId === myId)
                        continue;
                    var oStart = Number(obst.startFrame);
                    var oEnd = oStart + Number(obst.durationFrames);
                    if (candStart < oEnd && candEnd > oStart) {
                        obstacles.push({ oStart: oStart, oEnd: oEnd });
                    }
                }

                if (obstacles.length === 0)
                    return { valid: true, frame: candStart };

                // Snap flush against obstacle boundary
                var snapFrame = candStart;
                if (desiredFrame >= originFrame) {
                    var minStart = Infinity;
                    for (var c = 0; c < obstacles.length; ++c) {
                        if (obstacles[c].oStart < minStart) minStart = obstacles[c].oStart;
                    }
                    snapFrame = minStart - myDur;
                } else {
                    var maxEnd = -Infinity;
                    for (var d = 0; d < obstacles.length; ++d) {
                        if (obstacles[d].oEnd > maxEnd) maxEnd = obstacles[d].oEnd;
                    }
                    snapFrame = maxEnd;
                }

                snapFrame = Math.max(0, snapFrame);
                var snapEnd = snapFrame + myDur;

                for (var j = 0; j < trackClips.length; ++j) {
                    var checkClip = trackClips[j];
                    if (checkClip.clipId === myId)
                        continue;
                    var cs = Number(checkClip.startFrame);
                    var ce = cs + Number(checkClip.durationFrames);
                    if (snapFrame < ce && snapEnd > cs)
                        return { valid: false, frame: lastValidDragFrame };
                }

                return { valid: true, frame: snapFrame };
            }

            // 1. Attempt Full 2D Movement (Both X and Y)
            var res2D = testSinglePlacement(rawDesiredStart, targetTrackIdx);
            if (res2D.valid) {
                return { valid: true, frame: res2D.frame, track: targetTrackIdx };
            }

            // 2. Y is blocked: Fallback Y to lastValidDragTrack, allow X (time) to slide!
            var resX = testSinglePlacement(rawDesiredStart, lastValidDragTrack);
            if (resX.valid) {
                return { valid: true, frame: resX.frame, track: lastValidDragTrack };
            }

            // 3. X is blocked: Freeze X to lastValidDragFrame, allow Y (track) to switch!
            var resY = testSinglePlacement(lastValidDragFrame, targetTrackIdx);
            if (resY.valid) {
                return { valid: true, frame: resY.frame, track: targetTrackIdx };
            }

            // 4. Both axes blocked: stay at last valid
            return { valid: false, frame: lastValidDragFrame, track: lastValidDragTrack };
        }

        // ---------------------------------------------------------------------
        // PATH B: MULTI-CLIP MODE (PER-AXIS INDEPENDENT FOR GROUPS)
        // ---------------------------------------------------------------------
        var movingClips = getMovingClips();
        var numTracks = root.totalTrackCount();
        var candidateDeltaFrames = rawDesiredStart - originFrame;
        var candidateDeltaTracks = targetTrackIdx - originTrack;
        var lastValidDeltaTracks = lastValidDragTrack - originTrack;
        var lastValidDeltaFrames = lastValidDragFrame - originFrame;

        var minAllowedDelta = -Infinity;
        for (var k = 0; k < movingClips.length; ++k) {
            minAllowedDelta = Math.max(minAllowedDelta, -movingClips[k].startFrame);
        }

        function testGroupPlacement(rawDeltaF, shiftT) {
            for (var m = 0; m < movingClips.length; ++m) {
                var mc = movingClips[m];
                var destT = mc.trackIndex + shiftT;
                if (destT < 0 || destT >= numTracks)
                    return { valid: false, delta: lastValidDeltaFrames };
                if (root.activeTimelineModel.getTrackKind(destT) !== root.activeTimelineModel.getTrackKind(mc.trackIndex))
                    return { valid: false, delta: lastValidDeltaFrames };
            }

            var dF = Math.max(minAllowedDelta, rawDeltaF);

            function getCols(testD) {
                var cols = [];
                for (var a = 0; a < movingClips.length; ++a) {
                    var clipItem = movingClips[a];
                    var tIdx = clipItem.trackIndex + shiftT;
                    var cStart = clipItem.startFrame + testD;
                    var cEnd = cStart + clipItem.durationFrames;
                    var clipsOnTrack = root.activeTimelineModel.getClipsForTrack(tIdx);

                    for (var b = 0; b < clipsOnTrack.length; ++b) {
                        var obstClip = clipsOnTrack[b];
                        if (selIds.indexOf(obstClip.clipId) !== -1)
                            continue;
                        var oStart = Number(obstClip.startFrame);
                        var oEnd = oStart + Number(obstClip.durationFrames);
                        if (cStart < oEnd && cEnd > oStart) {
                            cols.push({ movingClip: clipItem, oStart: oStart, oEnd: oEnd });
                        }
                    }
                }
                return cols;
            }

            var activeCols = getCols(dF);
            if (activeCols.length === 0)
                return { valid: true, delta: dF };

            // Snap flush
            var resolvedD = dF;
            if (rawDeltaF >= lastValidDeltaFrames) {
                var minSnapR = Infinity;
                for (var r = 0; r < activeCols.length; ++r) {
                    var colR = activeCols[r];
                    var snapR = colR.oStart - colR.movingClip.durationFrames - colR.movingClip.startFrame;
                    if (snapR < minSnapR) minSnapR = snapR;
                }
                resolvedD = Math.max(minAllowedDelta, minSnapR);
            } else {
                var maxSnapL = -Infinity;
                for (var l = 0; l < activeCols.length; ++l) {
                    var colL = activeCols[l];
                    var snapL = colL.oEnd - colL.movingClip.startFrame;
                    if (snapL > maxSnapL) maxSnapL = snapL;
                }
                resolvedD = Math.max(minAllowedDelta, maxSnapL);
            }

            if (resolvedD >= minAllowedDelta && getCols(resolvedD).length === 0)
                return { valid: true, delta: resolvedD };

            return { valid: false, delta: lastValidDeltaFrames };
        }

        // 1. Attempt Full 2D Movement for group
        var gRes2D = testGroupPlacement(candidateDeltaFrames, candidateDeltaTracks);
        if (gRes2D.valid) {
            return { valid: true, frame: originFrame + gRes2D.delta, track: originTrack + candidateDeltaTracks };
        }

        // 2. Y is blocked: Fallback Y to last valid track shift, allow X (time) to slide!
        var gResX = testGroupPlacement(candidateDeltaFrames, lastValidDeltaTracks);
        if (gResX.valid) {
            return { valid: true, frame: originFrame + gResX.delta, track: originTrack + lastValidDeltaTracks };
        }

        // 3. X is blocked: Freeze X to last valid frame shift, allow Y (track) to switch!
        var gResY = testGroupPlacement(lastValidDeltaFrames, candidateDeltaTracks);
        if (gResY.valid) {
            return { valid: true, frame: originFrame + gResY.delta, track: originTrack + candidateDeltaTracks };
        }

        // 4. Both axes blocked: stay at last valid
        return { valid: false, frame: lastValidDragFrame, track: lastValidDragTrack };
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

        onPressed: function (mouse) {
            if (mouse.button !== Qt.LeftButton || root.isLocked)
                return;
            // console.log("[dragDebug] onPressed fired, clipId=" + (root.clipData ? root.clipData.clipId : "null") + " trackIndex=" + root.trackIndex);
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

            root.lastValidDragFrame = startClipFrame;
            root.lastValidDragTrack = root.trackIndex;
            root.dragHasValidPlacement = true;

            if (root.activeTimelineModel)
                root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, 0, 0);
        }

        onPositionChanged: function (mouse) {
            if (root.isLocked || !root.isDragging || !(mouse.buttons & Qt.LeftButton) || !root.clipData) {
                // console.log("[dragDebug] onPositionChanged EARLY RETURN: isLocked=" + root.isLocked + " isDragging=" + root.isDragging + " leftButtonHeld=" + !!(mouse.buttons & Qt.LeftButton) + " hasClipData=" + !!root.clipData);
                return;
            }
            didDrag = true;

            var pt = mapToItem(root.parent, mouse.x, mouse.y);
            var deltaPx = pt.x - startCanvasMouseX;
            var rawDeltaFrames = Math.round(deltaPx / root.zoomFactor);
            // console.log("[dragDebug] move: deltaPx=" + deltaPx + " rawDeltaFrames=" + rawDeltaFrames + " zoomFactor=" + root.zoomFactor);

            // 1. Leader Track Clamping (Blocks Video -> Audio, Audio -> Video)
            var rawHoveredTrack = root.timelineRoot ? root.timelineRoot.getTrackAtY(pt.y) : startTrackIdx;
            var safeTrack = root.clampToCompatibleTrack(rawHoveredTrack);
            var myDeltaTracks = safeTrack - startTrackIdx;

            // 2. Mirrored Partner Validation
            var partner = getLinkedPartner();
            if (partner) {
                var totalTracks = root.totalTrackCount();
                // REVERSED movement: If leader moves UP (-1), partner moves DOWN (+1)
                var partnerDeltaTracks = -myDeltaTracks;
                var partnerDestTrack = partner.trackIndex + partnerDeltaTracks;

                var isPartnerValid = (partnerDestTrack >= 0 && partnerDestTrack < totalTracks) &&
                    (root.activeTimelineModel.getTrackKind(partnerDestTrack) === partner.trackKind);

                if (!isPartnerValid) {
                    safeTrack = root.lastValidDragTrack;
                }
            }

            if (isRippleMove) {
                root.localTrackIndex = safeTrack;
                root.localStartFrame = Math.max(0, startClipFrame + rawDeltaFrames);
                root.lastValidDragFrame = root.localStartFrame;
                root.lastValidDragTrack = safeTrack;
            } else {
                var desiredStart = Math.max(0, startClipFrame + rawDeltaFrames);

                // Optional snapping to guides
                var playhead = root.timelineRoot ? Number(root.timelineRoot.playheadFrame ?? -1) : -1;
                var selIds = root.activeTimelineModel?.selectedClipIds ?? [root.clipData.clipId];
                var globalSnapping = root.activeTimelineModel ? root.activeTimelineModel.snappingEnabled : true;
                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                var isSnappingActive = hasShift ? !globalSnapping : globalSnapping;
                var snapResult = (isSnappingActive && root.activeTimelineModel)
                    ? root.activeTimelineModel.querySnap(desiredStart, Number(root.clipData.durationFrames), safeTrack, playhead, root.zoomFactor, selIds, 8.0)
                    : null;
                var candidateFrame = (snapResult && snapResult.isSnapped) ? Number(snapResult.snappedStart) : desiredStart;

                // 2. Hardened Collision Resolution
                var res = root.resolveHardenedPlacement(candidateFrame, safeTrack);
                // console.log("[dragDebug] resolveHardenedPlacement(candidateFrame=" + candidateFrame + ", safeTrack=" + safeTrack + ") => valid=" + res.valid + " frame=" + res.frame + " track=" + res.track + " (safeTrack came from rawHoveredTrack=" + rawHoveredTrack + " -> clamped=" + safeTrack + ")");
                root.localTrackIndex = res.track;
                root.localStartFrame = res.frame;
                root.dragHasValidPlacement = res.valid;

                if (res.valid) {
                    root.lastValidDragFrame = res.frame;
                    root.lastValidDragTrack = res.track;
                }

                if (snapResult && snapResult.isSnapped && root.timelineRoot && res.valid) {
                    if (snapResult.snapType === "spacing" && root.timelineRoot.showSpacingGuides)
                        root.timelineRoot.showSpacingGuides(snapResult.allMatchingGaps);
                    else if (root.timelineRoot.showSnapLine)
                        root.timelineRoot.showSnapLine(snapResult.guideFrame);
                } else if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }
            }

            // 3. Update C++ group drag: pass deltaTracks=0 when linked so C++ doesn't
            // push the partner into the wrong track kind during drag!
            if (root.activeTimelineModel) {
                if (partner) {
                    root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, root.localStartFrame - startClipFrame, 0);
                } else {
                    root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, root.localStartFrame - startClipFrame, root.localTrackIndex - startTrackIdx);
                }
            }
        }

onReleased: function (mouse) {
    if (mouse.button !== Qt.LeftButton || !root.isDragging)
        return;
    root.isDragging = false;

    if (root.timelineRoot && root.timelineRoot.hideSnapGuides)
        root.timelineRoot.hideSnapGuides();
    if (!root.activeTimelineModel || !root.clipData)
        return;

    var finalTrack = root.lastValidDragTrack;
    var finalFrame = Math.round(root.lastValidDragFrame);
    var deltaFrames = finalFrame - startClipFrame;
    var deltaTracks = finalTrack - startTrackIdx;

    if (isRippleMove) {
        var globalDefault = root.activeTimelineModel.globalRippleMode;
        var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
        root.activeTimelineModel.rippleMoveClip(root.clipData.clipId, finalTrack, finalFrame, hasShift ? !globalDefault : globalDefault);
    } else {
        var partnerClip = getLinkedPartner();
        if (partnerClip) {
            root.activeTimelineModel.moveClip(root.clipData.clipId, startTrackIdx, finalTrack, finalFrame);
            var partnerReversedDelta = -deltaTracks;
            var partnerFinalTrack = partnerClip.trackIndex + partnerReversedDelta;
            var partnerFinalFrame = partnerClip.startFrame + deltaFrames;
            root.activeTimelineModel.moveClip(partnerClip.clipId, partnerClip.trackIndex, partnerFinalTrack, partnerFinalFrame);
        } else {
            var selIds = root.activeTimelineModel.selectedClipIds ?? [];
            if (selIds.length > 1)
                root.activeTimelineModel.moveClips(selIds, deltaFrames, deltaTracks);
            else
                root.activeTimelineModel.moveClip(root.clipData.clipId, startTrackIdx, finalTrack, finalFrame);
        }
    }

    root.activeTimelineModel.clearGroupDrag();

    // Don't rely on the model's own change signals to have already
    // refreshed clipRepeater's snapshot by this point — force it, or the
    // delegate will read clipData.startFrame from the stale pre-move
    // array and visually snap back to its old position.
    if (root.timelineRoot && root.timelineRoot.refreshClips)
        root.timelineRoot.refreshClips();

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
root.localSourceInFrame = root.isTextClip ? 0 : (startIn + appliedDelta);

// Live-mirror onto the linked partner (e.g. video<->audio pair)
var partner = root.getLinkedPartner();
if (partner && root.timelineRoot) {
    var partnerItem = root.timelineRoot.findClipDelegate(partner.clipId);
    if (partnerItem) {
        var pBounds = partnerItem.getImmediateNeighborBounds(partner.trackIndex, partner.startFrame, partner.durationFrames);
        var pMinBoundary = partnerItem.isTextClip ? pBounds.minFrame : Math.max(pBounds.minFrame, partner.startFrame - partner.sourceInFrame);
        var pNewStart = Math.max(pMinBoundary, Math.min(partner.startFrame + partner.durationFrames - 1, partner.startFrame + appliedDelta));
        var pAppliedDelta = pNewStart - partner.startFrame;

        partnerItem.isTrimmingLeft = true;
        partnerItem.localStartFrame = pNewStart;
        partnerItem.localDurationFrames = partner.durationFrames - pAppliedDelta;
        partnerItem.localSourceInFrame = partnerItem.isTextClip ? 0 : (partner.sourceInFrame + pAppliedDelta);
    }
}

                root.localStartFrame = newStartFrame;
                root.localDurationFrames = startDur - appliedDelta;

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

    if (root.timelineRoot && root.timelineRoot.refreshClips)
        root.timelineRoot.refreshClips();
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

var partner = root.getLinkedPartner();
if (partner && root.timelineRoot) {
    var partnerItem = root.timelineRoot.findClipDelegate(partner.clipId);
    if (partnerItem) {
        var pBounds = partnerItem.getImmediateNeighborBounds(partner.trackIndex, partner.startFrame, partner.durationFrames);
        var pMaxFromNeighbor = pBounds.maxFrame - partner.startFrame;
        var pMaxAllowed = (partnerItem.isTextClip || !isFinite(partnerItem.totalSourceDuration))
            ? pMaxFromNeighbor
            : Math.min(partnerItem.totalSourceDuration - partner.sourceInFrame, pMaxFromNeighbor);

        partnerItem.isTrimmingRight = true;
        partnerItem.localDurationFrames = Math.max(1, Math.min(pMaxAllowed, partner.durationFrames + (root.localDurationFrames - startDur)));
    }
}

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
    if (root.timelineRoot && root.timelineRoot.refreshClips)
        root.timelineRoot.refreshClips();
            }
        }
    }
}
