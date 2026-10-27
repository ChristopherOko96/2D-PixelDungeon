<#
.SYNOPSIS
Plays real local peers through per-client UDP delay/loss fixtures.
.DESCRIPTION
No OS/firewall/router settings are changed. Each loopback proxy adds at least
50ms each way and independently drops1% of UDP datagrams by default. This is
not a two-computer LAN/WAN proof. Processes and stop markers are isolated.
#>
[CmdletBinding()]
param(
    [ValidateSet(2,4)][int]$Players = 4,
    [string]$PythonPath = 'python',
    [string]$GodotPath = '',
    [ValidateRange(30,1800)][int]$RunSeconds = 900,
    [int]$Seed = 42026,
    [ValidateRange(0,5000)][double]$OneWayDelayMs = 50,
    [ValidateRange(0,0.5)][double]$Loss = 0.01
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$python = (Get-Command $PythonPath -ErrorAction Stop).Source
$name = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'),([guid]::NewGuid().ToString('N').Substring(0,8))
$logRoot = Join-Path $projectRoot "Logs\impaired-campaign\$name"
$null = New-Item -ItemType Directory -Path $logRoot -Force
$owned = [System.Collections.Generic.List[object]]::new()
$leases = [System.Collections.Generic.List[object]]::new()
$ports = [System.Collections.Generic.List[int]]::new()
try {
    for ($index=0; $index -lt $Players; $index++) {
        $lease = [System.Net.Sockets.UdpClient]::new(0)
        $leases.Add($lease)
        $ports.Add(([System.Net.IPEndPoint]$lease.Client.LocalEndPoint).Port)
    }
}
finally { foreach ($lease in $leases) { $lease.Dispose() } }
$result = [ordered]@{
    Result='RUNNING'; Scope='Local UDP impairment; not real LAN/WAN'; Players=$Players
    OneWayDelayMs=$OneWayDelayMs; NominalRttMs=$OneWayDelayMs*2; Loss=$Loss
    HostPort=$ports[0]; Logs=$logRoot; ProxyStats=@(); Error=''
}
$resultPath = Join-Path $logRoot 'result.json'
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding utf8
try {
    for ($index=1; $index -lt $Players; $index++) {
        $stop = Join-Path $logRoot "proxy-$index.stop"
        $stats = Join-Path $logRoot "proxy-$index.json"
        $stdout = Join-Path $logRoot "proxy-$index.stdout.log"
        $stderr = Join-Path $logRoot "proxy-$index.stderr.log"
        $proxyScript = Join-Path $PSScriptRoot 'net_udp_proxy.py'
        $arguments = @(('"'+$proxyScript+'"'),'--target-port',"$($ports[0])",'--listen-port',"$($ports[$index])",'--delay-ms',"$OneWayDelayMs",'--loss',"$Loss",'--seed',"$($Seed+$index)",'--duration',"$($RunSeconds+60)",'--stop-file',('"'+$stop+'"'),'--stats-file',('"'+$stats+'"'))
        $process = Start-Process -FilePath $python -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null = $process.Handle
        $owned.Add([pscustomobject]@{Process=$process; Stop=$stop; Stats=$stats; Stdout=$stdout})
    }
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($entry in $owned) {
        while (-not (Test-Path -LiteralPath $entry.Stdout) -or (Get-Content -LiteralPath $entry.Stdout -Raw) -notmatch 'UDP_PROXY_READY') {
            $entry.Process.Refresh()
            if ($entry.Process.HasExited -or $watch.Elapsed.TotalSeconds -gt 10) { throw 'UDP fixture failed to start.' }
            Start-Sleep -Milliseconds 100
        }
    }
    $clientPorts = @($ports | Select-Object -Skip 1 | ForEach-Object { "$_" })
    Write-Host "IMPAIRED_CAMPAIGN players=$Players nominal_rtt_ms=$($OneWayDelayMs*2) loss=$Loss logs=$logRoot"
    $parameters = @{Players=$Players; Scenario='campaign'; Port=$ports[0]; Seed=$Seed; RunSeconds=$RunSeconds; ClientPorts=$clientPorts}
    if (-not [string]::IsNullOrWhiteSpace($GodotPath)) { $parameters.GodotPath = $GodotPath }
    & (Join-Path $PSScriptRoot 'ten_room_campaign_smoke.ps1') @parameters
    $result.Result = 'PASS'
}
catch {
    $result.Result = 'FAIL'
    $result.Error = $_.Exception.Message
    throw
}
finally {
    foreach ($entry in $owned) { [System.IO.File]::WriteAllText($entry.Stop,'stop') }
    foreach ($entry in $owned) {
        if (-not $entry.Process.WaitForExit(3000)) { Stop-Process -Id $entry.Process.Id -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $entry.Stats) {
            $report = Get-Content -LiteralPath $entry.Stats -Raw | ConvertFrom-Json
            $result.ProxyStats += $report
            if ($report.queue_overflow -gt 0 -or $report.transport_errors -gt 0) { $result.Result='FAIL'; $result.Error='UDP fixture overflow/transport error.' }
        }
        else { $result.Result='FAIL'; $result.Error='UDP fixture did not retain its report.' }
    }
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding utf8
    Write-Host "IMPAIRED_RESULT $($result.Result) result=$resultPath"
}
if ($result.Result -ne 'PASS') { throw $result.Error }
