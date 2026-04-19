#!/bin/bash

BRAND_NAME="${BRAND_NAME:-𝙃𝘼𝙉𝙕 𝘿𝙀𝙑}"
BRAND_TEXT="${BRAND_TEXT:-Protect By HanzDev}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@hanz_dev_sc}"

TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

echo "🚀 Memasang proteksi Nodes + Client Account API + Application API User + Application API Controller..."
echo ""

# ===================================================================
# BAGIAN 1: PROTEKSI NODES (Sembunyikan + Block Akses)
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 1: Proteksi Nodes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === Restore & proteksi NodeViewController ===
CONTROLLER="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeViewController.php"
LATEST_BACKUP=$(ls -t "${CONTROLLER}.bak_"* 2>/dev/null | tail -1)

if [ -n "$LATEST_BACKUP" ]; then
  cp "$LATEST_BACKUP" "$CONTROLLER"
  echo "📦 NodeViewController di-restore dari backup: $LATEST_BACKUP"
else
  echo "⚠️ Tidak ada backup NodeViewController, menggunakan file saat ini"
fi

cp "$CONTROLLER" "${CONTROLLER}.bak_${TIMESTAMP}"

python3 << 'PYEOF'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeViewController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Proteksi sudah ada di NodeViewController")
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
        new_lines.append("            abort(403, 'Akses ditolak - protect by 𝐇𝐀𝐍𝐙 𝐃𝐄𝐕');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke NodeViewController")
PYEOF

echo ""
grep -n "PROTEKSI_JHONALEY" "$CONTROLLER"

# === Sembunyikan menu Nodes di sidebar ===
echo ""
echo "🔧 Menyembunyikan menu Nodes dari sidebar..."

SIDEBAR_FILES=(
  "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
  "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"
)

SIDEBAR_FOUND=""
for SF in "${SIDEBAR_FILES[@]}"; do
  if [ -f "$SF" ]; then
    SIDEBAR_FOUND="$SF"
    break
  fi
done

if [ -z "$SIDEBAR_FOUND" ]; then
  SIDEBAR_FOUND=$(grep -rl "admin.nodes" /var/www/pterodactyl/resources/views/layouts/ 2>/dev/null | head -1)
  if [ -z "$SIDEBAR_FOUND" ]; then
    SIDEBAR_FOUND=$(grep -rl "admin.nodes" /var/www/pterodactyl/resources/views/partials/ 2>/dev/null | head -1)
  fi
fi

if [ -n "$SIDEBAR_FOUND" ]; then
  if [ ! -f "${SIDEBAR_FOUND}.bak_${TIMESTAMP}" ]; then
    cp "$SIDEBAR_FOUND" "${SIDEBAR_FOUND}.bak_${TIMESTAMP}"
  fi
  echo "📂 Sidebar ditemukan: $SIDEBAR_FOUND"

  python3 << PYEOF2
sidebar = "$SIDEBAR_FOUND"

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_NODES_SIDEBAR" in content:
    print("⚠️ Sidebar Nodes sudah diproteksi")
    exit(0)

import re

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]

    if ('admin.nodes' in line or "route('admin.nodes')" in line) and 'admin.nodes.view' not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1

        if li_start >= 0:
            new_lines.insert(li_start, "{{-- PROTEKSI_NODES_SIDEBAR --}}")
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

with open(sidebar, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Menu Nodes disembunyikan dari sidebar")
PYEOF2

else
  echo "⚠️ File sidebar tidak ditemukan."
fi

# === Proteksi NodeController (halaman list nodes) ===
NODE_LIST="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
if [ -f "$NODE_LIST" ]; then
  if ! grep -q "PROTEKSI_JHONALEY" "$NODE_LIST"; then
    cp "$NODE_LIST" "${NODE_LIST}.bak_${TIMESTAMP}"
    
    python3 << 'PYEOF3'
controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY" in content:
    print("⚠️ Sudah ada proteksi")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    content = content.replace(
        "use Pterodactyl\\Http\\Controllers\\Controller;",
        "use Pterodactyl\\Http\\Controllers\\Controller;\nuse Illuminate\\Support\\Facades\\Auth;"
    )

import re
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

print("✅ NodeController juga diproteksi")
PYEOF3
  else
    echo "⚠️ NodeController sudah diproteksi"
  fi
fi

echo ""
echo "✅ BAGIAN 1 SELESAI: Proteksi Nodes terpasang"
echo ""

# ===================================================================
# BAGIAN 2: PROTEKSI CLIENT ACCOUNT API (Block ubah password/email admin ID 1)
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 2: Proteksi Client Account API"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ACCT_CTRL="/var/www/pterodactyl/app/Http/Controllers/Api/Client/AccountController.php"

if [ ! -f "$ACCT_CTRL" ]; then
  ACCT_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Api/Client -maxdepth 1 -iname "AccountController.php" 2>/dev/null | head -1)
fi

if [ -n "$ACCT_CTRL" ] && [ -f "$ACCT_CTRL" ]; then
  echo "📂 Client AccountController ditemukan: $ACCT_CTRL"

  ACCT_BACKUP=$(ls -t "${ACCT_CTRL}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$ACCT_BACKUP" ]; then
    cp "$ACCT_BACKUP" "$ACCT_CTRL"
    echo "📦 Restore dari backup: $ACCT_BACKUP"
  fi

  cp "$ACCT_CTRL" "${ACCT_CTRL}.bak_${TIMESTAMP}"

  python3 << PYEOF4
import re

controller = "$ACCT_CTRL"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_ACCOUNT" in content:
    print("⚠️ Proteksi sudah ada di AccountController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    use_pattern = r'(use Pterodactyl\\[^;]+;)'
    match = re.search(use_pattern, content)
    if match:
        content = content.replace(match.group(0), match.group(0) + "\nuse Illuminate\\Support\\Facades\\Auth;", 1)

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    if re.search(r'public function (updatePassword|updateEmail|update)\b', line) and '__construct' not in line:
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY_ACCOUNT: Block ubah data admin ID 1")
        new_lines.append("        \$targetUser = \$request->user();")
        new_lines.append("        if ((int) \$targetUser->id === 1 && (!Auth::user() || (int) Auth::user()->id !== 1)) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by Jhonaley Tech');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke Client AccountController")
PYEOF4

  echo ""
  grep -n "PROTEKSI_JHONALEY_ACCOUNT" "$ACCT_CTRL"
else
  echo "⚠️ Client AccountController tidak ditemukan, skip."
fi

echo ""
echo "✅ BAGIAN 2 SELESAI: Proteksi Client Account API terpasang"
echo ""

# ===================================================================
# BAGIAN 3: PROTEKSI APPLICATION API USER
# Strategi: Inject authorize() di Form Request + Middleware + Controller
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 3: Proteksi Application API User"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === LANGKAH 3a: Proteksi via Form Request authorize() ===
# authorize() jalan SEBELUM rules(), jadi ini paling efektif
echo "🔧 Langkah 3a: Inject proteksi ke Form Request..."

FORM_REQUEST_DIR="/var/www/pterodactyl/app/Http/Requests/Api/Application/Users"

if [ -d "$FORM_REQUEST_DIR" ]; then
  for FR_FILE in "$FORM_REQUEST_DIR"/*.php; do
    if [ -f "$FR_FILE" ]; then
      FR_NAME=$(basename "$FR_FILE")
      
      if grep -q "PROTEKSI_JHONALEY_FORMREQ" "$FR_FILE"; then
        echo "⚠️ $FR_NAME sudah diproteksi"
        continue
      fi
      
      cp "$FR_FILE" "${FR_FILE}.bak_${TIMESTAMP}"
      
      python3 << PYEOF_FR
import re

fr_file = "$FR_FILE"
fr_name = "$FR_NAME"

with open(fr_file, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_FORMREQ" in content:
    print(f"⚠️ {fr_name} sudah diproteksi")
    exit(0)

# Cari method authorize()
auth_pattern = r'(public function authorize\s*\(\s*\)[^{]*\{)'
match = re.search(auth_pattern, content)

if match:
    # Inject check di awal authorize()
    inject = '''
        // PROTEKSI_JHONALEY_FORMREQ: Block modifikasi user ID 1
        if (preg_match('#/api/application/users/1(?:\\\?|$|/)#', request()->getPathInfo())) {
            if (in_array(request()->method(), ['PATCH', 'PUT', 'DELETE'])) {
                abort(403, 'Akses ditolak - protect by 𝙃𝘼𝙉𝙕 𝘿𝙀𝙑');
            }
        }
'''
    content = content.replace(match.group(1), match.group(1) + inject)
    
    with open(fr_file, "w") as f:
        f.write(content)
    print(f"✅ {fr_name} diproteksi via authorize()")
else:
    # Tidak ada authorize(), tambahkan method baru
    # Cari class body
    class_pattern = r'(class \w+[^{]*\{)'
    class_match = re.search(class_pattern, content)
    if class_match:
        inject_method = '''

    // PROTEKSI_JHONALEY_FORMREQ: Block modifikasi user ID 1
    public function authorize(): bool
    {
        if (preg_match('#/api/application/users/1(?:\\\?|$|/)#', request()->getPathInfo())) {
            if (in_array(request()->method(), ['PATCH', 'PUT', 'DELETE'])) {
                abort(403, 'Akses ditolak - protect by 𝙃𝘼𝙉𝙕 𝘿𝙀𝙑');
            }
        }
        return true;
    }
'''
        content = content.replace(class_match.group(1), class_match.group(1) + inject_method)
        
        with open(fr_file, "w") as f:
            f.write(content)
        print(f"✅ {fr_name} diproteksi (authorize() baru ditambahkan)")
    else:
        print(f"❌ Gagal menemukan class di {fr_name}")

PYEOF_FR
    fi
  done
else
  echo "⚠️ Direktori Form Request tidak ditemukan: $FORM_REQUEST_DIR"
  echo "🔍 Mencari Form Request..."
  FORM_REQUEST_DIR=$(find /var/www/pterodactyl/app/Http/Requests -type d -iname "Users" -path "*/Application/*" 2>/dev/null | head -1)
  if [ -n "$FORM_REQUEST_DIR" ]; then
    echo "📂 Ditemukan: $FORM_REQUEST_DIR"
    echo "⚠️ Jalankan ulang script setelah path diperbaiki"
  fi
fi

# === LANGKAH 3b: Buat Middleware (layer tambahan) ===
echo ""
echo "🔧 Langkah 3b: Middleware ProtectAdminUser..."
MIDDLEWARE_DIR="/var/www/pterodactyl/app/Http/Middleware"
MIDDLEWARE_FILE="${MIDDLEWARE_DIR}/ProtectAdminUser.php"

cat > "$MIDDLEWARE_FILE" << 'MWEOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class ProtectAdminUser
{
    /**
     * PROTEKSI_JHONALEY_MIDDLEWARE: Block semua akses API ke User ID 1
     */
    public function handle(Request $request, Closure $next)
    {
        $path = $request->getPathInfo();

        if (preg_match('#/api/application/users/1(?:\?|$|/)#', $path)) {
            if (in_array($request->method(), ['PATCH', 'PUT', 'DELETE', 'POST'])) {
                abort(403, 'Akses ditolak - protect by 𝙃𝘼𝙉𝙕 𝘿𝙀𝙑');
            }
        }

        return $next($request);
    }
}
MWEOF

echo "✅ Middleware ProtectAdminUser dibuat"

# === LANGKAH 3c: Register middleware di Kernel.php ===
KERNEL="/var/www/pterodactyl/app/Http/Kernel.php"

if [ -f "$KERNEL" ]; then
  if ! grep -q "ProtectAdminUser" "$KERNEL"; then
    cp "$KERNEL" "${KERNEL}.bak_${TIMESTAMP}"

    python3 << 'PYEOF5'
import re

kernel = "/var/www/pterodactyl/app/Http/Kernel.php"

with open(kernel, "r") as f:
    content = f.read()

if "ProtectAdminUser" in content:
    print("⚠️ Middleware sudah terdaftar di Kernel")
    exit(0)

# Cari protected $middleware array
pattern = r'(protected \$middleware\s*=\s*\[)(.*?)(\];)'
match = re.search(pattern, content, re.DOTALL)

if match:
    existing = match.group(2).rstrip()
    if not existing.rstrip().endswith(','):
        existing = existing.rstrip() + ','
    new_content = match.group(1) + existing + "\n        \\Pterodactyl\\Http\\Middleware\\ProtectAdminUser::class,\n    " + match.group(3)
    content = content[:match.start()] + new_content + content[match.end():]
else:
    # Fallback: cari $middlewareGroups api
    api_pattern = r"('api'\s*=>\s*\[)(.*?)(\],)"
    api_match = re.search(api_pattern, content, re.DOTALL)
    if api_match:
        existing = api_match.group(2).rstrip()
        if not existing.rstrip().endswith(','):
            existing = existing.rstrip() + ','
        new_content = api_match.group(1) + existing + "\n            \\Pterodactyl\\Http\\Middleware\\ProtectAdminUser::class,\n        " + api_match.group(3)
        content = content[:api_match.start()] + new_content + content[api_match.end():]
    else:
        print("❌ Tidak bisa menemukan array middleware di Kernel.php")
        exit(1)

with open(kernel, "w") as f:
    f.write(content)

print("✅ Middleware ProtectAdminUser didaftarkan di Kernel.php")
PYEOF5

  else
    echo "⚠️ Middleware ProtectAdminUser sudah terdaftar di Kernel"
  fi
else
  echo "❌ Kernel.php tidak ditemukan!"
fi

# === LANGKAH 3d: Juga proteksi controller (backup plan) ===
APP_USER_CTRL="/var/www/pterodactyl/app/Http/Controllers/Api/Application/Users/UserController.php"

if [ ! -f "$APP_USER_CTRL" ]; then
  APP_USER_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Api/Application -iname "UserController.php" 2>/dev/null | head -1)
fi

if [ -n "$APP_USER_CTRL" ] && [ -f "$APP_USER_CTRL" ]; then
  APP_BACKUP=$(ls -t "${APP_USER_CTRL}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$APP_BACKUP" ]; then
    cp "$APP_BACKUP" "$APP_USER_CTRL"
  fi
  cp "$APP_USER_CTRL" "${APP_USER_CTRL}.bak_${TIMESTAMP}"

  if ! grep -q "PROTEKSI_JHONALEY_APPUSER" "$APP_USER_CTRL"; then
    python3 << PYEOF6
import re

controller = "$APP_USER_CTRL"

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_APPUSER" in content:
    exit(0)

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
        
        new_lines.append("        // PROTEKSI_JHONALEY_APPUSER: Block akses API untuk admin ID 1")
        if 'User \$user' in line or (j > i and any('User \$user' in lines[k] for k in range(i, min(j+1, len(lines))))):
            new_lines.append("        if (isset(\$user) && (int) \$user->id === 1) {")
            new_lines.append("            abort(403, 'Akses ditolak - protect by 𝙃𝘼𝙉𝙕 𝘿𝙀𝙑');")
            new_lines.append("        }")
        else:
            new_lines.append("        if (preg_match('#/users/1(\\\\?|\$|/|\\\\b)#', \$request->getPathInfo())) {")
            new_lines.append("            abort(403, 'Akses ditolak - protect by 𝙃𝘼𝙉𝙕 𝘿𝙀𝙑');")
            new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Controller UserController juga diproteksi (backup plan)")
PYEOF6
  fi
fi

echo ""
echo "✅ BAGIAN 3 SELESAI: Proteksi Application API User terpasang (Middleware + Controller)"
echo ""

# ===================================================================
# BAGIAN 4: PROTEKSI API KEY - Block buat key atas nama User ID 1
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 4: Block buat API key atas nama User ID 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

API_CTRL="/var/www/pterodactyl/app/Http/Controllers/Admin/ApiController.php"

if [ ! -f "$API_CTRL" ]; then
  API_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Admin -maxdepth 1 -iname "*api*" -name "*.php" 2>/dev/null | head -1)
fi

if [ -n "$API_CTRL" ] && [ -f "$API_CTRL" ]; then
  echo "📂 ApiController ditemukan: $API_CTRL"

  API_BACKUP=$(ls -t "${API_CTRL}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$API_BACKUP" ]; then
    cp "$API_BACKUP" "$API_CTRL"
    echo "📦 Restore dari backup: $API_BACKUP"
  fi

  cp "$API_CTRL" "${API_CTRL}.bak_${TIMESTAMP}"

  export API_CTRL_PATH="$API_CTRL"
  python3 << 'PYEOF7'
import re
import os

controller = os.environ["API_CTRL_PATH"]

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_APIKEY" in content:
    print("⚠️ Proteksi sudah ada di ApiController")
    exit(0)

if "use Illuminate\\Support\\Facades\\Auth;" not in content:
    use_pattern = r'(use Pterodactyl\\\\Http\\\\Controllers\\\\Controller;)'
    if re.search(use_pattern, content):
        content = re.sub(use_pattern, r'\1\nuse Illuminate\\Support\\Facades\\Auth;', content)
    else:
        content = re.sub(r'(use [^;]+;)(\s*class )', r'\1\nuse Illuminate\\Support\\Facades\\Auth;\2', content)

lines = content.split("\n")
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)
    
    # Inject di method index
    if re.search(r'public function index', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY_APIKEY: Setiap admin hanya lihat key milik sendiri")
        new_lines.append("        if (Auth::user() && (int) Auth::user()->id !== 1) {")
        new_lines.append("            $keys = \\Pterodactyl\\Models\\ApiKey::where('user_id', (int) Auth::user()->id)")
        new_lines.append("                ->where('key_type', \\Pterodactyl\\Models\\ApiKey::TYPE_APPLICATION)")
        new_lines.append("                ->get();")
        new_lines.append("            return view('admin.api.index', ['keys' => $keys]);")
        new_lines.append("        }")
        
        if j > i:
            i = j
    
    # Inject di method store
    if re.search(r'public function store', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY_APIKEY: Block buat key atas nama User ID 1")
        new_lines.append("        $targetUserId = (int) ($request->input('user_id') ?? $request->input('user') ?? 0);")
        new_lines.append("        if ($targetUserId === 1 && (!Auth::user() || (int) Auth::user()->id !== 1)) {")
        new_lines.append("            abort(403, 'Tidak bisa membuat API key atas nama User ID 1 - protect by 𝙃𝘼𝙉𝙕 𝘿𝙀𝙑');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    
    # Inject di method delete/destroy
    if re.search(r'public function (delete|destroy)', line):
        j = i
        while j < len(lines) and '{' not in lines[j]:
            j += 1
            if j > i:
                new_lines.append(lines[j])
        
        new_lines.append("        // PROTEKSI_JHONALEY_APIKEY: Block hapus key milik User ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            $key = $request->route('id') ?? $request->route('key');")
        new_lines.append("            if ($key) {")
        new_lines.append("                $apiKey = \\Pterodactyl\\Models\\ApiKey::find($key);")
        new_lines.append("                if ($apiKey && (int) $apiKey->user_id === 1) {")
        new_lines.append("                    abort(403, 'Tidak bisa menghapus API key milik User ID 1 - protect by 𝙃𝘼𝙉𝙕 𝘿𝙀𝙑');")
        new_lines.append("                }")
        new_lines.append("            }")
        new_lines.append("        }")
        
        if j > i:
            i = j
    
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi API key berhasil diinjeksi ke ApiController")
PYEOF7

  echo ""
  grep -n "PROTEKSI_JHONALEY_APIKEY" "$API_CTRL"
else
  echo "⚠️ ApiController tidak ditemukan, skip."
fi

echo ""
echo "✅ BAGIAN 4 SELESAI: Proteksi API key terpasang"
echo ""

# ===================================================================
# ===================================================================
# PROTEKSI BLADE VIEW: API INDEX - filter key per admin
# ===================================================================
API_BLADE="/var/www/pterodactyl/resources/views/admin/api/index.blade.php"

if [ ! -f "$API_BLADE" ]; then
  API_BLADE=$(find /var/www/pterodactyl/resources/views/admin -path "*/api/index*" -name "*.blade.php" 2>/dev/null | head -1)
fi

if [ -n "$API_BLADE" ] && [ -f "$API_BLADE" ]; then
  echo "📂 API Blade view ditemukan: $API_BLADE"

  API_BLADE_BACKUP=$(ls -t "${API_BLADE}.bak_"* 2>/dev/null | tail -1)
  if [ -n "$API_BLADE_BACKUP" ]; then
    cp "$API_BLADE_BACKUP" "$API_BLADE"
    echo "📦 Restore dari backup: $API_BLADE_BACKUP"
  fi

  cp "$API_BLADE" "${API_BLADE}.bak_${TIMESTAMP}"

  export API_BLADE_PATH="$API_BLADE"
  python3 << 'PYEOF_BLADE'
import re
import os

blade_file = os.environ["API_BLADE_PATH"]

with open(blade_file, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_APIKEY_BLADE" in content:
    print("⚠️ Proteksi Blade sudah ada")
    exit(0)

# Cari loop @foreach yang menampilkan keys
foreach_pattern = r'(@foreach\s*\(\s*\$\w+\s+as\s+\$(\w+)\s*\))'
match = re.search(foreach_pattern, content)

if match:
    original_foreach = match.group(0)
    
    filter_code = """
{{-- PROTEKSI_JHONALEY_APIKEY_BLADE: Setiap admin hanya lihat key sendiri --}}
@php
    $__currentUserId = (int) Auth::user()->id;
    if ($__currentUserId !== 1) {
        $keys = $keys->filter(function($item) use ($__currentUserId) {
            return (int) $item->user_id === $__currentUserId;
        });
    }
@endphp
""" + original_foreach
    
    content = content.replace(original_foreach, filter_code, 1)
    
    with open(blade_file, "w") as f:
        f.write(content)
    print("✅ Proteksi Blade view API berhasil diterapkan")
else:
    foreach_generic = re.search(r'(@foreach\s*\([^)]+\))', content)
    if foreach_generic:
        original = foreach_generic.group(0)
        filter_code = """
{{-- PROTEKSI_JHONALEY_APIKEY_BLADE: Setiap admin hanya lihat key sendiri --}}
@php
    $__currentUserId = (int) Auth::user()->id;
    if ($__currentUserId !== 1) {
        $keys = isset($keys) ? $keys->filter(function($item) use ($__currentUserId) {
            return (int) ($item->user_id ?? 0) === $__currentUserId;
        }) : collect([]);
    }
@endphp
""" + original
        content = content.replace(original, filter_code, 1)
        
        with open(blade_file, "w") as f:
            f.write(content)
        print("✅ Proteksi Blade view API (fallback) berhasil diterapkan")
    else:
        print("⚠️ Tidak menemukan @foreach di Blade view")

PYEOF_BLADE
else
  echo "⚠️ Blade view API tidak ditemukan"
fi

# ===================================================================
# BAGIAN 5: PROTEKSI LOCATIONS (Sembunyikan + Block Akses)
# ===================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 BAGIAN 5: Proteksi Locations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# === Sembunyikan menu Locations di sidebar ===
echo "🔧 Menyembunyikan menu Locations dari sidebar..."

# Re-use sidebar file dari BAGIAN 1
LOC_SIDEBAR=""
for SF in "/var/www/pterodactyl/resources/views/layouts/admin.blade.php" "/var/www/pterodactyl/resources/views/partials/admin/sidebar.blade.php"; do
  if [ -f "$SF" ]; then
    LOC_SIDEBAR="$SF"
    break
  fi
done

if [ -z "$LOC_SIDEBAR" ]; then
  LOC_SIDEBAR=$(grep -rl "admin.locations" /var/www/pterodactyl/resources/views/ 2>/dev/null | head -1)
fi

if [ -n "$LOC_SIDEBAR" ] && [ -f "$LOC_SIDEBAR" ]; then
  if grep -q "PROTEKSI_LOCATIONS_SIDEBAR" "$LOC_SIDEBAR"; then
    echo "⚠️ Sidebar Locations sudah diproteksi"
  else
    if [ ! -f "${LOC_SIDEBAR}.bak_${TIMESTAMP}" ]; then
      cp "$LOC_SIDEBAR" "${LOC_SIDEBAR}.bak_${TIMESTAMP}"
    fi

    python3 << PYEOF_LOC_SIDEBAR
sidebar = "$LOC_SIDEBAR"

with open(sidebar, "r") as f:
    content = f.read()

if "PROTEKSI_LOCATIONS_SIDEBAR" in content:
    print("⚠️ Sidebar Locations sudah diproteksi")
    exit(0)

import re

lines = content.split("\n")
new_lines = []
i = 0

while i < len(lines):
    line = lines[i]

    if ('admin.locations' in line or "route('admin.locations')" in line) and 'admin.locations.view' not in line:
        li_start = len(new_lines) - 1
        while li_start >= 0 and '<li' not in new_lines[li_start]:
            li_start -= 1

        if li_start >= 0:
            new_lines.insert(li_start, "{{-- PROTEKSI_LOCATIONS_SIDEBAR --}}")
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

with open(sidebar, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Menu Locations disembunyikan dari sidebar")
PYEOF_LOC_SIDEBAR
  fi
else
  echo "⚠️ File sidebar tidak ditemukan untuk Locations"
fi

# === Proteksi LocationController ===
echo ""
echo "🔧 Memproteksi LocationController..."

LOC_CTRL="/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"

if [ ! -f "$LOC_CTRL" ]; then
  LOC_CTRL=$(find /var/www/pterodactyl/app/Http/Controllers/Admin -maxdepth 1 -iname "LocationController.php" 2>/dev/null | head -1)
fi

if [ -n "$LOC_CTRL" ] && [ -f "$LOC_CTRL" ]; then
  echo "📂 LocationController ditemukan: $LOC_CTRL"

  if grep -q "PROTEKSI_JHONALEY_LOCATION" "$LOC_CTRL"; then
    echo "⚠️ LocationController sudah diproteksi"
  else
    LOC_BACKUP=$(ls -t "${LOC_CTRL}.bak_"* 2>/dev/null | tail -1)
    if [ -n "$LOC_BACKUP" ]; then
      cp "$LOC_BACKUP" "$LOC_CTRL"
      echo "📦 Restore dari backup: $LOC_BACKUP"
    fi

    cp "$LOC_CTRL" "${LOC_CTRL}.bak_${TIMESTAMP}"

    python3 << 'PYEOF_LOC_CTRL'
import re

controller = "/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"

# Coba path default, kalau tidak ada cari
import os
if not os.path.exists(controller):
    import subprocess
    result = subprocess.run(
        ["find", "/var/www/pterodactyl/app/Http/Controllers/Admin", "-maxdepth", "1", "-iname", "LocationController.php"],
        capture_output=True, text=True
    )
    if result.stdout.strip():
        controller = result.stdout.strip().split("\n")[0]
    else:
        print("❌ LocationController tidak ditemukan")
        exit(1)

with open(controller, "r") as f:
    content = f.read()

if "PROTEKSI_JHONALEY_LOCATION" in content:
    print("⚠️ Sudah ada proteksi")
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
        
        new_lines.append("        // PROTEKSI_JHONALEY_LOCATION: Hanya admin ID 1")
        new_lines.append("        if (!Auth::user() || (int) Auth::user()->id !== 1) {")
        new_lines.append("            abort(403, 'Akses ditolak - protect by 𝙃𝘼𝙉𝙕 𝘿𝙀𝙑');")
        new_lines.append("        }")
        
        if j > i:
            i = j
    i += 1

with open(controller, "w") as f:
    f.write("\n".join(new_lines))

print("✅ Proteksi berhasil diinjeksi ke LocationController")
PYEOF_LOC_CTRL
  fi
else
  echo "⚠️ LocationController tidak ditemukan, skip."
fi

echo ""
echo "✅ BAGIAN 5 SELESAI: Proteksi Locations terpasang"
echo ""

# ===================================================================
# APPLY BRAND CUSTOMIZATION to all modified files
# ===================================================================
echo "🎨 Menerapkan kustomisasi brand..."
for MODIFIED_FILE in "$CONTROLLER" "$NODE_LIST" "$ACCT_CTRL" "$APP_USER_CTRL" "$API_CTRL" "$MIDDLEWARE_FILE" "$LOC_CTRL"; do
  if [ -n "$MODIFIED_FILE" ] && [ -f "$MODIFIED_FILE" ]; then
    sed -i "s|protect by 𝙃𝘼𝙉𝙕 𝘿𝙀𝙑|${BRAND_TEXT}|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|Akses ditolak - protect by 𝙃𝘼𝙉𝙕 𝘿𝙀𝙑|${BRAND_TEXT} - Akses ditolak|g" "$MODIFIED_FILE" 2>/dev/null || true
    sed -i "s|𝙃𝘼𝙉𝙕 𝘿𝙀𝙑|${BRAND_NAME}|g" "$MODIFIED_FILE" 2>/dev/null || true
  fi
done
echo "✅ Brand customization diterapkan"

# ===================================================================
# CLEAR CACHE - di-handle oleh controller
# ===================================================================
echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo ""
echo "==========================================="
echo "✅ SEMUA PROTEKSI LENGKAP TERPASANG!"
echo "==========================================="
echo "🔒 Menu Nodes disembunyikan dari sidebar (selain ID 1)"
echo "🔒 Akses /admin/nodes diblock (selain ID 1)"
echo "🔒 Menu Locations disembunyikan dari sidebar (selain ID 1)"
echo "🔒 Akses /admin/locations diblock (selain ID 1)"
echo "🔒 Password & email admin ID 1 tidak bisa diubah via Client API"
echo "🔒 Data admin ID 1 tidak bisa diakses/diubah/dihapus via Application API"
echo "🔒 Admin lain tidak bisa buat/hapus API key atas nama User ID 1"
echo "🚀 Panel tetap normal, server tetap jalan"
echo "==========================================="
echo ""
echo "⚠️ Jika ada masalah, restore:"
echo "   cp ${CONTROLLER}.bak_${TIMESTAMP} $CONTROLLER"
if [ -f "$NODE_LIST" ]; then
echo "   cp ${NODE_LIST}.bak_${TIMESTAMP} $NODE_LIST"
fi
if [ -n "$ACCT_CTRL" ] && [ -f "$ACCT_CTRL" ]; then
echo "   cp ${ACCT_CTRL}.bak_${TIMESTAMP} $ACCT_CTRL"
fi
if [ -n "$APP_USER_CTRL" ] && [ -f "$APP_USER_CTRL" ]; then
echo "   cp ${APP_USER_CTRL}.bak_${TIMESTAMP} $APP_USER_CTRL"
fi
if [ -n "$API_CTRL" ] && [ -f "$API_CTRL" ]; then
echo "   cp ${API_CTRL}.bak_${TIMESTAMP} $API_CTRL"
fi
echo "   cd /var/www/pterodactyl && php artisan view:clear && php artisan route:clear"
