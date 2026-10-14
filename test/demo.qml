// Demonstração animada para o README: um cursor falso usa o popup contra o servidor falso
// enquanto cada quadro é salvo em PNG (test/run.sh --docs junta tudo em docs/demo.gif).
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../package/contents/ui"

Window {
    id: win
    width: 440
    height: 560
    visible: true
    color: "black"

    property string base: Qt.application.arguments[Qt.application.arguments.length - 2]
    property string outDir: Qt.application.arguments[Qt.application.arguments.length - 1]

    Backend {
        id: st
        apiBase: win.base + "/v1"
        tokenUrl: win.base + "/oauth/token"
        token: "access-2"
        selectedDeviceId: "ac-1"
        active: true
    }

    Item {
        id: stage
        anchors.fill: parent

        // Papel de parede liso: gradientes viram faixas na paleta de 128 cores do GIF.
        Rectangle {
            anchors.fill: parent
            color: "#4f6f78"
        }

        FullView {
            id: view
            x: (parent.width - width) / 2
            y: 22
            width: implicitWidth
            height: implicitHeight
            backend: st
        }

        // Painel do Plasma, com a visão compacta mostrando o valor atual.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 40
            color: "#202326"
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 18
                Repeater {
                    model: ["start-here-kde-symbolic", "system-file-manager-symbolic", "internet-web-browser-symbolic"]
                    Kirigami.Icon {
                        required property string modelData
                        width: 20
                        height: 20
                        source: modelData
                        color: "#fcfcfc"
                        isMask: true
                    }
                }
            }
            CompactView {
                anchors.right: clock.left
                anchors.rightMargin: 18
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

        Rectangle {
            id: cursor
            property bool pressed: false
            width: 22
            height: 22
            radius: 11
            x: view.x + 300 - width / 2
            y: view.y + 430 - height / 2
            color: pressed ? "#c8ffffff" : "#80ffffff"
            border.color: "#202020"
            border.width: 2
            scale: pressed ? 0.75 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
        }
    }

    // ---- Roteiro ----
    // Cada passo: [instante em ms, x, y no popup, ação opcional]. O cursor desliza entre os pontos.
    readonly property real sliderLeft: 62
    readonly property real sliderWidth: 256
    function sliderX(value, min, max) {
        return sliderLeft + (value - min) / (max - min) * sliderWidth
    }

    function press() { cursor.pressed = true }
    function release() { cursor.pressed = false }
    function click(action) {
        return () => {
            press()
            action()
            releaseTimer.restart()
        }
    }

    property var steps: {
        const s = []
        const ac = (v) => sliderX(v, 16, 30)
        const light = (v) => sliderX(v, 1, 100)
        const at = (t, x, y, action) => s.push({ t: t, x: x, y: y, action: action })
        const drag = (t0, from, to, toX, y, duration) => {
            at(t0, toX(from), y, press)
            const n = Math.abs(to - from)
            for (let i = 1; i <= n; i++) {
                const v = from + (to > from ? i : -i)
                at(t0 + duration * i / n, toX(v), y, () => st.setPrimary(v))
            }
            at(t0 + duration + 150, toX(to), y, release)
        }

        at(0, 300, 430)
        at(900, ac(23), 283)
        drag(1200, 23, 19, ac, 283, 1100)
        at(3200, 297, 228)
        at(3500, 297, 228, click(() => st.toggleQuickMode()))
        at(4500, 57, 370)
        at(4800, 57, 370, click(() => st.chooseTile(st.tiles[0], "dry")))
        at(5900, 345, 35)
        at(6200, 345, 35, click(() => st.togglePower()))
        at(7600, 345, 35, click(() => st.togglePower()))
        at(8700, 70, 33)
        at(9000, 70, 33, click(() => { st.refreshAll(); view.showingList = true }))
        at(10100, 330, 241)
        at(10400, 330, 241, click(() => st.setPower("plug-1", !st.deviceIsOn("plug-1"))))
        at(11500, 150, 137)
        at(11800, 150, 137, click(() => { st.selectDevice("light-1"); view.showingList = false }))
        at(13000, light(70), 283)
        drag(13300, 70, 25, light, 283, 1200)
        at(15400, 345, 35)
        at(15700, 345, 35, click(() => st.togglePower()))
        at(16900, 345, 35, click(() => st.togglePower()))
        at(18200, 300, 430)
        at(19000, 300, 430)
        return s
    }

    Timer {
        id: releaseTimer
        interval: 160
        onTriggered: win.release()
    }

    property int frame: 0
    property real startedAt: 0
    property int nextStep: 0
    readonly property int frameMs: 50

    function ease(p) {
        return p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2
    }

    function tick() {
        const t = Date.now() - startedAt
        while (nextStep < steps.length && steps[nextStep].t <= t) {
            if (steps[nextStep].action)
                steps[nextStep].action()
            nextStep++
        }
        if (nextStep >= steps.length) {
            ticker.stop()
            console.log("FRAMES", frame)
            Qt.quit()
            return
        }
        const prev = steps[Math.max(0, nextStep - 1)]
        const next = steps[nextStep]
        const p = next.t === prev.t ? 1 : Math.min(1, Math.max(0, (t - prev.t) / (next.t - prev.t)))
        cursor.x = view.x + prev.x + (next.x - prev.x) * ease(p) - cursor.width / 2
        cursor.y = view.y + prev.y + (next.y - prev.y) * ease(p) - cursor.height / 2

        const name = win.outDir + "/frame-" + String(frame).padStart(4, "0") + ".png"
        frame++
        stage.grabToImage(result => result.saveToFile(name))
    }

    Timer {
        id: ticker
        interval: win.frameMs
        repeat: true
        onTriggered: win.tick()
    }

    // Espera a lista de dispositivos e o status chegarem antes de começar.
    Timer {
        interval: 1500
        running: true
        onTriggered: {
            win.startedAt = Date.now()
            ticker.start()
        }
    }
}
