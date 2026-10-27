<#
.SYNOPSIS
Observes black-covered room swaps and door/stair sounds in two real ENet peers.
.DESCRIPTION
Ordinary game bots win two floors. No damage, enemy clears, room transitions or
perks are forced by this harness. Observers sample after Game._process and require
a full-black frame before each displayed room change, five exactly-once sounds
in the order door,door,stairs,door,door, and continuing snapshots during fades.
This proves local logical presentation/audio dispatch, not speaker output or WAN.
#>
[CmdletBinding()]
param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$fadeProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $GodotPath) { $GodotPath = Join-Path $fadeProjectRoot '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' }
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$probe = [Net.Sockets.UdpClient]::new(0)
try { $port = ([Net.IPEndPoint]$probe.Client.LocalEndPoint).Port } finally { $probe.Dispose() }
$run = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0,8))
$logs = Join-Path $fadeProjectRoot ('Logs/transition-network-smoke/' + $run)
$null = New-Item -ItemType Directory -Path $logs
$owned = [Collections.Generic.List[object]]::new()

function Read-FadeOutput([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $stream = $null
    $reader = $null
    try {
        $sharing = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
        $stream = [IO.FileStream]::new($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,$sharing)
        $reader = [IO.StreamReader]::new($stream)
        return $reader.ReadToEnd()
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        elseif ($null -ne $stream) { $stream.Dispose() }
    }
}

try {
    foreach ($role in @('host','client')) {
        $stdout = Join-Path $logs "$role.stdout.log"
        $stderr = Join-Path $logs "$role.stderr.log"
        $arguments = @('--headless','--path',('"'+$fadeProjectRoot+'"'),'--script','res://tests/transition_network_peer.gd','--','--test-port',"$port")
        if ($role -eq 'host') { $arguments += '--test-host' }
        $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $fadeProjectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null = $process.Handle
        $owned.Add([pscustomobject]@{ Role=$role; Process=$process; Stdout=$stdout; Stderr=$stderr })
        if ($role -eq 'host') {
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            do {
                Start-Sleep -Milliseconds 100
                $text = Read-FadeOutput $stdout
                $process.Refresh()
                if ([DateTime]::UtcNow -gt $deadline -or $process.HasExited) {
                    throw "Fade host did not start. Logs: $logs`n$text`n$(Read-FadeOutput $stderr)"
                }
            } until ($text -match 'SESSION_HOSTED')
        }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(70)
    do {
        $running = @($owned | Where-Object { $_.Process.Refresh(); -not $_.Process.HasExited })
        if ($running.Count -eq 0) { break }
        if ([DateTime]::UtcNow -gt $deadline) { throw "Fade peers timed out. Logs: $logs" }
        Start-Sleep -Milliseconds 100
    } while ($true)
    $layoutsByRole = @{}
    foreach ($entry in $owned) {
        $entry.Process.WaitForExit()
        $entry.Process.Refresh()
        $output = (Read-FadeOutput $entry.Stdout) + (Read-FadeOutput $entry.Stderr)
        if ($entry.Process.ExitCode -ne 0 -or $output -match '(?im)^\s*(SCRIPT ERROR|ERROR:|TRANSITION_NET_FAIL:)' -or
            $output -notmatch 'FADE_PEER[^\r\n]*transitions=5 black_tokens=5 swaps=5 rooms=6 sounds=5 stairs=1[^\r\n]*explored=true result=PASS') {
            throw "Fade peer $($entry.Role) failed. Logs: $logs`n$output"
        }
        $soundKinds = @([regex]::Matches($output,'(?m)^FADE_SOUND token=\d+ kind=(\w+) count=1\r?$') | ForEach-Object { $_.Groups[1].Value })
        if (($soundKinds -join ',') -ne 'door,door,stairs,door,door') { throw "Unexpected fade sounds for $($entry.Role). Logs: $logs" }
        $layouts = @([regex]::Matches($output,'(?m)^ROOM_LAYOUT[^\r\n]*\r?$') | ForEach-Object { $_.Value.Trim() })
        if ($layouts.Count -ne 6) { throw "Expected six actual room layouts for $($entry.Role). Logs: $logs" }
        $layoutsByRole[$entry.Role] = $layouts
    }
    if (($layoutsByRole.host -join "`n") -cne ($layoutsByRole.client -join "`n")) {
        throw "Host and client room layout identities/hashes differ. Logs: $logs"
    }
    Write-Output "PASS: two real peers completed two floors, five black-covered room swaps, one stair sound and continued snapshot polling. Logs: $logs"
}
finally {
    foreach ($entry in $owned) {
        $entry.Process.Refresh()
        if (-not $entry.Process.HasExited) { $entry.Process.Kill(); $null = $entry.Process.WaitForExit(1000) }
        $entry.Process.Dispose()
    }
}
