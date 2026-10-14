#!/bin/sh
# Roda os harnesses contra o servidor falso e salva as capturas em OUT_DIR (padrão: test/out).
# Com --docs, copia as capturas usadas no README para docs/screenshots.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out=${OUT_DIR:-$root/test/out}
port=${PORT:-8765}

# Em várias distros /usr/bin/qml é o runtime do Qt 5; o widget precisa do Qt 6.
qml=""
for candidate in /usr/lib/qt6/bin/qml /usr/lib64/qt6/bin/qml /usr/lib/x86_64-linux-gnu/qt6/bin/qml qml6 qml; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" --version 2>/dev/null | grep -q " 6\."; then
        qml=$candidate
        break
    fi
done
[ -n "$qml" ] || { echo "Runtime qml do Qt 6 não encontrado." >&2; exit 1; }

mkdir -p "$out"
python3 "$root/test/mock_server.py" "$port" &
server=$!
trap 'kill $server 2>/dev/null' EXIT
sleep 0.5

# offscreen: não abre janelas; tema kde: carrega os ícones do Breeze; stderr: o console.log não vai pro journald.
export QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=kde QT_FORCE_STDERR_LOGGING=1
# Capturas em 2x ficam nítidas em telas HiDPI e no GitHub.
export QT_SCALE_FACTOR=${QT_SCALE_FACTOR:-2}
"$qml" "$root/test/harness.qml" -- "http://127.0.0.1:$port" "$out"
"$qml" "$root/test/config-harness.qml" -- "$out"

if [ "${1:-}" = "--docs" ]; then
    docs=$root/docs/screenshots
    mkdir -p "$docs"
    cp "$out/0-panel.png" "$docs/panel.png"
    cp "$out/1-ac.png" "$docs/ac.png"
    cp "$out/4-light.png" "$docs/light.png"
    cp "$out/5-list.png" "$docs/devices.png"
    cp "$out/settings-login.png" "$out/settings-connected.png" "$docs/"
    echo "Capturas copiadas para $docs"
fi
