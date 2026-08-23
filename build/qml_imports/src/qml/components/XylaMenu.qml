import QtQuick
import QtQuick.Controls

Menu {
    id: customMenu

    // Dynamic Width Calculation Loop
    // Forces the popup container window to fit the widest inner text/shortcut
    width: {
        var maxWidth = 160; // Minimum default width so it looks professional
        for (var i = 0; i < customMenu.count; ++i) {
            var item = customMenu.itemAt(i);
            if (item && item.implicitWidth) {
                maxWidth = Math.max(maxWidth, item.implicitWidth);
            }
        }
        return maxWidth;
    }

    background: Rectangle {
        color: "#1e1e1e"
        border.color: "#2d2d2d"
        border.width: 1
        radius: 6
    }
}
