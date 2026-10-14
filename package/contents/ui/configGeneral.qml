import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "oauth.js" as OAuth

KCM.SimpleKCM {
    id: page

    property alias cfg_token: tokenField.text
    property alias cfg_clientId: clientIdField.text
    property alias cfg_clientSecret: clientSecretField.text
    property alias cfg_redirectUri: redirectField.text
    property alias cfg_pollSeconds: pollSpin.value
    property string cfg_refreshToken
    property string cfg_selectedDeviceId

    // Textos com quebra de linha alargam o FormLayout sem limite; isso o mantém no tamanho do diálogo.
    readonly property real formWidth: Kirigami.Units.gridUnit * 26
    property string tokenUrl: "https://api.smartthings.com/oauth/token"
    readonly property bool hasApp: clientIdField.text.trim() !== "" && clientSecretField.text.trim() !== ""
    readonly property bool loggedIn: cfg_refreshToken !== ""
    // Estado do login em andamento: "" | "waiting" | "exchanging" | "done"
    property string step: ""
    property string loginError: ""
    property string pendingState: ""

    function startLogin() {
        loginError = ""
        pendingState = OAuth.randomState()
        step = "waiting"
        callbackField.text = ""
        Qt.openUrlExternally(OAuth.loginUrl(clientIdField.text.trim(), redirectField.text.trim(), pendingState))
        callbackField.forceActiveFocus()
    }

    function finishLogin() {
        const parsed = OAuth.parseCallback(callbackField.text)
        if (parsed.code === "") {
            loginError = "Não encontrei o código. Cole a URL ou o texto da página que abriu depois do login."
            return
        }
        if (parsed.state !== "" && pendingState !== "" && parsed.state !== pendingState) {
            loginError = "Esse código é de outro login. Clique em entrar de novo."
            return
        }
        loginError = ""
        step = "exchanging"
        OAuth.requestToken(tokenUrl, clientIdField.text.trim(), clientSecretField.text.trim(), {
            grant_type: "authorization_code",
            code: parsed.code,
            redirect_uri: redirectField.text.trim()
        }, (failure, data) => {
            if (failure !== "") {
                step = "waiting"
                loginError = failure
                return
            }
            tokenField.text = data.access_token
            cfg_refreshToken = data.refresh_token || ""
            callbackField.text = ""
            step = "done"
        })
    }

    // QML não lê a área de transferência diretamente; um TextEdit invisível faz o paste().
    TextEdit {
        id: clipboardReader
        visible: false
    }

    function importCredentials() {
        clipboardReader.text = ""
        clipboardReader.paste()
        const creds = OAuth.parseCredentials(clipboardReader.text)
        clipboardReader.text = ""
        if (!creds) {
            loginError = "A área de transferência não tem um JSON com oauthClientId e oauthClientSecret."
            return
        }
        loginError = ""
        clientIdField.text = creds.clientId
        clientSecretField.text = creds.clientSecret
        if (creds.redirectUri !== "")
            redirectField.text = creds.redirectUri
    }

    function logout() {
        tokenField.text = ""
        cfg_refreshToken = ""
        step = ""
        loginError = ""
    }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Conta Samsung"
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.maximumWidth: page.formWidth
            visible: true
            type: page.loggedIn ? Kirigami.MessageType.Positive : Kirigami.MessageType.Information
            text: page.step === "done"
                ? "Conectado! Clique em Aplicar para salvar. O widget renova o acesso sozinho daqui em diante."
                : page.loggedIn
                    ? "Conectado. O acesso é renovado automaticamente."
                    : page.hasApp
                        ? "Clique em \"Entrar com a conta Samsung\" para conectar."
                        : "Preencha o Client ID e o secret do seu app SmartThings (veja como criar abaixo)."
            actions: page.loggedIn ? [logoutAction] : []

            Kirigami.Action {
                id: logoutAction
                icon.name: "system-log-out"
                text: "Desconectar"
                onTriggered: page.logout()
            }
        }

        QQC2.Button {
            icon.name: "internet-services"
            text: page.loggedIn ? "Entrar novamente…" : "Entrar com a conta Samsung…"
            enabled: page.hasApp && redirectField.text.trim() !== "" && page.step !== "exchanging"
            onClicked: page.startLogin()
        }

        ColumnLayout {
            Kirigami.FormData.label: "Código de retorno:"
            Layout.fillWidth: true
            Layout.maximumWidth: page.formWidth
            visible: page.step === "waiting" || page.step === "exchanging"

            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Depois de autorizar no navegador, você cai numa página com o código. Copie a URL dela (ou o texto todo) e cole aqui:"
            }
            RowLayout {
                Layout.fillWidth: true
                QQC2.TextField {
                    id: callbackField
                    Layout.fillWidth: true
                    placeholderText: "https://httpbin.org/get?code=…"
                    enabled: page.step !== "exchanging"
                    onAccepted: page.finishLogin()
                    // Colar a URL inteira já basta: não precisa clicar em Concluir.
                    onTextChanged: if (/[?&]code=|"code"\s*:/.test(text)) page.finishLogin()
                }
                QQC2.Button {
                    text: "Concluir"
                    icon.name: "dialog-ok"
                    enabled: callbackField.text.trim() !== "" && page.step !== "exchanging"
                    onClicked: page.finishLogin()
                }
                QQC2.BusyIndicator {
                    visible: page.step === "exchanging"
                    running: visible
                    Layout.preferredHeight: callbackField.implicitHeight
                    Layout.preferredWidth: Layout.preferredHeight
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.maximumWidth: page.formWidth
            visible: page.loginError !== ""
            type: Kirigami.MessageType.Error
            text: page.loginError
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "App SmartThings (feito uma vez)"
        }
        QQC2.TextField {
            id: clientIdField
            Kirigami.FormData.label: "Client ID:"
            Layout.fillWidth: true
            Layout.maximumWidth: page.formWidth
        }
        QQC2.TextField {
            id: clientSecretField
            Kirigami.FormData.label: "Client secret:"
            Layout.fillWidth: true
            Layout.maximumWidth: page.formWidth
            echoMode: TextInput.Password
        }
        QQC2.TextField {
            id: redirectField
            Kirigami.FormData.label: "Redirect URI:"
            Layout.fillWidth: true
            Layout.maximumWidth: page.formWidth
            placeholderText: OAuth.defaultRedirectUri
        }
        QQC2.Button {
            icon.name: "edit-paste"
            text: "Colar credenciais (JSON)"
            onClicked: page.importCredentials()
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: page.formWidth
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            textFormat: Text.StyledText
            text: "Ainda não tem um app? Rode <b>tools/setup-app.sh</b> do repositório: ele cria o app na sua conta "
                + "e preenche estes campos. Em outro PC, copie o arquivo <b>~/.config/smartthings-widget-oauth.json</b> "
                + "e use \"Colar credenciais\" (ou <b>tools/setup-app.sh</b> de novo, que reaproveita o arquivo)."
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Alternativa: token pessoal"
        }
        QQC2.TextField {
            id: tokenField
            Kirigami.FormData.label: "Token de acesso:"
            Layout.fillWidth: true
            Layout.maximumWidth: page.formWidth
            echoMode: TextInput.Password
            placeholderText: "Personal Access Token"
            enabled: !page.loggedIn
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: page.formWidth
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            text: page.loggedIn
                ? "Preenchido automaticamente pelo login."
                : "Tokens de account.smartthings.com/tokens expiram em 24 horas. Use o login acima para não precisar trocar."
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }
        QQC2.SpinBox {
            id: pollSpin
            Kirigami.FormData.label: "Atualizar a cada (s):"
            from: 5
            to: 600
        }
    }
}
