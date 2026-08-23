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

    delegate: MenuBarItem {
        id: menuBarItem
        contentItem: Text {
            text: menuBarItem.text
            color: menuBarItem.highlighted ? "#ffffff" : "#cccccc"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: menuBarItem.highlighted ? "#262626" : "transparent"
            radius: 4
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
        XylaMenuSeparator {}
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
