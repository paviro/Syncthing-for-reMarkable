import QtQuick

Rectangle {
    id: button

    property string text: ""
    property real fontScale: 1.0
    property color fillColor: "#1887f0"
    property color pressedColor: "#0f6cca"
    property color disabledFillColor: "#cfd7eb"
    property color textColor: "#ffffff"
    property color disabledTextColor: "#ffffff"
    property int buttonRadius: 16

    signal clicked()

    implicitWidth: 160
    implicitHeight: 60
    radius: button.buttonRadius
    border.width: 0
    color: button.enabled ? (mouseArea.pressed ? button.pressedColor : button.fillColor) : button.disabledFillColor
    opacity: button.enabled ? 1.0 : 0.7

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
