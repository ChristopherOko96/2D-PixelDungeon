[CmdletBinding()]
param([string]$GodotPath = '', [switch]$RewardCards)
$ErrorActionPreference = 'Stop'
$pauseProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $GodotPath) { $GodotPath = Join-Path $pauseProjectRoot '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' }
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$probe = [Net.Sockets.UdpClient]::new(0)
try { $port = ([Net.IPEndPoint]$probe.Client.LocalEndPoint).Port } finally { $probe.Dispose() }
$run = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0,8))
$kind = if ($RewardCards) { 'reward' } else { 'pause' }
$peerScript = if ($RewardCards) { 'res://tests/reward_network_peer.gd' } else { 'res://tests/pause_network_peer.gd' }
$marker = if ($RewardCards) { 'REWARD_PEER' } else { 'PAUSE_PEER' }
$logs = Join-Path $pauseProjectRoot ("Logs/$kind-network-smoke/" + $run)
$null = New-Item -ItemType Directory -Path $logs
$owned = [Collections.Generic.List[object]]::new()
try {
    foreach ($role in @('host','client')) {
        $stdout = Join-Path $logs "$role.stdout.log"
        $stderr = Join-Path $logs "$role.stderr.log"
        $arguments = @('--headless','--path',('"'+$pauseProjectRoot+'"'),'--script',$peerScript,'--','--test-port',"$port")
        if ($role -eq 'host') { $arguments += '--test-host' }
        $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null = $process.Handle
        $owned.Add([pscustomobject]@{ Role=$role; Process=$process; Stdout=$stdout; Stderr=$stderr })
        if ($role -eq 'host') {
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            do {
                Start-Sleep -Milliseconds 100
                $text = if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw } else { '' }
                if ([DateTime]::UtcNow -gt $deadline -or $process.HasExited) { throw "Pause host did not start. Logs: $logs" }
            } until ($text -match 'SESSION_HOSTED')
        }
    }
    foreach ($entry in $owned) {
        if (-not $entry.Process.WaitForExit(20000)) { throw "Pause peer timed out. Logs: $logs" }
        $entry.Process.WaitForExit()
        $entry.Process.Refresh()
        $output = (Get-Content -LiteralPath $entry.Stdout -Raw) + (Get-Content -LiteralPath $entry.Stderr -Raw)
        if ($entry.Process.ExitCode -ne 0 -or $output -match '(?im)^\s*(SCRIPT ERROR|ERROR:|PAUSE_NET_FAIL:|REWARD_NET_FAIL:)' -or $output -notmatch ($marker+'[^\r\n]*result=PASS')) {
            throw "Pause peer $($entry.Role) failed. Logs: $logs`n$output"
        }
    }
    if ($RewardCards) { Write-Output "PASS: real host and client chose reward cards, received authoritative perks and returned to room-one exploration. Logs: $logs" }
    else { Write-Output "PASS: real host and client opened local menus; world, snapshots and neutral input continued. Logs: $logs" }
}
finally {
    foreach ($entry in $owned) {
        $entry.Process.Refresh()
        if (-not $entry.Process.HasExited) { $entry.Process.Kill(); $null = $entry.Process.WaitForExit(1000) }
        $entry.Process.Dispose()
    }
}
