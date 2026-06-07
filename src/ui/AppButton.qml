import QtQuick
import "Theme.js" as Theme

Rectangle {
    id: button

    property string text: ""
    property real fontScale: 1.0
    property color fillColor: Theme.accent
    property color pressedColor: Theme.accentPressed
    property color disabledFillColor: Theme.mutedBg
    property color textColor: Theme.onAccent
    property color disabledTextColor: Theme.textSubtle
    property color outlineColor: fillColor
    property color disabledOutlineColor: Theme.borderSoft
    property int buttonRadius: 10

    signal clicked()

    implicitWidth: 160
    implicitHeight: 60
    radius: button.buttonRadius
    border.width: 1
    border.color: button.enabled ? button.outlineColor : button.disabledOutlineColor
    color: button.enabled ? (mouseArea.pressed ? button.pressedColor : button.fillColor) : button.disabledFillColor
    opacity: button.enabled ? 1.0 : 0.86

    function fs(value) {
        return value * button.fontScale
    }

    Text {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 24)
        text: button.text
        font.pointSize: button.fs(18)
        font.bold: true
        color: button.enabled ? button.textColor : button.disabledTextColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: button.enabled
        onClicked: button.clicked()
    }
}
