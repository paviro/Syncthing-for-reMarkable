import QtQuick
import "Theme.js" as Theme

Rectangle {
    id: progressBar

    property real value: 0
    property color trackColor: Theme.mutedBg
    property color fillColor: Theme.accent
    property color fillBorderColor: "transparent"
    property int fillBorderWidth: 0
    property real fillOpacity: 1.0

    implicitHeight: 14
    radius: 8
    border.width: 1
    border.color: Theme.borderSoft
    color: progressBar.trackColor

    function normalizedValue() {
        var numeric = Number(progressBar.value)
        if (!isFinite(numeric))
            numeric = 0
        return Math.max(0, Math.min(1, numeric / 100))
    }

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        width: parent.width * progressBar.normalizedValue()
        radius: parent.radius
        border.width: progressBar.fillBorderWidth
        border.color: progressBar.fillBorderColor
        color: progressBar.fillColor
        opacity: progressBar.fillOpacity
    }
}
