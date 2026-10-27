[CmdletBinding()]
param([string]$GodotPath = '')
$ErrorActionPreference = 'Stop'
$cryptProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $GodotPath) { $GodotPath = Join-Path $cryptProjectRoot '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' }
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$probe = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback,0))
try { $port = ([Net.IPEndPoint]$probe.Client.LocalEndPoint).Port } finally { $probe.Dispose() }
$run = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([guid]::NewGuid().ToString('N').Substring(0,8))
$logs = Join-Path $cryptProjectRoot ('Logs/crypt-enemy-network/' + $run)
$null = New-Item -ItemType Directory -Path $logs
$owned = [Collections.Generic.List[object]]::new()

function Read-CryptOutput([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $stream = [IO.FileStream]::new($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $reader = [IO.StreamReader]::new($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

try {
    foreach ($role in @('host','client')) {
        $stdout = Join-Path $logs "$role.stdout.log"
        $stderr = Join-Path $logs "$role.stderr.log"
        $resultPath = Join-Path $logs "$role.json"
        $arguments = @('--headless','--max-fps','120','--path',('"'+$cryptProjectRoot+'"'),'--script','res://tests/crypt_enemy_network_peer.gd','--','--crypt-port',"$port",'--crypt-result',('"'+$resultPath+'"'))
        if ($role -eq 'host') { $arguments += '--crypt-host' }
        $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $cryptProjectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null = $process.Handle
        $owned.Add([pscustomobject]@{ Role=$role; Process=$process; Stdout=$stdout; Stderr=$stderr; Result=$resultPath })
        if ($role -eq 'host') {
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            do {
                Start-Sleep -Milliseconds 100
                $output = Read-CryptOutput $stdout
                $process.Refresh()
                if ($process.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw "Crypt host did not start: $output $(Read-CryptOutput $stderr)" }
            } until ($output -match 'SESSION_HOSTED')
        }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $running = @($owned | Where-Object { $_.Process.Refresh(); -not $_.Process.HasExited })
        if ($running.Count -eq 0) { break }
        if ([DateTime]::UtcNow -gt $deadline) { throw "Crypt peers timed out. Logs: $logs" }
        Start-Sleep -Milliseconds 100
    } while ($true)
    $results = @()
    foreach ($entry in $owned) {
        $entry.Process.WaitForExit()
        $entry.Process.Refresh()
        $output = (Read-CryptOutput $entry.Stdout) + (Read-CryptOutput $entry.Stderr)
        if ($entry.Process.ExitCode -ne 0 -or $output -match '(?im)^\s*(SCRIPT ERROR|ERROR:|CRYPT_NET_FAIL:)' -or -not (Test-Path -LiteralPath $entry.Result)) { throw "Crypt $($entry.Role) failed. Logs: $logs`n$output" }
        $result = Get-Content -LiteralPath $entry.Result -Raw | ConvertFrom-Json
        if (-not $result.passed -or -not $result.observed) { throw "Crypt $($entry.Role) rejected its assertions. Logs: $logs" }
        $results += $result
    }
    [pscustomobject]@{ passed=$true; scope='controlled two-process loopback enemy replication fixture; not played campaign/LAN/performance'; results=$results } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logs 'summary.json') -Encoding utf8
    Write-Output "CRYPT_NETWORK passed=2 failed=0 logs=$logs"
} finally {
    foreach ($entry in $owned) {
        $entry.Process.Refresh()
        if (-not $entry.Process.HasExited) { Stop-Process -Id $entry.Process.Id -Force -ErrorAction SilentlyContinue }
        $entry.Process.Dispose()
    }
}
