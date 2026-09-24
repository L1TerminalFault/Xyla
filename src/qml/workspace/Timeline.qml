import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Xyla 1.0

import "../components"
import "./timeline"

Item {
    id: root

    // =========================================================================
    // Active application objects
    // =========================================================================

    property var activeTimelineModel:
        typeof timelineModel !== "undefined" ? timelineModel : null

    property var activePlaybackManager:
        typeof playbackManager !== "undefined" ? playbackManager : null

    property var activeProjectManager:
        typeof projectManager !== "undefined" ? projectManager : null

    property var activeProject:
        activeProjectManager?.activeProject ?? null

    property var activeShortcutManager:
        typeof shortcutManager !== "undefined" ? shortcutManager : null

    property var activeMixerModel:
        typeof mixerModel !== "undefined" ? mixerModel : null

    // =========================================================================
    // Timeline state
    // =========================================================================

    readonly property int trackCount:
        activeTimelineModel ? activeTimelineModel.trackCount : 0

    readonly property int playheadFrame:
        activePlaybackManager ? activePlaybackManager.currentFrame : 0

    property double zoomFactor:
        activeTimelineModel ? activeTimelineModel.zoomFactor : 1.0

    property real horizontalOffset:
        activeTimelineModel ? activeTimelineModel.horizontalOffset : 0.0

    // =========================================================================
    // Active Tool & Razor state
    // =========================================================================
    property string activeTool: "pointer"
    property int activeToolIndex: 0
    property int razorHoverFrame: -1
    property int razorHoverTrack: -1
    property bool isRazorHovering: false

    /*
     * Vertical scrolling is deliberately owned here rather than separately
     * by the track list and canvas.
     *
     * This guarantees that:
     *   Track headers
     *   Track backgrounds
     *   Clips
     *
     * always use the exact same vertical position.
     */
    property real verticalScrollOffset: 0.0

    property real contentWidth: 3600
    property int cachedMaxFrame: 0

    property bool showAudioWaveforms: true
    property int thumbnailMode: 1

    // =========================================================================
    // Timeline dimensions
    // =========================================================================

    property int headerWidth: 220
    property int minHeaderWidth: 220
    property int maxHeaderWidth: 600

    property int paletteStripWidth: 0

    /*
     * The ruler and the track list must agree on this height.
     *
     * If XylaTimelineRuler later exposes a proper implicitHeight, this can
     * become:
     *
     *     timelineRuler.implicitHeight
     *
     * without changing the rest of the layout.
     */
    property int rulerHeight: 32

    property real playheadMargin: 0.0

    readonly property color bgDark: "#121212"
    readonly property color bgHeader: "#141414"
    readonly property color borderDark: "#2d2d2d"

    readonly property color videoTrackBg: "#0E0E0E"
    readonly property color audioTrackBg: "#101010"

    // =========================================================================
    // Track geometry
    // =========================================================================

    property var trackHeights: []
    property var trackOffsets: []
    property real totalTracksHeight: 200

    // =========================================================================
    // Timeline interaction state
    // =========================================================================

    property real snapGuideFrame: -1
    property bool isSnapLineVisible: false
    property var activeSpacingGaps: []

    property bool isMiddlePanning: false

    // =========================================================================
    // Project FPS
    // =========================================================================

    readonly property real projectFps: {
        if (!activeProject)
            return 30.0

        if (typeof activeProject.fps === "number" &&
            activeProject.fps > 0) {
            return activeProject.fps
        }

        if (activeProject.fpsNumerator &&
            activeProject.fpsDenominator) {
            return activeProject.fpsNumerator /
                   activeProject.fpsDenominator
        }

        return 30.0
    }

    // =========================================================================
    // Track helpers
    // =========================================================================

    function getTrackBgColor(trackIdx) {
        if (!root.activeTimelineModel)
            return root.videoTrackBg

        var kind = root.activeTimelineModel.getTrackKind(trackIdx)
        return kind === 1 ? root.audioTrackBg : root.videoTrackBg
    }

    function isPlayheadOnClipInTrack(trackIdx) {
        if (!root.activeTimelineModel)
            return false

        var clips = root.activeTimelineModel.getClipsForTrack(trackIdx)
        var pf = root.playheadFrame

        for (var i = 0; i < clips.length; ++i) {
            var clip = clips[i]
            var startF = Number(clip.startFrame)
            var endF = startF + Number(clip.durationFrames)

            if (pf >= startF && pf < endF)
                return true
        }

        return false
    }

    function updateTrackMetrics() {
        var count = root.trackCount > 0
                ? root.trackCount
                : (root.activeTimelineModel
                   ? root.activeTimelineModel.trackCount
                   : 0)

        var heights = []
        var offsets = []
        var cumulativeY = 0

        for (var i = 0; i < count; ++i) {
            var height = 68

            if (trackHeights &&
                i < trackHeights.length &&
                typeof trackHeights[i] === "number" &&
                trackHeights[i] > 0) {
                height = trackHeights[i]
            } else if (typeof trackHeaderColumn !== "undefined" &&
                       trackHeaderColumn &&
                       trackHeaderColumn.children &&
                       i < trackHeaderColumn.children.length) {

                var item = trackHeaderColumn.children[i]

                if (item &&
                    item.implicitHeight &&
                    item.implicitHeight > 0) {
                    height = item.implicitHeight
                }
            }

            heights.push(height)
            offsets.push(cumulativeY)
            cumulativeY += height
        }

        trackHeights = heights
        trackOffsets = offsets

        totalTracksHeight = Math.max(cumulativeY, count * 68)

        clampVerticalScroll()
    }

    function clampVerticalScroll() {
        var viewportHeight = Math.max(
            0,
            root.timelineCanvasHeight
        )

        var maxOffset = Math.max(
            0,
            root.totalTracksHeight - viewportHeight
        )

        root.verticalScrollOffset =
            Math.max(
                0,
                Math.min(maxOffset, root.verticalScrollOffset)
            )
    }

    function scrollVertical(delta) {
        var maxOffset = Math.max(
            0,
            root.totalTracksHeight - root.timelineCanvasHeight
        )

        root.verticalScrollOffset = Math.max(
            0,
            Math.min(
                maxOffset,
                root.verticalScrollOffset + delta
            )
        )
    }

    function getTrackY(trackIndex) {
        if (trackIndex < 0 ||
            !trackOffsets ||
            trackIndex >= trackOffsets.length) {
            return trackIndex * 68
        }

        return trackOffsets[trackIndex]
    }

    function getTrackHeight(trackIndex) {
        if (trackIndex < 0 ||
            !trackHeights ||
            trackIndex >= trackHeights.length) {
            return 68
        }

        return trackHeights[trackIndex]
    }

    function getTrackAtY(canvasY) {
        if (!trackOffsets || trackOffsets.length === 0)
            return 0

        /*
         * canvasY is relative to the visible canvas viewport.
         * Convert it into the complete track-content coordinate first.
         */
        var contentY = canvasY + root.verticalScrollOffset

        for (var i = trackOffsets.length - 1; i >= 0; --i) {
            if (contentY >= trackOffsets[i])
                return i
        }

        return 0
    }

    // =========================================================================
    // Content width / horizontal coordinate helpers
    // =========================================================================

    function updateContentWidth() {
        var requiredPx =
            (root.cachedMaxFrame * root.zoomFactor) + 1500

        root.contentWidth = Math.max(3600, requiredPx)
    }

    function frameToPx(frame) {
        return root.playheadMargin +
               (frame * root.zoomFactor)
    }

    function pxToFrame(px) {
        return Math.max(
            0,
            Math.round(
                (px - root.playheadMargin) /
                root.zoomFactor
            )
        )
    }

    function applyZoom(factor, cursorScreenX) {
        var canvasX =
            cursorScreenX -
            root.headerWidth -
            root.paletteStripWidth -
            root.playheadMargin

        var frameAtAnchor =
            (canvasX + root.horizontalOffset) /
            root.zoomFactor

        var newZoom =
            Math.max(
                0.1,
                Math.min(
                    10.0,
                    root.zoomFactor * factor
                )
            )

        var newOffset =
            (frameAtAnchor * newZoom) -
            canvasX

        var maxOffset =
            Math.max(
                0,
                root.contentWidth -
                (root.timelineCanvasWidth -
                 root.playheadMargin)
            )

        var clampedOffset =
            Math.max(
                0,
                Math.min(
                    maxOffset,
                    newOffset
                )
            )

        if (root.activeTimelineModel) {
            root.activeTimelineModel.zoomFactor = newZoom
            root.activeTimelineModel.horizontalOffset = clampedOffset
        }

        root.updateContentWidth()
    }

    // =========================================================================
    // Clip helpers
    // =========================================================================

    function findClipDelegate(clipId) {
        if (!clipId)
            return null

        for (var i = 0; i < clipRepeater.count; ++i) {
            var item = clipRepeater.itemAt(i)

            if (item &&
                item.clipData &&
                item.clipData.clipId === clipId) {
                return item
            }
        }

        return null
    }

    /*
     * Refresh the visual snapshot after timeline mutations.
     *
     * The clip repeater intentionally uses getAllClips() as a snapshot rather
     * than binding directly to the model's internal clip collection.
     */
    function refreshClips() {
        updateTrackMetrics()
        clipRepeater.refreshAllClips()
        updateContentWidth()
    }

    // =========================================================================
    // Cut / Razor Helpers
    // =========================================================================

    function findClipAt(trackIndex, frame) {
        if (!root.activeTimelineModel || trackIndex < 0)
            return null;
        var clips = root.activeTimelineModel.getClipsForTrack
                  ? root.activeTimelineModel.getClipsForTrack(trackIndex)
                  : [];
        for (var i = 0; i < clips.length; ++i) {
            var c = clips[i];
            var startF = Number(c.startFrame);
            var endF = startF + Number(c.durationFrames);
            if (frame > startF && frame < endF)
                return c;
        }
        return null;
    }

    function executeCut(targetTrack, targetFrame) {
        if (!root.activeTimelineModel || targetFrame < 0)
            return;

        var selectedClips = [];
        var allClips = root.activeTimelineModel.getAllClips ? root.activeTimelineModel.getAllClips() : [];
        for (var i = 0; i < allClips.length; ++i) {
            if (allClips[i].isSelected === true || allClips[i].selected === true)
                selectedClips.push(allClips[i]);
        }

        // ---------------------------------------------------------------------
        // CASE 1: Clips are selected -> Cut ONLY selected clips intersecting frame
        // ---------------------------------------------------------------------
        if (selectedClips.length > 0) {
            var cutAnySelected = false;
            for (var s = 0; s < selectedClips.length; ++s) {
                var sc = selectedClips[s];
                var sStart = Number(sc.startFrame);
                var sEnd = sStart + Number(sc.durationFrames);
                if (targetFrame > sStart && targetFrame < sEnd) {
                    if (typeof root.activeTimelineModel.splitClip === "function") {
                        root.activeTimelineModel.splitClip(sc.clipId, targetFrame);
                        cutAnySelected = true;
                    }
                }
            }
            if (cutAnySelected) {
                root.refreshClips();
                return;
            }
        }

        // ---------------------------------------------------------------------
        // CASE 2: Specific unselected clip clicked -> Cut ONLY that clip
        // ---------------------------------------------------------------------
        if (targetTrack >= 0) {
            var directClip = root.findClipAt(targetTrack, targetFrame);
            if (directClip) {
                if (typeof root.activeTimelineModel.splitClip === "function") {
                    root.activeTimelineModel.splitClip(directClip.clipId, targetFrame);
                } else if (typeof root.activeTimelineModel.cutClipAt === "function") {
                    root.activeTimelineModel.cutClipAt(targetTrack, targetFrame);
                }
                root.refreshClips();
                return;
            }
        }

        // ---------------------------------------------------------------------
        // CASE 3: Empty space / Ruler / No clip selected -> Global cut across all tracks
        // ---------------------------------------------------------------------
        if (typeof root.activeTimelineModel.cutAtPlayhead === "function") {
            root.activeTimelineModel.cutAtPlayhead(targetFrame);
        } else {
            for (var t = 0; t < root.trackCount; ++t) {
                var cAtTrack = root.findClipAt(t, targetFrame);
                if (cAtTrack && typeof root.activeTimelineModel.splitClip === "function") {
                    root.activeTimelineModel.splitClip(cAtTrack.clipId, targetFrame);
                }
            }
        }
        root.refreshClips();
    }

    // =========================================================================
    // Snap / spacing guides
    // =========================================================================

    function showSnapLine(frame) {
        var f =
            (typeof frame === "number" && !isNaN(frame))
            ? Number(frame)
            : -1

        snapGuideFrame = f
        isSnapLineVisible = f >= 0
        activeSpacingGaps = []
    }

    function showSpacingGuides(gapsList) {
        activeSpacingGaps =
            (gapsList && gapsList.length > 0)
            ? gapsList
            : []
    }

    function hideSnapGuides() {
        isSnapLineVisible = false
        snapGuideFrame = -1
        activeSpacingGaps = []
    }

    // =========================================================================
    // Canvas dimensions
    // =========================================================================

    readonly property real timelineCanvasWidth:
        Math.max(
            0,
            timelineView.width
        )

    readonly property real timelineCanvasHeight:
        Math.max(
            0,
            timelineCanvasViewport.height
        )

    // =========================================================================
    // Root background
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: root.bgDark
        z: -10
    }

    // =========================================================================
    // Main layout
    //
    // Column
    //   ├── Toolbar
    //   └── Content area
    //       ├── Empty state
    //       └── Timeline content
    // =========================================================================

    ColumnLayout {
        id: mainLayout

        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------------------
        // Top toolbar
        // ---------------------------------------------------------------------

        TimelineToolBar {
            id: topToolBar
            Layout.fillWidth: true
            playbackManager: root.activePlaybackManager
            timelineModel: root.activeTimelineModel
            projectFps: root.projectFps
            showAudioWaveforms: root.showAudioWaveforms
            onShowAudioWaveformsChanged: root.showAudioWaveforms = showAudioWaveforms
            thumbnailMode: root.thumbnailMode
            onThumbnailModeChanged: root.thumbnailMode = thumbnailMode

            // SYNC ACTIVE TOOL:
            activeToolIndex: root.activeToolIndex
            onToolChanged: function(toolId, toolIndex) {
                root.activeTool = toolId;
                root.activeToolIndex = toolIndex;
            }

            onAddVideoTrackRequested: {
                addTrackModal.pendingKind = 0;
                addTrackModal.open();
            }
            onAddAudioTrackRequested: {
                addTrackModal.pendingKind = 1;
                addTrackModal.open();
            }
        }

        // ---------------------------------------------------------------------
        // Timeline content area
        // ---------------------------------------------------------------------

        Item {
            id: contentArea

            Layout.fillWidth: true
            Layout.fillHeight: true

            // ================================================================
            // Empty state
            // ================================================================

            Item {
                id: emptyState

                anchors.fill: parent
                visible: root.trackCount === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 14

                    Image {
                        Layout.alignment: Qt.AlignHCenter

                        source: "qrc:/assets/icons/layers.svg"
                        sourceSize: Qt.size(42, 42)

                        opacity: 0.35
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter

                            text: "No Tracks in Timeline"

                            color: "#ffffff"
                            font.pixelSize: 15
                            font.bold: true
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter

                            text: "Initialize video and audio tracks to begin editing"

                            color: "#888888"
                            font.pixelSize: 12
                        }
                    }

                    XylaTextButton {
                        Layout.alignment: Qt.AlignHCenter

                        text: "Create Tracks..."
                        primary: true

                        onClicked: {
                            createTracksModal.open()
                        }
                    }
                }
            }

            // ================================================================
            // Main timeline content
            // ================================================================

            RowLayout {
                id: timelineContent

                anchors.fill: parent
                spacing: 0

                visible: root.trackCount > 0

                // ============================================================
                // TRACK LIST
                // ============================================================

                Item {
                    id: trackList

                    // FIX: Must have higher z so its shadow projects OVER the timeline canvas
                    z: 20

                    Rectangle {
                        id: trackBackgroundRect
                        anchors.fill: parent
                        color: "#121212"

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#99000000"
                            shadowBlur: 16
                            shadowHorizontalOffset: 8
                            shadowVerticalOffset: 0
                        }
                    }

                    // Soft Fallback Right Drop Shadow (Guarantees visible shadow even across layers)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.right
                        width: 8
                        z: 100
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#66000000" }
                            GradientStop { position: 1.0; color: "#00000000" }
                        }
                    }

                    Layout.preferredWidth:
                        root.headerWidth +
                        root.paletteStripWidth

                    Layout.minimumWidth:
                        root.headerWidth +
                        root.paletteStripWidth

                    Layout.maximumWidth:
                        root.headerWidth +
                        root.paletteStripWidth

                    Layout.fillHeight: true

                    // clip: true

                    // --------------------------------------------------------
                    // Track-list vertical scroll
                    // --------------------------------------------------------

                    WheelHandler {
                        target: null

                        acceptedDevices:
                            PointerDevice.Mouse |
                            PointerDevice.TouchPad

                        onWheel: function(event) {
                            var delta =
                                event.pixelDelta.y !== 0
                                ? event.pixelDelta.y
                                : event.angleDelta.y

                            root.scrollVertical(-delta)
                        }
                    }

                    // --------------------------------------------------------
                    // Header/ruler alignment spacer
                    //
                    // The track list has no ruler of its own, but its actual
                    // track headers must begin at exactly the same Y position
                    // as the first canvas track.
                    // --------------------------------------------------------

                    Rectangle {
                        id: trackListRulerSpacer

                        x: 0
                        y: 0

                        width: parent.width
                        height: root.rulerHeight

                        color: root.bgHeader

                        z: 10

                        Rectangle {
                            anchors.bottom: parent.bottom

                            width: parent.width
                            height: 1

                            color: "#1E1E1E"
                        }
                    }

                    // --------------------------------------------------------
                    // Track header content
                    // --------------------------------------------------------

                    Item {
                        id: trackHeaderViewport

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: trackListRulerSpacer.bottom
                        anchors.bottom: parent.bottom

                        clip: true

                        Item {
                            id: trackHeaderContent

                            width: parent.width

                            y: -root.verticalScrollOffset

                            height: root.totalTracksHeight

                            Column {
                                id: trackHeaderColumn

                                width: parent.width
                                spacing: 0

                                Repeater {
                                    model: root.activeTimelineModel

                                    TimelineTrackHeader {
                                        width: root.headerWidth

                                        trackIndex: index
                                        trackId:
                                            model.trackId || ""

                                        trackName:
                                            model.trackName || ""

                                        trackKind:
                                            model.trackKind !== undefined
                                            ? model.trackKind
                                            : 0

                                        isSelected:
                                            model.isTrackSelected !== undefined
                                            ? model.isTrackSelected
                                            : false

                                        isHighlighted:
                                            root.isPlayheadOnClipInTrack(index)

                                        onLockToggled: {
                                            if (root.activeTimelineModel)
                                                root.activeTimelineModel
                                                    .toggleTrackLock(trackIndex)
                                        }

                                        onImplicitHeightChanged: {
                                            root.updateTrackMetrics()
                                        }

                                        onTrackHeightChanged: {
                                            root.updateTrackMetrics()
                                        }

                                        Component.onCompleted: {
                                            root.updateTrackMetrics()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ============================================================
                // TIMELINE VIEW
                //
                // Owns the ruler + canvas.
                // ============================================================

                Item {
                    id: timelineView

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true
                    z: 5

                    // --------------------------------------------------------
                    // Left border separating track list from timeline
                    // --------------------------------------------------------

                    // Rectangle {
                    //     anchors.left: parent.left
                    //     anchors.top: parent.top
                    //     anchors.bottom: parent.bottom
                    //
                    //     width: 1
                    //
                    //     color: root.borderDark
                    //
                    //     z: 1000
                    // }

                    // --------------------------------------------------------
                    // Timeline ruler
                    // --------------------------------------------------------

                    XylaTimelineRuler {
                        id: timelineRuler

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top

                        height: root.rulerHeight

                        headerWidth: 0

                        zoomFactor: root.zoomFactor
                        horizontalOffset: root.horizontalOffset
                        contentWidth: root.contentWidth
                        fps: root.projectFps

                        z: 200

                        // Allow clicking/scrubbing on ruler with razor to cut at that frame
                        MouseArea {
                            anchors.fill: parent
                            enabled: root.activeTool === "razor"
                            cursorShape: Qt.CrossCursor
                            hoverEnabled: true
                            onPositionChanged: function(mouse) {
                                root.isRazorHovering = true;
                                root.razorHoverFrame = root.pxToFrame(mouse.x + root.horizontalOffset);
                                root.razorHoverTrack = -1;
                            }
                            onExited: {
                                root.isRazorHovering = false;
                                root.razorHoverFrame = -1;
                            }
                            onClicked: function(mouse) {
                                var cutFrame = root.pxToFrame(mouse.x + root.horizontalOffset);
                                root.executeCut(-1, cutFrame);
                            }
                        }
                    }

                    // --------------------------------------------------------
                    // Canvas viewport
                    // --------------------------------------------------------

                    Item {
                        id: timelineCanvasViewport
                        z: 10

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: timelineRuler.bottom
                        anchors.bottom: parent.bottom

                        clip: true

                        // ====================================================
                        // Canvas background / horizontal content
                        // ====================================================

                        Flickable {
                            id: trackScrollArea

                            anchors.fill: parent

                            clip: true

                            boundsBehavior: Flickable.StopAtBounds

                            /*
                             * Horizontal scrolling is represented by the
                             * timeline model's horizontalOffset.
                             *
                             * Vertical scrolling is centralized in root.
                             */
                            contentWidth:
                                root.contentWidth +
                                root.playheadMargin

                            contentHeight:
                                root.totalTracksHeight

                            interactive: false

                            contentX:
                                root.horizontalOffset -
                                root.playheadMargin

                            contentY:
                                root.verticalScrollOffset

                            Rectangle {
                                anchors.fill: parent

                                color: "#121212"

                                z: 0
                            }

                            // =================================================
                            // Middle-button panning
                            // =================================================

                            DragHandler {
                                id: middleDragHandler

                                target: null

                                acceptedButtons:
                                    Qt.MiddleButton

                                property real startHorizOffset: 0
                                property real startContentY: 0

                                onActiveChanged: {
                                    root.isMiddlePanning = active

                                    if (active) {
                                        startHorizOffset =
                                            root.horizontalOffset

                                        startContentY =
                                            root.verticalScrollOffset
                                    }
                                }

                                onTranslationChanged: {
                                    if (!active)
                                        return

                                    var maxHorizontalOffset =
                                        Math.max(
                                            0,
                                            root.contentWidth -
                                            (root.timelineCanvasWidth -
                                             root.playheadMargin)
                                        )

                                    var newHorizontalOffset =
                                        Math.max(
                                            0,
                                            Math.min(
                                                maxHorizontalOffset,
                                                startHorizOffset -
                                                translation.x
                                            )
                                        )

                                    if (root.activeTimelineModel) {
                                        root.activeTimelineModel
                                            .horizontalOffset =
                                            newHorizontalOffset
                                    }

                                    var maxVerticalOffset =
                                        Math.max(
                                            0,
                                            root.totalTracksHeight -
                                            root.timelineCanvasHeight
                                        )

                                    root.verticalScrollOffset =
                                        Math.max(
                                            0,
                                            Math.min(
                                                maxVerticalOffset,
                                                startContentY -
                                                translation.y
                                            )
                                        )
                                }
                            }

                            // =================================================
                            // Mouse / touchpad wheel
                            // =================================================

                            WheelHandler {
                                id: wheelHandler

                                target: null

                                acceptedDevices:
                                    PointerDevice.Mouse |
                                    PointerDevice.TouchPad

                                onWheel: function(event) {
                                    var cursorX =
                                        event.point?.position?.x ??
                                        wheelHandler.point?.position?.x ??
                                        (trackScrollArea.width / 2)

                                    // -----------------------------------------
                                    // Ctrl + wheel = zoom
                                    // -----------------------------------------

                                    if (event.modifiers &
                                        Qt.ControlModifier) {

                                        var delta =
                                            event.angleDelta.y

                                        if (delta !== 0) {
                                            var zoomMultiplier =
                                                Math.pow(
                                                    1.001,
                                                    delta
                                                )

                                            root.applyZoom(
                                                zoomMultiplier,
                                                cursorX
                                            )
                                        }

                                        return
                                    }

                                    var pixelX =
                                        event.pixelDelta.x !== 0
                                        ? event.pixelDelta.x
                                        : event.angleDelta.x

                                    var pixelY =
                                        event.pixelDelta.y !== 0
                                        ? event.pixelDelta.y
                                        : event.angleDelta.y

                                    var horizontal =
                                        Math.abs(pixelX) >
                                        Math.abs(pixelY) ||
                                        (event.modifiers &
                                         Qt.ShiftModifier)

                                    // -----------------------------------------
                                    // Horizontal scroll
                                    // -----------------------------------------

                                    if (horizontal) {
                                        var deltaX =
                                            pixelX !== 0
                                            ? -pixelX
                                            : -pixelY

                                        var maxOffset =
                                            Math.max(
                                                0,
                                                root.contentWidth -
                                                (root.timelineCanvasWidth -
                                                 root.playheadMargin)
                                            )

                                        var newOffset =
                                            Math.max(
                                                0,
                                                Math.min(
                                                    maxOffset,
                                                    root.horizontalOffset +
                                                    deltaX
                                                )
                                            )

                                        if (root.activeTimelineModel) {
                                            root.activeTimelineModel
                                                .horizontalOffset =
                                                newOffset
                                        }

                                    // -----------------------------------------
                                    // Vertical scroll
                                    // -----------------------------------------

                                    } else {
                                        root.scrollVertical(-pixelY)
                                    }
                                }
                            }

                            // =================================================
                            // Timeline content
                            // =================================================

                            Item {
                                id: timelineCanvasContent

                                width: root.contentWidth
                                height: root.totalTracksHeight

                                Rectangle {
                                  anchors.fill: parent
                                  color: "#121212"
                                }

                                // =============================================
                                // Track backgrounds
                                // =============================================

                                Column {
                                    id: canvasTrackBackgrounds

                                    width: parent.width

                                    Repeater {
                                        model: root.trackCount

                                        Rectangle {
                                            width: timelineCanvasContent.width

                                            height:
                                                root.getTrackHeight(index)

                                            color:
                                                root.getTrackBgColor(index)

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom

                                                height: 1

                                                color: "#1E1E1E"
                                            }
                                        }
                                    }
                                }

                                // =============================================
                                // Marquee selection
                                // =============================================

                                MouseArea {
                                    id: timelineInteractionArea
                                    anchors.fill: parent

                                    // Dynamic cursor: Scissors / Precision Crosshair for Razor
                                    cursorShape: root.activeTool === "razor" ? Qt.CrossCursor : Qt.ArrowCursor
                                    hoverEnabled: root.activeTool === "razor"

                                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                                    property real startGlobalX: 0
                                    property real startGlobalY: 0
                                    property real startCanvasX: 0
                                    property real startCanvasY: 0
                                    property bool isMarquee: false

                                    onEntered: {
                                        if (root.activeTool === "razor")
                                            root.isRazorHovering = true;
                                    }

                                    onExited: {
                                        root.isRazorHovering = false;
                                        root.razorHoverFrame = -1;
                                        root.razorHoverTrack = -1;
                                    }

                                    onPressed: function(mouse) {
                                        if (mouse.button === Qt.RightButton)
                                            return;

                                        // =====================================
                                        // RAZOR TOOL CLICK: CUT CLIP AT CURSOR
                                        // =====================================
                                        if (root.activeTool === "razor") {
                                            var cutFrame = root.pxToFrame(mouse.x);
                                            var cutTrack = root.getTrackAtY(mouse.y);
                                            root.executeCut(cutTrack, cutFrame);
                                            return;
                                        }

                                        // Standard Marquee setup
                                        var globalPoint = mapToItem(root, mouse.x, mouse.y);
                                        startGlobalX = globalPoint.x;
                                        startGlobalY = globalPoint.y;
                                        startCanvasX = mouse.x;
                                        startCanvasY = mouse.y;
                                        isMarquee = false;
                                    }

                                    onPositionChanged: function(mouse) {
                                        // Track razor hover position
                                        if (root.activeTool === "razor") {
                                            root.isRazorHovering = true;
                                            root.razorHoverFrame = root.pxToFrame(mouse.x);
                                            root.razorHoverTrack = root.getTrackAtY(mouse.y);
                                            return;
                                        }

                                        if (mouse.buttons & Qt.RightButton)
                                            return;

                                        var globalPoint = mapToItem(root, mouse.x, mouse.y);
                                        var dx = globalPoint.x - startGlobalX;
                                        var dy = globalPoint.y - startGlobalY;

                                        if (!isMarquee && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
                                            isMarquee = true;
                                            if (root.activeTimelineModel)
                                                root.activeTimelineModel.startSelectionBatch();
                                        }

                                        if (!isMarquee)
                                            return;

                                        marqueeRect.x = Math.min(startGlobalX, globalPoint.x);
                                        marqueeRect.y = Math.min(startGlobalY, globalPoint.y);
                                        marqueeRect.width = Math.max(startGlobalX, globalPoint.x) - marqueeRect.x;
                                        marqueeRect.height = Math.max(startGlobalY, globalPoint.y) - marqueeRect.y;
                                        marqueeRect.visible = true;

                                        var startFrame = root.pxToFrame(Math.min(startCanvasX, mouse.x));
                                        var endFrame = root.pxToFrame(Math.max(startCanvasX, mouse.x));
                                        var startTrack = root.getTrackAtY(Math.min(startCanvasY, mouse.y));
                                        var endTrack = root.getTrackAtY(Math.max(startCanvasY, mouse.y));
                                        var toggle = mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier);

                                        if (root.activeTimelineModel) {
                                            root.activeTimelineModel.selectBox(startFrame, endFrame, startTrack, endTrack, toggle);
                                        }
                                    }

                                    onReleased: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            var overlayPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                            timelineContextMenu.openAt(overlayPoint.x, overlayPoint.y, root.pxToFrame(mouse.x), root.getTrackAtY(mouse.y), null);
                                            return;
                                        }

                                        if (root.activeTool === "razor")
                                            return;

                                        if (isMarquee) {
                                            if (root.activeTimelineModel)
                                                root.activeTimelineModel.commitSelectionBatch();
                                            isMarquee = false;
                                            marqueeRect.visible = false;
                                        } else if (root.activeTimelineModel) {
                                            root.activeTimelineModel.clearSelection();
                                        }
                                    }
                                }

                                // =============================================
                                // Asset drop area
                                // =============================================

                                DropArea {
                                    anchors.fill: parent

                                    keys: [
                                        "xyla/media-asset",
                                        "text/uri-list",
                                        "text/plain"
                                    ]

                                    z: 2

                                    onEntered: function(drag) {
                                        drag.accept(Qt.CopyAction)
                                    }

                                    onPositionChanged: function(drag) {
                                        drag.accept(Qt.CopyAction)
                                    }

                                    onDropped: function(drop) {
                                        drop.accept(Qt.CopyAction)

                                        if (!root.activeTimelineModel)
                                            return

                                        var rawPayload = ""

                                        if (drop.formats &&
                                            drop.formats.indexOf(
                                                "xyla/media-asset"
                                            ) !== -1) {

                                            rawPayload =
                                                drop.getDataAsString(
                                                    "xyla/media-asset"
                                                ).trim()

                                        } else if (drop.hasText &&
                                                   drop.text &&
                                                   drop.text.length > 0) {

                                            rawPayload =
                                                drop.text.trim()

                                        } else if (drop.hasUrls &&
                                                   drop.urls &&
                                                   drop.urls.length > 0) {

                                            rawPayload =
                                                drop.urls[0].toString()
                                        }

                                        if (!rawPayload)
                                            return

                                        var assetId =
                                            (typeof mediaPool !== "undefined" &&
                                             mediaPool)
                                            ? mediaPool.getAssetId(rawPayload)
                                            : ""

                                        if (!assetId)
                                            assetId = rawPayload

                                        var assetDuration =
                                            (typeof mediaPool !== "undefined" &&
                                             mediaPool)
                                            ? mediaPool.getAssetDurationFrames(
                                                assetId,
                                                root.projectFps
                                            )
                                            : 0

                                        var slash =
                                            rawPayload.lastIndexOf("/")

                                        var assetName =
                                            slash >= 0
                                            ? rawPayload.substring(slash + 1)
                                            : rawPayload

                                        if (!assetName)
                                            assetName = "Clip"

                                        var dropFrame =
                                            root.pxToFrame(drop.x)

                                        var dropTrack =
                                            root.getTrackAtY(drop.y)

                                        var newId =
                                            root.activeTimelineModel.addClip(
                                                assetId,
                                                assetName,
                                                dropTrack,
                                                dropFrame,
                                                assetDuration,
                                                0
                                            )

                                        if (newId &&
                                            newId.length > 0) {
                                            root.updateContentWidth()
                                        }
                                    }
                                }

                                // =============================================
                                // Clips
                                // =============================================

                                Item {
                                    id: unifiedClipsLayer

                                    anchors.fill: parent

                                    z: 10

                                    Connections {
                                        target:
                                            root.activeTimelineModel
                                            ? root.activeTimelineModel
                                            : null

                                        function onTrackDataChanged(trackIndex) {
                                            root.updateTrackMetrics()
                                            clipRepeater.refreshAllClips()
                                            root.updateContentWidth()
                                        }

                                        function onTrackCountChanged() {
                                            root.updateTrackMetrics()
                                            clipRepeater.refreshAllClips()
                                            root.updateContentWidth()
                                        }

                                        function onClipPropertiesChanged(clipId) {
                                            clipRepeater.refreshAllClips()
                                        }
                                    }

                                    Repeater {
                                        id: clipRepeater

                                        model: []

                                        function refreshAllClips() {
                                            model =
                                                root.activeTimelineModel
                                                ? root.activeTimelineModel
                                                    .getAllClips()
                                                : []
                                        }

                                        Component.onCompleted: {
                                            refreshAllClips()
                                        }

                                        TimelineClipCard {
                                            timelineRoot: root

                                            clipData: modelData

                                            zoomFactor:
                                                root.zoomFactor
                                        }
                                    }
                                }

                                // =============================================
                                // Snap / spacing guides
                                // =============================================

                                Item {
                                    id: snapGuideLayer

                                    anchors.fill: parent

                                    z: 500

                                    Rectangle {
                                        id: snapLine

                                        visible:
                                            root.isSnapLineVisible &&
                                            root.snapGuideFrame >= 0

                                        x:
                                            Math.round(
                                                root.snapGuideFrame *
                                                root.zoomFactor
                                            )

                                        width: 1
                                        height: parent.height

                                        color: "#2563eb"
                                        opacity: 0.8

                                        z: 150

                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.horizontalCenter:
                                                parent.horizontalCenter

                                            width: 3
                                            height: 3

                                            radius: 1.5

                                            color: "#3b82f6"
                                        }
                                    }

                                    Item {
                                        id: spacingGuide

                                        visible:
                                            root.activeSpacingGaps.length > 0

                                        anchors.fill: parent

                                        z: 140

                                        Repeater {
                                            model:
                                                root.activeSpacingGaps

                                            Rectangle {
                                                id: gapRect

                                                readonly property bool isActive:
                                                    modelData.isActive === true

                                                x:
                                                    Math.round(
                                                        Number(modelData.start) *
                                                        root.zoomFactor
                                                    )

                                                width:
                                                    Math.max(
                                                        1,
                                                        Math.round(
                                                            (Number(modelData.end) -
                                                             Number(modelData.start)) *
                                                            root.zoomFactor
                                                        )
                                                    )

                                                height: parent.height

                                                color:
                                                    isActive
                                                    ? Qt.rgba(
                                                        0.145,
                                                        0.388,
                                                        0.922,
                                                        0.18
                                                      )
                                                    : Qt.rgba(
                                                        0.145,
                                                        0.388,
                                                        0.922,
                                                        0.10
                                                      )

                                                border.color:
                                                    isActive
                                                    ? "#3b82f6"
                                                    : "#2563eb"

                                                border.width: 1

                                                Rectangle {
                                                    anchors.centerIn: parent

                                                    width:
                                                        gapBadgeText.implicitWidth +
                                                        10

                                                    height: 18

                                                    color:
                                                        gapRect.isActive
                                                        ? "#2563eb"
                                                        : "#1d4ed8"

                                                    radius: 4

                                                    border.color:
                                                        gapRect.isActive
                                                        ? "#60a5fa"
                                                        : "#3b82f6"

                                                    border.width: 1

                                                    Text {
                                                        id: gapBadgeText

                                                        anchors.centerIn:
                                                            parent

                                                        text:
                                                            (modelData.gapFrames !==
                                                             undefined
                                                             ? modelData.gapFrames
                                                             : "") + "f"

                                                        color: "#ffffff"

                                                        font.pixelSize: 10
                                                        font.bold: true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ====================================================
                    // PLAYHEAD
                    //
                    // The playhead deliberately lives inside the canvas
                    // viewport. It can therefore never escape the canvas
                    // horizontally, even when the timeline is resized.
                    // ====================================================
                    //
                    // ========================================================
                    // FULL-HEIGHT RAZOR CUT LINE (Ruler Top to Canvas Bottom)
                    // Lower z-index than playhead (z: 800 vs z: 1000)
                    // ========================================================
                    RazorLine {
                        id: timelineRazorLine
                        z: 1000000
                        frame: (root.activeTool === "razor" && root.isRazorHovering) ? root.razorHoverFrame : -1
                        zoomFactor: root.zoomFactor
                        horizontalOffset: root.horizontalOffset
                        playheadMargin: root.playheadMargin
                        lineColor: "#ff50f0" // Purple
                        lineWidth: 1
                    }

                    // ========================================================
                    // PLAYHEAD LAYER (Spans ruler + canvas)
                    // Higher z-index than razor line (z: 1000)
                    // ========================================================
                    Item {
                        id: playheadLayer
                        anchors.fill: parent
                        opacity: root.activeTool === "pointer" ? 1.0 : 0
                        visible: opacity > 0
                        clip: true
                        z: 1000

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }

                        XylaPlayhead {
                            id: mainPlayhead
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            timelineRoot: root
                            topToolBar: topToolBar
                            activeTimelineModel: root.activeTimelineModel
                            currentFrame: root.activePlaybackManager ? root.activePlaybackManager.currentFrame : 0
                            zoomFactor: root.zoomFactor
                            horizontalOffset: root.horizontalOffset
                            playheadMargin: root.playheadMargin
                            rulerHeight: root.rulerHeight
                            headerWidth: 0
                        }
                    }
                }

                // ============================================================
                // MIXER SIDE
                // ============================================================

                Item {
                    id: timelineMixerSide

                    Layout.fillHeight: true
                    Layout.fillWidth: false

                    Layout.preferredWidth: 90
                    Layout.minimumWidth: 90
                    Layout.maximumWidth: 90

                    width: 90

                    // FIX: Must have higher z than timelineView (z: 5) to project shadow over it
                    z: 20

                    // Background with MultiEffect shadow on the opaque rectangle
                    Rectangle {
                        id: backgroundRect
                        anchors.fill: parent
                        color: "#181818"

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#99000000"
                            shadowBlur: 16
                            shadowHorizontalOffset: -8
                            shadowVerticalOffset: 0
                        }
                    }

                    // Soft Fallback Left Drop Shadow (Casts cleanly over the right edge of timeline)
                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.left
                        width: 8
                        z: 100
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#00000000" }
                            GradientStop { position: 1.0; color: "#66000000" }
                        }
                    }

                    Item {
                        anchors.fill: parent

                        anchors.topMargin: 18
                        anchors.rightMargin: 20
                        anchors.bottomMargin: 18

                        Repeater {
                            model: root.activeMixerModel

                            delegate: Item {
                                visible: false

                                Component.onCompleted: {
                                    if (model.isMaster === true) {
                                        masterPeakMeter.peakLeft =
                                            Qt.binding(function() {
                                                return model.peakL !== undefined
                                                       ? model.peakL
                                                       : 0.0
                                            })

                                        masterPeakMeter.peakRight =
                                            Qt.binding(function() {
                                                return model.peakR !== undefined
                                                       ? model.peakR
                                                       : 0.0
                                            })
                                    }
                                }
                            }
                        }

                        XylaPeakMeter {
                            id: masterPeakMeter

                            anchors.fill: parent

                            itemWidth: 14

                            peakLeft:
                                root.activeMixerModel &&
                                typeof root.activeMixerModel.masterPeakL ===
                                "number"
                                ? root.activeMixerModel.masterPeakL
                                : 0.0

                            peakRight:
                                root.activeMixerModel &&
                                typeof root.activeMixerModel.masterPeakR ===
                                "number"
                                ? root.activeMixerModel.masterPeakR
                                : 0.0

                            doNotShowNumbers: true
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // Marquee selection overlay
    // =========================================================================

    Rectangle {
        id: marqueeRect

        color: "#253B82F6"

        border.color: "#3B82F6"
        border.width: 1

        visible: false

        // z: 4
    }

    // =========================================================================
    // Sidebar resizer
    // =========================================================================

    Item {
        id: sidebarResizer

        width: 8

        x: root.headerWidth - 4
        y: topToolBar.height

        height: parent.height - y

        z: 350

        visible: root.trackCount > 0

        Rectangle {
            anchors.centerIn: parent

            width:
                resizerMouse.containsMouse ||
                resizerMouse.pressed
                ? 1
                : 0

            height: parent.height

            color:
                resizerMouse.containsMouse ||
                resizerMouse.pressed
                ? "#2555D3"
                : "transparent" // "#2d2d2d"

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

            onPressed: function(mouse) {
                var point =
                    mapToItem(
                        root,
                        mouse.x,
                        mouse.y
                    )

                startMouseX = point.x
                startWidth = root.headerWidth
            }

            onPositionChanged: function(mouse) {
                if (!pressed)
                    return

                var point =
                    mapToItem(
                        root,
                        mouse.x,
                        mouse.y
                    )

                var deltaX =
                    point.x - startMouseX

                root.headerWidth =
                    Math.max(
                        root.minHeaderWidth,
                        Math.min(
                            root.maxHeaderWidth,
                            startWidth + deltaX
                        )
                    )
            }
        }
    }

    // =========================================================================
    // Context menu
    // =========================================================================

    TimelineContextMenu {
        id: timelineContextMenu

        timelineRoot: root
        timelineModel: root.activeTimelineModel
        playbackManager: root.activePlaybackManager

        onDeleteRequested: {
            if (root.activeTimelineModel) {
                root.activeTimelineModel.deleteSelectedClips()
                root.updateContentWidth()
            }
        }

        onRippleDeleteRequested: {
            if (root.activeTimelineModel) {
                root.activeTimelineModel.deleteSelectedClips()
                root.updateContentWidth()
            }
        }

        onSplitRequested: function(frame, track) {
            if (root.activeTimelineModel &&
                root.activePlaybackManager) {

                root.activeTimelineModel.cutAtPlayhead(
                    root.activePlaybackManager.currentFrame
                )

                root.updateContentWidth()
            }
        }

        onSelectAllRequested: {
            if (!root.activeTimelineModel)
                return

            var all =
                root.activeTimelineModel.getAllClips()

            var ids = []

            for (var i = 0; i < all.length; ++i)
                ids.push(all[i].clipId)

            root.activeTimelineModel.applyDirectSelection(ids)
        }
    }

    // =========================================================================
    // Add track modal
    // =========================================================================

    TimelineAddTrackModal {
        id: addTrackModal

        onConfirmed: function(kind) {
            if (!root.activeTimelineModel)
                return

            if (kind === 0 &&
                root.activeTimelineModel.addVideoTrack) {

                root.activeTimelineModel.addVideoTrack()

            } else if (kind === 1 &&
                       root.activeTimelineModel.addAudioTrack) {

                root.activeTimelineModel.addAudioTrack()
            }

            root.updateTrackMetrics()
            clipRepeater.refreshAllClips()
            root.updateContentWidth()
        }
    }

    // =========================================================================
    // Create tracks modal
    // =========================================================================

    TimelineCreateTracksModal {
        id: createTracksModal

        onConfirmed: function(videoCount, audioCount) {
            if (!root.activeTimelineModel)
                return

            root.activeTimelineModel.createDefaultTracks(
                videoCount,
                audioCount
            )

            root.updateTrackMetrics()
            clipRepeater.refreshAllClips()
            root.updateContentWidth()
        }
    }
}
