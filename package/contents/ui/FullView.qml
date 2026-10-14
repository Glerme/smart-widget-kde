import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: view

    required property Backend backend
    property bool showingList: false
    signal configureRequested()

    implicitWidth: 380
    implicitHeight: 452
    Layout.minimumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    radius: 18
    color: "#0d0d0d"
    border.color: "#262626"

    readonly property var primary: backend.primary
    readonly property bool controllable: !backend.hasPower || backend.isOn

    // ---- Sem token ----
    ColumnLayout {
        visible: !view.backend.configured
        anchors.centerIn: parent
        width: parent.width - 60
        spacing: 14
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#b9b2a3"
            font.pixelSize: 13
            text: "Entre com a sua conta Samsung nas configurações para listar seus dispositivos."
        }
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: configureLabel.implicitWidth + 28
            implicitHeight: 34
            radius: 17
            color: "#e9e2d2"
            Text {
                id: configureLabel
                anchors.centerIn: parent
                text: "Configurar"
                color: "#111111"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: view.configureRequested()
            }
        }
    }

    // ---- Dispositivo ----
    ColumnLayout {
        visible: view.backend.configured && !view.showingList
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.maximumWidth: 210
                implicitWidth: nameRow.implicitWidth + 16
                implicitHeight: 30
                radius: 15
                color: nameArea.containsMouse ? "#222222" : "transparent"
                RowLayout {
                    id: nameRow
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 4
                    Text {
                        Layout.fillWidth: true
                        text: view.backend.current ? view.backend.current.label : "Dispositivos"
                        color: "#f1ece0"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Kirigami.Icon {
                        Layout.preferredWidth: 12
                        Layout.preferredHeight: 12
                        source: "go-down-symbolic"
                        isMask: true
                        color: "#8a8478"
                    }
                }
                MouseArea {
                    id: nameArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.backend.refreshAll()
                        view.showingList = true
                    }
                }
            }

            RowLayout {
                visible: view.backend.roomTemperature !== undefined
                spacing: 3
                Kirigami.Icon {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    source: "temperature-normal-symbolic"
                    isMask: true
                    color: "#8a8478"
                }
                Text {
                    text: Math.round(view.backend.roomTemperature) + "°C"
                    color: "#b9b2a3"
                    font.pixelSize: 12
                }
            }

            Item { Layout.fillWidth: true }

            IconButton {
                visible: view.backend.hasPower
                icon: "system-shutdown-symbolic"
                highlighted: view.backend.isOn
                onClicked: view.backend.togglePower()
            }
        }

        DeviceArt {
            Layout.fillWidth: true
            Layout.fillHeight: true
            kind: view.backend.kind
            on: view.backend.isOn
            level: view.primary && view.backend.kind === "light" ? view.primary.value / 100 : 1
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: view.primary ? view.primary.value : (view.backend.hasPower ? (view.backend.isOn ? "Ligado" : "Desligado") : "—")
                color: view.controllable ? "#f7f3ea" : "#6b665c"
                font.pixelSize: view.primary ? 44 : 28
                font.weight: Font.DemiBold
            }
            Text {
                visible: !!view.primary
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 8
                text: view.primary ? view.primary.unit : ""
                color: "#8a8478"
                font.pixelSize: 18
            }
            Item { Layout.fillWidth: true }

            Rectangle {
                visible: !!view.backend.quickMode
                enabled: view.controllable
                opacity: enabled ? 1 : 0.45
                implicitWidth: quickRow.implicitWidth + 24
                implicitHeight: 38
                radius: 10
                color: "#181818"
                RowLayout {
                    id: quickRow
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        text: view.backend.quickMode ? view.backend.quickMode.label : ""
                        color: "#f1ece0"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Toggle {
                        checked: !!view.backend.quickMode && view.backend.quickMode.on
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.backend.toggleQuickMode()
                }
            }
        }

        RowLayout {
            visible: !!view.primary
            enabled: view.controllable
            Layout.fillWidth: true
            spacing: 10

            IconButton {
                Layout.alignment: Qt.AlignTop
                icon: "list-remove-symbolic"
                onClicked: view.backend.setPrimary(view.primary.value - 1)
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ValueSlider {
                    Layout.fillWidth: true
                    from: view.primary ? view.primary.min : 0
                    to: view.primary ? view.primary.max : 100
                    value: view.primary ? view.primary.value : 0
                    onMoved: value => view.backend.setPrimary(value)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: view.primary ? view.primary.min + view.primary.suffix : ""
                        color: "#6b665c"
                        font.pixelSize: 10
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: view.primary ? view.primary.max + view.primary.suffix : ""
                        color: "#6b665c"
                        font.pixelSize: 10
                    }
                }
            }
            IconButton {
                Layout.alignment: Qt.AlignTop
                icon: "list-add-symbolic"
                onClicked: view.backend.setPrimary(view.primary.value + 1)
            }
        }

        RowLayout {
            visible: view.backend.tiles.length > 0
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: view.backend.tiles
                Tile {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    enabled: view.controllable
                    host: view
                    info: modelData
                    onChosen: value => view.backend.chooseTile(modelData, value)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Kirigami.Icon {
                id: statusIcon
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                source: view.backend.error !== "" ? "data-warning" : (view.backend.syncing ? "view-refresh-symbolic" : "emblem-ok-symbolic")
                isMask: true
                color: view.backend.error !== "" ? "#e0a070" : "#8a8478"
                RotationAnimation on rotation {
                    running: view.backend.syncing && view.backend.error === ""
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1200
                    onRunningChanged: if (!running) statusIcon.rotation = 0
                }
            }
            Text {
                Layout.fillWidth: true
                text: view.backend.error !== "" ? view.backend.error : (view.backend.syncing ? "Sincronizando…" : "Conectado")
                color: view.backend.error !== "" ? "#e0a070" : "#8a8478"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            IconButton {
                implicitWidth: 26
                implicitHeight: 26
                color: "transparent"
                icon: "configure"
                onClicked: view.configureRequested()
            }
        }
    }

    // ---- Lista de dispositivos ----
    ColumnLayout {
        visible: view.backend.configured && view.showingList
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            IconButton {
                icon: "go-previous-symbolic"
                onClicked: view.showingList = false
            }
            Text {
                Layout.fillWidth: true
                text: "Dispositivos"
                color: "#f1ece0"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            IconButton {
                icon: "view-refresh-symbolic"
                onClicked: view.backend.loadDevices()
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: view.backend.devices
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool hasSwitch: modelData.caps.includes("switch")
                readonly property bool on: view.backend.deviceIsOn(modelData.id)
                width: ListView.view.width
                height: 46
                radius: 10
                color: rowArea.containsMouse ? "#222222" : "#181818"
                border.color: modelData.id === view.backend.selectedDeviceId ? "#8f8776" : "transparent"

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.backend.selectDevice(row.modelData.id)
                        view.showingList = false
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.right: rowToggle.left
                    anchors.margins: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    color: "#f1ece0"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Toggle {
                    id: rowToggle
                    visible: row.hasSwitch
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    checked: row.on
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.backend.setPower(row.modelData.id, !row.on)
                    }
                }
            }

            Text {
                visible: parent.count === 0
                anchors.centerIn: parent
                text: view.backend.error !== "" ? view.backend.error : (view.backend.syncing ? "Carregando…" : "Nenhum dispositivo")
                color: "#8a8478"
                font.pixelSize: 12
            }
        }
    }
}
