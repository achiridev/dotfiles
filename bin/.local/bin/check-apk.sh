#!/usr/bin/env bash
set -euo pipefail
APK="$1"

echo "=== [1] Firma del certificado ==="
apksigner verify --print-certs "$APK" | grep -E "DN:|SHA-256"

echo ""
echo "=== [2] Escaneo ClamAV ==="
clamscan --heuristic-alerts=yes "$APK"

echo ""
echo "=== [3] Descompilando con apktool... ==="
OUTDIR="${APK%.apk}_decomp"
apktool d "$APK" -o "$OUTDIR" -f -q

echo ""
echo "=== [4] Permisos declarados ==="
grep "uses-permission" "$OUTDIR/AndroidManifest.xml"

echo ""
echo "=== [5] URLs encontradas en smali ==="
grep -r "https\?://" "$OUTDIR/smali/" | grep -v "schemas.android" | \
  sed 's/.*\(https\?:\/\/[^"]*\).*/\1/' | sort -u | head -30

echo ""
echo "=== [6] Trackers detectados ==="
grep -r "appsflyer\|adjust\|branch\.io\|mopub\|chartboost\|\
flurry\|inmobi\|startapp" "$OUTDIR/smali/" -l 2>/dev/null || echo "Ninguno detectado"

echo ""
echo "Listo. Revisa manualmente con: jadx-gui $APK"

# Se ejecuta con:  
# ~/.local/bin/check-apk.sh app.apk