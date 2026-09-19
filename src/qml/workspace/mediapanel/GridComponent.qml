import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Xyla 1.0
import "../../components"

GridView {
    id: gridView
    cacheBuffer: 600
    // Exposed properties from parent
    property var panelRoot: null
    property var contextMenu: null
    property var globalDummyDragTarget: null

    clip: true
    property real gridGap: 12
    property real gridPadding: 10
    topMargin: gridPadding
    bottomMargin: gridPadding
    leftMargin: gridPadding
    rightMargin: gridPadding
    cellWidth: panelRoot.gridCellSize + gridGap
    cellHeight: (panelRoot.gridCellSize * 0.90) + gridGap
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

    delegate: Item {
        id: gridDelegateItem
        property int itemIndex: index
        width: gridView.cellWidth - gridView.gridGap
        height: gridView.cellHeight - gridView.gridGap

        // 1. Initialize to initial animation state
        property real cardScale: panelRoot.allowEntranceCascade ? 0.82 : 1.0
        property real cardOpacity: panelRoot.allowEntranceCascade ? 0.0 : 1.0
        scale: cardScale
        opacity: cardOpacity
        transformOrigin: Item.Center

        // 2. Targeted animation
        function playEntranceAnim() {
            gridTargetedAnim.restart();
        }

        // 3. Stagger only runs on initial load / view mode switch
        Component.onCompleted: {
            if (panelRoot.editingItemId === model.id) {
                grabFocus();
                gridFocusTimer.restart();
            }

            if (panelRoot.allowEntranceCascade) {
                gridStaggerTimer.interval = Math.min(index * 25, 300);
                gridStaggerTimer.start();
            }
        }

        Timer {
            id: gridStaggerTimer
            repeat: false
            onTriggered: entranceAnim.restart()
        }

        // Initial load/mode-switch animation
        ParallelAnimation {
            id: entranceAnim
            NumberAnimation {
                target: gridDelegateItem
                property: "cardScale"
                from: 0.82
                to: 1.0
                duration: 190
                easing.type: Easing.OutBack
                easing.overshoot: 1.35
            }
            NumberAnimation {
                target: gridDelegateItem
                property: "cardOpacity"
                from: 0.0
                to: 1.0
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        // Targeted animation for single modified/renamed/added item
        SequentialAnimation {
            id: gridTargetedAnim
            NumberAnimation {
                target: gridDelegateItem
                property: "cardScale"
                from: 1.0
                to: 1.08
                duration: 120
                easing.type: Easing.OutBack
            }
            NumberAnimation {
                target: gridDelegateItem
                property: "cardScale"
                from: 1.08
                to: 1.0
                duration: 170
                easing.type: Easing.OutQuad
            }
        }

        Drag.active: cardMouseArea.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.keys: ["xyla/media-asset", "text/uri-list"]
        Drag.source: gridDelegateItem
        Drag.mimeData: {
            "xyla/media-asset": model.id || "",
            "text/uri-list": model.path ? (model.path.startsWith("file://") ? model.path : "file://" + model.path) : ""
        }
        // FIX: Drag image
        Drag.imageSource: model.isFolder ? "qrc:/assets/icons/folder.svg" : (model.path ? ("image://thumbnails/" + model.path + "?width=120") : "qrc:/assets/icons/crop-landscape.svg")
        Drag.hotSpot.x: 20
        Drag.hotSpot.y: 20

        // Folder drop target in Grid
        DropArea {
            id: gridDropOnFolder
            anchors.fill: parent
            anchors.margins: 10
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
                    // root.clearSelection();
                    root.draggedAssetIds = [];
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: gridDropOnFolder.containsDrag ? "#233554" : (panelRoot.isSelected(index) ? "#1c2538" : (cardMouseArea.containsMouse ? "#222225" : panelRoot.bgCard))
            border.color: gridDropOnFolder.containsDrag ? "#4d88e8" : (panelRoot.isSelected(index) ? "#2555D3" : (cardMouseArea.containsMouse ? "#3a3a3d" : "#28282a"))
            border.width: 1 // (panelRoot.isSelected(index) || gridDropOnFolder.containsDrag) ? 1.5 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 7
                // spacing: 8
                spacing: panelRoot.editingItemId === model.id ? 6 : 8

                Rectangle {
                    id: thumbFrame
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: "#121213"

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                        maskSource: ShaderEffectSource {
                            sourceItem: Rectangle {
                                width: thumbFrame.width
                                height: thumbFrame.height
                                radius: thumbFrame.radius
                            }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        visible: !model.isFolder
                        fillMode: Image.PreserveAspectCrop
                        source: model.path ? "image://thumbnails/" + model.path + "?width=1000" /* + Math.round(panelRoot.gridCellSize * 1.5) */ : ""
                        asynchronous: true
                    }

                    ////////////////////////////////////////////////////////////////////////////////////////////

                    Item {
                        id: folderContents
                        anchors.fill: parent
                        visible: model.isFolder

                        // Helper property to fetch current folder contents dynamically
                        readonly property var folderItems: (model.isFolder && model.id !== undefined) ? getFolderContents(model.id, false) : []
                        readonly property int itemCount: folderItems.length

                        // Custom SVG Path for folder items (Update this source string to your local SVG path)
                        readonly property string folderSvgSrc: "qrc:/icons/folder.svg"

                        // ========================================================
                        // FOLDER COVER GEOMETRY
                        // ========================================================
                        property real folderStartY: 46
                        property real folderBottom: 8
                        property real folderRightY: 58
                        property real folderRightCurveX: 6
                        property real folderRightCurveY: 52
                        property real folderTabEnd: 0.62
                        property real folderTabStart: 0.48
                        property real folderCurve1: 0.58
                        property real folderCurve2: 0.56
                        property real folderTabY: 40
                        property real folderTabLeft: 8

                        // ========================================================
                        // BUBBLE DOTS (MINIMUM Z-INDEX)
                        // ========================================================
                        // 1. LARGER BUBBLE DOT (RIGHT)
                        Rectangle {
                            z: -1
                            x: parent.width * 0.82
                            y: parent.height * 0.32
                            width: 4
                            height: 4
                            radius: 2
                            color: "#444444"
                        }

                        // 2. SMALL ACCENT BUBBLE DOT (CENTER-LEFT)
                        Rectangle {
                            z: -1
                            x: parent.width * 0.14
                            y: parent.height * 0.24
                            width: 6
                            height: 6
                            radius: 3
                            color: "#3a3a3a"
                        }

                        // ========================================================
                        // 0 ITEMS: DEFAULT EMPTY ARTWORK
                        // ========================================================
                        Item {
                            id: emptyFolderArtifact
                            visible: folderContents.itemCount === 0
                            width: parent.width
                            height: parent.height
                            y: -5

                            // PHOTO ITEM CARD
                            Rectangle {
                                id: photoCard
                                z: 1
                                x: parent.width * 0.30
                                y: parent.height * 0.14
                                width: parent.width * 0.23
                                height: width * 1.12
                                opacity: 0.3
                                radius: 7
                                rotation: -6

                                color: "#28282b"
                                border.width: 1
                                border.color: "#48484c"

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: 5
                                    color: "#1e1e20"

                                    Canvas {
                                        anchors.fill: parent
                                        anchors.margins: 4

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);

                                            ctx.fillStyle = "#6e6e73";
                                            ctx.beginPath();
                                            ctx.arc(width * 0.65, height * 0.30, 3, 0, 2 * Math.PI);
                                            ctx.fill();

                                            ctx.fillStyle = "#55555a";
                                            ctx.beginPath();
                                            ctx.moveTo(0, height);
                                            ctx.lineTo(width * 0.38, height * 0.45);
                                            ctx.lineTo(width * 0.60, height * 0.70);
                                            ctx.lineTo(width * 0.80, height * 0.52);
                                            ctx.lineTo(width, height);
                                            ctx.closePath();
                                            ctx.fill();
                                        }
                                    }
                                }
                            }

                            // VIDEO PALETTE CARD
                            Rectangle {
                                id: videoCard
                                z: 2
                                x: parent.width * 0.54
                                y: parent.height * 0.20
                                width: parent.width * 0.21
                                height: width * 1.12
                                opacity: 0.3
                                radius: 7
                                rotation: 10

                                color: "#252528"
                                border.width: 1
                                border.color: "#424246"

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: 5
                                    color: "#1a1a1c"

                                    Canvas {
                                        anchors.centerIn: parent
                                        width: 12
                                        height: 12

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);

                                            ctx.fillStyle = "#68686d";
                                            ctx.beginPath();
                                            ctx.moveTo(3, 1);
                                            ctx.lineTo(11, 6);
                                            ctx.lineTo(3, 11);
                                            ctx.closePath();
                                            ctx.fill();
                                        }
                                    }
                                }
                            }

                            // DASHED CARD PLACEHOLDER
                            Canvas {
                                id: dashedCard
                                z: 5
                                x: parent.width * 0.10
                                y: parent.height * 0.16
                                width: parent.width * 0.24
                                height: width * 1.15
                                rotation: -14

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    ctx.save();
                                    ctx.beginPath();

                                    var r = 6;
                                    var w = width - 2;
                                    var h = height - 2;

                                    ctx.moveTo(r + 1, 1);
                                    ctx.arcTo(w + 1, 1, w + 1, h + 1, r);
                                    ctx.arcTo(w + 1, h + 1, 1, h + 1, r);
                                    ctx.arcTo(1, h + 1, 1, 1, r);
                                    ctx.arcTo(1, 1, w + 1, 1, r);

                                    ctx.strokeStyle = "#ffffff";
                                    ctx.globalAlpha = 0.25;
                                    ctx.lineWidth = 1.2;
                                    ctx.setLineDash([4, 4]);

                                    ctx.stroke();
                                    ctx.restore();
                                }
                            }

                            // MATCHED LOOP TRAIL & AIRPLANE
                            Canvas {
                                id: planeTrail
                                z: 3
                                x: parent.width * 0.62
                                y: parent.height * 0.24
                                width: parent.width * 0.26
                                height: parent.height * 0.38

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    ctx.save();
                                    ctx.beginPath();

                                    ctx.moveTo(width * 0.02, height * 0.52);
                                    ctx.bezierCurveTo(width * 0.38, height * 1.05, width * 0.58, height * 0.85, width * 0.35, height * 0.65);
                                    ctx.bezierCurveTo(width * 0.12, height * 0.45, width * 0.28, height * 0.25, width * 0.88, height * 0.10);

                                    ctx.strokeStyle = "#ffffff";
                                    ctx.globalAlpha = 0.25;
                                    ctx.lineWidth = 1.2;
                                    ctx.setLineDash([3, 3]);

                                    ctx.stroke();
                                    ctx.restore();
                                }
                            }

                            Canvas {
                                id: paperPlane
                                z: 4
                                x: parent.width * 0.82
                                y: parent.height * 0.21
                                width: 17
                                height: 17
                                rotation: 40

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    ctx.fillStyle = "#6e6e75";
                                    ctx.beginPath();
                                    ctx.moveTo(0, height * 0.5);
                                    ctx.lineTo(width, 0);
                                    ctx.lineTo(width * 0.65, height);
                                    ctx.lineTo(width * 0.42, height * 0.62);
                                    ctx.closePath();
                                    ctx.fill();

                                    ctx.fillStyle = "#4a4a50";
                                    ctx.beginPath();
                                    ctx.moveTo(width * 0.42, height * 0.62);
                                    ctx.lineTo(width, 0);
                                    ctx.lineTo(width * 0.65, height);
                                    ctx.closePath();
                                    ctx.fill();
                                }
                            }
                        }

                        // ========================================================
                        // 1-3+ ITEMS: DYNAMIC REAL MEDIA
                        // ========================================================
                        Item {
                            id: dynamicFolderArtifacts
                            visible: folderContents.itemCount > 0
                            width: parent.width
                            height: parent.height
                            y: -5

                            // DASHED CARD PLACEHOLDER (LEFT)
                            Canvas {
                                id: dynamicDashedCard
                                z: 1
                                x: parent.width * 0.10
                                y: parent.height * 0.16
                                visible: folderContents.itemCount > 3
                                width: parent.width * 0.24
                                height: width * 1.15
                                rotation: -14

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);

                                    ctx.save();
                                    ctx.beginPath();

                                    var r = 6;
                                    var w = width - 2;
                                    var h = height - 2;

                                    ctx.moveTo(r + 1, 1);
                                    ctx.arcTo(w + 1, 1, w + 1, h + 1, r);
                                    ctx.arcTo(w + 1, h + 1, 1, h + 1, r);
                                    ctx.arcTo(1, h + 1, 1, 1, r);
                                    ctx.arcTo(1, 1, w + 1, 1, r);

                                    ctx.strokeStyle = "#ffffff";
                                    ctx.globalAlpha = 0.25;
                                    ctx.lineWidth = 1.2;
                                    ctx.setLineDash([4, 4]);

                                    ctx.stroke();
                                    ctx.restore();
                                }
                            }

                            // THUMBNAIL PALETTE CARDS
                            Repeater {
                                model: Math.min(folderContents.itemCount, 3)

                                delegate: Rectangle {
                                    id: itemCard
                                    z: index + 5

                                    readonly property var currentItem: folderContents.folderItems[index]
                                    readonly property bool isSubFolder: currentItem && currentItem.isFolder === true

                                    x: parent.width * (0.30 + (index * 0.16))
                                    y: parent.height * (0.14 + (index * 0.04))
                                    width: parent.width * 0.23
                                    height: width * 1.12
                                    radius: 7
                                    rotation: index === 0 ? -6 : (index === 1 ? 10 : 2)

                                    color: index % 2 === 0 ? "#28282b" : "#252528"
                                    border.width: 1
                                    border.color: index % 2 === 0 ? "#48484c" : "#424246"

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        radius: 5
                                        color: "#1e1e20"
                                        clip: true

                                        // Standard Media Thumbnail
                                        Image {
                                            anchors.fill: parent
                                            visible: !itemCard.isSubFolder
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            source: {
                                                if (itemCard.currentItem && itemCard.currentItem.path) {
                                                    return "image://thumbnails/" + itemCard.currentItem.path + "?width=" + Math.round(panelRoot.gridCellSize * 1.5);
                                                }
                                                return "";
                                            }
                                        }

                                        // IF ELEMENT IS A FOLDER (.isFolder == true) -> RENDER FOLDER SVG
                                        Canvas {
                                            anchors.centerIn: parent
                                            width: 14
                                            height: 12
                                            visible: itemCard.isSubFolder

                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.clearRect(0, 0, width, height);

                                                ctx.save();
                                                ctx.strokeStyle = "#8a8a90";
                                                ctx.lineWidth = 1.2;
                                                ctx.lineJoin = "round";
                                                ctx.lineCap = "round";

                                                var r = 1.5;
                                                var w = width - 1;
                                                var h = height - 1;

                                                // Outlined folder path with top tab
                                                ctx.beginPath();
                                                ctx.moveTo(1, 2.5);
                                                ctx.lineTo(4.5, 2.5);
                                                ctx.lineTo(6.5, 4);
                                                ctx.lineTo(w - r, 4);
                                                ctx.arcTo(w, 4, w, 4 + r, r);
                                                ctx.lineTo(w, h - r);
                                                ctx.arcTo(w, h, w - r, h, r);
                                                ctx.lineTo(1 + r, h);
                                                ctx.arcTo(1, h, 1, h - r, r);
                                                ctx.closePath();

                                                ctx.stroke();
                                                ctx.restore();
                                            }
                                        }
                                    }
                                }
                            }

                            // PLUS "+" BADGE FOR >3 ITEMS
                            Rectangle {
                                id: dynamicPlusCard
                                visible: folderContents.itemCount > 3
                                z: 10
                                x: parent.width * 0.74
                                y: parent.height * 0.16
                                width: parent.width * 0.16
                                height: width // * 1.12
                                radius: 7
                                rotation: 16

                                color: "#28282b"
                                border.width: 1
                                border.color: "#48484c"

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 3
                                    radius: 5
                                    color: "#1e1e20"

                                    Canvas {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10

                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);

                                            ctx.strokeStyle = "#88888d";
                                            ctx.lineWidth = 2;
                                            ctx.lineCap = "round";

                                            ctx.beginPath();
                                            ctx.moveTo(width / 2, 0);
                                            ctx.lineTo(width / 2, height);
                                            ctx.moveTo(0, height / 2);
                                            ctx.lineTo(width, height / 2);
                                            ctx.stroke();
                                        }
                                    }
                                }
                            }
                        }

                        // ========================================================
                        // FOLDER COVER SHAPE
                        // ========================================================
                        Shape {
                            id: folderCover
                            anchors.fill: parent
                            layer.enabled: true
                            layer.samples: 4

                            ShapePath {
                                fillColor: "#2c2c2f"
                                strokeColor: "#3a3a3e"
                                strokeWidth: 1

                                startX: 0
                                startY: folderContents.folderStartY

                                PathLine {
                                    x: 0
                                    y: folderCover.height - folderContents.folderBottom
                                }

                                PathQuad {
                                    x: folderContents.folderTabLeft
                                    y: folderCover.height
                                    controlX: 0
                                    controlY: folderCover.height
                                }

                                PathLine {
                                    x: folderCover.width - folderContents.folderTabLeft
                                    y: folderCover.height
                                }

                                PathQuad {
                                    x: folderCover.width
                                    y: folderCover.height - folderContents.folderBottom
                                    controlX: folderCover.width
                                    controlY: folderCover.height
                                }

                                PathLine {
                                    x: folderCover.width
                                    y: folderContents.folderRightY
                                }

                                PathQuad {
                                    x: folderCover.width - folderContents.folderRightCurveX
                                    y: folderContents.folderRightCurveY
                                    controlX: folderCover.width
                                    controlY: folderContents.folderRightCurveY
                                }

                                PathLine {
                                    x: folderCover.width * folderContents.folderTabEnd
                                    y: folderContents.folderRightCurveY
                                }

                                PathCubic {
                                    x: folderCover.width * folderContents.folderTabStart
                                    y: folderContents.folderTabY

                                    control1X: folderCover.width * folderContents.folderCurve1
                                    control1Y: folderContents.folderRightCurveY

                                    control2X: folderCover.width * folderContents.folderCurve2
                                    control2Y: folderContents.folderTabY
                                }

                                PathLine {
                                    x: folderContents.folderTabLeft
                                    y: folderContents.folderTabY
                                }

                                PathQuad {
                                    x: 0
                                    y: folderContents.folderStartY
                                    controlX: 0
                                    controlY: folderContents.folderTabY
                                }
                            }
                        }

                        // ========================================================
                        // BOTTOM-RIGHT BADGE PALETTE
                        // ========================================================
                        Rectangle {
                            id: countBadge
                            z: 20
                            visible: folderContents.itemCount > 0
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6

                            width: 22
                            height: 22
                            radius: 11

                            color: "#2c2c2f"
                            border.color: "#181818" // "#2c2c2f"
                            border.width: 2

                            Text {
                                anchors.centerIn: parent

                                text: folderContents.itemCount

                                color: "#ffffff"
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }

                    RowLayout {
                        id: badgeRow
                        anchors.right: parent.right
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 4
                        Layout.alignment: Qt.AlignBottom
                        spacing: 3
                        visible: !model.isFolder

                        // 3. Duration Badge
                        Rectangle {
                            id: durationBadge
                            width: durationText.implicitWidth + 8
                            height: 16
                            radius: 6
                            color: "#181818"
                            visible: model.duration !== undefined && model.duration !== ""

                            Text {
                                id: durationText
                                anchors.centerIn: parent
                                text: model.duration || ""
                                color: "#ffffff"
                                font.pixelSize: 9
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // 1. Video Badge: appears whenever media has a video stream
                        Rectangle {
                            id: videoBadge
                            width: 20
                            height: 20
                            radius: 6
                            color: "#181818"
                            visible: Boolean(model.hasVideo)

                            Image {
                                id: videoIcon
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                sourceSize.width: 10
                                sourceSize.height: 10
                                fillMode: Image.PreserveAspectFit
                                source: "qrc:/assets/icons/film.svg"
                            }
                        }

                        // 2. Audio Badge: appears whenever media has an audio stream
                        Rectangle {
                            id: audioBadge
                            width: 20
                            height: 20
                            radius: 6
                            color: "#181818"
                            visible: Boolean(model.hasAudio)

                            Image {
                                id: audioIcon
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                sourceSize.width: 10
                                sourceSize.height: 10
                                fillMode: Image.PreserveAspectFit
                                source: "qrc:/assets/icons/audio.svg"
                            }
                        }
                    }
                }

                Text {
                    id: gridNameText
                    visible: panelRoot.editingItemId !== model.id
                    Layout.bottomMargin: 4
                    Layout.topMargin: 2
                    Layout.fillWidth: true
                    text: model.isFolder ? (model.name || "") : panelRoot.displayName(model.name || "", panelRoot.showExtensions)
                    color: panelRoot.isSelected(index) ? "#ffffff" : "#c4c4c4"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                TextField {
                    id: gridRenameField
                    visible: panelRoot.editingItemId === model.id
                    Layout.fillWidth: true
                    z: 20
                    text: model.name || ""
                    font.pixelSize: 11
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    selectByMouse: true
                    focus: visible
                    background: Rectangle {
                        color: "#121212"
                        radius: 6
                    }

                    property bool isReady: false

                    function grabFocus() {
                        gridRenameField.forceActiveFocus();
                        gridRenameField.selectAll();
                    }

                    onVisibleChanged: {
                        if (visible) {
                            isReady = false;
                            text = model.name || "";
                            grabFocus();
                            gridFocusTimer.restart();
                        } else {
                            isReady = false;
                        }
                    }

                    Timer {
                        id: gridFocusTimer
                        interval: 160
                        repeat: false
                        onTriggered: {
                            if (gridRenameField.visible) {
                                gridRenameField.grabFocus();
                                gridRenameField.isReady = true;
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
                                panelRoot.activeMediaBinModel.renameAsset(index, newName);
                            }
                        } else {
                            panelRoot.editingItemId = "";
                        }
                    }
                }
            }

            // FIX: Pill visibility
            // Top-right tag pill
            Rectangle {
                id: tagBadge

                width: 20
                height: 20

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.rightMargin: 9.5 // -6 for outside of the card

                color: "transparent"
                z: 10

                visible: Boolean(model.tag && model.tag > 0)

                Image {
                    id: badgeIcon
                    anchors.fill: parent
                    source: "qrc:/assets/icons/tag-filled.svg" // Replace with your SVG path

                    // This ensures the crisp rendering of vector SVGs at runtime scale
                    sourceSize: Qt.size(parent.width, parent.height)
                    smooth: true

                    // Use MultiEffect to cleanly tint the SVG solid path
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0 // 1.0 means fully tinted by the color below

                        colorizationColor: model.tagColor // || "transparent"

                        // 2. Enable and configure the path-perfect drop shadow here
                        shadowEnabled: true
                        shadowColor: "#80000000"
                        shadowBlur: 0.3                // Softness of the shadow (0.0 to 1.0 range)
                        shadowHorizontalOffset: 0      // X-offset
                        shadowVerticalOffset: 2        // Y-offset (pushes shadow down)

                        // Animates the SVG color changes smoothly
                        Behavior on colorizationColor {
                            ColorAnimation {
                                duration: 250
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: cardMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: panelRoot.editingItemId === ""
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: globalDummyDragTarget
            drag.threshold: 5

            onPressed: function (mouse) {
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
                if (cardMouseArea.drag.active) {
                    if (!gridDelegateItem.Drag.active) {
                    }
                    panelRoot.isCustomDragging = true;
                    let pt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                    panelRoot.dragGlobalX = pt.x;
                    panelRoot.dragGlobalY = pt.y;
                }
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
                        let targetId = model.id;
                        if (panelRoot.activeMediaBinModel) {
                            panelRoot.activeMediaBinModel.currentBinId = targetId;
                            panelRoot.clearSelection();
                        }
                    } else {
                        if (typeof clipMonitorController !== "undefined" && clipMonitorController) {
                            clipMonitorController.loadAsset(model.id);
                        }
                    }
                }
            }
        }
    }

    MediaPanelEmpty {
        visible: gridView.count === 0
    }
}
