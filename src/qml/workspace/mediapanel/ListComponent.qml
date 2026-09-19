import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Xyla 1.0

ListView {
    id: listView
    cacheBuffer: 600
    // Exposed properties from parent
    property var panelRoot: null
    property var contextMenu: null
    property var globalDummyDragTarget: null

    clip: true
    spacing: 2
    model: panelRoot.activeMediaBinModel
    focus: false
    keyNavigationEnabled: false
    activeFocusOnTab: false

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: function (eventPoint, button) {
            panelRoot.editingItemId = "";
            panelRoot.clearSelection();
            if (button === Qt.RightButton) {
                contextMenu.hasSelection = false;
                contextMenu.selectionCount = 0;
                contextMenu.selectionIsFolder = false;
                contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
                contextMenu.openAt(eventPoint.scenePosition.x, eventPoint.scenePosition.y);
            }
        }
    }

    DropArea {
        anchors.fill: parent
        z: -1 // Sits behind delegates

        onDropped: function (drop) {
            if (panelRoot.draggedAssetIds.length > 0 && panelRoot.activeMediaBinModel) {
                drop.accept(Qt.MoveAction);

                // Pass "" (or null/0) to move items to root
                panelRoot.activeMediaBinModel.moveAssetsById(panelRoot.draggedAssetIds, "");
                // panelRoot.clearSelection();
                panelRoot.draggedAssetIds = [];
            }
        }
    }

    delegate: Item {
        id: listDelegateContainer
        width: listView.width
        height: model.isFolder ? 32 : 60

        readonly property int stepSize: 20
        readonly property int depthVal: model.depth || 0
        readonly property int cardIndent: depthVal * stepSize + (depthVal > 0 ? 6 : 0)

        // 1. Initialize to initial animation state so it never "flashes" full opacity first
        property real itemScale: panelRoot.allowEntranceCascade ? 0.90 : 1.0
        property real itemOpacity: panelRoot.allowEntranceCascade ? 0.0 : 1.0
        scale: itemScale
        opacity: itemOpacity
        transformOrigin: Item.Left

        // 2. Targeted animation when called directly (pulse/pop in place without vanishing)
        function playEntranceAnim() {
            listTargetedAnim.restart();
        }

        function playEntranceAnimWithDelay(delayMs) {
            if (delayMs > 0) {
                animDelayTimer.interval = delayMs;
                animDelayTimer.restart();
            } else {
                playEntranceAnim();
            }
        }

        Timer {
            id: animDelayTimer
            repeat: false
            onTriggered: playEntranceAnim()
        }

        // 3. Stagger only runs on initial load / view mode switch
        Component.onCompleted: {
            if (panelRoot.editingItemId === model.id) {
                renameField.grabFocus();
                listFocusTimer.restart();
            }

            if (panelRoot.allowEntranceCascade) {
                listStaggerTimer.interval = Math.min(index * 20, 240);
                listStaggerTimer.start();
            }
        }

        Timer {
            id: listStaggerTimer
            repeat: false
            onTriggered: listEntranceAnim.restart()
        }

        // Initial load/mode-switch animation
        ParallelAnimation {
            id: listEntranceAnim
            NumberAnimation {
                target: listDelegateContainer
                property: "itemScale"
                from: 0.90
                to: 1.0
                duration: 180
                easing.type: Easing.OutBack
                easing.overshoot: 1.25
            }
            NumberAnimation {
                target: listDelegateContainer
                property: "itemOpacity"
                from: 0.0
                to: 1.0
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        // Targeted animation for single modified/renamed/added item
        SequentialAnimation {
            id: listTargetedAnim
            NumberAnimation {
                target: listDelegateContainer
                property: "itemScale"
                from: 1.0
                to: 1.04
                duration: 120
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: listDelegateContainer
                property: "itemScale"
                from: 1.04
                to: 1.0
                duration: 160
                easing.type: Easing.InOutQuad
            }
        }

        // Full-depth tree hierarchy connector
        Canvas {
            id: treeConnectorCanvas
            visible: depthVal > 0 || (model.isFolder && model.isExpanded)
            width: Math.max(32, cardIndent + 2)
            height: parent.height + listView.spacing
            anchors.left: parent.left
            anchors.top: parent.top
            z: 0

            property int curDepth: depthVal
            property bool isExp: model.isExpanded || false
            property bool isLast: model.isLastChild || false
            property int maskVal: model.ancestorMask || 0

            onCurDepthChanged: requestPaint()
            onIsExpChanged: requestPaint()
            onIsLastChanged: requestPaint()
            onMaskValChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                var depth = depthVal;
                var rowH = parent.height;
                var totalH = height;
                var midY = Math.round(rowH / 2);
                var radius = 6;
                var step = stepSize;
                var mask = model.ancestorMask || 0;

                ctx.strokeStyle = "#3e3e42";
                ctx.lineWidth = 0.5;
                ctx.beginPath();

                // A. Expanded parent folder: vertical spine under chevron
                if (model.isFolder && model.isExpanded) {
                    var fldSpineX = depth * step + 14;
                    ctx.moveTo(fldSpineX, midY + 6);
                    ctx.lineTo(fldSpineX, totalH);
                }

                if (depth <= 0) {
                    ctx.stroke();
                    return;
                }

                // B. Ancestor pass-through lines
                for (var d = 0; d < depth - 1; d++) {
                    if (mask & (1 << d)) {
                        var spineX = d * step + 14;
                        ctx.moveTo(spineX, 0);
                        ctx.lineTo(spineX, totalH);
                    }
                }

                // C. Immediate parent branch line curving into child card with comfortable gap
                var parentSpineX = (depth - 1) * step + 14;
                var isLast = model.isLastChild;
                var targetEndX = cardIndent;

                ctx.moveTo(parentSpineX, 0);
                ctx.lineTo(parentSpineX, midY - radius);

                // Smooth curved turn with clear spacing into the card
                ctx.quadraticCurveTo(parentSpineX, midY, parentSpineX + radius, midY);
                ctx.lineTo(targetEndX, midY);

                // Continue straight down for lower siblings if not last child
                if (!isLast) {
                    ctx.moveTo(parentSpineX, midY - radius);
                    ctx.lineTo(parentSpineX, totalH);
                }

                ctx.stroke();
            }
        }

        Rectangle {
            id: listDelegateItem
            property int itemIndex: index
            anchors.fill: parent
            anchors.leftMargin: listDelegateContainer.cardIndent
            // anchors.leftMargin: (model.depth || 0) * 16
            anchors.rightMargin: 0
            radius: 5
            color: listDropOnFolder.containsDrag ? "#233554" : (panelRoot.isSelected(index) ? panelRoot.bgCardSelected : (itemMouseArea.containsMouse ? panelRoot.bgCardHover : "#1a1a1c"))
            border.color: listDropOnFolder.containsDrag ? "#4d88e8" : (panelRoot.isSelected(index) ? panelRoot.accentColor : "transparent")
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Drag.active: itemMouseArea.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.keys: ["xyla/media-asset", "text/uri-list"]
            Drag.source: listDelegateItem
            Drag.mimeData: {
                "xyla/media-asset": model.id || "",
                "text/uri-list": model.path ? (model.path.startsWith("file://") ? model.path : "file://" + model.path) : ""
            }
            Drag.imageSource: model.isFolder ? "qrc:/assets/icons/folder.svg" : (model.path ? ("image://thumbnails/" + model.path + "?width=40") : "qrc:/assets/icons/crop-landscape.svg")
            Drag.hotSpot.x: 20
            Drag.hotSpot.y: 20

            // Folder drop target in Tree
            DropArea {
                id: listDropOnFolder
                anchors.fill: parent
                enabled: model.isFolder
                keys: ["xyla/media-asset", "text/uri-list"]

                onEntered: function (drag) {
                    if (panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
                        drag.accepted = false;
                        return;
                    }
                    drag.accept(Qt.MoveAction);
                }

                onDropped: function (drop) {
                    if (!model.isFolder || panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
                        drop.accepted = false;
                        return;
                    }
                    drop.accept(Qt.MoveAction);
                    var targetFolderId = model.id;
                    var root = panelRoot;
                    if (root && root.draggedAssetIds.length > 0 && root.activeMediaBinModel) {
                        root.activeMediaBinModel.moveAssetsById(root.draggedAssetIds, targetFolderId);
                        root.draggedAssetIds = [];
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8 // + ((model.depth || 0) * 16)
                anchors.rightMargin: 10
                spacing: 6
                z: 1

                Item {
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    visible: model.isFolder

                    Image {
                        id: chevronIcon
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        source: "qrc:/assets/icons/chevron-down.svg"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        transformOrigin: Item.Center
                        rotation: model.isExpanded ? 0 : -90

                        Behavior on rotation {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Color overlay using MultiEffect
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: treeChevronMouse.containsMouse ? "#ffffff" : "#808080"

                            Behavior on colorizationColor {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: treeChevronMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            panelRoot.editingItemId = "";
                            if (panelRoot.activeMediaBinModel) {
                                panelRoot.activeMediaBinModel.toggleFolderExpanded(model.id);
                            }
                        }
                    }
                }

                Item {
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    visible: !model.isFolder
                }

                Rectangle {
                    id: thumbFrame_
                    visible: !model.isFolder
                    width: 70
                    height: 48
                    // Layout.fillWidth: true
                    // Layout.fillHeight: true
                    radius: 5
                    color: "#121213"

                    // Mask item defined cleanly with proper binding sizes
                    Item {
                        id: maskContainer
                        width: thumbFrame_.width
                        height: thumbFrame_.height
                        visible: false

                        Rectangle {
                            width: parent.width
                            height: parent.height
                            radius: thumbFrame_.radius
                            color: "black"
                        }
                    }

                    Image {
                        anchors.fill: parent
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectCrop
                        clip: true
                        source: model.path ? "image://thumbnails/" + model.path + "?width=" + Math.round(panelRoot.gridCellSize * 1.5) : ""
                        asynchronous: true

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                sourceItem: maskContainer
                                live: true
                                hideSource: true
                            }
                        }
                    }
                }

                Image {
                    visible: model.isFolder
                    source: model.isExpanded ? "qrc:/assets/icons/folder-open.svg" : "qrc:/assets/icons/folder.svg"
                    sourceSize.width: 15
                    sourceSize.height: 15
                    opacity: model.isFolder ? 0.95 : 0.75
                }

                Text {
                    id: nameText
                    visible: panelRoot.editingItemId !== model.id
                    text: model.isFolder ? (model.name || "") : panelRoot.displayName(model.name || "", panelRoot.showExtensions)
                    color: panelRoot.textPrimary
                    font.pixelSize: 12
                    font.weight: model.isFolder ? Font.Medium : Font.Normal
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                TextField {
                    id: renameField
                    visible: panelRoot.editingItemId === model.id
                    Layout.fillWidth: true
                    z: 20
                    text: model.name || ""
                    font.pixelSize: 12
                    color: "#ffffff"
                    selectByMouse: true
                    focus: visible
                    background: Rectangle {
                        color: "#121212"
                        radius: 6
                    }

                    property bool isReady: false

                    function grabFocus() {
                        renameField.forceActiveFocus();
                        renameField.selectAll();
                    }

                    onVisibleChanged: {
                        if (visible) {
                            isReady = false;
                            text = model.name || "";
                            grabFocus();
                            listFocusTimer.restart();
                        } else {
                            isReady = false;
                        }
                    }

                    Timer {
                        id: listFocusTimer
                        interval: 160
                        repeat: false
                        onTriggered: {
                            if (renameField.visible) {
                                renameField.grabFocus();
                                renameField.isReady = true;
                            }
                        }
                    }

                    onActiveFocusChanged: {
                        if (!activeFocus && isReady && visible) {
                            commitRename();
                        }
                    }

                    Keys.onReturnPressed: commitRename()
                    Keys.onEnterPressed: commitRename()
                    Keys.onEscapePressed: panelRoot.editingItemId = ""

                    function commitRename() {
                        if (panelRoot.editingItemId === model.id && panelRoot.activeMediaBinModel) {
                            let newName = text.trim();
                            panelRoot.editingItemId = "";
                            if (newName !== "" && newName !== model.name) {
                                panelRoot.activeMediaBinModel.renameAssetById(model.id, newName);
                            }
                        } else {
                            panelRoot.editingItemId = "";
                        }
                    }
                }

                Text {
                    text: model.resolution || ""
                    color: "#666666"
                    font.pixelSize: 10
                    visible: !model.isFolder && panelRoot.editingItemId !== model.id
                }

                Text {
                    text: model.duration || ""
                    color: "#888888"
                    font.pixelSize: 11
                    visible: !model.isFolder && panelRoot.editingItemId !== model.id
                }
            }

            MouseArea {
                id: itemMouseArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: panelRoot.editingItemId === ""
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                drag.target: globalDummyDragTarget
                drag.threshold: 5

                onPressed: function (mouse) {
                    // dragPreview.visible = false;

                    if (panelRoot.editingItemId !== "" && panelRoot.editingItemId !== model.id) {
                        panelRoot.editingItemId = "";
                    }

                    if (mouse.button === Qt.LeftButton) {
                        if (mouse.modifiers & Qt.ShiftModifier && panelRoot.lastSelectedIndex >= 0) {
                            panelRoot.selectRange(panelRoot.lastSelectedIndex, index);
                        } else if (mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) {
                            panelRoot.toggleSelect(index);
                        } else if (!panelRoot.isSelected(index)) {
                            panelRoot.selectSingle(index);
                        }

                        panelRoot.draggedAssetIds = panelRoot.getSelectedAssetIds();
                        panelRoot.dragPreviewName = model.name || "";
                        panelRoot.dragPreviewPath = model.path || "";
                        panelRoot.dragPreviewIsFolder = model.isFolder;
                        panelRoot.dragCount = Math.max(1, panelRoot.selectedIndices.length);
                    }
                }

                onPositionChanged: function (mouse) {
                    if (!itemMouseArea.drag.active)
                        return;

                    var pt = itemMouseArea.mapToItem(Overlay.overlay, mouse.x, mouse.y);

                    panelRoot.isCustomDragging = true;

                    panelRoot.dragGlobalX = pt.x;
                    panelRoot.dragGlobalY = pt.y;
                }

                onReleased: function (mouse) {
                    panelRoot.isCustomDragging = false;
                }

                onCanceled: {
                    panelRoot.isCustomDragging = false;
                }

                onClicked: function (mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        if (!(mouse.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.MetaModifier))) {
                            panelRoot.selectSingle(index);
                            clipMonitorController.loadAsset(model.id);
                        }
                    } else if (mouse.button === Qt.RightButton) {
                        if (!panelRoot.isSelected(index)) {
                            panelRoot.selectSingle(index);
                        }
                        let globalPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                        contextMenu.hasSelection = true;
                        contextMenu.selectionCount = Math.max(1, panelRoot.selectedIndices.length);
                        contextMenu.selectionIsFolder = (contextMenu.selectionCount === 1 && model.isFolder);
                        contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
                        contextMenu.openAt(globalPoint.x, globalPoint.y);
                    }
                }

                onDoubleClicked: function (mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        if (model.isFolder) {
                            panelRoot.editingItemId = "";
                            // Folders expand / collapse
                            if (panelRoot.activeMediaBinModel) {
                                panelRoot.activeMediaBinModel.toggleFolderExpanded(model.id);
                            }
                        } else {
                            // Media clips load into the Clip Monitor!
                            if (typeof clipMonitorController !== "undefined" && clipMonitorController) {
                                clipMonitorController.loadAsset(model.id);
                            }
                        }
                    }
                }
            }
        }
    }

    // New items only — existing cards are NOT staggered.
    add: Transition {
        SequentialAnimation {
            PauseAnimation {
                duration: Math.min(index * 20, 240)
            }
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }

    // Existing cards pushed down/up by an insertion/removal.
    // Position only — no fade, no scale.
    addDisplaced: Transition {
        NumberAnimation {
            properties: "y"
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    moveDisplaced: Transition {
        NumberAnimation {
            properties: "y"
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    move: Transition {
        NumberAnimation {
            properties: "y"
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    remove: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: 140
            easing.type: Easing.InCubic
        }
    }

    removeDisplaced: Transition {
        SequentialAnimation {
            PauseAnimation {
                duration: 130
            }
            NumberAnimation {
                properties: "y"
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }

    MediaPanelEmpty {
        visible: listView.count === 0
    }
}
