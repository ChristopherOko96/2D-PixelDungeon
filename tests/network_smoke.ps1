<#
.SYNOPSIS
Checks separate localhost Godot processes and their network lifecycle markers.
.DESCRIPTION
With two players, runs the game's scripted smoke roles. With four players,
checks a host and three independent clients in the lobby. This verifies local
functionality only, not LAN/WAN connectivity, latency tolerance, or performance.
The four-player check also verifies all three disconnects are processed while
the host stays alive. Use -DisconnectOrder reverse to stagger client exits in
reverse join order and exercise a different teardown schedule.
All processes started by this script are stopped in finally. Logs remain in
the ignored Logs/network-smoke/<unique-run> directory for diagnosis.
#>
[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [ValidateSet(2, 4)]
    [int]$Players = 2,
    [ValidateRange(0, 65535)]
    [int]$Port = 0,
    [ValidateSet('simultaneous', 'reverse')]
    [string]$DisconnectOrder = 'simultaneous'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = Join-Path $projectRoot '..\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath. Pass -GodotPath with your console executable."
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'src\game.gd') -PathType Leaf)) {
    throw 'src/game.gd is missing; create the playable project before running this check.'
}
if ($Port -gt 0 -and $Port -lt 1024) {
    throw 'Pass -Port 0 for automatic selection, or a port from 1024 to 65535.'
}
if ($Port -eq 0) {
    $udpProbe = [System.Net.Sockets.UdpClient]::new(0)
    try {
        $Port = ([System.Net.IPEndPoint]$udpProbe.Client.LocalEndPoint).Port
    }
    finally {
        $udpProbe.Dispose()
    }
}
$runName = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
$logRoot = Join-Path $projectRoot "Logs\network-smoke\$runName"
$null = New-Item -ItemType Directory -Path $logRoot -Force
$owned = [System.Collections.Generic.List[object]]::new()
$timer = [System.Diagnostics.Stopwatch]::StartNew()

function Get-ProcessOutput {
    param([object]$Entry)
    $chunks = foreach ($path in @($Entry.Stdout, $Entry.Stderr)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            # Start-Process keeps its redirected output writer open on Windows
            # PowerShell 5. A reader must allow that writer to keep writing.
            $stream = $null
            $reader = $null
            try {
                $sharing = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
                $stream = [System.IO.FileStream]::new($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $sharing)
                $reader = [System.IO.StreamReader]::new($stream)
                $reader.ReadToEnd()
            }
            catch [System.IO.IOException] {
                # Marker polling retries transient creation/rotation locks.
                continue
            }
            finally {
                if ($null -ne $reader) { $reader.Dispose() }
                elseif ($null -ne $stream) { $stream.Dispose() }
            }
        }
    }
    return ($chunks -join "`n")
}

function Start-SmokeProcess {
    param([string]$Name, [string[]]$GameArguments)
    $stdout = Join-Path $logRoot "$Name.stdout.log"
    $stderr = Join-Path $logRoot "$Name.stderr.log"
    # Windows paths cannot contain a double quote. The resolved project root
    # has no trailing slash, so a quoted argument preserves spaces safely.
    $nativeArguments = @('--headless', '--path', ('"' + $projectRoot + '"'), '--') + $GameArguments
    $process = Start-Process -FilePath $GodotPath -ArgumentList $nativeArguments `
        -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    # Cache the native handle while running; Windows PowerShell 5 can otherwise
    # lose ExitCode for a Start-Process object that has already exited.
    $null = $process.Handle
    $entry = [pscustomobject]@{ Name = $Name; Process = $process; Stdout = $stdout; Stderr = $stderr }
    $owned.Add($entry)
    return $entry
}

function Wait-ForMarker {
    param([object]$Entry, [string]$Pattern, [double]$TimeoutSeconds = 5)
    $deadline = $timer.Elapsed.TotalSeconds + $TimeoutSeconds
    while ($timer.Elapsed.TotalSeconds -lt $deadline) {
        if ((Get-ProcessOutput -Entry $Entry) -match $Pattern) { return }
        $Entry.Process.Refresh()
        if ($Entry.Process.HasExited) {
            throw "$($Entry.Name) exited before marker '$Pattern'. Logs: $logRoot"
        }
        if ($timer.Elapsed.TotalSeconds -ge 50) {
            throw "Network smoke exceeded its 50-second limit. Logs: $logRoot"
        }
        Start-Sleep -Milliseconds 100
    }
    throw "$($Entry.Name) did not emit '$Pattern' in $TimeoutSeconds seconds. Logs: $logRoot"
}

try {
    Write-Host "Starting localhost network check: $Players players, UDP $Port, $DisconnectOrder disconnects."
    if ($Players -eq 2) {
        $hostArguments = @('--host', '--smoke-role', 'host', '--auto-start', '--port', "$Port", '--auto-exit', '16')
        $clientArguments = @('--join', '127.0.0.1', '--smoke-role', 'client', '--port', "$Port", '--auto-exit', '12')
    }
    else {
        $hostArguments = @('--host', '--port', "$Port", '--auto-exit', '20')
        $clientArguments = @('--join', '127.0.0.1', '--port', "$Port", '--auto-exit', '12')
    }
    $hostEntry = Start-SmokeProcess -Name 'host' -GameArguments $hostArguments
    Wait-ForMarker -Entry $hostEntry -Pattern 'SESSION_HOSTED'
    $clients = [System.Collections.Generic.List[object]]::new()
    for ($index = 1; $index -lt $Players; $index++) {
        $argumentsForClient = $clientArguments
        if ($Players -eq 4 -and $DisconnectOrder -eq 'reverse') {
            $exitSeconds = 12 + ($Players - 1 - $index)
            $argumentsForClient = @('--join', '127.0.0.1', '--port', "$Port", '--auto-exit', "$exitSeconds")
        }
        $client = Start-SmokeProcess -Name "client-$index" -GameArguments $argumentsForClient
        $clients.Add($client)
    }
    foreach ($client in $clients) {
        Wait-ForMarker -Entry $client -Pattern 'CLIENT_CONNECTED'
        Wait-ForMarker -Entry $client -Pattern 'SNAPSHOT_RECEIVED'
    }
    Wait-ForMarker -Entry $hostEntry -Pattern ("PEER_JOINED[^\r\n]*count[=: ]+$Players\b")
    if ($Players -eq 2) {
        Wait-ForMarker -Entry $hostEntry -Pattern 'RUN_STARTED' -TimeoutSeconds 6
        foreach ($client in $clients) {
            Wait-ForMarker -Entry $client -Pattern 'SNAPSHOT_RECEIVED[^\r\n]*phase=combat' -TimeoutSeconds 6
        }
    }
    while ($true) {
        $running = @($owned | Where-Object { $_.Process.Refresh(); -not $_.Process.HasExited })
        if ($running.Count -eq 0) { break }
        if ($timer.Elapsed.TotalSeconds -ge 50) {
            throw "Network smoke exceeded its 50-second limit. Logs: $logRoot"
        }
        Start-Sleep -Milliseconds 150
    }
    foreach ($entry in $owned) {
        $entry.Process.WaitForExit()
        if ($entry.Process.ExitCode -ne 0) {
            throw "$($entry.Name) exited with code $($entry.Process.ExitCode). Logs: $logRoot"
        }
        $output = Get-ProcessOutput -Entry $entry
        if ($output -match '(?im)^\s*(?:SCRIPT ERROR|ERROR|Parse Error|Parser Error)\b') {
            throw "$($entry.Name) logged a Godot error. Logs: $logRoot"
        }
    }
    if ($Players -eq 4) {
        $hostOutput = Get-ProcessOutput -Entry $hostEntry
        $disconnected = [regex]::Matches($hostOutput, '(?m)^PEER_LEFT peer=\d+ count=\d+\r?$').Count
        if ($disconnected -ne 3 -or $hostOutput -notmatch 'AUTO_EXIT phase=lobby PLAYER_COUNT=1\b') {
            throw "Host did not process all three disconnects and remain alone in the lobby. Logs: $logRoot"
        }
    }
    Write-Host "PASS: host + $($Players - 1) separate clients connected; every client received a snapshot; no Godot errors."
    Write-Host 'Coverage: localhost functional connectivity only. LAN/WAN and performance remain unverified.'
    [pscustomobject]@{
        Result = 'PASS'
        Players = $Players
        Port = $Port
        Mode = $(if ($Players -eq 2) { 'scripted gameplay' } else { 'lobby' })
        DisconnectOrder = $(if ($Players -eq 4) { $DisconnectOrder } else { 'client before host' })
        ElapsedSeconds = [math]::Round($timer.Elapsed.TotalSeconds, 1)
        Logs = $logRoot
    }
}
finally {
    foreach ($entry in $owned) {
        try {
            $entry.Process.Refresh()
            if (-not $entry.Process.HasExited) {
                Stop-Process -InputObject $entry.Process -Force -ErrorAction SilentlyContinue
                $null = $entry.Process.WaitForExit(500)
            }
        }
        finally {
            $entry.Process.Dispose()
        }
    }
    $timer.Stop()
}
