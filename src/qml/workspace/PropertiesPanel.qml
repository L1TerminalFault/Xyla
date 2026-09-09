import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "./sections"

Item {
    id: propRoot

    property var activeTimelineModel: typeof timelineModel !== "undefined" ? timelineModel : null
    property var activePlaybackManager: typeof playbackManager !== "undefined" ? playbackManager : null

    property string activeClipId: (activeTimelineModel && activeTimelineModel.selectedClipId !== undefined) ? activeTimelineModel.selectedClipId : ""
    property var activeClipData: (activeTimelineModel && activeTimelineModel.selectedClipData !== undefined) ? activeTimelineModel.selectedClipData : null

    readonly property int currentPlayheadFrame: activePlaybackManager ? activePlaybackManager.currentFrame : 0
    property int keyframeRevision: 0
    property bool hasClip: activeClipId !== "" && activeClipData !== null
    property int currentTab: 0

    // Resolved clip ids for the current selection (supports linked A/V pair)
    property string videoClipId: ""
    property string audioClipId: ""
    property bool hasVideo: videoClipId !== ""
    property bool hasAudio: audioClipId !== ""

    // Live values – Video
    property real clipPosX: 0.0
    property real clipPosY: 0.0
    property real clipScaleX: 1.0
    property real clipScaleY: 1.0
    property bool uniformScale: true
    property real clipRotation: 0.0
    property real clipOpacity: 1.0
    property int clipBlendMode: 0

    // Live values – Audio
    property real clipVolume: 1.0
    property real clipPan: 0.0

    // Keyframe state
    property bool posXKeyed: false
    property bool posYKeyed: false
    property bool scaleXKeyed: false
    property bool scaleYKeyed: false
    property bool rotationKeyed: false
    property bool opacityKeyed: false
    property bool volumeKeyed: false
    property bool panKeyed: false

    function resolveSelection() {
        videoClipId = "";
        audioClipId = "";

        if (!activeTimelineModel || !hasClip)
            return;
        const primaryId = activeClipId;
        const trackIdx = activeClipData.trackIndex ?? -1;
        const kind = activeTimelineModel.getTrackKind(trackIdx);

        if (kind === 0) {          // TrackKind.Video
            videoClipId = primaryId;
            const linked = activeTimelineModel.getLinkedClipIds(primaryId);
            for (let i = 0; i < linked.length; ++i) {
                const id = linked[i];
                if (id === primaryId)
                    continue;
                // Assume the other half of a standard A/V link is audio
                audioClipId = id;
                break;
            }
        } else if (kind === 1) {   // TrackKind.Audio
            audioClipId = primaryId;
            const linked = activeTimelineModel.getLinkedClipIds(primaryId);
            for (let i = 0; i < linked.length; ++i) {
                const id = linked[i];
                if (id === primaryId)
                    continue;
                videoClipId = id;
                break;
            }
        }

        // Keep current tab valid
        if (currentTab === 0 && !hasVideo && hasAudio)
            currentTab = 1;
        else if (currentTab === 1 && !hasAudio && hasVideo)
            currentTab = 0;
    }

    function updateLiveValues() {
        if (!activeTimelineModel)
            return;
        if (hasVideo) {
            clipPosX = activeTimelineModel.getClipEvaluatedProperty(videoClipId, "positionX", currentPlayheadFrame);
            clipPosY = activeTimelineModel.getClipEvaluatedProperty(videoClipId, "positionY", currentPlayheadFrame);
            clipScaleX = activeTimelineModel.getClipEvaluatedProperty(videoClipId, "scaleX", currentPlayheadFrame);
            clipScaleY = activeTimelineModel.getClipEvaluatedProperty(videoClipId, "scaleY", currentPlayheadFrame);
            clipRotation = activeTimelineModel.getClipEvaluatedProperty(videoClipId, "rotation", currentPlayheadFrame);
            clipOpacity = activeTimelineModel.getClipEvaluatedProperty(videoClipId, "opacity", currentPlayheadFrame);

            posXKeyed = activeTimelineModel.hasKeyframe(videoClipId, "positionX", currentPlayheadFrame);
            posYKeyed = activeTimelineModel.hasKeyframe(videoClipId, "positionY", currentPlayheadFrame);
            scaleXKeyed = activeTimelineModel.hasKeyframe(videoClipId, "scaleX", currentPlayheadFrame);
            scaleYKeyed = activeTimelineModel.hasKeyframe(videoClipId, "scaleY", currentPlayheadFrame);
            rotationKeyed = activeTimelineModel.hasKeyframe(videoClipId, "rotation", currentPlayheadFrame);
            opacityKeyed = activeTimelineModel.hasKeyframe(videoClipId, "opacity", currentPlayheadFrame);
        }

        if (hasAudio) {
            clipVolume = activeTimelineModel.getClipEvaluatedProperty(audioClipId, "volume", currentPlayheadFrame);
            clipPan = activeTimelineModel.getClipEvaluatedProperty(audioClipId, "pan", currentPlayheadFrame);

            volumeKeyed = activeTimelineModel.hasKeyframe(audioClipId, "volume", currentPlayheadFrame);
            panKeyed = activeTimelineModel.hasKeyframe(audioClipId, "pan", currentPlayheadFrame);
        }
    }

    function commitTransform(key, val) {
        if (!activeTimelineModel)
            return;
        const id = videoClipId !== "" ? videoClipId : activeClipId;
        if (id === "")
            return;
        activeTimelineModel.updateClipTransformProperty(id, key, val);
        keyframeRevision++;
        updateLiveValues();
    }

    function commitAudio(key, val) {
        if (!activeTimelineModel)
            return;
        const id = audioClipId !== "" ? audioClipId : activeClipId;
        if (id === "")
            return;
        activeTimelineModel.updateClipAudioProperty(id, key, val);
        keyframeRevision++;
        updateLiveValues();
    }

    function togglePropKeyframe(clipId, key, currentVal) {
        if (!activeTimelineModel)
            return;
        const id = clipId !== "" ? clipId : activeClipId;
        if (id === "")
            return;
        activeTimelineModel.toggleKeyframe(id, key, currentPlayheadFrame, currentVal);
        keyframeRevision++;
        updateLiveValues();
    }

    function resetTransforms() {
        clipPosX = 0;
        clipPosY = 0;
        clipScaleX = 1;
        clipScaleY = 1;
        clipRotation = 0;
        clipOpacity = 1;
        clipBlendMode = 0;
        commitTransform("positionX", 0);
        commitTransform("positionY", 0);
        commitTransform("scaleX", 1);
        commitTransform("scaleY", 1);
        commitTransform("rotation", 0);
        commitTransform("opacity", 1);
        commitTransform("blendMode", 0);
    }

    function resetAudio() {
        clipVolume = 1;
        clipPan = 0;
        commitAudio("volume", 1);
        commitAudio("pan", 0);
    }

    Connections {
        target: propRoot.activePlaybackManager
        function onFrameChanged() {
            propRoot.keyframeRevision++;
            propRoot.updateLiveValues();
        }
    }

    Connections {
        target: propRoot.activeTimelineModel
        function onClipPropertiesChanged(clipId) {
            if (clipId === propRoot.videoClipId || clipId === propRoot.audioClipId) {
                propRoot.keyframeRevision++;
                propRoot.updateLiveValues();
            }
        }
        function onSelectedClipIdChanged() {
            propRoot.resolveSelection();
            propRoot.updateLiveValues();
            propRoot.keyframeRevision++;
        }
    }

    onActiveClipDataChanged: {
        if (!activeClipData) {
            videoClipId = "";
            audioClipId = "";
            clipPosX = 0;
            clipPosY = 0;
            clipScaleX = 1;
            clipScaleY = 1;
            clipRotation = 0;
            clipOpacity = 1;
            clipBlendMode = 0;
            clipVolume = 1;
            clipPan = 0;
            return;
        }
        clipBlendMode = activeClipData.blendMode ?? 0;
        resolveSelection();
        updateLiveValues();
        keyframeRevision++;
    }

    Component.onCompleted: {
        resolveSelection();
        updateLiveValues();
    }

    // ── UI ──────────────────────────────────────────────────────────

    component XylaCollapsibleSection: ColumnLayout {
        id: sectionRoot
        property string title: "Section"
        property bool expanded: true
        default property alias contentData: contentSlot.data

        Layout.fillWidth: true
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            height: 24
            radius: 3
            color: headerMouse.containsMouse ? "#222222" : "#191919"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 6

                Text {
                    text: sectionRoot.title
                    color: "#bbbbbb"
                    font.pixelSize: 10
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    Layout.fillWidth: true
                }

                Image {
                    source: "qrc:/assets/icons/chevron-down.svg"
                    sourceSize.width: 14
                    sourceSize.height: 14
                    opacity: headerMouse.containsMouse ? 1.0 : 0.55
                    rotation: sectionRoot.expanded ? 0 : -90
                    Behavior on rotation {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sectionRoot.expanded = !sectionRoot.expanded
            }
        }

        Item {
            Layout.fillWidth: true
            clip: true
            visible: implicitHeight > 0
            implicitHeight: sectionRoot.expanded ? contentSlot.implicitHeight + 16 : 0
            opacity: sectionRoot.expanded ? 1.0 : 0.0
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 110
                }
            }

            ColumnLayout {
                id: contentSlot
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                spacing: 6
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#161616"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        opacity: propRoot.hasClip ? 1.0 : 0.18
        enabled: propRoot.hasClip

        // Sidebar tabs

Rectangle {
    Layout.fillHeight: true
    Layout.preferredWidth: 38
    color: "#181818"

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: "#242424"
    }

    Column {
        id: tabColumn

        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        // Video tab
        Rectangle {
            id: videoTab

            width: 28
            height: 28
            radius: 5

            visible: propRoot.hasVideo || (!propRoot.hasVideo && !propRoot.hasAudio)

            color: propRoot.currentTab === 0
                   ? "#282828"
                   : (vidTabMouse.containsMouse ? "#202020" : "transparent")

            Image {
                anchors.centerIn: parent
                width: 15
                height: 15
                source: "qrc:/assets/icons/video.svg"
                opacity: propRoot.currentTab === 0 ? 1.0 : 0.4
            }

            MouseArea {
                id: vidTabMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    propRoot.currentTab = 0
                }
            }
        }

        // Audio tab
        Rectangle {
            id: audioTab

            width: 28
            height: 28
            radius: 5

            visible: propRoot.hasAudio || (!propRoot.hasVideo && !propRoot.hasAudio)

            color: propRoot.currentTab === 1
                   ? "#282828"
                   : (audTabMouse.containsMouse ? "#202020" : "transparent")

            Image {
                anchors.centerIn: parent
                width: 15
                height: 15
                source: "qrc:/assets/icons/volume.svg"
                opacity: propRoot.currentTab === 1 ? 1.0 : 0.4
            }

            MouseArea {
                id: audTabMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    propRoot.currentTab = 1
                }
            }
        }

        // Metadata tab
        Rectangle {
            id: metadataTab

            width: 28
            height: 28
            radius: 5

            visible: true

            color: propRoot.currentTab === 2
                   ? "#282828"
                   : (metaTabMouse.containsMouse ? "#202020" : "transparent")

            Image {
                anchors.centerIn: parent
                width: 15
                height: 15
                source: "qrc:/assets/icons/info.svg"
                opacity: propRoot.currentTab === 2 ? 1.0 : 0.4
            }

            MouseArea {
                id: metaTabMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    propRoot.currentTab = 2
                }
            }
        }
    }

    // EXACT same selection-pill animation used by Settings.
    Rectangle {
        id: selectionPill

        width: 2
        radius: 1
        color: "#3b82f6"

        // Same horizontal position as the original
        // per-tab indicators:
        //
        // tab left = 5
        // indicator left = 5 - 4 = 1
        x: 1

        z: 10

        property Item targetItem: null
        property real baseHeight: 16
        property real pillY: 0
        property real pillHeight: baseHeight

        visible: targetItem !== null
        opacity: targetItem !== null ? 1.0 : 0.0

        y: pillY
        height: pillHeight

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }

        SequentialAnimation {
            id: pillAnim

            property real startY: 0
            property real targetY: 0
            property real startHeight: selectionPill.baseHeight
            property real distance: 0
            property bool movingDown: true

            onStarted: {
                distance = Math.abs(targetY - startY)
                movingDown = targetY > startY
            }

            // Stretch + move
            ParallelAnimation {
                NumberAnimation {
                    target: selectionPill
                    property: "pillY"

                    from: pillAnim.startY
                    to: pillAnim.movingDown
                       ? pillAnim.startY
                       : pillAnim.targetY

                    duration: 140
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: selectionPill
                    property: "pillHeight"

                    from: pillAnim.startHeight
                    to: selectionPill.baseHeight + pillAnim.distance

                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            // Finish movement + contract
            ParallelAnimation {
                NumberAnimation {
                    target: selectionPill
                    property: "pillY"

                    from: pillAnim.movingDown
                          ? pillAnim.startY
                          : pillAnim.targetY

                    to: pillAnim.targetY

                    duration: 40
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: selectionPill
                    property: "pillHeight"

                    from: selectionPill.baseHeight + pillAnim.distance
                    to: selectionPill.baseHeight

                    duration: 40
                    easing.type: Easing.OutCubic
                }
            }

            onFinished: {
                selectionPill.pillY = targetY
                selectionPill.pillHeight = selectionPill.baseHeight
            }
        }

        function updatePosition(item) {
            if (!item)
                return

            Qt.callLater(function() {
                if (!item || !selectionPill.parent)
                    return

                var p = item.mapToItem(
                    selectionPill.parent,
                    0,
                    0
                )

                var newY = p.y
                           + (item.height - selectionPill.baseHeight) / 2

                if (targetItem === null) {
                    targetItem = item
                    pillY = newY
                    pillHeight = baseHeight
                    return
                }

                if (targetItem === item) {
                    pillY = newY
                    return
                }

                var currentY = pillY
                var currentHeight = pillHeight

                if (pillAnim.running)
                    pillAnim.stop()

                pillAnim.startY = currentY
                pillAnim.targetY = newY
                pillAnim.startHeight = currentHeight

                targetItem = item
                pillAnim.start()
            })
        }

        function currentTabItem() {
            if (propRoot.currentTab === 0)
                return videoTab

            if (propRoot.currentTab === 1)
                return audioTab

            if (propRoot.currentTab === 2)
                return metadataTab

            return null
        }

        Component.onCompleted: {
            updatePosition(currentTabItem())
        }

        Connections {
            target: propRoot

            function onCurrentTabChanged() {
                selectionPill.updatePosition(
                    selectionPill.currentTabItem()
                )
            }
        }
    }
}

        // Main content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                height: 32
                color: "#181818"

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: "#242424"
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8

                    Text {
                        text: propRoot.currentTab === 0 ? "Video Properties" : propRoot.currentTab === 1 ? "Audio Properties" : "Clip Information"
                        color: "#dddddd"
                        font.pixelSize: 11
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    XylaIconButton {
                        iconSource: "qrc:/assets/icons/rotate.svg"
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        tooltip: "Reset All Parameters"
                        visible: propRoot.currentTab === 0 || propRoot.currentTab === 1
                        onClicked: {
                            if (propRoot.currentTab === 0)
                                propRoot.resetTransforms();
                            else if (propRoot.currentTab === 1)
                                propRoot.resetAudio();
                        }
                    }
                }
            }

            ScrollView {
                id: propScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                StackLayout {
                    width: propScroll.availableWidth
                    currentIndex: propRoot.currentTab

                    // Tab 0 – Video
                    ColumnLayout {
                        width: propScroll.availableWidth
                        spacing: 2
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8

                        XylaCollapsibleSection {
                            title: "Transform"
                            TransformSection {
                                posX: propRoot.clipPosX
                                posY: propRoot.clipPosY
                                scaleX: propRoot.clipScaleX
                                scaleY: propRoot.clipScaleY
                                rotation: propRoot.clipRotation
                                uniformScale: propRoot.uniformScale
                                posXKeyed: propRoot.posXKeyed
                                posYKeyed: propRoot.posYKeyed
                                scaleXKeyed: propRoot.scaleXKeyed
                                scaleYKeyed: propRoot.scaleYKeyed
                                rotationKeyed: propRoot.rotationKeyed

                                onValueCommitted: (key, val) => propRoot.commitTransform(key, val)
                                onKeyframeToggled: (key, val) => propRoot.togglePropKeyframe(propRoot.videoClipId, key, val)
                                onUniformScaleToggled: propRoot.uniformScale = !propRoot.uniformScale
                            }
                        }

                        XylaCollapsibleSection {
                            title: "Compositing"
                            CompositingSection {
                                opacityValue: propRoot.clipOpacity
                                blendMode: propRoot.clipBlendMode
                                opacityKeyed: propRoot.opacityKeyed

                                onValueCommitted: (key, val) => {
                                    if (key === "blendMode")
                                        propRoot.clipBlendMode = val;
                                    propRoot.commitTransform(key, val);
                                }
                                onKeyframeToggled: (key, val) => propRoot.togglePropKeyframe(propRoot.videoClipId, key, val)
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    // Tab 1 – Audio
                    ColumnLayout {
                        width: propScroll.availableWidth
                        spacing: 2
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8

                        XylaCollapsibleSection {
                            title: "Audio Controls"
                            AudioSection {
                                volume: propRoot.clipVolume
                                pan: propRoot.clipPan
                                volumeKeyed: propRoot.volumeKeyed
                                panKeyed: propRoot.panKeyed

                                onValueCommitted: (key, val) => propRoot.commitAudio(key, val)
                                onKeyframeToggled: (key, val) => propRoot.togglePropKeyframe(propRoot.audioClipId, key, val)
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    // Tab 2 – Metadata
                    ColumnLayout {
                        width: propScroll.availableWidth
                        spacing: 2
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8

                        XylaCollapsibleSection {
                            title: "File Information"
                            MetadataSection {
                                clipName: propRoot.activeClipData ? (propRoot.activeClipData.name ?? "") : ""
                                durationFrames: propRoot.activeClipData ? (propRoot.activeClipData.durationFrames ?? 0) : 0
                                assetId: propRoot.activeClipData ? (propRoot.activeClipData.assetId ?? "") : ""
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }
        }
    }
}
