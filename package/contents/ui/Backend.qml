import QtQuick
import "oauth.js" as OAuth

// Estado e chamadas à API REST do SmartThings. Não depende do Plasma.
Item {
    id: backend

    property string apiBase: "https://api.smartthings.com/v1"
    property string tokenUrl: "https://api.smartthings.com/oauth/token"

    property string token
    property string clientId
    property string clientSecret
    property string refreshToken
    property string selectedDeviceId
    property int pollSeconds: 30
    // Popup aberto: atualiza na hora e mantém o polling.
    property bool active: false

    signal tokensRefreshed(string accessToken, string newRefreshToken)

    property var devices: []
    // deviceId -> status do componente "main"
    property var statuses: ({})
    property string error: ""
    property int pending: 0

    readonly property bool canRefresh: clientId !== "" && clientSecret !== "" && refreshToken !== ""
    readonly property bool configured: token !== "" || canRefresh
    readonly property bool syncing: pending > 0 || debounce.running
    readonly property var current: devices.find(d => d.id === selectedDeviceId) || null
    readonly property var status: (current && statuses[current.id]) || ({})

    readonly property string kind: {
        if (!current)
            return "none"
        if (hasCap("thermostatCoolingSetpoint"))
            return "ac"
        if (hasCap("switchLevel"))
            return "light"
        if (hasCap("audioVolume"))
            return "audio"
        return "generic"
    }
    readonly property bool hasPower: hasCap("switch")
    readonly property bool isOn: attr("switch", "switch") === "on"
    readonly property var roomTemperature: attr("temperatureMeasurement", "temperature")

    // Controle principal (slider): null quando o dispositivo não tem um.
    readonly property var primary: {
        if (kind === "ac") {
            const range = attr("thermostatCoolingSetpoint", "coolingSetpointRange") || {}
            return {
                value: Number(attr("thermostatCoolingSetpoint", "coolingSetpoint") ?? 24),
                min: Number(range.minimum ?? 16), max: Number(range.maximum ?? 30),
                unit: "°C", suffix: "°",
                capability: "thermostatCoolingSetpoint", attribute: "coolingSetpoint", command: "setCoolingSetpoint"
            }
        }
        if (kind === "light")
            return {
                value: Number(attr("switchLevel", "level") ?? 0), min: 1, max: 100, unit: "%", suffix: "%",
                capability: "switchLevel", attribute: "level", command: "setLevel"
            }
        if (kind === "audio")
            return {
                value: Number(attr("audioVolume", "volume") ?? 0), min: 0, max: 100, unit: "%", suffix: "%",
                capability: "audioVolume", attribute: "volume", command: "setVolume"
            }
        return null
    }

    readonly property var tileSpecs: [
        { key: "mode", title: "Modo", icon: "weather-snow-symbolic", capability: "airConditionerMode",
          attribute: "airConditionerMode", supported: "supportedAcModes", command: "setAirConditionerMode" },
        { key: "fan", title: "Ventilador", icon: "speedometer", capability: "airConditionerFanMode",
          attribute: "fanMode", supported: "supportedAcFanModes", command: "setFanMode" },
        { key: "optional", title: "Especial", icon: "weather-clear-night-symbolic", capability: "custom.airConditionerOptionalMode",
          attribute: "acOptionalMode", supported: "supportedAcOptionalMode", command: "setAcOptionalMode" },
        { key: "airflow", title: "Direção", icon: "adjustlevels", capability: "fanOscillationMode",
          attribute: "fanOscillationMode", supported: "supportedFanOscillationModes", command: "setFanOscillationMode" },
        { key: "colorTemp", title: "Cor", icon: "redshift-status-on", capability: "colorTemperature",
          attribute: "colorTemperature", command: "setColorTemperature", fixed: [2700, 4000, 6500] }
    ]
    readonly property var labels: ({
        cool: "Frio", heat: "Calor", dry: "Seco", wind: "Ventilar", fan: "Ventilar", auto: "Auto", aIComfort: "IA",
        low: "Baixa", medium: "Média", high: "Alta", turbo: "Turbo",
        off: "Desligado", sleep: "Dormir", quiet: "Silencioso", windFree: "WindFree",
        windFreeSleep: "WindFree noite", speed: "Rápido", eco: "Eco",
        fixed: "Fixo", vertical: "Vertical", horizontal: "Horizontal", all: "Todas",
        "2700": "Quente", "4000": "Neutra", "6500": "Fria"
    })

    // Dropdowns disponíveis para o dispositivo atual.
    readonly property var tiles: {
        const result = []
        for (const spec of tileSpecs) {
            if (!hasCap(spec.capability))
                continue
            const options = spec.fixed || attr(spec.capability, spec.supported) || []
            const value = attr(spec.capability, spec.attribute)
            if (options.length === 0 && value === undefined)
                continue
            result.push({
                spec: spec, title: spec.title, icon: spec.icon, value: value,
                valueLabel: spec.key === "colorTemp" ? (value ? value + " K" : "—") : label(value),
                options: options.map(o => ({ value: o, label: label(o) }))
            })
        }
        return result
    }

    // Atalho em forma de chave para um modo especial do ar-condicionado.
    readonly property var quickMode: {
        const supported = attr("custom.airConditionerOptionalMode", "supportedAcOptionalMode") || []
        const mode = ["eco", "windFree", "quiet", "sleep"].find(m => supported.includes(m))
        if (!mode)
            return null
        return { mode: mode, label: label(mode), on: attr("custom.airConditionerOptionalMode", "acOptionalMode") === mode }
    }

    function label(value) {
        if (value === undefined || value === null)
            return "—"
        return labels[String(value)] || String(value)
    }

    function hasCap(capability) {
        return !!current && current.caps.includes(capability)
    }

    function attr(capability, attribute) {
        const cap = status[capability]
        return cap && cap[attribute] ? cap[attribute].value ?? undefined : undefined
    }

    function deviceIsOn(deviceId) {
        const s = statuses[deviceId]
        return !!s && !!s.switch && s.switch.switch.value === "on"
    }

    // ---- HTTP ----

    property var refreshWaiters: null

    function request(method, url, body, onDone, isRetry) {
        if (token === "" && canRefresh && !isRetry) {
            refreshAccessToken(() => request(method, url, body, onDone, true))
            return
        }
        pending++
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            pending--
            if (xhr.status === 401 && !isRetry && canRefresh) {
                refreshAccessToken(() => request(method, url, body, onDone, true))
                return
            }
            if (xhr.status < 200 || xhr.status >= 300) {
                error = describeError(xhr.status)
                return
            }
            error = ""
            let data = {}
            try {
                data = JSON.parse(xhr.responseText)
            } catch (e) {
            }
            if (onDone)
                onDone(data)
        }
        xhr.open(method, url.startsWith("http") ? url : apiBase + url)
        xhr.setRequestHeader("Authorization", "Bearer " + token)
        xhr.setRequestHeader("Accept", "application/json")
        if (body) {
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.send(JSON.stringify(body))
        } else {
            xhr.send()
        }
    }

    function describeError(httpStatus) {
        if (httpStatus === 0)
            return "Sem conexão"
        if (httpStatus === 401)
            return "Token inválido ou expirado"
        if (httpStatus === 403)
            return "Token sem permissão"
        if (httpStatus === 429)
            return "Muitas requisições"
        return "Erro " + httpStatus
    }

    // O refresh token do SmartThings é trocado a cada uso, então só pode haver uma renovação por vez.
    function refreshAccessToken(onDone) {
        if (refreshWaiters) {
            refreshWaiters.push(onDone)
            return
        }
        refreshWaiters = [onDone]
        pending++
        OAuth.requestToken(tokenUrl, clientId, clientSecret,
                           { grant_type: "refresh_token", refresh_token: refreshToken }, (failure, data) => {
            pending--
            const waiters = refreshWaiters
            refreshWaiters = null
            if (failure !== "") {
                error = failure
                return
            }
            // Quem instancia o Backend grava os novos tokens (as propriedades ficam ligadas à configuração).
            tokensRefreshed(data.access_token, data.refresh_token || refreshToken)
            waiters.forEach(w => w())
        })
    }

    // O access token dura 24 h e o refresh token morre após 29 dias sem uso: renovar antes evita os dois.
    Timer {
        interval: 12 * 60 * 60 * 1000
        running: backend.canRefresh
        repeat: true
        onTriggered: backend.refreshAccessToken(() => {})
    }

    // ---- Leitura ----

    // Evita requisições disparadas por mudanças de propriedade enquanto o componente ainda é montado.
    property bool ready: false

    function loadDevices() {
        if (!configured || !ready)
            return
        const collected = []
        const fetchPage = url => request("GET", url, null, data => {
            for (const d of data.items || []) {
                const components = d.components || []
                const main = components.find(c => c.id === "main") || components[0] || {}
                collected.push({
                    id: d.deviceId,
                    label: d.label || d.name || "Dispositivo",
                    caps: (main.capabilities || []).map(c => c.id)
                })
            }
            const next = data._links && data._links.next && data._links.next.href
            if (next) {
                fetchPage(next)
                return
            }
            collected.sort((a, b) => a.label.localeCompare(b.label))
            devices = collected
            if (!current && collected.length > 0)
                selectedDeviceId = (collected.find(d => d.caps.includes("switch")) || collected[0]).id
            refreshCurrent()
        })
        fetchPage("/devices")
    }

    // Após um comando, a nuvem ainda devolve o estado antigo por alguns segundos.
    property var holdUntil: ({})

    function refreshDevice(deviceId) {
        request("GET", "/devices/" + deviceId + "/components/main/status", null, data => {
            if ((holdUntil[deviceId] || 0) > Date.now())
                return
            const copy = Object.assign({}, statuses)
            copy[deviceId] = data
            statuses = copy
        })
    }

    function refreshCurrent() {
        if (current)
            refreshDevice(current.id)
    }

    function refreshAll() {
        devices.forEach(d => refreshDevice(d.id))
    }

    // ---- Escrita ----

    function setLocal(deviceId, capability, attribute, value) {
        const copy = Object.assign({}, statuses)
        const deviceStatus = Object.assign({}, copy[deviceId])
        const cap = Object.assign({}, deviceStatus[capability])
        cap[attribute] = Object.assign({}, cap[attribute], { value: value })
        deviceStatus[capability] = cap
        copy[deviceId] = deviceStatus
        statuses = copy
        holdUntil[deviceId] = Date.now() + 4000
        settle.restart()
    }

    function command(deviceId, capability, name, args) {
        request("POST", "/devices/" + deviceId + "/commands", {
            commands: [{ component: "main", capability: capability, command: name, arguments: args || [] }]
        }, () => settle.restart())
    }

    function setPower(deviceId, on) {
        setLocal(deviceId, "switch", "switch", on ? "on" : "off")
        command(deviceId, "switch", on ? "on" : "off")
    }

    function togglePower() {
        if (current && hasPower)
            setPower(current.id, !isOn)
    }

    function setPrimary(value) {
        if (!primary)
            return
        const clamped = Math.max(primary.min, Math.min(primary.max, Math.round(value)))
        if (clamped === primary.value)
            return
        setLocal(current.id, primary.capability, primary.attribute, clamped)
        debounce.target = { deviceId: current.id, capability: primary.capability, command: primary.command, value: clamped }
        debounce.restart()
    }

    function chooseTile(tile, value) {
        setLocal(current.id, tile.spec.capability, tile.spec.attribute, value)
        command(current.id, tile.spec.capability, tile.spec.command, [value])
    }

    function toggleQuickMode() {
        if (!quickMode)
            return
        const value = quickMode.on ? "off" : quickMode.mode
        setLocal(current.id, "custom.airConditionerOptionalMode", "acOptionalMode", value)
        command(current.id, "custom.airConditionerOptionalMode", "setAcOptionalMode", [value])
    }

    function selectDevice(deviceId) {
        debounce.flush()
        selectedDeviceId = deviceId
        refreshCurrent()
    }

    // Junta os passos do slider em um único comando.
    Timer {
        id: debounce
        property var target: null
        interval: 600
        onTriggered: flush()
        function flush() {
            stop()
            if (!target)
                return
            backend.command(target.deviceId, target.capability, target.command, [target.value])
            target = null
        }
    }

    Timer {
        id: settle
        interval: 4200
        onTriggered: backend.refreshCurrent()
    }

    Timer {
        interval: backend.pollSeconds * 1000
        running: backend.configured
        repeat: true
        onTriggered: backend.devices.length > 0 ? backend.refreshCurrent() : backend.loadDevices()
    }

    onActiveChanged: {
        if (!active)
            return
        if (devices.length > 0)
            refreshCurrent()
        else
            loadDevices()
    }
    onConfiguredChanged: loadDevices()
    Component.onCompleted: {
        ready = true
        loadDevices()
    }
}
