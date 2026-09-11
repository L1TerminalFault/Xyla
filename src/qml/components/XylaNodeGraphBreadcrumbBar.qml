import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: pathBarContainer

    Layout.fillWidth: true
    Layout.preferredHeight: 32

    property var activeTimelineModel: null
    property string activeSelectedClipId: ""
    property string currentGraphId: ""

    signal graphSelected(string graphId)

    // Helper: Resolve icons matching your exact file manager style
    function getNodeIcon(name, isClip, isDefault) {
        if (isClip) return "qrc:/assets/icons/video.svg";
        if (isDefault) return "qrc:/assets/icons/lock.svg";
        return "qrc:/assets/icons/graph.svg";
    }

    // Build the breadcrumbs list
    function parseNodeBreadcrumbs() {
        var crumbs = [];

        if (!activeTimelineModel || activeSelectedClipId === "") {
            // Standalone mode: Root is "Project Graphs"
            crumbs.push({
                name: "Project Graphs",
                id: "project_root",
                isClip: true,
                icon: "qrc:/assets/icons/folder.svg"
            });
            var standaloneGName = activeTimelineModel ? activeTimelineModel.getGraphName(currentGraphId) : "Default";
            crumbs.push({
                name: (standaloneGName && standaloneGName !== "") ? standaloneGName : "Default",
                id: currentGraphId,
                isClip: false,
                isDefault: (currentGraphId === "default_io_graph"),
                icon: getNodeIcon(standaloneGName, false, currentGraphId === "default_io_graph")
            });
            return crumbs;
        }

        // Clip Mode: Root crumb is Clip
        var clipData = activeTimelineModel.selectedClipData;
        var clipTitle = (clipData && clipData.name && clipData.name !== "") ? clipData.name : ("Clip: " + activeSelectedClipId);
        crumbs.push({
            name: clipTitle,
            id: activeSelectedClipId,
            isClip: true,
            icon: "qrc:/assets/icons/video.svg"
        });

        // Child crumbs: All graphs attached to this clip
        var attached = activeTimelineModel.getClipAttachedGraphs(activeSelectedClipId);
        for (var i = 0; i < attached.length; ++i) {
            crumbs.push({
                name: attached[i].name,
                id: attached[i].id,
                isClip: false,
                isDefault: attached[i].isDefault,
                icon: getNodeIcon(attached[i].name, false, attached[i].isDefault)
            });
        }
        return crumbs;
    }

    // Main Surface (Exact 1:1 styling with your file manager bar)
    Rectangle {
        id: barBackground
        anchors.fill: parent
        // color: "#0e0e0e"
        color: "transparent"
        // border.color: "#101010"
        // border.width: 1
        // radius: height / 2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 12
            spacing: 2
            z: 1

            Item {
                id: breadcrumbContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                property var breadcrumbs: parseNodeBreadcrumbs()
                property var displayItems: []
                property var hiddenIndexes: []

                function breadcrumbWidth(index) {
                    var item = breadcrumbMeasurements.itemAt(index);
                    return item ? item.implicitWidth : 0;
                }

                function separatorWidth() {
                    return 4 + 8;
                }

                function rebuildDisplayItems() {
                    var result = [];
                    for (var i = 0; i < breadcrumbs.length; ++i) {
                        if (i > 0 && i === hiddenIndexes[0])
                            result.push({ type: "ellipsis" });

                        if (hiddenIndexes.indexOf(i) === -1)
                            result.push({ type: "crumb", index: i });
                    }
                    displayItems = result;
                }

                function recalculateBreadcrumbs() {
                    var count = breadcrumbs.length;
                    hiddenIndexes = [];
                    displayItems = [];

                    if (count === 0) return;
                    if (count === 1) {
                        rebuildDisplayItems();
                        return;
                    }

                    var available = width - 16;
                    if (available <= 0) return;

                    var fullWidth = 0;
                    for (var f = 0; f < count; ++f) {
                        fullWidth += breadcrumbWidth(f);
                        if (f < count - 1) fullWidth += separatorWidth();
                    }

                    if (fullWidth <= available) {
                        rebuildDisplayItems();
                        return;
                    }

                    var bestHiddenStart = -1;
                    var bestHiddenEnd = -1;
                    var bestVisibleWidth = -1;

                    for (var start = 1; start < count - 1; ++start) {
                        for (var end = start; end < count - 1; ++end) {
                            var visibleWidth = 0;
                            var visibleCount = 0;

                            visibleWidth += breadcrumbWidth(0);
                            visibleCount++;

                            for (var left = 1; left < start; ++left) {
                                visibleWidth += breadcrumbWidth(left);
                                visibleCount++;
                            }

                            var ellipsisWidth = 28;
                            visibleWidth += ellipsisWidth;
                            visibleCount++;

                            for (var right = end + 1; right < count - 1; ++right) {
                                visibleWidth += breadcrumbWidth(right);
                                visibleCount++;
                            }

                            visibleWidth += breadcrumbWidth(count - 1);
                            visibleCount++;

                            if (visibleCount > 1)
                                visibleWidth += (visibleCount - 1) * separatorWidth();

                            if (visibleWidth <= available) {
                                var rightVisibleCount = count - 1 - (end + 1);
                                var bestRightVisibleCount = bestHiddenEnd >= 0 ? count - 1 - (bestHiddenEnd + 1) : -1;

                                if (visibleWidth > bestVisibleWidth || (visibleWidth === bestVisibleWidth && rightVisibleCount > bestRightVisibleCount)) {
                                    bestVisibleWidth = visibleWidth;
                                    bestHiddenStart = start;
                                    bestHiddenEnd = end;
                                }
                            }
                        }
                    }

                    if (bestHiddenStart === -1) {
                        bestHiddenStart = 1;
                        bestHiddenEnd = count - 2;
                    }

                    var hidden = [];
                    for (var h = bestHiddenStart; h <= bestHiddenEnd; ++h) {
                        hidden.push(h);
                    }
                    hiddenIndexes = hidden;
                    rebuildDisplayItems();
                }

                onWidthChanged: Qt.callLater(recalculateBreadcrumbs)

                // Reactive Listeners
                Connections {
                    target: pathBarContainer
                    function onActiveSelectedClipIdChanged() {
                        breadcrumbContainer.breadcrumbs = parseNodeBreadcrumbs();
                        Qt.callLater(breadcrumbContainer.recalculateBreadcrumbs);
                    }
                    function onCurrentGraphIdChanged() {
                        breadcrumbContainer.breadcrumbs = parseNodeBreadcrumbs();
                        Qt.callLater(breadcrumbContainer.recalculateBreadcrumbs);
                    }
                }

                Connections {
                    target: pathBarContainer.activeTimelineModel ? pathBarContainer.activeTimelineModel : null
                    function onProjectGraphsChanged() {
                        breadcrumbContainer.breadcrumbs = parseNodeBreadcrumbs();
                        Qt.callLater(breadcrumbContainer.recalculateBreadcrumbs);
                    }
                }

                RowLayout {
                    id: breadcrumbRow
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    spacing: 2

                    Repeater {
                        id: visibleBreadcrumbs
                        model: breadcrumbContainer.displayItems

                        delegate: RowLayout {
                            id: crumbDelegateRow
                            required property var modelData
                            required property int index

                            spacing: 4
                            height: breadcrumbRow.height

                            readonly property var crumbObj: {
                                if (modelData.type !== "crumb" || !breadcrumbContainer.breadcrumbs) return null;
                                return breadcrumbContainer.breadcrumbs[modelData.index] || null;
                            }

                            readonly property bool isActiveGraph: {
                                if (!crumbObj || crumbObj.isClip) return false;
                                return crumbObj.id === pathBarContainer.currentGraphId;
                            }

                            // Normal Breadcrumb Capsule
                            Rectangle {
                                visible: modelData.type === "crumb"
                                implicitWidth: modelData.type === "crumb"
                                    ? breadcrumbContainer.breadcrumbWidth(modelData.index)
                                    : 28
                                Layout.preferredWidth: implicitWidth
                                Layout.preferredHeight: 24
                                radius: height / 2

                                color: crumbDelegateRow.isActiveGraph
                                    ? "#232323"
                                    : (crumbMouse.containsMouse ? "#272727" : "transparent")
                                // border.color: crumbDelegateRow.isActiveGraph ? "#2555D3" : "transparent"
                                // border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Image {
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                        source: crumbDelegateRow.crumbObj ? crumbDelegateRow.crumbObj.icon : ""
                                        sourceSize: Qt.size(14, 14)
                                        opacity: crumbDelegateRow.isActiveGraph ? 1.0 : 0.85
                                    }

                                    Text {
                                        text: crumbDelegateRow.crumbObj ? crumbDelegateRow.crumbObj.name : ""
                                        color: crumbDelegateRow.isActiveGraph ? "#ffffff" : (crumbMouse.containsMouse ? "#ffffff" : "#cccccc")
                                        opacity: crumbMouse.containsMouse ? 1.0 : 0.8
                                        font.pixelSize: 11
                                        font.weight: (modelData.type === "crumb" && modelData.index === breadcrumbContainer.breadcrumbs.length - 1)
                                            ? Font.Medium
                                            : Font.Normal
                                    }
                                }

                                MouseArea {
                                    id: crumbMouse
                                    anchors.fill: parent
                                    enabled: modelData.type === "crumb"
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        // 1. If clicked the clip root crumb, do nothing
                                        if (crumbDelegateRow.crumbObj.isClip) {
                                            return;
                                        }

                                        // 2. Block click if it is the default immutable In/Out graph
                                        if (crumbDelegateRow.crumbObj.id === "default_io_graph" || crumbDelegateRow.crumbObj.isDefault) {
                                            return;
                                        }

                                        // 3. Valid editable user graph selected
                                        pathBarContainer.graphSelected(crumbDelegateRow.crumbObj.id);
                                        // if (!crumbDelegateRow.crumbObj) return;

                                        // // If clicked the clip crumb, do nothing or switch to clip's first graph
                                        // if (crumbDelegateRow.crumbObj.id === "default_io_graph" || crumbDelegateRow.crumbObj.isDefault) {
                                        //     if (pathBarContainer.activeTimelineModel && pathBarContainer.activeSelectedClipId !== "") {
                                        //         var firstGId = pathBarContainer.activeTimelineModel.getClipActiveGraphId(pathBarContainer.activeSelectedClipId);
                                        //         pathBarContainer.graphSelected(firstGId);
                                        //     }
                                        //     return;
                                        // }

                                        // // Clicked a graph crumb: switch to it!
                                        // pathBarContainer.graphSelected(crumbDelegateRow.crumbObj.id);
                                    }
                                }
                            }

                            // Ellipsis Capsule (Collapsible Middle Range)
                            Rectangle {
                                visible: modelData.type === "ellipsis"
                                implicitWidth: 28
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 24
                                radius: 6
                                color: ellipsisMouse.containsMouse ? "#252525" : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "..."
                                    color: "#ffffff"
                                    font.pixelSize: 13
                                    font.bold: true
                                }

                                MouseArea {
                                    id: ellipsisMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var p = parent.mapToItem(Overlay.overlay, 0, parent.height + 4);
                                        hiddenBreadcrumbPopup.x = p.x;
                                        hiddenBreadcrumbPopup.y = p.y;
                                        hiddenBreadcrumbPopup.open();
                                    }
                                }
                            }

                            // Separator
                            Text {
                                visible: index < breadcrumbContainer.displayItems.length - 1
                                text: "›"
                                color: separatorMouse.containsMouse ? "#ffffff" : "#666666"
                                font.pixelSize: 16
                                Layout.alignment: Qt.AlignVCenter

                                MouseArea {
                                    id: separatorMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }
                }

                // Measurement Repeater
                Repeater {
                    id: breadcrumbMeasurements
                    model: breadcrumbContainer.breadcrumbs

                    delegate: Item {
                        required property var modelData
                        required property int index
                        visible: false
                        implicitWidth: measurementText.implicitWidth + 12 + 14 + 6

                        Text {
                            id: measurementText
                            text: modelData.name
                            font.pixelSize: 12
                            font.weight: index === breadcrumbContainer.breadcrumbs.length - 1 ? Font.Bold : Font.Normal
                        }
                    }

                    onCountChanged: Qt.callLater(breadcrumbContainer.recalculateBreadcrumbs)
                }

                // Ellipsis Popup with MultiEffect Shadow
                Popup {
                    id: hiddenBreadcrumbPopup
                    parent: Overlay.overlay
                    modal: false
                    focus: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    padding: 6
                    width: 220

                    background: Rectangle {
                        anchors.fill: parent
                        color: "#181818"
                        border.color: "#303030"
                        border.width: 1
                        radius: 12

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#90000000"
                            shadowBlur: 0.65
                            shadowVerticalOffset: 6
                        }
                    }

                    contentItem: ListView {
                        id: hiddenBreadcrumbList
                        clip: true
                        spacing: 2
                        implicitHeight: Math.min(contentHeight, 260)
                        model: breadcrumbContainer.hiddenIndexes

                        delegate: Rectangle {
                            required property int modelData
                            required property int index
                            width: hiddenBreadcrumbList.width
                            height: 30
                            radius: 6
                            color: hiddenMouse.containsMouse ? "#252525" : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Image {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
                                    source: breadcrumbContainer.breadcrumbs[modelData].icon
                                    sourceSize: Qt.size(14, 14)
                                    opacity: 0.85
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: breadcrumbContainer.breadcrumbs[modelData].name
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: hiddenMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var crumb = breadcrumbContainer.breadcrumbs[modelData];
                                    hiddenBreadcrumbPopup.close();
                                    if (crumb && !crumb.isClip && crumb.id !== "default_io_graph") { pathBarContainer.graphSelected(crumb.id); }
                                }
                            }
                        }
                    }
                }

                Component.onCompleted: Qt.callLater(recalculateBreadcrumbs)
            }
        }
    }
}
