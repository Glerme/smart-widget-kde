import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

MouseArea {
    id: compact

    required property Backend backend
    signal toggleExpanded()

    readonly property string valueText: {
        if (backend.primary && (!backend.hasPower || backend.isOn))
            return backend.primary.value + backend.primary.suffix
        return ""
    }

    Layout.minimumWidth: row.implicitWidth
    Layout.preferredWidth: row.implicitWidth
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton)
            backend.togglePower()
        else
            toggleExpanded()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        height: parent.height
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Math.min(compact.height, Kirigami.Units.iconSizes.smallMedium)
            Layout.preferredHeight: Layout.preferredWidth
            source: compact.backend.kind === "audio" ? "audio-volume-high-symbolic"
                  : compact.backend.kind === "ac" ? "weather-snow-symbolic" : "go-home-symbolic"
            opacity: !compact.backend.hasPower || compact.backend.isOn ? 1 : 0.5
        }
        PlasmaComponents.Label {
            visible: text !== ""
            text: compact.valueText
        }
    }
}
