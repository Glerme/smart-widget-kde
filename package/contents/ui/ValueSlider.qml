import QtQuick

Item {
    id: slider

    property real from: 0
    property real to: 100
    property real value: 0
    signal moved(real value)

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    implicitHeight: 34
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: 9
        color: "#161616"
    }

    Rectangle {
        height: parent.height
        width: handle.x + handle.width
        radius: 9
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#2a2722" }
            GradientStop { position: 1; color: "#7d7667" }
        }
    }

    Rectangle {
        id: handle
        width: 20
        height: parent.height
        radius: 6
        color: "#e9e2d2"
        x: slider.ratio * (slider.width - width)
        Behavior on x {
            enabled: !area.pressed
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function update(mouseX) {
            const r = Math.max(0, Math.min(1, (mouseX - handle.width / 2) / (slider.width - handle.width)))
            slider.moved(Math.round(slider.from + r * (slider.to - slider.from)))
        }
        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => update(mouse.x)
        onWheel: wheel => slider.moved(slider.value + (wheel.angleDelta.y > 0 ? 1 : -1))
    }
}
