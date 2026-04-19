#!/bin/bash

set -e

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

BRAND_NAME="${BRAND_NAME:-Jhonaley Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@danangvalentp}"
BOT_LINK="${BOT_LINK:-@upgradeuser_bot}"
WELCOME_TITLE="${WELCOME_TITLE:-Welcome To Server $BRAND_NAME}"
WELCOME_MESSAGE="${WELCOME_MESSAGE:-Butuh panel legal yang anti mokad? langsung aja ke $BOT_LINK. Jika ada kendala dan ada yang ingin di tanyakan hubungi $CONTACT_TELEGRAM.}"

TELEGRAM_USERNAME="${CONTACT_TELEGRAM#@}"
BOT_USERNAME="${BOT_LINK#@}"

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g"
}

js_escape() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e "s/'/\\\\'/g"
}

sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'
}

BRAND_NAME_HTML=$(html_escape "$BRAND_NAME")
BRAND_TEXT_HTML=$(html_escape "$BRAND_TEXT")
CONTACT_TELEGRAM_HTML=$(html_escape "$CONTACT_TELEGRAM")
BOT_LINK_HTML=$(html_escape "$BOT_LINK")
BRAND_NAME_JS=$(js_escape "$BRAND_NAME")
CONTACT_TELEGRAM_JS=$(js_escape "$CONTACT_TELEGRAM")
WELCOME_TITLE_JS=$(js_escape "$WELCOME_TITLE")
WELCOME_MESSAGE_JS=$(js_escape "$WELCOME_MESSAGE")
SAFE_TITLE=$(sed_escape "$BRAND_NAME")

can_modify_file() {
  local file="$1"
  if [ -f "$file" ] && [ -w "$file" ]; then
    return 0
  fi

  local dir
  dir=$(dirname "$file")
  [ -w "$dir" ]
}

write_temp_to_target() {
  local temp_file="$1"
  local target_file="$2"
  local label="$3"

  if [ -f "$target_file" ]; then
    chmod u+w "$target_file" 2>/dev/null || true
    chown --reference="$target_file" "$temp_file" 2>/dev/null || true
    chmod --reference="$target_file" "$temp_file" 2>/dev/null || true
  fi

  if cat "$temp_file" > "$target_file" 2>/dev/null; then
    return 0
  fi

  if cp "$temp_file" "$target_file" 2>/dev/null; then
    return 0
  fi

  echo "⚠️ Tidak bisa menulis ke $label, skip. Cek permission file/folder target."
  return 1
}

remove_block_by_markers() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip cleanup branding di $file karena tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)
  awk -v start="$start_marker" -v end="$end_marker" '
    index($0, start) { skip=1; next }
    skip && index($0, end) { skip=0; next }
    !skip { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

cleanup_old_branding() {
  local file="$1"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip branding cleanup di $file karena tidak writable"
    return 0
  fi

  remove_block_by_markers "$file" "<!-- BRANDING_JHONALEY_START -->" "<!-- BRANDING_JHONALEY_END -->"
  remove_block_by_markers "$file" "<!-- BRANDING_JHONALEY: Custom Branding -->" "</style>"

  tmp_file=$(mktemp)
  awk '
    BEGIN { skip=0; depth=0; seen_div=0 }
    /<!-- BRANDING_JHONALEY: Footer -->/ { skip=1; depth=0; seen_div=0; next }
    skip {
      line=$0
      opens=gsub(/<div[^>]*>/, "&", line)
      closes=gsub(/<\/div>/, "&", line)
      if (opens > 0) {
        depth += opens
        seen_div = 1
      }
      if (closes > 0) {
        depth -= closes
      }
      if (seen_div && depth <= 0) {
        skip=0
      }
      next
    }
    { print }
  ' "$file" > "$tmp_file"

  write_temp_to_target "$tmp_file" "$file" "$file" || true
  rm -f "$tmp_file"
}

inject_before_closing() {
  local file="$1"
  local snippet_file="$2"
  local label="$3"
  local tmp_file

  if ! can_modify_file "$file"; then
    echo "⚠️ Skip inject ke $label karena file tidak writable"
    return 0
  fi

  tmp_file=$(mktemp)

  if grep -q "</body>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/body>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </body> di $label"
  elif grep -q "</html>" "$file"; then
    awk -v snippet="$snippet_file" '
      /<\/html>/ { while ((getline line < snippet) > 0) print line; close(snippet) }
      { print }
    ' "$file" > "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten diinjeksi sebelum </html> di $label"
  else
    cat "$snippet_file" > "$tmp_file"
    cat "$file" >> "$tmp_file"
    write_temp_to_target "$tmp_file" "$file" "$label" || true
    echo "✅ Konten ditambahkan di akhir $label"
  fi

  rm -f "$tmp_file"
}

echo "==========================================="
echo "🔒 INSTALLPROTECT5: Proteksi Nests + Branding + Welcome Banner"
echo "==========================================="
echo ""
echo "📦 Bagian 1: Proteksi Nests (Sembunyikan + Block Akses)"
echo "📦 Bagian 2: Branding Footer $BRAND_NAME"
echo "📦 Bagian 3: Welcome Banner Client Dashboard"
echo ""
echo "🚀 Memasang proteksi Nests (Sembunyikan + Block Akses)..."
echo ""

# === LANGKAH 1: Restore NestController dari backup asli ===
CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
LATEST_BACKUP=$(ls -t "${CONTROLLER}.bak_"* 2>/dev/null | tail -1)

if [ -n "$LATEST_BACKUP" ]; then
  cp "$LATEST_BACKUP" "$CONTROLLER"
  echo "📦 Controller di-restore dari backup paling awal: $LATEST_BACKUP"
else
  echo "⚠️ Tidak ada backup, menggunakan file saat ini"
fi

cp "$CONTROLLER" "${CONTROLLER}.bak_${TIMESTAMP}"

# === LANGKAH 2: Inject proteksi ke NestController ===
python3 << 'PYEOF'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Proteksi sudah ada di NestController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)

    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])

        new_lines.append("        // PROTEKSI_JHONALEY: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
        new_lines.append("        }")

        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke NestController")
PYEOF

echo ""
echo "📋 Verifikasi NestController (cari PROTEKSI):"
grep -n "PROTEKSI_JHONALEY" "$CONTROLLER"
echo ""

# === LANGKAH 3: Proteksi juga EggController (halaman egg di dalam nest) ===
EGG_CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/EggController.php"
if [ -f "$EGG_CONTROLLER" ]; then
  if ! grep -q "PROTEKSI_JHONALEY" "$EGG_CONTROLLER"; then
    cp "$EGG_CONTROLLER" "${EGG_CONTROLLER}.bak_${TIMESTAMP}"

    python3 << 'PYEOF2'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/EggController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Sudah ada proteksi di EggController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)

    if re.search(r'public function (?!__construct)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])

        new_lines.append("        // PROTEKSI_JHONALEY: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
        new_lines.append("        }")

        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ EggController juga diproteksi")
PYEOF2
  else
    echo "⚠️ EggController sudah diproteksi"
  fi
fi

# === LANGKAH 4: Sembunyikan menu Nests di sidebar ===
echo "🔧 Menyembunyikan menu Nests dari sidebar..."

SIDEBAR_FILES=(
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"
)

SIDEBAR_FOUND=""
for SF in "${SIDEBAR_FILES[@]}"; do
  if [ -f "$SF" ] && grep -q "admin.nests" "$SF" 2>/dev/null; then
    SIDEBAR_FOUND="$SF"
    break
  fi
done

if [ -z "$SIDEBAR_FOUND" ]; then
  SIDEBAR_FOUND=$(grep -rl "admin.nests" /var/www/pterodactyl/resources/views/partials/ 2>/dev/null | head -1)
  if [ -z "$SIDEBAR_FOUND" ]; then
    SIDEBAR_FOUND=$(grep -rl "admin.nests" /var/www/pterodactyl/resources/views/layouts/ 2>/dev/null | head -1)
  fi
fi

if [ -n "$SIDEBAR_FOUND" ]; then
  echo "📂 Sidebar ditemukan: $SIDEBAR_FOUND"

  echo "📋 Baris terkait Nests di sidebar:"
  grep -n -i "nest" "$SIDEBAR_FOUND" | head -10
  echo ""

  if ! can_modify_file "$SIDEBAR_FOUND"; then
    echo "⚠️ Sidebar tidak writable, skip sembunyikan menu Nests."
  else
    cp "$SIDEBAR_FOUND" "${SIDEBAR_FOUND}.bak_${TIMESTAMP}" 2>/dev/null || true

    SIDEBAR_TEMP=$(mktemp)
    export SIDEBAR_FOUND SIDEBAR_TEMP
    python3 << 'PYEOF3'
import os

sidebar = os.environ["SIDEBAR_FOUND"]
sidebar_temp = os.environ["SIDEBAR_TEMP"]

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_NESTS_SIDEBAR" in content:
    print("⚠️ Sidebar Nests sudah diproteksi")
    raise SystemExit(0)

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]

    if ('admin.nests' in line or "route('admin.nests')" in line) and 'admin.nests.view' not in line and 'admin.nests.egg' not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1

        if li_start >= 0:
            new_lines.insert(li_start, "{{-- PROTEKSI_NESTS_SIDEBAR --}}")
            new_lines.insert(li_start, "@if((int) Auth::user()->id === 1)")

            new_lines.append(line)
            i += 1

            li_depth = 1
            while i < len(lines) and li_depth > 0:
                curr = lines[i]
                li_depth += curr.count('<li') - curr.count('</li')
                new_lines.append(curr)
                i += 1

            new_lines.append("@endif")
            continue

    new_lines.append(line)
    i += 1

with open(sidebar_temp, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Temp sidebar berhasil dibuat")
PYEOF3

    if write_temp_to_target "$SIDEBAR_TEMP" "$SIDEBAR_FOUND" "$SIDEBAR_FOUND"; then
      echo "✅ Menu Nests disembunyikan dari sidebar"
    else
      echo "⚠️ Gagal menulis perubahan sidebar, skip langkah sembunyikan menu."
    fi

    rm -f "$SIDEBAR_TEMP"
  fi
else
  echo "⚠️ File sidebar tidak ditemukan."
fi

# === LANGKAH 5: Cache clear di-handle oleh controller ===
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller setelah install selesai"

echo ""
echo "==========================================="
echo "✅ Proteksi Nests LENGKAP selesai!"
echo "==========================================="
echo "🔒 Menu Nests disembunyikan dari sidebar (selain ID 1)"
echo "🔒 Akses /admin/nests diblock (selain ID 1)"
echo "🔒 Akses /admin/nests/view/* diblock (selain ID 1)"
echo "🔒 EggController juga diproteksi"
echo "🚀 Panel tetap normal, server tetap jalan"
echo "==========================================="
echo ""
echo "⚠️ Jika ada masalah, restore:"
echo "   cp ${CONTROLLER}.bak_${TIMESTAMP} $CONTROLLER"
if [ -n "$SIDEBAR_FOUND" ]; then
  echo "   cp ${SIDEBAR_FOUND}.bak_${TIMESTAMP} $SIDEBAR_FOUND"
fi
echo "   cd /var/www/pterodactyl && php artisan view:clear && php artisan route:clear"

# ============================================================
# === BRANDING: Inject footer brand ke layout panel ===
# ============================================================
echo ""
echo "🎨 Memasang branding $BRAND_NAME..."

LAYOUT_FILES=(
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"
)

# Cleanup branding lama dari master.blade.php dan auth.blade.php jika ada
for CLEANUP_FILE in "/var/www/pterodactyl/resources/views/layouts/master.blade.php" "/var/www/pterodactyl/resources/views/layouts/auth.blade.php"; do
  if [ -f "$CLEANUP_FILE" ] && grep -q "BRANDING_JHONALEY" "$CLEANUP_FILE" 2>/dev/null; then
    cleanup_old_branding "$CLEANUP_FILE"
    echo "🧹 Branding lama dihapus dari $(basename "$CLEANUP_FILE")"
  fi
done

BRANDING_FOUND=0

inject_branding() {
  local FILE="$1"
  local LABEL="$2"

  if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "⚠️ File $LABEL tidak ditemukan: $FILE"
    return
  fi

  BRANDING_FOUND=1

  if ! can_modify_file "$FILE"; then
    echo "⚠️ File $LABEL tidak writable, skip branding di file ini"
    return
  fi

  if [ ! -f "${FILE}.bak_${TIMESTAMP}" ]; then
    cp "$FILE" "${FILE}.bak_${TIMESTAMP}" 2>/dev/null || true
  fi

  cleanup_old_branding "$FILE"

  BRANDING_TMP="/tmp/branding_inject_${TIMESTAMP}_$(basename "$FILE").html"
  cat > "$BRANDING_TMP" << BRANDHTML
<!-- BRANDING_JHONALEY_START -->
<style>
  .jhonaley-footer {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    z-index: 9999;
    background: linear-gradient(135deg, #0c1929, #132f4c, #0a2744);
    padding: 10px 20px;
    text-align: center;
    border-top: 2px solid rgba(59, 130, 246, 0.35);
    box-shadow: 0 -4px 20px rgba(59, 130, 246, 0.12);
    font-family: 'Segoe UI', system-ui, sans-serif;
  }
  .jhonaley-footer .jt-inner {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    flex-wrap: wrap;
  }
  .jhonaley-footer .jt-badge {
    background: linear-gradient(135deg, #0f3e68, #1d74b7);
    color: #e0f2fe;
    padding: 4px 12px;
    border-radius: 20px;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 1px;
    text-transform: uppercase;
    box-shadow: 0 2px 10px rgba(29, 116, 183, 0.35);
  }
  .jhonaley-footer .jt-text {
    color: #cfe7ff;
    font-size: 13px;
    font-weight: 500;
  }
  .jhonaley-footer .jt-text a {
    color: #7dd3fc;
    text-decoration: none;
    font-weight: 700;
    transition: all 0.3s ease;
  }
  .jhonaley-footer .jt-text a:hover {
    color: #bae6fd;
  }
  .jhonaley-footer .jt-separator {
    color: #2f6fa3;
    font-size: 10px;
  }
  .jhonaley-footer .jt-tg {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    background: rgba(56, 189, 248, 0.12);
    border: 1px solid rgba(56, 189, 248, 0.28);
    padding: 3px 10px;
    border-radius: 15px;
    color: #bae6fd;
    font-size: 12px;
    text-decoration: none;
    transition: all 0.3s ease;
  }
  .jhonaley-footer .jt-tg:hover {
    background: rgba(56, 189, 248, 0.22);
    border-color: rgba(125, 211, 252, 0.55);
    color: #e0f2fe;
    transform: translateY(-1px);
  }
  .jhonaley-footer .jt-tg svg {
    width: 14px;
    height: 14px;
    fill: currentColor;
  }
  .jhonaley-footer .jt-promo {
    color: #dbeafe;
    font-size: 12px;
    font-weight: 600;
  }
  .jhonaley-footer .jt-promo a {
    color: #7dd3fc;
    text-decoration: none;
    font-weight: 700;
  }
  .jhonaley-footer .jt-promo a:hover {
    color: #e0f2fe;
  }
  body {
    padding-bottom: 50px !important;
  }
</style>
<div class="jhonaley-footer">
  <div class="jt-inner">
    <span class="jt-badge">$BRAND_TEXT_HTML</span>
    <span class="jt-text">Panel by <a href="https://t.me/$TELEGRAM_USERNAME" target="_blank">$BRAND_NAME_HTML</a></span>
    <span class="jt-separator">●</span>
    <a class="jt-tg" href="https://t.me/$TELEGRAM_USERNAME" target="_blank">
      <svg viewBox="0 0 24 24"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>
      $CONTACT_TELEGRAM_HTML
    </a>
    <span class="jt-separator">●</span>
    <span class="jt-promo">Butuh panel yang anti mokad? Langsung aja ke <a href="https://t.me/$BOT_USERNAME" target="_blank">$BOT_LINK_HTML</a></span>
  </div>
</div>
<!-- BRANDING_JHONALEY_END -->
BRANDHTML

  inject_before_closing "$FILE" "$BRANDING_TMP" "$LABEL"
  rm -f "$BRANDING_TMP"
  echo "✅ Branding diperbarui di $LABEL"
}

BRANDING_APPLIED=0
for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ]; then
    inject_branding "$LF" "$(basename "$LF")"
    if grep -q "BRANDING_JHONALEY" "$LF" 2>/dev/null; then
      BRANDING_APPLIED=1
    fi
  fi
done

if [ "$BRANDING_APPLIED" -eq 0 ]; then
  echo "❌ Branding admin gagal dipasang: layout admin tidak ditemukan atau tidak termodifikasi"
  exit 1
fi

for LF in "${LAYOUT_FILES[@]}"; do
  if [ -f "$LF" ] && grep -q "<title>" "$LF"; then
    sed -i "s|<title>.*</title>|<title>Pterodactyl - $SAFE_TITLE</title>|g" "$LF" 2>/dev/null || true
    echo "✅ Title diubah di $(basename "$LF")"
  fi
done

echo "✅ Branding selesai!"

# ============================================================
# === BAGIAN 3: Welcome Banner di Client Dashboard ===
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Welcome Banner Client Dashboard"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WRAPPER_FILE="/var/www/pterodactyl/resources/views/templates/wrapper.blade.php"
MASTER_FILE="/var/www/pterodactyl/resources/views/layouts/master.blade.php"

WELCOME_TARGET=""
if [ -f "$WRAPPER_FILE" ]; then
  WELCOME_TARGET="$WRAPPER_FILE"
elif [ -f "$MASTER_FILE" ]; then
  WELCOME_TARGET="$MASTER_FILE"
else
  WELCOME_TARGET=$(find /var/www/pterodactyl/resources/views/ -name "wrapper.blade.php" 2>/dev/null | head -1)
  if [ -z "$WELCOME_TARGET" ]; then
    WELCOME_TARGET=$(find /var/www/pterodactyl/resources/views/templates/ -name "*.blade.php" 2>/dev/null | head -1)
  fi
fi

if [ -z "$WELCOME_TARGET" ] || [ ! -f "$WELCOME_TARGET" ]; then
  echo "⚠️ File layout client tidak ditemukan, skip welcome banner."
else
  echo "📂 Target: $WELCOME_TARGET"

  cp "$WELCOME_TARGET" "${WELCOME_TARGET}.bak_${TIMESTAMP}" 2>/dev/null || true
  remove_block_by_markers "$WELCOME_TARGET" "<!-- WELCOME_JHONALEY: Welcome Banner -->" "<!-- /WELCOME_JHONALEY -->"

  WELCOME_TEMP=$(mktemp)
  cat > "$WELCOME_TEMP" << WELCOME_EOF
<!-- WELCOME_JHONALEY: Welcome Banner -->
<style>
  .jhonaley-welcome {
    background: linear-gradient(135deg, #0c1929, #132f4c, #0a2744);
    border: 1px solid rgba(59, 130, 246, 0.4);
    border-left: 4px solid #3b82f6;
    border-radius: 8px;
    padding: 16px 20px;
    margin: 16px;
    display: flex;
    align-items: flex-start;
    gap: 12px;
    font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
    box-shadow: 0 4px 20px rgba(59, 130, 246, 0.1);
  }
  .jhonaley-welcome .jw-icon {
    background: rgba(59, 130, 246, 0.2);
    border-radius: 50%;
    width: 36px; height: 36px; min-width: 36px;
    display: flex; align-items: center; justify-content: center;
    font-size: 18px; color: #60a5fa; margin-top: 2px;
  }
  .jhonaley-welcome .jw-content h3 {
    color: #93c5fd; font-size: 16px; font-weight: 700;
    margin: 0 0 6px 0; letter-spacing: 0.3px;
  }
  .jhonaley-welcome .jw-content p {
    color: #94a3b8; font-size: 14px; margin: 0; line-height: 1.5;
  }
  .jhonaley-welcome .jw-content a {
    color: #e2e8f0; font-weight: 700; text-decoration: none; transition: color 0.2s;
  }
  .jhonaley-welcome .jw-content a:hover {
    color: #93c5fd; text-shadow: 0 0 8px rgba(147, 197, 253, 0.3);
  }
</style>
<script>
document.addEventListener("DOMContentLoaded", function() {
  function injectWelcome() {
    if (document.getElementById("jhonaley-welcome-banner")) return;
    var containers = [
      document.querySelector("[class*=ContentContainer]"),
      document.querySelector("[class*=content-wrapper]"),
      document.querySelector("#app > div > div:last-child"),
      document.querySelector("main"),
      document.querySelector(".content-wrapper"),
      document.querySelector("#app")
    ];
    var target = null;
    for (var i = 0; i < containers.length; i++) {
      if (containers[i]) { target = containers[i]; break; }
    }
    if (!target) return;
    var banner = document.createElement("div");
    banner.id = "jhonaley-welcome-banner";
    banner.className = "jhonaley-welcome";
    banner.innerHTML = '<div class="jw-icon">ℹ️</div><div class="jw-content"><h3>$WELCOME_TITLE_JS</h3><p>$WELCOME_MESSAGE_JS</p></div>';
    if (target.firstChild) { target.insertBefore(banner, target.firstChild); }
    else { target.appendChild(banner); }
  }
  injectWelcome();
  var observer = new MutationObserver(function() {
    if (!document.getElementById("jhonaley-welcome-banner")) injectWelcome();
  });
  var appEl = document.getElementById("app") || document.body;
  observer.observe(appEl, { childList: true, subtree: true });
});
</script>
<!-- /WELCOME_JHONALEY -->
WELCOME_EOF

  inject_before_closing "$WELCOME_TARGET" "$WELCOME_TEMP" "$(basename "$WELCOME_TARGET")"
  rm -f "$WELCOME_TEMP"
  echo "✅ Welcome banner diperbarui di $(basename "$WELCOME_TARGET")"
fi

# ===================================================================
# RE-INJECT SIDEBAR PROTECT MANAGER (jika hilang setelah modifikasi admin.blade.php)
# ===================================================================
ADMIN_LAYOUT=""
for CANDIDATE in \
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php" \
  "/var/www/pterodactyl/resources/views/layouts/app.blade.php"; do
  if [ -f "$CANDIDATE" ]; then
    ADMIN_LAYOUT="$CANDIDATE"
    break
  fi
done

if [ -f "$ADMIN_LAYOUT" ] && ! grep -q "PROTEKSI_JHONALEY_MASTER_SIDEBAR" "$ADMIN_LAYOUT" 2>/dev/null; then
  echo "🔧 Re-inject sidebar Protect Manager..."

  SIDEBAR_SNIPPET=$(mktemp)
  cat > "$SIDEBAR_SNIPPET" << 'SIDEBAR_PM_EOF'
                {{-- PROTEKSI_JHONALEY_MASTER_SIDEBAR: Protect Manager Menu --}}
                @if(Auth::user() && Auth::user()->id === 1)
                <li class="{{ Route::currentRouteName() === 'admin.protect-manager' ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>
                @endif
                {{-- END PROTEKSI_JHONALEY_MASTER_SIDEBAR --}}
SIDEBAR_PM_EOF

  INSERT_LINE=""
  SETTINGS_LINE=$(grep -n "admin.settings\|Configuration\|Settings\|settings" "$ADMIN_LAYOUT" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$SETTINGS_LINE" ]; then
    INSERT_LINE=$((SETTINGS_LINE - 1))
    while [ "$INSERT_LINE" -gt 0 ]; do
      if sed -n "${INSERT_LINE}p" "$ADMIN_LAYOUT" | grep -q "<li"; then
        break
      fi
      INSERT_LINE=$((INSERT_LINE - 1))
    done
  fi

  if [ -z "$INSERT_LINE" ] || [ "$INSERT_LINE" -le 0 ]; then
    INSERT_LINE=$(grep -n "</ul>" "$ADMIN_LAYOUT" | tail -1 | cut -d: -f1)
    if [ -n "$INSERT_LINE" ]; then
      INSERT_LINE=$((INSERT_LINE - 1))
    fi
  fi

  if [ -n "$INSERT_LINE" ] && [ "$INSERT_LINE" -gt 0 ]; then
    TEMP_LAYOUT=$(mktemp)
    head -n "$INSERT_LINE" "$ADMIN_LAYOUT" > "$TEMP_LAYOUT"
    cat "$SIDEBAR_SNIPPET" >> "$TEMP_LAYOUT"
    tail -n +"$((INSERT_LINE + 1))" "$ADMIN_LAYOUT" >> "$TEMP_LAYOUT"
    if cat "$TEMP_LAYOUT" > "$ADMIN_LAYOUT" 2>/dev/null; then
      echo "✅ Sidebar Protect Manager berhasil di-re-inject"
    else
      echo "⚠️ Gagal re-inject sidebar, skip"
    fi
    rm -f "$TEMP_LAYOUT"
  else
    echo "⚠️ Tidak bisa menemukan posisi sidebar untuk re-inject"
  fi
  rm -f "$SIDEBAR_SNIPPET"
fi

# ===================================================================
# CLEAR CACHE - di-handle oleh controller
# ===================================================================
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo ""
echo "==========================================="
echo "✅ INSTALLPROTECT5 SELESAI!"
echo "==========================================="
echo "🔒 Menu Nests disembunyikan (selain ID 1)"
echo "🔒 Akses NestController diblock (selain ID 1)"
echo "🎨 Branding footer $BRAND_NAME terpasang (hanya admin)"
echo "📝 Title panel diubah"
echo "📋 Welcome banner terpasang di client dashboard"
echo "📱 Kontak: $CONTACT_TELEGRAM"
echo "==========================================="