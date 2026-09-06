import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: control

    width: 250 // 290
    padding: 12
    clip: false

    property var mediaBinModel: null
    property bool _recentlyClosed: false

    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Shortcut {
        enabled: control.opened
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: control.close()
    }

    onAboutToHide: {
        _recentlyClosed = true;
        closeResetTimer.restart();
    }

    Timer {
        id: closeResetTimer
        interval: 200
        onTriggered: control._recentlyClosed = false
    }

    background: Rectangle {
        id: popupSurface__
        anchors.fill: parent
        color: "#181818"
        border.color: "#282828"
        border.width: 1
        radius: 12

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#90000000"
            shadowBlur: 0.65
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 1.0; to: 0.95; duration: 120; easing.type: Easing.OutCubic }
    }

    contentItem: Flickable {
        id: scrollArea
        implicitWidth: 266
        implicitHeight: Math.min(540, filterColumn.implicitHeight)
        contentWidth: width
        contentHeight: filterColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: filterColumn
            width: parent.width
            spacing: 16

            // ================= 1. HEADER (NO LAYOUT SHIFT) =================
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 26

                Text {
                    text: "Filter Options"
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.bold: true
                    Layout.fillWidth: true
                }

                XylaIconButton {
                    id: resetAllBtn
                    ghost: true
                    iconColor: "#ef4444"
                    Layout.preferredWidth: 22 // 26
                    Layout.preferredHeight: 22 //  26
                    tooltip: "Reset All Filters"
                    iconSource: "qrc:/assets/icons/clear.svg"

                    readonly property bool hasActive: control.mediaBinModel ? control.mediaBinModel.hasActiveFilters : false
                    opacity: hasActive ? 1.0 : 0.0
                    enabled: hasActive

                    Behavior on opacity {
                        NumberAnimation { duration: 120 }
                    }

                    onClicked: {
                        if (control.mediaBinModel) {
                            control.mediaBinModel.resetAllFilters();
                        }
                        colorContainer.selectedTags = [];
                        typeContainer.resetAllTypes();
                        extSelect.currentIndex = 0;
                    }
                }
            }

            // ================= 2. COLOR TAGS (Morphs tag.svg -> tag-filled.svg, Hover only, Dedicated Clear) =================
            ColumnLayout {
                id: colorContainer
                Layout.fillWidth: true
                spacing: 4

                property var selectedTags: []
                property int lastTagIndex: -1

                function isTagSelected(t) {
                    return selectedTags.indexOf(t) !== -1;
                }

                function applyTagFilters() {
                    if (!control.mediaBinModel) return;
                    if (selectedTags.length === 0) {
                        control.mediaBinModel.tagFilter = 0;
                    } else if (selectedTags.length === 1) {
                        control.mediaBinModel.tagFilter = selectedTags[0];
                    } else {
                        if (control.mediaBinModel.setTagsFilter)
                            control.mediaBinModel.setTagsFilter(selectedTags);
                        else
                            control.mediaBinModel.tagFilter = selectedTags[0];
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Tag"
                        color: "#888888"
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }

                    XylaIconButton {
                        ghost: true
                        iconColor: (colorContainer.selectedTags.length > 0) ? "#fff" : "#333"
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        tooltip: "Clear Tag Filter"
                        iconSource: "qrc:/assets/icons/clear.svg"
                        onClicked: {
                            colorContainer.selectedTags = [];
                            colorContainer.lastTagIndex = -1;
                            colorContainer.applyTagFilters();
                        }
                    }
                }

Column {
    Layout.fillWidth: true
    spacing: 4
    
    // Centers both rows horizontally within the parental space
    anchors.horizontalCenter: parent.horizontalCenter

    // Row 1: First 5 items (Red to Cyan)
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        
        Repeater {
            model: [
                { tag: 1, name: "Red",    color: "#FF0000" },
                { tag: 2, name: "Orange", color: "#FF9800" },
                { tag: 3, name: "Yellow", color: "#FFFF00" },
                { tag: 4, name: "Green",  color: "#00FF00" },
                { tag: 5, name: "Cyan",   color: "#06b6d4" }
            ]
            delegate: tagDelegateComponent
        }
    }

    // Row 2: Last 4 items (Blue to White) - Automatically centered beautifully under row 1!
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        
        Repeater {
            model: [
                { tag: 6, name: "Blue",   color: "#0000FF" },
                { tag: 7, name: "Purple", color: "#F000FF" },
                { tag: 8, name: "Pink",   color: "#FF0088" },
                { tag: 9, name: "White",  color: "#FFFFFF" }
            ]
            delegate: tagDelegateComponent
        }
    }

    // Define the delegate once here so we don't repeat the inner logic code
    Component {
        id: tagDelegateComponent
        
        Item {
            width: 36
            height: 32

            readonly property bool isSelected: colorContainer.isTagSelected(modelData.tag)

            Rectangle {
                anchors.centerIn: parent
                width: 30
                height: 30
                radius: 15
                color: tagMouse.containsMouse ? "#242424" : "#181818"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Image {
                id: tagIcon
                anchors.centerIn: parent
                width: 20
                height: 20
                source: isSelected ? "qrc:/assets/icons/tag-filled.svg" : "qrc:/assets/icons/tag.svg"
                sourceSize: Qt.size(22, 22)
                fillMode: Image.PreserveAspectFit
                visible: false
                smooth: true
            }

            MultiEffect {
                anchors.fill: tagIcon
                source: tagIcon
                colorization: 1.0
                colorizationColor: modelData.color
            }

            MouseArea {
                id: tagMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: (mouse) => {
                    let tags = colorContainer.selectedTags.slice();
                    let currentTag = modelData.tag;

                    if (mouse.modifiers & Qt.ShiftModifier) {
                        let start = (colorContainer.lastTagIndex >= 0) ? Math.min(colorContainer.lastTagIndex, index) : 0;
                        let end = Math.max(colorContainer.lastTagIndex >= 0 ? colorContainer.lastTagIndex : 0, index);
                        for (let i = start; i <= end; i++) {
                            let t = i + 1;
                            if (t <= 9 && tags.indexOf(t) === -1) tags.push(t);
                        }
                    } else if (mouse.modifiers & Qt.ControlModifier) {
                        let idx = tags.indexOf(currentTag);
                        if (idx !== -1) tags.splice(idx, 1);
                        else tags.push(currentTag);
                        colorContainer.lastTagIndex = index;
                    } else {
                        if (tags.length === 1 && tags[0] === currentTag) {
                            tags = [];
                        } else {
                            tags = [currentTag];
                        }
                        colorContainer.lastTagIndex = index;
                    }

                    colorContainer.selectedTags = tags;
                    colorContainer.applyTagFilters();
                }
            }

            XylaToolTip {
                visible: tagMouse.containsMouse && modelData.name !== ""
                position: "right"
                text: modelData.name
            }
        }
    }
}

                // GridLayout {
                //     Layout.fillWidth: true
                //     columns: 5
                //     rowSpacing: 4
                //     columnSpacing: 4
                //
                //     Repeater {
                //         model: [
                //             { tag: 1, name: "Red",    color: "#FF0000" },
                //             { tag: 2, name: "Orange", color: "#FF9800" },
                //             { tag: 3, name: "Yellow", color: "#FFFF00" },
                //             { tag: 4, name: "Green",  color: "#00FF00" },
                //             { tag: 5, name: "Cyan",   color: "#06b6d4" },
                //             { tag: 6, name: "Blue",   color: "#0000FF" },
                //             { tag: 7, name: "Purple", color: "#F000FF" },
                //             { tag: 8, name: "Pink",   color: "#FF0088" },
                //             { tag: 9, name: "White",  color: "#FFFFFF" }
                //         ]
                //
                //         delegate: Item {
                //             width: 36
                //             height: 32
                //             Layout.alignment: Qt.AlignCenter
                //
                //             readonly property bool isSelected: colorContainer.isTagSelected(modelData.tag)
                //
                //             // Hover Indication ONLY (No selection background, no borders)
                //             Rectangle {
                //                 anchors.centerIn: parent
                //                 width: 30
                //                 height: 30
                //                 radius: 15
                //                 color: tagMouse.containsMouse ? "#242424" : "#181818"
                //                 Behavior on color { ColorAnimation { duration: 120 } }
                //             }
                //
                //             // Dynamic SVG Source: tag.svg when unselected, tag-filled.svg when selected
                //             Image {
                //                 id: tagIcon
                //                 anchors.centerIn: parent
                //                 width: 20
                //                 height: 20
                //                 source: isSelected ? "qrc:/assets/icons/tag-filled.svg" : "qrc:/assets/icons/tag.svg"
                //                 sourceSize: Qt.size(22, 22)
                //                 fillMode: Image.PreserveAspectFit
                //                 visible: false
                //                 smooth: true
                //             }
                //
                //             MultiEffect {
                //                 anchors.fill: tagIcon
                //                 source: tagIcon
                //                 colorization: 1.0
                //                 colorizationColor: modelData.color
                //             }
                //
                //             MouseArea {
                //                 id: tagMouse
                //                 anchors.fill: parent
                //                 hoverEnabled: true
                //                 cursorShape: Qt.PointingHandCursor
                //
                //                 onClicked: (mouse) => {
                //                     let tags = colorContainer.selectedTags.slice();
                //                     let currentTag = modelData.tag;
                //
                //                     if (mouse.modifiers & Qt.ShiftModifier) {
                //                         let start = (colorContainer.lastTagIndex >= 0) ? Math.min(colorContainer.lastTagIndex, index) : 0;
                //                         let end = Math.max(colorContainer.lastTagIndex >= 0 ? colorContainer.lastTagIndex : 0, index);
                //                         for (let i = start; i <= end; i++) {
                //                             let t = i + 1;
                //                             if (t <= 9 && tags.indexOf(t) === -1) tags.push(t);
                //                         }
                //                     } else if (mouse.modifiers & Qt.ControlModifier) {
                //                         let idx = tags.indexOf(currentTag);
                //                         if (idx !== -1) tags.splice(idx, 1);
                //                         else tags.push(currentTag);
                //                         colorContainer.lastTagIndex = index;
                //                     } else {
                //                         if (tags.length === 1 && tags[0] === currentTag) {
                //                             tags = [];
                //                         } else {
                //                             tags = [currentTag];
                //                         }
                //                         colorContainer.lastTagIndex = index;
                //                     }
                //
                //                     colorContainer.selectedTags = tags;
                //                     colorContainer.applyTagFilters();
                //                 }
                //             }
                //
                //             XylaToolTip {
                //                 visible: tagMouse.containsMouse && modelData.name !== ""
                //                 position: "right"
                //                 text: modelData.name
                //             }
                //         }
                //     }
                // }
            }

            // ================= 3. FILE TYPE (Icons-Only Grid, All Selected by Default, + "Others") =================
            ColumnLayout {
                id: typeContainer
                Layout.fillWidth: true
                spacing: 4

                // FIX: Review this
                // C++ enum class MediaType { Unknown=0, Video=1, Audio=2, Image=3, ImageSequence=4 } + Folder=5 + Others=6
                property var mediaTypes: [
                    { name: "Video",          typeVal: 1, icon: "qrc:/assets/icons/video.svg" },
                    { name: "Audio",          typeVal: 2, icon: "qrc:/assets/icons/music.svg" },
                    { name: "Image",          typeVal: 3, icon: "qrc:/assets/icons/image.svg" },
                    { name: "Image Sequence", typeVal: 4, icon: "qrc:/assets/icons/layers.svg" },
                    { name: "Folder",         typeVal: 5, icon: "qrc:/assets/icons/folder.svg" },
                    { name: "Others",         typeVal: 6, icon: "qrc:/assets/icons/file.svg" }
                ]

                // All selected by default
                property var selectedTypes: [1, 2, 3, 4, 5, 6]
                property int lastTypeIndex: -1

                function isTypeSelected(val) {
                    return selectedTypes.indexOf(val) !== -1;
                }

                function resetAllTypes() {
                    selectedTypes = [1, 2, 3, 4, 5, 6];
                    lastTypeIndex = -1;
                    applyTypeFilters();
                }

                function applyTypeFilters() {
                    if (!control.mediaBinModel) return;
                    if (selectedTypes.length === mediaTypes.length) {
                        control.mediaBinModel.typeFilter = 0; // All files active
                    } else if (selectedTypes.length === 0) {
                        control.mediaBinModel.typeFilter = -1; // Match none
                    } else if (selectedTypes.length === 1) {
                        control.mediaBinModel.typeFilter = selectedTypes[0];
                    } else {
                        if (control.mediaBinModel.setTypesFilter)
                            control.mediaBinModel.setTypesFilter(selectedTypes);
                        else
                            control.mediaBinModel.typeFilter = selectedTypes[0];
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "File Type"
                        color: "#888888"
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }

                    XylaIconButton {
                        ghost: true
                        iconColor: (typeContainer.selectedTypes.length < typeContainer.mediaTypes.length) ? "#fff" : "#333"
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        tooltip: "Reset All Types"
                        iconSource: "qrc:/assets/icons/clear.svg"
                        onClicked: typeContainer.resetAllTypes()
                    }
                }

                // Icons-Only Grid (6 columns for a sleek single-row or 3x2 grid)
RowLayout {
    id: rowLayoutContainer
    Layout.fillWidth: true
    spacing: 0 // Turned off because empty space is handled by the visual spacers below

    Repeater {
        model: typeContainer.mediaTypes

        delegate: RowLayout {
            // We need a wrapper to insert a spacer right BEFORE every item except the first one
            spacing: 0
            
            // This is the spacer. It forces a "justify-between" distribution 
            // by automatically drinking up all remaining layout width evenly.
            Item {
                Layout.fillWidth: true
                visible: index > 0 // Do not put a spacer before the very first icon
            }

            Rectangle {
                width: 32
                height: 32
                radius: 9

                readonly property bool isSelected: typeContainer.isTypeSelected(modelData.typeVal)
                readonly property bool hovered: typeMouse.containsMouse
                readonly property bool down: typeMouse.pressed

                color: isSelected 
                       ? (down ? "#11389F" : (hovered ? "#2555D3" : "#1c356e"))
                       : (down ? "#353535" : (hovered ? "#242424" : "#181818"))

                border.color: isSelected ? "#2555D3" : (hovered ? "#3a3a3a" : "#282828")
                border.width: 1

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: modelData.icon
                    sourceSize: Qt.size(18, 18)
                    fillMode: Image.PreserveAspectFit
                    opacity: isSelected ? 1.0 : 0.4
                }

                MouseArea {
                    id: typeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: (mouse) => {
                        let types = typeContainer.selectedTypes.slice();
                        let currentVal = modelData.typeVal;

                        if (mouse.modifiers & Qt.ShiftModifier) {
                            // Shift Mass Select
                            let start = (typeContainer.lastTypeIndex >= 0) ? Math.min(typeContainer.lastTypeIndex, index) : 0;
                            let end = Math.max(typeContainer.lastTypeIndex >= 0 ? typeContainer.lastTypeIndex : 0, index);
                            for (let i = start; i <= end; i++) {
                                let v = typeContainer.mediaTypes[i].typeVal;
                                if (types.indexOf(v) === -1) types.push(v);
                            }
                        } else if (mouse.modifiers & Qt.ControlModifier) {
                            // Ctrl Toggle
                            let idx = types.indexOf(currentVal);
                            if (idx !== -1) types.splice(idx, 1);
                            else types.push(currentVal);
                            typeContainer.lastTypeIndex = index;
                        } else {
                            // Plain Click
                            if (types.length === 1 && types[0] === currentVal) {
                                types = typeContainer.mediaTypes.map(item => item.typeVal);
                            } else {
                                types = [currentVal];
                            }
                            typeContainer.lastTypeIndex = index;
                        }

                        typeContainer.selectedTypes = types;
                        typeContainer.applyTypeFilters();
                    }
                }

                XylaToolTip {
                    visible: typeMouse.containsMouse
                    position: "bottom"
                    text: modelData.name
                }
            }
        }
    }
}

                // GridLayout {
                //     Layout.fillWidth: true
                //     columns: 6
                //     rowSpacing: 6
                //     columnSpacing: 6
                //
                //     Repeater {
                //         model: typeContainer.mediaTypes
                //
                //         delegate: Rectangle {
                //             width: 32
                //             height: 32
                //             radius: 9
                //
                //             readonly property bool isSelected: typeContainer.isTypeSelected(modelData.typeVal)
                //             readonly property bool hovered: typeMouse.containsMouse
                //             readonly property bool down: typeMouse.pressed
                //
                //             color: isSelected 
                //                    ? (down ? "#11389F" : (hovered ? "#2555D3" : "#1c356e"))
                //                    : (down ? "#353535" : (hovered ? "#242424" : "#181818"))
                //
                //             border.color: isSelected ? "#2555D3" : (hovered ? "#3a3a3a" : "#282828")
                //             border.width: 1
                //
                //             Image {
                //                 anchors.centerIn: parent
                //                 width: 18
                //                 height: 18
                //                 source: modelData.icon
                //                 sourceSize: Qt.size(18, 18)
                //                 fillMode: Image.PreserveAspectFit
                //                 opacity: isSelected ? 1.0 : 0.4
                //             }
                //
                //             MouseArea {
                //                 id: typeMouse
                //                 anchors.fill: parent
                //                 hoverEnabled: true
                //                 cursorShape: Qt.PointingHandCursor
                //
                //                 onClicked: (mouse) => {
                //                     let types = typeContainer.selectedTypes.slice();
                //                     let currentVal = modelData.typeVal;
                //
                //                     if (mouse.modifiers & Qt.ShiftModifier) {
                //                         // Shift Mass Select
                //                         let start = (typeContainer.lastTypeIndex >= 0) ? Math.min(typeContainer.lastTypeIndex, index) : 0;
                //                         let end = Math.max(typeContainer.lastTypeIndex >= 0 ? typeContainer.lastTypeIndex : 0, index);
                //                         for (let i = start; i <= end; i++) {
                //                             let v = typeContainer.mediaTypes[i].typeVal;
                //                             if (types.indexOf(v) === -1) types.push(v);
                //                         }
                //                     } else if (mouse.modifiers & Qt.ControlModifier) {
                //                         // Ctrl Toggle
                //                         let idx = types.indexOf(currentVal);
                //                         if (idx !== -1) types.splice(idx, 1);
                //                         else types.push(currentVal);
                //                         typeContainer.lastTypeIndex = index;
                //                     } else {
                //                         // Plain Click
                //                         if (types.length === 1 && types[0] === currentVal) {
                //                             types = [1, 2, 3, 4, 5, 6]; // reset to all
                //                         } else {
                //                             types = [currentVal];
                //                         }
                //                         typeContainer.lastTypeIndex = index;
                //                     }
                //
                //                     typeContainer.selectedTypes = types;
                //                     typeContainer.applyTypeFilters();
                //                 }
                //             }
                //
                //             XylaToolTip {
                //                 visible: typeMouse.containsMouse
                //                 position: "bottom"
                //                 text: modelData.name
                //             }
                //         }
                //     }
                // }
            }

            // ================= 6. FILE EXTENSION (XylaSelect + Clear Button) =================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "Extension"
                    color: "#888888"
                    font.pixelSize: 11
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    XylaSelect {
                        id: extSelect
                        Layout.fillWidth: true
                        model: [
                            "All Extensions",
                            "mp4",
                            "mov",
                            "mkv",
                            "avi",
                            "webm",
                            "wav",
                            "mp3",
                            "aac",
                            "flac",
                            "png",
                            "jpg",
                            "jpeg",
                            "exr",
                            "svg"
                        ]

                        onCurrentTextChanged: {
                            if (!control.mediaBinModel) return;
                            if (currentIndex === 0 || currentText === "All Extensions") {
                                control.mediaBinModel.extensionFilter = "";
                            } else {
                                control.mediaBinModel.extensionFilter = currentText;
                            }
                        }
                    }

                    XylaIconButton {
                        ghost: true
                        iconColor: (extSelect.currentIndex === 0) ? "#333" : "#fff"
                        Layout.preferredWidth: 22 // 28
                        Layout.preferredHeight: 22 // 28
                        tooltip: "Clear Extension Filter"
                        iconSource: "qrc:/assets/icons/clear.svg"
                        onClicked: {
                            extSelect.currentIndex = 0;
                            if (control.mediaBinModel) control.mediaBinModel.extensionFilter = "";
                        }
                    }
                }
            }

            // ================= 4. DURATION RANGE (1-to-1 Pill Track Slider) =================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Duration"
                        color: "#888888"
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                    XylaIconButton {
                        ghost: true
                        iconColor: (control.mediaBinModel && (control.mediaBinModel.minDurationFilter > 0 || control.mediaBinModel.maxDurationFilter > 0)) ? "#fff" : "#333"
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        tooltip: "Clear Duration"
                        iconSource: "qrc:/assets/icons/clear.svg"
                        onClicked: {
                            durMinInput.text = "";
                            durMaxInput.text = "";
                            if (control.mediaBinModel) control.mediaBinModel.setDurationRange(0, 0);
                        }
                    }
                }

                // RowLayout {
                //     Layout.fillWidth: true
                //     spacing: 6
                //
                //     XylaIconButton {
                //         implicitWidth: 30
                //         implicitHeight: 30
                //         iconSource: "qrc:/assets/icons/zoom-out.svg"
                //         ghost: true
                //         onClicked: {
                //             var cur = control.mediaBinModel ? control.mediaBinModel.maxDurationFilter : 600;
                //             var nextVal = Math.max(0, (cur > 0 ? cur : 600) - 30);
                //             durMaxInput.text = nextVal.toString();
                //             if (control.mediaBinModel) control.mediaBinModel.maxDurationFilter = nextVal;
                //         }
                //     }
                //
                //     Item {
                //         id: durSlider
                //         Layout.fillWidth: true
                //         Layout.preferredHeight: 32
                //
                //         readonly property real maxLimit: 600.0
                //
                //         property real minVal: (!control.mediaBinModel || control.mediaBinModel.minDurationFilter <= 0) ? 0.0 : Math.min(control.mediaBinModel.minDurationFilter, maxLimit)
                //         property real maxVal: (!control.mediaBinModel || control.mediaBinModel.maxDurationFilter <= 0) ? maxLimit : Math.min(control.mediaBinModel.maxDurationFilter, maxLimit)
                //
                //         Rectangle {
                //             id: durTrackGroove
                //             anchors.verticalCenter: parent.verticalCenter
                //             width: parent.width
                //             height: 28
                //             radius: 10
                //             color: "#232323"
                //             clip: true
                //
                //             Rectangle {
                //                 id: durProgressFill
                //                 x: (durSlider.minVal / durSlider.maxLimit) * parent.width
                //                 width: Math.min(parent.width - x, Math.max(10, ((durSlider.maxVal - durSlider.minVal) / durSlider.maxLimit) * parent.width))
                //                 height: parent.height
                //
                //                 topLeftRadius: 5 // 10
                //                 bottomLeftRadius: 5 // 10
                //                 topRightRadius: 5
                //                 bottomRightRadius: 5
                //                 color: "#d8d8d8"
                //
                //                 Rectangle {
                //                     id: durLeftIndicator
                //                     anchors.left: parent.left
                //                     anchors.leftMargin: 2
                //                     anchors.verticalCenter: parent.verticalCenter
                //                     width: 6
                //                     height: 22
                //                     radius: 3
                //                     color: "#232323"
                //                 }
                //
                //                 Rectangle {
                //                     id: durRightIndicator
                //                     anchors.right: parent.right
                //                     anchors.rightMargin: 2
                //                     anchors.verticalCenter: parent.verticalCenter
                //                     width: 6
                //                     height: 22
                //                     radius: 3
                //                     color: "#232323"
                //                 }
                //             }
                //         }
                //
                //         Rectangle {
                //             id: durLeftThumb
                //             x: Math.max(0, Math.min(parent.width - width, (durSlider.minVal / durSlider.maxLimit) * parent.width))
                //             anchors.verticalCenter: parent.verticalCenter
                //             width: 14
                //             height: 28
                //             color: "transparent"
                //
                //             MouseArea {
                //                 anchors.fill: parent
                //                 drag.target: parent
                //                 drag.axis: Drag.XAxis
                //                 drag.minimumX: 0
                //                 drag.maximumX: durRightThumb.x - 12
                //                 cursorShape: Qt.SizeHorCursor
                //
                //                 onPositionChanged: {
                //                     if (drag.active) {
                //                         var sec = Math.round((parent.x / (durSlider.width - parent.width)) * durSlider.maxLimit);
                //                         durMinInput.text = sec > 0 ? sec.toString() : "";
                //                         if (control.mediaBinModel) control.mediaBinModel.minDurationFilter = sec;
                //                     }
                //                 }
                //             }
                //         }
                //
                //         Rectangle {
                //             id: durRightThumb
                //             x: Math.max(durLeftThumb.x + 12, Math.min(parent.width - width, (durSlider.maxVal / durSlider.maxLimit) * parent.width))
                //             anchors.verticalCenter: parent.verticalCenter
                //             width: 14
                //             height: 28
                //             color: "transparent"
                //
                //             MouseArea {
                //                 anchors.fill: parent
                //                 drag.target: parent
                //                 drag.axis: Drag.XAxis
                //                 drag.minimumX: durLeftThumb.x + 12
                //                 drag.maximumX: durSlider.width - width
                //                 cursorShape: Qt.SizeHorCursor
                //
                //                 onPositionChanged: {
                //                     if (drag.active) {
                //                         var sec = Math.round((parent.x / (durSlider.width - parent.width)) * durSlider.maxLimit);
                //                         durMaxInput.text = sec < durSlider.maxLimit ? sec.toString() : "";
                //                         if (control.mediaBinModel) {
                //                             control.mediaBinModel.maxDurationFilter = (sec >= durSlider.maxLimit) ? 0 : sec;
                //                         }
                //                     }
                //                 }
                //             }
                //         }
                //     }
                //
                //     XylaIconButton {
                //         implicitWidth: 30
                //         implicitHeight: 30
                //         iconSource: "qrc:/assets/icons/zoom-in.svg"
                //         ghost: true
                //         onClicked: {
                //             var cur = control.mediaBinModel ? control.mediaBinModel.maxDurationFilter : 600;
                //             var nextVal = Math.min(600, (cur > 0 ? cur : 600) + 30);
                //             durMaxInput.text = nextVal < 600 ? nextVal.toString() : "";
                //             if (control.mediaBinModel) control.mediaBinModel.maxDurationFilter = (nextVal >= 600) ? 0 : nextVal;
                //         }
                //     }
                // }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 6
                        color: "#202020"
                        border.color: durMinInput.activeFocus ? "#2555D3" : "#2d2d2d"

                        TextInput {
                            id: durMinInput
                            anchors.fill: parent
                            anchors.margins: 6
                            clip: true
                            color: "#ffffff"
                            font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: 0; decimals: 1 }

                            Text {
                                anchors.fill: parent
                                text: "Min (s)"
                                color: "#555555"
                                font.pixelSize: 10
                                verticalAlignment: TextInput.AlignVCenter
                                visible: !durMinInput.text && !durMinInput.activeFocus
                            }
                            onEditingFinished: if (control.mediaBinModel) control.mediaBinModel.minDurationFilter = parseFloat(text) || 0.0;
                        }
                    }

                    Text { text: "–"; color: "#666666"; font.pixelSize: 11 }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 6
                        color: "#202020"
                        border.color: durMaxInput.activeFocus ? "#2555D3" : "#2d2d2d"

                        TextInput {
                            id: durMaxInput
                            anchors.fill: parent
                            anchors.margins: 6
                            color: "#ffffff"
                            clip: true
                            font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: 0; decimals: 1 }

                            Text {
                                anchors.fill: parent
                                text: "Max (s)"
                                color: "#555555"
                                font.pixelSize: 10
                                verticalAlignment: TextInput.AlignVCenter
                                visible: !durMaxInput.text && !durMaxInput.activeFocus
                            }
                            onEditingFinished: if (control.mediaBinModel) control.mediaBinModel.maxDurationFilter = parseFloat(text) || 0.0;
                        }
                    }
                }
            }

            // ================= 5. FILE SIZE RANGE (1-to-1 Pill Track Slider) =================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "File Size"
                        color: "#888888"
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                    XylaIconButton {
                        ghost: true
                        iconColor: (control.mediaBinModel && (control.mediaBinModel.minSizeMBFilter > 0 || control.mediaBinModel.maxSizeMBFilter > 0)) ? "#fff" : "#333"
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        tooltip: "Clear Size"
                        iconSource: "qrc:/assets/icons/clear.svg"
                        onClicked: {
                            sizeMinInput.text = "";
                            sizeMaxInput.text = "";
                            if (control.mediaBinModel) control.mediaBinModel.setSizeRangeMB(0, 0);
                        }
                    }
                }

                // RowLayout {
                //     Layout.fillWidth: true
                //     spacing: 6
                //
                //     XylaIconButton {
                //         implicitWidth: 30
                //         implicitHeight: 30
                //         iconSource: "qrc:/assets/icons/zoom-out.svg"
                //         ghost: true
                //         onClicked: {
                //             var cur = control.mediaBinModel ? control.mediaBinModel.maxSizeMBFilter : 2048;
                //             var nextVal = Math.max(0, (cur > 0 ? cur : 2048) - 100);
                //             sizeMaxInput.text = nextVal.toString();
                //             if (control.mediaBinModel) control.mediaBinModel.maxSizeMBFilter = nextVal;
                //         }
                //     }
                //
                //     Item {
                //         id: szSlider
                //         Layout.fillWidth: true
                //         Layout.preferredHeight: 32
                //
                //         readonly property real maxLimit: 2048.0
                //
                //         property real minVal: (!control.mediaBinModel || control.mediaBinModel.minSizeMBFilter <= 0) ? 0.0 : Math.min(control.mediaBinModel.minSizeMBFilter, maxLimit)
                //         property real maxVal: (!control.mediaBinModel || control.mediaBinModel.maxSizeMBFilter <= 0) ? maxLimit : Math.min(control.mediaBinModel.maxSizeMBFilter, maxLimit)
                //
                //         Rectangle {
                //             id: szTrackGroove
                //             anchors.verticalCenter: parent.verticalCenter
                //             width: parent.width
                //             height: 28
                //             radius: 10
                //             color: "#232323"
                //             clip: true
                //
                //             Rectangle {
                //                 id: szProgressFill
                //                 x: (szSlider.minVal / szSlider.maxLimit) * parent.width
                //                 width: Math.min(parent.width - x, Math.max(10, ((szSlider.maxVal - szSlider.minVal) / szSlider.maxLimit) * parent.width))
                //                 height: parent.height
                //
                //                 topLeftRadius: 5 // 10
                //                 bottomLeftRadius: 5 // 10
                //                 topRightRadius: 5
                //                 bottomRightRadius: 5
                //                 color: "#d8d8d8"
                //
                //                 Rectangle {
                //                     id: szLeftIndicator
                //                     anchors.left: parent.left
                //                     anchors.leftMargin: 2
                //                     anchors.verticalCenter: parent.verticalCenter
                //                     width: 6
                //                     height: 22
                //                     radius: 3
                //                     color: "#232323"
                //                 }
                //
                //                 Rectangle {
                //                     id: szRightIndicator
                //                     anchors.right: parent.right
                //                     anchors.rightMargin: 2
                //                     anchors.verticalCenter: parent.verticalCenter
                //                     width: 6
                //                     height: 22
                //                     radius: 3
                //                     color: "#232323"
                //                 }
                //             }
                //         }
                //
                //         Rectangle {
                //             id: szLeftThumb
                //             x: Math.max(0, Math.min(parent.width - width, (szSlider.minVal / szSlider.maxLimit) * parent.width))
                //             anchors.verticalCenter: parent.verticalCenter
                //             width: 14
                //             height: 28
                //             color: "transparent"
                //
                //             MouseArea {
                //                 anchors.fill: parent
                //                 drag.target: parent
                //                 drag.axis: Drag.XAxis
                //                 drag.minimumX: 0
                //                 drag.maximumX: szRightThumb.x - 12
                //                 cursorShape: Qt.SizeHorCursor
                //
                //                 onPositionChanged: {
                //                     if (drag.active) {
                //                         var mb = Math.round((parent.x / (szSlider.width - parent.width)) * szSlider.maxLimit);
                //                         sizeMinInput.text = mb > 0 ? mb.toString() : "";
                //                         if (control.mediaBinModel) control.mediaBinModel.minSizeMBFilter = mb;
                //                     }
                //                 }
                //             }
                //         }
                //
                //         Rectangle {
                //             id: szRightThumb
                //             x: Math.max(szLeftThumb.x + 12, Math.min(parent.width - width, (szSlider.maxVal / szSlider.maxLimit) * parent.width))
                //             anchors.verticalCenter: parent.verticalCenter
                //             width: 14
                //             height: 28
                //             color: "transparent"
                //
                //             MouseArea {
                //                 anchors.fill: parent
                //                 drag.target: parent
                //                 drag.axis: Drag.XAxis
                //                 drag.minimumX: szLeftThumb.x + 12
                //                 drag.maximumX: szSlider.width - width
                //                 cursorShape: Qt.SizeHorCursor
                //
                //                 onPositionChanged: {
                //                     if (drag.active) {
                //                         var mb = Math.round((parent.x / (szSlider.width - parent.width)) * szSlider.maxLimit);
                //                         sizeMaxInput.text = mb < szSlider.maxLimit ? mb.toString() : "";
                //                         if (control.mediaBinModel) {
                //                             control.mediaBinModel.maxSizeMBFilter = (mb >= szSlider.maxLimit) ? 0 : mb;
                //                         }
                //                     }
                //                 }
                //             }
                //         }
                //     }
                //
                //     XylaIconButton {
                //         implicitWidth: 30
                //         implicitHeight: 30
                //         iconSource: "qrc:/assets/icons/zoom-in.svg"
                //         ghost: true
                //         onClicked: {
                //             var cur = control.mediaBinModel ? control.mediaBinModel.maxSizeMBFilter : 2048;
                //             var nextVal = Math.min(2048, (cur > 0 ? cur : 2048) + 100);
                //             sizeMaxInput.text = nextVal < 2048 ? nextVal.toString() : "";
                //             if (control.mediaBinModel) control.mediaBinModel.maxSizeMBFilter = (nextVal >= 2048) ? 0 : nextVal;
                //         }
                //     }
                // }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 6
                        color: "#202020"
                        border.color: sizeMinInput.activeFocus ? "#2555D3" : "#2d2d2d"

                        TextInput {
                            id: sizeMinInput
                            anchors.fill: parent
                            anchors.margins: 6
                            clip: true
                            color: "#ffffff"
                            font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: 0; decimals: 1 }

                            Text {
                                anchors.fill: parent
                                text: "Min (MB)"
                                color: "#555555"
                                font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                                visible: !sizeMinInput.text && !sizeMinInput.activeFocus
                            }
                            onEditingFinished: if (control.mediaBinModel) control.mediaBinModel.minSizeMBFilter = parseFloat(text) || 0.0;
                        }
                    }

                    Text { text: "–"; color: "#666666"; font.pixelSize: 11 }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 6
                        color: "#202020"
                        border.color: sizeMaxInput.activeFocus ? "#2555D3" : "#2d2d2d"

                        TextInput {
                            id: sizeMaxInput
                            anchors.fill: parent
                            anchors.margins: 6
                            clip: true
                            color: "#ffffff"
                            font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                            validator: DoubleValidator { bottom: 0; decimals: 1 }

                            Text {
                                anchors.fill: parent
                                text: "Max (MB)"
                                color: "#555555"
                                font.pixelSize: 10
                            verticalAlignment: TextInput.AlignVCenter
                                visible: !sizeMaxInput.text && !sizeMaxInput.activeFocus
                            }
                            onEditingFinished: if (control.mediaBinModel) control.mediaBinModel.maxSizeMBFilter = parseFloat(text) || 0.0;
                        }
                    }
                }
            }
        }
    }
}
