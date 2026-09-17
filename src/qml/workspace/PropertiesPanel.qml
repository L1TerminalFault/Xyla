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

    readonly property bool isTextClip: {
        if (!activeClipData)
            return false;
        if (activeClipData.isTextClip !== undefined && activeClipData.isTextClip !== null)
            return Boolean(activeClipData.isTextClip);
        if (activeClipData.assetId && (activeClipData.assetId.indexOf("asset_title_") !== -1 || activeClipData.assetId.indexOf("title") !== -1))
            return true;
        return false;
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered && typeof layoutController !== "undefined" && layoutController)
                layoutController.setActiveDockId("InspectorPanel");
        }
    }

    property string videoClipId: ""
    property string audioClipId: ""
    property bool hasVideo: videoClipId !== ""
    property bool hasAudio: audioClipId !== ""

    property real clipPosX: 0.0
    property real clipPosY: 0.0
    property real clipScaleX: 1.0
    property real clipScaleY: 1.0
    property bool uniformScale: activeClipData ? (activeClipData.uniformScale ?? true) : true
    property real clipRotation: 0.0
    property real clipOpacity: 1.0
    property int clipBlendMode: 0

    function toggleUniformScale() {
        if (!activeTimelineModel)
            return;
        const targetId = videoClipId !== "" ? videoClipId : activeClipId;
        if (targetId === "")
            return;

        var nextState = !uniformScale;
        uniformScale = nextState;
        activeTimelineModel.setClipUniformScale(targetId, nextState);
    }

    property real clipVolume: 1.0
    property real clipPan: 0.0

    property string textContent: ""
    property string textFontFamily: "Inter"
    property real textFontSize: 72.0
    property real textTracking: 0.0
    property real textLineSpacing: 1.2
    property real textStrokeWidth: 0.0
    property int textStrokePosition: 0
    property real textTrimStart: 0.0
    property real textTrimEnd: 1.0
    property real textTrimOffset: 0.0

    property bool posXKeyed: false
    property bool posYKeyed: false
    property bool scaleXKeyed: false
    property bool scaleYKeyed: false
    property bool rotationKeyed: false
    property bool opacityKeyed: false
    property bool volumeKeyed: false
    property bool panKeyed: false
    property bool fontSizeKeyed: false
    property bool trackingKeyed: false
    property bool strokeWidthKeyed: false
    property bool trimStartKeyed: false
    property bool trimEndKeyed: false
    property bool trimOffsetKeyed: false

    function resolveSelection() {
        videoClipId = "";
        audioClipId = "";

        if (!activeTimelineModel || !hasClip)
            return;

        const primaryId = activeClipId;
        const trackIdx = activeClipData.trackIndex ?? -1;
        const primaryKind = activeTimelineModel.getTrackKind(trackIdx);

        if (primaryKind === 0) {
            videoClipId = primaryId;
        } else if (primaryKind === 1) {
            audioClipId = primaryId;
        } else {
            videoClipId = primaryId;
        }

        const linked = activeTimelineModel.getLinkedClipIds(primaryId);
        for (let i = 0; i < linked.length; ++i) {
            const cId = linked[i];
            if (cId === primaryId)
                continue;

            for (let t = 0; t < activeTimelineModel.trackCount; ++t) {
                const clipsOnTrack = activeTimelineModel.getClipsForTrack(t);
                for (let k = 0; k < clipsOnTrack.length; ++k) {
                    if (clipsOnTrack[k].clipId === cId) {
                        const tKind = activeTimelineModel.getTrackKind(t);
                        if (tKind === 0 && videoClipId === "")
                            videoClipId = cId;
                        else if (tKind === 1 && audioClipId === "")
                            audioClipId = cId;
                        break;
                    }
                }
            }
        }
    }

    onActiveClipIdChanged: {
        resolveSelection();
        if (isTextClip) {
            currentTab = 2;
        } else if (!hasVideo && hasAudio) {
            currentTab = 1;
        } else {
            currentTab = 0;
        }
        updateLiveValues();
    }

    function updateLiveValues() {
        if (!activeTimelineModel || !hasClip)
            return;

        const vId = videoClipId !== "" ? videoClipId : activeClipId;
        if (hasVideo) {
            clipPosX = activeTimelineModel.getClipEvaluatedProperty(vId, "positionX", currentPlayheadFrame);
            clipPosY = activeTimelineModel.getClipEvaluatedProperty(vId, "positionY", currentPlayheadFrame);
            clipScaleX = activeTimelineModel.getClipEvaluatedProperty(vId, "scaleX", currentPlayheadFrame);
            clipScaleY = activeTimelineModel.getClipEvaluatedProperty(vId, "scaleY", currentPlayheadFrame);
            clipRotation = activeTimelineModel.getClipEvaluatedProperty(vId, "rotation", currentPlayheadFrame);
            clipOpacity = activeTimelineModel.getClipEvaluatedProperty(vId, "opacity", currentPlayheadFrame);

            if (activeClipData && activeClipData.uniformScale !== undefined) {
                uniformScale = activeClipData.uniformScale;
            }

            posXKeyed = activeTimelineModel.hasKeyframe(vId, "positionX", currentPlayheadFrame);
            posYKeyed = activeTimelineModel.hasKeyframe(vId, "positionY", currentPlayheadFrame);
            scaleXKeyed = activeTimelineModel.hasKeyframe(vId, "scaleX", currentPlayheadFrame);
            scaleYKeyed = activeTimelineModel.hasKeyframe(vId, "scaleY", currentPlayheadFrame);
            rotationKeyed = activeTimelineModel.hasKeyframe(vId, "rotation", currentPlayheadFrame);
            opacityKeyed = activeTimelineModel.hasKeyframe(vId, "opacity", currentPlayheadFrame);
        }

        if (isTextClip) {
            textContent = activeClipData.text ?? (activeClipData.textContent ?? (activeClipData.name ?? "Title"));
            textFontFamily = activeClipData.fontFamily ?? "Inter";
            textStrokePosition = activeClipData.strokePosition ?? 0;

            textFontSize = activeTimelineModel.getClipEvaluatedProperty(vId, "text.fontSize", currentPlayheadFrame);
            if (textFontSize <= 0)
                textFontSize = 72;

            textTracking = activeTimelineModel.getClipEvaluatedProperty(vId, "text.tracking", currentPlayheadFrame);
            textLineSpacing = activeTimelineModel.getClipEvaluatedProperty(vId, "text.lineSpacing", currentPlayheadFrame);
            if (textLineSpacing <= 0)
                textLineSpacing = 1.2;

            textStrokeWidth = activeTimelineModel.getClipEvaluatedProperty(vId, "text.strokeWidth", currentPlayheadFrame);
            textTrimStart = activeTimelineModel.getClipEvaluatedProperty(vId, "text.trimStart", currentPlayheadFrame);
            textTrimEnd = activeTimelineModel.getClipEvaluatedProperty(vId, "text.trimEnd", currentPlayheadFrame);
            textTrimOffset = activeTimelineModel.getClipEvaluatedProperty(vId, "text.trimOffset", currentPlayheadFrame);

            fontSizeKeyed = activeTimelineModel.hasKeyframe(vId, "text.fontSize", currentPlayheadFrame);
            trackingKeyed = activeTimelineModel.hasKeyframe(vId, "text.tracking", currentPlayheadFrame);
            strokeWidthKeyed = activeTimelineModel.hasKeyframe(vId, "text.strokeWidth", currentPlayheadFrame);
            trimStartKeyed = activeTimelineModel.hasKeyframe(vId, "text.trimStart", currentPlayheadFrame);
            trimEndKeyed = activeTimelineModel.hasKeyframe(vId, "text.trimEnd", currentPlayheadFrame);
            trimOffsetKeyed = activeTimelineModel.hasKeyframe(vId, "text.trimOffset", currentPlayheadFrame);
        }

        const aId = audioClipId !== "" ? audioClipId : activeClipId;
        if (hasAudio) {
            clipVolume = activeTimelineModel.getClipEvaluatedProperty(aId, "volume", currentPlayheadFrame);
            clipPan = activeTimelineModel.getClipEvaluatedProperty(aId, "pan", currentPlayheadFrame);

            volumeKeyed = activeTimelineModel.hasKeyframe(aId, "volume", currentPlayheadFrame);
            panKeyed = activeTimelineModel.hasKeyframe(aId, "pan", currentPlayheadFrame);
        }
    }

    onCurrentPlayheadFrameChanged: updateLiveValues()

    function commitProperty(targetClipId, address, val) {
        if (!activeTimelineModel || targetClipId === "")
            return;

        activeTimelineModel.updateClipProperty(targetClipId, address, val);
        keyframeRevision++;
        updateLiveValues();
    }

    function commitTransform(key, val) {
        const id = videoClipId !== "" ? videoClipId : activeClipId;
        const address = (key.indexOf(".") !== -1 || key === "blendMode") ? key : ("transform." + key);
        commitProperty(id, address, val);
    }

    function commitAudio(key, val) {
        const id = audioClipId !== "" ? audioClipId : activeClipId;
        const address = key.indexOf(".") !== -1 ? key : ("audio." + key);
        commitProperty(id, address, val);
    }

    function commitText(key, val) {
        const id = videoClipId !== "" ? videoClipId : activeClipId;
        const address = key.indexOf(".") !== -1 ? key : ("text." + key);
        commitProperty(id, address, val);
    }

    function togglePropKeyframe(clipId, key, currentVal) {
        if (!activeTimelineModel)
            return;
        const id = clipId !== "" ? clipId : (videoClipId !== "" ? videoClipId : activeClipId);
        if (id === "")
            return;

        activeTimelineModel.toggleKeyframe(id, key, currentPlayheadFrame, currentVal);
        keyframeRevision++;
        updateLiveValues();
    }

    function resetTransforms() {
        const id = videoClipId !== "" ? videoClipId : activeClipId;
        if (!activeTimelineModel || id === "")
            return;

        commitTransform("positionX", 0);
        commitTransform("positionY", 0);
        commitTransform("scaleX", 1);
        commitTransform("scaleY", 1);
        commitTransform("rotation", 0);
        commitTransform("opacity", 1);
        commitTransform("blendMode", 0);
    }

    function resetAudio() {
        const id = audioClipId !== "" ? audioClipId : activeClipId;
        if (!activeTimelineModel || id === "")
            return;

        commitAudio("volume", 1);
        commitAudio("pan", 0);
    }

    function resetText() {
        commitText("fontSize", 72);
        commitText("tracking", 0);
        commitText("lineSpacing", 1.2);
        commitText("strokeWidth", 0);
        commitText("trimStart", 0);
        commitText("trimEnd", 1);
        commitText("trimOffset", 0);
    }

    Connections {
        target: propRoot.activePlaybackManager
        function onFrameChanged(frame, timeSeconds) {
            propRoot.keyframeRevision++;
            propRoot.updateLiveValues();
        }
    }

    Connections {
        target: propRoot.activeTimelineModel
        function onClipPropertiesChanged(clipId) {
            if (clipId === propRoot.videoClipId || clipId === propRoot.audioClipId || clipId === propRoot.activeClipId) {
                propRoot.keyframeRevision++;
                propRoot.updateLiveValues();
            }
        }
        function onSelectedClipDataChanged() {
            propRoot.resolveSelection();
            // Force QML to reload the live data
            propRoot.activeClipData = propRoot.activeTimelineModel ? propRoot.activeTimelineModel.selectedClipData : null;
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
            textContent = "";
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

        // =====================================================================
        // VERTICAL TAB NAVIGATION DOCK
        // =====================================================================
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

                // Tab 0: Video
                Rectangle {
                    id: videoTab
                    width: 28
                    height: 28
                    radius: 5
                    visible: propRoot.hasVideo || (!propRoot.hasVideo && !propRoot.hasAudio)
                    color: propRoot.currentTab === 0 ? "#282828" : (vidTabMouse.containsMouse ? "#202020" : "transparent")

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
                        onClicked: propRoot.currentTab = 0
                    }
                }

                // Tab 1: Audio
                Rectangle {
                    id: audioTab
                    width: 28
                    height: 28
                    radius: 5
                    visible: propRoot.hasAudio || (!propRoot.hasVideo && !propRoot.hasAudio)
                    color: propRoot.currentTab === 1 ? "#282828" : (audTabMouse.containsMouse ? "#202020" : "transparent")

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
                        onClicked: propRoot.currentTab = 1
                    }
                }

                // Tab 2: Text Properties
                Rectangle {
                    id: textTab
                    width: 28
                    height: 28
                    radius: 5
                    visible: propRoot.isTextClip
                    color: propRoot.currentTab === 2 ? "#282828" : (txtTabMouse.containsMouse ? "#202020" : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "T"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#ffffff"
                        opacity: propRoot.currentTab === 2 ? 1.0 : 0.4
                    }

                    MouseArea {
                        id: txtTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: propRoot.currentTab = 2
                    }
                }

                // Tab 4: Text Animators (Modifiers)
                Rectangle {
                    id: animatorsTab
                    width: 28
                    height: 28
                    radius: 5
                    visible: propRoot.isTextClip
                    color: propRoot.currentTab === 4 ? "#282828" : (animTabMouse.containsMouse ? "#202020" : "transparent")

                    Text {
                        anchors.centerIn: parent
                        text: "✦"
                        font.pixelSize: 14
                        color: propRoot.currentTab === 4 ? "#3b82f6" : "#ffffff"
                        opacity: propRoot.currentTab === 4 ? 1.0 : 0.4
                    }

                    MouseArea {
                        id: animTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: propRoot.currentTab = 4
                    }
                }

                // Tab 3: Metadata / Info
                Rectangle {
                    id: metadataTab
                    width: 28
                    height: 28
                    radius: 5
                    visible: true
                    color: propRoot.currentTab === 3 ? "#282828" : (metaTabMouse.containsMouse ? "#202020" : "transparent")

                    Image {
                        anchors.centerIn: parent
                        width: 15
                        height: 15
                        source: "qrc:/assets/icons/info.svg"
                        opacity: propRoot.currentTab === 3 ? 1.0 : 0.4
                    }

                    MouseArea {
                        id: metaTabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: propRoot.currentTab = 3
                    }
                }
            }

            Rectangle {
                id: selectionPill
                width: 2
                radius: 1
                color: "#3b82f6"
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

                function updatePosition(item) {
                    if (!item)
                        return;
                    Qt.callLater(function () {
                        if (!item || !selectionPill.parent)
                            return;
                        var p = item.mapToItem(selectionPill.parent, 0, 0);
                        pillY = p.y + (item.height - selectionPill.baseHeight) / 2;
                        targetItem = item;
                    });
                }

                function currentTabItem() {
                    if (propRoot.currentTab === 0)
                        return videoTab;
                    if (propRoot.currentTab === 1)
                        return audioTab;
                    if (propRoot.currentTab === 2)
                        return textTab;
                    if (propRoot.currentTab === 3)
                        return metadataTab;
                    if (propRoot.currentTab === 4)
                        return animatorsTab;
                    return null;
                }

                Component.onCompleted: updatePosition(currentTabItem())

                Connections {
                    target: propRoot
                    function onCurrentTabChanged() {
                        selectionPill.updatePosition(selectionPill.currentTabItem());
                    }
                }
            }
        }

        // =====================================================================
        // CONTENT AREA
        // =====================================================================
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
                        text: {
                            if (propRoot.currentTab === 0)
                                return "Video Properties";
                            if (propRoot.currentTab === 1)
                                return "Audio Properties";
                            if (propRoot.currentTab === 2)
                                return "Text & Title Properties";
                            if (propRoot.currentTab === 4)
                                return "Character Animators";
                            return "Clip Information";
                        }
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
                        visible: propRoot.currentTab === 0 || propRoot.currentTab === 1 || propRoot.currentTab === 2
                        onClicked: {
                            if (propRoot.currentTab === 0)
                                propRoot.resetTransforms();
                            else if (propRoot.currentTab === 1)
                                propRoot.resetAudio();
                            else if (propRoot.currentTab === 2)
                                propRoot.resetText();
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

                    // Tab 0: Video (Transform + Compositing)
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
                                onUniformScaleToggled: propRoot.toggleUniformScale()
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

                    // Tab 1: Audio Controls
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

                    // Tab 2: Title & Typography
                    ColumnLayout {
                        width: propScroll.availableWidth
                        spacing: 2
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8

                        XylaCollapsibleSection {
                            title: "Title & Typography"
                            TextSection {
                                textContent: propRoot.textContent
                                fontFamily: propRoot.textFontFamily
                                fontSize: propRoot.textFontSize
                                tracking: propRoot.textTracking
                                lineSpacing: propRoot.textLineSpacing
                                strokeWidth: propRoot.textStrokeWidth
                                strokePosition: propRoot.textStrokePosition
                                trimStart: propRoot.textTrimStart
                                trimEnd: propRoot.textTrimEnd
                                trimOffset: propRoot.textTrimOffset

                                fillColor: propRoot.activeClipData?.fillColor ?? "#ffffff"
                                strokeColor: propRoot.activeClipData?.strokeColor ?? "#000000"

                                fontSizeKeyed: propRoot.fontSizeKeyed
                                trackingKeyed: propRoot.trackingKeyed
                                strokeWidthKeyed: propRoot.strokeWidthKeyed
                                trimStartKeyed: propRoot.trimStartKeyed
                                trimEndKeyed: propRoot.trimEndKeyed
                                trimOffsetKeyed: propRoot.trimOffsetKeyed

                                onValueCommitted: (key, val) => propRoot.commitText(key, val)
                                onKeyframeToggled: (key, val) => propRoot.togglePropKeyframe(propRoot.videoClipId, "text." + key, val)
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    // Tab 3: File Information
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

                    // Tab 4: Character Animators (Blender-Style Modifier Stack)
                    ColumnLayout {
                        width: propScroll.availableWidth
                        spacing: 2
                        Layout.topMargin: 6
                        Layout.bottomMargin: 6
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8

                        AnimatorsSection {
                            Layout.fillWidth: true
                            clipId: propRoot.activeClipId
                            clipData: propRoot.activeClipData
                            activeTimelineModel: propRoot.activeTimelineModel
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
