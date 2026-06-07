import QtQuick

Rectangle {
    id: badge

    property string text: "Unknown"
    property real fontScale: 1.0
    property color textColor: "#1b2236"

    implicitWidth: Math.max(130, badgeText.implicitWidth + 24)
    implicitHeight: 38
    radius: 14

    function fs(value) {
        return value * badge.fontScale
    }

    Text {
        id: badgeText
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 16)
        text: badge.text
        font.pointSize: badge.fs(16)
        color: badge.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
