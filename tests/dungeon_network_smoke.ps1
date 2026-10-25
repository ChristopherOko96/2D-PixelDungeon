<#
.SYNOPSIS
Proves a seeded Isaac-style dungeon floor with two independent local Godot peers.
.DESCRIPTION
The existing smoke bots play combat through ordinary host-authoritative inputs and
walk through open doors toward the boss (or the nearest unvisited room while the
boss is unseen). This script never grants damage, clears enemies, or changes the
game state. It requires every entered combat room to be cleared, a door travel
into each room after the start, the boss clear with both peers' perks, victory on
both processes, and matching room identities, templates and layout hashes.
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
    [ValidateRange(30, 240)]
    [int]$RunSeconds = 120
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

function Get-Rooms {
    param([string]$OutputText, [string]$Pattern)
    return @([regex]::Matches($OutputText, $Pattern) | ForEach-Object { [int]$_.Groups[1].Value })
}

function Get-RoomLayouts {
    param([string]$OutputText, [string]$ProcessName)
    $lines = [regex]::Matches($OutputText, '(?m)^ROOM_LAYOUT[^\r\n]*\r?$')
    $matchesForLayout = [regex]::Matches($OutputText, '(?m)^ROOM_LAYOUT id=(\S+) template=(\S+) version=(\d+) signature=([a-fA-F0-9]{64})\r?$')
    if ($lines.Count -lt 2 -or $matchesForLayout.Count -ne $lines.Count) {
        throw "$ProcessName must report at least two valid ROOM_LAYOUT lines; found $($lines.Count) lines and $($matchesForLayout.Count) valid hashes. Logs: $logRoot"
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
    # Act: two real processes use the same requested seed and ordinary bot inputs.
    Write-Host "Starting seeded dungeon check: host + client, seed $Seed, UDP $Port."
    $hostArguments = @('--host', '--seed', "$Seed", '--smoke-role', 'host', '--auto-start', '--port', "$Port", '--auto-exit', "$RunSeconds")
    $clientSeconds = $RunSeconds - 3
    $clientArguments = @('--join', '127.0.0.1', '--seed', "$Seed", '--smoke-role', 'client', '--port', "$Port", '--auto-exit', "$clientSeconds")
    $hostEntry = Start-DungeonProcess -Name 'host' -GameArguments $hostArguments
    Wait-ForMarker -Entry $hostEntry -Pattern '(?m)^SESSION_HOSTED\b'
    $clientEntry = Start-DungeonProcess -Name 'client' -GameArguments $clientArguments
    Wait-ForMarker -Entry $clientEntry -Pattern '(?m)^CLIENT_CONNECTED\b'
    Wait-ForMarker -Entry $hostEntry -Pattern '(?m)^PEER_JOINED[^\r\n]*count=2\r?$'
    Wait-ForMarker -Entry $hostEntry -Pattern ("(?m)^RUN_STARTED seed=$Seed players=2 rooms=\d+\r?$")
    Wait-ForMarker -Entry $clientEntry -Pattern '(?m)^SNAPSHOT_RECEIVED phase=explore players=2 room=1\r?$'
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
    $clientOutput = Get-ProcessOutput -Entry $clientEntry
    $runStart = [regex]::Match($hostOutput, "(?m)^RUN_STARTED seed=$Seed players=2 rooms=(\d+)\r?$")
    $roomCount = if ($runStart.Success) { [int]$runStart.Groups[1].Value } else { 0 }
    if ($roomCount -lt 6 -or $roomCount -gt 10) {
        throw "The host must start one 6-10 room floor; found '$($runStart.Value)'. Logs: $logRoot"
    }
    $combatRooms = @(Get-Rooms $hostOutput '(?m)^ROOM_STARTED room=(\d+) kind=(?:normal|boss) enemies=[1-9]\d* boss=\w+\r?$' | Sort-Object -Unique)
    $clearedRooms = @(Get-Rooms $hostOutput '(?m)^ROOM_CLEARED room=(\d+) phase=(?:explore|reward)\r?$' | Sort-Object -Unique)
    $uncleared = @($combatRooms | Where-Object { $clearedRooms -notcontains $_ })
    if ($combatRooms.Count -lt 1 -or $uncleared.Count -gt 0) {
        throw "Every entered combat room must be cleared by real combat; uncleared: '$($uncleared -join ',')'. Logs: $logRoot"
    }
    $bossRooms = @(Get-Rooms $hostOutput '(?m)^ROOM_STARTED room=(\d+) kind=boss enemies=1 boss=true\r?$' | Sort-Object -Unique)
    if ($bossRooms.Count -ne 1 -or $clearedRooms -notcontains $bossRooms[0] -or
        [regex]::Matches($hostOutput, '(?m)^RUN_COMPLETED players=2 rooms_cleared=\d+\r?$').Count -ne 1) {
        throw "The host did not complete exactly one two-player run through the boss room. Logs: $logRoot"
    }
    # Every room after the start is reached through a door, never by a scripted jump.
    $travels = [regex]::Matches($hostOutput, '(?m)^ROOM_TRAVEL from=(\d+) to=(\d+) side=(?:north|east|south|west)\r?$')
    $entered = @(Get-Rooms $hostOutput '(?m)^ROOM_STARTED room=(\d+)\b[^\r\n]*\r?$')
    if ($travels.Count -lt 1 -or $entered.Count -ne $travels.Count + 1) {
        throw "Every room after the start must be entered through a door; travels $($travels.Count), rooms entered $($entered.Count). Logs: $logRoot"
    }
    for ($index = 0; $index -lt $travels.Count; $index++) {
        if ([int]$travels[$index].Groups[2].Value -ne $entered[$index + 1]) {
            throw "Door travel $($index + 1) did not lead into the next started room. Logs: $logRoot"
        }
    }
    foreach ($entry in $owned) {
        $output = Get-ProcessOutput -Entry $entry
        if ($output -notmatch '(?m)^SNAPSHOT_RECEIVED phase=victory players=2 room=\d+\r?$' -or
            $output -notmatch '(?m)^AUTO_EXIT phase=victory PLAYER_COUNT=\d+\r?$') {
            throw "$($entry.Name) did not receive and retain the final victory. Logs: $logRoot"
        }
    }
    $perks = [regex]::Matches($hostOutput, '(?m)^PERK_SELECTED peer=(\d+) room=(\d+) perk=(\S+)\r?$')
    $perkKeys = @($perks | ForEach-Object { '{0}:{1}' -f $_.Groups[1].Value, $_.Groups[2].Value })
    $treasureRooms = @(Get-Rooms $hostOutput '(?m)^ROOM_STARTED room=(\d+) kind=treasure\b[^\r\n]*\r?$')
    $perkRooms = @($perks | ForEach-Object { [int]$_.Groups[2].Value } | Sort-Object -Unique)
    $outsideRewards = @($perkRooms | Where-Object { $_ -ne $bossRooms[0] -and $treasureRooms -notcontains $_ })
    $bossPerks = @($perks | Where-Object { [int]$_.Groups[2].Value -eq $bossRooms[0] })
    if ($outsideRewards.Count -gt 0 -or $bossPerks.Count -ne 2 -or @($perkKeys | Sort-Object -Unique).Count -ne $perkKeys.Count) {
        throw "Perks must come only from treasure and boss rooms, once per peer, with both peers choosing after the boss. Logs: $logRoot"
    }
    $hostLayouts = @(Get-RoomLayouts -OutputText $hostOutput -ProcessName 'Host')
    $clientLayouts = @(Get-RoomLayouts -OutputText $clientOutput -ProcessName 'Client')
    if ($hostLayouts.Count -ne $clientLayouts.Count) {
        throw "Host saw $($hostLayouts.Count) room layouts, client $($clientLayouts.Count). Logs: $logRoot"
    }
    for ($index = 0; $index -lt $hostLayouts.Count; $index++) {
        $expected = $hostLayouts[$index]
        $actual = $clientLayouts[$index]
        if ($expected.Version -ne 2 -or $actual.Version -ne 2 -or
            $expected.Id -cne $actual.Id -or $expected.Template -cne $actual.Template -or
            $expected.Signature -cne $actual.Signature) {
            throw "Host/client room $($index + 1) identity, template, generator version or layout hash differs. Logs: $logRoot"
        }
    }
    Write-Host "PASS: two real peers walked a $roomCount-room floor through $($travels.Count) doors, cleared $($combatRooms.Count) combat rooms including the boss, with matching layouts."
    Write-Host 'Coverage: localhost bot gameplay and layout replication; LAN/WAN and performance remain unverified.'
    [pscustomobject]@{
        Result = 'PASS'
        Players = 2
        Seed = $Seed
        RoomCount = $roomCount
        DoorsUsed = $travels.Count
        RoomsCleared = $combatRooms.Count
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
