[CmdletBinding()]
param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$ringRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $GodotPath) { $GodotPath = Join-Path $ringRoot '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' }
$probe = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
try { $ringPort = ([Net.IPEndPoint]$probe.Client.LocalEndPoint).Port } finally { $probe.Dispose() }
$ringLogs = Join-Path $ringRoot ('Logs/soul-ring/' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$null = New-Item -ItemType Directory -Path $ringLogs
$ringOwned = [Collections.Generic.List[object]]::new()
try {
    foreach ($role in @('host', 'client')) {
        $stdout = Join-Path $ringLogs "$role.stdout.log"
        $stderr = Join-Path $ringLogs "$role.stderr.log"
        $result = Join-Path $ringLogs "$role.json"
        $arguments = @('--headless', '--max-fps', '120', '--log-file', ('"' + (Join-Path $ringLogs "$role.engine.log") + '"'), '--path', ('"' + $ringRoot + '"'), '--script', 'res://tests/soul_ring_network_peer.gd', '--', '--ring-port', "$ringPort", '--ring-result', ('"' + $result + '"'))
        if ($role -eq 'host') { $arguments += '--ring-host' }
        $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $ringRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null = $process.Handle
        $ringOwned.Add([pscustomobject]@{ Role=$role; Process=$process; Stdout=$stdout; Stderr=$stderr; Result=$result })
        if ($role -eq 'host') {
            $deadline = [DateTime]::UtcNow.AddSeconds(30)
            do {
                Start-Sleep -Milliseconds 100
                $process.Refresh()
                if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw "Ring host did not start; logs=$ringLogs" }
            } until ((Get-Content -LiteralPath $stdout -Raw) -match 'SESSION_HOSTED')
        }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(75)
    do {
        $running = @($ringOwned | Where-Object { $_.Process.Refresh(); -not $_.Process.HasExited })
        if ($running.Count -eq 0) { break }
        if ([DateTime]::UtcNow -gt $deadline) { throw "Ring peers timed out; logs=$ringLogs" }
        Start-Sleep -Milliseconds 100
    } while ($true)
    $results = @()
    foreach ($entry in $ringOwned) {
        $entry.Process.WaitForExit()
        $output = (Get-Content -LiteralPath $entry.Stdout -Raw) + (Get-Content -LiteralPath $entry.Stderr -Raw)
        if ($entry.Process.ExitCode -ne 0 -or $output -match '(?im)^\s*(SCRIPT ERROR|RING_NET_FAIL)' -or -not (Test-Path -LiteralPath $entry.Result)) { throw "Ring $($entry.Role) failed; logs=$ringLogs`n$output" }
        $unexpected = ($output -split "`n" | Where-Object { $_ -match '^ERROR:' -and $_ -notmatch '^ERROR: \d+ resources still in use at exit' })
        if ($unexpected) { throw "Ring engine errors; logs=$ringLogs`n$unexpected" }
        $data = Get-Content -LiteralPath $entry.Result -Raw | ConvertFrom-Json
        if (-not $data.passed) { throw "Ring assertions failed; logs=$ringLogs" }
        $results += $data
    }
    [pscustomobject]@{ passed=$true; scope='local loopback, not LAN/WAN/performance'; results=$results } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $ringLogs 'summary.json') -Encoding utf8
    Write-Output "SOUL_RING_NETWORK passed=2 failed=0 logs=$ringLogs"
} finally {
    foreach ($entry in $ringOwned) {
        $entry.Process.Refresh()
        if (-not $entry.Process.HasExited) { Stop-Process -Id $entry.Process.Id -Force -ErrorAction SilentlyContinue }
        $entry.Process.Dispose()
    }
}
