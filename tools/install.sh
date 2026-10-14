#!/bin/sh
# Instala (ou atualiza) o widget para o usuário atual.
set -eu

package=$(dirname "$0")/../package
plugin_id=io.github.gui.smartthings

command -v kpackagetool6 >/dev/null || { echo "kpackagetool6 não encontrado: o widget precisa do KDE Plasma 6." >&2; exit 1; }

if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$plugin_id"; then
    kpackagetool6 -t Plasma/Applet -u "$package"
    echo "Atualizado. Para carregar a versão nova: systemctl --user restart plasma-plasmashell"
else
    kpackagetool6 -t Plasma/Applet -i "$package"
    echo "Instalado. Clique com o botão direito no painel > Adicionar widgets > SmartThings."
fi
