[CmdletBinding()]
param([string]$GodotPath='', [switch]$Freeform)
$ErrorActionPreference='Stop'
$roomRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $GodotPath) { $GodotPath=Join-Path $roomRoot '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' }
$probe=[Net.Sockets.UdpClient]::new(0)
try { $port=([Net.IPEndPoint]$probe.Client.LocalEndPoint).Port } finally { $probe.Dispose() }
$roomLogs=Join-Path $roomRoot ('Logs/custom-room-network/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$null=New-Item -ItemType Directory -Path $roomLogs -Force
$owned=@()
try {
    foreach ($role in @('host','client')) {
        $arguments=@('--headless','--path',('"'+$roomRoot+'"'),'--script','res://tests/custom_room_network_peer.gd','--','--port',"$port")
        if ($role -eq 'host') { $arguments+='--host' }
        if ($Freeform) { $arguments+='--freeform' }
        $process=Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$roomLogs/$role.out.log" -RedirectStandardError "$roomLogs/$role.err.log"
        $null=$process.Handle
        $owned+=$process
        if ($role -eq 'host') { Start-Sleep -Milliseconds 800 }
    }
    foreach ($process in $owned) {
        if (-not $process.WaitForExit(20000)) { throw 'Custom room network timeout' }
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "Custom room peer failed; logs: $roomLogs" }
    }
    $errors=Get-Content "$roomLogs/*.err.log" -Raw
    if ($errors -match 'SCRIPT ERROR|ERROR:|FAIL') { throw "Custom room errors: $errors" }
    $client=Get-Content "$roomLogs/client.out.log" -Raw
    if ($client -notmatch 'CUSTOM_ROOM_NET_PASS') { throw 'Client did not confirm custom geometry' }
    Write-Output "PASS custom room ENet replication; $roomLogs"
}
finally {
    foreach ($process in $owned) { if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force } }
}
