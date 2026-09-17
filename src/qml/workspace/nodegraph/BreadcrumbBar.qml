import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

Item {
    id: pathBarContainer

    Layout.fillWidth: true
    Layout.preferredHeight: 32

    property var activeTimelineModel: null
    property var nodeGraphController: null
    property string activeSelectedClipId: ""
    property string currentGraphId: ""

    signal graphSelected(string graphId)
    signal reorderClipGraphsRequested(string clipId, var orderedGraphIds)

    readonly property var activeGraphController: nodeGraphController ? nodeGraphController : (typeof globalNodeGraphController !== "undefined" ? globalNodeGraphController : null)

    function getNodeIcon(name, isClip, isDefault) {
        if (isClip)
            return "qrc:/assets/icons/video.svg";
        if (isDefault)
            return "qrc:/assets/icons/lock.svg";
        return "qrc:/assets/icons/graph.svg";
    }

    function parseNodeBreadcrumbs() {
        var crumbs = [];

        if (!activeTimelineModel || activeSelectedClipId === "") {
            crumbs.push({
                name: "Project Graphs",
                id: "project_root",
                isClip: true,
                icon: "qrc:/assets/icons/folder.svg"
            });
            var standaloneGName = (activeGraphController && typeof activeGraphController.getGraphName === "function") ? activeGraphController.getGraphName(currentGraphId) : "Default";
            crumbs.push({
                name: (standaloneGName && standaloneGName !== "") ? standaloneGName : "Default",
                id: currentGraphId,
                isClip: false,
                isDefault: (currentGraphId === "default_io_graph"),
                icon: getNodeIcon(standaloneGName, false, currentGraphId === "default_io_graph")
            });
            return crumbs;
        }

        var clipData = activeTimelineModel.selectedClipData;
        var clipTitle = (clipData && clipData.name && clipData.name !== "") ? clipData.name : ("Clip: " + activeSelectedClipId);
        crumbs.push({
            name: clipTitle,
            id: activeSelectedClipId,
            isClip: true,
            icon: "qrc:/assets/icons/video.svg"
        });

        var attached = activeGraphController ? activeGraphController.getClipAttachedGraphs(activeSelectedClipId) : [];
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

    Rectangle {
        id: barBackground
        anchors.fill: parent
        color: "transparent"

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
                            result.push({
                                type: "ellipsis"
                            });

                        if (hiddenIndexes.indexOf(i) === -1)
                            result.push({
                                type: "crumb",
                                index: i
                            });
                    }
                    displayItems = result;
                }

                function recalculateBreadcrumbs() {
                    var count = breadcrumbs.length;
                    hiddenIndexes = [];
                    displayItems = [];

                    if (count === 0)
                        return;
                    if (count === 1) {
                        rebuildDisplayItems();
                        return;
                    }

                    var available = width - 16;
                    if (available <= 0)
                        return;

                    var fullWidth = 0;
                    for (var f = 0; f < count; ++f) {
                        fullWidth += breadcrumbWidth(f);
                        if (f < count - 1)
                            fullWidth += separatorWidth();
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
                    target: pathBarContainer.activeGraphController
                    function onProjectGraphsChanged() {
                        breadcrumbContainer.breadcrumbs = parseNodeBreadcrumbs();
                        Qt.callLater(breadcrumbContainer.recalculateBreadcrumbs);
                    }
                    function onActiveGraphChanged() {
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
                            enabled: crumbDelegateRow.crumbObj ? !crumbDelegateRow.crumbObj.isDefault : false
                            opacity: enabled ? 1.0 : 0.4

                            spacing: 4
                            height: breadcrumbRow.height

                            readonly property var crumbObj: {
                                if (modelData.type !== "crumb" || !breadcrumbContainer.breadcrumbs)
                                    return null;
                                return breadcrumbContainer.breadcrumbs[modelData.index] || null;
                            }

                            readonly property bool isActiveGraph: {
                                if (!crumbObj || crumbObj.isClip)
                                    return false;
                                return crumbObj.id === pathBarContainer.currentGraphId;
                            }

                            Rectangle {
                                id: crumbPill
                                visible: modelData.type === "crumb"
                                implicitWidth: modelData.type === "crumb" ? breadcrumbContainer.breadcrumbWidth(modelData.index) : 28
                                Layout.preferredWidth: implicitWidth
                                Layout.preferredHeight: 24
                                radius: height / 2

                                color: crumbDelegateRow.isActiveGraph ? "#232323" : (crumbMouse.containsMouse ? "#272727" : "transparent")

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
                                        font.weight: (modelData.type === "crumb" && modelData.index === breadcrumbContainer.breadcrumbs.length - 1) ? Font.Medium : Font.Normal
                                    }
                                }

                                MouseArea {
                                    id: crumbMouse
                                    anchors.fill: parent
                                    enabled: modelData.type === "crumb"
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (!crumbDelegateRow.crumbObj)
                                            return;

                                        if (crumbDelegateRow.crumbObj.isClip && pathBarContainer.activeSelectedClipId !== "") {
                                            var p1 = crumbPill.mapToItem(Overlay.overlay, 0, crumbPill.height + 4);
                                            clipGraphsManagerPopup.x = Math.max(8, Math.min(p1.x, Overlay.overlay.width - clipGraphsManagerPopup.width - 8));
                                            clipGraphsManagerPopup.y = p1.y;
                                            clipGraphsManagerPopup.open();
                                            return;
                                        }

                                        if (crumbDelegateRow.crumbObj.isClip && pathBarContainer.activeSelectedClipId === "") {
                                            var p2 = crumbPill.mapToItem(Overlay.overlay, 0, crumbPill.height + 4);
                                            projectGraphsPopup.x = Math.max(8, Math.min(p2.x, Overlay.overlay.width - projectGraphsPopup.width - 8));
                                            projectGraphsPopup.y = p2.y;
                                            projectGraphsPopup.open();
                                            return;
                                        }

                                        if (crumbDelegateRow.crumbObj.id === "default_io_graph" || crumbDelegateRow.crumbObj.isDefault) {
                                            return;
                                        }

                                        pathBarContainer.graphSelected(crumbDelegateRow.crumbObj.id);
                                    }
                                }
                            }

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

                Component.onCompleted: Qt.callLater(recalculateBreadcrumbs)
            }
        }
    }

    Popup {
        id: clipGraphsManagerPopup
        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 6
        width: 260

        property var attachedGraphs: []

        function reload() {
            if (!pathBarContainer.activeGraphController || pathBarContainer.activeSelectedClipId === "") {
                attachedGraphs = [];
                return;
            }
            attachedGraphs = pathBarContainer.activeGraphController.getClipAttachedGraphs(pathBarContainer.activeSelectedClipId);
        }

        onAboutToShow: reload()

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
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 4

                Text {
                    text: "Attached Graphs"
                    color: "#91919A"
                    font.pixelSize: 11
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "Execution Order"
                    color: "#52525B"
                    font.pixelSize: 10
                }
            }

            ListView {
                id: clipGraphsList
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 240)
                clip: true
                spacing: 2
                model: clipGraphsManagerPopup.attachedGraphs

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    enabled: !modelData.isDefault
                    opacity: enabled ? 1.0 : 0.4

                    width: clipGraphsList.width
                    height: 32
                    radius: 6
                    color: modelData.id === pathBarContainer.currentGraphId ? "#2e2e2e" : (rowHover.hovered ? "#222222" : "transparent")

                    HoverHandler {
                        id: rowHover
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: 6

                        Image {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            source: modelData.isDefault ? "qrc:/assets/icons/lock.svg" : "qrc:/assets/icons/graph.svg"
                            opacity: 0.85
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: "#FFFFFF"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: !modelData.isDefault && index > 1
                            width: 18
                            height: 18
                            radius: 9
                            color: upHover.hovered ? "#3F3F46" : "transparent"

                            Image {
                                anchors.centerIn: parent
                                width: 10
                                height: 10
                                source: "qrc:/assets/icons/chevron-down.svg"
                                fillMode: Image.PreserveAspectFit
                                rotation: 180
                                sourceSize: Qt.size(20, 20)
                            }

                            HoverHandler {
                                id: upHover
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var arr = clipGraphsManagerPopup.attachedGraphs.slice();
                                    var item = arr.splice(index, 1)[0];
                                    arr.splice(index - 1, 0, item);
                                    var ids = arr.map(function (g) {
                                        return g.id;
                                    });
                                    if (pathBarContainer.activeGraphController)
                                        pathBarContainer.activeGraphController.reorderClipGraphs(pathBarContainer.activeSelectedClipId, ids);
                                    pathBarContainer.reorderClipGraphsRequested(pathBarContainer.activeSelectedClipId, ids);
                                    clipGraphsManagerPopup.reload();
                                }
                            }
                        }

                        Rectangle {
                            visible: !modelData.isDefault && index < clipGraphsList.count - 1
                            width: 18
                            height: 18
                            radius: 9
                            color: downHover.hovered ? "#3F3F46" : "transparent"

                            Image {
                                anchors.centerIn: parent
                                width: 10
                                height: 10
                                source: "qrc:/assets/icons/chevron-down.svg"
                                fillMode: Image.PreserveAspectFit
                                sourceSize: Qt.size(20, 20)
                            }

                            HoverHandler {
                                id: downHover
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    var arr = clipGraphsManagerPopup.attachedGraphs.slice();
                                    var item = arr.splice(index, 1)[0];
                                    arr.splice(index + 1, 0, item);
                                    var ids = arr.map(function (g) {
                                        return g.id;
                                    });
                                    if (pathBarContainer.activeGraphController)
                                        pathBarContainer.activeGraphController.reorderClipGraphs(pathBarContainer.activeSelectedClipId, ids);
                                    pathBarContainer.reorderClipGraphsRequested(pathBarContainer.activeSelectedClipId, ids);
                                    clipGraphsManagerPopup.reload();
                                }
                            }
                        }

                        Rectangle {
                            visible: !modelData.isDefault
                            width: 18
                            height: 18
                            radius: 9
                            color: detachHover.hovered ? "#3F3F46" : "transparent"

                            Image {
                                id: detachIcon
                                anchors.centerIn: parent
                                width: 10
                                height: 10
                                source: "qrc:/assets/icons/x.svg"
                                fillMode: Image.PreserveAspectFit
                                sourceSize: Qt.size(20, 20)
                                visible: false
                            }

                            ColorOverlay {
                                anchors.fill: detachIcon
                                source: detachIcon
                                color: "#EF4444"
                            }

                            HoverHandler {
                                id: detachHover
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (pathBarContainer.activeGraphController)
                                        pathBarContainer.activeGraphController.detachGraphFromClip(pathBarContainer.activeSelectedClipId, modelData.id);
                                    clipGraphsManagerPopup.reload();
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: {
                            if (!modelData.isDefault) {
                                pathBarContainer.graphSelected(modelData.id);
                                clipGraphsManagerPopup.close();
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: projectGraphsPopup
        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 6
        width: 230

        property var allGraphs: []

        function reload() {
            if (!pathBarContainer.activeGraphController) {
                allGraphs = [];
                return;
            }
            var all = (typeof pathBarContainer.activeGraphController.getAllProjectGraphs === "function") ? pathBarContainer.activeGraphController.getAllProjectGraphs() : (typeof pathBarContainer.activeGraphController.listAllGraphsSummary === "function" ? pathBarContainer.activeGraphController.listAllGraphsSummary() : []);
            var filtered = [];
            for (var i = 0; i < all.length; ++i) {
                if (all[i].id !== "default_io_graph" && !all[i].isDefault) {
                    filtered.push(all[i]);
                }
            }
            allGraphs = filtered;
        }

        onAboutToShow: reload()

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
            spacing: 4

            Text {
                Layout.margins: 4
                text: "Project Node Graphs"
                color: "#91919A"
                font.pixelSize: 11
            }

            Text {
                visible: projectGraphsPopup.allGraphs.length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                text: "No custom graphs created"
                color: "#52525B"
                font.pixelSize: 11
            }

            ListView {
                id: projectGraphsList
                visible: projectGraphsPopup.allGraphs.length > 0
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 240)
                clip: true
                spacing: 2
                model: projectGraphsPopup.allGraphs

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: projectGraphsList.width
                    height: 30
                    radius: 6
                    color: modelData.id === pathBarContainer.currentGraphId ? "#2e2e2e" : (projHover.hovered ? "#222222" : "transparent")

                    HoverHandler {
                        id: projHover
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Image {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            source: "qrc:/assets/icons/graph.svg"
                            opacity: 0.85
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: "#FFFFFF"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pathBarContainer.graphSelected(modelData.id);
                            projectGraphsPopup.close();
                        }
                    }
                }
            }
        }
    }

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
                        if (crumb && !crumb.isClip && crumb.id !== "default_io_graph") {
                            pathBarContainer.graphSelected(crumb.id);
                        }
                    }
                }
            }
        }
    }
}
