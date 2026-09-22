import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Xyla 1.0
import "../components"
import "./mediapanel"

Item {
    id: panelRoot

    property var activeMediaPool: typeof mediaPool !== "undefined" ? mediaPool : null
    property var activeMediaBinModel: typeof mediaBinModel !== "undefined" ? mediaBinModel : null
    property var mediaPanelSettings: activeMediaBinModel ? activeMediaBinModel.mediaPanelSettings : null

    property var selectedIndices: []
    property int lastSelectedIndex: -1
    // property int editingItemId: -1
    property string editingItemId: ""
    property var clipboardAssets: [] // Array of { id: string, isCut: bool }

    HoverHandler {
        onHoveredChanged: if (hovered && typeof layoutController !== "undefined" && layoutController)
            layoutController.setActiveDockId("MediaPanel")
    }

    property bool showExtensions: mediaPanelSettings ? mediaPanelSettings.showFileExtensions : true
    property bool isListView: mediaPanelSettings ? (mediaPanelSettings.defaultView.toString().toLowerCase() === "list") : false
    property bool hoverScrubEnabled: mediaPanelSettings ? mediaPanelSettings.hoverScrub : false
    property bool showWaveforms: mediaPanelSettings ? mediaPanelSettings.showWaveforms : false
    property bool showTooltips: mediaPanelSettings ? mediaPanelSettings.showTooltips : true

    property int selectedItemIndex: -1
    property real gridCellSize: 195
    // Flag to control initial cascade vs targeted updates
    property bool allowEntranceCascade: true


    // TopBar subcomponent aliases for external references
    readonly property var sortComboBox: topBar.sortComboBox
    readonly property var sortOrderToggle: topBar.sortOrderToggle
    readonly property var searchPopup: topBar.searchPopup
    readonly property var settingsBtn: topBar.settingsBtn
    readonly property var filterPopup: topBar.filterPopup
    readonly property var viewModeToggle: topBar.viewModeToggle

    Timer {
        id: cascadeResetTimer
        interval: 400
        repeat: false
        onTriggered: panelRoot.allowEntranceCascade = false
    }

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

    // Drag tracking
    property var draggedAssetIds: []
    property bool isCustomDragging: false
    property real dragGlobalX: 0
    property real dragGlobalY: 0
    property string dragPreviewName: ""
    property string dragPreviewPath: ""
    property bool dragPreviewIsFolder: false
    property int dragCount: 1

    readonly property color bgDark: "#121212"
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

    /**
     * Retrieves contents of any folder item without navigating or expanding.
     * @param {string|object} folderOrId - Folder ID string or model item object
     * @param {boolean} [recursive=false] - Whether to get all nested descendants
     * @returns {Array<object>} List of child item objects
     */
    function getFolderContents(folderOrId, recursive) {
        if (!panelRoot.activeMediaBinModel || !folderOrId)
            return [];

        var folderId = (typeof folderOrId === "object") ? folderOrId.id : folderOrId;
        if (!folderId)
            return [];

        return panelRoot.activeMediaBinModel.getFolderContents(folderId, !!recursive);
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
        if (targetIndex < 0)
            return;
        var view = panelRoot.isListView ? listView : gridView;
        if (view && view.itemAtIndex) {
            var item = view.itemAtIndex(targetIndex);
            if (item && item.playEntranceAnim) {
                item.playEntranceAnim();
            }
        }
    }

//     function triggerStaggerAnimationForSelection(explicitIds) {
//     if (!panelRoot.activeMediaBinModel)
//         return;
//
//     var view = panelRoot.isListView ? listView : gridView;
//     if (!view)
//         return;
//
//     var indices = [];
//
//     if (explicitIds && explicitIds.length > 0) {
//         var count = panelRoot.isListView ? listView.count : gridView.count;
//         for (let i = 0; i < count; i++) {
//             let it = panelRoot.activeMediaBinModel.get(i);
//             if (it && explicitIds.indexOf(it.id) !== -1) {
//                 indices.push(i);
//             }
//         }
//     } else {
//         indices = panelRoot.selectedIndices.length > 0
//             ? panelRoot.selectedIndices.slice()
//             : (panelRoot.selectedItemIndex >= 0 ? [panelRoot.selectedItemIndex] : []);
//     }
//
//     if (indices.length === 0)
//         return;
//
//     indices.sort(function (a, b) { return a - b; });
//
//     for (let i = 0; i < indices.length; i++) {
//         let delegateItem = view.itemAtIndex ? view.itemAtIndex(indices[i]) : null;
//         if (!delegateItem)
//             continue;
//
//         let delay = Math.min(i * 25, 250);
//         if (delegateItem.playEntranceAnimWithDelay) {
//             delegateItem.playEntranceAnimWithDelay(delay);
//         } else if (delegateItem.playEntranceAnim) {
//             delegateItem.playEntranceAnim();
//         }
//     }
// }

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

    // INFO: Previous bumpup animation
    function triggerItemsAnimationByIds(ids) {
        if (!ids || ids.length === 0 || !panelRoot.activeMediaBinModel)
            return;

        // Use a deferred call so newly constructed delegates are ready in the view
        animDeferredTimer.targetIds = ids;
        animDeferredTimer.restart();
    }

    // INFO: Stagger animation for selected ids
    // FIX: This is not working
    // function triggerItemsAnimationByIds(targetIds, staggered) {
    //     if (!targetIds || targetIds.length === 0)
    //         return;
    //
    //     var count = panelRoot.isListView ? listView.count : gridView.count;
    //     var view = panelRoot.isListView ? listView : gridView;
    //     if (!view) return;
    //
    //     var matchedOrder = 0;
    //     for (var i = 0; i < count; i++) {
    //         var item = view.itemAtIndex ? view.itemAtIndex(i) : null;
    //         if (item && item.itemId && targetIds.indexOf(item.itemId) !== -1) {
    //             if (staggered) {
    //                 var delay = Math.min(matchedOrder * 25, 250);
    //                 item.playEntranceAnimWithDelay ? item.playEntranceAnimWithDelay(delay) : item.playEntranceAnim();
    //                 matchedOrder++;
    //             } else {
    //                 item.playEntranceAnim();
    //             }
    //         }
    //     }
    // }

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
                panelRoot.selectSingle(i);
                if (it && it.id === assetId) {
                break;
            }
        }
    }

function performRename() {
    var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
    if (targetIdx >= 0 && panelRoot.activeMediaBinModel) {
        var it = panelRoot.activeMediaBinModel.get(targetIdx);
        if (it && it.id) panelRoot.editingItemId = it.id;
    }
}

function performDuplicate() {
    panelRoot.editingItemId = "";
    if (!panelRoot.activeMediaBinModel)
        return;

    var indices = panelRoot.selectedIndices.length > 0 ? panelRoot.selectedIndices : (panelRoot.selectedItemIndex >= 0 ? [panelRoot.selectedItemIndex] : []);
    if (indices.length === 0)
        return;

    var binMap = {};
    var fallbackBin = panelRoot.isListView ? "root" : (panelRoot.activeMediaBinModel.currentBinId || "root");

    for (var i = 0; i < indices.length; i++) {
        var it = panelRoot.activeMediaBinModel.get(indices[i]);
        if (it && it.id) {
            var parentBin = (it.parentBinId !== undefined && it.parentBinId !== "") ? it.parentBinId : fallbackBin;
            if (!binMap[parentBin]) binMap[parentBin] = [];
            binMap[parentBin].push(it.id);
        }
    }

    for (var binId in binMap) {
        if (binMap.hasOwnProperty(binId) && binMap[binId].length > 0) {
            panelRoot.activeMediaBinModel.duplicateAssetsById(binMap[binId], binId);
        }
    }
}

function performNewFolder() {
    if (!panelRoot.activeMediaBinModel) return;
    let parentBin = "";
    if (panelRoot.isListView) {
        var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
        if (targetIdx >= 0) {
            var it = panelRoot.activeMediaBinModel.get(targetIdx);
            if (it && it.isFolder) parentBin = it.id;
        }
    }
    var newIdx = panelRoot.activeMediaBinModel.createFolder("New Folder", parentBin);
    if (newIdx >= 0) {
        panelRoot.selectSingle(newIdx);
        var created = panelRoot.activeMediaBinModel.get(newIdx);
        if (created && created.id) {
            newFolderTimer.targetId = created.id;
            newFolderTimer.restart();
        }
    }
}

function performSelectAll() {
    panelRoot.editingItemId = "";
    let count = panelRoot.isListView ? listView.count : gridView.count;
    if (count > 0) {
        let arr = [];
        for (let i = 0; i < count; i++) arr.push(i);
        panelRoot.selectedIndices = arr;
        panelRoot.selectedItemIndex = arr[arr.length - 1];
        panelRoot.lastSelectedIndex = arr[arr.length - 1];
    }
}

function performCopy() {
    panelRoot.editingItemId = "";
    panelRoot.clipboardAssets = panelRoot.buildClipboardFromSelection(false);
}

function performCut() {
    panelRoot.editingItemId = "";
    panelRoot.clipboardAssets = panelRoot.buildClipboardFromSelection(true);
}

function performPaste() {
    panelRoot.editingItemId = "";
    if (!panelRoot.activeMediaBinModel || panelRoot.clipboardAssets.length === 0)
        return;

    var curBin = panelRoot.isListView ? "root" : (panelRoot.activeMediaBinModel.currentBinId || "root");
    var cutIds = [], copyIds = [];
    for (let i = 0; i < panelRoot.clipboardAssets.length; i++) {
        if (panelRoot.clipboardAssets[i].isCut) cutIds.push(panelRoot.clipboardAssets[i].id);
        else copyIds.push(panelRoot.clipboardAssets[i].id);
    }

    if (cutIds.length > 0) {
        panelRoot.activeMediaBinModel.moveAssetsById(cutIds, curBin);
        panelRoot.clipboardAssets = [];
    }
    if (copyIds.length > 0) {
        panelRoot.activeMediaBinModel.duplicateAssetsById(copyIds, curBin);
    }
}

    Connections {
        target: panelRoot.activeMediaBinModel

        // function onItemRenamed(id) {
        //     // panelRoot.triggerItemsAnimationByIds([id]);
        //     panelRoot.triggerStaggerAnimationForSelection([id]); // triggerItemsAnimationByIds(ids);
        //     panelRoot.reselectItemById(id);
        // }

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
    if (childIds && childIds.length > 0) panelRoot.triggerStaggerAnimationForSelection(childIds);
}
function onItemsAdded(ids) { panelRoot.triggerStaggerAnimationForSelection(ids); }
function onItemRenamed(id) {
    panelRoot.triggerStaggerAnimationForSelection([id]);
    panelRoot.reselectItemById(id);
}

        function onCurrentBinIdChanged() {
            if (!panelRoot.isListView) {
                panelRoot.allowEntranceCascade = true;
                cascadeResetTimer.restart();
            }
        }
function onRenameRequested() { panelRoot.performRename(); }
function onDuplicateRequested() { panelRoot.performDuplicate(); }
function onNewFolderRequested() { panelRoot.performNewFolder(); }
function onSelectAllRequested() { panelRoot.performSelectAll(); }
function onImportRequested() { folderDialog.open(); }
function onCopyRequested() { panelRoot.performCopy(); }
function onCutRequested() { panelRoot.performCut(); }
function onPasteRequested() { panelRoot.performPaste(); }
    }

    Item {
        id: globalDummyDragTarget
    }

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
            panelRoot.editingItemId = "";
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
    MediaPanelContextMenu {
        id: contextMenu
        root: panelRoot

        onCutRequested: {
            panelRoot.editingItemId = "";
            panelRoot.clipboardAssets = panelRoot.buildClipboardFromSelection(true);
        }

        onCopyRequested: {
            panelRoot.editingItemId = "";
            panelRoot.clipboardAssets = panelRoot.buildClipboardFromSelection(false);
        }
        onPasteRequested: {
            panelRoot.editingItemId = "";
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
            panelRoot.editingItemId = "";
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
            contextMenu.close();
            var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
            if (targetIdx >= 0 && panelRoot.activeMediaBinModel) {
                var it = panelRoot.activeMediaBinModel.get(targetIdx);
                if (it && it.id) panelRoot.editingItemId = it.id;
            }
        }

        // FIX:
        onDuplicateRequested: {
            panelRoot.editingItemId = "";
            contextMenu.close();
            if (!panelRoot.activeMediaBinModel)
                return;

            // 1. Gather selected indices
            var indices = [];
            if (panelRoot.selectedIndices && panelRoot.selectedIndices.length > 0) {
                indices = panelRoot.selectedIndices;
            } else if (panelRoot.selectedItemIndex >= 0) {
                indices = [panelRoot.selectedItemIndex];
            }

            if (indices.length === 0)
                return;

            // 2. Group asset IDs by their parentBinId so each copy stays in its original folder
            var binMap = {};
            var fallbackBin = panelRoot.isListView ? "root" : (panelRoot.activeMediaBinModel.currentBinId || "root");

            for (var i = 0; i < indices.length; i++) {
                var it = panelRoot.activeMediaBinModel.get(indices[i]);
                if (it && it.id) {
                    var parentBin = (it.parentBinId !== undefined && it.parentBinId !== "") ? it.parentBinId : fallbackBin;
                    if (!binMap[parentBin]) {
                        binMap[parentBin] = [];
                    }
                    binMap[parentBin].push(it.id);
                }
            }

            // 3. Call duplicate for each target bin
            for (var binId in binMap) {
                if (binMap.hasOwnProperty(binId) && binMap[binId].length > 0) {
                    panelRoot.activeMediaBinModel.duplicateAssetsById(binMap[binId], binId);
                }
            }
        }

        onNewFolderRequested: {
            contextMenu.close();
            if (panelRoot.activeMediaBinModel) {
                let parentBin = "";
                if (panelRoot.isListView) {
                    var targetIdx = panelRoot.selectedIndices.length === 1 ? panelRoot.selectedIndices[0] : panelRoot.selectedItemIndex;
                    if (targetIdx >= 0) {
                        var it = panelRoot.activeMediaBinModel.get(targetIdx);
                        if (it && it.isFolder) {
                            parentBin = it.id;
                        }
                    }
                }

                var newIdx = panelRoot.activeMediaBinModel.createFolder("New Folder", parentBin);
                if (newIdx >= 0) {
                    panelRoot.selectSingle(newIdx);
                    // Defer setting editingItemId by 1 tick so delegate mounts first and triggers onVisibleChanged
                    newFolderTimer.targetIndex = newIdx;
                    newFolderTimer.restart();
                }
            }
        }

        Timer {
            id: renameFocusTimer
            interval: 35
            repeat: false
            property string targetId: ""
            onTriggered: {
                if (targetIndex >= 0) {
                    panelRoot.selectSingle(targetIndex);
                    panelRoot.editingItemId = targetId;
                }
            }
        }

        onDeleteRequested: {
            panelRoot.editingItemId = "";
            if (panelRoot.activeMediaBinModel) {
                let ids = panelRoot.getSelectedAssetIds();
                if (ids.length > 0) {
                    panelRoot.activeMediaBinModel.removeAssetsById(ids);
                    panelRoot.clearSelection();
                }
            }
        }

        onSelectAllRequested: {
            panelRoot.editingItemId = "";
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
            if (panelRoot.activeMediaBinModel && panelRoot.selectedItemIndex >= 0) {
                var fullData = panelRoot.activeMediaBinModel.getFullMetadata(panelRoot.selectedItemIndex);
                propertiesPopup.openWith(fullData);
            }
        }
    }

Timer {
    id: newFolderTimer
    interval: 35
    repeat: false
    property string targetId: ""
    onTriggered: if (targetId !== "") panelRoot.editingItemId = targetId;
}

    // Properties Popup (Studio Inspector)
    XylaPropertiesDialog {
        id: propertiesPopup
    }

    // Panel Background
    Rectangle {
        anchors.fill: parent
        color: panelRoot.bgDark
        z: -1
    }

Timer {
    id: staggerDeferredTimer
    interval: 35
    repeat: false
    property var targetIds: []
    onTriggered: {
        var view = panelRoot.isListView ? listView : gridView;
        if (!view || !panelRoot.activeMediaBinModel) return;

        var count = panelRoot.isListView ? listView.count : gridView.count;
        var ordered = [];
        for (let i = 0; i < count; i++) {
            let it = panelRoot.activeMediaBinModel.get(i);
            if (it && targetIds.indexOf(it.id) !== -1) ordered.push(i);
        }

        for (let i = 0; i < ordered.length; i++) {
            let delegateItem = view.itemAtIndex ? view.itemAtIndex(ordered[i]) : null;
            if (!delegateItem) continue;
            let delay = Math.min(i * 25, 250);
            if (delegateItem.playEntranceAnimWithDelay) delegateItem.playEntranceAnimWithDelay(delay);
            else if (delegateItem.playEntranceAnim) delegateItem.playEntranceAnim();
        }
    }
}

function triggerStaggerAnimationForSelection(explicitIds) {
    var ids = (explicitIds && explicitIds.length > 0) ? explicitIds : panelRoot.getSelectedAssetIds();
    if (!ids || ids.length === 0) return;
    staggerDeferredTimer.targetIds = ids;
    staggerDeferredTimer.restart();
}

    MediaPanelSettingsPopup {
        id: settingsPopup
        parent: topBar.settingsBtn
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

        // Header Toolbar
        MediaPanelTopBar {
            id: topBar
            panelRoot: panelRoot
            folderDialog: folderDialog
            settingsPopup: settingsPopup
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
                    panelRoot.editingItemId = "";
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
                        panelRoot.editingItemId = "";
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
                    ListComponent {
                        id: listView
                        panelRoot: panelRoot
                        contextMenu: contextMenu
                        globalDummyDragTarget: globalDummyDragTarget
                    }

                    // ================================================================
                    // GRID VIEW
                    // ================================================================
                    GridComponent {
                        id: gridView
                        panelRoot: panelRoot
                        contextMenu: contextMenu
                        globalDummyDragTarget: globalDummyDragTarget
                    }
                }
            }
        }
    }
}

