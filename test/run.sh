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

    # GIF animado: servidor novo, para a demonstração começar do estado inicial dos dispositivos.
    if command -v ffmpeg >/dev/null; then
        python3 "$root/test/mock_server.py" $((port + 1)) >/dev/null &
        demo_server=$!
        sleep 0.5
        rm -rf "$out/frames" && mkdir -p "$out/frames"
        "$qml" "$root/test/demo.qml" -- "http://127.0.0.1:$((port + 1))" "$out/frames"
        kill $demo_server
        ffmpeg -loglevel error -y -framerate 20 -i "$out/frames/frame-%04d.png" -vf \
            "scale=560:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
            "$root/docs/demo.gif"
    else
        echo "ffmpeg não encontrado: docs/demo.gif não foi atualizado." >&2
    fi
    echo "Capturas copiadas para $docs"
fi
