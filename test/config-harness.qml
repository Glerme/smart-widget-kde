// Renderiza a página de configurações fora do Plasma e salva capturas dos estados do login.
import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Window {
    id: win
    width: 640
    height: 680
    visible: true
    color: Kirigami.Theme.backgroundColor

    property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]

    Loader {
        id: loader
        anchors.fill: parent
        source: "../package/contents/ui/configGeneral.qml"
        onLoaded: {
            item.cfg_clientId = "c0ffee00-1234-4abc-9def-001122334455"
            item.cfg_clientSecret = "segredo-de-exemplo"
            item.cfg_redirectUri = "https://httpbin.org/get"
            item.cfg_pollSeconds = 30
        }
    }

    function shot(name, next) {
        loader.item.grabToImage(result => {
            result.saveToFile(win.outDir + "/" + name + ".png")
            console.log("SHOT", name, "step=" + loader.item.step, "loggedIn=" + loader.item.loggedIn)
            next()
        })
    }

    property int step: 0
    Timer {
        interval: 800
        running: true
        repeat: true
        onTriggered: {
            win.step++
            const page = loader.item
            switch (win.step) {
            case 1:
                // Só o estado visual do passo "aguardando código"; não abre o navegador.
                page.step = "waiting"
                break
            case 2:
                win.shot("settings-login", () => {
                    page.step = "done"
                    page.cfg_token = "token-de-exemplo"
                    page.cfg_refreshToken = "refresh-de-exemplo"
                })
                break
            case 3:
                win.shot("settings-connected", () => Qt.quit())
                break
            }
        }
    }
}
