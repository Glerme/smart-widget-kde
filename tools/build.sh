#!/bin/sh
# Gera dist/smartthings-<versão>.plasmoid, o arquivo que vai nas releases do GitHub e na KDE Store.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
version=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Version"])' "$root/package/metadata.json")
out=$root/dist/smartthings-$version.plasmoid

mkdir -p "$root/dist"
rm -f "$out"
# zipfile do Python em vez do zip, que nem toda distro instala.
python3 -I - "$root/package" "$out" <<'EOF'
import os, sys, zipfile
src, out = sys.argv[1:]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for folder, _, files in os.walk(src):
        for name in sorted(files):
            if not name.endswith((".qmlc", ".jsc")):
                path = os.path.join(folder, name)
                z.write(path, os.path.relpath(path, src))
EOF
echo "$out"
