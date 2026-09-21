#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-"$ROOT/../baidu-release"}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
python3 - "$ROOT" "$OUT/site.tar.gz" <<'PY'
import pathlib, sys, tarfile
root, output = map(pathlib.Path, sys.argv[1:])
allowed = {'.html','.css','.js','.json','.xml','.txt','.png','.svg','.ico','.webp'}
files = [p for p in root.iterdir() if p.is_file() and p.suffix in allowed]
files += [p for p in (root/'img').rglob('*') if p.is_file() and not any(x.startswith('.') for x in p.relative_to(root).parts)]
assert root/'index.html' in files
with tarfile.open(output, 'w:gz') as archive:
    for p in sorted(files):
        if p.is_symlink(): raise SystemExit(f'Refusing symbolic link: {p}')
        archive.add(p, arcname=str(p.relative_to(root)), recursive=False)
print(f'Packaged {len(files)} files')
PY
cp "$ROOT/deploy/install-baidu.sh" "$ROOT/deploy/BAIDU.md" "$OUT/"
(cd "$OUT" && shasum -a 256 site.tar.gz > site.tar.gz.sha256)
printf '完成：%s\n上传此目录文件到服务器，然后 sudo bash install-baidu.sh\n' "$OUT"
