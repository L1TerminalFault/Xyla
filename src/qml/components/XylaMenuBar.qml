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

        contentItem: Text {
            padding: 5
            text: menuBarItem.text
            color: menuBarItem.enabled ? (menuBarItem.highlighted ? "#ffffff" : "#cccccc") : "#555555"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            anchors.fill: parent
            radius: 6
            color: menuBarItem.highlighted ? "#252525" : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 100
                    easing.type: Easing.OutCubic
                }
            }

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

    Instantiator {
        model: typeof menuManager !== "undefined" ? menuManager.menuTree : []

        delegate: XylaMenu {
            id: topMenu
            title: modelData.title || ""

            menuIcon: (modelData && modelData.icon) ? modelData.icon : ""
            menuDescription: (modelData && modelData.description) ? modelData.description : ""

            Instantiator {
                model: modelData.items || []

                delegate: Loader {
                    id: level2Loader
                    property var dataContext: modelData

                    sourceComponent: {
                        if (!modelData)
                            return null
                        if (modelData.isSeparator)
                            return separatorComp
                        if (modelData.isSubmenu)
                            return submenuComp
                        return menuItemComp
                    }

                    onLoaded: {
                        if (!item)
                            return
                        if ("itemData" in item)
                            item.itemData = level2Loader.dataContext
                        if ("subMenuData" in item)
                            item.subMenuData = level2Loader.dataContext
                    }
                }

                onObjectAdded: (index, object) => {
                    function insertChild() {
                        var childItem = object.item
                        if (!childItem)
                            return
                        if (object.dataContext && object.dataContext.isSubmenu)
                            topMenu.insertMenu(index, childItem)
                        else
                            topMenu.insertItem(index, childItem)
                    }
                    if (object.item)
                        insertChild()
                    else
                        object.loaded.connect(insertChild)
                }

                onObjectRemoved: (index, object) => {
                    if (!object.item)
                        return
                    if (object.dataContext && object.dataContext.isSubmenu)
                        topMenu.removeMenu(object.item)
                    else
                        topMenu.removeItem(object.item)
                }
            }
        }

        onObjectAdded: (index, object) => menuBar.insertMenu(index, object)
        onObjectRemoved: (index, object) => menuBar.removeMenu(object)
    }

    Component {
        id: menuItemComp
        XylaMenuItem {
            id: itemWrapper
            property var itemData: null
            property string actionIdentifier: itemData ? (itemData.id || "") : ""

            descriptionText: (itemData && itemData.description) ? itemData.description : ""
            itemIcon: (itemData && itemData.icon) ? itemData.icon : ""
            itemShortcut: (itemData && itemData.shortcut) ? itemData.shortcut : ""
            itemIsSubmenu: false

            action: Action {
                text: (itemWrapper.itemData && itemWrapper.itemData.title) ? itemWrapper.itemData.title : ""
                shortcut: (itemWrapper.itemData && itemWrapper.itemData.shortcut) ? itemWrapper.itemData.shortcut : ""
                icon.source: (itemWrapper.itemData && itemWrapper.itemData.icon) ? itemWrapper.itemData.icon : ""
                enabled: (itemWrapper.itemData && itemWrapper.itemData.enabled !== undefined) ? itemWrapper.itemData.enabled : true
                onTriggered: {
                    if (typeof menuManager !== "undefined")
                        menuManager.triggerAction(itemWrapper.actionIdentifier)
                }
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

            menuIcon: (subMenuData && subMenuData.icon) ? subMenuData.icon : ""
            menuDescription: (subMenuData && subMenuData.description) ? subMenuData.description : ""
            icon.source: menuIcon
            enabled: (subMenuData && subMenuData.enabled !== undefined) ? subMenuData.enabled : true
            title: (subMenuData && subMenuData.title) ? subMenuData.title : ""

            Instantiator {
                model: (nestedSubMenu.subMenuData && nestedSubMenu.subMenuData.items) ? nestedSubMenu.subMenuData.items : []

                delegate: Loader {
                    id: level3Loader
                    property var dataContext: modelData

                    sourceComponent: {
                        if (!modelData)
                            return null
                        if (modelData.isSeparator)
                            return separatorComp
                        if (modelData.isSubmenu)
                            return submenuComp
                        return menuItemComp
                    }

                    onLoaded: {
                        if (!item)
                            return
                        if ("itemData" in item)
                            item.itemData = level3Loader.dataContext
                        if ("subMenuData" in item)
                            item.subMenuData = level3Loader.dataContext
                    }
                }

                onObjectAdded: (index, object) => {
                    function insertChild() {
                        var childItem = object.item
                        if (!childItem)
                            return
                        if (object.dataContext && object.dataContext.isSubmenu)
                            nestedSubMenu.insertMenu(index, childItem)
                        else
                            nestedSubMenu.insertItem(index, childItem)
                    }
                    if (object.item)
                        insertChild()
                    else
                        object.loaded.connect(insertChild)
                }

                onObjectRemoved: (index, object) => {
                    if (!object.item)
                        return
                    if (object.dataContext && object.dataContext.isSubmenu)
                        nestedSubMenu.removeMenu(object.item)
                    else
                        nestedSubMenu.removeItem(object.item)
                }
            }
        }
    }
}
