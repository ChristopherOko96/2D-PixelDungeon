<#
.SYNOPSIS
Proves two seeded dungeon floors with two or four independent local Godot peers.
.DESCRIPTION
The existing smoke bots play combat through ordinary host-authoritative inputs.
This script never grants damage, clears enemies, or changes the game state.
It requires six matching room identities, templates and layout hashes on every
peer, both floors' combat/reward phases, spatial door/stair transitions and
continued exploration after the second boss. Native tile size is thirty-two pixels.
Coverage is local functional replication, not LAN/WAN or performance evidence.
Only processes started here are stopped in finally. Diagnostic logs are retained.
#>
[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [ValidateRange(0, 65535)]
    [int]$Port = 0,
    [ValidateRange(1, 2147483647)]
    [int]$Seed = 24680,
    [ValidateSet(2, 4)]
    [int]$Players = 2,
    [ValidateRange(30, 110)]
    [int]$RunSeconds = 75
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Arrange: isolate the port, process handles and logs for this invocation.
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = Join-Path $projectRoot '..\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable not found: $GodotPath. Pass -GodotPath with the console executable."
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'src\game.gd') -PathType Leaf)) {
    throw 'src/game.gd is missing.'
}
$roomConfiguration = Get-Content -LiteralPath (Join-Path $projectRoot 'assets\data\dungeon_rooms.json') -Raw | ConvertFrom-Json
if ($roomConfiguration.tile_size -ne 32 -or $roomConfiguration.generator_version -ne 4 -or
    $roomConfiguration.world_size[0] -ne 896 -or $roomConfiguration.world_size[1] -ne 480) {
    throw 'This check requires native 32-pixel dungeon data, generator version 4 and a 896x480 world.'
}
if ($Port -gt 0 -and $Port -lt 1024) {
    throw 'Pass -Port 0 for automatic selection, or a port from 1024 to 65535.'
}
if ($Port -eq 0) {
    $udpProbe = [System.Net.Sockets.UdpClient]::new(0)
    try { $Port = ([System.Net.IPEndPoint]$udpProbe.Client.LocalEndPoint).Port }
    finally { $udpProbe.Dispose() }
}
$runName = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
$logRoot = Join-Path $projectRoot "Logs\dungeon-network-smoke\$runName"
$null = New-Item -ItemType Directory -Path $logRoot -Force
$owned = [System.Collections.Generic.List[object]]::new()
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$deadlineSeconds = $RunSeconds + 15

function Get-ProcessOutput {
    param([object]$Entry)
    $chunks = foreach ($path in @($Entry.Stdout, $Entry.Stderr)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $stream = $null
        $reader = $null
        try {
            # PowerShell 5 retains redirected writers while processes are alive.
            $sharing = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
            $stream = [System.IO.FileStream]::new($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $sharing)
            $reader = [System.IO.StreamReader]::new($stream)
            $reader.ReadToEnd()
        }
        catch [System.IO.IOException] { continue }
        finally {
            if ($null -ne $reader) { $reader.Dispose() }
            elseif ($null -ne $stream) { $stream.Dispose() }
        }
    }
    return ($chunks -join "`n")
}

function Start-DungeonProcess {
    param([string]$Name, [string[]]$GameArguments)
    $stdout = Join-Path $logRoot "$Name.stdout.log"
    $stderr = Join-Path $logRoot "$Name.stderr.log"
    $nativeArguments = @('--headless', '--path', ('"' + $projectRoot + '"'), '--') + $GameArguments
    $process = Start-Process -FilePath $GodotPath -ArgumentList $nativeArguments `
        -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $process.Handle
    $entry = [pscustomobject]@{ Name = $Name; Process = $process; Stdout = $stdout; Stderr = $stderr }
    $owned.Add($entry)
    return $entry
}

function Assert-NoProcessErrors {
    foreach ($entry in $owned) {
        $output = Get-ProcessOutput -Entry $entry
        if ($output -match '(?im)^\s*(?:SCRIPT ERROR|ERROR|Parse Error|Parser Error)\b') {
            throw "$($entry.Name) logged a Godot error. Logs: $logRoot"
        }
        if ($output -match '(?m)^TEAM_WIPE\b') {
            throw "$($entry.Name) reported a team wipe before completing the dungeon. Logs: $logRoot"
        }
    }
}

function Wait-ForMarker {
    param([object]$Entry, [string]$Pattern)
    $markerDeadline = [Math]::Min($deadlineSeconds, $timer.Elapsed.TotalSeconds + 8)
    while ($timer.Elapsed.TotalSeconds -lt $markerDeadline) {
        Assert-NoProcessErrors
        if ((Get-ProcessOutput -Entry $Entry) -match $Pattern) { return }
        $Entry.Process.Refresh()
        if ($Entry.Process.HasExited) {
            throw "$($Entry.Name) exited before '$Pattern'. Logs: $logRoot"
        }
        Start-Sleep -Milliseconds 100
    }
    throw "$($Entry.Name) did not emit '$Pattern' before the startup deadline. Logs: $logRoot"
}

function Assert-RoomSequence {
    param([string]$OutputText, [string]$Pattern, [string]$Description)
    $matchesForSequence = [regex]::Matches($OutputText, $Pattern)
    $rooms = @($matchesForSequence | ForEach-Object { [int]$_.Groups[1].Value })
    if (($rooms -join ',') -ne '1,2,3,1,2,3') {
        throw "$Description must report two floors of rooms 1,2,3 in order; found '$($rooms -join ',')'. Logs: $logRoot"
    }
}

function Get-RoomLayouts {
    param([string]$OutputText, [string]$ProcessName)
    $lines = [regex]::Matches($OutputText, '(?m)^ROOM_LAYOUT[^\r\n]*\r?$')
    $matchesForLayout = [regex]::Matches($OutputText, '(?m)^ROOM_LAYOUT id=(\S+) template=(\S+) version=(\d+) signature=([a-fA-F0-9]{64})\r?$')
    if ($lines.Count -ne 6 -or $matchesForLayout.Count -ne 6) {
        throw "$ProcessName must report six valid ROOM_LAYOUT lines; found $($lines.Count) lines and $($matchesForLayout.Count) valid hashes. Logs: $logRoot"
    }
    foreach ($layout in $matchesForLayout) {
        [pscustomobject]@{
            Id = $layout.Groups[1].Value
            Template = $layout.Groups[2].Value
            Version = [int]$layout.Groups[3].Value
            Signature = $layout.Groups[4].Value.ToLowerInvariant()
        }
    }
}

try {
    # Act: real processes use ordinary bot inputs, including walking to exits.
    Write-Host "Starting two-floor dungeon check: $Players peers, seed $Seed, UDP $Port."
    $hostArguments = @('--host', '--seed', "$Seed", '--smoke-role', 'host', '--auto-start', '--wait-players', "$Players", '--smoke-floors', '2', '--port', "$Port", '--auto-exit', "$RunSeconds")
    $hostEntry = Start-DungeonProcess -Name 'host' -GameArguments $hostArguments
    Wait-ForMarker -Entry $hostEntry -Pattern '(?m)^SESSION_HOSTED\b'
    for ($index = 1; $index -lt $Players; $index++) {
        # Startup is sequential. Later clients must still finish before the host;
        # subtract actual elapsed startup time instead of a fixed three seconds.
        $clientSeconds = [Math]::Max(5, $RunSeconds - [Math]::Ceiling($timer.Elapsed.TotalSeconds) - 3)
        $clientArguments = @('--join', '127.0.0.1', '--seed', "$Seed", '--smoke-role', 'client', '--smoke-floors', '2', '--port', "$Port", '--auto-exit', "$clientSeconds")
        $clientEntry = Start-DungeonProcess -Name "client-$index" -GameArguments $clientArguments
        Wait-ForMarker -Entry $clientEntry -Pattern '(?m)^CLIENT_CONNECTED\b'
    }
    Wait-ForMarker -Entry $hostEntry -Pattern ("(?m)^PEER_JOINED[^\r\n]*count=$Players\r?$")
    Wait-ForMarker -Entry $hostEntry -Pattern ("(?m)^RUN_STARTED seed=$Seed players=$Players\r?$")
    foreach ($entry in $owned) {
        Wait-ForMarker -Entry $entry -Pattern ("(?m)^SNAPSHOT_RECEIVED phase=combat players=$Players room=1\r?$")
    }
    while ($true) {
        Assert-NoProcessErrors
        $running = @($owned | Where-Object { $_.Process.Refresh(); -not $_.Process.HasExited })
        if ($running.Count -eq 0) { break }
        if ($timer.Elapsed.TotalSeconds -ge $deadlineSeconds) {
            throw "Dungeon smoke exceeded its $deadlineSeconds-second deadline. Logs: $logRoot"
        }
        Start-Sleep -Milliseconds 150
    }

    # Assert: clean exits, real room clears and identical replicated geometry.
    foreach ($entry in $owned) {
        $entry.Process.WaitForExit()
        if ($entry.Process.ExitCode -ne 0) {
            throw "$($entry.Name) exited with code $($entry.Process.ExitCode). Logs: $logRoot"
        }
    }
    Assert-NoProcessErrors
    $hostOutput = Get-ProcessOutput -Entry $hostEntry
    Assert-RoomSequence -OutputText $hostOutput -Pattern '(?m)^ROOM_STARTED room=(\d+)\b[^\r\n]*\r?$' -Description 'Host combat starts'
    Assert-RoomSequence -OutputText $hostOutput -Pattern '(?m)^ROOM_CLEARED room=(\d+) phase=reward\r?$' -Description 'Host combat clears'
    foreach ($entry in $owned) {
        $output = Get-ProcessOutput -Entry $entry
        Assert-RoomSequence -OutputText $output -Pattern ("(?m)^SNAPSHOT_RECEIVED phase=combat players=$Players room=(\d+)\r?$") -Description "$($entry.Name) combat snapshots"
        Assert-RoomSequence -OutputText $output -Pattern ("(?m)^SNAPSHOT_RECEIVED phase=reward players=$Players room=(\d+)\r?$") -Description "$($entry.Name) reward snapshots"
        $receivedFloors = @([regex]::Matches($output, '(?m)^FLOOR_RECEIVED floor=(\d+) seed=\d+\r?$') | ForEach-Object { [int]$_.Groups[1].Value })
        if (($receivedFloors -join ',') -ne '1,2' -or
            $output -notmatch ("(?m)^SNAPSHOT_RECEIVED phase=explore players=$Players room=3\r?$") -or
            $output -notmatch '(?m)^AUTO_EXIT phase=explore PLAYER_COUNT=\d+\r?$') {
            throw "$($entry.Name) did not receive both floors and remain freely exploring after the final boss. Logs: $logRoot"
        }
    }
    $clearedFloors = @([regex]::Matches($hostOutput, ("(?m)^FLOOR_CLEARED floor=(\d+) players=$Players\r?$")) | ForEach-Object { [int]$_.Groups[1].Value })
    if ([regex]::Matches($hostOutput, '(?im)^ROOM_STARTED room=3\b[^\r\n]*\bboss=true\r?$').Count -ne 2 -or
        ($clearedFloors -join ',') -ne '1,2') {
        throw "The host did not clear both three-room floors ending in bosses. Logs: $logRoot"
    }
    $perks = [regex]::Matches($hostOutput, '(?m)^PERK_SELECTED peer=(\d+) room=(\d+) perk=(\S+) floor=(\d+)\r?$')
    $perkKeys = @($perks | ForEach-Object { '{0}:{1}:{2}' -f $_.Groups[4].Value, $_.Groups[1].Value, $_.Groups[2].Value })
    $rewardRooms = @($perks | ForEach-Object { '{0}:{1}' -f $_.Groups[4].Value, $_.Groups[2].Value } | Sort-Object -Unique)
    if ($perks.Count -ne 6 * $Players -or ($rewardRooms -join ',') -ne '1:1,1:2,1:3,2:1,2:2,2:3' -or
        @($perkKeys | Sort-Object -Unique).Count -ne $perkKeys.Count) {
        throw "Each of the six cleared rooms must grant one perk per member without duplicate floor/peer/room grants. Logs: $logRoot"
    }
    $hostLayouts = @(Get-RoomLayouts -OutputText $hostOutput -ProcessName 'Host')
    if (@($hostLayouts.Id | Sort-Object -Unique).Count -ne 6) {
        throw "The dungeon reused a stable room ID within the run. Logs: $logRoot"
    }
    foreach ($entry in $owned) {
        $layouts = @(Get-RoomLayouts -OutputText (Get-ProcessOutput -Entry $entry) -ProcessName $entry.Name)
        for ($index = 0; $index -lt 6; $index++) {
            $expected = $hostLayouts[$index]
            $actual = $layouts[$index]
            if ($expected.Version -ne 4 -or $actual.Version -ne 4 -or
                $expected.Id -cne $actual.Id -or $expected.Template -cne $actual.Template -or
                $expected.Signature -cne $actual.Signature) {
                throw "Host/$($entry.Name) layout $($index + 1) identity, template, version or hash differs. Logs: $logRoot"
            }
        }
    }
    Write-Host "PASS: $Players real peers completed two floors, six matching layouts, personal rewards and free exploration."
    Write-Host 'Coverage: localhost bot gameplay and layout replication; LAN/WAN and performance remain unverified.'
    [pscustomobject]@{
        Result = 'PASS'
        Players = $Players
        Seed = $Seed
        FloorsCleared = 2
        RoomsCleared = 6
        PerksSelected = $perks.Count
        Layouts = $hostLayouts
        ElapsedSeconds = [Math]::Round($timer.Elapsed.TotalSeconds, 1)
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
        finally { $entry.Process.Dispose() }
    }
    $timer.Stop()
}
