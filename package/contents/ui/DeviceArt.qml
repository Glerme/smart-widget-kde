import QtQuick
import org.kde.kirigami as Kirigami

// Ilustração do dispositivo: ar-condicionado com fluxo de ar, lâmpada com brilho ou ícone genérico.
Item {
    id: art

    property string kind: "generic"
    property bool on: false
    // 0..1, usado pelo brilho da lâmpada
    property real level: 1

    implicitHeight: 120

    Item {
        visible: art.kind === "ac"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        width: 132
        height: 46

        Item {
            anchors.fill: parent
            opacity: art.on ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }

            Repeater {
                model: 11
                Rectangle {
                    id: streak
                    required property int index
                    x: 14 + index * 10
                    y: 42
                    width: 2
                    height: 54
                    radius: 1
                    transformOrigin: Item.Top
                    rotation: -(index - 5) / 5 * 22 + 6
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#70ffffff" }
                        GradientStop { position: 1; color: "#00ffffff" }
                    }
                    opacity: 0.25
                    SequentialAnimation on opacity {
                        running: art.on && art.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: streak.index * 70 }
                        NumberAnimation { to: 0.9; duration: 500 }
                        NumberAnimation { to: 0.25; duration: 700 }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 9
            gradient: Gradient {
                GradientStop { position: 0; color: "#ffffff" }
                GradientStop { position: 0.75; color: "#e4e4e4" }
                GradientStop { position: 1; color: "#bdbdbd" }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 20
                height: art.on ? 5 : 2
                radius: 2
                color: "#3a3a3a"
                Behavior on height { NumberAnimation { duration: 250 } }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 9
                width: 4
                height: 4
                radius: 2
                color: art.on ? "#7be08a" : "#b0b0b0"
            }
        }
    }

    Item {
        visible: art.kind === "light"
        anchors.centerIn: parent
        width: 96
        height: 96

        Rectangle {
            anchors.centerIn: parent
            width: 46 + 50 * art.level
            height: width
            radius: width / 2
            color: "#ffd98a"
            opacity: art.on ? 0.10 + 0.22 * art.level : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            Behavior on width { NumberAnimation { duration: 150 } }
        }
        Rectangle {
            id: bulb
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -6
            width: 44
            height: 44
            radius: 22
            color: art.on ? Qt.rgba(1, 0.86 + 0.08 * art.level, 0.55 + 0.25 * art.level, 1) : "#3a3a3a"
            Behavior on color { ColorAnimation { duration: 250 } }
        }
        Rectangle {
            anchors.top: bulb.bottom
            anchors.topMargin: -6
            anchors.horizontalCenter: parent.horizontalCenter
            width: 20
            height: 16
            radius: 4
            color: "#8a8478"
        }
    }

    Kirigami.Icon {
        visible: art.kind !== "ac" && art.kind !== "light"
        anchors.centerIn: parent
        width: 72
        height: 72
        source: art.kind === "audio" ? "audio-volume-high-symbolic" : "go-home-symbolic"
        isMask: true
        color: art.on ? "#e9e2d2" : "#4a463f"
        Behavior on color { ColorAnimation { duration: 250 } }
    }
}
