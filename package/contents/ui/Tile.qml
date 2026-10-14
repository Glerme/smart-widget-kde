import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: tile

    // { title, icon, value, valueLabel, options: [{ value, label }] }
    property var info
    // Item que cobre o card inteiro; o menu é desenhado sobre ele.
    required property Item host
    signal chosen(var value)

    implicitHeight: 70
    radius: 10
    color: area.containsMouse ? "#222222" : "#181818"
    opacity: enabled ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: 120 } }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 9
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                source: tile.info.icon
                isMask: true
                color: "#b9b2a3"
            }
            Item { Layout.fillWidth: true }
            Kirigami.Icon {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                visible: tile.info.options.length > 0
                source: "go-down-symbolic"
                isMask: true
                color: "#8a8478"
            }
        }
        Item { Layout.fillHeight: true }
        Text {
            Layout.fillWidth: true
            text: tile.info.title
            color: "#8a8478"
            font.pixelSize: 10
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: tile.info.valueLabel
            color: "#f1ece0"
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (menu.visible)
                menu.close()
            else if (tile.info.options.length > 0)
                menu.open()
        }
    }

    // Desenhado dentro da própria cena: como janela separada (padrão do Menu) o Plasma
    // não entrega o clique fora dele, e o menu só fechava ao escolher uma opção.
    Item {
        id: menu
        parent: tile.host
        anchors.fill: parent
        z: 100
        visible: false

        function open() {
            const origin = tile.mapToItem(tile.host, 0, 0)
            box.x = Math.max(8, Math.min(origin.x, tile.host.width - box.width - 8))
            box.y = Math.max(8, origin.y - box.height - 4)
            visible = true
            forceActiveFocus()
        }
        function close() {
            visible = false
        }

        Keys.onEscapePressed: close()

        // Fecha em qualquer clique fora; o clique segue adiante para já abrir outro menu,
        // exceto sobre o próprio botão, que só fecha.
        MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
                const p = mapToItem(tile, mouse.x, mouse.y)
                mouse.accepted = tile.contains(Qt.point(p.x, p.y))
                // Esconder durante a entrega do clique impediria que ele seguisse adiante.
                Qt.callLater(menu.close)
            }
        }

        Rectangle {
            id: box
            width: Math.max(tile.width, 124)
            height: options.height + 8
            radius: 10
            color: "#181818"
            border.color: "#2e2e2e"

            MouseArea { anchors.fill: parent }

            Column {
                id: options
                x: 4
                y: 4
                width: parent.width - 8
                Repeater {
                    model: tile.info.options
                    Rectangle {
                        id: option
                        required property var modelData
                        readonly property bool current: modelData.value === tile.info.value
                        width: parent.width
                        height: 28
                        radius: 7
                        color: optionArea.containsMouse ? "#2a2a2a" : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.right: check.left
                            anchors.leftMargin: 8
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            text: option.modelData.label
                            color: option.current ? "#f1ece0" : "#b9b2a3"
                            font.pixelSize: 12
                            font.weight: option.current ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                        Kirigami.Icon {
                            id: check
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12
                            height: 12
                            visible: option.current
                            source: "emblem-ok-symbolic"
                            isMask: true
                            color: "#f1ece0"
                        }
                        MouseArea {
                            id: optionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                menu.close()
                                tile.chosen(option.modelData.value)
                            }
                        }
                    }
                }
            }
        }
    }

    // O card some ao perder o foco; sem isto ele reabriria com o menu ainda aberto.
    Connections {
        target: tile.Window.window
        function onVisibleChanged() {
            if (!tile.Window.window.visible)
                menu.close()
        }
    }
}
