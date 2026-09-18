import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "./timeline"
import "./dopesheet"
import "./animationGraph"

import Xyla.Animation 1.0

Item {
    id: dopesheetRoot

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null

    property string activeClipId: activeTimelineModel ? (activeTimelineModel.selectedClipId || "") : ""
    property var activeClipData: activeTimelineModel ? (activeTimelineModel.selectedClipData || null) : null
    readonly property bool hasClip: activeClipId !== "" && activeClipId !== "null"
    property bool normalizeCurves: false

    // Persistent storage for custom track properties
    property var customTrackColors: ({})
    property var hiddenCurves: ({})          // Curve visibility in graph view
    property var customTrackMutes: ({})      // Track muting state
    property var customTrackLocks: ({})      // Track locking state

    readonly property int currentPlayheadFrame: activePlaybackManager ? activePlaybackManager.currentFrame : 0

    // 0: Dopesheet (Diamonds), 1: Animation / Speed Graph (Curves)
    property int activeViewMode: 0

    // ── Active Tool State ────────────────────────────────────────
    property string activeTool: "pointer"
    property int activeToolIndex: 0

    // ── Multi-Target Snapping State ─────────────────────────────
    property bool snappingEnabled: true
    property bool snapToFrames: true
    property bool snapToOtherKeys: true
    property bool snapToPlayhead: true

    property real zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real contentWidth: 5000

    property int headerWidth: 200
    property int minHeaderWidth: 140
    property int maxHeaderWidth: 500

    property string activePropId: ""

    readonly property int graphRulerWidth: 44
    readonly property int effectiveHeaderWidth: headerWidth + (activeViewMode === 1 ? graphRulerWidth : 0)

    HoverHandler {
        onHoveredChanged: if (hovered && typeof layoutController !== "undefined" && layoutController)
            layoutController.setActiveDockId("DopesheetPanel")
    }

    property var selectedKeyframes: []
    property var rawChannelsData: []
    property var collapsedNodes: ({})
    property int expansionRevision: 0

    // ── Quick-Action Handlers for Tree ───────────────────────────
    function toggleTrackVisibility(clipId, propId, isSolo, isEnableAll) {
        var key = (clipId && clipId !== "") ? (clipId + "|" + propId) : propId;

        // 1. Alt + Click: Enable / Show All
        if (isEnableAll) {
            dopesheetRoot.hiddenCurves = ({});
            dopesheetRoot.expansionRevision++;
            return;
        }

        // 2. Shift + Click: Solo Mode
        if (isSolo) {
            var otherVisibleCount = 0;
            for (var j = 0; j < rawChannelsData.length; ++j) {
                var otherCh = rawChannelsData[j];
                if (otherCh.id !== propId) {
                    var oKey = (otherCh.clipId || dopesheetRoot.activeClipId) + "|" + otherCh.id;
                    if (!dopesheetRoot.hiddenCurves[otherCh.id] && !dopesheetRoot.hiddenCurves[oKey]) {
                        otherVisibleCount++;
                    }
                }
            }

            var thisIsVisible = !dopesheetRoot.hiddenCurves[propId] && !dopesheetRoot.hiddenCurves[key];
            if (otherVisibleCount === 0 && thisIsVisible) {
                dopesheetRoot.hiddenCurves = ({});
            } else {
                var newHidden = {};
                for (var i = 0; i < rawChannelsData.length; ++i) {
                    var ch = rawChannelsData[i];
                    var chClip = ch.clipId || dopesheetRoot.activeClipId;
                    var chKey = (chClip && chClip !== "") ? (chClip + "|" + ch.id) : ch.id;
                    if (ch.id !== propId && chKey !== key) {
                        newHidden[ch.id] = true;
                        newHidden[chKey] = true;
                    }
                }
                dopesheetRoot.hiddenCurves = newHidden;
            }
            dopesheetRoot.expansionRevision++;
            return;
        }

        // 3. Normal Click: Toggle individual track
        var copy = Object.assign({}, dopesheetRoot.hiddenCurves);
        var curHidden = !!(copy[key] || copy[propId]);

        if (curHidden) {
            delete copy[key];
            delete copy[propId];
        } else {
            copy[key] = true;
            copy[propId] = true;
        }

        dopesheetRoot.hiddenCurves = copy;
        dopesheetRoot.expansionRevision++;
    }

    function toggleTrackMute(clipId, propId) {
        var key = (clipId && clipId !== "") ? (clipId + "|" + propId) : propId;
        var curMuted = !!dopesheetRoot.customTrackMutes[key];

        for (var i = 0; i < rawChannelsData.length; ++i) {
            if (rawChannelsData[i].id === propId) {
                if (dopesheetRoot.customTrackMutes[key] === undefined)
                    curMuted = !!rawChannelsData[i].isMuted;
                break;
            }
        }

        var copy = Object.assign({}, dopesheetRoot.customTrackMutes);
        copy[key] = !curMuted;
        copy[propId] = !curMuted;
        dopesheetRoot.customTrackMutes = copy;

        if (activeTimelineModel) {
            if (typeof activeTimelineModel.toggleTrackMute === "function") {
                // Pass single propId to avoid "Too many arguments" warning
                activeTimelineModel.toggleTrackMute(propId);
            } else if (typeof activeTimelineModel.setTrackMuted === "function") {
                if (activeTimelineModel.setTrackMuted.length === 2) {
                    activeTimelineModel.setTrackMuted(propId, !curMuted);
                } else {
                    activeTimelineModel.setTrackMuted(clipId, propId, !curMuted);
                }
            }
        }
        dopesheetRoot.expansionRevision++;
    }

    function toggleTrackLock(clipId, propId) {
        var key = (clipId && clipId !== "") ? (clipId + "|" + propId) : propId;
        var curLocked = !!dopesheetRoot.customTrackLocks[key];

        for (var i = 0; i < rawChannelsData.length; ++i) {
            if (rawChannelsData[i].id === propId) {
                if (dopesheetRoot.customTrackLocks[key] === undefined)
                    curLocked = !!rawChannelsData[i].isLocked;
                break;
            }
        }

        var copy = Object.assign({}, dopesheetRoot.customTrackLocks);
        copy[key] = !curLocked;
        copy[propId] = !curLocked;
        dopesheetRoot.customTrackLocks = copy;

        if (activeTimelineModel) {
            if (typeof activeTimelineModel.toggleTrackLock === "function") {
                // Pass single propId to avoid "Too many arguments" warning
                activeTimelineModel.toggleTrackLock(propId);
            } else if (typeof activeTimelineModel.setTrackLocked === "function") {
                if (activeTimelineModel.setTrackLocked.length === 2) {
                    activeTimelineModel.setTrackLocked(propId, !curLocked);
                } else {
                    activeTimelineModel.setTrackLocked(clipId, propId, !curLocked);
                }
            }
        }
        dopesheetRoot.expansionRevision++;
    }

    // ── Tool Engines ─────────────────────────────────────────────
    function deleteSelectedKeyframes() {
        if (!activeTimelineModel || selectedKeyframes.length === 0)
            return;
        activeTimelineModel.removeKeyframes(selectedKeyframes);
        selectedKeyframes = [];
        refreshChannels();
    }

    function deleteKeyframesBatch(keysToDelete) {
        if (!activeTimelineModel || !keysToDelete || keysToDelete.length === 0)
            return;

        if (typeof activeTimelineModel.removeKeyframes === "function") {
            activeTimelineModel.removeKeyframes(keysToDelete);
        } else {
            for (var i = 0; i < keysToDelete.length; ++i) {
                var k = keysToDelete[i];
                if (typeof activeTimelineModel.deleteKeyframe === "function") {
                    activeTimelineModel.deleteKeyframe(k.clipId, k.propId, k.frame);
                } else if (typeof activeTimelineModel.removeKeyframe === "function") {
                    activeTimelineModel.removeKeyframe(k.clipId, k.propId, k.frame);
                }
            }
        }

        var cur = dopesheetRoot.selectedKeyframes.slice();
        dopesheetRoot.selectedKeyframes = cur.filter(function (s) {
            return !keysToDelete.some(function (d) {
                return (d.propId === s.propId && Math.round(d.frame) === Math.round(s.frame));
            });
        });
        refreshChannels();
    }

    function commitScaledKeyframes(scaledList) {
        if (!activeTimelineModel || !scaledList || scaledList.length === 0)
            return;

        var items = scaledList.slice();
        items.sort(function (a, b) {
            return b.newFrame - a.newFrame;
        });

        for (var i = 0; i < items.length; ++i) {
            var item = items[i];
            if (item.oldFrame !== item.newFrame && typeof activeTimelineModel.moveKeyframe === "function") {
                activeTimelineModel.moveKeyframe(item.clipId, item.propId, item.oldFrame, item.newFrame);
            }
        }

        var updatedSel = [];
        for (var j = 0; j < scaledList.length; ++j) {
            updatedSel.push({
                clipId: scaledList[j].clipId,
                propId: scaledList[j].propId,
                frame: scaledList[j].newFrame
            });
        }
        dopesheetRoot.selectedKeyframes = updatedSel;
        refreshChannels();
    }

    function applyClonedValue(clipId, propId, frame, clonedData) {
        if (!activeTimelineModel || !clonedData)
            return;

        var val = clonedData.value;
        var interp = clonedData.interp !== undefined ? clonedData.interp : 1;
        var inX = clonedData.inX !== undefined ? clonedData.inX : 0.666;
        var inY = clonedData.inY !== undefined ? clonedData.inY : 0.0;
        var outX = clonedData.outX !== undefined ? clonedData.outX : 0.333;
        var outY = clonedData.outY !== undefined ? clonedData.outY : 0.0;

        if (typeof activeTimelineModel.updateKeyframe === "function") {
            activeTimelineModel.updateKeyframe(clipId, propId, frame, frame, val, interp, inX, inY, outX, outY);
        } else if (typeof activeTimelineModel.setKeyframeValue === "function") {
            activeTimelineModel.setKeyframeValue(clipId, propId, frame, val);
        }
        refreshChannels();
    }

    readonly property var treeRows: {
        var _rev = expansionRevision;

        if (!hasClip)
            return [];

        var rows = [];
        var clipName = activeClipData ? (activeClipData.name || "Selected Clip") : "Selected Clip";
        var clipRowId = "clip_" + activeClipId;
        var clipExpanded = !collapsedNodes[clipRowId];

        var clipKeysMap = {};
        for (var i = 0; i < rawChannelsData.length; ++i) {
            var kfs = rawChannelsData[i].keyframes || [];
            for (var k = 0; k < kfs.length; ++k)
                clipKeysMap[kfs[k]] = true;
        }
        var clipSummaryKeys = Object.keys(clipKeysMap).map(Number).sort((a, b) => a - b);
        rows.push({
            id: clipRowId,
            clipId: activeClipId,
            name: clipName,
            type: "clip",
            indent: 0,
            isExpandable: true,
            expanded: clipExpanded,
            keyCount: clipSummaryKeys.length,
            keyframes: clipSummaryKeys
        });

        if (!clipExpanded)
            return rows;

        var groups = {};
        for (var c = 0; c < rawChannelsData.length; ++c) {
            var ch = rawChannelsData[c];
            if (!ch.keyframes || ch.keyframes.length === 0)
                continue;

            var grp = ch.group || "Parameters";
            if (!groups[grp])
                groups[grp] = [];
            groups[grp].push(ch);
        }

        for (var grpName in groups) {
            var grpChannels = groups[grpName];
            var grpRowId = clipRowId + "_" + grpName;
            var grpExpanded = !collapsedNodes[grpRowId];
            var grpClipId = (grpChannels.length > 0 && grpChannels[0].clipId) ? grpChannels[0].clipId : activeClipId;

            var grpKeysMap = {};
            for (var j = 0; j < grpChannels.length; ++j) {
                var gKfs = grpChannels[j].keyframes || [];
                for (var gk = 0; gk < gKfs.length; ++gk)
                    grpKeysMap[gKfs[gk]] = true;
            }
            var grpSummaryKeys = Object.keys(grpKeysMap).map(Number).sort((a, b) => a - b);

            rows.push({
                id: grpRowId,
                clipId: grpClipId,
                name: grpName,
                type: "group",
                indent: 1,
                isExpandable: true,
                expanded: grpExpanded,
                keyCount: grpSummaryKeys.length,
                keyframes: grpSummaryKeys
            });

            if (!grpExpanded)
                continue;

            var subgroups = {};
            var standalone = [];

            for (var sc = 0; sc < grpChannels.length; ++sc) {
                var chItem = grpChannels[sc];
                if (chItem.parent && chItem.parent !== "") {
                    if (!subgroups[chItem.parent])
                        subgroups[chItem.parent] = [];
                    subgroups[chItem.parent].push(chItem);
                } else {
                    standalone.push(chItem);
                }
            }

            for (var subName in subgroups) {
                var subChannels = subgroups[subName];
                var subRowId = grpRowId + "_" + subName;
                var subExpanded = !collapsedNodes[subRowId];
                var subClipId = (subChannels.length > 0 && subChannels[0].clipId) ? subChannels[0].clipId : grpClipId;

                var subKeysMap = {};
                for (var sj = 0; sj < subChannels.length; ++sj) {
                    var sKfs = subChannels[sj].keyframes || [];
                    for (var sk = 0; sk < sKfs.length; ++sk)
                        subKeysMap[sKfs[sk]] = true;
                }
                var subSummaryKeys = Object.keys(subKeysMap).map(Number).sort((a, b) => a - b);

                rows.push({
                    id: subRowId,
                    clipId: subClipId,
                    name: subName,
                    type: "group",
                    indent: 2,
                    isExpandable: true,
                    expanded: subExpanded,
                    keyCount: subSummaryKeys.length,
                    keyframes: subSummaryKeys
                });

                if (subExpanded) {
                    for (var sci = 0; sci < subChannels.length; ++sci) {
                        var leaf = subChannels[sci];
                        var leafClip = leaf.clipId || subClipId;
                        var assignedLeafColor = dopesheetRoot.customTrackColors[leaf.id] || dopesheetRoot.customTrackColors[leafClip + "|" + leaf.id] || leaf.color || "#3B82F6";

                        var isMutedVal = dopesheetRoot.customTrackMutes[leafClip + "|" + leaf.id] !== undefined ? !!dopesheetRoot.customTrackMutes[leafClip + "|" + leaf.id] : (dopesheetRoot.customTrackMutes[leaf.id] !== undefined ? !!dopesheetRoot.customTrackMutes[leaf.id] : !!leaf.isMuted);
                        var isLockedVal = dopesheetRoot.customTrackLocks[leafClip + "|" + leaf.id] !== undefined ? !!dopesheetRoot.customTrackLocks[leafClip + "|" + leaf.id] : (dopesheetRoot.customTrackLocks[leaf.id] !== undefined ? !!dopesheetRoot.customTrackLocks[leaf.id] : !!leaf.isLocked);
                        var isVisVal = dopesheetRoot.hiddenCurves[leafClip + "|" + leaf.id] !== true && dopesheetRoot.hiddenCurves[leaf.id] !== true;

                        rows.push({
                            id: leaf.id,
                            clipId: leafClip,
                            propId: leaf.id,
                            name: leaf.name,
                            color: assignedLeafColor,
                            type: "channel",
                            indent: 3,
                            isExpandable: false,
                            expanded: false,
                            keyCount: leaf.keyframes ? leaf.keyframes.length : 0,
                            keyframes: leaf.keyframes || [],
                            details: leaf.details || [],
                            isMuted: isMutedVal,
                            isLocked: isLockedVal,
                            isVisibleInGraph: isVisVal
                        });
                    }
                }
            }

            for (var st = 0; st < standalone.length; ++st) {
                var sChan = standalone[st];
                var sClip = sChan.clipId || grpClipId;
                var assignedStandaloneColor = dopesheetRoot.customTrackColors[sChan.id] || dopesheetRoot.customTrackColors[sClip + "|" + sChan.id] || sChan.color || "#3B82F6";

                var isMutedStand = dopesheetRoot.customTrackMutes[sClip + "|" + sChan.id] !== undefined ? !!dopesheetRoot.customTrackMutes[sClip + "|" + sChan.id] : (dopesheetRoot.customTrackMutes[sChan.id] !== undefined ? !!dopesheetRoot.customTrackMutes[sChan.id] : !!sChan.isMuted);
                var isLockedStand = dopesheetRoot.customTrackLocks[sClip + "|" + sChan.id] !== undefined ? !!dopesheetRoot.customTrackLocks[sClip + "|" + sChan.id] : (dopesheetRoot.customTrackLocks[sChan.id] !== undefined ? !!dopesheetRoot.customTrackLocks[sChan.id] : !!sChan.isLocked);
                var isVisStand = dopesheetRoot.hiddenCurves[sClip + "|" + sChan.id] !== true && dopesheetRoot.hiddenCurves[sChan.id] !== true;

                rows.push({
                    id: sChan.id,
                    clipId: sClip,
                    propId: sChan.id,
                    name: sChan.name,
                    color: assignedStandaloneColor,
                    type: "channel",
                    indent: 2,
                    isExpandable: false,
                    expanded: false,
                    keyCount: sChan.keyframes ? sChan.keyframes.length : 0,
                    keyframes: sChan.keyframes || [],
                    details: sChan.details || [],
                    isMuted: isMutedStand,
                    isLocked: isLockedStand,
                    isVisibleInGraph: isVisStand
                });
            }
        }

        return rows;
    }

    function toggleRowExpansion(index) {
        if (index < 0 || index >= treeRows.length)
            return;
        var row = treeRows[index];
        var copy = Object.assign({}, collapsedNodes);
        copy[row.id] = !copy[row.id];
        collapsedNodes = copy;
        expansionRevision++;
    }

    function refreshChannels() {
        if (!activeTimelineModel || !hasClip) {
            rawChannelsData = [];
            return;
        }
        rawChannelsData = activeTimelineModel.getClipAnimChannels(activeClipId, currentPlayheadFrame);
        expansionRevision++;
    }

    Connections {
        target: activeTimelineModel
        function onCopyKeyframesRequested() {
            if (contextController && dopesheetRoot) {
                contextController.copy(activeTimelineModel, dopesheetRoot.selectedKeyframes);
            }
        }
        function onPasteKeyframesRequested() {
            if (contextController) {
                contextController.paste(activeTimelineModel, dopesheetRoot.currentPlayheadFrame);
                dopesheetRoot.refreshChannels();
            }
        }
        function onDeleteSelectedKeyframesRequested() {
            dopesheetRoot.deleteSelectedKeyframes();
        }
        function onClipPropertiesChanged(clipId) {
            if (clipId === dopesheetRoot.activeClipId) {
                dopesheetRoot.refreshChannels();
            } else if (activeTimelineModel && activeTimelineModel.getLinkedClipIds(dopesheetRoot.activeClipId).indexOf(clipId) !== -1) {
                dopesheetRoot.refreshChannels();
            }
        }
        function onSelectedClipIdChanged() {
            dopesheetRoot.activeClipId = activeTimelineModel.selectedClipId || "";
            dopesheetRoot.activeClipData = activeTimelineModel.selectedClipData || null;
            dopesheetRoot.selectedKeyframes = [];
            dopesheetRoot.refreshChannels();
        }
    }

    Connections {
        target: activePlaybackManager
        function onFrameChanged() {
            dopesheetRoot.refreshChannels();
        }
    }

    onActiveViewModeChanged: {
        canvas.zoomFactor = dopesheetRoot.zoomFactor;
        canvas.horizontalOffset = dopesheetRoot.horizontalOffset;
        graphCanvas.zoomFactor = dopesheetRoot.zoomFactor;
        graphCanvas.horizontalOffset = dopesheetRoot.horizontalOffset;
    }
    onActiveClipIdChanged: refreshChannels()
    Component.onCompleted: refreshChannels()

    Rectangle {
        anchors.fill: parent
        color: "#141414"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top Toolbar Integration
        DopesheetToolbar {
            id: topToolBar
            activeViewMode: dopesheetRoot.activeViewMode
            onViewModeChanged: function (mode) {
                dopesheetRoot.activeViewMode = mode;
            }

            activeToolIndex: dopesheetRoot.activeToolIndex
            onToolChanged: function (toolId) {
                dopesheetRoot.activeTool = toolId;
                var tools = ["pointer", "scale", "color-picker", "pencil-minus"];
                var idx = tools.indexOf(toolId);
                if (idx !== -1)
                    dopesheetRoot.activeToolIndex = idx;
            }

            snappingEnabled: dopesheetRoot.snappingEnabled
            snapToFrames: dopesheetRoot.snapToFrames
            snapToOtherKeys: dopesheetRoot.snapToOtherKeys
            snapToPlayhead: dopesheetRoot.snapToPlayhead

            onSnappingToggled: function (enabled) {
                dopesheetRoot.snappingEnabled = enabled;
            }
            onSnapModesChanged: function (f, ok, p) {
                dopesheetRoot.snapToFrames = f;
                dopesheetRoot.snapToOtherKeys = ok;
                dopesheetRoot.snapToPlayhead = p;
            }

            normalizeEnabled: dopesheetRoot.normalizeCurves
            onNormalizeToggled: function (enabled) {
                dopesheetRoot.normalizeCurves = enabled;
            }

            // ── Live Numeric Stats Binding ──────────────────────
            readonly property var leadKeyData: {
                if (!dopesheetRoot.selectedKeyframes || dopesheetRoot.selectedKeyframes.length === 0)
                    return null;
                var lead = dopesheetRoot.selectedKeyframes[0];
                for (var r = 0; r < dopesheetRoot.treeRows.length; ++r) {
                    var row = dopesheetRoot.treeRows[r];
                    if (row.type !== "channel" || !row.details || row.propId !== lead.propId)
                        continue;
                    for (var k = 0; k < row.details.length; ++k) {
                        var kf = row.details[k];
                        if (Math.round(kf.frame) === Math.round(lead.frame)) {
                            return {
                                frame: kf.frame,
                                value: Number(kf.value !== undefined ? kf.value : 0),
                                interp: Number(kf.interp !== undefined ? kf.interp : 1)
                            };
                        }
                    }
                }
                return {
                    frame: lead.frame,
                    value: 0.0,
                    interp: 1
                };
            }

            hasSelectedKey: dopesheetRoot.selectedKeyframes.length > 0 && leadKeyData !== null
            selectedKeyTime: leadKeyData ? leadKeyData.frame : 0.0
            selectedKeyValue: leadKeyData ? leadKeyData.value : 0.0
            selectedKeyInterp: leadKeyData ? leadKeyData.interp : -1

            // Commit edited Time (Frame)
            onKeyTimeCommitted: function (newFrame) {
                if (!activeTimelineModel || dopesheetRoot.selectedKeyframes.length === 0)
                    return;
                var primary = dopesheetRoot.selectedKeyframes[0];
                var targetFrame = Math.max(0, Math.round(newFrame));
                if (targetFrame === Math.round(primary.frame))
                    return;

                if (typeof activeTimelineModel.moveKeyframe === "function") {
                    activeTimelineModel.moveKeyframe(primary.clipId, primary.propId, primary.frame, targetFrame);
                }

                dopesheetRoot.selectedKeyframes = [
                    {
                        clipId: primary.clipId,
                        propId: primary.propId,
                        frame: targetFrame
                    }
                ];
                dopesheetRoot.refreshChannels();
            }

            // Commit edited Value
            onKeyValueCommitted: function (newVal) {
                if (!activeTimelineModel || dopesheetRoot.selectedKeyframes.length === 0)
                    return;
                var primary = dopesheetRoot.selectedKeyframes[0];

                for (var r = 0; r < dopesheetRoot.treeRows.length; ++r) {
                    var row = dopesheetRoot.treeRows[r];
                    if (row.type !== "channel" || !row.details || row.propId !== primary.propId)
                        continue;
                    for (var k = 0; k < row.details.length; ++k) {
                        var kf = row.details[k];
                        if (Math.round(kf.frame) === Math.round(primary.frame)) {
                            var curInterp = kf.interp !== undefined ? kf.interp : 1;
                            var inX = kf.inX !== undefined ? kf.inX : 0.666;
                            var inY = kf.inY !== undefined ? kf.inY : 0.0;
                            var outX = kf.outX !== undefined ? kf.outX : 0.333;
                            var outY = kf.outY !== undefined ? kf.outY : 0.0;
                            activeTimelineModel.updateKeyframe(row.clipId, row.propId, kf.frame, kf.frame, newVal, curInterp, inX, inY, outX, outY);
                            break;
                        }
                    }
                }
                dopesheetRoot.refreshChannels();
            }

            // Extended Tangents (Spline: 2, Linear: 1, Stepped: 0, Flat: 3, Plateau: 4, Ease: 5)
            onSetInterpolationRequested: function (interpType) {
                if (!activeTimelineModel || dopesheetRoot.selectedKeyframes.length === 0)
                    return;

                for (var r = 0; r < dopesheetRoot.treeRows.length; ++r) {
                    var row = dopesheetRoot.treeRows[r];
                    if (row.type !== "channel" || !row.details)
                        continue;
                    for (var k = 0; k < row.details.length; ++k) {
                        var kf = row.details[k];
                        for (var s = 0; s < dopesheetRoot.selectedKeyframes.length; ++s) {
                            if (dopesheetRoot.selectedKeyframes[s].propId === row.propId && Math.round(dopesheetRoot.selectedKeyframes[s].frame) === Math.round(kf.frame)) {
                                var actualInterp = interpType;
                                var inX = kf.inX !== undefined ? kf.inX : 0.666;
                                var inY = kf.inY !== undefined ? kf.inY : 0.0;
                                var outX = kf.outX !== undefined ? kf.outX : 0.333;
                                var outY = kf.outY !== undefined ? kf.outY : 0.0;

                                if (interpType === 3) { // Flat
                                    actualInterp = 2;
                                    inY = 0.0;
                                    outY = 0.0;
                                    inX = 0.666;
                                    outX = 0.333;
                                } else if (interpType === 4) { // Plateau
                                    actualInterp = 2;
                                    inY = 0.0;
                                    outY = 0.0;
                                    inX = 0.75;
                                    outX = 0.25;
                                } else if (interpType === 5) { // Ease
                                    actualInterp = 2;
                                    inX = 0.85;
                                    inY = 0.0;
                                    outX = 0.15;
                                    outY = 0.0;
                                }

                                activeTimelineModel.updateKeyframe(row.clipId, row.propId, kf.frame, kf.frame, kf.value, actualInterp, inX, inY, outX, outY);
                                break;
                            }
                        }
                    }
                }
                dopesheetRoot.refreshChannels();
            }

            onExpandAllRequested: function () {
                dopesheetRoot.collapsedNodes = ({});
                dopesheetRoot.expansionRevision++;
            }
            onCollapseAllRequested: function () {
                var copy = {};
                for (var i = 0; i < dopesheetRoot.treeRows.length; ++i) {
                    var r = dopesheetRoot.treeRows[i];
                    if (r.isExpandable)
                        copy[r.id] = true;
                }
                dopesheetRoot.collapsedNodes = copy;
                dopesheetRoot.expansionRevision++;
            }

            onSelectAllRequested: function () {
                var all = [];
                for (var c = 0; c < rawChannelsData.length; ++c) {
                    var ch = rawChannelsData[c];
                    var kfs = ch.keyframes || [];
                    for (var k = 0; k < kfs.length; ++k)
                        all.push({
                            clipId: ch.clipId || activeClipId,
                            propId: ch.id,
                            frame: kfs[k]
                        });
                }
                dopesheetRoot.selectedKeyframes = all;
            }
            onSelectNoneRequested: function () {
                dopesheetRoot.selectedKeyframes = [];
            }
            onInvertSelectionRequested: {
                var inverted = [];
                for (var c = 0; c < rawChannelsData.length; ++c) {
                    var ch = rawChannelsData[c];
                    var kfs = ch.keyframes || [];
                    for (var k = 0; k < kfs.length; ++k) {
                        var f = kfs[k];
                        var found = false;
                        for (var s = 0; s < selectedKeyframes.length; ++s) {
                            if (selectedKeyframes[s].propId === ch.id && selectedKeyframes[s].frame === f) {
                                found = true;
                                break;
                            }
                        }
                        if (!found)
                            inverted.push({
                                clipId: ch.clipId || activeClipId,
                                propId: ch.id,
                                frame: f
                            });
                    }
                }
                dopesheetRoot.selectedKeyframes = inverted;
            }
            onSelectBeforePlayheadRequested: function () {
                var list = [];
                for (var c = 0; c < rawChannelsData.length; ++c) {
                    var ch = rawChannelsData[c];
                    var kfs = ch.keyframes || [];
                    for (var k = 0; k < kfs.length; ++k) {
                        if (kfs[k] <= currentPlayheadFrame)
                            list.push({
                                clipId: ch.clipId || activeClipId,
                                propId: ch.id,
                                frame: kfs[k]
                            });
                    }
                }
                dopesheetRoot.selectedKeyframes = list;
            }
            onSelectAfterPlayheadRequested: function () {
                var list = [];
                for (var c = 0; c < rawChannelsData.length; ++c) {
                    var ch = rawChannelsData[c];
                    var kfs = ch.keyframes || [];
                    for (var k = 0; k < kfs.length; ++k) {
                        if (kfs[k] >= currentPlayheadFrame)
                            list.push({
                                clipId: ch.clipId || activeClipId,
                                propId: ch.id,
                                frame: kfs[k]
                            });
                    }
                }
                dopesheetRoot.selectedKeyframes = list;
            }
            onDeleteSelectedRequested: function () {
                dopesheetRoot.deleteSelectedKeyframes();
            }
            onSnapToPlayheadRequested: function () {
                if (!activeTimelineModel || selectedKeyframes.length === 0)
                    return;
                for (var i = 0; i < selectedKeyframes.length; ++i) {
                    var k = selectedKeyframes[i];
                    activeTimelineModel.moveKeyframe(k.clipId, k.propId, k.frame, currentPlayheadFrame);
                }
                refreshChannels();
            }
        }

        XylaTimelineRuler {
            id: dopesheetRuler
            Layout.fillWidth: true
            headerWidth: dopesheetRoot.effectiveHeaderWidth
            zoomFactor: dopesheetRoot.zoomFactor
            onZoomFactorChanged: dopesheetRoot.zoomFactor = zoomFactor
            horizontalOffset: dopesheetRoot.horizontalOffset
            onHorizontalOffsetChanged: dopesheetRoot.horizontalOffset = horizontalOffset
            contentWidth: dopesheetRoot.contentWidth
            activePlaybackManager: dopesheetRoot.activePlaybackManager
            z: 250
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            DopesheetEmptyState {
                visible: !dopesheetRoot.hasClip
                hasClip: false
                z: 10
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0
                visible: dopesheetRoot.hasClip

                DopesheetTree {
                    treeRows: dopesheetRoot.treeRows
                    headerWidth: dopesheetRoot.headerWidth
                    activePropId: dopesheetRoot.activePropId
                    activeClipId: dopesheetRoot.activeClipId

                    onToggleRowExpansion: idx => dopesheetRoot.toggleRowExpansion(idx)

                    onTrackSelected: (cId, pId) => {
                        if (cId && cId !== "")
                            dopesheetRoot.activeClipId = cId;
                        dopesheetRoot.activePropId = pId;
                    }

                    onContextMenuRequested: (gx, gy, cId, pId, muted, locked) => {
                        if (pId !== "") {
                            channelContextMenu.openAt(gx, gy, cId, pId, muted, locked);
                        }
                    }

                    onToggleTrackVisibilityRequested: (cId, pId, isSolo, isEnableAll) => {
                        dopesheetRoot.toggleTrackVisibility(cId, pId, isSolo, isEnableAll);
                    }
                    onToggleTrackMuteRequested: (cId, pId) => {
                        dopesheetRoot.toggleTrackMute(cId, pId);
                    }
                    onToggleTrackLockRequested: (cId, pId) => {
                        dopesheetRoot.toggleTrackLock(cId, pId);
                    }
                }

                StackLayout {
                    id: canvasStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: dopesheetRoot.activeViewMode

                    DopesheetCanvas {
                        id: canvas
                        treeRows: dopesheetRoot.treeRows
                        zoomFactor: dopesheetRoot.zoomFactor
                        onZoomFactorChanged: dopesheetRoot.zoomFactor = zoomFactor
                        horizontalOffset: dopesheetRoot.horizontalOffset
                        onHorizontalOffsetChanged: dopesheetRoot.horizontalOffset = horizontalOffset
                        contentWidthFrames: dopesheetRoot.contentWidth
                        selectedKeyframes: dopesheetRoot.selectedKeyframes
                        activePropId: dopesheetRoot.activePropId
                        activeClipId: dopesheetRoot.activeClipId

                        activeTool: dopesheetRoot.activeTool

                        snappingEnabled: dopesheetRoot.snappingEnabled
                        snapToFrames: dopesheetRoot.snapToFrames
                        snapToOtherKeys: dopesheetRoot.snapToOtherKeys
                        snapToPlayhead: dopesheetRoot.snapToPlayhead

                        onTrackSelected: (cId, pId) => {
                            if (cId && cId !== "")
                                dopesheetRoot.activeClipId = cId;
                            dopesheetRoot.activePropId = pId;
                        }

                        onSelectionBatchUpdated: newSelection => {
                            dopesheetRoot.selectedKeyframes = newSelection;
                        }

                        onClearSelectionRequested: dopesheetRoot.selectedKeyframes = []

                        onKeyframeSingleSelected: (cId, pId, f) => {
                            dopesheetRoot.selectedKeyframes = [
                                {
                                    clipId: cId,
                                    propId: pId,
                                    frame: f
                                }
                            ];
                        }

                        onKeyframeSelectionRequested: (cId, pId, f, toggle) => {
                            var copy = dopesheetRoot.selectedKeyframes.slice();
                            for (var i = 0; i < copy.length; ++i) {
                                if (copy[i].clipId === cId && copy[i].propId === pId && copy[i].frame === f) {
                                    if (toggle)
                                        copy.splice(i, 1);
                                    dopesheetRoot.selectedKeyframes = copy;
                                    return;
                                }
                            }
                            copy.push({
                                clipId: cId,
                                propId: pId,
                                frame: f
                            });
                            dopesheetRoot.selectedKeyframes = copy;
                        }

                        onMoveKeyframesCommitted: delta => {
                            if (delta === 0 || !activeTimelineModel || selectedKeyframes.length === 0)
                                return;

                            activeTimelineModel.moveKeyframes(selectedKeyframes, delta);

                            var updatedSelection = [];
                            for (var i = 0; i < selectedKeyframes.length; ++i) {
                                var k = selectedKeyframes[i];
                                updatedSelection.push({
                                    clipId: k.clipId,
                                    propId: k.propId,
                                    frame: Math.max(0, k.frame + delta)
                                });
                            }
                            dopesheetRoot.selectedKeyframes = updatedSelection;
                            refreshChannels();
                        }

                        onDeleteKeyframesBatchRequested: function (keysToDelete) {
                            dopesheetRoot.deleteKeyframesBatch(keysToDelete);
                        }

                        onScaleKeyframesCommitted: function (scaledList) {
                            dopesheetRoot.commitScaledKeyframes(scaledList);
                        }

                        onApplyKeyframeValueRequested: function (clipId, propId, frame, valData) {
                            dopesheetRoot.applyClonedValue(clipId, propId, frame, valData);
                        }

                        onContextMenuRequested: (gx, gy, cId, pId, f, hasK, muted, locked) => {
                            if (hasK) {
                                keyframeContextMenu.openAt(gx, gy);
                            } else if (pId !== "") {
                                channelContextMenu.openAt(gx, gy, cId, pId, muted, locked);
                            } else {
                                keyframeContextMenu.openAt(gx, gy);
                            }
                        }
                    }

                    AnimationGraphCanvas {
                        id: graphCanvas
                        treeRows: dopesheetRoot.treeRows
                        zoomFactor: dopesheetRoot.zoomFactor
                        onZoomFactorChanged: dopesheetRoot.zoomFactor = zoomFactor
                        horizontalOffset: dopesheetRoot.horizontalOffset
                        onHorizontalOffsetChanged: dopesheetRoot.horizontalOffset = horizontalOffset
                        contentWidthFrames: dopesheetRoot.contentWidth
                        selectedKeyframes: dopesheetRoot.selectedKeyframes
                        normalizeEnabled: dopesheetRoot.normalizeCurves

                        hiddenCurves: dopesheetRoot.hiddenCurves

                        activeChannelId: dopesheetRoot.activePropId
                        onTrackSelected: (cId, pId) => {
                            if (cId && cId !== "")
                                dopesheetRoot.activeClipId = cId;
                            dopesheetRoot.activePropId = pId;
                        }
                        onSelectionChanged: newSelection => {
                            dopesheetRoot.selectedKeyframes = newSelection;
                        }
                        onContextMenuRequested: (gx, gy, cId, pId, f, hasK) => {
                            if (hasK) {
                                keyframeContextMenu.openAt(gx, gy);
                            } else if (pId !== "") {
                                channelContextMenu.openAt(gx, gy, cId, pId, false, false);
                            } else {
                                keyframeContextMenu.openAt(gx, gy);
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: sidebarResizer
        width: 8
        x: dopesheetRoot.headerWidth - 4
        y: topToolBar.height
        height: parent.height - y
        z: 350
        visible: dopesheetRoot.hasClip

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
                var pt = mapToItem(dopesheetRoot, mouse.x, mouse.y);
                startMouseX = pt.x;
                startWidth = dopesheetRoot.headerWidth;
            }

            onPositionChanged: function (mouse) {
                if (pressed) {
                    var pt = mapToItem(dopesheetRoot, mouse.x, mouse.y);
                    var deltaX = pt.x - startMouseX;
                    var newW = Math.max(dopesheetRoot.minHeaderWidth, Math.min(dopesheetRoot.maxHeaderWidth, startWidth + deltaX));
                    dopesheetRoot.headerWidth = newW;
                }
            }
        }
    }

    XylaPlayhead {
        id: mainPlayhead
        timelineRoot: dopesheetRoot
        activeTimelineModel: dopesheetRoot.activeTimelineModel
        currentFrame: dopesheetRoot.currentPlayheadFrame
        zoomFactor: dopesheetRoot.zoomFactor
        horizontalOffset: dopesheetRoot.horizontalOffset
        rulerHeight: 28 + 28
        playheadMargin: dopesheetRoot.effectiveHeaderWidth
        headerWidth: dopesheetRoot.effectiveHeaderWidth
        height: parent.height
        visible: dopesheetRoot.hasClip
        z: 200
    }

    KeyframeContextMenuController {
        id: contextController
    }

    KeyframeContextMenu {
        id: keyframeContextMenu
        timelineModel: dopesheetRoot.activeTimelineModel
        dopesheetRoot: dopesheetRoot

        controller: contextController
        activeViewMode: dopesheetRoot.activeViewMode
        playheadFrame: dopesheetRoot.currentPlayheadFrame
    }

    ChannelContextMenu {
        id: channelContextMenu
        timelineModel: dopesheetRoot.activeTimelineModel
        controller: contextController
        treeRows: dopesheetRoot.treeRows

        onExpandAllRequested: topToolBar.expandAllRequested()
        onCollapseAllRequested: topToolBar.collapseAllRequested()

        onSelectAllInTrackRequested: (cId, pId) => {
            var selected = [];
            for (var i = 0; i < rawChannelsData.length; ++i) {
                var ch = rawChannelsData[i];
                if ((ch.clipId === cId || ch.clipId === activeClipId) && ch.id === pId) {
                    var kfs = ch.keyframes || [];
                    for (var k = 0; k < kfs.length; ++k) {
                        selected.push({
                            clipId: ch.clipId || activeClipId,
                            propId: ch.id,
                            frame: Math.round(kfs[k])
                        });
                    }
                }
            }
            dopesheetRoot.selectedKeyframes = selected;
        }

        onChangeTrackColorRequested: (cId, pId, colorHex) => {
            var copy = Object.assign({}, dopesheetRoot.customTrackColors);
            copy[pId] = colorHex;
            var targetClip = cId || dopesheetRoot.activeClipId;
            if (targetClip)
                copy[targetClip + "|" + pId] = colorHex;
            dopesheetRoot.customTrackColors = copy;
            dopesheetRoot.expansionRevision++;
        }
    }
}
