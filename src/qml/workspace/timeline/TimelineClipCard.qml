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

    // =========================================================================
    // ACTIVE TOOL & RIPPLE MODE
    // =========================================================================
    readonly property string currentTool: root.timelineRoot?.activeTool ?? "pointer"
    readonly property bool isRippleActive: currentTool === "ripple"

    property bool isRippleTrimmingLeft: false
    property bool isRippleTrimmingRight: false
    // =========================================================================
    // ACTIVE TOOL & RIPPLE MODE
    // =========================================================================
    //
    // =========================================================================
    // ROLL EDIT TOOL STATE & HELPERS
    // =========================================================================
    readonly property bool isRollActive: currentTool === "roll"
    property bool isRollingLeft: false
    property bool isRollingRight: false
    // =========================================================================
    // ROLL EDIT TOOL STATE & HELPERS
    // =========================================================================

    // =========================================================================
    // SLIP TOOL STATE
    // =========================================================================
    readonly property bool isSlipActive: currentTool === "slip"
    property bool isSlipping: false
    property real slipDeltaFrames: 0
    property real originalSourceInFrame: 0
    // =========================================================================
    // SLIP TOOL STATE
    // =========================================================================

    // Finds the clip immediately preceding this clip on the same track (flush at this clip's In-point)
    function getLeftAdjacentClip() {
        if (!root.activeTimelineModel || !root.clipData)
            return null;
        var myStart = Number(root.clipData.startFrame);
        var clips = root.activeTimelineModel.getClipsForTrack(root.trackIndex);
        for (var i = 0; i < clips.length; ++i) {
            var c = clips[i];
            if (c.clipId === root.clipData.clipId)
                continue;
            var cEnd = Number(c.startFrame) + Number(c.durationFrames);
            // Adjacent flush cut (tolerance of 1 frame)
            if (Math.abs(cEnd - myStart) <= 1)
                return c;
        }
        return null;
    }

    // Finds the clip immediately following this clip on the same track (flush at this clip's Out-point)
    function getRightAdjacentClip() {
        if (!root.activeTimelineModel || !root.clipData)
            return null;
        var myEnd = Number(root.clipData.startFrame) + Number(root.clipData.durationFrames);
        var clips = root.activeTimelineModel.getClipsForTrack(root.trackIndex);
        for (var i = 0; i < clips.length; ++i) {
            var c = clips[i];
            if (c.clipId === root.clipData.clipId)
                continue;
            var cStart = Number(c.startFrame);
            // Adjacent flush cut (tolerance of 1 frame)
            if (Math.abs(cStart - myEnd) <= 1)
                return c;
        }
        return null;
    }
    // =========================================================================
    // ROLL EDIT TOOL STATE & HELPERS
    // =========================================================================

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

    x: ((isDragging || isTrimmingLeft) ? localStartFrame : (Number(clipData?.startFrame ?? 0) + groupDeltaFrames)) * root.zoomFactor

    y: (root.timelineRoot ? root.timelineRoot.getTrackY(isDragging ? localTrackIndex : (root.trackIndex + effectiveGroupDeltaTracks)) : ((isDragging ? localTrackIndex : root.trackIndex) * 68)) + 4

    // Behavior on x {
    //     enabled: !isDragging
    //     NumberAnimation {
    //         duration: 160
    //         easing.type: Easing.OutCubic
    //     }
    // }

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
            return {
                valid: true,
                frame: rawDesiredStart,
                track: targetTrackIdx
            };

        var originFrame = (typeof moveMouse !== "undefined" && moveMouse.startClipFrame !== undefined) ? moveMouse.startClipFrame : Number(root.clipData.startFrame ?? 0);
        var originTrack = (typeof moveMouse !== "undefined" && moveMouse.startTrackIdx !== undefined) ? moveMouse.startTrackIdx : root.trackIndex;

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
                    return {
                        valid: false,
                        frame: lastValidDragFrame
                    };
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
                        obstacles.push({
                            oStart: oStart,
                            oEnd: oEnd
                        });
                    }
                }

                if (obstacles.length === 0)
                    return {
                        valid: true,
                        frame: candStart
                    };

                // Snap flush against obstacle boundary
                var snapFrame = candStart;
                if (desiredFrame >= originFrame) {
                    var minStart = Infinity;
                    for (var c = 0; c < obstacles.length; ++c) {
                        if (obstacles[c].oStart < minStart)
                            minStart = obstacles[c].oStart;
                    }
                    snapFrame = minStart - myDur;
                } else {
                    var maxEnd = -Infinity;
                    for (var d = 0; d < obstacles.length; ++d) {
                        if (obstacles[d].oEnd > maxEnd)
                            maxEnd = obstacles[d].oEnd;
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
                        return {
                            valid: false,
                            frame: lastValidDragFrame
                        };
                }

                return {
                    valid: true,
                    frame: snapFrame
                };
            }

            // 1. Attempt Full 2D Movement (Both X and Y)
            var res2D = testSinglePlacement(rawDesiredStart, targetTrackIdx);
            if (res2D.valid) {
                return {
                    valid: true,
                    frame: res2D.frame,
                    track: targetTrackIdx
                };
            }

            // 2. Y is blocked: Fallback Y to lastValidDragTrack, allow X (time) to slide!
            var resX = testSinglePlacement(rawDesiredStart, lastValidDragTrack);
            if (resX.valid) {
                return {
                    valid: true,
                    frame: resX.frame,
                    track: lastValidDragTrack
                };
            }

            // 3. X is blocked: Freeze X to lastValidDragFrame, allow Y (track) to switch!
            var resY = testSinglePlacement(lastValidDragFrame, targetTrackIdx);
            if (resY.valid) {
                return {
                    valid: true,
                    frame: resY.frame,
                    track: targetTrackIdx
                };
            }

            // 4. Both axes blocked: stay at last valid
            return {
                valid: false,
                frame: lastValidDragFrame,
                track: lastValidDragTrack
            };
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
                    return {
                        valid: false,
                        delta: lastValidDeltaFrames
                    };
                if (root.activeTimelineModel.getTrackKind(destT) !== root.activeTimelineModel.getTrackKind(mc.trackIndex))
                    return {
                        valid: false,
                        delta: lastValidDeltaFrames
                    };
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
                            cols.push({
                                movingClip: clipItem,
                                oStart: oStart,
                                oEnd: oEnd
                            });
                        }
                    }
                }
                return cols;
            }

            var activeCols = getCols(dF);
            if (activeCols.length === 0)
                return {
                    valid: true,
                    delta: dF
                };

            // Snap flush
            var resolvedD = dF;
            if (rawDeltaF >= lastValidDeltaFrames) {
                var minSnapR = Infinity;
                for (var r = 0; r < activeCols.length; ++r) {
                    var colR = activeCols[r];
                    var snapR = colR.oStart - colR.movingClip.durationFrames - colR.movingClip.startFrame;
                    if (snapR < minSnapR)
                        minSnapR = snapR;
                }
                resolvedD = Math.max(minAllowedDelta, minSnapR);
            } else {
                var maxSnapL = -Infinity;
                for (var l = 0; l < activeCols.length; ++l) {
                    var colL = activeCols[l];
                    var snapL = colL.oEnd - colL.movingClip.startFrame;
                    if (snapL > maxSnapL)
                        maxSnapL = snapL;
                }
                resolvedD = Math.max(minAllowedDelta, maxSnapL);
            }

            if (resolvedD >= minAllowedDelta && getCols(resolvedD).length === 0)
                return {
                    valid: true,
                    delta: resolvedD
                };

            return {
                valid: false,
                delta: lastValidDeltaFrames
            };
        }

        // 1. Attempt Full 2D Movement for group
        var gRes2D = testGroupPlacement(candidateDeltaFrames, candidateDeltaTracks);
        if (gRes2D.valid) {
            return {
                valid: true,
                frame: originFrame + gRes2D.delta,
                track: originTrack + candidateDeltaTracks
            };
        }

        // 2. Y is blocked: Fallback Y to last valid track shift, allow X (time) to slide!
        var gResX = testGroupPlacement(candidateDeltaFrames, lastValidDeltaTracks);
        if (gResX.valid) {
            return {
                valid: true,
                frame: originFrame + gResX.delta,
                track: originTrack + lastValidDeltaTracks
            };
        }

        // 3. X is blocked: Freeze X to last valid frame shift, allow Y (track) to switch!
        var gResY = testGroupPlacement(lastValidDeltaFrames, candidateDeltaTracks);
        if (gResY.valid) {
            return {
                valid: true,
                frame: originFrame + gResY.delta,
                track: originTrack + candidateDeltaTracks
            };
        }

        // 4. Both axes blocked: stay at last valid
        return {
            valid: false,
            frame: lastValidDragFrame,
            track: lastValidDragTrack
        };
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
        color: root.isLocked ? "#262626" : (root.isAudioTrack ? "#30673AEE"  // Equivalent to Qt.rgba(0.486, 0.227, 0.929, 0.28)
            : (root.isTextClip ? "#30F59E0A"  // Equivalent to Qt.rgba(0.96, 0.62, 0.04, 0.28)
                : "#301D3DFF"  // Equivalent to Qt.rgba(0.114, 0.365, 0.859, 0.3)
            ))
        border.color: (root.isSelected || root.isDragging || root.isTrimmingLeft || root.isTrimmingRight) ? (root.isAudioTrack ? "#A78BFA" : (root.isTextClip ? "#FBBF24" : "#3B82F6")) : (root.isLocked ? "#383838" : (root.isAudioTrack ? Qt.rgba(0.486, 0.227, 0.929, 0.55) : (root.isTextClip ? Qt.rgba(0.96, 0.62, 0.04, 0.55) : Qt.rgba(0.114, 0.365, 0.859, 0.5))))
        border.width: 1
        radius: 2
        clip: true

        Item {
            id: titleHeaderBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 20

            // Left Palette: Title Text
            Rectangle {
                id: textPalette
                anchors.left: parent.left
                // anchors.leftMargin: 4
                anchors.top: parent.top
                // anchors.topMargin: 4
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1 // Leaves room for the bottom border line
                // Dynamically size or anchor between left and right palette
                width: Math.min(parent.width - iconPalette.width - 8, headerText.implicitWidth + 16)
                anchors.rightMargin: 4
                clip: true

                color: root.isLocked ? "#262626" : (root.isAudioTrack ? "#673AEE"  // Equivalent to Qt.rgba(0.486, 0.227, 0.929, 0.28)
                    : (root.isTextClip ? "#F59E0A"  // Equivalent to Qt.rgba(0.96, 0.62, 0.04, 0.28)
                        : "#1D3DFF"  // Equivalent to Qt.rgba(0.114, 0.365, 0.859, 0.3)
                    ))
                topLeftRadius: 2
                bottomLeftRadius: 0
                topRightRadius: 0
                bottomRightRadius: 8

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6

                    Text {
                        id: headerText
                        Layout.fillWidth: true
                        text: root.clipData?.name ?? (root.isTextClip ? "Title" : "Clip")
                        color: root.isLocked ? "#a3a3a3" : "#ffffff"
                        font.pixelSize: 10
                        // font.bold: true
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Right Palette: Icons Container
            Rectangle {
                id: iconPalette
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                visible: root.isLinked || root.isLocked

                // Only take up as much width as the icons need
                width: iconRow.implicitWidth + 12

                color: root.isLocked ? "#262626" : (root.isAudioTrack ? "#673AEE"  // Equivalent to Qt.rgba(0.486, 0.227, 0.929, 0.28)
                    : (root.isTextClip ? "#F59E0A"  // Equivalent to Qt.rgba(0.96, 0.62, 0.04, 0.28)
                        : "#1D3DFF"  // Equivalent to Qt.rgba(0.114, 0.365, 0.859, 0.3)
                    ))
                topLeftRadius: 0
                bottomLeftRadius: 8
                topRightRadius: 2
                bottomRightRadius: 0

                RowLayout {
                    id: iconRow
                    anchors.centerIn: parent
                    spacing: 4

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

        // Cursor:
        //   Slip = horizontal resize / closed hand while dragging
        //   Normal = pointing hand / closed hand while dragging
        cursorShape: root.isLocked ? Qt.ArrowCursor : (root.isSlipActive ? (pressed ? Qt.ClosedHandCursor : Qt.SizeHorCursor) : (moveMouse.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor))

        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startCanvasMouseX: 0
        property real startCanvasMouseY: 0
        property int startClipFrame: 0
        property int startTrackIdx: 0
        property bool didDrag: false
        property bool isRippleMove: false

        // =============================================================
        // SLIP STATE
        // =============================================================

        property int slipStartSourceIn: 0

        onPressed: function (mouse) {
            if (mouse.button !== Qt.LeftButton || root.isLocked)
                return;

            didDrag = false;

            var isToggle = (mouse.modifiers & Qt.ControlModifier) !== 0 || (mouse.modifiers & Qt.MetaModifier) !== 0;

            var isRange = (mouse.modifiers & Qt.ShiftModifier) !== 0;

            if (root.activeTimelineModel && root.clipData) {
                if (isToggle || isRange || !root.isSelected) {
                    root.activeTimelineModel.selectClip(root.clipData.clipId, isToggle, isRange);
                }
            }

            var pt = mapToItem(root.parent, mouse.x, mouse.y);

            startCanvasMouseX = pt.x;
            startCanvasMouseY = pt.y;

            // =============================================================
            // SLIP TOOL
            //
            // IMPORTANT:
            // Do this before normal drag initialization.
            // Slip changes source media only. It must NOT become a move.
            // =============================================================
            if (root.isSlipActive) {
                if (!root.clipData)
                    return;

                root.isSlipping = true;
                root.slipDeltaFrames = 0;

                slipStartSourceIn = Number(root.clipData.sourceInFrame ?? 0);

                root.originalSourceInFrame = slipStartSourceIn;

                root.localSourceInFrame = slipStartSourceIn;

                // Do NOT set:
                // root.isDragging = true
                //
                // A slip keeps the clip's timeline position and duration.
                return;
            }

            // =============================================================
            // NORMAL / RIPPLE MOVE
            // =============================================================

            // Ripple activation:
            //   1. Ripple tool active
            //   2. Ctrl+Alt shortcut
            isRippleMove = root.isRippleActive || ((mouse.modifiers & Qt.ControlModifier) !== 0 && (mouse.modifiers & Qt.AltModifier) !== 0);

            root.isDragging = true;

            if (!root.clipData)
                return;

            startClipFrame = Number(root.clipData.startFrame);

            startTrackIdx = root.trackIndex;

            root.localStartFrame = startClipFrame;

            root.localTrackIndex = root.trackIndex;

            root.lastValidDragFrame = startClipFrame;

            root.lastValidDragTrack = root.trackIndex;

            root.dragHasValidPlacement = true;

            if (root.activeTimelineModel) {
                root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, 0, 0);
            }
        }

        onPositionChanged: function (mouse) {
            if (root.isLocked || !(mouse.buttons & Qt.LeftButton) || !root.clipData) {
                return;
            }

            var pt = mapToItem(root.parent, mouse.x, mouse.y);

            var deltaPx = pt.x - startCanvasMouseX;

            var rawDeltaFrames = Math.round(deltaPx / root.zoomFactor);

            // =============================================================
            // SLIP TOOL
            //
            // Timeline position stays fixed.
            // Only sourceInFrame changes.
            // =============================================================
            if (root.isSlipping) {
                didDrag = true;

                // Drag right  -> source window moves earlier
                // Drag left   -> source window moves later
                //
                // This preserves the existing slip-tool convention.
                var candidateSourceIn = root.originalSourceInFrame - rawDeltaFrames;

                var duration = Number(root.clipData.durationFrames);

                // Valid source range:
                //
                //   0
                //   ...
                //   totalSourceDuration - duration
                //
                var maxSourceIn = (root.isTextClip || !isFinite(root.totalSourceDuration)) ? Infinity : Math.max(0, root.totalSourceDuration - duration);

                var clampedSourceIn = Math.max(0, isFinite(maxSourceIn) ? Math.min(maxSourceIn, candidateSourceIn) : candidateSourceIn);

                var effectiveDelta = root.originalSourceInFrame - clampedSourceIn;

                root.slipDeltaFrames = effectiveDelta;

                root.localSourceInFrame = clampedSourceIn;

                if (waveformCanvas.visible) {
                    waveformCanvas.requestPaint();
                }

                // ---------------------------------------------------------
                // Mirror Slip onto linked partner.
                // ---------------------------------------------------------
                var partner = root.getLinkedPartner();

                if (partner && root.timelineRoot) {
                    var partnerItem = root.timelineRoot.findClipDelegate(partner.clipId);

                    if (partnerItem) {
                        partnerItem.isSlipping = true;

                        partnerItem.slipDeltaFrames = effectiveDelta;

                        // Preserve the existing linked-slip behavior.
                        partnerItem.localSourceInFrame = clampedSourceIn;

                        if (partnerItem.waveformCanvas) {
                            partnerItem.waveformCanvas.requestPaint();
                        }
                    }
                }

                return;
            }

            // =============================================================
            // NORMAL MOVE
            // =============================================================

            if (!root.isDragging)
                return;

            didDrag = true;

            // -------------------------------------------------------------
            // 1. Leader Track Clamping
            //
            // Blocks invalid Video -> Audio / Audio -> Video movement.
            // -------------------------------------------------------------
            var rawHoveredTrack = root.timelineRoot ? root.timelineRoot.getTrackAtY(pt.y) : startTrackIdx;

            var safeTrack = root.clampToCompatibleTrack(rawHoveredTrack);

            var myDeltaTracks = safeTrack - startTrackIdx;

            // -------------------------------------------------------------
            // 2. Mirrored Partner Validation
            // -------------------------------------------------------------
            var partner = getLinkedPartner();

            if (partner) {
                var totalTracks = root.totalTrackCount();

                // Linked partner moves in the opposite vertical direction.
                var partnerDeltaTracks = -myDeltaTracks;

                var partnerDestTrack = partner.trackIndex + partnerDeltaTracks;

                var isPartnerValid = (partnerDestTrack >= 0 && partnerDestTrack < totalTracks) && (root.activeTimelineModel.getTrackKind(partnerDestTrack) === partner.trackKind);

                if (!isPartnerValid) {
                    safeTrack = root.lastValidDragTrack;
                }
            }

            // =============================================================
            // RIPPLE MOVE
            // =============================================================
            if (isRippleMove) {
                root.localTrackIndex = safeTrack;

                root.localStartFrame = Math.max(0, startClipFrame + rawDeltaFrames);

                root.lastValidDragFrame = root.localStartFrame;

                root.lastValidDragTrack = safeTrack;
            } else

            // =============================================================
            // NORMAL MOVE
            // =============================================================
            {
                var desiredStart = Math.max(0, startClipFrame + rawDeltaFrames);

                // ---------------------------------------------------------
                // Optional snapping
                // ---------------------------------------------------------
                var playhead = root.timelineRoot ? Number(root.timelineRoot.playheadFrame ?? -1) : -1;

                var selIds = root.activeTimelineModel?.selectedClipIds ?? [root.clipData.clipId];

                var globalSnapping = root.activeTimelineModel ? root.activeTimelineModel.snappingEnabled : true;

                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;

                var isSnappingActive = hasShift ? !globalSnapping : globalSnapping;

                var snapResult = (isSnappingActive && root.activeTimelineModel) ? root.activeTimelineModel.querySnap(desiredStart, Number(root.clipData.durationFrames), safeTrack, playhead, root.zoomFactor, selIds, 8.0) : null;

                var candidateFrame = (snapResult && snapResult.isSnapped) ? Number(snapResult.snappedStart) : desiredStart;

                // ---------------------------------------------------------
                // Hardened collision resolution
                // ---------------------------------------------------------
                var res = root.resolveHardenedPlacement(candidateFrame, safeTrack);

                root.localTrackIndex = res.track;

                root.localStartFrame = res.frame;

                root.dragHasValidPlacement = res.valid;

                if (res.valid) {
                    root.lastValidDragFrame = res.frame;

                    root.lastValidDragTrack = res.track;
                }

                // ---------------------------------------------------------
                // Snap guides
                // ---------------------------------------------------------
                if (snapResult && snapResult.isSnapped && root.timelineRoot && res.valid) {
                    if (snapResult.snapType === "spacing" && root.timelineRoot.showSpacingGuides) {
                        root.timelineRoot.showSpacingGuides(snapResult.allMatchingGaps);
                    } else if (root.timelineRoot.showSnapLine) {
                        root.timelineRoot.showSnapLine(snapResult.guideFrame);
                    }
                } else if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }
            }

            // =============================================================
            // 3. Update C++ group drag
            //
            // When linked, do NOT pass vertical track delta to C++ because
            // the partner is manually mirrored onto its compatible track.
            // =============================================================
            if (root.activeTimelineModel) {
                if (partner) {
                    root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, root.localStartFrame - startClipFrame, 0);
                } else {
                    root.activeTimelineModel.updateGroupDrag(root.clipData.clipId, root.localStartFrame - startClipFrame, root.localTrackIndex - startTrackIdx);
                }
            }
        }

        onReleased: function (mouse) {
            if (mouse.button !== Qt.LeftButton)
                return;

            // =============================================================
            // SLIP TOOL RELEASE
            // =============================================================
            if (root.isSlipping) {
                root.isSlipping = false;

                var finalSourceIn = Math.round(root.localSourceInFrame);

                if (root.activeTimelineModel && root.clipData) {
                    var duration = Number(root.clipData.durationFrames);

                    var startFrame = Number(root.clipData.startFrame);

                    // -----------------------------------------------------
                    // Commit main clip slip.
                    // -----------------------------------------------------
                    if (typeof root.activeTimelineModel.slipClip === "function") {
                        root.activeTimelineModel.slipClip(root.clipData.clipId, finalSourceIn);
                    } else if (typeof root.activeTimelineModel.trimClip === "function") {
                        // Fallback:
                        // same timeline start + same duration,
                        // only sourceIn changes.
                        root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, startFrame, duration, finalSourceIn, false);
                    }

                    // -----------------------------------------------------
                    // Commit linked partner slip.
                    // -----------------------------------------------------
                    var partner = root.getLinkedPartner();

                    if (partner) {
                        var partnerItem = root.timelineRoot ? root.timelineRoot.findClipDelegate(partner.clipId) : null;

                        if (partnerItem) {
                            partnerItem.isSlipping = false;
                        }

                        if (typeof root.activeTimelineModel.slipClip === "function") {
                            root.activeTimelineModel.slipClip(partner.clipId, finalSourceIn);
                        } else if (typeof root.activeTimelineModel.trimClip === "function") {
                            root.activeTimelineModel.trimClip(partner.clipId, partner.trackIndex, partner.startFrame, partner.durationFrames, finalSourceIn, false);
                        }
                    }
                }

                root.slipDeltaFrames = 0;

                if (root.timelineRoot && root.timelineRoot.refreshClips) {
                    root.timelineRoot.refreshClips();
                }

                return;
            }

            // =============================================================
            // NORMAL MOVE / RIPPLE RELEASE
            // =============================================================

            if (!root.isDragging)
                return;

            root.isDragging = false;

            if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                root.timelineRoot.hideSnapGuides();
            }

            if (!root.activeTimelineModel || !root.clipData) {
                isRippleMove = false;
                return;
            }

            var finalTrack = root.lastValidDragTrack;

            var finalFrame = Math.round(root.lastValidDragFrame);

            var deltaFrames = finalFrame - startClipFrame;

            var deltaTracks = finalTrack - startTrackIdx;

            // =============================================================
            // RIPPLE MOVE COMMIT
            // =============================================================
            if (isRippleMove) {
                var globalDefault = root.activeTimelineModel.globalRippleMode;

                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;

                root.activeTimelineModel.rippleMoveClip(root.clipData.clipId, finalTrack, finalFrame, hasShift ? !globalDefault : globalDefault);
            } else {
                var partnerClip = getLinkedPartner();
                var selIds = root.activeTimelineModel.selectedClipIds ? root.activeTimelineModel.selectedClipIds.slice() : [];

                if (selIds.indexOf(root.clipData.clipId) === -1) {
                    selIds.push(root.clipData.clipId);
                }
                if (partnerClip && selIds.indexOf(partnerClip.clipId) === -1) {
                    selIds.push(partnerClip.clipId);
                }

                if (selIds.length > 1) {
                    root.activeTimelineModel.moveClips(selIds, deltaFrames, deltaTracks);
                } else {
                    root.activeTimelineModel.moveClip(root.clipData.clipId, startTrackIdx, finalTrack, finalFrame);
                }
            }

            root.activeTimelineModel.clearGroupDrag();

            if (root.timelineRoot && root.timelineRoot.refreshClips) {
                root.timelineRoot.refreshClips();
            }

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

    Item {
        id: slipGhostWindow
        visible: root.isSlipping && isFinite(root.totalSourceDuration) && root.totalSourceDuration > 0
        z: 200

        // Position: projects backwards to the start of the master source asset
        x: -Number(root.localSourceInFrame) * root.zoomFactor
        y: 0
        width: Number(root.totalSourceDuration) * root.zoomFactor
        height: parent.height

        // Master media full-length ghostly container
        Rectangle {
            anchors.fill: parent
            color: root.isAudioTrack ? Qt.rgba(0.486, 0.227, 0.929, 0.1) : Qt.rgba(0.114, 0.365, 0.859, 0.1)
            border.color: "#38bdf8"
            border.width: 1
            opacity: 0.85
            radius: 4

            // Top dashed/strip header indicating full asset bounds
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 14
                color: root.isAudioTrack ? Qt.rgba(0.486, 0.227, 0.929, 0.3) : Qt.rgba(0.114, 0.365, 0.859, 0.3)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Master Source: " + Math.round(root.totalSourceDuration) + "f"
                    color: "#93c5fd"
                    font.pixelSize: 9
                    // font.bold: true
                }
            }

            // In-point boundary indicator
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                width: 2
                color: root.localSourceInFrame <= 0 ? "#ef4444" : "#38bdf8" // Red when clamped at head
            }

            // Out-point boundary indicator
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                width: 2
                color: (root.localSourceInFrame + Number(root.clipData?.durationFrames ?? 0) >= root.totalSourceDuration) ? "#ef4444" : "#38bdf8" // Red when clamped at tail
            }
        }

        // Active timeline cut aperture highlight inside the master media
        Rectangle {
            x: Number(root.localSourceInFrame) * root.zoomFactor
            y: 0
            width: Number(root.clipData?.durationFrames ?? 30) * root.zoomFactor
            height: parent.height
            color: "transparent"
            border.color: "#38bdf8"
            border.width: 2

            // Interactive Slip Delta Badge
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: deltaText.implicitWidth + 12
                height: 16
                radius: 6
                color: "#121212" // "#1e293b"
                // border.color: "#38bdf8"
                // border.width: 1

                Text {
                    id: deltaText
                    anchors.centerIn: parent
                    text: "Slip: " + (root.slipDeltaFrames >= 0 ? "+" : "") + Math.round(root.slipDeltaFrames) + "f"
                    color: "#FFFFFF" // "#38bdf8"
                    font.pixelSize: 10
                    // font.bold: true
                }
            }
        }
    }

    // =========================================================================
    // LEFT TRIM (Standard Selection, Ripple, and Roll Edit)
    // =========================================================================
    Rectangle {
        id: leftTrim
        visible: !root.isLocked
        width: (root.isRollActive || root.isRippleActive) ? 3 : 1
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        anchors.bottomMargin: 4

        // Standard: Blue/Purple
        // Ripple: Amber (#D97706)
        // Roll: Cyan (#06B6D4)
        color: {
            if (root.isRollActive)
                return (leftTrimMouse.containsMouse || leftTrimMouse.pressed) ? "#22D3EE" : "#06B6D4";

            if (root.isRippleActive)
                return (leftTrimMouse.containsMouse || leftTrimMouse.pressed) ? "#FBBF24" : "#D97706";

            return (leftTrimMouse.containsMouse || leftTrimMouse.pressed) ? (root.isAudioTrack ? "#C4B5FD" : (root.isTextClip ? "#FCD34D" : "#60A5FA")) : (root.isAudioTrack ? "#7C3AED" : (root.isTextClip ? "#D97706" : "#1D5DDB"));
        }

        z: 100

        MouseArea {
            id: leftTrimMouse

            anchors.fill: parent
            anchors.leftMargin: -4
            anchors.rightMargin: -4

            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            property real startCanvasX: 0
            property int startFrame: 0
            property int startDur: 0
            property int startIn: 0

            // Ripple/normal trim boundary
            property int minBoundaryFrame: 0

            // Roll state
            property var leftNeighbor: null
            property int neighborStartDur: 0
            property int neighborStartFrame: 0
            property int neighborSourceIn: 0
            property int maxLeftRollFrames: 0
            property int maxRightRollFrames: 0

            onPressed: function (mouse) {
                if (root.isLocked)
                    return;

                if (!root.isSelected && root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.selectClip(root.clipData.clipId, false, false);
                }

                root.isTrimmingLeft = true;

                // Roll takes precedence over ripple because they are
                // mutually exclusive edit modes.
                root.isRollingLeft = root.isRollActive;
                root.isRippleTrimmingLeft = root.isRippleActive && !root.isRollActive;

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

                // -------------------------------------------------------------
                // CASE 1: ROLL MODE SETUP
                // -------------------------------------------------------------
                if (root.isRollActive) {
                    leftNeighbor = root.getLeftAdjacentClip();

                    if (leftNeighbor) {
                        neighborStartFrame = Number(leftNeighbor.startFrame);
                        neighborStartDur = Number(leftNeighbor.durationFrames);
                        neighborSourceIn = Number(leftNeighbor.sourceInFrame ?? 0);

                        var neighborAssetDur = (root.activeTimelineModel && leftNeighbor.assetId) ? root.activeTimelineModel.getAssetDuration(leftNeighbor.assetId) : Infinity;

                        // How far the edit point can move LEFT:
                        //
                        // Our clip:
                        //   - must not move before its available source head.
                        //
                        // Left neighbor:
                        //   - must retain at least one frame.
                        //
                        var ourHeadAllowance = root.isTextClip ? startFrame : startIn;

                        var neighborMinDurLimit = Math.max(0, neighborStartDur - 1);

                        maxLeftRollFrames = Math.min(ourHeadAllowance, neighborMinDurLimit);

                        // How far the edit point can move RIGHT:
                        //
                        // Left neighbor:
                        //   - must not run beyond its source media tail.
                        //
                        // Our clip:
                        //   - must retain at least one frame.
                        //
                        var neighborTailAllowance = isFinite(neighborAssetDur) ? Math.max(0, neighborAssetDur - (neighborSourceIn + neighborStartDur)) : Infinity;

                        var ourMinDurLimit = Math.max(0, startDur - 1);

                        maxRightRollFrames = Math.min(neighborTailAllowance, ourMinDurLimit);
                    }

                    // Roll does not use ripple boundaries.
                    minBoundaryFrame = 0;
                    return;
                }

                // -------------------------------------------------------------
                // CASE 2: ORIGINAL RIPPLE / STANDARD TRIM SETUP
                // -------------------------------------------------------------
                if (root.isRippleActive) {
                    // In Ripple Mode, left trim can pull clips all the way
                    // back to 0. Downstream clips are moved by the model
                    // when the edit is committed.
                    minBoundaryFrame = root.isTextClip ? 0 : Math.max(0, startFrame - startIn);
                } else {
                    var bounds = root.getImmediateNeighborBounds(root.trackIndex, startFrame, startDur);

                    minBoundaryFrame = root.isTextClip ? bounds.minFrame : Math.max(bounds.minFrame, startFrame - startIn);
                }
            }

            onPositionChanged: function (mouse) {
                if (root.isLocked || !pressed || !root.clipData)
                    return;

                var pt = mapToItem(root.parent, mouse.x, mouse.y);

                var rawDelta = Math.round((pt.x - startCanvasX) / root.zoomFactor);

                // =============================================================
                // CASE 1: ROLL EDIT
                // =============================================================
                //
                // The boundary between the left neighbor and this clip moves.
                //
                // Moving RIGHT:
                //   neighbor gets longer
                //   this clip gets shorter
                //   this clip sourceIn moves forward
                //
                // Moving LEFT:
                //   neighbor gets shorter
                //   this clip gets longer
                //   this clip sourceIn moves backward
                //
                if (root.isRollingLeft && leftNeighbor) {
                    var clampedRollDelta = Math.max(-maxLeftRollFrames, Math.min(maxRightRollFrames, rawDelta));

                    // Current clip
                    root.localStartFrame = startFrame + clampedRollDelta;

                    root.localDurationFrames = startDur - clampedRollDelta;

                    root.localSourceInFrame = root.isTextClip ? 0 : startIn + clampedRollDelta;

                    // Mirror the edit onto the left neighbor.
                    var neighborItem = root.timelineRoot ? root.timelineRoot.findClipDelegate(leftNeighbor.clipId) : null;

                    if (neighborItem) {
                        neighborItem.isTrimmingRight = true;

                        neighborItem.localStartFrame = neighborStartFrame;

                        neighborItem.localDurationFrames = neighborStartDur + clampedRollDelta;

                        neighborItem.localSourceInFrame = neighborSourceIn;
                    }

                    // Roll does not use normal trim snapping because the
                    // edit point itself is constrained by the two adjacent
                    // clips' media bounds.
                    if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                        root.timelineRoot.hideSnapGuides();
                    }

                    return;
                }

                // =============================================================
                // CASE 2: ORIGINAL STANDARD / RIPPLE LEFT TRIM
                // =============================================================

                var desiredStart = startFrame + rawDelta;

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

                root.localSourceInFrame = root.isTextClip ? 0 : startIn + appliedDelta;

                // -------------------------------------------------------------
                // Preserve original linked-partner behavior.
                // -------------------------------------------------------------
                var partner = root.getLinkedPartner();

                if (partner && root.timelineRoot) {
                    var partnerItem = root.timelineRoot.findClipDelegate(partner.clipId);

                    if (partnerItem) {
                        var pMinBoundary = root.isRippleActive ? (partnerItem.isTextClip ? 0 : Math.max(0, partner.startFrame - partner.sourceInFrame)) : (partnerItem.isTextClip ? partnerItem.getImmediateNeighborBounds(partnerItem.trackIndex, partner.startFrame, partner.durationFrames).minFrame : Math.max(partnerItem.getImmediateNeighborBounds(partnerItem.trackIndex, partner.startFrame, partner.durationFrames).minFrame, partner.startFrame - partner.sourceInFrame));

                        var pNewStart = Math.max(pMinBoundary, Math.min(partner.startFrame + partner.durationFrames - 1, partner.startFrame + appliedDelta));

                        var pAppliedDelta = pNewStart - partner.startFrame;

                        partnerItem.isTrimmingLeft = true;

                        partnerItem.localStartFrame = pNewStart;

                        partnerItem.localDurationFrames = partner.durationFrames - pAppliedDelta;

                        partnerItem.localSourceInFrame = partnerItem.isTextClip ? 0 : partner.sourceInFrame + pAppliedDelta;
                    }
                }

                // Preserve original snap guides.
                if (snapResult && snapResult.isSnapped && root.timelineRoot && root.timelineRoot.showSnapLine) {
                    root.timelineRoot.showSnapLine(snapResult.guideFrame);
                } else if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }
            }

            onReleased: function () {
                if (root.isLocked)
                    return;

                var wasRoll = root.isRollingLeft;

                var wasRipple = root.isRippleTrimmingLeft;

                var neighbor = leftNeighbor;

                // Clear primary edit states first.
                root.isTrimmingLeft = false;
                root.isRollingLeft = false;
                root.isRippleTrimmingLeft = false;

                leftNeighbor = null;

                if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }

                if (!root.activeTimelineModel || !root.clipData) {
                    return;
                }

                var finalStart = Math.round(root.localStartFrame);

                var finalDur = Math.round(root.localDurationFrames);

                var finalSourceIn = root.isTextClip ? 0 : Math.round(root.localSourceInFrame);

                // =============================================================
                // CASE 1: COMMIT ROLL
                // =============================================================
                if (wasRoll && neighbor) {
                    var neighborItem = root.timelineRoot ? root.timelineRoot.findClipDelegate(neighbor.clipId) : null;

                    var neighborFinalDur = neighborItem ? Math.round(neighborItem.localDurationFrames) : (neighborStartDur + (finalStart - startFrame));

                    if (neighborItem) {
                        neighborItem.isTrimmingRight = false;
                    }

                    // Prefer the atomic model-level roll operation.
                    if (typeof root.activeTimelineModel.rollEdit === "function") {
                        root.activeTimelineModel.rollEdit(neighbor.clipId, root.clipData.clipId, finalStart);
                    } else {
                        // Fallback: commit both sides without ripple.
                        if (typeof root.activeTimelineModel.trimClip === "function") {
                            root.activeTimelineModel.trimClip(neighbor.clipId, root.trackIndex, Number(neighbor.startFrame), neighborFinalDur, Number(neighbor.sourceInFrame ?? 0), false);

                            root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, finalStart, finalDur, finalSourceIn, false);
                        }
                    }
                } else

                // =============================================================
                // CASE 2: COMMIT ORIGINAL RIPPLE TRIM
                // =============================================================
                if (wasRipple) {
                    if (typeof root.activeTimelineModel.rippleTrimClip === "function") {
                        // C++:
                        // rippleTrimClip(
                        //     clipId,
                        //     trackIndex,
                        //     newStartFrame,
                        //     newDuration,
                        //     newSourceIn,
                        //     isRightTrim
                        // )
                        root.activeTimelineModel.rippleTrimClip(root.clipData.clipId, root.trackIndex, finalStart, finalDur, finalSourceIn, false);
                    } else if (typeof root.activeTimelineModel.trimClip === "function") {
                        // Preserve the working ripple=true path.
                        root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, finalStart, finalDur, finalSourceIn, true);
                    }
                } else

                // =============================================================
                // CASE 3: COMMIT ORIGINAL STANDARD TRIM
                // =============================================================
                if (typeof root.activeTimelineModel.trimClip === "function") {
                    root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, finalStart, finalDur, finalSourceIn, false);
                }

                if (root.timelineRoot && root.timelineRoot.refreshClips) {
                    root.timelineRoot.refreshClips();
                }
            }
        }
    }

    // =========================================================================
    // RIGHT TRIM (Standard Selection, Ripple, and Roll Edit)
    // =========================================================================
    Rectangle {
        id: rightTrim
        visible: !root.isLocked
        width: (root.isRollActive || root.isRippleActive) ? 3 : 1
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        anchors.bottomMargin: 4

        // Standard: Blue/Purple
        // Ripple: Amber (#D97706)
        // Roll: Cyan (#06B6D4)
        color: {
            if (root.isRollActive)
                return (rightTrimMouse.containsMouse || rightTrimMouse.pressed) ? "#22D3EE" : "#06B6D4";

            if (root.isRippleActive)
                return (rightTrimMouse.containsMouse || rightTrimMouse.pressed) ? "#FBBF24" : "#D97706";

            return (rightTrimMouse.containsMouse || rightTrimMouse.pressed) ? (root.isAudioTrack ? "#C4B5FD" : (root.isTextClip ? "#FCD34D" : "#60A5FA")) : (root.isAudioTrack ? "#7C3AED" : (root.isTextClip ? "#D97706" : "#1D5DDB"));
        }

        z: 100

        MouseArea {
            id: rightTrimMouse

            anchors.fill: parent
            anchors.leftMargin: -4
            anchors.rightMargin: -4

            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            property real startCanvasX: 0
            property int startFrame: 0
            property int startDur: 0
            property int startIn: 0

            // -------------------------------------------------------------
            // Roll state
            // -------------------------------------------------------------
            property var rightNeighbor: null
            property int neighborStartFrame: 0
            property int neighborStartDur: 0
            property int neighborStartIn: 0

            property int maxLeftRollFrames: 0
            property int maxRightRollFrames: 0

            // -------------------------------------------------------------
            // Ripple / normal trim state
            // -------------------------------------------------------------
            property real maxAllowedDuration: 0

            onPressed: function (mouse) {
                if (root.isLocked)
                    return;

                if (!root.isSelected && root.activeTimelineModel && root.clipData) {
                    root.activeTimelineModel.selectClip(root.clipData.clipId, false, false);
                }

                root.isTrimmingRight = true;

                // Roll takes priority over ripple.
                root.isRollingRight = root.isRollActive;
                root.isRippleTrimmingRight = root.isRippleActive && !root.isRollActive;

                if (!root.clipData)
                    return;

                var pt = mapToItem(root.parent, mouse.x, mouse.y);

                startCanvasX = pt.x;
                startFrame = Number(root.clipData.startFrame);
                startDur = Number(root.clipData.durationFrames);
                startIn = Number(root.clipData.sourceInFrame);

                root.localDurationFrames = startDur;

                // =============================================================
                // CASE 1: ROLL MODE SETUP
                // =============================================================
                if (root.isRollActive) {
                    rightNeighbor = root.getRightAdjacentClip();

                    if (rightNeighbor) {
                        neighborStartFrame = Number(rightNeighbor.startFrame);

                        neighborStartDur = Number(rightNeighbor.durationFrames);

                        neighborStartIn = Number(rightNeighbor.sourceInFrame ?? 0);

                        var myAssetDur = (root.activeTimelineModel && root.clipData.assetId) ? root.activeTimelineModel.getAssetDuration(root.clipData.assetId) : Infinity;

                        // -----------------------------------------------------
                        // Moving the roll boundary LEFT:
                        //
                        // Current clip becomes shorter.
                        // Right neighbor becomes longer.
                        //
                        // Limited by:
                        //   1. current clip minimum duration
                        //   2. right neighbor's available source head
                        // -----------------------------------------------------
                        var neighborHeadAllowance = (rightNeighbor.isTextClip || !isFinite(neighborStartIn)) ? neighborStartFrame : neighborStartIn;

                        var ourMinDurLimit = Math.max(0, startDur - 1);

                        maxLeftRollFrames = Math.min(neighborHeadAllowance, ourMinDurLimit);

                        // -----------------------------------------------------
                        // Moving the roll boundary RIGHT:
                        //
                        // Current clip becomes longer.
                        // Right neighbor becomes shorter.
                        //
                        // Limited by:
                        //   1. current clip's source media tail
                        //   2. right neighbor minimum duration
                        // -----------------------------------------------------
                        var myTailAllowance = (root.isTextClip || !isFinite(myAssetDur)) ? Infinity : Math.max(0, myAssetDur - (startIn + startDur));

                        var neighborMinDurLimit = Math.max(0, neighborStartDur - 1);

                        maxRightRollFrames = Math.min(myTailAllowance, neighborMinDurLimit);
                    }

                    // Roll does not use normal trim boundaries.
                    maxAllowedDuration = Infinity;

                    return;
                }

                // =============================================================
                // CASE 2: ORIGINAL RIPPLE / STANDARD TRIM SETUP
                // =============================================================

                // In Ripple Mode, the right edge is not blocked by
                // downstream neighbor clips. The model will move them
                // when the ripple operation is committed.
                if (root.isRippleActive) {
                    if (root.isTextClip || !isFinite(root.totalSourceDuration)) {
                        maxAllowedDuration = Infinity;
                    } else {
                        maxAllowedDuration = root.totalSourceDuration - startIn;
                    }
                } else {
                    var bounds = root.getImmediateNeighborBounds(root.trackIndex, startFrame, startDur);

                    var maxFromNeighbor = bounds.maxFrame - startFrame;

                    if (root.isTextClip || !isFinite(root.totalSourceDuration)) {
                        maxAllowedDuration = maxFromNeighbor;
                    } else {
                        maxAllowedDuration = Math.min(root.totalSourceDuration - startIn, maxFromNeighbor);
                    }
                }
            }

            onPositionChanged: function (mouse) {
                if (root.isLocked || !pressed || !root.clipData) {
                    return;
                }

                var pt = mapToItem(root.parent, mouse.x, mouse.y);

                var rawDelta = Math.round((pt.x - startCanvasX) / root.zoomFactor);

                // =============================================================
                // CASE 1: ROLL EDIT
                // =============================================================
                //
                // Right edge of current clip and left edge of right neighbor
                // move together.
                //
                // delta < 0:
                //   current clip gets shorter
                //   right neighbor gets longer
                //
                // delta > 0:
                //   current clip gets longer
                //   right neighbor gets shorter
                //
                if (root.isRollingRight && rightNeighbor) {
                    var clampedRollDelta = Math.max(-maxLeftRollFrames, Math.min(maxRightRollFrames, rawDelta));

                    // Current clip
                    root.localDurationFrames = startDur + clampedRollDelta;

                    // Update right neighbor visually in real time.
                    var neighborItem = root.timelineRoot ? root.timelineRoot.findClipDelegate(rightNeighbor.clipId) : null;

                    if (neighborItem) {
                        neighborItem.isTrimmingLeft = true;

                        neighborItem.localStartFrame = neighborStartFrame + clampedRollDelta;

                        neighborItem.localDurationFrames = neighborStartDur - clampedRollDelta;

                        neighborItem.localSourceInFrame = rightNeighbor.isTextClip ? 0 : neighborStartIn + clampedRollDelta;
                    }

                    // Roll does not use ordinary snap guides.
                    if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                        root.timelineRoot.hideSnapGuides();
                    }

                    return;
                }

                // =============================================================
                // CASE 2: ORIGINAL STANDARD / RIPPLE TRIM
                // =============================================================

                var desiredEnd = startFrame + startDur + rawDelta;

                var playhead = root.timelineRoot ? Number(root.timelineRoot.playheadFrame ?? -1) : -1;

                var selIds = root.activeTimelineModel?.selectedClipIds ?? [root.clipData.clipId];

                var globalSnapping = root.activeTimelineModel ? root.activeTimelineModel.snappingEnabled : true;

                var hasShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;

                var isSnappingActive = hasShift ? !globalSnapping : globalSnapping;

                var snapResult = (isSnappingActive && root.activeTimelineModel) ? root.activeTimelineModel.querySnap(desiredEnd, 0, root.trackIndex, playhead, root.zoomFactor, selIds, 8.0) : null;

                var candidateEnd = (snapResult && snapResult.isSnapped) ? Number(snapResult.snappedStart) : desiredEnd;

                var newDuration = Math.max(1, candidateEnd - startFrame);

                if (isFinite(maxAllowedDuration)) {
                    newDuration = Math.min(maxAllowedDuration, newDuration);
                }

                root.localDurationFrames = newDuration;

                // -------------------------------------------------------------
                // Preserve original linked-partner behavior.
                // -------------------------------------------------------------
                var partner = root.getLinkedPartner();

                if (partner && root.timelineRoot) {
                    var partnerItem = root.timelineRoot.findClipDelegate(partner.clipId);

                    if (partnerItem) {
                        var pMaxAllowed;

                        if (root.isRippleActive || partnerItem.isTextClip || !isFinite(partnerItem.totalSourceDuration)) {
                            pMaxAllowed = (root.isRippleActive && isFinite(partnerItem.totalSourceDuration)) ? (partnerItem.totalSourceDuration - partner.sourceInFrame) : Infinity;
                        } else {
                            pMaxAllowed = Math.min(partnerItem.totalSourceDuration - partner.sourceInFrame, partnerItem.getImmediateNeighborBounds(partnerItem.trackIndex, partner.startFrame, partner.durationFrames).maxFrame - partner.startFrame);
                        }

                        partnerItem.isTrimmingRight = true;

                        partnerItem.localDurationFrames = Math.max(1, Math.min(pMaxAllowed, partner.durationFrames + (root.localDurationFrames - startDur)));
                    }
                }

                // -------------------------------------------------------------
                // Preserve original snap guides.
                // -------------------------------------------------------------
                if (snapResult && snapResult.isSnapped && root.timelineRoot && root.timelineRoot.showSnapLine) {
                    root.timelineRoot.showSnapLine(snapResult.guideFrame);
                } else if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }
            }

            onReleased: function () {
                if (root.isLocked)
                    return;

                var wasRoll = root.isRollingRight;

                var wasRipple = root.isRippleTrimmingRight;

                var neighbor = rightNeighbor;

                // Clear edit states.
                root.isTrimmingRight = false;
                root.isRollingRight = false;
                root.isRippleTrimmingRight = false;

                rightNeighbor = null;

                if (root.timelineRoot && root.timelineRoot.hideSnapGuides) {
                    root.timelineRoot.hideSnapGuides();
                }

                if (!root.activeTimelineModel || !root.clipData) {
                    return;
                }

                var finalDur = Math.round(root.localDurationFrames);

                var finalSourceIn = root.isTextClip ? 0 : Number(root.clipData.sourceInFrame);

                // =============================================================
                // CASE 1: COMMIT ROLL
                // =============================================================
                if (wasRoll && neighbor) {
                    var neighborItem = root.timelineRoot ? root.timelineRoot.findClipDelegate(neighbor.clipId) : null;

                    var durationDelta = finalDur - startDur;

                    var neighborFinalStart = neighborItem ? Math.round(neighborItem.localStartFrame) : (neighborStartFrame + durationDelta);

                    var neighborFinalDur = neighborItem ? Math.round(neighborItem.localDurationFrames) : (neighborStartDur - durationDelta);

                    var neighborFinalIn = neighborItem ? Math.round(neighborItem.localSourceInFrame) : (neighborStartIn + durationDelta);

                    if (neighborItem) {
                        neighborItem.isTrimmingLeft = false;
                    }

                    // Prefer atomic roll operation.
                    if (typeof root.activeTimelineModel.rollEdit === "function") {
                        root.activeTimelineModel.rollEdit(root.clipData.clipId, neighbor.clipId, startFrame + finalDur);
                    } else if (typeof root.activeTimelineModel.trimClip === "function") {
                        // Fallback: commit both sides atomically
                        // from the model's perspective.
                        root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Number(root.clipData.startFrame), finalDur, finalSourceIn, false);

                        root.activeTimelineModel.trimClip(neighbor.clipId, root.trackIndex, neighborFinalStart, neighborFinalDur, neighborFinalIn, false);
                    }
                } else

                // =============================================================
                // CASE 2: COMMIT ORIGINAL RIPPLE TRIM
                // =============================================================
                if (wasRipple) {
                    if (typeof root.activeTimelineModel.rippleTrimClip === "function") {
                        // C++:
                        // rippleTrimClip(
                        //     clipId,
                        //     trackIndex,
                        //     startFrame,
                        //     newDuration,
                        //     sourceIn,
                        //     isRightTrim
                        // )
                        //
                        // RIGHT trim => isRightTrim = true
                        root.activeTimelineModel.rippleTrimClip(root.clipData.clipId, root.trackIndex, Number(root.clipData.startFrame), finalDur, finalSourceIn, true);
                    } else if (typeof root.activeTimelineModel.trimClip === "function") {
                        // Preserve the working ripple=true path.
                        root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Number(root.clipData.startFrame), finalDur, finalSourceIn, true);
                    }
                } else

                // =============================================================
                // CASE 3: COMMIT NORMAL TRIM
                // =============================================================
                if (typeof root.activeTimelineModel.trimClip === "function") {
                    root.activeTimelineModel.trimClip(root.clipData.clipId, root.trackIndex, Number(root.clipData.startFrame), finalDur, finalSourceIn, false);
                }

                if (root.timelineRoot && root.timelineRoot.refreshClips) {
                    root.timelineRoot.refreshClips();
                }
            }
        }
    }
}
