<#
.SYNOPSIS
Plays the current ten-room crypt through real local Godot peers.
.DESCRIPTION
Normal authoritative input and actual reward-button signals clear ten rooms,
backtrack without a second reward, defeat the room10 boss and use the stairs.
The restart scenario instead waits for ordinary enemy damage/team wipe and
uses the ordinary host menu restart. No entity/stat/phase cheats are applied.
Headless runs prove functionality and replication, never GPU FPS or real LAN.
#>
[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [ValidateSet(1, 2, 4)][int]$Players = 1,
    [ValidateSet('campaign', 'restart', 'restart_after_reward')][string]$Scenario = 'campaign',
    [ValidateRange(0, 65535)][int]$Port = 0,
    [ValidateRange(1, 2147483647)][int]$Seed = 42026,
    [ValidateRange(30, 1800)][int]$RunSeconds = 900,
    [string[]]$ClientPorts = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = Join-Path $projectRoot '..\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe'
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
if ($Port -gt 0 -and $Port -lt 1024) { throw 'Use an unprivileged port or0.' }
if ($ClientPorts.Count -ne 0 -and $ClientPorts.Count -ne $Players-1) { throw 'ClientPorts must contain one local proxy port per client.' }
$config = Get-Content -LiteralPath (Join-Path $projectRoot 'assets\data\dungeon_rooms.json') -Raw | ConvertFrom-Json
if ($config.tile_size -ne 32 -or $config.generator_version -ne 4 -or $config.campaign_room_count -ne 10) {
    throw 'The active configuration must be the current32px ten-room campaign.'
}
if ($Port -eq 0) {
    $probe = [System.Net.Sockets.UdpClient]::new(0)
    try { $Port = ([System.Net.IPEndPoint]$probe.Client.LocalEndPoint).Port }
    finally { $probe.Dispose() }
}
$runName = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0,8))
$logRoot = Join-Path $projectRoot "Logs\ten-room-campaign\$runName"
$null = New-Item -ItemType Directory -Path $logRoot -Force
$owned = [System.Collections.Generic.List[object]]::new()
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$resultPath = Join-Path $logRoot 'result.json'
$run = [ordered]@{ Result='RUNNING'; Players=$Players; Scenario=$Scenario; Seed=$Seed; Port=$Port; ClientPorts=$ClientPorts; Scope='Independent localhost processes; not real LAN or GPU performance'; Started=(Get-Date).ToString('o'); Logs=$logRoot; DungeonSHA256=(Get-FileHash -LiteralPath (Join-Path $projectRoot 'assets\data\dungeon_rooms.json') -Algorithm SHA256).Hash }
$run | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding utf8

function Read-Output {
    param([object]$Entry)
    $chunks = foreach ($path in @($Entry.Stdout,$Entry.Stderr)) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $reader = $null
        $stream = $null
        try {
            $stream = [System.IO.FileStream]::new($path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
            $reader = [System.IO.StreamReader]::new($stream)
            $reader.ReadToEnd()
        }
        finally {
            if ($null -ne $reader) { $reader.Dispose() }
            elseif ($null -ne $stream) { $stream.Dispose() }
        }
    }
    $chunks -join "`n"
}

function Start-Peer {
    param([string]$Name,[string]$Role,[int]$ConnectPort)
    $stdout = Join-Path $logRoot "$Name.stdout.log"
    $stderr = Join-Path $logRoot "$Name.stderr.log"
    $report = Join-Path $logRoot "$Name.json"
    $nativeArguments = @('--headless','--max-fps','120','--path',('"'+$projectRoot+'"'),'--script','res://tests/ten_room_campaign_peer.gd','--','--campaign-role',$Role,'--campaign-port',"$ConnectPort",'--campaign-players',"$Players",'--campaign-seed',"$Seed",'--campaign-scenario',$Scenario,'--campaign-seconds',"$RunSeconds",'--campaign-report',('"'+$report+'"'))
    $process = Start-Process -FilePath $GodotPath -ArgumentList $nativeArguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $process.Handle
    $entry = [pscustomobject]@{ Name=$Name; Process=$process; Stdout=$stdout; Stderr=$stderr; Report=$report }
    $owned.Add($entry)
    $entry
}

function Assert-Errors {
    foreach ($entry in $owned) {
        $output = Read-Output $entry
        if ($output -match '(?im)^\s*(?:SCRIPT ERROR|ERROR|Parse Error|Parser Error|CAMPAIGN_FAIL)\b') { throw "$($entry.Name) reported an error. Logs: $logRoot" }
        $entry.Process.Refresh()
        if ($entry.Process.HasExited -and $entry.Process.ExitCode -ne 0) { throw "$($entry.Name) exited with$($entry.Process.ExitCode). Logs: $logRoot" }
    }
}

try {
    Write-Host "TEN_ROOM_START players=$Players scenario=$Scenario seed=$Seed port=$Port logs=$logRoot"
    $hostEntry = Start-Peer 'host' 'host' $Port
    $startupDeadline = $timer.Elapsed.TotalSeconds+20
    while ((Read-Output $hostEntry) -notmatch '(?m)^SESSION_HOSTED\b') {
        Assert-Errors
        if ($timer.Elapsed.TotalSeconds -gt $startupDeadline) { throw 'Host startup timed out.' }
        Start-Sleep -Milliseconds 100
    }
    for ($index=1; $index -lt $Players; $index++) {
        $connectPort = if ($ClientPorts.Count -gt 0) { [int]$ClientPorts[$index-1] } else { $Port }
        $null = Start-Peer "client-$index" 'client' $connectPort
    }
    $lastProgress = -10
    while (@($owned | Where-Object { $_.Process.Refresh(); -not $_.Process.HasExited }).Count -gt 0) {
        Assert-Errors
        if ($timer.Elapsed.TotalSeconds -gt $RunSeconds+30) { throw 'Campaign processes exceeded their deadline.' }
        if ($timer.Elapsed.TotalSeconds-$lastProgress -ge 10) {
            $lastProgress = $timer.Elapsed.TotalSeconds
            $progress = [regex]::Matches((Read-Output $hostEntry),'(?m)^CAMPAIGN_PROGRESS[^\r\n]*')
            if ($progress.Count -gt 0) { Write-Host $progress[$progress.Count-1].Value }
        }
        Start-Sleep -Milliseconds 200
    }
    Assert-Errors
    $reports = @()
    foreach ($entry in $owned) {
        $entry.Process.WaitForExit()
        if (-not (Test-Path -LiteralPath $entry.Report)) { throw "$($entry.Name) produced no report." }
        $report = Get-Content -LiteralPath $entry.Report -Raw | ConvertFrom-Json
        if ($report.result -ne 'PASS') { throw "$($entry.Name) did not pass." }
        $reports += $report
    }
    if ($Scenario -eq 'campaign') {
        $expectedLayouts = @($reports[0].layouts)
        foreach ($report in $reports) {
            $actualLayouts = @($report.layouts)
            if ($actualLayouts.Count -ne 11) { throw 'Expected ten first-floor rooms and next-floor room1.' }
            for ($index=0; $index -lt 11; $index++) {
                if ($actualLayouts[$index].id -cne $expectedLayouts[$index].id -or $actualLayouts[$index].template -cne $expectedLayouts[$index].template -or $actualLayouts[$index].signature -cne $expectedLayouts[$index].signature) {
                    throw "Replicated layout mismatch for$($report.role) at$index."
                }
            }
        }
        $perks = [regex]::Matches((Read-Output $hostEntry),'(?m)^PERK_SELECTED peer=(\d+) room=(\d+) perk=(\S+) floor=1\r?$')
        $expectedGrants = [int](($reports | Measure-Object -Property expected_reward_grants -Sum).Sum)
        if ($perks.Count -ne $expectedGrants) { throw "Expected$expectedGrants first-floor living-player perk grants; found$($perks.Count)." }
        $grantKeys = @($perks | ForEach-Object { "$($_.Groups[1].Value):$($_.Groups[2].Value)" })
        if (@($grantKeys | Sort-Object -Unique).Count -ne $grantKeys.Count) { throw 'A revisited room granted a duplicate perk.' }
        $hostOutput = Read-Output $hostEntry
        if ([regex]::Matches($hostOutput,'(?m)^ROOM_STARTED room=10[^\r\n]*boss=true\r?$').Count -ne 1) { throw 'Room10 did not contain exactly one boss encounter.' }
    }
    $run.Result = 'PASS'
    $run.Reports = $reports
    Write-Host "TEN_ROOM_PASS players=$Players scenario=$Scenario logs=$logRoot"
}
catch {
    $run.Result = 'FAIL'
    $run.Error = $_.Exception.Message
    throw
}
finally {
    foreach ($entry in $owned) {
        try {
            $entry.Process.Refresh()
            if (-not $entry.Process.HasExited) {
                Stop-Process -InputObject $entry.Process -Force -ErrorAction SilentlyContinue
                $null = $entry.Process.WaitForExit(1000)
            }
        }
        finally { $entry.Process.Dispose() }
    }
    $run.ElapsedSeconds = [Math]::Round($timer.Elapsed.TotalSeconds,3)
    $run | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resultPath -Encoding utf8
    $timer.Stop()
}
