param([string]$GodotPath = '', [int]$Port = 0)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = Join-Path (Split-Path -Parent $repoRoot) 'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' }
if ($Port -eq 0) {
    $probe = [System.Net.Sockets.UdpClient]::new([System.Net.IPEndPoint]::new([System.Net.IPAddress]::Loopback,0))
    $Port = $probe.Client.LocalEndPoint.Port
    $probe.Dispose()
}
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
$logRoot = Join-Path $repoRoot "Logs/session-protocol/$runId"
[void](New-Item -ItemType Directory -Path $logRoot -Force)
$owned = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

function Start-ProtocolPeer([string]$Mode) {
    $outPath = Join-Path $logRoot "$Mode.stdout.log"
    $errPath = Join-Path $logRoot "$Mode.stderr.log"
    $resultPath = Join-Path $logRoot "$Mode.json"
    $arguments = @('--headless','--max-fps','120','--path',('"'+$repoRoot+'"'),'--script','res://tests/session_protocol_peer.gd','--','--protocol-mode',$Mode,'--protocol-port',$Port,'--protocol-result',('"'+$resultPath+'"'))
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $outPath -RedirectStandardError $errPath -PassThru
    $owned.Add($process)
    return $process
}

function Wait-ProtocolPeer([System.Diagnostics.Process]$Process,[string]$Mode) {
    if (-not $Process.WaitForExit(30000)) { throw "$Mode peer timed out" }
    $Process.Refresh()
    $result = Get-Content -LiteralPath (Join-Path $logRoot "$Mode.json") -Raw | ConvertFrom-Json
    $errors = Get-Content -LiteralPath (Join-Path $logRoot "$Mode.stderr.log") -Raw
    if ($Process.ExitCode -ne 0 -or -not $result.passed -or $errors -match 'SCRIPT ERROR|Parse Error|ERROR:') { throw "$Mode peer failed: $errors" }
    return $result
}

try {
    $hostProcess = Start-ProtocolPeer 'host'
    $readyDeadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 100
        $hostOutput = Get-Content -LiteralPath (Join-Path $logRoot 'host.stdout.log') -Raw -ErrorAction SilentlyContinue
    } while ($hostOutput -notmatch 'SESSION_HOSTED' -and [DateTime]::UtcNow -lt $readyDeadline -and -not $hostProcess.HasExited)
    if ($hostOutput -notmatch 'SESSION_HOSTED') { throw 'Host did not become ready' }
    $validProcess = Start-ProtocolPeer 'valid'
    $protocolProcess = Start-ProtocolPeer 'protocol'
    $contentProcess = Start-ProtocolPeer 'content'
    $results = @()
    $results += Wait-ProtocolPeer $validProcess 'valid'
    $results += Wait-ProtocolPeer $protocolProcess 'protocol'
    $results += Wait-ProtocolPeer $contentProcess 'content'
    $malformedProcess = Start-ProtocolPeer 'malformed'
    $results += Wait-ProtocolPeer $malformedProcess 'malformed'
    $silentProcess = Start-ProtocolPeer 'silent'
    $results += Wait-ProtocolPeer $silentProcess 'silent'
    $results += Wait-ProtocolPeer $hostProcess 'host'
    [pscustomobject]@{passed=$true;port=$Port;results=$results;log_root=$logRoot} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logRoot 'summary.json') -Encoding utf8
    Write-Output "SESSION_PROTOCOL_SMOKE passed=6 failed=0 logs=$logRoot"
} finally {
    foreach ($process in $owned) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
        $process.Dispose()
    }
}
