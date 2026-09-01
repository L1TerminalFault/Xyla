import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Xyla 1.0
import "../components"

Item {
    id: panelRoot

    property var activeMediaPool: typeof mediaPool !== "undefined" ? mediaPool : null
    property var activeMediaBinModel: typeof mediaBinModel !== "undefined" ? mediaBinModel : null
    property var mediaPanelSettings: activeMediaBinModel ? activeMediaBinModel.mediaPanelSettings : null

    property var selectedIndices: []
    property int lastSelectedIndex: -1
    property int editingIndex: -1
    property var clipboardAssets: [] // Array of { id: string, isCut: bool }

    property bool showExtensions: mediaPanelSettings ? mediaPanelSettings.showFileExtensions : true
    property bool isListView: mediaPanelSettings ? (mediaPanelSettings.defaultView.toString().toLowerCase() === "list") : false
    property bool hoverScrubEnabled: mediaPanelSettings ? mediaPanelSettings.hoverScrub : false
    property bool showWaveforms: mediaPanelSettings ? mediaPanelSettings.showWaveforms : false
    property bool showTooltips: mediaPanelSettings ? mediaPanelSettings.showTooltips : true

    property int selectedItemIndex: -1
    property real gridCellSize: 195
    // Flag to control initial cascade vs targeted updates
    property bool allowEntranceCascade: true

    // onIsListViewChanged: {
    //     panelRoot.allowEntranceCascade = true;
    //     cascadeResetTimer.restart();
    // }

    Timer {
        id: cascadeResetTimer
        interval: 400
        repeat: false
        onTriggered: panelRoot.allowEntranceCascade = false
    }

    // Component.onCompleted: {
    //     panelRoot.allowEntranceCascade = true;
    //     cascadeResetTimer.restart();
    // }

    // Sync treeMode with isListView
    onIsListViewChanged: {
        panelRoot.allowEntranceCascade = true;
        cascadeResetTimer.restart();
        if (panelRoot.activeMediaBinModel) {
            panelRoot.activeMediaBinModel.treeMode = panelRoot.isListView;
        }
    }

    Component.onCompleted: {
        panelRoot.allowEntranceCascade = true;
        cascadeResetTimer.restart();
        if (panelRoot.mediaPanelSettings) {
            panelRoot.mediaPanelSettings.loadSettings();
        }
        if (panelRoot.activeMediaBinModel) {
            panelRoot.activeMediaBinModel.treeMode = panelRoot.isListView;
            if (sortComboBox && sortComboBox.currentIndex >= 0) {
                panelRoot.activeMediaBinModel.setSortRole(sortComboBox.currentIndex);
            }
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
        if (pos === -1)
            arr.push(index);
        else
            arr.splice(pos, 1);
        panelRoot.selectedIndices = arr;
        panelRoot.selectedItemIndex = index;
        panelRoot.lastSelectedIndex = index;
    }

    function selectRange(fromIndex, toIndex) {
        var lo = Math.min(fromIndex, toIndex);
        var hi = Math.max(fromIndex, toIndex);
        var arr = [];
        for (let i = lo; i <= hi; i++)
            arr.push(i);
        panelRoot.selectedIndices = arr;
        panelRoot.selectedItemIndex = toIndex;
    }

    function getSelectedAssetIds() {
        var ids = [];
        if (!panelRoot.activeMediaBinModel)
            return ids;
        var indices = panelRoot.selectedIndices.length > 0 ? panelRoot.selectedIndices : (panelRoot.selectedItemIndex >= 0 ? [panelRoot.selectedItemIndex] : []);
        for (let i = 0; i < indices.length; i++) {
            let item = panelRoot.activeMediaBinModel.get(indices[i]);
            if (item && item.id)
                ids.push(item.id);
        }
        return ids;
    }

    function displayName(name, showExt) {
        var show = (typeof showExt !== "undefined") ? showExt : panelRoot.showExtensions;
        if (show || !name)
            return name ? name.toString() : "";
        var str = name.toString();
        var lastDot = str.lastIndexOf(".");
        return lastDot > 0 ? str.substring(0, lastDot) : str;
    }

    function triggerItemAnimation(targetIndex) {
        if (targetIndex < 0) return;
        var view = panelRoot.isListView ? listView : gridView;
        if (view && view.itemAtIndex) {
            var item = view.itemAtIndex(targetIndex);
            if (item && item.playEntranceAnim) {
                item.playEntranceAnim();
            }
        }
    }

    // function triggerFullTreeStaggerAnimation() {
    //     // 1. Re-enable the cascade gate for any newly mounted delegates
    //     panelRoot.allowEntranceCascade = true;
    //     cascadeResetTimer.restart();
    //
    //     // 2. Trigger stagger on all currently existing visual delegates
    //     var count = panelRoot.isListView ? listView.count : gridView.count;
    //     var view = panelRoot.isListView ? listView : gridView;
    //     if (!view) return;
    //
    //     for (var i = 0; i < count; i++) {
    //         var item = view.itemAtIndex ? view.itemAtIndex(i) : null;
    //         if (item) {
    //             // If using the delegate's internal staggered timer or entrance animation:
    //             if (item.playEntranceAnim) {
    //                 // Stagger each row by (i * 20ms) up to 260ms max
    //                 (function(targetItem, delay) {
    //                     var t = Qt.createQmlObject('import QtQuick 2.15; Timer { interval: ' + delay + '; repeat: false; running: true; onTriggered: { targetItem.playEntranceAnim(); destroy(); } }', panelRoot);
    //                 })(item, Math.min(i * 20, 260));
    //             }
    //         }
    //     }
    // }

  function triggerItemsAnimationByIds(ids) {
        if (!ids || ids.length === 0 || !panelRoot.activeMediaBinModel)
            return;

        // Use a deferred call so newly constructed delegates are ready in the view
        animDeferredTimer.targetIds = ids;
        animDeferredTimer.restart();
    }

    Timer {
        id: animDeferredTimer
        interval: 35
        repeat: false
        property var targetIds: []
        onTriggered: {
            var view = panelRoot.isListView ? listView : gridView;
            if (!view || !panelRoot.activeMediaBinModel)
                return;

            var count = panelRoot.isListView ? listView.count : gridView.count;
            for (let i = 0; i < count; i++) {
                let it = panelRoot.activeMediaBinModel.get(i);
                if (it && targetIds.indexOf(it.id) !== -1) {
                    let delegateItem = view.itemAtIndex ? view.itemAtIndex(i) : null;
                    if (delegateItem && delegateItem.playEntranceAnim) {
                        delegateItem.playEntranceAnim();
                    }
                }
            }
        }
    }

    // function reselectItemById(assetId) {
    //     if (!assetId || !panelRoot.activeMediaBinModel)
    //         return;
    //     var count = panelRoot.isListView ? listView.count : gridView.count;
    //     for (let i = 0; i < count; i++) {
    //         let it = panelRoot.activeMediaBinModel.get(i);
    //         if (it && it.id === assetId) {
    //             panelRoot.selectSingle(i);
    //             break;
    //         }
    //     }
    // }

    function reselectItemsByIds(assetIds) {
        if (!assetIds || assetIds.length === 0 || !panelRoot.activeMediaBinModel)
            return;
        var count = panelRoot.isListView ? listView.count : gridView.count;
        var newIndices = [];
        for (let i = 0; i < count; i++) {
            let it = panelRoot.activeMediaBinModel.get(i);
            if (it && assetIds.indexOf(it.id) !== -1) {
                newIndices.push(i);
            }
        }
        if (newIndices.length > 0) {
            panelRoot.selectedIndices = newIndices;
            panelRoot.selectedItemIndex = newIndices[0];
            panelRoot.lastSelectedIndex = newIndices[0];
        }
    }

    function reselectItemById(assetId) {
        if (!assetId || !panelRoot.activeMediaBinModel)
            return;
        var count = panelRoot.isListView ? listView.count : gridView.count;
        for (let i = 0; i < count; i++) {
            let it = panelRoot.activeMediaBinModel.get(i);
            if (it && it.id === assetId) {
                panelRoot.selectSingle(i);
                break;
            }
        }
    }

    Connections {
        target: panelRoot.activeMediaBinModel

        function onItemRenamed(id) {
            panelRoot.triggerItemsAnimationByIds([id]);
            panelRoot.reselectItemById(id);
        }

        function onItemsMoved(ids) {
            panelRoot.triggerItemsAnimationByIds(ids);
            if (ids && ids.length > 0) {
                // Re-select all moved items at their new visual indices
                panelRoot.reselectItemsByIds(ids);
            }
        }

        function onSortRoleChanged() {
            panelRoot.allowEntranceCascade = true;
            cascadeResetTimer.restart();
        }

        function onSortAscendingChanged() {
            panelRoot.allowEntranceCascade = true;
            cascadeResetTimer.restart();
        }

        function onSearchFilterChanged() {
            panelRoot.allowEntranceCascade = true;
            cascadeResetTimer.restart();
        }

        function onFolderExpanded(childIds) {
            if (childIds && childIds.length > 0) {
                panelRoot.triggerItemsAnimationByIds(childIds);
            }
        }

        // function onItemsMoved(ids) {
        //     panelRoot.triggerItemsAnimationByIds(ids);
        //     if (ids && ids.length > 0) {
        //         panelRoot.reselectItemById(ids[0]);
        //     }
        // }

        function onItemsAdded(ids) {
            panelRoot.triggerItemsAnimationByIds(ids);
        }

        function onCurrentBinIdChanged() {
            if (!panelRoot.isListView) {
                panelRoot.allowEntranceCascade = true;
                cascadeResetTimer.restart();
            }
        }
    }

    Item {
        id: globalDummyDragTarget
    }

    // Connections {
    //     target: panelRoot.activeMediaBinModel
    //
    //     function onItemRenamed(id) {
    //         if (!panelRoot.activeMediaBinModel) return;
    //         for (let i = 0; i < (panelRoot.isListView ? listView.count : gridView.count); i++) {
    //             let it = panelRoot.activeMediaBinModel.get(i);
    //             if (it && it.id === id) {
    //                 panelRoot.triggerItemAnimation(i);
    //                 break;
    //             }
    //         }
    //     }
    //
    //     function onItemsAdded(ids) {
    //         if (!ids || ids.length === 0 || !panelRoot.activeMediaBinModel) return;
    //         for (let i = 0; i < (panelRoot.isListView ? listView.count : gridView.count); i++) {
    //             let it = panelRoot.activeMediaBinModel.get(i);
    //             if (it && ids.indexOf(it.id) !== -1) {
    //                 panelRoot.triggerItemAnimation(i);
    //             }
    //         }
    //     }
    // }

function applyRubberBandSelection(x1, y1, x2, y2) {
        if (!panelRoot.activeMediaBinModel)
            return;
        var count = panelRoot.isListView ? listView.count : gridView.count;
        if (count === 0)
            return;

        var arr = [];

        if (panelRoot.isListView) {
            let rowH = 32 + listView.spacing;
            let currentView = listView;
            let cy1 = Math.max(0, y1 + currentView.contentY);
            let cy2 = Math.max(0, y2 + currentView.contentY);
            let firstRow = Math.max(0, Math.floor(cy1 / rowH));
            let lastRow = Math.min(count - 1, Math.floor(cy2 / rowH));
            for (let i = firstRow; i <= lastRow; i++) {
                arr.push(i);
            }
        } else {
            let cw = gridView.cellWidth;
            let ch = gridView.cellHeight;
            let itemsPerRow = Math.max(1, Math.floor(gridView.width / cw));
            let cy1g = Math.max(0, y1 + gridView.contentY);
            let cy2g = Math.max(0, y2 + gridView.contentY);
            let colFirst = Math.max(0, Math.floor(x1 / cw));
            let colLast = Math.min(itemsPerRow - 1, Math.floor(x2 / cw));
            let rowFirst = Math.max(0, Math.floor(cy1g / ch));
            let rowLast = Math.min(Math.ceil(count / itemsPerRow) - 1, Math.floor(cy2g / ch));
            for (let r = rowFirst; r <= rowLast; r++) {
                for (let c = colFirst; c <= colLast; c++) {
                    let idx = r * itemsPerRow + c;
                    if (idx >= 0 && idx < count)
                        arr.push(idx);
                }
            }
        }
        panelRoot.selectedIndices = arr;
        panelRoot.selectedItemIndex = arr.length > 0 ? arr[arr.length - 1] : -1;
    }
    // function applyRubberBandSelection(x1, y1, x2, y2) {
    //     if (!panelRoot.activeMediaBinModel)
    //         return;
    //     var count = panelRoot.isListView ? listView.count : gridView.count;
    //     var arr = [];
    //
    //     if (panelRoot.isListView) {
    //         let rowH = 36 + listView.spacing;
    //         let cy1 = y1 + listView.contentY, cy2 = y2 + listView.contentY;
    //         let firstRow = Math.max(0, Math.floor(cy1 / rowH));
    //         let lastRow = Math.min(count - 1, Math.ceil(cy2 / rowH));
    //         for (let i = firstRow; i <= lastRow; i++)
    //             arr.push(i);
    //     } else {
    //         let cw = gridView.cellWidth, ch = gridView.cellHeight;
    //         let itemsPerRow = Math.max(1, Math.floor(gridView.width / cw));
    //         let cy1g = y1 + gridView.contentY, cy2g = y2 + gridView.contentY;
    //         let colFirst = Math.max(0, Math.floor(x1 / cw));
    //         let colLast = Math.min(itemsPerRow - 1, Math.floor(x2 / cw));
    //         let rowFirst = Math.max(0, Math.floor(cy1g / ch));
    //         let rowLast = Math.floor(cy2g / ch);
    //         for (let r = rowFirst; r <= rowLast; r++) {
    //             for (let c = colFirst; c <= colLast; c++) {
    //                 let idx = r * itemsPerRow + c;
    //                 if (idx >= 0 && idx < count)
    //                     arr.push(idx);
    //             }
    //         }
    //     }
    //     panelRoot.selectedIndices = arr;
    //     panelRoot.selectedItemIndex = arr.length > 0 ? arr[arr.length - 1] : -1;
    // }

    function buildClipboardFromSelection(isCut) {
        let arr = [];
        if (!panelRoot.activeMediaBinModel)
            return arr;
        let ids = panelRoot.getSelectedAssetIds();
        for (let i = 0; i < ids.length; i++) {
            arr.push({
                id: ids[i],
                isCut: isCut
            });
        }
        return arr;
    }

    function urlToLocalPath(urlVal) {
        if (!urlVal)
            return "";
        let str = urlVal.toString().trim();
        if (str.startsWith("//"))
            return "";

        if (str.startsWith("file://")) {
            let path = str.replace(/^file:\/\//, "");
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
        onFolderSelected: function (paths) {
            panelRoot.editingIndex = -1;
            if (!panelRoot.activeMediaPool)
                return;
            
            let pathList = Array.isArray(paths) ? paths : [paths];
            let currentBin = panelRoot.activeMediaBinModel ? panelRoot.activeMediaBinModel.currentBinId : "root";
            
            let validPaths = pathList.map(p => {
                let cleanPath = p.toString();
                // Strip file:// prefix if coming from QML dialogs
                if (cleanPath.startsWith("file://")) {
                    cleanPath = decodeURIComponent(cleanPath.replace(/^file:\/\/\/?/, ""));
                    // Restore leading slash on Unix systems if stripped
                    if (Qt.platform.os !== "windows" && !cleanPath.startsWith("/")) {
                        cleanPath = "/" + cleanPath;
                    }
                }
                return cleanPath;
            }).filter(p => p.length > 0);

            if (validPaths.length > 0) {
                panelRoot.activeMediaPool.importFilesAsync(validPaths, currentBin);
            }
        }
    }

Connections {
    target: panelRoot.mediaPanelSettings

    function onDefaultViewChanged() {
        if (target) {
            panelRoot.isListView = (target.defaultView.toString().toLowerCase() === "list");
        }
    }

    function onShowFileExtensionsChanged() {
        if (target) {
            panelRoot.showExtensions = target.showFileExtensions;
        }
    }

    function onHoverScrubChanged() {
        if (target) {
            panelRoot.hoverScrubEnabled = target.hoverScrub;
        }
    }

    function onShowWaveformsChanged() {
        if (target) {
            panelRoot.showWaveforms = target.showWaveforms;
        }
    }

    function onShowTooltipsChanged() {
        if (target) {
            panelRoot.showTooltips = target.showTooltips;
        }
    }

    function onSortModeChanged() {
        if (target && target.sortMode) {
            var idx = sortComboBox.model.indexOf(target.sortMode);
            if (idx >= 0) {
                sortComboBox.currentIndex = idx;
                if (panelRoot.activeMediaBinModel) {
                    panelRoot.activeMediaBinModel.setSortRole(idx);
                }
            }
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

            for (let i = 0; i < panelRoot.clipboardAssets.length; i++) {
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
                let it = panelRoot.activeMediaBinModel.get(targetIdx);
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
            contextMenu.close();
            if (targetIdx >= 0) {
                panelRoot.editingIndex = targetIdx;
            }
        }

        onNewFolderRequested: {
            contextMenu.close();
            if (panelRoot.activeMediaBinModel) {
                var parentBin = "";
                var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
                if (targetIdx >= 0) {
                    var it = panelRoot.activeMediaBinModel.get(targetIdx);
                    if (it && it.isFolder) {
                        parentBin = it.id;
                    }
                }
                var newIdx = panelRoot.activeMediaBinModel.createFolder("New Folder", parentBin);
                if (newIdx >= 0) {
                    panelRoot.selectSingle(newIdx);
                    // Defer setting editingIndex by 1 tick so delegate mounts first and triggers onVisibleChanged
                    newFolderTimer.targetIndex = newIdx;
                    newFolderTimer.restart();
                }
            }
        }
        // onNewFolderRequested: {
        //     contextMenu.close();
        //     if (panelRoot.activeMediaBinModel) {
        //         var parentBin = "";
        //         var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
        //         if (targetIdx >= 0) {
        //             var it = panelRoot.activeMediaBinModel.get(targetIdx);
        //             if (it && it.isFolder) {
        //                 parentBin = it.id;
        //             }
        //         }
        //         let newIdx = panelRoot.activeMediaBinModel.createFolder("New Folder", parentBin);
        //         if (newIdx >= 0) {
        //             panelRoot.selectSingle(newIdx);
        //             panelRoot.editingIndex = newIdx;
        //         }
        //     }
        // }
        // onRenameRequested: {
        //     var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
        //     contextMenu.close();
        //     if (targetIdx >= 0) {
        //         renameFocusTimer.targetIndex = targetIdx;
        //         renameFocusTimer.restart();
        //     }
        // }

        Timer {
            id: renameFocusTimer
            interval: 35
            repeat: false
            property int targetIndex: -1
            onTriggered: {
                if (targetIndex >= 0) {
                    panelRoot.selectSingle(targetIndex);
                    panelRoot.editingIndex = targetIndex;
                }
            }
        }
        // onRenameRequested: {
        //     var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
        //     if (targetIdx >= 0) {
        //         panelRoot.editingIndex = targetIdx;
        //     }
        // }

        onDeleteRequested: {
            panelRoot.editingIndex = -1;
            if (panelRoot.activeMediaBinModel) {
                let ids = panelRoot.getSelectedAssetIds();
                if (ids.length > 0) {
                    panelRoot.activeMediaBinModel.removeAssetsById(ids);
                    panelRoot.clearSelection();
                }
            }
        }

        // onNewFolderRequested: {
        //     if (!panelRoot.activeMediaBinModel)
        //         return;
        //
        //     contextMenu.close();
        //
        //     var parentBin = "";
        //     var selectedIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
        //
        //     if (selectedIdx >= 0) {
        //         var selectedItem = panelRoot.activeMediaBinModel.get(selectedIdx);
        //         if (selectedItem && selectedItem.isFolder) {
        //             parentBin = selectedItem.id;
        //         }
        //     }
        //
        //     var newIdx = panelRoot.activeMediaBinModel.createFolder("New Folder", parentBin);
        //     if (newIdx >= 0) {
        //         newFolderFocusTimer.targetIndex = newIdx;
        //         newFolderFocusTimer.restart();
        //     }
        // }
        // onNewFolderRequested: {
        //     if (!panelRoot.activeMediaBinModel)
        //         return;
        //
        //     var parentBin = "";
        //     var selectedIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
        //
        //     if (selectedIdx >= 0) {
        //         var selectedItem = panelRoot.activeMediaBinModel.get(selectedIdx);
        //         if (selectedItem && selectedItem.isFolder) {
        //             parentBin = selectedItem.id;
        //         }
        //     }
        //
        //     var newIdx = panelRoot.activeMediaBinModel.createFolder("New Folder", parentBin);
        //     if (newIdx >= 0) {
        //         panelRoot.selectSingle(newIdx);
        //         panelRoot.editingIndex = newIdx;
        //         var item = panelRoot.activeMediaBinModel.get(newIdx);
        //         if (item && item.id) {
        //             panelRoot.triggerItemsAnimationByIds([item.id]);
        //         }
        //     }
        // }

        onSelectAllRequested: {
            panelRoot.editingIndex = -1;
            let count = panelRoot.isListView ? listView.count : gridView.count;
            if (count > 0) {
                let arr = [];
                for (let i = 0; i < count; i++)
                    arr.push(i);
                panelRoot.selectedIndices = arr;
                panelRoot.selectedItemIndex = arr[arr.length - 1];
                panelRoot.lastSelectedIndex = arr[arr.length - 1];
            }
        }

        onPropertiesRequested: {
            panelRoot.editingIndex = -1;
            let targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
            if (panelRoot.activeMediaBinModel && targetIdx >= 0) {
                let propItem = panelRoot.activeMediaBinModel.get(targetIdx);
                if (propItem) {
                    // propPopup.assetName = propItem.name || "Unknown";
                    // propPopup.assetPath = propItem.path || "-";
                    // propPopup.assetDuration = propItem.duration || "-";
                    // propPopup.assetResolution = propItem.resolution || "-";
                    // propPopup.assetType = propItem.isFolder ? "Folder Bin" : "Media Clip";
                    // propPopup.isFolder = propItem.isFolder || false;
                    // propPopup.openAt(contextMenu.x, contextMenu.y);
                }
            }
        }
    }

    Timer {
        id: newFolderTimer
        interval: 35
        repeat: false
        property int targetIndex: -1
        onTriggered: {
            if (targetIndex >= 0) {
                panelRoot.editingIndex = targetIndex;
            }
        }
    }
    // Timer {
    //     id: newFolderFocusTimer
    //     interval: 60
    //     repeat: false
    //     property int targetIndex: -1
    //     onTriggered: {
    //         if (targetIndex >= 0 && panelRoot.activeMediaBinModel) {
    //             panelRoot.selectSingle(targetIndex);
    //             panelRoot.editingIndex = targetIndex;
    //             var item = panelRoot.activeMediaBinModel.get(targetIndex);
    //             if (item && item.id) {
    //                 panelRoot.triggerItemsAnimationByIds([item.id]);
    //             }
    //         }
    //     }
    // }

    // Properties Popup (Studio Inspector)
    // FIX: Refine Properties popup and Re-enable it here
    // XylaPropertiesDialog {
    //   id: propPopup
    // }

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
    if (panelRoot.mediaPanelSettings) {
        panelRoot.mediaPanelSettings.defaultView = isListView ? "list" : "grid";
    }
}

onGridCellSizeChanged: {
    if (settingsPopup.gridCellSize > 0) {
        panelRoot.gridCellSize = settingsPopup.gridCellSize;
    }
}

onHoverScrubToggled: function (enabled) {
    panelRoot.hoverScrubEnabled = enabled;
    if (panelRoot.mediaPanelSettings) {
        panelRoot.mediaPanelSettings.hoverScrub = enabled;
    }
}

onShowWaveformsToggled: function (enabled) {
    panelRoot.showWaveforms = enabled;
    if (panelRoot.mediaPanelSettings) {
        panelRoot.mediaPanelSettings.showWaveforms = enabled;
    }
}

onShowExtensionsToggled: function (enabled) {
    panelRoot.showExtensions = enabled;
    if (panelRoot.mediaPanelSettings) {
        panelRoot.mediaPanelSettings.showFileExtensions = enabled;
    }
}

onGroupByMediaTypeRequested: {
    if (panelRoot.activeMediaBinModel) {
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
    
    if (panelRoot.mediaPanelSettings) {
        panelRoot.mediaPanelSettings.sortMode = field;
    }

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

currentIndex: {
    var settings = panelRoot.mediaPanelSettings;
    if (!settings || !settings.sortMode)
        return 0;

    var idx = model.indexOf(settings.sortMode);
    return idx >= 0 ? idx : 0;
}

onActivated: function (index) {
    panelRoot.editingIndex = -1;

    if (panelRoot.mediaPanelSettings) {
        panelRoot.mediaPanelSettings.sortMode = model[index];
    }

    if (panelRoot.activeMediaBinModel) {
        panelRoot.activeMediaBinModel.setSortRole(index);
    }
}
    // currentIndex: {
    //     if (!panelRoot.activeMediaBinModel ||
    //         !panelRoot.activeMediaBinModel.mediaPanelSettings)
    //         return 0;
    //
    //     var mode =
    //         panelRoot.activeMediaBinModel.mediaPanelSettings.sortMode;
    //
    //     return model.indexOf(mode) >= 0
    //             ? model.indexOf(mode)
    //             : 0;
    // }
    //
    // onActivated: function (index) {
    //     panelRoot.editingIndex = -1;
    //
    //     if (!panelRoot.activeMediaBinModel)
    //         return;
    //
    //     var settings =
    //         panelRoot.activeMediaBinModel.mediaPanelSettings;
    //
    //     if (settings)
    //         settings.sortMode = model[index];
    //
    //     // Keep the actual model sorting in sync.
    //     panelRoot.activeMediaBinModel.setSortRole(index);
    // }
}
            // XylaSelect {
            //     id: sortComboBox
            //     // Layout.preferredWidth: 95
            //     // implicitHeight: 30
            //     icon: "qrc:/assets/icons/sort.svg"
            //     activeFocusOnTab: false
            //     model: ["Name", "Duration", "Path"]
            //     onActivated: function (index) {
            //         panelRoot.editingIndex = -1;
            //         if (!panelRoot.activeMediaBinModel)
            //             return;
            //         panelRoot.activeMediaBinModel.setSortRole(index);
            //     }
            // }

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

    options: [
        {
            icon: "qrc:/assets/icons/list.svg",
            value: "list"
        },
        {
            icon: "qrc:/assets/icons/layout-grid.svg",
            value: "grid"
        }
    ]

    // Declarative binding to root UI state
    currentIndex: panelRoot.isListView ? 0 : 1

    onOptionSelected: (index, value) => {
        panelRoot.editingIndex = -1;

        var isList = (value === "list");
        panelRoot.isListView = isList;

        if (panelRoot.mediaPanelSettings) {
            panelRoot.mediaPanelSettings.defaultView = value;
        }
    }
}
// XylaSegmentedToggle {
//     id: viewModeToggle
//
//     implicitHeight: 30
//
//     options: [
//         {
//             icon: "qrc:/assets/icons/list.svg",
//             value: "list"
//         },
//         {
//             icon: "qrc:/assets/icons/layout-grid.svg",
//             value: "grid"
//         }
//     ]
//
//     currentIndex: {
//         if (!panelRoot.activeMediaBinModel ||
//             !panelRoot.activeMediaBinModel.mediaPanelSettings)
//             return panelRoot.isListView ? 0 : 1;
//
//         return panelRoot.activeMediaBinModel.mediaPanelSettings.defaultView === "list"
//                 ? 0
//                 : 1;
//     }
//
//     onOptionSelected: (index, value) => {
//         panelRoot.editingIndex = -1;
//
//         panelRoot.isListView = (value === "list");
//
//         if (!panelRoot.activeMediaBinModel)
//             return;
//
//         var settings =
//             panelRoot.activeMediaBinModel.mediaPanelSettings;
//
//         if (settings)
//             settings.defaultView = value;
//     }
// }
            // XylaSegmentedToggle {
            //     id: viewModeToggle
            //     implicitHeight: 30
            //     currentIndex: panelRoot.isListView ? 0 : 1
            //     options: [
            //         {
            //             icon: "qrc:/assets/icons/list.svg",
            //             value: "list"
            //         },
            //         {
            //             icon: "qrc:/assets/icons/layout-grid.svg",
            //             value: "grid"
            //         }
            //     ]
            //     onOptionSelected: (index, value) => {
            //         panelRoot.editingIndex = -1;
            //         panelRoot.isListView = (value === "list");
            //     }
            // }

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
                                // Only force focus if searchPopup is explicitly opened AND user didn't enter editing mode
                                if (!activeFocus && searchPopup.opened && panelRoot.editingIndex === -1) {
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

                            Keys.onReturnPressed: event => {
                                searchPopup.close();
                                event.accepted = true;
                            }

                            Keys.onEnterPressed: event => {
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
                    if (drop.source !== null)
                        return;
                    drop.accept(Qt.CopyAction);

                    if (!drop.hasUrls || drop.urls.length === 0 || !panelRoot.activeMediaPool)
                        return;

                    var rawPaths = [];
                    for (let i = 0; i < drop.urls.length; i++) {
                        let localPath = panelRoot.urlToLocalPath(drop.urls[i]);
                        if (localPath.length > 0)
                            rawPaths.push(localPath);
                    }

                    if (rawPaths.length === 0)
                        return;

                    var currentBin = panelRoot.isListView ? "root" : (panelRoot.activeMediaBinModel ? panelRoot.activeMediaBinModel.currentBinId : "root");
                    panelRoot.activeMediaPool.importFilesAsync(rawPaths, currentBin);
                }

                MouseArea {
                    id: rubberBandArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    z: 15
                    preventStealing: selecting
                    propagateComposedEvents: true

                    property real startX: 0
                    property real startY: 0
                    property bool selecting: false

                    onPressed: function (mouse) {
                        startX = mouse.x;
                        startY = mouse.y;
                        selecting = false;
                        panelRoot.editingIndex = -1;
                        mouse.accepted = false; // allow clicks to propagate through to items if not dragging
                    }

                    onPositionChanged: function (mouse) {
                        if (!selecting && (Math.abs(mouse.x - startX) > 6 || Math.abs(mouse.y - startY) > 6)) {
                            selecting = true;
                            if (!(mouse.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.MetaModifier))) {
                                panelRoot.clearSelection();
                            }
                        }
                        if (selecting) {
                            let x1 = Math.min(startX, mouse.x), x2 = Math.max(startX, mouse.x);
                            let y1 = Math.min(startY, mouse.y), y2 = Math.max(startY, mouse.y);
                            selectionRect.x = x1;
                            selectionRect.y = y1;
                            selectionRect.width = x2 - x1;
                            selectionRect.height = y2 - y1;

                            // Map coordinates to stack view container
                            var targetView = panelRoot.isListView ? listView : gridView;
                            var localPt1 = mapToItem(targetView, x1, y1);
                            var localPt2 = mapToItem(targetView, x2, y2);
                            panelRoot.applyRubberBandSelection(localPt1.x, localPt1.y, localPt2.x, localPt2.y);
                        }
                    }

                    onReleased: function (mouse) {
                        if (selecting) {
                            selecting = false;
                            selectionRect.width = 0;
                            selectionRect.height = 0;
                            mouse.accepted = true;
                        } else {
                            mouse.accepted = false;
                        }
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

                    anchors.topMargin: searchPopup.visible ? 28 : 0

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
                            onTapped: function (eventPoint, button) {
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

                        // Item {
                        //     id: dragPreview
                        //
                        //     parent: Overlay.overlay
                        //
                        //     width: 64
                        //     height: 64
                        //
                        //     visible: false
                        //     z: 100000
                        //
                        //     property bool isFolder: false
                        //     property string path: ""
                        //
                        //     scale: visible ? 1.0 : 0.85
                        //
                        //     Rectangle {
                        //         id: dragPreviewBackground
                        //
                        //         anchors.fill: parent
                        //
                        //         radius: 10
                        //         color: "#252525"
                        //
                        //         border.width: 1
                        //         border.color: "#404040"
                        //
                        //         clip: true
                        //
                        //         Image {
                        //             id: dragPreviewImage
                        //
                        //             anchors.fill: parent
                        //             anchors.margins: 8
                        //
                        //             source: dragPreview.isFolder
                        //                     ? "qrc:/assets/icons/folder.svg"
                        //                     : (dragPreview.path
                        //                        ? "image://thumbnails/"
                        //                          + dragPreview.path
                        //                          + "?width=120"
                        //                        : "qrc:/assets/icons/crop-landscape.svg")
                        //
                        //             fillMode: Image.PreserveAspectFit
                        //             smooth: true
                        //
                        //             layer.enabled: true
                        //
                        //             layer.effect: MultiEffect {
                        //                 maskEnabled: true
                        //
                        //                 maskSource: Rectangle {
                        //                     width: dragPreviewImage.width
                        //                     height: dragPreviewImage.height
                        //                     radius: 7
                        //                 }
                        //             }
                        //         }
                        //     }
                        //
                        //     Behavior on scale {
                        //         NumberAnimation {
                        //             duration: 120
                        //             easing.type: Easing.OutCubic
                        //         }
                        //     }
                        // }
                        // ADDED: Outer/Background DropArea to catch drops outside any item/folder
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

                            // 3. Stagger only runs on initial load / view mode switch
                            Component.onCompleted: {
                                if (panelRoot.editingIndex === index) {
                                    grabFocus();
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
                        // delegate: Item {
                        //     id: listDelegateContainer
                        //     width: listView.width
                        //     height: model.isFolder ? 32 : 60
                        //
                        //     readonly property int stepSize: 20
                        //     readonly property int depthVal: model.depth || 0
                        //     readonly property int cardIndent: depthVal * stepSize + (depthVal > 0 ? 6 : 0)
                        //
                        //     property real itemScale: 1.0
                        //     property real itemOpacity: 1.0
                        //     scale: itemScale
                        //     opacity: itemOpacity
                        //     transformOrigin: Item.Left
                        //
                        //     function playEntranceAnim() {
                        //         listEntranceAnim.restart();
                        //     }
                        //
                        //     Component.onCompleted: {
                        //         // Stagger initial load animation slightly per row
                        //         listStaggerTimer.interval = Math.min(index * 20, 240);
                        //         listStaggerTimer.start();
                        //     }
                        //
                        //     Timer {
                        //         id: listStaggerTimer
                        //         repeat: false
                        //         onTriggered: listEntranceAnim.restart()
                        //     }
                        //
                        //     ParallelAnimation {
                        //         id: listEntranceAnim
                        //         NumberAnimation {
                        //             target: listDelegateContainer
                        //             property: "itemScale"
                        //             from: 0.88
                        //             to: 1.0
                        //             duration: 180
                        //             easing.type: Easing.OutBack
                        //             easing.overshoot: 1.25
                        //         }
                        //         NumberAnimation {
                        //             target: listDelegateContainer
                        //             property: "itemOpacity"
                        //             from: 0.0
                        //             to: 1.0
                        //             duration: 150
                        //             easing.type: Easing.OutQuad
                        //         }
                        //     }

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

                        // delegate: Rectangle {
                        //     id: listDelegateItem
                        //     property int itemIndex: index
                        //     width: listView.width
                        //     height: model.isFolder ? 32 : 60
                        //     radius: 5
                        //     color: listDropOnFolder.containsDrag ? "#233554" : (panelRoot.isSelected(index) ? panelRoot.bgCardSelected : (itemMouseArea.containsMouse ? panelRoot.bgCardHover : "#1a1a1c")) // "transparent"))
                        //     border.color: listDropOnFolder.containsDrag ? "#4d88e8" : (panelRoot.isSelected(index) ? panelRoot.accentColor : "transparent")
                        //     border.width: 1
                        //
                        //     Drag.active: itemMouseArea.drag.active
                        //     Drag.dragType: Drag.Automatic
                        //     Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
                        //     Drag.keys: ["xyla/media-asset", "text/uri-list"]
                        //     Drag.source: listDelegateItem
                        //     Drag.mimeData: {
                        //         "xyla/media-asset": model.id || "",
                        //         "text/uri-list": model.path ? (model.path.startsWith("file://") ? model.path : "file://" + model.path) : ""
                        //     }
                        //     // FIX: The Drag image fix here
                        //     Drag.imageSource: model.isFolder ? "qrc:/assets/icons/folder.svg" : (model.path ? ("image://thumbnails/" + model.path + "?width=40") : "qrc:/assets/icons/crop-landscape.svg")
                        //     Drag.hotSpot.x: 20
                        //     Drag.hotSpot.y: 20

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
                                        // root.clearSelection();
                                        root.draggedAssetIds = [];
                                    }
                                }

                                // onDropped: function (drop) {
                                //     if (!model.isFolder || panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
                                //         drop.accepted = false;
                                //         return;
                                //     }
                                //     drop.accept(Qt.MoveAction);
                                //     var targetFolderId = model.id;
                                //     var root = panelRoot;
                                //     if (root && root.draggedAssetIds.length > 0 && root.activeMediaBinModel) {
                                //         root.activeMediaBinModel.moveAssetsById(root.draggedAssetIds, targetFolderId);
                                //         root.clearSelection();
                                //         root.draggedAssetIds = [];
                                //     }
                                // }
                                // onDropped: function (drop) {
                                //     if (!model.isFolder || panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
                                //         drop.accepted = false;
                                //         return;
                                //     }
                                //     // if (panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
                                //     //     drop.accepted = false;
                                //     //     return;
                                //     // }
                                //     drop.accept(Qt.MoveAction);
                                //     var targetFolderId = model.id;
                                //     if (panelRoot.draggedAssetIds.length > 0 && panelRoot.activeMediaBinModel) {
                                //         panelRoot.activeMediaBinModel.moveAssetsById(panelRoot.draggedAssetIds, targetFolderId);
                                //         panelRoot.clearSelection();
                                //         panelRoot.draggedAssetIds = [];
                                //     }
                                // }
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
            if (panelRoot.activeMediaBinModel) {
                panelRoot.activeMediaBinModel.toggleFolderExpanded(model.id);
            }
        }
    }
}
// Item {
//     Layout.preferredWidth: 10
//     Layout.preferredHeight: 10
//     visible: model.isFolder
//
//     Item {
//         id: chevronContainer
//         anchors.fill: parent
//         rotation: model.isExpanded ? 0 : 270
//
//         Behavior on rotation {
//             NumberAnimation {
//                 duration: 160
//                 easing.type: Easing.OutCubic
//             }
//         }
//
//         Image {
//             id: chevronIcon
//             anchors.fill: parent
//             source: "qrc:/assets/icons/chevron-down.svg"
//             fillMode: Image.PreserveAspectFit
//             smooth: true
//             visible: false
//         }
//
//         MultiEffect {
//             source: chevronIcon
//             anchors.fill: chevronIcon
//             colorization: 1.0
//             colorizationColor: treeChevronMouse.containsMouse ? "#ffffff" : "#808080"
//
//             Behavior on colorizationColor {
//                 ColorAnimation {
//                     duration: 120
//                 }
//             }
//         }
//     }
//
//     MouseArea {
//         id: treeChevronMouse
//         anchors.fill: parent
//         hoverEnabled: true
//         cursorShape: Qt.PointingHandCursor
//         onClicked: {
//             if (panelRoot.activeMediaBinModel) {
//                 panelRoot.activeMediaBinModel.toggleFolderExpanded(model.id);
//             }
//         }
//     }
// }

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
                                    visible: panelRoot.editingIndex !== index
                                    text: model.isFolder ? (model.name || "") : panelRoot.displayName(model.name || "", panelRoot.showExtensions)
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
                                    Keys.onEscapePressed: panelRoot.editingIndex = -1

                                    function commitRename() {
                                        if (panelRoot.editingIndex === index && panelRoot.activeMediaBinModel) {
                                            let newName = text.trim();
                                            panelRoot.editingIndex = -1;
                                            if (newName !== "" && newName !== model.name) {
                                                panelRoot.activeMediaBinModel.renameAsset(index, newName);
                                            }
                                        } else {
                                            panelRoot.editingIndex = -1;
                                        }
                                    }
                                }
                                // TextField {
                                //     id: renameField
                                //     visible: panelRoot.editingIndex === index
                                //     Layout.fillWidth: true
                                //     z: 20
                                //     text: model.name || ""
                                //     font.pixelSize: 12
                                //     color: "#ffffff"
                                //     selectByMouse: true
                                //     focus: visible
                                //     background: Rectangle {
                                //         color: "#121212"
                                //         // border.color: panelRoot.accentColor
                                //         // border.width: 1.5
                                //         radius: 6
                                //     }
                                //
                                //     property bool isReady: false
                                //
                                //     function grabFocus() {
                                //         renameField.forceActiveFocus();
                                //         renameField.selectAll();
                                //     }
                                //
                                //     onVisibleChanged: {
                                //         if (visible) {
                                //             isReady = false;
                                //             text = model.name || "";
                                //             grabFocus();
                                //             listFocusTimer.restart();
                                //         } else {
                                //             isReady = false;
                                //         }
                                //     }
                                //
                                //     Timer {
                                //         id: listFocusTimer
                                //         interval: 160
                                //         repeat: false
                                //         onTriggered: {
                                //             if (renameField.visible) {
                                //                 renameField.grabFocus();
                                //                 renameField.isReady = true;
                                //             }
                                //         }
                                //     }
                                //
                                //     onActiveFocusChanged: {
                                //         if (!activeFocus && isReady && visible) {
                                //             commitRename();
                                //         }
                                //     }
                                //
                                //     Keys.onReturnPressed: commitRename()
                                //     Keys.onEnterPressed: commitRename()
                                //     Keys.onEscapePressed: panelRoot.editingIndex = -1
                                //
                                //     function commitRename() {
                                //         if (panelRoot.editingIndex === index && panelRoot.activeMediaBinModel) {
                                //             let newName = text.trim();
                                //             panelRoot.editingIndex = -1;
                                //             if (newName !== "" && newName !== model.name) {
                                //                 panelRoot.activeMediaBinModel.renameAsset(index, newName);
                                //             }
                                //         } else {
                                //             panelRoot.editingIndex = -1;
                                //         }
                                //     }
                                // }

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
                                enabled: panelRoot.editingIndex === -1
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                drag.target: globalDummyDragTarget
                                drag.threshold: 5

                                // Item {
                                //     id: listDummyDragTarget
                                // }

                                onPressed: function (mouse) {
                                    // dragPreview.visible = false;

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
                                // onPressed: function (mouse) {
                                //     dragPreview.isFolder = model.isFolder
                                //     dragPreview.path = model.path
                                //     dragPreview.visible = true
                                //
                                //     if (panelRoot.editingIndex !== -1 && panelRoot.editingIndex !== index) {
                                //         panelRoot.editingIndex = -1;
                                //     }
                                //     if (mouse.button === Qt.LeftButton) {
                                //         if (mouse.modifiers & Qt.ShiftModifier && panelRoot.lastSelectedIndex >= 0) {
                                //             panelRoot.selectRange(panelRoot.lastSelectedIndex, index);
                                //         } else if (mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) {
                                //             panelRoot.toggleSelect(index);
                                //         } else if (!panelRoot.isSelected(index)) {
                                //             panelRoot.selectSingle(index);
                                //         }
                                //
                                //         panelRoot.draggedAssetIds = panelRoot.getSelectedAssetIds();
                                //         panelRoot.dragPreviewName = model.name || "";
                                //         panelRoot.dragPreviewPath = model.path || "";
                                //         panelRoot.dragPreviewIsFolder = model.isFolder;
                                //         panelRoot.dragCount = Math.max(1, panelRoot.selectedIndices.length);
                                //     }
                                // }

                                onPositionChanged: function (mouse) {
                                    if (!itemMouseArea.drag.active)
                                        return;

                                    var pt = itemMouseArea.mapToItem(
                                        Overlay.overlay,
                                        mouse.x,
                                        mouse.y
                                    );

                                    // dragPreview.x = pt.x + 14;
                                    // dragPreview.y = pt.y + 14;

                                    // listDelegateItem.Drag.active = true;
                                    panelRoot.isCustomDragging = true;

                                    panelRoot.dragGlobalX = pt.x;
                                    panelRoot.dragGlobalY = pt.y;

                                    // Only becomes visible after the drag threshold is crossed.
                                    // if (!dragPreview.visible) {
                                    //     dragPreview.isFolder = model.isFolder;
                                    //     dragPreview.path = model.path || "";
                                    //     dragPreview.visible = true;
                                    // }
                                }
                                // onPositionChanged: function (mouse) {
                                //     if (pressed) {
                                //         dragPreview.x = mouse.x + 14
                                //         dragPreview.y = mouse.y + 14
                                //     }
                                //
                                //     if (itemMouseArea.drag.active) {
                                //         listDelegateItem.Drag.active = true;
                                //         panelRoot.isCustomDragging = true;
                                //         var pt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                //         panelRoot.dragGlobalX = pt.x;
                                //         panelRoot.dragGlobalY = pt.y;
                                //     }
                                // }

                                onReleased: function (mouse) {
                                    // listDelegateItem.Drag.active = false;
                                    panelRoot.isCustomDragging = false;
                                    // dragPreview.visible = false;
                                }

                                onCanceled: {
                                    // listDelegateItem.Drag.active = false;
                                    panelRoot.isCustomDragging = false;
                                    // dragPreview.visible = false;
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
                                        let globalPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
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
                        }

                        XylaMediaPanelEmpty {
                            visible: listView.count === 0
                        }
                        // Text {
                        //     anchors.centerIn: parent
                        //     text: "No Media Assets Loaded\n(Drag & Drop files here or right-click to import)"
                        //     horizontalAlignment: Text.AlignHCenter
                        //     color: "#505050"
                        //     font.pixelSize: 12
                        //     visible: listView.count === 0
                        // }
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
                            onTapped: function (eventPoint, button) {
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
                                if (panelRoot.editingIndex === index) {
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
                        // delegate: Item {
                        //     id: gridDelegateItem
                        //     property int itemIndex: index
                        //     width: gridView.cellWidth
                        //     height: gridView.cellHeight
                        //
                        //     property real cardScale: 1.0
                        //     property real cardOpacity: 1.0
                        //     scale: cardScale
                        //     opacity: cardOpacity
                        //     transformOrigin: Item.Center
                        //
                        //     function playEntranceAnim() {
                        //         entranceAnim.restart();
                        //     }
                        //
                        //     Component.onCompleted: {
                        //         gridStaggerTimer.interval = Math.min(index * 25, 300);
                        //         gridStaggerTimer.start();
                        //     }
                        //
                        //     Timer {
                        //         id: gridStaggerTimer
                        //         repeat: false
                        //         onTriggered: entranceAnim.restart()
                        //     }
                        //
                        //     ParallelAnimation {
                        //         id: entranceAnim
                        //         NumberAnimation {
                        //             target: gridDelegateItem
                        //             property: "cardScale"
                        //             from: 0.82
                        //             to: 1.0
                        //             duration: 190
                        //             easing.type: Easing.OutBack
                        //             easing.overshoot: 1.35
                        //         }
                        //         NumberAnimation {
                        //             target: gridDelegateItem
                        //             property: "cardOpacity"
                        //             from: 0.0
                        //             to: 1.0
                        //             duration: 160
                        //             easing.type: Easing.OutQuad
                        //         }
                        //     }

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
                                // onEntered: function (drag) {
                                //     if (panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
                                //         drag.accepted = false;
                                //         return;
                                //     }
                                //     drag.accept(Qt.MoveAction);
                                // }
                                //
                                // onDropped: function (drop) {
                                //     if (panelRoot.draggedAssetIds.indexOf(model.id) !== -1) {
                                //         drop.accepted = false;
                                //         return;
                                //     }
                                //     drop.accept(Qt.MoveAction);
                                //     var targetFolderId = model.id;
                                //     if (panelRoot.draggedAssetIds.length > 0 && panelRoot.activeMediaBinModel) {
                                //         panelRoot.activeMediaBinModel.moveAssetsById(panelRoot.draggedAssetIds, targetFolderId);
                                //         panelRoot.clearSelection();
                                //         panelRoot.draggedAssetIds = [];
                                //     }
                                // }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 10
                                radius: 12
                                color: gridDropOnFolder.containsDrag ? "#233554" : (panelRoot.isSelected(index) ? "#1c2538" : (cardMouseArea.containsMouse ? "#222225" : panelRoot.bgCard))
                                border.color: gridDropOnFolder.containsDrag ? "#4d88e8" : (panelRoot.isSelected(index) ? "#2555D3" : (cardMouseArea.containsMouse ? "#3a3a3d" : "#28282a"))
                                border.width: (panelRoot.isSelected(index) || gridDropOnFolder.containsDrag) ? 1.5 : 1

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
                                    spacing: panelRoot.editingIndex === index ? 6 : 8

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
                                        Layout.bottomMargin: 4
                                        Layout.topMargin: 2
                                        Layout.fillWidth: true
                                        text: model.isFolder ? (model.name || "") : panelRoot.displayName(model.name || "", panelRoot.showExtensions)
                                        color: panelRoot.isSelected(index) ? "#ffffff" : "#c4c4c4"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    // Text {
                                    //     id: gridNameText
                                    //     visible: panelRoot.editingIndex !== index
                                    //     // Layout.bottomMargin: 2
                                    //     Layout.bottomMargin: 4
                                    //     Layout.topMargin: 2
                                    //     Layout.fillWidth: true
                                    //     text: model.isFolder ? (model.name || "") : panelRoot.displayName(model.name || "")
                                    //     color: panelRoot.isSelected(index) ? "#ffffff" : "#c4c4c4"
                                    //     font.pixelSize: 11
                                    //     elide: Text.ElideRight
                                    //     horizontalAlignment: Text.AlignHCenter
                                    // }

TextField {
                                        id: gridRenameField
                                        visible: panelRoot.editingIndex === index
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
                                        Keys.onEscapePressed: panelRoot.editingIndex = -1

                                        function commitRename() {
                                            if (panelRoot.editingIndex === index && panelRoot.activeMediaBinModel) {
                                                let newName = text.trim();
                                                panelRoot.editingIndex = -1;
                                                if (newName !== "" && newName !== model.name) {
                                                    panelRoot.activeMediaBinModel.renameAsset(index, newName);
                                                }
                                            } else {
                                                panelRoot.editingIndex = -1;
                                            }
                                        }
                                    }
                                    // TextField {
                                    //     id: gridRenameField
                                    //     visible: panelRoot.editingIndex === index
                                    //     // Layout.bottomMargin: 2
                                    //     Layout.fillWidth: true
                                    //     z: 20
                                    //     text: model.name || ""
                                    //     font.pixelSize: 11
                                    //     color: "#ffffff"
                                    //     horizontalAlignment: Text.AlignHCenter
                                    //     selectByMouse: true
                                    //     focus: visible
                                    //     background: Rectangle {
                                    //         color: "#121212"
                                    //         // border.color: panelRoot.accentColor
                                    //         // border.width: 1.5
                                    //         radius: 6
                                    //     }
                                    //
                                    //     property bool isReady: false
                                    //
                                    //     function grabFocus() {
                                    //         gridRenameField.forceActiveFocus();
                                    //         gridRenameField.selectAll();
                                    //     }
                                    //
                                    //     onVisibleChanged: {
                                    //         if (visible) {
                                    //             isReady = false;
                                    //             text = model.name || "";
                                    //             grabFocus();
                                    //             gridFocusTimer.restart();
                                    //         } else {
                                    //             isReady = false;
                                    //         }
                                    //     }
                                    //
                                    //     Timer {
                                    //         id: gridFocusTimer
                                    //         interval: 160
                                    //         repeat: false
                                    //         onTriggered: {
                                    //             if (gridRenameField.visible) {
                                    //                 gridRenameField.grabFocus();
                                    //                 gridRenameField.isReady = true;
                                    //             }
                                    //         }
                                    //     }
                                    //
                                    //     onActiveFocusChanged: {
                                    //         if (!activeFocus && isReady && visible) {
                                    //             commitRename();
                                    //         }
                                    //     }
                                    //
                                    //     Keys.onReturnPressed: commitRename()
                                    //     Keys.onEnterPressed: commitRename()
                                    //     Keys.onEscapePressed: panelRoot.editingIndex = -1
                                    //
                                    //     function commitRename() {
                                    //         if (panelRoot.editingIndex === index && panelRoot.activeMediaBinModel) {
                                    //             let newName = text.trim();
                                    //             panelRoot.editingIndex = -1;
                                    //             if (newName !== "" && newName !== model.name) {
                                    //                 panelRoot.activeMediaBinModel.renameAsset(index, newName);
                                    //             }
                                    //         } else {
                                    //             panelRoot.editingIndex = -1;
                                    //         }
                                    //     }
                                    // }
                                }
                            }

                            MouseArea {
                                id: cardMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: panelRoot.editingIndex === -1
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                drag.target: globalDummyDragTarget
                                drag.threshold: 5

                                // Item {
                                //     id: gridDummyDragTarget
                                // }

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
                                            // gridDelegateItem.Drag.active = true;
                                        }
                                        panelRoot.isCustomDragging = true;
                                        let pt = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                        panelRoot.dragGlobalX = pt.x;
                                        panelRoot.dragGlobalY = pt.y;
                                    }
                                }

                                onReleased: function (mouse) {
                                    // gridDelegateItem.Drag.active = false;
                                    panelRoot.isCustomDragging = false;
                                }
                                onCanceled: {
                                    // gridDelegateItem.Drag.active = false;
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
                                        let globalPoint = mapToItem(Overlay.overlay, mouse.x, mouse.y);
                                        contextMenu.hasSelection = true;
                                        contextMenu.selectionCount = Math.max(1, panelRoot.selectedIndices.length);
                                        contextMenu.selectionIsFolder = (contextMenu.selectionCount === 1 && model.isFolder);
                                        contextMenu.canPaste = panelRoot.clipboardAssets.length > 0;
                                        contextMenu.openAt(globalPoint.x, globalPoint.y);
                                    }
                                }

                                onDoubleClicked: function (mouse) {
                                    if (mouse.button === Qt.LeftButton && model.isFolder) {
                                        let targetId = model.id;
                                        if (panelRoot.activeMediaBinModel) {
                                            panelRoot.activeMediaBinModel.currentBinId = targetId;
                                            panelRoot.clearSelection();
                                        }
                                    }
                                }
                            }
                        }

                        XylaMediaPanelEmpty {
                            visible: gridView.count === 0
                        }
                        // Text {
                        //     anchors.centerIn: parent
                        //     text: "No Media Assets Loaded\n(Drag & Drop files here or right-click to import)"
                        //     horizontalAlignment: Text.AlignHCenter
                        //     color: "#505050"
                        //     font.pixelSize: 12
                        //     visible: gridView.count === 0
                        // }
                    }
                }
            }
        }
    }
}
