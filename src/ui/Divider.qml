import QtQuick
import "Theme.js" as Theme

Rectangle {
    id: divider

    property color dividerColor: Theme.borderSoft

    implicitHeight: 1
    color: divider.dividerColor
}
