#!/bin/bash

BRAND_NAME="${BRAND_NAME:-Jhonaley Tech}"
BRAND_TEXT="${BRAND_TEXT:-Protect By Jhonaley}"
CONTACT_TELEGRAM="${CONTACT_TELEGRAM:-@danangvalentp}"

echo "🚀 Memasang proteksi Anti Tautan Server..."

INDEX_FILE="/var/www/pterodactyl/resources/views/admin/servers/index.blade.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

if [ -f "$INDEX_FILE" ]; then
  cp "$INDEX_FILE" "${INDEX_FILE}.bak_${TIMESTAMP}"
  echo "📦 Backup index file dibuat: ${INDEX_FILE}.bak_${TIMESTAMP}"
fi

cat > "$INDEX_FILE" << 'EOF'
@extends('layouts.admin')
@section('title')
    Servers
@endsection

@section('content-header')
    <h1>Servers<small>All servers available on the system.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Servers</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-xs-12">
        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">Server List</h3>
                <div class="box-tools search01">
                    <form action="{{ route('admin.servers') }}" method="GET">
                        <div class="input-group input-group-sm">
                            <input type="text" name="query" class="form-control pull-right" value="{{ request()->input('query') }}" placeholder="Search Servers">
                            <div class="input-group-btn">
                                <button type="submit" class="btn btn-default"><i class="fa fa-search"></i></button>
                                <a href="{{ route('admin.servers.new') }}"><button type="button" class="btn btn-sm btn-primary" style="border-radius:0 3px 3px 0;margin-left:2px;">Create New</button></a>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
            <div class="box-body table-responsive no-padding">
                <table class="table table-hover">
                    <thead>
                        <tr>
                            <th>Server Name</th>
                            <th>UUID</th>
                            <th>Owner</th>
                            <th>Node</th>
                            <th>Connection</th>
                            <th class="text-center">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($servers as $server)
                            <tr class="align-middle">
                                <td class="middle">
                                    <strong>{{ $server->name }}</strong>
                                    @if($server->id == 26)
                                    <br><small class="text-muted">HanzDev</small>
                                    @endif
                                </td>
                                <td class="middle"><code>{{ $server->uuidShort }}</code></td>
                                <td class="middle">
                                    <span class="label label-default">
                                        <i class="fa fa-user"></i> {{ $server->user->username }}
                                    </span>
                                </td>
                                <td class="middle">
                                    <span class="label label-info">
                                        <i class="fa fa-server"></i> {{ $server->node->name }}
                                    </span>
                                </td>
                                <td class="middle">
                                    <code>{{ $server->allocation->alias }}:{{ $server->allocation->port }}</code>
                                    @if($server->id == 26)
                                    <br><small><code>HanzDev:2007</code></small>
                                    @endif
                                </td>
                                <td class="text-center">
                                    @if((int) auth()->user()->id === 1)
                                        <a href="{{ route('admin.servers.view', $server->id) }}" class="btn btn-xs btn-primary">
                                            <i class="fa fa-wrench"></i> Manage
                                        </a>
                                    @else
                                        <span class="label label-warning" data-toggle="tooltip" title="Hanya Root Admin yang bisa mengakses">
                                            <i class="fa fa-shield"></i> Protected
                                        </span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            @if($servers->hasPages())
                <div class="box-footer with-border">
                    <div class="col-md-12 text-center">{!! $servers->appends(['query' => Request::input('query')])->render() !!}</div>
                </div>
            @endif
        </div>

        @if((int) auth()->user()->id !== 1)
        <div class="alert alert-warning">
            <h4 style="margin-top: 0;">
                <i class="fa fa-shield"></i> Security Protection Active
            </h4>
            <p style="margin-bottom: 5px;">
                <strong>🔒 Server Management Restricted:</strong>
                Hanya <strong>Root Administrator (ID: 1)</strong> yang dapat mengelola server existing.
            </p>
            <p style="margin-bottom: 0; font-size: 12px;">
                <strong>✅ Create New Server:</strong> Available for all administrators<br>
                <strong>🚫 Manage Existing:</strong> Root Admin only<br>
                <i class="fa fa-info-circle"></i>
                Protected by:
                <span class="label label-primary">@hanz_dev_sc</span>
                <span class="label label-success">@hanzmarketplace</span>
                <span class="label label-info">𝐇𝐀𝐍𝐙 𝐃𝐄𝐕</span>
            </p>
        </div>
        @else
        <div class="alert alert-success">
            <h4 style="margin-top: 0;">
                <i class="fa fa-crown"></i> Root Administrator Access
            </h4>
            <p style="margin-bottom: 0;">
                Anda memiliki akses penuh sebagai <strong>Root Administrator (ID: 1)</strong>.
                Semua server dapat dikelola secara normal.
            </p>
        </div>
        @endif
    </div>
</div>
@endsection

@section('footer-scripts')
    @parent
    <script>
        $(document).ready(function() {
            $('[data-toggle="tooltip"]').tooltip();

            @if((int) auth()->user()->id !== 1)
            $('a[href*="/admin/servers/view/"]').on('click', function(e) {
                e.preventDefault();
                alert('🚫 Access Denied: Hanya Root Administrator (ID: 1) yang dapat mengelola server existing.\n\n✅ Anda masih bisa membuat server baru dengan tombol "Create New"\n\nProtected by: @hanz_dev_sc');
            });
            @endif
        });
    </script>
@endsection
EOF

sed -i "s|𝐇𝐀𝐍𝐙 𝐃𝐄𝐕|${BRAND_NAME}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@hanz_dev_sc|${CONTACT_TELEGRAM}|g" "$INDEX_FILE" 2>/dev/null || true
sed -i "s|@hanz_dev_sc|${CONTACT_TELEGRAM}|g" "$INDEX_FILE" 2>/dev/null || true

chmod 644 "$INDEX_FILE"

echo "ℹ️ Cache clear akan dilakukan oleh Protect Manager controller"

echo ""
echo "🎉 PROTEKSI BERHASIL DIPASANG!"
echo "✅ Admin ID 1: Bisa akses semua (server list, view, dan management)"
echo "✅ Admin lain: Bisa Create New server, tapi tidak bisa manage existing"
echo "✅ View server asli tidak diubah agar tab tetap normal"
echo "🛡️ Security by: @hanz_dev_sc"
