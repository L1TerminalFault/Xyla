import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "./timeline"
import "./dopesheet"

Item {
    id: dopesheetRoot

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null

    property string activeClipId: activeTimelineModel ? (activeTimelineModel.selectedClipId || "") : ""
    property var activeClipData: activeTimelineModel ? (activeTimelineModel.selectedClipData || null) : null
    readonly property bool hasClip: activeClipId !== "" && activeClipId !== "null"

    readonly property int currentPlayheadFrame: activePlaybackManager ? activePlaybackManager.currentFrame : 0

    property real zoomFactor: 1.0
    property real horizontalOffset: 0.0
    property real contentWidth: 5000

    // Resizable header width constraints
    property int headerWidth: 200
    property int minHeaderWidth: 140
    property int maxHeaderWidth: 500

    property var selectedKeyframes: []
    property var rawChannelsData: []
    property var collapsedNodes: ({})
    property int expansionRevision: 0

    readonly property int totalKeyCount: {
        var count = 0;
        for (var i = 0; i < rawChannelsData.length; ++i) {
            count += (rawChannelsData[i].keyframes ? rawChannelsData[i].keyframes.length : 0);
        }
        return count;
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

            var grpKeysMap = {};
            for (var j = 0; j < grpChannels.length; ++j) {
                var gKfs = grpChannels[j].keyframes || [];
                for (var gk = 0; gk < gKfs.length; ++gk)
                    grpKeysMap[gKfs[gk]] = true;
            }
            var grpSummaryKeys = Object.keys(grpKeysMap).map(Number).sort((a, b) => a - b);

            rows.push({
                id: grpRowId,
                clipId: activeClipId,
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

                var subKeysMap = {};
                for (var sj = 0; sj < subChannels.length; ++sj) {
                    var sKfs = subChannels[sj].keyframes || [];
                    for (var sk = 0; sk < sKfs.length; ++sk)
                        subKeysMap[sKfs[sk]] = true;
                }
                var subSummaryKeys = Object.keys(subKeysMap).map(Number).sort((a, b) => a - b);

                rows.push({
                    id: subRowId,
                    clipId: activeClipId,
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
                        rows.push({
                            id: leaf.id,
                            clipId: activeClipId,
                            propId: leaf.id,
                            name: leaf.name,
                            color: leaf.color || "#3B82F6",
                            type: "channel",
                            indent: 3,
                            isExpandable: false,
                            expanded: false,
                            keyCount: leaf.keyframes ? leaf.keyframes.length : 0,
                            keyframes: leaf.keyframes || []
                        });
                    }
                }
            }

            for (var st = 0; st < standalone.length; ++st) {
                var sChan = standalone[st];
                rows.push({
                    id: sChan.id,
                    clipId: activeClipId,
                    propId: sChan.id,
                    name: sChan.name,
                    color: sChan.color || "#3B82F6",
                    type: "channel",
                    indent: 2,
                    isExpandable: false,
                    expanded: false,
                    keyCount: sChan.keyframes ? sChan.keyframes.length : 0,
                    keyframes: sChan.keyframes || []
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
    }

    Connections {
        target: activeTimelineModel

        function onClipPropertiesChanged(clipId) {
            if (clipId === dopesheetRoot.activeClipId)
                dopesheetRoot.refreshChannels();
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

    onActiveClipIdChanged: refreshChannels()
    Component.onCompleted: refreshChannels()

    Rectangle {
        anchors.fill: parent
        color: "#141414"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        DopesheetToolbar {
            id: topToolBar
            onExpandAllRequested: {
                dopesheetRoot.collapsedNodes = ({});
                dopesheetRoot.expansionRevision++;
            }
            onCollapseAllRequested: {
                var copy = {};
                for (var i = 0; i < dopesheetRoot.treeRows.length; ++i) {
                    var r = dopesheetRoot.treeRows[i];
                    if (r.isExpandable)
                        copy[r.id] = true;
                }
                dopesheetRoot.collapsedNodes = copy;
                dopesheetRoot.expansionRevision++;
            }

            onSelectAllRequested: {
                var all = [];
                for (var c = 0; c < rawChannelsData.length; ++c) {
                    var ch = rawChannelsData[c];
                    var kfs = ch.keyframes || [];
                    for (var k = 0; k < kfs.length; ++k)
                        all.push({
                            clipId: activeClipId,
                            propId: ch.id,
                            frame: kfs[k]
                        });
                }
                dopesheetRoot.selectedKeyframes = all;
            }
            onSelectNoneRequested: dopesheetRoot.selectedKeyframes = []

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
                                clipId: activeClipId,
                                propId: ch.id,
                                frame: f
                            });
                    }
                }
                dopesheetRoot.selectedKeyframes = inverted;
            }

            onSelectBeforePlayheadRequested: {
                var list = [];
                for (var c = 0; c < rawChannelsData.length; ++c) {
                    var ch = rawChannelsData[c];
                    var kfs = ch.keyframes || [];
                    for (var k = 0; k < kfs.length; ++k) {
                        if (kfs[k] <= currentPlayheadFrame)
                            list.push({
                                clipId: activeClipId,
                                propId: ch.id,
                                frame: kfs[k]
                            });
                    }
                }
                dopesheetRoot.selectedKeyframes = list;
            }

            onSelectAfterPlayheadRequested: {
                var list = [];
                for (var c = 0; c < rawChannelsData.length; ++c) {
                    var ch = rawChannelsData[c];
                    var kfs = ch.keyframes || [];
                    for (var k = 0; k < kfs.length; ++k) {
                        if (kfs[k] >= currentPlayheadFrame)
                            list.push({
                                clipId: activeClipId,
                                propId: ch.id,
                                frame: kfs[k]
                            });
                    }
                }
                dopesheetRoot.selectedKeyframes = list;
            }

            onDeleteSelectedRequested: {
                if (!activeTimelineModel)
                    return;
                for (var i = 0; i < selectedKeyframes.length; ++i) {
                    var k = selectedKeyframes[i];
                    activeTimelineModel.removeKeyframe(k.clipId, k.propId, k.frame);
                }
                selectedKeyframes = [];
                refreshChannels();
            }

            onSnapToPlayheadRequested: {
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
            headerWidth: dopesheetRoot.headerWidth
            zoomFactor: dopesheetRoot.zoomFactor
            horizontalOffset: dopesheetRoot.horizontalOffset
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
                    onToggleRowExpansion: idx => dopesheetRoot.toggleRowExpansion(idx)
                }

                DopesheetCanvas {
                    id: canvas
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    treeRows: dopesheetRoot.treeRows
                    zoomFactor: dopesheetRoot.zoomFactor
                    horizontalOffset: dopesheetRoot.horizontalOffset
                    contentWidth: dopesheetRoot.contentWidth
                    selectedKeyframes: dopesheetRoot.selectedKeyframes

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
                        if (delta === 0 || !activeTimelineModel)
                            return;
                        var updatedSelection = [];
                        for (var i = 0; i < selectedKeyframes.length; ++i) {
                            var k = selectedKeyframes[i];
                            var target = Math.max(0, k.frame + delta);
                            activeTimelineModel.moveKeyframe(k.clipId, k.propId, k.frame, target);
                            updatedSelection.push({
                                clipId: k.clipId,
                                propId: k.propId,
                                frame: target
                            });
                        }
                        dopesheetRoot.selectedKeyframes = updatedSelection;
                        refreshChannels();
                    }
                    onContextMenuRequested: (gx, gy, cId, pId, f, hasK) => {
                        dopesheetContextMenu.openAt(gx, gy, cId, pId, f, hasK);
                    }
                }
            }
        }
    }

    // Sidebar Resizer matching timeline
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
        playheadMargin: dopesheetRoot.headerWidth
        headerWidth: dopesheetRoot.headerWidth
        height: parent.height
        visible: dopesheetRoot.hasClip
        z: 300
    }

    XylaDopesheetContextMenu {
        id: dopesheetContextMenu
        dopesheetRoot: dopesheetRoot
        timelineModel: dopesheetRoot.activeTimelineModel

        onDeleteKeyframeRequested: {
            if (activeTimelineModel && activeClipId !== "" && activePropertyId !== "") {
                activeTimelineModel.removeKeyframe(activeClipId, activePropertyId, clickedFrame);
                refreshChannels();
            }
        }
    }
}
