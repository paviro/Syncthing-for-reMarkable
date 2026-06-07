import QtQuick

Rectangle {
    id: progressBar

    property real value: 0
    property color trackColor: "#cbd3e4"
    property color fillColor: "#1887f0"
    property real fillOpacity: 1.0

    implicitHeight: 14
    radius: 8
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
        color: progressBar.fillColor
        opacity: progressBar.fillOpacity
    }
}
