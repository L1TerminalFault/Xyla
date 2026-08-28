import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

MenuBar {
    id: menuBar

    background: Rectangle {
        color: "#181818"
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#2d2d2d"
        }
    }

    leftPadding: 4
    rightPadding: 4
    topPadding: 4
    bottomPadding: 4

    delegate: MenuBarItem {
        id: menuBarItem

        implicitHeight: 32

        // The Top Buttons ("File", "Edit" .....)
        contentItem: Text {
            padding: 5
            text: menuBarItem.text

            color: menuBarItem.enabled ? (menuBarItem.highlighted ? "#ffffff" : "#cccccc") : "#555555"

            font.pixelSize: 12

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            id: menuBarItemBackground

            anchors.fill: parent

            radius: 6

            color: menuBarItem.highlighted ? "#252525" : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 100
                    easing.type: Easing.OutCubic
                }
            }

            // Slightly brighter pressed state
            Rectangle {
                anchors.fill: parent

                radius: parent.radius

                color: menuBarItem.pressed ? "#2b2b2b" : "transparent"

                opacity: menuBarItem.pressed ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 80
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // Level 1: Dynamic Top-Level Menu bar Category Headings (File, Edit, etc.)
    Instantiator {
        model: menuManager.menuTree

        delegate: XylaMenu {
            id: topMenu
            title: modelData.title || ""

            // Level 2: Dynamically populates items into dropdown panels
            Instantiator {
                model: modelData.items || []

                delegate: Loader {
                    id: level2Loader
                    property var dataContext: modelData

                    sourceComponent: {
                        if (modelData.isSeparator)
                            return separatorComp;
                        if (modelData.isSubmenu)
                            return submenuComp;
                        return menuItemComp;
                    }

                    onItemChanged: {
                        if (item) {
                            if ("itemData" in item)
                                item.itemData = Qt.binding(() => level2Loader.dataContext);
                            if ("subMenuData" in item)
                                item.subMenuData = Qt.binding(() => level2Loader.dataContext);
                        }
                    }
                }

                // FIX: Use insertMenu/insertItem with explicit index to preserve order
                onObjectAdded: (index, object) => {
                    if (object.item) {
                        if (modelData.isSubmenu) {
                            topMenu.insertMenu(index, object.item);
                        } else {
                            topMenu.insertItem(index, object.item);
                        }
                    } else {
                        object.loaded.connect(function () {
                            if (modelData.isSubmenu)
                                topMenu.insertMenu(index, object.item);
                            else
                                topMenu.insertItem(index, object.item);
                        });
                    }
                }
                onObjectRemoved: (index, object) => {
                    if (object.item) {
                        if (modelData.isSubmenu)
                            topMenu.removeMenu(object.item);
                        else
                            topMenu.removeItem(object.item);
                    }
                }
            }
        }

        onObjectAdded: (index, object) => menuBar.insertMenu(index, object)
        onObjectRemoved: (index, object) => menuBar.removeMenu(object)
    }

    // --- REUSABLE FACTORY COMPONENT BLOCKS ---

    Component {
        id: menuItemComp
        XylaMenuItem {
            id: itemWrapper

            property var itemData: null

            property string actionIdentifier: itemData ? (itemData.id || "") : ""
            descriptionText: (itemData && itemData.description) ? itemData.description : ""

            action: Action {
                text: (itemWrapper.itemData && itemWrapper.itemData.title) ? itemWrapper.itemData.title : ""
                shortcut: (itemWrapper.itemData && itemWrapper.itemData.shortcut) ? itemWrapper.itemData.shortcut : ""
                icon.source: (itemWrapper.itemData && itemWrapper.itemData.icon) ? itemWrapper.itemData.icon : ""
                enabled: (itemWrapper.itemData && itemWrapper.itemData.enabled !== undefined) ? itemWrapper.itemData.enabled : true

                onTriggered: menuManager.triggerAction(itemWrapper.actionIdentifier)
            }
        }
    }

    Component {
        id: separatorComp
        Item {
            implicitWidth: separator.implicitWidth
            // Total height = separator line + top margin + bottom margin
            implicitHeight: separator.implicitHeight + 12 

            XylaMenuSeparator {
                id: separator
                anchors.centerIn: parent
                width: parent.width
            }
        }
    }

    Component {
        id: submenuComp
        XylaMenu {
            id: nestedSubMenu

            property var subMenuData: null
            title: (subMenuData && subMenuData.title) ? subMenuData.title : ""

            // Level 3: Inner loop for deeper nested submenus
            Instantiator {
                model: (nestedSubMenu.subMenuData && nestedSubMenu.subMenuData.items) ? nestedSubMenu.subMenuData.items : []

                delegate: Loader {
                    id: level3Loader
                    property var dataContext: modelData

                    sourceComponent: {
                        if (modelData.isSeparator)
                            return separatorComp;
                        return menuItemComp;
                    }

                    onItemChanged: {
                        if (item && "itemData" in item) {
                            item.itemData = Qt.binding(() => level3Loader.dataContext);
                        }
                    }
                }

                onObjectAdded: (index, object) => {
                    if (object.item) {
                        nestedSubMenu.insertItem(index, object.item);
                    } else {
                        object.loaded.connect(function () {
                            if (object.item)
                                nestedSubMenu.insertItem(index, object.item);
                        });
                    }
                }
                onObjectRemoved: (index, object) => {
                    if (object.item)
                        nestedSubMenu.removeItem(object.item);
                }
            }
        }
    }
}
