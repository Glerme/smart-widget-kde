import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    Plasmoid.icon: "go-home-symbolic"
    toolTipMainText: st.current ? st.current.label : "SmartThings"
    toolTipSubText: {
        if (!st.configured)
            return "Conta não conectada"
        if (st.error !== "")
            return st.error
        if (!st.current)
            return ""
        const state = st.hasPower ? (st.isOn ? "Ligado" : "Desligado") : ""
        return st.primary ? (state + " · " + st.primary.value + st.primary.unit) : state
    }

    Backend {
        id: st
        token: Plasmoid.configuration.token
        clientId: Plasmoid.configuration.clientId
        clientSecret: Plasmoid.configuration.clientSecret
        refreshToken: Plasmoid.configuration.refreshToken
        pollSeconds: Plasmoid.configuration.pollSeconds
        active: popup.visible
        onTokensRefreshed: (accessToken, newRefreshToken) => {
            Plasmoid.configuration.token = accessToken
            Plasmoid.configuration.refreshToken = newRefreshToken
        }
        onSelectedDeviceIdChanged: Plasmoid.configuration.selectedDeviceId = selectedDeviceId
        Component.onCompleted: selectedDeviceId = Plasmoid.configuration.selectedDeviceId
    }

    // O popup padrão do Plasma sempre desenha a moldura do tema; um Dialog próprio permite tirá-la.
    preferredRepresentation: fullRepresentation
    compactRepresentation: null
    fullRepresentation: CompactView {
        backend: st
        onToggleExpanded: popup.visible = !popup.visible
    }

    Plasmoid.onActivated: popup.visible = !popup.visible

    PlasmaCore.Dialog {
        id: popup
        visualParent: root
        location: Plasmoid.location
        hideOnWindowDeactivate: true
        flags: Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        onVisibleChanged: if (visible) requestActivate()

        mainItem: FullView {
            width: implicitWidth
            height: implicitHeight
            backend: st
            onConfigureRequested: {
                popup.visible = false
                Plasmoid.internalAction("configure").trigger()
            }
        }
    }
}
