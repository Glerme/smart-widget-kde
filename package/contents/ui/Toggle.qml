import QtQuick

Rectangle {
    id: toggle

    property bool checked: false

    implicitWidth: 38
    implicitHeight: 20
    radius: height / 2
    color: checked ? "#8f8776" : "#2c2c2c"
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: 22
        height: parent.height - 6
        radius: height / 2
        y: 3
        x: toggle.checked ? parent.width - width - 3 : 3
        color: "#f1ece0"
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }
}
