#!/bin/sh
# Cria o app OAuth do SmartThings na sua conta (só na primeira vez) e preenche o widget com as credenciais.
#
# Primeira vez: precisa do Node.js (npx). A CLI oficial abre o navegador para você entrar na conta Samsung.
# Outros PCs: copie ~/.config/smartthings-widget-oauth.json para o mesmo lugar e rode de novo; nada é recriado.
#
# Uso: tools/setup-app.sh [arquivo-de-credenciais]
set -eu

creds=${1:-${XDG_CONFIG_HOME:-$HOME/.config}/smartthings-widget-oauth.json}
redirect_uri=https://httpbin.org/get
plugin_id=io.github.gui.smartthings

command -v python3 >/dev/null || { echo "Precisa do python3." >&2; exit 1; }

if [ ! -s "$creds" ]; then
    if command -v smartthings >/dev/null; then
        cli=smartthings
    elif command -v npx >/dev/null; then
        # @latest evita que o npx reaproveite uma versão antiga em cache (a 1.x não funciona mais).
        cli="npx -y @smartthings/cli@latest"
    else
        echo "Instale o Node.js (para usar o npx) ou a CLI do SmartThings." >&2
        exit 1
    fi

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    suffix=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
    cat > "$tmp/app.json" <<EOF
{
  "appName": "kde-widget-$suffix",
  "displayName": "Widget SmartThings (KDE)",
  "description": "Controle dos dispositivos SmartThings pelo painel do KDE Plasma",
  "appType": "API_ONLY",
  "classifications": ["CONNECTED_SERVICE"],
  "singleInstance": true,
  "apiOnly": {},
  "oauth": {
    "clientName": "Widget SmartThings (KDE)",
    "scope": ["r:devices:*", "x:devices:*"],
    "redirectUris": ["$redirect_uri"]
  }
}
EOF
    echo "Criando o app OAuth. Se o navegador abrir, entre com a sua conta Samsung."
    mkdir -p "$(dirname "$creds")"
    (umask 077 && $cli apps:create -j -i "$tmp/app.json" -o "$creds")
    chmod 600 "$creds"
    echo "Credenciais salvas em $creds (o secret não aparece de novo: guarde este arquivo)."
fi

# Monta o script do Plasma que grava as credenciais em todas as instâncias do widget.
script=$(python3 -I - "$creds" "$redirect_uri" "$plugin_id" <<'EOF'
import json, sys
path, redirect_uri, plugin_id = sys.argv[1:]
data = json.load(open(path))
values = {
    "clientId": data.get("oauthClientId") or data["clientId"],
    "clientSecret": data.get("oauthClientSecret") or data["clientSecret"],
    "redirectUri": data.get("redirectUri") or redirect_uri,
}
print("""
var values = %s, count = 0;
var containments = panels().concat(desktops());
for (var i = 0; i < containments.length; i++) {
    var widgets = containments[i].widgets(%s);
    for (var j = 0; j < widgets.length; j++) {
        widgets[j].currentConfigGroup = ["General"];
        for (var key in values)
            widgets[j].writeConfig(key, values[key]);
        widgets[j].reloadConfig();
        count++;
    }
}
print(count);
""" % (json.dumps(values), json.dumps(plugin_id)))
EOF
)

qdbus=""
for candidate in qdbus6 qdbus-qt6 /usr/lib/qt6/bin/qdbus /usr/lib/x86_64-linux-gnu/qt6/bin/qdbus qdbus; do
    if command -v "$candidate" >/dev/null 2>&1; then
        qdbus=$candidate
        break
    fi
done

count=0
if [ -n "$qdbus" ]; then
    count=$("$qdbus" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" 2>/dev/null || echo 0)
fi

if [ "$count" -gt 0 ] 2>/dev/null; then
    echo "Widget configurado. Se ainda não estiver conectado, abra as configurações dele e clique em \"Entrar com a conta Samsung…\"."
else
    echo "Não encontrei o widget no Plasma. Adicione-o ao painel e rode este script de novo,"
    echo "ou copie o conteúdo de $creds e use \"Colar credenciais (JSON)\" nas configurações do widget."
fi
