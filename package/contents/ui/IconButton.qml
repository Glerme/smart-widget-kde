import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: button

    property string icon
    property bool highlighted: false
    property real iconSize: Math.round(width * 0.5)
    signal clicked()

    implicitWidth: 34
    implicitHeight: 34
    radius: width / 2
    color: highlighted ? "#e9e2d2" : (area.containsMouse ? "#2a2a2a" : "#1b1b1b")
    opacity: enabled ? 1 : 0.4
    scale: area.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: 80 } }
    Behavior on color { ColorAnimation { duration: 120 } }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: button.iconSize
        height: width
        source: button.icon
        isMask: true
        color: button.highlighted ? "#111111" : "#e9e2d2"
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
