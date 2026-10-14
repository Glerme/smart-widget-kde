// Carrega o popup contra o servidor falso, exercita os controles e salva capturas.
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../package/contents/ui"

Window {
    id: win
    width: 420
    height: 492
    visible: true
    color: "#6f8a7a"

    property string base: Qt.application.arguments[Qt.application.arguments.length - 2]
    property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]

    Backend {
        id: st
        apiBase: win.base + "/v1"
        tokenUrl: win.base + "/oauth/token"
        token: "access-expired"
        clientId: "client"
        clientSecret: "secret"
        refreshToken: "refresh-1"
        selectedDeviceId: "ac-1"
        active: true
        onTokensRefreshed: (accessToken, newRefreshToken) => {
            token = accessToken
            refreshToken = newRefreshToken
        }
    }

    FullView {
        id: view
        anchors.centerIn: parent
        backend: st
    }

    // Faixa imitando o painel do Plasma, para o print da visão compacta.
    Rectangle {
        id: panel
        y: win.height
        width: 260
        height: 40
        color: "#202326"
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            Repeater {
                model: ["network-wireless-symbolic", "audio-volume-high-symbolic", "battery-good-symbolic"]
                Kirigami.Icon {
                    required property string modelData
                    width: 18
                    height: 18
                    source: modelData
                    color: "#fcfcfc"
                    isMask: true
                }
            }
        }
        CompactView {
            anchors.right: clock.left
            anchors.rightMargin: 16
            width: Layout.preferredWidth
            height: parent.height
            backend: st
            Kirigami.Theme.textColor: "#fcfcfc"
        }
        Text {
            id: clock
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "10:42"
            color: "#fcfcfc"
            font.pixelSize: 14
        }
    }

    function shot(name, next, item) {
        (item || view).grabToImage(result => {
            result.saveToFile(win.outDir + "/" + name + ".png")
            console.log("SHOT", name, "token=" + st.token, "refresh=" + st.refreshToken,
                        "devices=" + st.devices.length, "kind=" + st.kind, "on=" + st.isOn,
                        "primary=" + (st.primary ? st.primary.value : "-"), "tiles=" + st.tiles.length,
                        "syncing=" + st.syncing, "error=" + st.error)
            next()
        })
    }

    property int step: 0
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            win.step++
            switch (win.step) {
            case 1:
                win.shot("0-panel", () => {}, panel)
                win.shot("1-ac", () => {
                    // Três passos seguidos devem virar um único comando.
                    st.setPrimary(22); st.setPrimary(21); st.setPrimary(20)
                    st.toggleQuickMode()
                    st.chooseTile(st.tiles[0], "dry")
                })
                break
            case 2: win.shot("2-ac-changed", () => st.togglePower()); break
            case 3: win.shot("3-ac-off", () => st.selectDevice("light-1")); break
            case 4: win.shot("4-light", () => { st.selectDevice("plug-1"); st.refreshAll(); view.showingList = true }); break
            case 5: win.shot("5-list", () => { view.showingList = false; st.togglePower() }); break
            case 6: win.shot("6-plug", () => { st.token = ""; st.clientId = "" }); break
            case 7: win.shot("7-unconfigured", () => Qt.quit()); break
            }
        }
    }
}
