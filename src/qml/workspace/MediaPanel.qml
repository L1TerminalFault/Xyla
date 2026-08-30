// import QtQuick
// import QtQuick.Controls
// import QtQuick.Layouts
// import QtQuick.Dialogs
// import QtQuick.Effects
// import Xyla 1.0
// import "../components"
//
// Item {
//     id: panelRoot
//
//     property var activeMediaPool: typeof mediaPool !== "undefined" ? mediaPool : null
//     property var activeMediaBinModel: typeof mediaBinModel !== "undefined" ? mediaBinModel : null
//
//     property var selectedIndices: []
//     property int lastSelectedIndex: -1
//     property int editingIndex: -1
//     property var clipboardAssets: [] // Array of { id: string, isCut: bool }
//     property bool showExtensions: false
//
//     property bool isListView: false
//     property int selectedItemIndex: -1
//     property real gridCellSize: 195
//     property bool hoverScrubEnabled: true
//     property bool showWaveforms: true
//     property bool groupByMediaType: false
//
//     // Drag tracking
//     property var draggedAssetIds: []
//     property bool isCustomDragging: false
//     property real dragGlobalX: 0
//     property real dragGlobalY: 0
//     property string dragPreviewName: ""
//     property string dragPreviewPath: ""
//     property bool dragPreviewIsFolder: false
//     property int dragCount: 1
//
//     readonly property color bgDark: "#141414"
//     readonly property color bgCard: "#1f1f20"
//     readonly property color bgCardHover: "#2a2a2c"
//     readonly property color bgCardSelected: "#232d42"
//     readonly property color textPrimary: "#ffffff"
//     readonly property color textSecondary: "#888888"
//     readonly property color accentColor: "#2555D3"
//     readonly property color borderColor: "#282829"
//
//     function isSelected(index) {
//         return panelRoot.selectedIndices.indexOf(index) !== -1;
//     }
//
//     function clearSelection() {
//         panelRoot.selectedIndices = [];
//         panelRoot.selectedItemIndex = -1;
//         panelRoot.lastSelectedIndex = -1;
//     }
//
//     function selectSingle(index) {
//         panelRoot.selectedIndices = [index];
//         panelRoot.selectedItemIndex = index;
//         panelRoot.lastSelectedIndex = index;
//     }
//
//     function toggleSelect(index) {
//         var arr = panelRoot.selectedIndices.slice();
//         var pos = arr.indexOf(index);
//         if (pos === -1) arr.push(index); else arr.splice(pos, 1);
//         panelRoot.selectedIndices = arr;
//         panelRoot.selectedItemIndex = index;
//         panelRoot.lastSelectedIndex = index;
//     }
//
//     function selectRange(fromIndex, toIndex) {
//         var lo = Math.min(fromIndex, toIndex);
//         var hi = Math.max(fromIndex, toIndex);
//         var arr = [];
//         for (var i = lo; i <= hi; i++) arr.push(i);
//         panelRoot.selectedIndices = arr;
//         panelRoot.selectedItemIndex = toIndex;
//     }
//
//     function getSelectedAssetIds() {
//         var ids = [];
//         if (!panelRoot.activeMediaBinModel) return ids;
//         var indices = panelRoot.selectedIndices.length > 0 
//             ? panelRoot.selectedIndices 
//             : (panelRoot.selectedItemIndex >= 0 ? [panelRoot.selectedItemIndex] : []);
//         for (var i = 0; i < indices.length; i++) {
//             var item = panelRoot.activeMediaBinModel.get(indices[i]);
//             if (item && item.id) ids.push(item.id);
//         }
//         return ids;
//     }
//
//     function displayName(name) {
//         if (panelRoot.showExtensions || !name) return name;
//         var lastDot = name.lastIndexOf(".");
//         return lastDot > 0 ? name.substring(0, lastDot) : name;
//     }
//
//     function applyRubberBandSelection(x1, y1, x2, y2) {
//         if (!panelRoot.activeMediaBinModel) return;
//         var count = panelRoot.isListView ? listView.count : gridView.count;
//         var arr = [];
//
//         if (panelRoot.isListView) {
//             var rowH = 36 + listView.spacing;
//             var cy1 = y1 + listView.contentY, cy2 = y2 + listView.contentY;
//             var firstRow = Math.max(0, Math.floor(cy1 / rowH));
//             var lastRow = Math.min(count - 1, Math.ceil(cy2 / rowH));
//             for (var i = firstRow; i <= lastRow; i++) arr.push(i);
//         } else {
//             var cw = gridView.cellWidth, ch = gridView.cellHeight;
//             var itemsPerRow = Math.max(1, Math.floor(gridView.width / cw));
//             var cy1g = y1 + gridView.contentY, cy2g = y2 + gridView.contentY;
//             var colFirst = Math.max(0, Math.floor(x1 / cw));
//             var colLast = Math.min(itemsPerRow - 1, Math.floor(x2 / cw));
//             var rowFirst = Math.max(0, Math.floor(cy1g / ch));
//             var rowLast = Math.floor(cy2g / ch);
//             for (var r = rowFirst; r <= rowLast; r++) {
//                 for (var c = colFirst; c <= colLast; c++) {
//                     var idx = r * itemsPerRow + c;
//                     if (idx >= 0 && idx < count) arr.push(idx);
//                 }
//             }
//         }
//         panelRoot.selectedIndices = arr;
//         panelRoot.selectedItemIndex = arr.length > 0 ? arr[arr.length - 1] : -1;
//     }
//
//     function buildClipboardFromSelection(isCut) {
//         var arr = [];
//         if (!panelRoot.activeMediaBinModel) return arr;
//         var ids = panelRoot.getSelectedAssetIds();
//         for (var i = 0; i < ids.length; i++) {
//             arr.push({ id: ids[i], isCut: isCut });
//         }
//         return arr;
//     }
//
//     function urlToLocalPath(urlVal) {
//         if (!urlVal) return "";
//         var str = urlVal.toString().trim();
//         if (str.startsWith("//")) return "";
//
//         if (str.startsWith("file://")) {
//             var path = str.replace(/^file:\/\//, "");
//             path = decodeURIComponent(path);
//             if (/^\/[a-zA-Z]:/.test(path))
//                 path = path.substring(1);
//             return path;
//         }
//
//         if (str.startsWith("/") && !str.startsWith("//"))
//             return decodeURIComponent(str);
//         if (/^[a-zA-Z]:[/\\]/.test(str))
//             return decodeURIComponent(str);
//         return "";
//     }
//
//     // Custom File/Folder Dialog
//     XylaFolderDialog {
//         id: folderDialog
//         returnType: "file"
//         selectMultiple: true
//         onFolderSelected: function (path) {
//             if (!panelRoot.activeMediaPool) return;
//             if (path && path.length > 0) {
//                 var currentBin = panelRoot.activeMediaBinModel ? panelRoot.activeMediaBinModel.currentBinId : "root";
//                 panelRoot.activeMediaPool.importFilesAsync([path], currentBin);
//             }
//         }
//     }
//
//     // Context Menu Popup
//     XylaMediaPanelContextMenu {
//         id: contextMenu
//
//         onCutRequested: {
//             panelRoot.clipboardAssets = panelRoot.buildClipboardFromSelection(true);
//         }
//
//         onCopyRequested: {
//             panelRoot.clipboardAssets = panelRoot.buildClipboardFromSelection(false);
//         }
//
//         onPasteRequested: {
//             if (!panelRoot.activeMediaBinModel || panelRoot.clipboardAssets.length === 0)
//                 return;
//
//             var curBin = panelRoot.activeMediaBinModel.currentBinId || "root";
//             var cutIds = [];
//             var copyIds = [];
//
//             for (var i = 0; i < panelRoot.clipboardAssets.length; i++) {
//                 if (panelRoot.clipboardAssets[i].isCut)
//                     cutIds.push(panelRoot.clipboardAssets[i].id);
//                 else
//                     copyIds.push(panelRoot.clipboardAssets[i].id);
//             }
//
//             if (cutIds.length > 0) {
//                 panelRoot.activeMediaBinModel.moveAssetsById(cutIds, curBin);
//                 panelRoot.clipboardAssets = [];
//             }
//
//             if (copyIds.length > 0) {
//                 panelRoot.activeMediaBinModel.duplicateAssetsById(copyIds, curBin);
//             }
//         }
//
//         onOpenRequested: {
//             var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
//             if (panelRoot.activeMediaBinModel && targetIdx >= 0) {
//                 var it = panelRoot.activeMediaBinModel.get(targetIdx);
//                 if (it && it.isFolder) {
//                     panelRoot.activeMediaBinModel.currentBinId = it.id;
//                     panelRoot.clearSelection();
//                 }
//             }
//         }
//
//         onRenameRequested: {
//             var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
//             if (targetIdx >= 0) {
//                 panelRoot.editingIndex = targetIdx;
//             }
//         }
//
//         onDeleteRequested: {
//             if (panelRoot.activeMediaBinModel) {
//                 var ids = panelRoot.getSelectedAssetIds();
//                 if (ids.length > 0) {
//                     panelRoot.activeMediaBinModel.removeAssetsById(ids);
//                     panelRoot.clearSelection();
//                 }
//             }
//         }
//
//         onNewFolderRequested: {
//             if (panelRoot.activeMediaBinModel) {
//                 var newIdx = panelRoot.activeMediaBinModel.createFolder("New Folder");
//                 if (newIdx >= 0) {
//                     panelRoot.selectSingle(newIdx);
//                     panelRoot.editingIndex = newIdx;
//                 }
//             }
//         }
//
//         onSelectAllRequested: {
//             var count = panelRoot.isListView ? listView.count : gridView.count;
//             if (count > 0) {
//                 var arr = [];
//                 for (var i = 0; i < count; i++) arr.push(i);
//                 panelRoot.selectedIndices = arr;
//                 panelRoot.selectedItemIndex = arr[arr.length - 1];
//                 panelRoot.lastSelectedIndex = arr[arr.length - 1];
//             }
//         }
//
//         onPropertiesRequested: {
//             var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
//             if (panelRoot.activeMediaBinModel && targetIdx >= 0) {
//                 var propItem = panelRoot.activeMediaBinModel.get(targetIdx);
//                 if (propItem) {
//                     propDialog.assetName = propItem.name || "Unknown";
//                     propDialog.assetPath = propItem.path || "-";
//                     propDialog.assetDuration = propItem.duration || "-";
//                     propDialog.assetResolution = propItem.resolution || "-";
//                     propDialog.assetType = propItem.isFolder ? "Folder Bin" : "Media Clip";
//                     propDialog.open();
//                 }
//             }
//         }
//     }
//
//     // Properties Dialog
//     Dialog {
//         id: propDialog
//         x: Math.round((parent.width - width) / 2)
//         y: Math.round((parent.height - height) / 2)
//         width: 360
//         modal: true
//         title: "Asset Properties"
//         property string assetName: ""
//         property string assetPath: ""
//         property string assetDuration: ""
//         property string assetResolution: ""
//         property string assetType: ""
//
//         background: Rectangle {
//             color: "#1e1e20"
//             border.color: "#353538"
//             radius: 8
//         }
//
//         contentItem: ColumnLayout {
//             spacing: 6
//             Text {
//                 text: "Name: " + propDialog.assetName
//                 color: "#ffffff"
//                 font.pixelSize: 12
//             }
//             Text {
//                 text: "Type: " + propDialog.assetType
//                 color: "#aaaaaa"
//                 font.pixelSize: 11
//             }
//             Text {
//                 text: "Resolution: " + propDialog.assetResolution
//                 color: "#aaaaaa"
//                 font.pixelSize: 11
//             }
//             Text {
//                 text: "Duration: " + propDialog.assetDuration
//                 color: "#aaaaaa"
//                 font.pixelSize: 11
//             }
//             Text {
//                 text: "Path: " + propDialog.assetPath
//                 color: "#777777"
//                 font.pixelSize: 10
//                 elide: Text.ElideMiddle
//                 Layout.maximumWidth: 320
//             }
//             Button {
//                 Layout.alignment: Qt.AlignRight
//                 text: "Close"
//                 onClicked: propDialog.close()
//             }
//         }
//     }
//
//     // Panel Background
//     Rectangle {
//         anchors.fill: parent
//         color: panelRoot.bgDark
//         z: -1
//     }
//
//     XylaMediaPanelSettingsPopup {
//         id: settingsPopup
//         parent: settingsBtn
//         x: settingsBtn.width - width
//         y: settingsBtn.height + 4
//         isListView: panelRoot.isListView
//         gridCellSize: panelRoot.gridCellSize
//
//         onViewModeChanged: function (isListView) {
//             panelRoot.isListView = isListView;
//         }
//
//         onGridCellSizeChanged: function (size) {
//             if (size !== undefined && !isNaN(size)) {
//                 panelRoot.gridCellSize = size;
//             }
//         }
//
//         onHoverScrubToggled: function (enabled) {
//             panelRoot.hoverScrubEnabled = enabled;
//         }
//
//         onShowWaveformsToggled: function (enabled) {
//             panelRoot.showWaveforms = enabled;
//         }
//
//         onShowExtensionsToggled: function (enabled) {
//             panelRoot.showExtensions = enabled;
//         }
//
//         onGroupByMediaTypeToggled: function (enabled) {
//             panelRoot.groupByMediaType = enabled;
//             if (enabled && panelRoot.activeMediaBinModel) {
//                 panelRoot.activeMediaBinModel.groupByMediaType();
//             }
//         }
//
//         onSortOrderChanged: function (field, ascending) {
//             if (!panelRoot.activeMediaBinModel)
//                 return;
//             var roleIndex = 0;
//             if (field.toLowerCase() === "duration")
//                 roleIndex = 1;
//             else if (field.toLowerCase() === "path" || field.toLowerCase() === "type")
//                 roleIndex = 2;
//             panelRoot.activeMediaBinModel.setSortRole(roleIndex);
//             panelRoot.activeMediaBinModel.setSortAscending(ascending);
//             sortComboBox.currentIndex = roleIndex;
//             sortOrderToggle.isAscending = ascending;
//         }
//     }
//
//     // Drag Follower Miniature
//     Item {
//         id: dragProxy
//         parent: Overlay.overlay
//         visible: panelRoot.isCustomDragging
//         z: 99999
//         width: 110
//         height: 75
//         x: panelRoot.dragGlobalX - width / 2
//         y: panelRoot.dragGlobalY - height / 2
//
//         Rectangle {
//             anchors.fill: parent
//             radius: 8
//             color: "#1c2538"
//             border.color: panelRoot.accentColor
//             border.width: 1.5
//             opacity: 0.92
//
//             layer.enabled: true
//             layer.effect: MultiEffect {
//                 shadowEnabled: true
//                 shadowColor: "#a0000000"
//                 shadowBlur: 0.6
//                 shadowVerticalOffset: 4
//             }
//
//             ColumnLayout {
//                 anchors.fill: parent
//                 anchors.margins: 4
//                 spacing: 2
//
//                 Rectangle {
//                     Layout.fillWidth: true
//                     Layout.fillHeight: true
//                     radius: 4
//                     color: "#111112"
//                     clip: true
//
//                     Image {
//                         anchors.fill: parent
//                         visible: !panelRoot.dragPreviewIsFolder
//                         fillMode: Image.PreserveAspectCrop
//                         source: panelRoot.dragPreviewPath ? "image://thumbnails/" + panelRoot.dragPreviewPath + "?width=100" : ""
//                     }
//
//                     Image {
//                         anchors.centerIn: parent
//                         visible: panelRoot.dragPreviewIsFolder
//                         source: "qrc:/assets/icons/folder.svg"
//                         sourceSize: Qt.size(24, 24)
//                     }
//                 }
//
//                 Text {
//                     Layout.fillWidth: true
//                     text: panelRoot.displayName(panelRoot.dragPreviewName)
//                     color: "#ffffff"
//                     font.pixelSize: 9
//                     font.weight: Font.Medium
//                     elide: Text.ElideRight
//                     horizontalAlignment: Text.AlignHCenter
//                 }
//             }
//
//             Rectangle {
//                 anchors.top: parent.top
//                 anchors.right: parent.right
//                 anchors.margins: -4
//                 width: badgeText.implicitWidth + 8
//                 height: 16
//                 radius: 8
//                 color: panelRoot.accentColor
//                 visible: panelRoot.dragCount > 1
//
//                 Text {
//                     id: badgeText
//                     anchors.centerIn: parent
//                     text: "+" + panelRoot.dragCount
//                     color: "#ffffff"
//                     font.pixelSize: 9
//                     font.weight: Font.Bold
//                 }
//             }
//         }
//     }
//
//     // MAIN MEDIA PANEL CONTAINER
//     ColumnLayout {
//         anchors.fill: parent
//         anchors.margins: 8
//         spacing: 8
//
//         // Header Toolbar
//         RowLayout {
//             id: toolbarRow
//             Layout.fillWidth: true
//             spacing: 6
//
//             // Add button
//             XylaIconButton {
//                 implicitWidth: 30
//                 implicitHeight: 30
//                 iconSource: "qrc:/assets/icons/plus.svg"
//                 primary: true
//                 onClicked: folderDialog.open()
//             }
//
//             // Settings button
//             XylaIconButton {
//                 id: settingsBtn
//                 implicitWidth: 30
//                 implicitHeight: 30
//                 primary: settingsPopup.opened
//                 iconSource: "qrc:/assets/icons/settings.svg"
//                 onClicked: {
//                     if (settingsPopup.opened) {
//                         settingsPopup.close();
//                     } else {
//                         settingsPopup.open();
//                     }
//                 }
//             }
//
//             // Up folder navigation / Bin Title
//             RowLayout {
//                 spacing: 6
//                 visible: panelRoot.activeMediaBinModel && panelRoot.activeMediaBinModel.currentBinId !== "root"
//
//                 XylaIconButton {
//                     implicitWidth: 30
//                     implicitHeight: 30
//                     iconSource: "qrc:/assets/icons/arrow-up.svg"
//                     onClicked: {
//                         if (panelRoot.activeMediaBinModel) {
//                             panelRoot.activeMediaBinModel.goToParentBin();
//                             panelRoot.clearSelection();
//                         }
//                     }
//                 }
//
//                 Text {
//                     text: panelRoot.activeMediaBinModel ? panelRoot.activeMediaBinModel.currentBinName : ""
//                     color: panelRoot.textPrimary
//                     font.pixelSize: 12
//                     font.weight: Font.DemiBold
//                     elide: Text.ElideRight
//                     Layout.fillWidth: true
//                     Layout.maximumWidth: 120
//                 }
//             }
//
//             Item {
//                 Layout.minimumWidth: 10
//                 Layout.fillWidth: true
//             }
//
//             // Sort Select Dropdown
//             XylaSelect {
//                 id: sortComboBox
//                 Layout.preferredWidth: 95
//                 implicitHeight: 30
//                 icon: "qrc:/assets/icons/sort.svg"
//                 activeFocusOnTab: false
//                 model: ["Name", "Duration", "Path"]
//                 onActivated: function (index) {
//                     if (!panelRoot.activeMediaBinModel) return;
//                     panelRoot.activeMediaBinModel.setSortRole(index);
//                 }
//             }
//
//             // Sort Order Toggle
//             XylaIconButton {
//                 id: sortOrderToggle
//                 implicitWidth: 30
//                 implicitHeight: 30
//                 property bool isAscending: true
//                 iconSource: ""
//
//                 onClicked: {
//                     isAscending = !isAscending;
//                     if (panelRoot.activeMediaBinModel) {
//                         panelRoot.activeMediaBinModel.setSortAscending(isAscending);
//                     }
//                 }
//
//                 Image {
//                     id: sortIcon
//                     anchors.centerIn: parent
//                     width: 16
//                     height: 16
//                     source: "qrc:/assets/icons/sort-ascending.svg"
//                     fillMode: Image.PreserveAspectFit
//                     rotation: sortOrderToggle.isAscending ? 0 : 180
//
//                     Behavior on rotation {
//                         NumberAnimation {
//                             duration: 250
//                             easing.type: Easing.OutBack
//                         }
//                     }
//                 }
//             }
//
//             // Segmented Toggle (List / Grid)
//             XylaSegmentedToggle {
//                 id: viewModeToggle
//                 implicitHeight: 30
//                 currentIndex: panelRoot.isListView ? 0 : 1
//                 options: [
//                     { icon: "qrc:/assets/icons/list.svg", value: "list" },
//                     { icon: "qrc:/assets/icons/layout-grid.svg", value: "grid" }
//                 ]
//                 onOptionSelected: (index, value) => {
//                     panelRoot.isListView = (value === "list");
//                 }
//             }
//
//             // Search Toggle Button
//             XylaIconButton {
//                 id: searchBtn
//                 implicitWidth: 30
//                 implicitHeight: 30
//                 iconSource: "qrc:/assets/icons/search.svg"
//                 primary: searchPopup.opened || (searchInput.text !== "")
//
//                 onClicked: {
//                     if (searchPopup.opened) {
//                         searchPopup.close();
//                     } else {
//                         searchPopup.open();
//                     }
//                 }
//
//                 Popup {
//                     id: searchPopup
//                     y: searchBtn.height + 6
//                     x: searchBtn.width - width
//                     width: 220
//                     height: 32
//                     padding: 0
//                     modal: false
//                     focus: true
//                     closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape
//
//                     onOpened: searchInput.forceActiveFocus()
//                     onAboutToHide: searchInput.focus = false
//
//                     background: Rectangle {
//                         color: "#181818"
//                         border.color: searchInput.activeFocus ? panelRoot.accentColor : "#2e2e30"
//                         border.width: 1
//                         radius: 6
//
//                         layer.enabled: true
//                         layer.effect: MultiEffect {
//                             shadowEnabled: true
//                             shadowColor: "#90000000"
//                             shadowBlur: 0.65
//                             shadowVerticalOffset: 4
//                         }
//                     }
//
//                     contentItem: RowLayout {
//                         anchors.fill: parent
//                         anchors.leftMargin: 8
//                         anchors.rightMargin: 8
//                         spacing: 4
//
//                         TextField {
//                             id: searchInput
//                             Layout.fillWidth: true
//                             Layout.fillHeight: true
//                             placeholderText: "Search bin..."
//                             placeholderTextColor: "#606060"
//                             color: "#ffffff"
//                             font.pixelSize: 11
//                             background: Item {}
//                             selectByMouse: true
//
//                             onTextChanged: {
//                                 if (panelRoot.activeMediaBinModel) {
//                                     panelRoot.activeMediaBinModel.searchFilter = text;
//                                 }
//                             }
//
//                             Keys.onEscapePressed: {
//                                 text = "";
//                                 if (panelRoot.activeMediaBinModel) {
//                                     panelRoot.activeMediaBinModel.searchFilter = "";
//                                 }
//                                 searchPopup.close();
//                             }
//
//                             Keys.onReturnPressed: (event) => {
//                                 searchPopup.close();
//                                 event.accepted = true;
//                             }
//                         }
//
//                         Text {
//                             text: "✕"
//                             color: "#777777"
//                             font.pixelSize: 11
//                             visible: searchInput.text.length > 0
//                             MouseArea {
//                                 anchors.fill: parent
//                                 cursorShape: Qt.PointingHandCursor
//                                 onClicked: searchInput.text = ""
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//
//         // Drop Area & Media Container
//         Item {
//             Layout.fillWidth: true
//             Layout.fillHeight: true
//
//             DropArea {
//                 id: dropArea
//                 anchors.fill: parent
//
//                 onEntered: function (drag) {
//                     if (drag.source !== null) {
//                         drag.accepted = false;
//                         return;
//                     }
//                     drag.acceptProposedAction();
//                 }
//
//                 onDropped: function (drop) {
//                     if (drop.source !== null) return;
//                     drop.acceptProposedAction();
//
//                     if (!drop.hasUrls || drop.urls.length === 0 || !panelRoot.activeMediaPool)
//                         return;
//
//                     var rawPaths = [];
//                     for (var i = 0; i < drop.urls.length; i++) {
//                         var localPath = panelRoot.urlToLocalPath(drop.urls[i]);
//                         if (localPath.length > 0)
//                             rawPaths.push(localPath);
//                     }
//
//                     if (rawPaths.length === 0) return;
//
//                     var currentBin = panelRoot.activeMediaBinModel ? panelRoot.activeMediaBinModel.currentBinId : "root";
//                     panelRoot.activeMediaPool.importFilesAsync(rawPaths, currentBin);
//                 }
//
//                 MouseArea {
//                     id: rubberBandArea
//                     anchors.fill: parent
//                     acceptedButtons: Qt.LeftButton
//                     z: -1
//                     property real startX: 0
//                     property real startY: 0
//                     property bool selecting: false
//
//                     onPressed: function (mouse) {
//                         startX = mouse.x;
//                         startY = mouse.y;
//                         selecting = false;
//                         if (!(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))) {
//                             panelRoot.clearSelection();
//                             panelRoot.editingIndex = -1;
//                         }
//                     }
//
//                     onPositionChanged: function (mouse) {
//                         if (!selecting && (Math.abs(mouse.x - startX) > 4 || Math.abs(mouse.y - startY) > 4)) {
//                             selecting = true;
//                         }
//                         if (selecting) {
//                             var x1 = Math.min(startX, mouse.x), x2 = Math.max(startX, mouse.x);
//                             var y1 = Math.min(startY, mouse.y), y2 = Math.max(startY, mouse.y);
//                             selectionRect.x = x1; selectionRect.y = y1;
//                             selectionRect.width = x2 - x1; selectionRect.height = y2 - y1;
//                             panelRoot.applyRubberBandSelection(x1, y1, x2, y2);
//                         }
//                     }
//
//                     onReleased: function (mouse) {
//                         selecting = false;
//                         selectionRect.width = 0;
//                         selectionRect.height = 0;
//                     }
//                 }
//
//                 Rectangle {
//                     id: selectionRect
//                     color: "#2a2555D3"
//                     border.color: panelRoot.accentColor
//                     border.width: 1
//                     visible: rubberBandArea.selecting && (width > 2 || height > 2)
//                     z: 20
//                 }
//
//                 Rectangle {
//                     anchors.fill: parent
//                     color: (dropArea.containsDrag && dropArea.drag.source === null) ? "#152555D3" : "transparent"
//                     border.color: (dropArea.containsDrag && dropArea.drag.source === null) ? panelRoot.accentColor : "transparent"
//                     border.width: 1.5
//                     radius: 6
//                     z: 10
//                 }
//
//                 // Stack View: List vs Grid
//                 StackLayout {
//                     anchors.fill: parent
//                     currentIndex: panelRoot.isListView ? 0 : 1
//
//                     // --- Search popup top margin animation ---
//                     anchors.topMargin: searchPopup.visible ? 20 : 0
//
//                     Behavior on anchors.topMargin {
//                         NumberAnimation {
//                             duration: 180
//                             easing.type: Easing.OutCubic
//                         }
//                     }
//
//                     // LIST VIEW
//                     ListView {
//                         id: listView
//                         clip: true
//                         spacing: 4
//                         model: panelRoot.activeMediaBinModel
//
//                         TapHandler {
//                             acceptedButtons: Qt.LeftButton | Qt.RightButton
//                             onTapped: function (eventPoint, button) {
//                                 panelRoot.clearSelection();
//                                 panelRoot.editingIndex = -1;
//                                 if (button === Qt.RightButton) {
//                                     var pt = mapToItem(Overlay.overlay, eventPoint.position.x, eventPoint.position.y);
//                                     contextMenu.hasSelection = false;
//                                     contextMenu.selectionCount = 0;
//                                     contextMenu.selectionIsFolder = false;
//                                     contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
//                                     contextMenu.openAt(pt.x, pt.y);
//                                 }
//                             }
//                         }
//
//                         delegate: Rectangle {
//                             id: listDelegateItem
//                             property int itemIndex: index
//                             width: listView.width
//                             height: 36
//                             radius: 6
//                             color: listDropOnFolder.containsDrag ? "#233554" : (panelRoot.isSelected(index) ? panelRoot.bgCardSelected : (itemMouseArea.containsMouse ? panelRoot.bgCardHover : panelRoot.bgCard))
//                             border.color: listDropOnFolder.containsDrag ? "#4d88e8" : (panelRoot.isSelected(index) ? panelRoot.accentColor : panelRoot.borderColor)
//                             border.width: listDropOnFolder.containsDrag ? 1.5 : 1
//
//                             Drag.active: itemMouseArea.drag.active
//                             Drag.dragType: Drag.Automatic
//                             Drag.keys: ["xyla/media-asset", "text/uri-list"]
//                             Drag.source: listDelegateItem
//                             Drag.mimeData: {
//                                 "text/uri-list": model.path ? (model.path.startsWith("file://") ? model.path : "file://" + model.path) : ""
//                             }
//                             Drag.imageSource: model.isFolder ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/crop-landscape.svg"
//                             Drag.hotSpot.x: 20
//                             Drag.hotSpot.y: 20
//                             Drag.supportedActions: Qt.MoveAction | Qt.CopyAction
//
//                             // Folder drop target in List
//                             DropArea {
//                                 id: listDropOnFolder
//                                 anchors.fill: parent
//                                 enabled: model.isFolder
//                                 keys: ["xyla/media-asset", "text/uri-list"]
//
//                                 onEntered: function (drag) {
//                                     if (panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
//                                         drag.accepted = false;
//                                         return;
//                                     }
//                                     drag.acceptProposedAction();
//                                 }
//
//                                 onDropped: function (drop) {
//                                     if (panelRoot.draggedAssetIds.indexOf(model.id) !== -1) return;
//                                     drop.acceptProposedAction();
//                                     var targetFolderId = model.id;
//                                     if (panelRoot.draggedAssetIds.length > 0 && panelRoot.activeMediaBinModel) {
//                                         panelRoot.activeMediaBinModel.moveAssetsById(panelRoot.draggedAssetIds, targetFolderId);
//                                         panelRoot.clearSelection();
//                                         panelRoot.draggedAssetIds = [];
//                                     }
//                                 }
//                             }
//
//                             RowLayout {
//                                 anchors.fill: parent
//                                 anchors.leftMargin: 10
//                                 anchors.rightMargin: 10
//                                 spacing: 10
//                                 z: 1
//
//                                 Image {
//                                     source: model.isFolder ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/crop-landscape.svg"
//                                     sourceSize.width: 16
//                                     sourceSize.height: 16
//                                 }
//
//                                 Text {
//                                     id: nameText
//                                     visible: panelRoot.editingIndex !== index
//                                     text: model.isFolder ? (model.name || "") : panelRoot.displayName(model.name || "")
//                                     color: panelRoot.textPrimary
//                                     font.pixelSize: 12
//                                     font.weight: panelRoot.isSelected(index) ? Font.DemiBold : Font.Normal
//                                     elide: Text.ElideRight
//                                     Layout.fillWidth: true
//                                 }
//
//                                 TextField {
//                                     id: renameField
//                                     visible: panelRoot.editingIndex === index
//                                     Layout.fillWidth: true
//                                     z: 20
//                                     text: model.name || ""
//                                     font.pixelSize: 12
//                                     color: "#ffffff"
//                                     selectByMouse: true
//                                     focus: visible
//                                     background: Rectangle {
//                                         color: "#121212"
//                                         border.color: panelRoot.accentColor
//                                         border.width: 1.5
//                                         radius: 4
//                                     }
//
//                                     property bool isReady: false
//
//                                     function grabFocus() {
//                                         renameField.forceActiveFocus();
//                                         renameField.selectAll();
//                                     }
//
//                                     onVisibleChanged: {
//                                         if (visible) {
//                                             isReady = false;
//                                             text = model.name || "";
//                                             grabFocus();
//                                             listFocusTimer.restart();
//                                         } else {
//                                             isReady = false;
//                                         }
//                                     }
//
//                                     Timer {
//                                         id: listFocusTimer
//                                         interval: 160
//                                         repeat: false
//                                         onTriggered: {
//                                             if (renameField.visible) {
//                                                 renameField.grabFocus();
//                                                 renameField.isReady = true;
//                                             }
//                                         }
//                                     }
//
//                                     onActiveFocusChanged: {
//                                         if (!activeFocus && isReady && visible) {
//                                             commitRename();
//                                         }
//                                     }
//
//                                     Keys.onReturnPressed: commitRename()
//                                     Keys.onEnterPressed: commitRename()
//                                     Keys.onEscapePressed: panelRoot.editingIndex = -1
//
//                                     function commitRename() {
//                                         if (panelRoot.editingIndex === index && panelRoot.activeMediaBinModel) {
//                                             var newName = text.trim();
//                                             panelRoot.editingIndex = -1;
//                                             if (newName !== "" && newName !== model.name) {
//                                                 panelRoot.activeMediaBinModel.renameAsset(index, newName);
//                                             }
//                                         } else {
//                                             panelRoot.editingIndex = -1;
//                                         }
//                                     }
//                                 }
//
//                                 Text {
//                                     text: model.resolution || ""
//                                     color: "#777777"
//                                     font.pixelSize: 10
//                                     visible: !model.isFolder && panelRoot.editingIndex !== index
//                                 }
//
//                                 Text {
//                                     text: model.duration || ""
//                                     color: "#aaaaaa"
//                                     font.pixelSize: 11
//                                     visible: !model.isFolder && panelRoot.editingIndex !== index
//                                 }
//                             }
//
//                             MouseArea {
//                                 id: itemMouseArea
//                                 anchors.fill: parent
//                                 hoverEnabled: true
//                                 enabled: panelRoot.editingIndex !== index
//                                 acceptedButtons: Qt.LeftButton | Qt.RightButton
//                                 drag.target: listDummyDragTarget
//
//                                 Item {
//                                     id: listDummyDragTarget
//                                 }
//
//                                 onPressed: function (mouse) {
//                                     if (mouse.button === Qt.LeftButton) {
//                                         if (mouse.modifiers & Qt.ShiftModifier && panelRoot.lastSelectedIndex >= 0) {
//                                             panelRoot.selectRange(panelRoot.lastSelectedIndex, index);
//                                         } else if (mouse.modifiers & Qt.ControlModifier) {
//                                             panelRoot.toggleSelect(index);
//                                         } else if (!panelRoot.isSelected(index)) {
//                                             panelRoot.selectSingle(index);
//                                         }
//                                         panelRoot.draggedAssetIds = panelRoot.getSelectedAssetIds();
//                                     }
//                                 }
//
//                                 onPositionChanged: function (mouse) {
//                                     if (drag.active) {
//                                         panelRoot.isCustomDragging = true;
//                                         var pt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
//                                         panelRoot.dragGlobalX = pt.x;
//                                         panelRoot.dragGlobalY = pt.y;
//                                         panelRoot.dragPreviewName = model.name || "";
//                                         panelRoot.dragPreviewPath = model.path || "";
//                                         panelRoot.dragPreviewIsFolder = model.isFolder;
//                                         panelRoot.dragCount = Math.max(1, panelRoot.selectedIndices.length);
//                                     }
//                                 }
//
//                                 onReleased: function (mouse) {
//                                     panelRoot.isCustomDragging = false;
//                                 }
//
//                                 onClicked: function (mouse) {
//                                     if (mouse.button === Qt.RightButton) {
//                                         if (!panelRoot.isSelected(index)) {
//                                             panelRoot.selectSingle(index);
//                                         }
//                                         var globalPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
//                                         contextMenu.hasSelection = true;
//                                         contextMenu.selectionCount = Math.max(1, panelRoot.selectedIndices.length);
//                                         contextMenu.selectionIsFolder = (contextMenu.selectionCount === 1 && model.isFolder);
//                                         contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
//                                         contextMenu.openAt(globalPoint.x, globalPoint.y);
//                                     }
//                                 }
//
//                                 onDoubleClicked: function (mouse) {
//                                     if (mouse.button === Qt.LeftButton && model.isFolder) {
//                                         var targetId = model.id;
//                                         if (panelRoot.activeMediaBinModel) {
//                                             panelRoot.activeMediaBinModel.currentBinId = targetId;
//                                             panelRoot.clearSelection();
//                                         }
//                                     }
//                                 }
//                             }
//                         }
//
//                         Text {
//                             anchors.centerIn: parent
//                             text: "No Media Assets Loaded\n(Drag & Drop files here or right-click to import)"
//                             horizontalAlignment: Text.AlignHCenter
//                             color: "#505050"
//                             font.pixelSize: 12
//                             visible: listView.count === 0
//                         }
//                     }
//
//                     // GRID VIEW
//                     GridView {
//                         id: gridView
//                         clip: true
//                         cellWidth: panelRoot.gridCellSize
//                         cellHeight: panelRoot.gridCellSize * 0.90
//                         model: panelRoot.activeMediaBinModel
//
//                         TapHandler {
//                             acceptedButtons: Qt.LeftButton | Qt.RightButton
//                             onTapped: function (eventPoint, button) {
//                                 panelRoot.clearSelection();
//                                 panelRoot.editingIndex = -1;
//                                 if (button === Qt.RightButton) {
//                                     var pt = mapToItem(Overlay.overlay, eventPoint.position.x, eventPoint.position.y);
//                                     contextMenu.hasSelection = false;
//                                     contextMenu.selectionCount = 0;
//                                     contextMenu.selectionIsFolder = false;
//                                     contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
//                                     contextMenu.openAt(pt.x, pt.y);
//                                 }
//                             }
//                         }
//
//                         delegate: Item {
//                             id: gridDelegateItem
//                             property int itemIndex: index
//                             width: gridView.cellWidth
//                             height: gridView.cellHeight
//
//                             property real cardScale: 1.0
//                             scale: cardScale
//                             transformOrigin: Item.Center
//
//                             Component.onCompleted: entranceAnim.restart()
//
//                             ParallelAnimation {
//                                 id: entranceAnim
//                                 ScriptAction { script: gridDelegateItem.cardScale = 0.0 }
//                                 NumberAnimation {
//                                     target: gridDelegateItem
//                                     property: "cardScale"
//                                     from: 0.8
//                                     to: 1.0
//                                     duration: 180
//                                     easing.type: Easing.OutBack
//                                     easing.overshoot: 1.5
//                                 }
//                             }
//
//                             Drag.active: cardMouseArea.drag.active
//                             Drag.dragType: Drag.Automatic
//                             Drag.keys: ["xyla/media-asset", "text/uri-list"]
//                             Drag.source: gridDelegateItem
//                             Drag.mimeData: {
//                                 "text/uri-list": model.path ? (model.path.startsWith("file://") ? model.path : "file://" + model.path) : ""
//                             }
//                             Drag.imageSource: model.isFolder ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/crop-landscape.svg"
//                             Drag.hotSpot.x: 20
//                             Drag.hotSpot.y: 20
//                             Drag.supportedActions: Qt.MoveAction | Qt.CopyAction
//
//                             // Folder drop target in Grid
//                             DropArea {
//                                 id: gridDropOnFolder
//                                 anchors.fill: parent
//                                 anchors.margins: 10
//                                 enabled: model.isFolder
//                                 keys: ["xyla/media-asset", "text/uri-list"]
//
//                                 onEntered: function (drag) {
//                                     if (panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
//                                         drag.accepted = false;
//                                         return;
//                                     }
//                                     drag.acceptProposedAction();
//                                 }
//
//                                 onDropped: function (drop) {
//                                     if (panelRoot.draggedAssetIds.indexOf(model.id) !== -1) return;
//                                     drop.acceptProposedAction();
//                                     var targetFolderId = model.id;
//                                     if (panelRoot.draggedAssetIds.length > 0 && panelRoot.activeMediaBinModel) {
//                                         panelRoot.activeMediaBinModel.moveAssetsById(panelRoot.draggedAssetIds, targetFolderId);
//                                         panelRoot.clearSelection();
//                                         panelRoot.draggedAssetIds = [];
//                                     }
//                                 }
//                             }
//
//                             Rectangle {
//                                 anchors.fill: parent
//                                 anchors.margins: 10
//                                 radius: 12
//                                 color: gridDropOnFolder.containsDrag ? "#233554" : (panelRoot.isSelected(index) ? "#1c2538" : (cardMouseArea.containsMouse ? "#222225" : panelRoot.bgCard))
//                                 border.color: gridDropOnFolder.containsDrag ? "#4d88e8" : (panelRoot.isSelected(index) ? "#2555D3" : (cardMouseArea.containsMouse ? "#3a3a3d" : "#28282a"))
//                                 border.width: (panelRoot.isSelected(index) || gridDropOnFolder.containsDrag) ? 1.5 : 1
//
//                                 ColumnLayout {
//                                     anchors.fill: parent
//                                     anchors.margins: 7
//                                     spacing: 8
//
//                                     Rectangle {
//                                         id: thumbFrame
//                                         Layout.fillWidth: true
//                                         Layout.fillHeight: true
//                                         radius: 8
//                                         color: "#121213"
//
//                                         layer.enabled: true
//                                         layer.effect: MultiEffect {
//                                             maskEnabled: true
//                                             maskThresholdMin: 0.5
//                                             maskSpreadAtMin: 1.0
//                                             maskSource: ShaderEffectSource {
//                                                 sourceItem: Rectangle {
//                                                     width: thumbFrame.width
//                                                     height: thumbFrame.height
//                                                     radius: thumbFrame.radius
//                                                 }
//                                             }
//                                         }
//
//                                         Image {
//                                             anchors.fill: parent
//                                             visible: !model.isFolder
//                                             fillMode: Image.PreserveAspectCrop
//                                             source: model.path ? "image://thumbnails/" + model.path + "?width=" + Math.round(panelRoot.gridCellSize * 1.5) : ""
//                                             asynchronous: true
//                                         }
//
//                                         Image {
//                                             anchors.centerIn: parent
//                                             visible: model.isFolder
//                                             source: "qrc:/assets/icons/folder.svg"
//                                             sourceSize.width: Math.max(22, Math.min(46, panelRoot.gridCellSize * 0.3))
//                                             sourceSize.height: Math.max(22, Math.min(46, panelRoot.gridCellSize * 0.3))
//                                         }
//
//                                         Rectangle {
//                                             anchors.right: parent.right
//                                             anchors.bottom: parent.bottom
//                                             anchors.margins: 4
//                                             width: durationText.implicitWidth + 8
//                                             height: 16
//                                             radius: 4
//                                             color: "#e60d0d0e"
//                                             visible: !model.isFolder && model.duration !== undefined && model.duration !== ""
//
//                                             Text {
//                                                 id: durationText
//                                                 anchors.centerIn: parent
//                                                 text: model.duration || ""
//                                                 color: "#ffffff"
//                                                 font.pixelSize: 9
//                                                 font.weight: Font.DemiBold
//                                             }
//                                         }
//                                     }
//
//                                     Text {
//                                         id: gridNameText
//                                         visible: panelRoot.editingIndex !== index
//                                         Layout.bottomMargin: 2
//                                         Layout.fillWidth: true
//                                         text: model.isFolder ? (model.name || "") : panelRoot.displayName(model.name || "")
//                                         color: panelRoot.isSelected(index) ? "#ffffff" : "#c4c4c4"
//                                         font.pixelSize: 11
//                                         elide: Text.ElideRight
//                                         horizontalAlignment: Text.AlignHCenter
//                                     }
//
//                                     TextField {
//                                         id: gridRenameField
//                                         visible: panelRoot.editingIndex === index
//                                         Layout.bottomMargin: 2
//                                         Layout.fillWidth: true
//                                         z: 20
//                                         text: model.name || ""
//                                         font.pixelSize: 11
//                                         color: "#ffffff"
//                                         horizontalAlignment: Text.AlignHCenter
//                                         selectByMouse: true
//                                         focus: visible
//                                         background: Rectangle {
//                                             color: "#121212"
//                                             border.color: panelRoot.accentColor
//                                             border.width: 1.5
//                                             radius: 3
//                                         }
//
//                                         property bool isReady: false
//
//                                         function grabFocus() {
//                                             gridRenameField.forceActiveFocus();
//                                             gridRenameField.selectAll();
//                                         }
//
//                                         onVisibleChanged: {
//                                             if (visible) {
//                                                 isReady = false;
//                                                 text = model.name || "";
//                                                 grabFocus();
//                                                 gridFocusTimer.restart();
//                                             } else {
//                                                 isReady = false;
//                                             }
//                                         }
//
//                                         Timer {
//                                             id: gridFocusTimer
//                                             interval: 160
//                                             repeat: false
//                                             onTriggered: {
//                                                 if (gridRenameField.visible) {
//                                                     gridRenameField.grabFocus();
//                                                     gridRenameField.isReady = true;
//                                                 }
//                                             }
//                                         }
//
//                                         onActiveFocusChanged: {
//                                             if (!activeFocus && isReady && visible) {
//                                                 commitRename();
//                                             }
//                                         }
//
//                                         Keys.onReturnPressed: commitRename()
//                                         Keys.onEnterPressed: commitRename()
//                                         Keys.onEscapePressed: panelRoot.editingIndex = -1
//
//                                         function commitRename() {
//                                             if (panelRoot.editingIndex === index && panelRoot.activeMediaBinModel) {
//                                                 var newName = text.trim();
//                                                 panelRoot.editingIndex = -1;
//                                                 if (newName !== "" && newName !== model.name) {
//                                                     panelRoot.activeMediaBinModel.renameAsset(index, newName);
//                                                 }
//                                             } else {
//                                                 panelRoot.editingIndex = -1;
//                                             }
//                                         }
//                                     }
//                                 }
//                             }
//
//                             MouseArea {
//                                 id: cardMouseArea
//                                 anchors.fill: parent
//                                 hoverEnabled: true
//                                 enabled: panelRoot.editingIndex !== index
//                                 acceptedButtons: Qt.LeftButton | Qt.RightButton
//                                 drag.target: gridDummyDragTarget
//
//                                 Item {
//                                     id: gridDummyDragTarget
//                                 }
//
//                                 onPressed: function (mouse) {
//                                     if (mouse.button === Qt.LeftButton) {
//                                         if (mouse.modifiers & Qt.ShiftModifier && panelRoot.lastSelectedIndex >= 0) {
//                                             panelRoot.selectRange(panelRoot.lastSelectedIndex, index);
//                                         } else if (mouse.modifiers & Qt.ControlModifier) {
//                                             panelRoot.toggleSelect(index);
//                                         } else if (!panelRoot.isSelected(index)) {
//                                             panelRoot.selectSingle(index);
//                                         }
//                                         panelRoot.draggedAssetIds = panelRoot.getSelectedAssetIds();
//                                     }
//                                 }
//
//                                 onPositionChanged: function (mouse) {
//                                     if (drag.active) {
//                                         panelRoot.isCustomDragging = true;
//                                         var pt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
//                                         panelRoot.dragGlobalX = pt.x;
//                                         panelRoot.dragGlobalY = pt.y;
//                                         panelRoot.dragPreviewName = model.name || "";
//                                         panelRoot.dragPreviewPath = model.path || "";
//                                         panelRoot.dragPreviewIsFolder = model.isFolder;
//                                         panelRoot.dragCount = Math.max(1, panelRoot.selectedIndices.length);
//                                     }
//                                 }
//
//                                 onReleased: function (mouse) {
//                                     panelRoot.isCustomDragging = false;
//                                 }
//
//                                 onClicked: function (mouse) {
//                                     if (mouse.button === Qt.RightButton) {
//                                         if (!panelRoot.isSelected(index)) {
//                                             panelRoot.selectSingle(index);
//                                         }
//                                         var globalPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
//                                         contextMenu.hasSelection = true;
//                                         contextMenu.selectionCount = Math.max(1, panelRoot.selectedIndices.length);
//                                         contextMenu.selectionIsFolder = (contextMenu.selectionCount === 1 && model.isFolder);
//                                         contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
//                                         contextMenu.openAt(globalPoint.x, globalPoint.y);
//                                     }
//                                 }
//
//                                 onDoubleClicked: function (mouse) {
//                                     if (mouse.button === Qt.LeftButton && model.isFolder) {
//                                         var targetId = model.id;
//                                         if (panelRoot.activeMediaBinModel) {
//                                             panelRoot.activeMediaBinModel.currentBinId = targetId;
//                                             panelRoot.clearSelection();
//                                         }
//                                     }
//                                 }
//                             }
//                         }
//
//                         Text {
//                             anchors.centerIn: parent
//                             text: "No Media Assets Loaded\n(Drag & Drop files here or right-click to import)"
//                             horizontalAlignment: Text.AlignHCenter
//                             color: "#555555"
//                             font.pixelSize: 12
//                             visible: gridView.count === 0
//                         }
//                     }
//                 }
//             }
//         }
//     }
// }


import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import Xyla 1.0
import "../components"

Item {
    id: panelRoot

    property var activeMediaPool: typeof mediaPool !== "undefined" ? mediaPool : null
    property var activeMediaBinModel: typeof mediaBinModel !== "undefined" ? mediaBinModel : null

    property var selectedIndices: []
    property int lastSelectedIndex: -1
    property int editingIndex: -1
    property var clipboardAssets: [] // Array of { id: string, isCut: bool }
    property bool showExtensions: false

    property bool isListView: false
    property int selectedItemIndex: -1
    property real gridCellSize: 195
    property bool hoverScrubEnabled: true
    property bool showWaveforms: true
    property bool groupByMediaType: false

    // Sync treeMode with isListView
    onIsListViewChanged: {
        if (panelRoot.activeMediaBinModel) {
            panelRoot.activeMediaBinModel.treeMode = panelRoot.isListView;
        }
    }

    Component.onCompleted: {
        if (panelRoot.activeMediaBinModel) {
            panelRoot.activeMediaBinModel.treeMode = panelRoot.isListView;
        }
    }

    // Escape shortcut: dismiss rename or deselect all items
    Shortcut {
        sequence: "Escape"
        enabled: true
        onActivated: {
            if (panelRoot.editingIndex !== -1) {
                panelRoot.editingIndex = -1;
            } else {
                panelRoot.clearSelection();
            }
        }
    }

    // Drag tracking
    property var draggedAssetIds: []
    property bool isCustomDragging: false
    property real dragGlobalX: 0
    property real dragGlobalY: 0
    property string dragPreviewName: ""
    property string dragPreviewPath: ""
    property bool dragPreviewIsFolder: false
    property int dragCount: 1

    readonly property color bgDark: "#141414"
    readonly property color bgCard: "#1f1f20"
    readonly property color bgCardHover: "#2a2a2c"
    readonly property color bgCardSelected: "#232d42"
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#888888"
    readonly property color accentColor: "#2555D3"
    readonly property color borderColor: "#282829"

    function isSelected(index) {
        return panelRoot.selectedIndices.indexOf(index) !== -1;
    }

    function clearSelection() {
        panelRoot.selectedIndices = [];
        panelRoot.selectedItemIndex = -1;
        panelRoot.lastSelectedIndex = -1;
    }

    function selectSingle(index) {
        panelRoot.selectedIndices = [index];
        panelRoot.selectedItemIndex = index;
        panelRoot.lastSelectedIndex = index;
    }

    function toggleSelect(index) {
        var arr = panelRoot.selectedIndices.slice();
        var pos = arr.indexOf(index);
        if (pos === -1) arr.push(index); else arr.splice(pos, 1);
        panelRoot.selectedIndices = arr;
        panelRoot.selectedItemIndex = index;
        panelRoot.lastSelectedIndex = index;
    }

    function selectRange(fromIndex, toIndex) {
        var lo = Math.min(fromIndex, toIndex);
        var hi = Math.max(fromIndex, toIndex);
        var arr = [];
        for (var i = lo; i <= hi; i++) arr.push(i);
        panelRoot.selectedIndices = arr;
        panelRoot.selectedItemIndex = toIndex;
    }

    function getSelectedAssetIds() {
        var ids = [];
        if (!panelRoot.activeMediaBinModel) return ids;
        var indices = panelRoot.selectedIndices.length > 0 
            ? panelRoot.selectedIndices 
            : (panelRoot.selectedItemIndex >= 0 ? [panelRoot.selectedItemIndex] : []);
        for (var i = 0; i < indices.length; i++) {
            var item = panelRoot.activeMediaBinModel.get(indices[i]);
            if (item && item.id) ids.push(item.id);
        }
        return ids;
    }

    function displayName(name) {
        if (panelRoot.showExtensions || !name) return name;
        var lastDot = name.lastIndexOf(".");
        return lastDot > 0 ? name.substring(0, lastDot) : name;
    }

    function applyRubberBandSelection(x1, y1, x2, y2) {
        if (!panelRoot.activeMediaBinModel) return;
        var count = panelRoot.isListView ? listView.count : gridView.count;
        var arr = [];

        if (panelRoot.isListView) {
            var rowH = 36 + listView.spacing;
            var cy1 = y1 + listView.contentY, cy2 = y2 + listView.contentY;
            var firstRow = Math.max(0, Math.floor(cy1 / rowH));
            var lastRow = Math.min(count - 1, Math.ceil(cy2 / rowH));
            for (var i = firstRow; i <= lastRow; i++) arr.push(i);
        } else {
            var cw = gridView.cellWidth, ch = gridView.cellHeight;
            var itemsPerRow = Math.max(1, Math.floor(gridView.width / cw));
            var cy1g = y1 + gridView.contentY, cy2g = y2 + gridView.contentY;
            var colFirst = Math.max(0, Math.floor(x1 / cw));
            var colLast = Math.min(itemsPerRow - 1, Math.floor(x2 / cw));
            var rowFirst = Math.max(0, Math.floor(cy1g / ch));
            var rowLast = Math.floor(cy2g / ch);
            for (var r = rowFirst; r <= rowLast; r++) {
                for (var c = colFirst; c <= colLast; c++) {
                    var idx = r * itemsPerRow + c;
                    if (idx >= 0 && idx < count) arr.push(idx);
                }
            }
        }
        panelRoot.selectedIndices = arr;
        panelRoot.selectedItemIndex = arr.length > 0 ? arr[arr.length - 1] : -1;
    }

    function buildClipboardFromSelection(isCut) {
        var arr = [];
        if (!panelRoot.activeMediaBinModel) return arr;
        var ids = panelRoot.getSelectedAssetIds();
        for (var i = 0; i < ids.length; i++) {
            arr.push({ id: ids[i], isCut: isCut });
        }
        return arr;
    }

    function urlToLocalPath(urlVal) {
        if (!urlVal) return "";
        var str = urlVal.toString().trim();
        if (str.startsWith("//")) return "";

        if (str.startsWith("file://")) {
            var path = str.replace(/^file:\/\//, "");
            path = decodeURIComponent(path);
            if (/^\/[a-zA-Z]:/.test(path))
                path = path.substring(1);
            return path;
        }

        if (str.startsWith("/") && !str.startsWith("//"))
            return decodeURIComponent(str);
        if (/^[a-zA-Z]:[/\\]/.test(str))
            return decodeURIComponent(str);
        return "";
    }

    // Custom File/Folder Dialog
    XylaFolderDialog {
        id: folderDialog
        returnType: "file"
        selectMultiple: true
        onFolderSelected: function (path) {
            panelRoot.editingIndex = -1;
            if (!panelRoot.activeMediaPool) return;
            if (path && path.length > 0) {
                var currentBin = panelRoot.activeMediaBinModel ? panelRoot.activeMediaBinModel.currentBinId : "root";
                panelRoot.activeMediaPool.importFilesAsync([path], currentBin);
            }
        }
    }

    // Context Menu Popup
    XylaMediaPanelContextMenu {
        id: contextMenu
        root: panelRoot

        onCutRequested: {
            panelRoot.editingIndex = -1;
            panelRoot.clipboardAssets = panelRoot.buildClipboardFromSelection(true);
        }

        onCopyRequested: {
            panelRoot.editingIndex = -1;
            panelRoot.clipboardAssets = panelRoot.buildClipboardFromSelection(false);
        }

        onPasteRequested: {
            panelRoot.editingIndex = -1;
            if (!panelRoot.activeMediaBinModel || panelRoot.clipboardAssets.length === 0)
                return;

            var curBin = panelRoot.isListView ? "root" : (panelRoot.activeMediaBinModel.currentBinId || "root");
            var cutIds = [];
            var copyIds = [];

            for (var i = 0; i < panelRoot.clipboardAssets.length; i++) {
                if (panelRoot.clipboardAssets[i].isCut)
                    cutIds.push(panelRoot.clipboardAssets[i].id);
                else
                    copyIds.push(panelRoot.clipboardAssets[i].id);
            }

            if (cutIds.length > 0) {
                panelRoot.activeMediaBinModel.moveAssetsById(cutIds, curBin);
                panelRoot.clipboardAssets = [];
            }

            if (copyIds.length > 0) {
                panelRoot.activeMediaBinModel.duplicateAssetsById(copyIds, curBin);
            }
        }

        onOpenRequested: {
            panelRoot.editingIndex = -1;
            var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
            if (panelRoot.activeMediaBinModel && targetIdx >= 0) {
                var it = panelRoot.activeMediaBinModel.get(targetIdx);
                if (it && it.isFolder) {
                    if (panelRoot.isListView) {
                        panelRoot.activeMediaBinModel.toggleFolderExpanded(it.id);
                    } else {
                        panelRoot.activeMediaBinModel.currentBinId = it.id;
                        panelRoot.clearSelection();
                    }
                }
            }
        }

        onRenameRequested: {
            var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
            if (targetIdx >= 0) {
                panelRoot.editingIndex = targetIdx;
            }
        }

        onDeleteRequested: {
            panelRoot.editingIndex = -1;
            if (panelRoot.activeMediaBinModel) {
                var ids = panelRoot.getSelectedAssetIds();
                if (ids.length > 0) {
                    panelRoot.activeMediaBinModel.removeAssetsById(ids);
                    panelRoot.clearSelection();
                }
            }
        }

        onNewFolderRequested: {
            if (panelRoot.activeMediaBinModel) {
                var newIdx = panelRoot.activeMediaBinModel.createFolder("New Folder");
                if (newIdx >= 0) {
                    panelRoot.selectSingle(newIdx);
                    panelRoot.editingIndex = newIdx;
                }
            }
        }

        onSelectAllRequested: {
            panelRoot.editingIndex = -1;
            var count = panelRoot.isListView ? listView.count : gridView.count;
            if (count > 0) {
                var arr = [];
                for (var i = 0; i < count; i++) arr.push(i);
                panelRoot.selectedIndices = arr;
                panelRoot.selectedItemIndex = arr[arr.length - 1];
                panelRoot.lastSelectedIndex = arr[arr.length - 1];
            }
        }

        onPropertiesRequested: {
            panelRoot.editingIndex = -1;
            var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
            if (panelRoot.activeMediaBinModel && targetIdx >= 0) {
                var propItem = panelRoot.activeMediaBinModel.get(targetIdx);
                if (propItem) {
                    propPopup.assetName = propItem.name || "Unknown";
                    propPopup.assetPath = propItem.path || "-";
                    propPopup.assetDuration = propItem.duration || "-";
                    propPopup.assetResolution = propItem.resolution || "-";
                    propPopup.assetType = propItem.isFolder ? "Folder Bin" : "Media Clip";
                    propPopup.isFolder = propItem.isFolder || false;
                    propPopup.openAt(contextMenu.x, contextMenu.y);
                }
            }
        }
    }

    // Properties Popup (Studio Inspector)
    Popup {
        id: propPopup
        parent: Overlay.overlay
        width: 290
        padding: 12
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string assetName: ""
        property string assetPath: ""
        property string assetDuration: ""
        property string assetResolution: ""
        property string assetType: ""
        property bool isFolder: false
        property bool pathCopied: false

        property real requestedX: 0
        property real requestedY: 0

        function reposition() {
            if (!parent) return;
            x = Math.max(10, Math.min(requestedX, parent.width - width - 10));
            y = Math.max(10, Math.min(requestedY, parent.height - height - 10));
        }

        onImplicitWidthChanged: if (visible) reposition()
        onImplicitHeightChanged: if (visible) reposition()

        function openAt(screenX, screenY) {
            requestedX = screenX;
            requestedY = screenY;
            pathCopied = false;
            reposition();
            open();
        }

        background: Rectangle {
            id: propSurface
            anchors.fill: parent
            color: "#161618"
            border.color: "#2c2c2f"
            border.width: 1
            radius: 12

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#95000000"
                shadowBlur: 0.7
                shadowVerticalOffset: 6
                shadowHorizontalOffset: 0
            }
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.95
                to: 1.0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 120
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: 0.95
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        contentItem: ColumnLayout {
            spacing: 10
            width: 266

            // Header: Title & Close Button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Rectangle {
                //     width: 22
                //     height: 22
                //     radius: 5
                //     color: "#222226"
                //     border.color: "#303035"
                //     border.width: 1
                //
                //     Image {
                //         anchors.centerIn: parent
                //         width: 13
                //         height: 13
                //         source: propPopup.isFolder ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/crop-landscape.svg"
                //         sourceSize: Qt.size(13, 13)
                //     }
                // }

                Text {
                    text: "Properties"
                    color: "#dedede"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                // Rectangle {
                //     width: 20
                //     height: 20
                //     radius: 10
                //     color: closePropMouse.containsMouse ? "#2a2a2e" : "transparent"
                //
                //     Text {
                //         anchors.centerIn: parent
                //         text: "✕"
                //         color: closePropMouse.containsMouse ? "#ffffff" : "#707075"
                //         font.pixelSize: 10
                //     }
                //
                //     MouseArea {
                //         id: closePropMouse
                //         anchors.fill: parent
                //         hoverEnabled: true
                //         cursorShape: Qt.PointingHandCursor
                //         onClicked: propPopup.close()
                //     }
                // }
            }

            // Hero Thumbnail Card Viewport
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: propPopup.isFolder ? 74 : 96
                radius: 7
                color: "#101012"
                border.color: "#242428"
                border.width: 1
                clip: true

                Image {
                    anchors.fill: parent
                    visible: !propPopup.isFolder && propPopup.assetPath !== "" && propPopup.assetPath !== "-"
                    fillMode: Image.PreserveAspectCrop
    source: (propPopup.assetPath && propPopup.assetPath !== "-") ? "image://thumbnails/" + propPopup.assetPath + "?width=280" : ""
                    // source: propPopup.assetPath ? "image://thumbnails/" + propPopup.assetPath + "?width=280" : ""
                    asynchronous: true
                }

                Image {
                    anchors.centerIn: parent
                    visible: propPopup.isFolder
                    source: "qrc:/assets/icons/folder.svg"
                    sourceSize: Qt.size(28, 28)
                    opacity: 0.85
                }

                // Resolution Badge
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 5
                    width: resText.implicitWidth + 8
                    height: 16
                    radius: 3.5
                    color: "#cc0c0c0e"
                    visible: !propPopup.isFolder && propPopup.assetResolution !== "" && propPopup.assetResolution !== "-"

                    Text {
                        id: resText
                        anchors.centerIn: parent
                        text: propPopup.assetResolution
                        color: "#ffffff"
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }

                // Duration Badge
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 5
                    width: durText.implicitWidth + 8
                    height: 16
                    radius: 3.5
                    color: "#cc0c0c0e"
                    visible: !propPopup.isFolder && propPopup.assetDuration !== "" && propPopup.assetDuration !== "-"

                    Text {
                        id: durText
                        anchors.centerIn: parent
                        text: propPopup.assetDuration
                        color: "#ffffff"
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }
            }

            // Metadata Spec Rows
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                // File / Bin Name
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Name"
                        color: "#75757a"
                        font.pixelSize: 11
                        Layout.preferredWidth: 64
                    }
                    Text {
                        text: propPopup.assetName
                        color: "#ffffff"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Type Tag
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Type"
                        color: "#75757a"
                        font.pixelSize: 11
                        Layout.preferredWidth: 64
                    }
                    Rectangle {
                        implicitWidth: typeTagText.implicitWidth + 8
                        implicitHeight: 18
                        radius: 4
                        color: propPopup.isFolder ? "#1e2a38" : "#1e2430"
                        // border.color: propPopup.isFolder ? "#304860" : "#2a4268"
                        // border.width: 1

                        Text {
                            id: typeTagText
                            anchors.centerIn: parent
                            text: propPopup.assetType.toUpperCase()
                            color: propPopup.isFolder ? "#6ab4f8" : "#7aaaf8"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }
                }

                // File Path Container with Quick-Copy
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    visible: !propPopup.isFolder && propPopup.assetPath !== "" && propPopup.assetPath !== "-"

                    Text {
                        text: "File Location"
                        color: "#75757a"
                        font.pixelSize: 10
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: 5
                        color: "#101012"
                        border.color: pathMouse.containsMouse ? "#3a3a40" : "#222225"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 7
                            anchors.rightMargin: 4
                            spacing: 4

                            Text {
                                text: propPopup.assetPath
                                color: "#8a8a90"
                                font.pixelSize: 10
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                radius: 3.5
                                color: copyBtnMouse.containsMouse ? "#28282e" : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: propPopup.pathCopied ? "✓" : "📋"
                                    color: propPopup.pathCopied ? "#4ade80" : "#99999f"
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    id: copyBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var field = Qt.createQmlObject('import QtQuick; TextEdit {}', parent);
                                        field.text = propPopup.assetPath;
                                        field.selectAll();
                                        field.copy();
                                        field.destroy();
                                        propPopup.pathCopied = true;
                                        copyResetTimer.restart();
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: pathMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                        }
                    }
                }
            }

            Timer {
                id: copyResetTimer
                interval: 1800
                repeat: false
                onTriggered: propPopup.pathCopied = false
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#222226"
            }

            // Rectangle {
            //     Layout.fillWidth: true
            //     implicitHeight: 28
            //     radius: 6
            //     color: doneMouse.containsMouse ? "#25334c" : "#1a2232"
            //     border.color: doneMouse.containsMouse ? "#3b5b96" : "#2555D3"
            //     border.width: 1
            //
            //     Text {
            //         anchors.centerIn: parent
            //         text: "Close"
            //         color: "#ffffff"
            //         font.pixelSize: 11
            //         font.weight: Font.Medium
            //     }
            //
            //     MouseArea {
            //         id: doneMouse
            //         anchors.fill: parent
            //         hoverEnabled: true
            //         cursorShape: Qt.PointingHandCursor
            //         onClicked: propPopup.close()
            //     }
            // }
        }
    }

    // Panel Background
    Rectangle {
        anchors.fill: parent
        color: panelRoot.bgDark
        z: -1
    }

    XylaMediaPanelSettingsPopup {
        id: settingsPopup
        parent: settingsBtn
        // x: settingsBtn.width - width
        // y: settingsBtn.height + 4
        isListView: panelRoot.isListView
        gridCellSize: panelRoot.gridCellSize

        onViewModeChanged: function (isListView) {
            panelRoot.isListView = isListView;
        }

        onGridCellSizeChanged: {
            if (settingsPopup.gridCellSize > 0) {
                panelRoot.gridCellSize = settingsPopup.gridCellSize;
            }
        }

        onHoverScrubToggled: function (enabled) {
            panelRoot.hoverScrubEnabled = enabled;
        }

        onShowWaveformsToggled: function (enabled) {
            panelRoot.showWaveforms = enabled;
        }

        onShowExtensionsToggled: function (enabled) {
            panelRoot.showExtensions = enabled;
        }

        onGroupByMediaTypeToggled: function (enabled) {
            panelRoot.groupByMediaType = enabled;
            if (enabled && panelRoot.activeMediaBinModel) {
                panelRoot.activeMediaBinModel.groupByMediaType();
            }
        }

        onSortOrderChanged: function (field, ascending) {
            if (!panelRoot.activeMediaBinModel)
                return;
            var roleIndex = 0;
            if (field.toLowerCase() === "duration")
                roleIndex = 1;
            else if (field.toLowerCase() === "path" || field.toLowerCase() === "type")
                roleIndex = 2;
            panelRoot.activeMediaBinModel.setSortRole(roleIndex);
            panelRoot.activeMediaBinModel.setSortAscending(ascending);
            sortComboBox.currentIndex = roleIndex;
            sortOrderToggle.isAscending = ascending;
        }
    }

    // Mouse-Following Miniature Drag Follower
    Item {
        id: dragProxy
        parent: Overlay.overlay
        visible: panelRoot.isCustomDragging
        enabled: false
        z: 99999
        width: 76
        height: 54
        x: panelRoot.dragGlobalX - width / 2
        y: panelRoot.dragGlobalY - height / 2

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: "#1c2538"
            border.color: panelRoot.accentColor
            border.width: 1.5
            opacity: 0.95

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#a0000000"
                shadowBlur: 0.65
                shadowVerticalOffset: 4
            }

            Rectangle {
                id: dragThumbFrame
                anchors.fill: parent
                anchors.margins: 4
                radius: 6
                color: "#121213"

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: dragThumbFrame.width
                            height: dragThumbFrame.height
                            radius: dragThumbFrame.radius
                        }
                    }
                }

                Image {
                    anchors.fill: parent
                    visible: !panelRoot.dragPreviewIsFolder
                    fillMode: Image.PreserveAspectCrop
                    source: panelRoot.dragPreviewPath ? "image://thumbnails/" + panelRoot.dragPreviewPath + "?width=120" : ""
                    asynchronous: true
                }

                Image {
                    anchors.centerIn: parent
                    visible: panelRoot.dragPreviewIsFolder
                    source: "qrc:/assets/icons/folder.svg"
                    sourceSize: Qt.size(24, 24)
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: -4
                width: badgeText.implicitWidth + 8
                height: 16
                radius: 8
                color: panelRoot.accentColor
                visible: panelRoot.dragCount > 1

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: "+" + panelRoot.dragCount
                    color: "#ffffff"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
            }
        }
    }

    // MAIN MEDIA PANEL CONTAINER
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Header Toolbar
        RowLayout {
            id: toolbarRow
            Layout.fillWidth: true
            spacing: 6

            // Add button
            XylaIconButton {
                implicitWidth: 30
                implicitHeight: 30
                iconSource: "qrc:/assets/icons/plus.svg"
                primary: true
                onClicked: {
                    panelRoot.editingIndex = -1;
                    folderDialog.open();
                }
            }

            // Settings button
            XylaIconButton {
                id: settingsBtn
                implicitWidth: 30
                implicitHeight: 30
                primary: settingsPopup.opened
                iconSource: "qrc:/assets/icons/settings.svg"
                onClicked: {
                    panelRoot.editingIndex = -1;
                    if (settingsPopup.opened) {
                        settingsPopup.close();
                    } else {
                        settingsPopup.open();
                    }
                }
            }

            // Up folder navigation (Only relevant in Grid View)
            RowLayout {
                spacing: 6
                visible: !panelRoot.isListView && panelRoot.activeMediaBinModel && panelRoot.activeMediaBinModel.currentBinId !== "root"

                XylaIconButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    iconSource: "qrc:/assets/icons/arrow-up.svg"
                    onClicked: {
                        panelRoot.editingIndex = -1;
                        if (panelRoot.activeMediaBinModel) {
                            panelRoot.activeMediaBinModel.goToParentBin();
                            panelRoot.clearSelection();
                        }
                    }
                }

                Text {
                    text: panelRoot.activeMediaBinModel ? panelRoot.activeMediaBinModel.currentBinName : ""
                    color: panelRoot.textPrimary
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.maximumWidth: 120
                }
            }

            Item {
                Layout.minimumWidth: 10
                Layout.fillWidth: true
            }

            // Sort Select Dropdown
            XylaSelect {
                id: sortComboBox
                // Layout.preferredWidth: 95
                // implicitHeight: 30
                icon: "qrc:/assets/icons/sort.svg"
                activeFocusOnTab: false
                model: ["Name", "Duration", "Path"]
                onActivated: function (index) {
                    panelRoot.editingIndex = -1;
                    if (!panelRoot.activeMediaBinModel) return;
                    panelRoot.activeMediaBinModel.setSortRole(index);
                }
            }

            // Sort Order Toggle
            XylaIconButton {
                id: sortOrderToggle
                implicitWidth: 30
                implicitHeight: 30
                property bool isAscending: true
                iconSource: ""

                onClicked: {
                    panelRoot.editingIndex = -1;
                    isAscending = !isAscending;
                    if (panelRoot.activeMediaBinModel) {
                        panelRoot.activeMediaBinModel.setSortAscending(isAscending);
                    }
                }

                Image {
                    id: sortIcon
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "qrc:/assets/icons/sort-ascending.svg"
                    fillMode: Image.PreserveAspectFit
                    rotation: sortOrderToggle.isAscending ? 0 : 180

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }

            // Segmented Toggle (List / Grid)
            XylaSegmentedToggle {
                id: viewModeToggle
                implicitHeight: 30
                currentIndex: panelRoot.isListView ? 0 : 1
                options: [
                    { icon: "qrc:/assets/icons/list.svg", value: "list" },
                    { icon: "qrc:/assets/icons/layout-grid.svg", value: "grid" }
                ]
                onOptionSelected: (index, value) => {
                    panelRoot.editingIndex = -1;
                    panelRoot.isListView = (value === "list");
                }
            }

            // Search Toggle Button
            XylaIconButton {
                id: searchBtn
                implicitWidth: 30
                implicitHeight: 30
                iconSource: "qrc:/assets/icons/search.svg"
                primary: searchPopup.opened || (searchInput.text !== "")

                onClicked: {
                    panelRoot.editingIndex = -1;
                    if (searchPopup.opened) {
                        searchPopup.close();
                    } else {
                        searchPopup.open();
                    }
                }

                Popup {
                    id: searchPopup
                    y: searchBtn.height + 6
                    x: searchBtn.width - (width)
                    width: 230
                    height: 34
                    padding: 0
                    modal: false
                    focus: false
                    closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape

                    onOpened: searchInput.forceActiveFocus()
                    onAboutToHide: searchInput.focus = false

                    background: Rectangle {
                        color: "#181818"
                        border.color: searchInput.activeFocus ? panelRoot.accentColor : "#2e2e30"
                        border.width: 1
                        radius: 6

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#90000000"
                            shadowBlur: 0.65
                            shadowVerticalOffset: 6
                        }
                    }

                    enter: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0.0
                            to: 1.0
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.95
                            to: 1.0
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }

                    exit: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 1.0
                            to: 0.0
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 1.0
                            to: 0.95
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                    }

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 4

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: "Search bin..."
                            placeholderTextColor: "#606060"
                            color: "#ffffff"
                            font.pixelSize: 11
                            background: Item {}
                            selectByMouse: true
                            focus: true
                            activeFocusOnTab: false

                            onActiveFocusChanged: {
                                if (!activeFocus && searchPopup.opened) {
                                    searchInput.forceActiveFocus();
                                }
                            }

                            onTextChanged: searchDebounce.restart()

                            Timer {
                                id: searchDebounce
                                interval: 50
                                repeat: false
                                onTriggered: {
                                    if (panelRoot.activeMediaBinModel) {
                                        panelRoot.activeMediaBinModel.searchFilter = searchInput.text;
                                    }
                                }
                            }
                            // onTextChanged: {
                            //     if (panelRoot.activeMediaBinModel) {
                            //         panelRoot.activeMediaBinModel.searchFilter = text;
                            //     }
                            // }

                            Keys.onEscapePressed: {
                                text = "";
                                if (panelRoot.activeMediaBinModel) {
                                    panelRoot.activeMediaBinModel.searchFilter = "";
                                }
                                searchPopup.close();
                            }

                            Keys.onReturnPressed: (event) => {
                                searchPopup.close();
                                event.accepted = true;
                            }

                            Keys.onEnterPressed: (event) => {
                                searchPopup.close();
                                event.accepted = true;
                            }
                        }

                        // Quick clear button
                        Text {
                            text: "✕"
                            color: "#777777"
                            font.pixelSize: 11
                            visible: searchInput.text.length > 0
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchInput.text = ""
                            }
                        }
                    }
                }
            }
        }

        // Drop Area & Media Container
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // External OS files drop area
            DropArea {
                id: dropArea
                anchors.fill: parent

                onEntered: function (drag) {
                    if (drag.source !== null) {
                        drag.accepted = false;
                        return;
                    }
                    drag.accept(Qt.CopyAction);
                }

                onDropped: function (drop) {
                    panelRoot.editingIndex = -1;
                    if (drop.source !== null) return;
                    drop.accept(Qt.CopyAction);

                    if (!drop.hasUrls || drop.urls.length === 0 || !panelRoot.activeMediaPool)
                        return;

                    var rawPaths = [];
                    for (var i = 0; i < drop.urls.length; i++) {
                        var localPath = panelRoot.urlToLocalPath(drop.urls[i]);
                        if (localPath.length > 0)
                            rawPaths.push(localPath);
                    }

                    if (rawPaths.length === 0) return;

                    var currentBin = panelRoot.isListView ? "root" : (panelRoot.activeMediaBinModel ? panelRoot.activeMediaBinModel.currentBinId : "root");
                    panelRoot.activeMediaPool.importFilesAsync(rawPaths, currentBin);
                }

                MouseArea {
                    id: rubberBandArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    z: -1
                    property real startX: 0
                    property real startY: 0
                    property bool selecting: false

                    onPressed: function (mouse) {
                        startX = mouse.x;
                        startY = mouse.y;
                        selecting = false;
                        panelRoot.editingIndex = -1;
                        if (!(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier))) {
                            panelRoot.clearSelection();
                        }
                    }

                    onPositionChanged: function (mouse) {
                        if (!selecting && (Math.abs(mouse.x - startX) > 4 || Math.abs(mouse.y - startY) > 4)) {
                            selecting = true;
                        }
                        if (selecting) {
                            var x1 = Math.min(startX, mouse.x), x2 = Math.max(startX, mouse.x);
                            var y1 = Math.min(startY, mouse.y), y2 = Math.max(startY, mouse.y);
                            selectionRect.x = x1; selectionRect.y = y1;
                            selectionRect.width = x2 - x1; selectionRect.height = y2 - y1;
                            panelRoot.applyRubberBandSelection(x1, y1, x2, y2);
                        }
                    }

                    onReleased: function (mouse) {
                        selecting = false;
                        selectionRect.width = 0;
                        selectionRect.height = 0;
                    }
                }

                Rectangle {
                    id: selectionRect
                    color: "#2a2555D3"
                    border.color: panelRoot.accentColor
                    border.width: 1
                    visible: rubberBandArea.selecting && (width > 2 || height > 2)
                    z: 20
                }

                Rectangle {
                    anchors.fill: parent
                    color: (dropArea.containsDrag && dropArea.drag.source === null) ? "#152555D3" : "transparent"
                    border.color: (dropArea.containsDrag && dropArea.drag.source === null) ? panelRoot.accentColor : "transparent"
                    border.width: 1.5
                    radius: 6
                    z: 10
                }

                // Stack View: List (Tree) vs Grid
                StackLayout {
                    anchors.fill: parent
                    currentIndex: panelRoot.isListView ? 0 : 1

                    anchors.topMargin: searchPopup.visible ? 20 : 0

                    Behavior on anchors.topMargin {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    // ================================================================
                    // TREE HIERARCHY LIST VIEW
                    // ================================================================
                    ListView {
                        id: listView
                        clip: true
                        spacing: 2
                        model: panelRoot.activeMediaBinModel
    focus: false
    keyNavigationEnabled: false
    activeFocusOnTab: false

// Place inside ListView (replacing TapHandler):
// MouseArea {
//     id: listBgMouseArea
//     anchors.fill: parent
//     z: -1
//     acceptedButtons: Qt.LeftButton | Qt.RightButton
//
//     onClicked: function (mouse) {
//         panelRoot.editingIndex = -1;
//         panelRoot.clearSelection();
//         if (mouse.button === Qt.RightButton) {
//             var globalPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
//             contextMenu.hasSelection = false;
//             contextMenu.selectionCount = 0;
//             contextMenu.selectionIsFolder = false;
//             contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
//             contextMenu.openAt(globalPt.x, globalPt.y);
//         }
//     }
// }
TapHandler {
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onTapped: function(eventPoint, button) {
        panelRoot.editingIndex = -1;
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

                        delegate: Rectangle {
                            id: listDelegateItem
                            property int itemIndex: index
                            width: listView.width
                            height: 32
                            radius: 5
                            color: listDropOnFolder.containsDrag ? "#233554" : (panelRoot.isSelected(index) ? panelRoot.bgCardSelected : (itemMouseArea.containsMouse ? panelRoot.bgCardHover : "transparent"))
                            border.color: listDropOnFolder.containsDrag ? "#4d88e8" : (panelRoot.isSelected(index) ? panelRoot.accentColor : "transparent")
                            border.width: 1

                            // Drag.active: itemMouseArea.drag.active
                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
                            Drag.keys: ["xyla/media-asset", "text/uri-list"]
                            Drag.source: listDelegateItem
                            Drag.mimeData: {
                                "xyla/media-asset": model.id || "",
                                "text/uri-list": model.path ? (model.path.startsWith("file://") ? model.path : "file://" + model.path) : ""
                            }
                            Drag.imageSource: model.isFolder ? "qrc:/assets/icons/folder.svg" : "qrc:/assets/icons/crop-landscape.svg"
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
                                    if (panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
                                        drop.accepted = false;
                                        return;
                                    }
                                    drop.accept(Qt.MoveAction);
                                    var targetFolderId = model.id;
                                    if (panelRoot.draggedAssetIds.length > 0 && panelRoot.activeMediaBinModel) {
                                        panelRoot.activeMediaBinModel.moveAssetsById(panelRoot.draggedAssetIds, targetFolderId);
                                        panelRoot.clearSelection();
                                        panelRoot.draggedAssetIds = [];
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8 + ((model.depth || 0) * 16)
                                anchors.rightMargin: 10
                                spacing: 6
                                z: 1

                                Item {
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                    visible: model.isFolder

                                    Text {
                                        anchors.centerIn: parent
                                        text: "›"
                                        color: treeChevronMouse.containsMouse ? "#ffffff" : "#808080"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        rotation: model.isExpanded ? 90 : 0
                                        transformOrigin: Item.Center

                                        Behavior on rotation {
                                            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                                        }
                                    }

                                    MouseArea {
                                        id: treeChevronMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (panelRoot.activeMediaBinModel) {
                                                panelRoot.activeMediaBinModel.toggleFolderExpanded(model.id);
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                    visible: !model.isFolder
                                }

                                Image {
                                    source: model.isFolder ? (model.isExpanded ? "qrc:/assets/icons/folder-open.svg" : "qrc:/assets/icons/folder.svg") : "qrc:/assets/icons/crop-landscape.svg"
                                    sourceSize.width: 15
                                    sourceSize.height: 15
                                    opacity: model.isFolder ? 0.95 : 0.75
                                }

                                Text {
                                    id: nameText
                                    visible: panelRoot.editingIndex !== index
                                    text: model.isFolder ? (model.name || "") : panelRoot.displayName(model.name || "")
                                    color: panelRoot.textPrimary
                                    font.pixelSize: 12
                                    font.weight: model.isFolder ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                TextField {
                                    id: renameField
                                    visible: panelRoot.editingIndex === index
                                    Layout.fillWidth: true
                                    z: 20
                                    text: model.name || ""
                                    font.pixelSize: 12
                                    color: "#ffffff"
                                    selectByMouse: true
                                    focus: visible
                                    background: Rectangle {
                                        color: "#121212"
                                        border.color: panelRoot.accentColor
                                        border.width: 1.5
                                        radius: 4
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
                                    Keys.onEscapePressed: panelRoot.editingIndex = -1

                                    function commitRename() {
                                        if (panelRoot.editingIndex === index && panelRoot.activeMediaBinModel) {
                                            var newName = text.trim();
                                            panelRoot.editingIndex = -1;
                                            if (newName !== "" && newName !== model.name) {
                                                panelRoot.activeMediaBinModel.renameAsset(index, newName);
                                            }
                                        } else {
                                            panelRoot.editingIndex = -1;
                                        }
                                    }
                                }

                                Text {
                                    text: model.resolution || ""
                                    color: "#666666"
                                    font.pixelSize: 10
                                    visible: !model.isFolder && panelRoot.editingIndex !== index
                                }

                                Text {
                                    text: model.duration || ""
                                    color: "#888888"
                                    font.pixelSize: 11
                                    visible: !model.isFolder && panelRoot.editingIndex !== index
                                }
                            }

                            MouseArea {
                                id: itemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: panelRoot.editingIndex !== index
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                drag.target: listDummyDragTarget
                                drag.threshold: 5

                                Item {
                                    id: listDummyDragTarget
                                }

                                onPressed: function (mouse) {
                                    if (panelRoot.editingIndex !== -1 && panelRoot.editingIndex !== index) {
                                        panelRoot.editingIndex = -1;
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
    if (itemMouseArea.drag.active) {
        listDelegateItem.Drag.active = true;
        panelRoot.isCustomDragging = true;
        var pt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
        panelRoot.dragGlobalX = pt.x;
        panelRoot.dragGlobalY = pt.y;
    }
}

onReleased: function (mouse) {
    listDelegateItem.Drag.active = false;
    panelRoot.isCustomDragging = false;
}
onCanceled: {
    listDelegateItem.Drag.active = false;
    panelRoot.isCustomDragging = false;
}
                                // onPositionChanged: function (mouse) {
                                //     if (itemMouseArea.drag.active) {
                                //         panelRoot.isCustomDragging = true;
                                //         var pt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                //         panelRoot.dragGlobalX = pt.x;
                                //         panelRoot.dragGlobalY = pt.y;
                                //     }
                                // }
                                //
                                // onReleased: function (mouse) {
                                //     panelRoot.isCustomDragging = false;
                                // }
                                // onCanceled: {
                                //     panelRoot.isCustomDragging = false;
                                // }

                                onClicked: function (mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (!(mouse.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.MetaModifier))) {
                                            panelRoot.selectSingle(index);
                                        }
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (!panelRoot.isSelected(index)) {
                                            panelRoot.selectSingle(index);
                                        }
                                        var globalPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                        contextMenu.hasSelection = true;
                                        contextMenu.selectionCount = Math.max(1, panelRoot.selectedIndices.length);
                                        contextMenu.selectionIsFolder = (contextMenu.selectionCount === 1 && model.isFolder);
                                        contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
                                        contextMenu.openAt(globalPoint.x, globalPoint.y);
                                    }
                                }

                                onDoubleClicked: function (mouse) {
                                    if (mouse.button === Qt.LeftButton && model.isFolder) {
                                        if (panelRoot.activeMediaBinModel) {
                                            panelRoot.activeMediaBinModel.toggleFolderExpanded(model.id);
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No Media Assets Loaded\n(Drag & Drop files here or right-click to import)"
                            horizontalAlignment: Text.AlignHCenter
                            color: "#505050"
                            font.pixelSize: 12
                            visible: listView.count === 0
                        }
                    }

                    // ================================================================
                    // GRID VIEW
                    // ================================================================
                    GridView {
                        id: gridView
                        clip: true
                        cellWidth: panelRoot.gridCellSize
                        cellHeight: panelRoot.gridCellSize * 0.90
                        model: panelRoot.activeMediaBinModel
    focus: false
    keyNavigationEnabled: false
    activeFocusOnTab: false

// Place inside GridView (replacing TapHandler):
// MouseArea {
//     id: gridBgMouseArea
//     anchors.fill: parent
//     z: -1
//     acceptedButtons: Qt.LeftButton | Qt.RightButton
//
//     onClicked: function (mouse) {
//         panelRoot.editingIndex = -1;
//         panelRoot.clearSelection();
//         if (mouse.button === Qt.RightButton) {
//             var globalPt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
//             contextMenu.hasSelection = false;
//             contextMenu.selectionCount = 0;
//             contextMenu.selectionIsFolder = false;
//             contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
//             contextMenu.openAt(globalPt.x, globalPt.y);
//         }
//     }
// }
TapHandler {
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onTapped: function(eventPoint, button) {
        panelRoot.editingIndex = -1;
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
                            width: gridView.cellWidth
                            height: gridView.cellHeight

                            property real cardScale: 1.0
                            scale: cardScale
                            transformOrigin: Item.Center

                            Component.onCompleted: entranceAnim.restart()

                            ParallelAnimation {
                                id: entranceAnim
                                ScriptAction { script: gridDelegateItem.cardScale = 0.0 }
                                NumberAnimation {
                                    target: gridDelegateItem
                                    property: "cardScale"
                                    from: 0.8
                                    to: 1.0
                                    duration: 180
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.5
                                }
                            }

                            // Drag.active: cardMouseArea.drag.active
                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
                            Drag.keys: ["xyla/media-asset", "text/uri-list"]
                            Drag.source: gridDelegateItem
                            Drag.mimeData: {
                                "xyla/media-asset": model.id || "",
                                "text/uri-list": model.path ? (model.path.startsWith("file://") ? model.path : "file://" + model.path) : ""
                            }
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
                                    if (panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
                                        drop.accepted = false;
                                        return;
                                    }
                                    drop.accept(Qt.MoveAction);
                                    var targetFolderId = model.id;
                                    if (panelRoot.draggedAssetIds.length > 0 && panelRoot.activeMediaBinModel) {
                                        panelRoot.activeMediaBinModel.moveAssetsById(panelRoot.draggedAssetIds, targetFolderId);
                                        panelRoot.clearSelection();
                                        panelRoot.draggedAssetIds = [];
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 10
                                radius: 12
                                color: gridDropOnFolder.containsDrag ? "#233554" : (panelRoot.isSelected(index) ? "#1c2538" : (cardMouseArea.containsMouse ? "#222225" : panelRoot.bgCard))
                                border.color: gridDropOnFolder.containsDrag ? "#4d88e8" : (panelRoot.isSelected(index) ? "#2555D3" : (cardMouseArea.containsMouse ? "#3a3a3d" : "#28282a"))
                                border.width: (panelRoot.isSelected(index) || gridDropOnFolder.containsDrag) ? 1.5 : 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 8

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
                                            source: model.path ? "image://thumbnails/" + model.path + "?width=" + Math.round(panelRoot.gridCellSize * 1.5) : ""
                                            asynchronous: true
                                        }

                                        Image {
                                            anchors.centerIn: parent
                                            visible: model.isFolder
                                            source: "qrc:/assets/icons/folder.svg"
                                            sourceSize.width: Math.max(22, Math.min(46, panelRoot.gridCellSize * 0.3))
                                            sourceSize.height: Math.max(22, Math.min(46, panelRoot.gridCellSize * 0.3))
                                        }

                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 4
                                            width: durationText.implicitWidth + 8
                                            height: 16
                                            radius: 4
                                            color: "#e60d0d0e"
                                            visible: !model.isFolder && model.duration !== undefined && model.duration !== ""

                                            Text {
                                                id: durationText
                                                anchors.centerIn: parent
                                                text: model.duration || ""
                                                color: "#ffffff"
                                                font.pixelSize: 9
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                    }

                                    Text {
                                        id: gridNameText
                                        visible: panelRoot.editingIndex !== index
                                        Layout.bottomMargin: 2
                                        Layout.fillWidth: true
                                        text: model.isFolder ? (model.name || "") : panelRoot.displayName(model.name || "")
                                        color: panelRoot.isSelected(index) ? "#ffffff" : "#c4c4c4"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    TextField {
                                        id: gridRenameField
                                        visible: panelRoot.editingIndex === index
                                        Layout.bottomMargin: 2
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
                                            border.color: panelRoot.accentColor
                                            border.width: 1.5
                                            radius: 3
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
                                        Keys.onEscapePressed: panelRoot.editingIndex = -1

                                        function commitRename() {
                                            if (panelRoot.editingIndex === index && panelRoot.activeMediaBinModel) {
                                                var newName = text.trim();
                                                panelRoot.editingIndex = -1;
                                                if (newName !== "" && newName !== model.name) {
                                                    panelRoot.activeMediaBinModel.renameAsset(index, newName);
                                                }
                                            } else {
                                                panelRoot.editingIndex = -1;
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: panelRoot.editingIndex !== index
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                drag.target: gridDummyDragTarget
                                drag.threshold: 5

                                Item {
                                    id: gridDummyDragTarget
                                }

                                onPressed: function (mouse) {
                                    if (panelRoot.editingIndex !== -1 && panelRoot.editingIndex !== index) {
                                        panelRoot.editingIndex = -1;
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
                gridDelegateItem.Drag.active = true;
            }
        panelRoot.isCustomDragging = true;
        var pt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
        panelRoot.dragGlobalX = pt.x;
        panelRoot.dragGlobalY = pt.y;
    }
}

onReleased: function (mouse) {
    gridDelegateItem.Drag.active = false;
    panelRoot.isCustomDragging = false;
}
onCanceled: {
    gridDelegateItem.Drag.active = false;
    panelRoot.isCustomDragging = false;
}
                                // onPositionChanged: function (mouse) {
                                //     if (cardMouseArea.drag.active) {
                                //         panelRoot.isCustomDragging = true;
                                //         var pt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                //         panelRoot.dragGlobalX = pt.x;
                                //         panelRoot.dragGlobalY = pt.y;
                                //     }
                                // }
                                //
                                // onReleased: function (mouse) {
                                //     panelRoot.isCustomDragging = false;
                                // }
                                // onCanceled: {
                                //     panelRoot.isCustomDragging = false;
                                // }

                                onClicked: function (mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        if (!(mouse.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.MetaModifier))) {
                                            panelRoot.selectSingle(index);
                                        }
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (!panelRoot.isSelected(index)) {
                                            panelRoot.selectSingle(index);
                                        }
                                        var globalPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                        contextMenu.hasSelection = true;
                                        contextMenu.selectionCount = Math.max(1, panelRoot.selectedIndices.length);
                                        contextMenu.selectionIsFolder = (contextMenu.selectionCount === 1 && model.isFolder);
                                        contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
                                        contextMenu.openAt(globalPoint.x, globalPoint.y);
                                    }
                                }

                                onDoubleClicked: function (mouse) {
                                    if (mouse.button === Qt.LeftButton && model.isFolder) {
                                        var targetId = model.id;
                                        if (panelRoot.activeMediaBinModel) {
                                            panelRoot.activeMediaBinModel.currentBinId = targetId;
                                            panelRoot.clearSelection();
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No Media Assets Loaded\n(Drag & Drop files here or right-click to import)"
                            horizontalAlignment: Text.AlignHCenter
                            color: "#505050"
                            font.pixelSize: 12
                            visible: gridView.count === 0
                        }
                    }
                }
            }
        }
    }
}
