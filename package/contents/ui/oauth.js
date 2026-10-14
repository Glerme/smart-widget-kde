.pragma library

// Fluxo OAuth (authorization code) do SmartThings, usado pela tela de login e pela renovação do Backend.

var authorizeUrl = "https://api.smartthings.com/oauth/authorize"
var scopes = "r:devices:* x:devices:*"
// A SmartThings recusa redirecionar para localhost; o httpbin só mostra o código na página.
var defaultRedirectUri = "https://httpbin.org/get"

function loginUrl(clientId, redirectUri, state) {
    return authorizeUrl
        + "?client_id=" + encodeURIComponent(clientId)
        + "&response_type=code"
        + "&scope=" + encodeURIComponent(scopes)
        + "&redirect_uri=" + encodeURIComponent(redirectUri)
        + "&state=" + encodeURIComponent(state)
}

function randomState() {
    var s = ""
    for (var i = 0; i < 16; i++)
        s += Math.floor(Math.random() * 16).toString(16)
    return s
}

// Aceita o código puro, a URL de retorno ou o JSON que o httpbin mostra.
// Devolve { code, state } (state vazio quando não veio junto).
function parseCallback(text) {
    text = String(text || "").trim()
    var find = function (name) {
        var m = text.match(new RegExp("[?&#]" + name + "=([^&#\\s\"]+)"))
            || text.match(new RegExp("\"" + name + "\"\\s*:\\s*\"([^\"]+)\""))
        return m ? decodeURIComponent(m[1]) : ""
    }
    var code = find("code")
    if (code === "" && /^[A-Za-z0-9_-]+$/.test(text))
        code = text
    return { code: code, state: find("state") }
}

// POST no endpoint de token; onDone(erro, dados) com erro vazio em caso de sucesso.
function requestToken(tokenUrl, clientId, clientSecret, params, onDone) {
    var body = "client_id=" + encodeURIComponent(clientId)
    for (var key in params)
        body += "&" + key + "=" + encodeURIComponent(params[key])

    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return
        var data = null
        try {
            data = JSON.parse(xhr.responseText)
        } catch (e) {
        }
        if (xhr.status === 200 && data && data.access_token)
            onDone("", data)
        else
            onDone(describeTokenError(xhr.status, data), data)
    }
    xhr.open("POST", tokenUrl)
    xhr.setRequestHeader("Authorization", "Basic " + base64(clientId + ":" + clientSecret))
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
    xhr.setRequestHeader("Accept", "application/json")
    xhr.send(body)
}

// Lê o JSON que a CLI (apps:create -j) ou tools/setup-app.sh gera. Devolve null se não achar as credenciais.
function parseCredentials(text) {
    var data = null
    try {
        data = JSON.parse(String(text || "").trim())
    } catch (e) {
        return null
    }
    var id = data && (data.oauthClientId || data.clientId)
    var secret = data && (data.oauthClientSecret || data.clientSecret)
    if (!id || !secret)
        return null
    return { clientId: id, clientSecret: secret, redirectUri: data.redirectUri || "" }
}

// Qt.btoa(string) está obsoleto; as credenciais são ASCII, então basta um codificador simples.
function base64(text) {
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    var out = ""
    for (var i = 0; i < text.length; i += 3) {
        var a = text.charCodeAt(i), b = text.charCodeAt(i + 1), c = text.charCodeAt(i + 2)
        var n = (a << 16) | ((b || 0) << 8) | (c || 0)
        out += chars[(n >> 18) & 63] + chars[(n >> 12) & 63]
            + (i + 1 < text.length ? chars[(n >> 6) & 63] : "=")
            + (i + 2 < text.length ? chars[n & 63] : "=")
    }
    return out
}

function describeTokenError(status, data) {
    if (status === 0)
        return "Sem conexão"
    var code = data && data.error
    if (code === "invalid_grant")
        return "Login expirado, entre de novo com a conta Samsung"
    if (code === "invalid_client" || status === 401)
        return "Client ID ou secret incorretos"
    return "Falha no login (" + (code || status) + ")"
}
