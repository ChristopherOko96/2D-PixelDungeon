<# Real visible fullscreen client plus three headless local peers; no fake GPU FPS. #>
param([string]$GodotPath = '', [switch]$Campaign)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $GodotPath) { $GodotPath = (Resolve-Path -LiteralPath (Join-Path $repoRoot '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe')).Path }
$probe = [System.Net.Sockets.UdpClient]::new(0)
$port = ([System.Net.IPEndPoint]$probe.Client.LocalEndPoint).Port
$probe.Dispose()
$runName = Get-Date -Format 'yyyyMMdd-HHmmss'
$logRoot = Join-Path $repoRoot "Logs/client-render/$runName"
$outRoot = Join-Path $repoRoot 'production/qa/evidence/story-019-client-smoothing-admission'
if ($Campaign) { $outRoot = Join-Path $repoRoot 'production/qa/evidence/story-020-ten-room-coop-acceptance/visible-four-campaign' }
$null = New-Item -ItemType Directory -Path $logRoot -Force
$null = New-Item -ItemType Directory -Path $outRoot -Force
$owned = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
function Start-LoadPeer([string]$Name,[string]$Role) {
    $arguments = @('--headless','--max-fps','120','--path',('"'+$repoRoot+'"'),'--script','res://tests/client_render_probe.gd','--','--render-role',$Role,'--render-port',"$port")
    if ($Campaign) { $arguments += '--render-campaign' }
    $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot "$Name.stdout.log") -RedirectStandardError (Join-Path $logRoot "$Name.stderr.log")
    $owned.Add($process)
    return $process
}
try {
    $hostPeer = Start-LoadPeer 'host' 'host'
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 100
        $hostText = Get-Content -LiteralPath (Join-Path $logRoot 'host.stdout.log') -Raw -ErrorAction SilentlyContinue
    } while ($hostText -notmatch 'SESSION_HOSTED' -and [DateTime]::UtcNow -lt $deadline -and -not $hostPeer.HasExited)
    if ($hostText -notmatch 'SESSION_HOSTED') { throw "Render load host not ready: $logRoot" }
    $null = Start-LoadPeer 'client-1' 'client'
    $null = Start-LoadPeer 'client-2' 'client'
    $visibleArguments = @('--path',$repoRoot,'--script','res://tests/client_render_probe.gd','--log-file',(Join-Path $logRoot 'visible-client.log'),'--','--render-role','client','--render-port',"$port",'--render-output',$outRoot,'--render-visible')
    if ($Campaign) { $visibleArguments += '--render-campaign' }
    & $GodotPath @visibleArguments
    if ($LASTEXITCODE -ne 0) { throw "Visible client render probe failed: $outRoot/client-frame-times.json" }
    $report = Get-Content -LiteralPath (Join-Path $outRoot 'client-frame-times.json') -Raw | ConvertFrom-Json
    if (-not $report.passed) { throw 'Client render criteria were not met.' }
    Write-Output "CLIENT_RENDER_PASS logs=$logRoot evidence=$outRoot"
}
finally {
    foreach ($process in $owned) {
        $process.Refresh()
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -ErrorAction SilentlyContinue }
        $process.Dispose()
    }
}
