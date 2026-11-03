[CmdletBinding()]
param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$guardianRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $GodotPath) { $GodotPath = Join-Path $guardianRoot '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' }
$probe = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
try { $guardianPort = ([Net.IPEndPoint]$probe.Client.LocalEndPoint).Port } finally { $probe.Dispose() }
$guardianLogs = Join-Path $guardianRoot ('Logs/guardian-commands/' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$null = New-Item -ItemType Directory -Path $guardianLogs
$guardianOwned = [Collections.Generic.List[object]]::new()
try {
    foreach ($role in @('host', 'client')) {
        $stdout = Join-Path $guardianLogs "$role.stdout.log"
        $stderr = Join-Path $guardianLogs "$role.stderr.log"
        $result = Join-Path $guardianLogs "$role.json"
        $arguments = @('--headless', '--max-fps', '120', '--log-file', ('"' + (Join-Path $guardianLogs "$role.engine.log") + '"'), '--path', ('"' + $guardianRoot + '"'), '--script', 'res://tests/guardian_commands_network_peer.gd', '--', '--guardian-port', "$guardianPort", '--guardian-result', ('"' + $result + '"'))
        if ($role -eq 'host') { $arguments += '--guardian-host' }
        $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $guardianRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null = $process.Handle
        $guardianOwned.Add([pscustomobject]@{ Role=$role; Process=$process; Stdout=$stdout; Stderr=$stderr; Result=$result })
        if ($role -eq 'host') {
            $deadline = [DateTime]::UtcNow.AddSeconds(60)
            do {
                Start-Sleep -Milliseconds 100
                $process.Refresh()
                if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw "Guardian host did not start; logs=$guardianLogs" }
            } until ((Get-Content -LiteralPath $stdout -Raw) -match 'SESSION_HOSTED')
        }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(75)
    do {
        $running = @($guardianOwned | Where-Object { $_.Process.Refresh(); -not $_.Process.HasExited })
        if ($running.Count -eq 0) { break }
        if ([DateTime]::UtcNow -gt $deadline) { throw "Guardian peers timed out; logs=$guardianLogs" }
        Start-Sleep -Milliseconds 100
    } while ($true)
    $results = @()
    foreach ($entry in $guardianOwned) {
        $entry.Process.WaitForExit()
        $output = (Get-Content -LiteralPath $entry.Stdout -Raw) + (Get-Content -LiteralPath $entry.Stderr -Raw)
        if ($entry.Process.ExitCode -ne 0 -or $output -match '(?im)^\s*(SCRIPT ERROR|GUARDIAN_NET_FAIL)' -or -not (Test-Path -LiteralPath $entry.Result)) { throw "Guardian $($entry.Role) failed; logs=$guardianLogs`n$output" }
        $unexpected = ($output -split "`n" | Where-Object { $_ -match '^ERROR:' -and $_ -notmatch '^ERROR: \d+ resources still in use at exit' })
        if ($unexpected) { throw "Guardian engine errors; logs=$guardianLogs`n$unexpected" }
        $data = Get-Content -LiteralPath $entry.Result -Raw | ConvertFrom-Json
        if (-not $data.passed) { throw "Guardian assertions failed; logs=$guardianLogs" }
        $results += $data
    }
    [pscustomobject]@{ passed=$true; scope='local loopback, not LAN/WAN/performance'; results=$results } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $guardianLogs 'summary.json') -Encoding utf8
    Write-Output "SOUL_GUARDIAN_NETWORK passed=2 failed=0 logs=$guardianLogs"
} finally {
    foreach ($entry in $guardianOwned) {
        $entry.Process.Refresh()
        if (-not $entry.Process.HasExited) { Stop-Process -Id $entry.Process.Id -Force -ErrorAction SilentlyContinue }
        $entry.Process.Dispose()
    }
}
