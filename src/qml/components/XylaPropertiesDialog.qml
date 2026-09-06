// import QtQuick
// import QtQuick.Controls
// import QtQuick.Layouts
// import QtQuick.Effects
// 
// Popup {
//     id: root
// 
//     // ============================================================
//     // NEW ASSIGNED DATA PROPERTIES
//     // ============================================================
// 
//     property string assetName: ""
//     property string assetPath: ""
//     property string assetDuration: "-"
//     property string assetResolution: "-"
//     property string assetType: "Media Clip"
//     property bool isFolder: false
// 
//     // Internal fallback bindings to match original logic seamlessly
//     property string fileName: root.assetName
//     property string filePath: root.assetPath
//     property bool isDir: root.isFolder
//     property real fileSize: 0
//     property int itemCount: 0
//     property var lastModified: null
// 
//     // ============================================================
//     // POPUP SETTINGS & FOCUS MANAGEMENT
//     // ============================================================
// 
//     width: 400
//     // Dynamic height calculation: Header (36) + Margins (12) + Preview Height. 
//     // It expands and contracts dynamically based on what content is inside.
//     height: 88 + (previewImage.status === Image.Ready ? Math.min(300, previewImage.paintedHeight) : 300)
// 
//     modal: true
//     dim: true
//     focus: true
//     padding: 0
// 
//     closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
// 
//     onOpened: root.forceActiveFocus()
//     // onOpened: surfaceContentLayout.forceActiveFocus()
// 
//     // Catch the key event at the root popup layer before focus shifts down
//     // Keys.onPressed: (event) => {
//     //     if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
//     //         root.close()
//     //         event.accepted = true
//     //     }
//     // }
// 
//     function openAt(px, py) {
//         root.x = px;
//         root.y = py;
//         root.open();
//     }
// 
//     function openWith(item) {
//         assetName = item.name || item.fileName || "";
//         assetPath = item.path || item.filePath || "";
//         assetDuration = item.duration || "-";
//         assetResolution = item.resolution || "-";
//         isFolder = item.isFolder !== undefined ? item.isFolder : (item.isDir || false);
//         assetType = item.assetType || (isFolder ? "Folder Bin" : "Media Clip");
//         
//         fileSize = item.fileSize || 0;
//         itemCount = item.itemCount || 0;
//         lastModified = item.lastModified || null;
// 
//         open();
//     }
// 
//     function humanSize(bytes) {
//         if (!bytes || bytes <= 0)
//             return "-";
// 
//         if (bytes < 1024)
//             return bytes + " B";
// 
//         if (bytes < 1024 * 1024)
//             return (bytes / 1024).toFixed(1) + " KB";
// 
//         if (bytes < 1024 * 1024 * 1024)
//             return (bytes / (1024 * 1024)).toFixed(1) + " MB";
// 
//         return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
//     }
// 
//     function formatDate(dt) {
//         if (!dt)
//             return "-";
// 
//         return Qt.formatDateTime(dt, "yyyy-MM-dd  HH:mm");
//     }
// 
//     // ============================================================
//     // ANIMATION
//     // ============================================================
// 
//     enter: Transition {
//         NumberAnimation {
//             property: "opacity"
//             from: 0.0
//             to: 1.0
//             duration: 150
//             easing.type: Easing.OutCubic
//         }
// 
//         NumberAnimation {
//             property: "scale"
//             from: 0.95
//             to: 1.0
//             duration: 180
//             easing.type: Easing.OutCubic
//         }
//     }
// 
//     exit: Transition {
//         NumberAnimation {
//             property: "opacity"
//             from: 1.0
//             to: 0.0
//             duration: 120
//             easing.type: Easing.OutCubic
//         }
// 
//         NumberAnimation {
//             property: "scale"
//             from: 1.0
//             to: 0.95
//             duration: 120
//             easing.type: Easing.OutCubic
//         }
//     }
// 
//     // ============================================================
//     // BACKGROUND
//     // ============================================================
// 
//     background: Rectangle {
//         id: surface
// 
//         anchors.fill: parent
//         radius: 12
// 
//         color: "#161616"
// 
//         border.width: 1
//         border.color: "#2d2d2d"
// 
//         layer.enabled: true
//         layer.effect: MultiEffect {
//             shadowEnabled: true
//             shadowColor: "#90000000"
//             shadowBlur: 0.65
//             shadowVerticalOffset: 6
//             shadowHorizontalOffset: 0
//         }
// 
//         // ========================================================
//         // CONTENT
//         // ========================================================
// 
//         ColumnLayout {
//             anchors.fill: parent
// 
//             spacing: 0
// 
//             Keys.onPressed: (event) => {
//                 if (event.key === Qt.Key_Escape) {
//                     root.close()
//                     event.accepted = true
//                 }
//             }
// 
//             // ====================================================
//             // HEADER
//             // ====================================================
// 
//             Item {
//                 Layout.fillWidth: true
//                 Layout.preferredHeight: 36
// 
//                 Text {
//                     anchors.left: parent.left
//                     anchors.leftMargin: 14
// 
//                     anchors.verticalCenter: parent.verticalCenter
// 
//                     text: "Properties"
// 
//                     color: "#fff"
// 
//                     font.pixelSize: 12
//                     // font.weight: Font.DemiBold
//                 }
//             }
// 
//             // ====================================================
//             // BODY
//             // ====================================================
// 
//             ColumnLayout {
//                 Layout.fillWidth: true
//                 Layout.fillHeight: true
// 
//                 Layout.leftMargin: 12
//                 Layout.rightMargin: 12
//                 Layout.topMargin: 0
//                 Layout.bottomMargin: 12
// 
//                 spacing: 8
// 
//                 // =================================================
//                 // PREVIEW
//                 // =================================================
// 
// Item {
//     Layout.fillWidth: true
//     // Automatically wraps to the exact image size, drops to 80 for folders, and caps at 140 max so it fits perfectly in a 200px popup
//     Layout.preferredHeight: previewImage.status === Image.Ready ? Math.min(200, previewImage.paintedHeight) : 200
// 
//     Rectangle {
//         id: previewClip
//         anchors.fill: parent
//         radius: 8
//         color: "#0d0d0d"
//         clip: true
// 
//         // Move Image & overlays down here so text overlays are drawn on top layer
//         Image {
//             id: previewImage
//             anchors.fill: parent
//             source: root.isDir ? "" : (root.filePath ? "image://thumbnails/" + root.filePath + "?width=600" : "")
//             fillMode: Image.PreserveAspectFit
//             asynchronous: true
//             cache: true
//             smooth: true
//             visible: !root.isDir && status === Image.Ready
//             layer.enabled: true
//             layer.smooth: true
//         }
// 
//         Rectangle {
//             anchors.fill: parent
//             visible: !root.isDir && previewImage.status === Image.Ready
//             color: "#000000"
//             opacity: 0.10
//         }
// 
//         Item {
//             anchors.fill: parent
//             visible: root.isDir || previewImage.status !== Image.Ready
//             Rectangle {
//                 anchors.centerIn: parent
//                 width: root.isDir ? 52 : 44
//                 height: root.isDir ? 52 : 44
//                 radius: root.isDir ? 14 : 10
//                 color: root.isDir ? "#282519" : "#202020"
//                 Image {
//                     anchors.centerIn: parent
//                     width: root.isDir ? 28 : 22
//                     height: root.isDir ? 28 : 22
//                     source: root.isDir ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/file.svg"
//                     opacity: root.isDir ? 0.75 : 0.35
//                 }
//             }
//         }
// 
//         Rectangle {
//             id: resolutionOverlay
//             anchors.left: parent.left
//             anchors.bottom: parent.bottom
//             anchors.margins: 8
//             visible: !root.isDir && root.assetResolution !== "" && root.assetResolution !== "-"
//             height: 18
//             width: resText.implicitWidth + 12
//             radius: 6
//             color: "#181818"
//             Text {
//                 id: resText
//                 anchors.centerIn: parent
//                 text: root.assetResolution
//                 color: "#fff"
//                 font.pixelSize: 10
//                 // font.bold: true
//             }
//         }
// 
//         Rectangle {
//             id: durationOverlay
//             anchors.right: parent.right
//             anchors.bottom: parent.bottom
//             anchors.margins: 8
//             visible: !root.isDir && root.assetDuration !== "" && root.assetDuration !== "-"
//             height: 18
//             width: durationText.implicitWidth + 12
//             radius: 6
//             color: "#181818"
//             Text {
//                 id: durationText
//                 anchors.centerIn: parent
//                 text: root.assetDuration
//                 color: "#fff"
//                 font.pixelSize: 10
//                 // font.bold: true
//             }
//         }
// 
//                     }
//                 }
// 
// 
//                 // =================================================
//                 // LOCATION (HIDDEN IF ISFOLDER)
//                 // =================================================
// 
//                 ColumnLayout {
//                     Layout.fillWidth: true
// 
//                     spacing: 3
// 
//                     visible: !root.isDir
// 
//                     // Text {
//                     //     text: "Location"
//                     //
//                     //     color: "#666666"
//                     //
//                     //     font.pixelSize: 9
//                     //     // font.weight: Font.DemiBold
//                     // }
// 
//                     Rectangle {
//                         Layout.fillWidth: true
// 
//                         Layout.preferredHeight: 32
// 
//                         radius: 8
// 
//                         color: "#111111"
// 
//                         // border.width: 1
//                         // border.color: "#292929"
// 
//                         Text {
//                             id: locationText
// 
//                             anchors.left: parent.left
//                             anchors.right: copyButton.left
// 
//                             anchors.leftMargin: 10
//                             anchors.rightMargin: 4
// 
//                             anchors.verticalCenter: parent.verticalCenter
// 
//                             text: root.filePath || "—"
// 
//                             color: "#dddddd"
// 
//                             font.pixelSize: 12
// 
//                             elide: Text.ElideMiddle
// 
//                             wrapMode: Text.NoWrap
//                         }
// 
//                         XylaIconButton {
//                             id: copyButton
// 
//                             anchors.right: parent.right
//                             anchors.rightMargin: 4
// 
//                             anchors.verticalCenter: parent.verticalCenter
// 
//                             width: 24
//                             height: 24
// 
//                             ghost: true
// 
//                             iconSource: "qrc:/assets/icons/copy.svg"
// 
//                             tooltip: "Copy location"
// 
//                             onClicked: {
//                                 if (typeof clipboardManager !== "undefined")
//                                     clipboardManager.setText(root.filePath);
//                             }
//                         }
//                     }
//                 }
// 
//                 // =================================================
//                 // BOTTOM SPACE
//                 // =================================================
// 
//                 Item {
//                     Layout.fillHeight: true
//                 }
//             }
//         }
//     }
// }





import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: root

    // ============================================================
    // PROPERTIES & METADATA BINDINGS
    // ============================================================
    property var meta: ({})

    property string assetName: meta.name || ""
    property string assetPath: meta.path || meta.filePath || ""
    property string assetDuration: meta.duration || (meta.durationSeconds ? formatSeconds(meta.durationSeconds) : "-")
    property string assetResolution: meta.resolution || (meta.width && meta.height ? (meta.width + "x" + meta.height) : "-")
    property bool isFolder: Boolean(meta.isFolder)

    // Center in overlay so it never cuts off
    parent: Overlay.overlay
    anchors.centerIn: parent

    width: 480
    height: Math.min(Overlay.overlay ? Overlay.overlay.height - 40 : 660, 660)

    modal: true
    dim: true
    focus: true
    clip: false
    padding: 12

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onOpened: root.forceActiveFocus()

    // Modified helper function to handle data and coordinates
    function openWith(itemData, callerItem) {
        meta = itemData || {};
        
        if (callerItem && Overlay.overlay) {
            // Map caller's (0,0) position to the overlay coordinate system
            var mappedPoint = callerItem.mapToItem(Overlay.overlay, 0, 0);
            
            // Set x and y directly. 
            // Optional: Offset 'y' by callerItem.height to position it exactly under the caller
            root.x = mappedPoint.x;
            root.y = mappedPoint.y + callerItem.height;
            
            // Boundary safety check: Prevent the popup from bleeding off the right/bottom screen edges
            if (root.x + root.width > Overlay.overlay.width) {
                root.x = Overlay.overlay.width - root.width - 10;
            }
            if (root.y + root.height > Overlay.overlay.height) {
                // If it bleeds off the bottom, position it ABOVE the caller instead
                root.y = mappedPoint.y - root.height;
            }
        }
        
        open();
    }
    // function openWith(itemData) {
    //     meta = itemData || {};
    //     open();
    // }

    function formatSeconds(sec) {
        if (!sec || sec <= 0) return "-";
        var totalSec = Math.floor(sec);
        var ms = Math.floor((sec - totalSec) * 100);
        var m = Math.floor(totalSec / 60);
        var s = totalSec % 60;
        var h = Math.floor(m / 60);
        m = m % 60;

        if (h > 0)
            return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s + "." + (ms < 10 ? "0" : "") + ms;
    }

    function humanSize(bytes) {
        if (!bytes || bytes <= 0) return "-";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB";
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
    }

    function humanBitrate(bps) {
        if (!bps || bps <= 0) return "-";
        if (bps < 1000) return bps + " bps";
        if (bps < 1000000) return (bps / 1000).toFixed(0) + " kb/s";
        return (bps / 1000000).toFixed(2) + " Mb/s";
    }

    // ============================================================
    // ANIMATIONS
    // ============================================================
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 1.0; to: 0.95; duration: 120; easing.type: Easing.OutCubic }
    }

    // ============================================================
    // BACKGROUND (Working Shadow with padding margins)
    // ============================================================
    background: Item {
        Rectangle {
            id: surfaceCard
            anchors.fill: parent
            anchors.margins: 10
            radius: 22
            color: "#161616"
            // border.width: 1
            // border.color: "#282828"

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#c0000000"
                shadowBlur: 0.8
                shadowVerticalOffset: 10
                shadowHorizontalOffset: 0
            }
        }
    }

    contentItem: Item {
        anchors.fill: parent
        anchors.margins: 10

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

// ================= 1. HERO PREVIEW (Full Image Visible + Black Fill + Rounded) =================
            Rectangle {
                id: heroContainer
                Layout.fillWidth: true
                Layout.preferredHeight: root.isFolder ? 90 : 280
                radius: 18
                color: "#000000" // Pure black letterbox / pillarbox fill
                // border.color: "#282828"
                // border.width: 1
                clip: true // Clean rounded clipping for the letterbox canvas

                Image {
                    id: previewImage
                    anchors.fill: parent
                    anchors.margins: 2 // Keeps 1px border crisp around the edges
                    source: root.isFolder ? "" : (root.assetPath ? "image://thumbnails/" + root.assetPath + "?width=1000" : "")
                    // Shows the 100% full image with ZERO cropping
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                    smooth: true
                    visible: !root.isFolder && status === Image.Ready
                }

                // Placeholder for folders or when image is loading
                Item {
                    anchors.fill: parent
                    visible: root.isFolder || previewImage.status !== Image.Ready

                    Rectangle {
                        anchors.centerIn: parent
                        width: 56
                        height: 56
                        radius: 14
                        color: root.isFolder ? "#252115" : "#111111"

                        Image {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            source: root.isFolder ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/file.svg"
                            opacity: root.isFolder ? 0.85 : 0.4
                        }
                    }
                }
            }

            // ================= 2. TITLE & PATH HEADER (Stationary) =================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    // Asset Name Title
                    Text {
                        text: root.assetName || "Untitled Asset"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    // Top-right pill tag
                    Rectangle {
                        height: 20
                        width: topRatedText.implicitWidth
                        radius: 10
                        color: "#0a0a0a"
                        // border.color: "#363636"
                        // border.width: 1

                        Text {
                            id: topRatedText
                            anchors.centerIn: parent
                            text: root.meta.bitDepth ? (root.meta.bitDepth + "-bit") : (root.isFolder ? "Folder" : "Inspected")
                            color: "#fff"
                            font.pixelSize: 11
                            // font.weight: Font.Medium
                        }
                    }
                }

                // Path / Copy Bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 10
                    color: "#0a0a0a"
                    // border.color: "#222222"
                    // border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 6

                        Text {
                            text: root.assetPath || "No path available"
                            color: "#aaaaaa"
                            font.pixelSize: 11
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }

                        XylaIconButton {
                            implicitWidth: 22
                            implicitHeight: 22
                            ghost: true
                            iconSource: "qrc:/assets/icons/copy.svg"
                            tooltip: "Copy path"
                            onClicked: {
                                if (typeof clipboardManager !== "undefined")
                                    clipboardManager.setText(root.assetPath);
                            }
                        }
                    }
                }
            }

            // ================= 3. SCROLLABLE SPECS (STRICTLY VERTICAL SCROLL ONLY) =================
            Flickable {
                id: flickArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Strictly lock to vertical flicking: ZERO horizontal movement
                flickableDirection: Flickable.VerticalFlick
                contentWidth: width
                contentHeight: specCol.implicitHeight + 10
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    active: flickArea.moving || flickArea.flushing
                    policy: ScrollBar.AsNeeded
                }

                ColumnLayout {
                    id: specCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 12

                    // Section Title Helper
                    component SpecHeader: Text {
                        property string textStr
                        text: textStr
                        color: "#888888"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        Layout.topMargin: 2
                    }

                    // Section Card Box Helper
                    component SpecCard: Rectangle {
                        id: card
                        property var items: []
                        Layout.fillWidth: true
                        radius: 12
                        color: "#0a0a0a"
                        // border.color: "#222222"
                        // border.width: 1
                        implicitHeight: cardCol.implicitHeight + 16

                        ColumnLayout {
                            id: cardCol
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2

                            Repeater {
                                model: card.items
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: 24
                                    radius: 6
                                    color: "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10

                                        Text {
                                            text: modelData.label
                                            color: "#777777"
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 130
                                        }

                                        Text {
                                            text: modelData.value ? modelData.value.toString() : "-"
                                            color: "#dddddd"
                                            font.pixelSize: 11
                                            font.family: "Monospace"
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // CONTAINER & TIMING
                    SpecHeader { textStr: "CONTAINER & TIMING" }
                    SpecCard {
                        items: [
                            { label: "Duration",           value: root.assetDuration },
                            { label: "Container Bitrate",  value: root.humanBitrate(root.meta.bitrate) },
                            { label: "File Size",          value: root.humanSize(root.meta.fileSize) },
                            { label: "Container Name",     value: root.meta.formatName || "-" }
                        ]
                    }

                    // VIDEO STREAM
                    SpecHeader {
                        textStr: "VIDEO SPECIFICATIONS"
                        visible: !root.isFolder && Boolean(root.meta.videoCodec)
                    }
                    SpecCard {
                        visible: !root.isFolder && Boolean(root.meta.videoCodec)
                        items: [
                            { label: "Video Codec",     value: (root.meta.videoCodecLong || root.meta.videoCodec || "").toUpperCase() },
                            { label: "Resolution",      value: root.assetResolution },
                            { label: "Frame Rate",      value: root.meta.fps ? (root.meta.fps.toFixed(3) + " fps") : "-" },
                            { label: "Pixel Format",    value: root.meta.pixelFormat || "-" },
                            { label: "Color Space",     value: root.meta.colorSpace || "-" },
                            { label: "Color Primaries", value: root.meta.colorPrimaries || "-" },
                            { label: "Color Transfer",  value: root.meta.colorTransfer || "-" },
                            { label: "Total Frames",    value: root.meta.totalFrames || "-" }
                        ]
                    }

                    // AUDIO STREAM
                    SpecHeader {
                        textStr: "AUDIO SPECIFICATIONS"
                        visible: !root.isFolder && Boolean(root.meta.audioCodec)
                    }
                    SpecCard {
                        visible: !root.isFolder && Boolean(root.meta.audioCodec)
                        items: [
                            { label: "Audio Codec",       value: (root.meta.audioCodec || "").toUpperCase() },
                            { label: "Sample Rate",       value: root.meta.sampleRate ? (root.meta.sampleRate + " Hz") : "-" },
                            { label: "Channels / Layout", value: (root.meta.channels ? (root.meta.channels + " ch") : "") + (root.meta.channelLayout ? (" (" + root.meta.channelLayout + ")") : "") },
                            { label: "Audio Bitrate",     value: root.humanBitrate(root.meta.audioBitrate) }
                        ]
                    }

                    // Item { height: 8 }
                }
            }
        }
    }
}









