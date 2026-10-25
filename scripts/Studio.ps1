[CmdletBinding()]
param(
    [ValidateSet('Doctor', 'Check', 'Sync', 'Open', 'CommitCheck', 'PushCheck')]
    [string]$Action = 'Doctor',
    [string]$PythonPath,
    [string]$CodexPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Resolve-Python {
    if ($PythonPath) {
        $candidates = @([pscustomobject]@{ File = $PythonPath; Prefix = @() })
    } else {
        $candidates = @()
        $launcher = Get-Command py.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($launcher) { $candidates += [pscustomobject]@{ File = $launcher.Source; Prefix = @('-3') } }
        foreach ($name in @('python3.exe', 'python.exe')) {
            $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($command -and $command.Source -notmatch '\\WindowsApps\\') {
                $candidates += [pscustomobject]@{ File = $command.Source; Prefix = @() }
            }
        }
        $pythonDirectory = Join-Path $env:LOCALAPPDATA 'Programs/Python'
        if (Test-Path -LiteralPath $pythonDirectory) {
            foreach ($directory in (Get-ChildItem -LiteralPath $pythonDirectory -Directory | Sort-Object Name -Descending)) {
                $candidate = Join-Path $directory.FullName 'python.exe'
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    $candidates += [pscustomobject]@{ File = $candidate; Prefix = @() }
                }
            }
        }
    }
    foreach ($candidate in $candidates) {
        $prefix = @($candidate.Prefix)
        $version = & $candidate.File @prefix -c 'import sys; print(sys.version.split()[0]); sys.exit(sys.version_info < (3, 9))' 2>$null
        if ($LASTEXITCODE -eq 0 -and $version) {
            return [pscustomobject]@{ File = $candidate.File; Prefix = $prefix; Version = [string]$version }
        }
    }
    throw 'Python 3.9+ was not found. Supply -PythonPath with a real Python executable; no pip packages are needed.'
}

function Resolve-GitBash {
    $candidates = @()
    if ($env:STUDIO_BASH) { $candidates += $env:STUDIO_BASH }
    $gitCommand = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gitCommand) {
        $gitRoot = Split-Path -Parent (Split-Path -Parent $gitCommand.Source)
        $candidates += Join-Path $gitRoot 'bin/bash.exe'
    }
    $candidates += @('C:/Program Files/Git/bin/bash.exe', 'C:/Program Files/Git/usr/bin/bash.exe')
    $bashCommand = Get-Command bash.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($bashCommand -and $bashCommand.Source -notmatch '\\Windows\\System32\\') { $candidates += $bashCommand.Source }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw 'Git Bash was not found. Install Git for Windows or set STUDIO_BASH to its bash.exe.'
}

function Resolve-Codex {
    $requested = if ($CodexPath) { $CodexPath } else { $env:STUDIO_CODEX }
    if ($requested) {
        $candidates = @($requested)
    } else {
        $candidates = @()
        $bundled = Join-Path $env:LOCALAPPDATA 'OpenAI/Codex/bin'
        if (Test-Path -LiteralPath $bundled) {
            foreach ($directory in (Get-ChildItem -LiteralPath $bundled -Directory)) {
                $candidate = Join-Path $directory.FullName 'codex.exe'
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidates += $candidate }
            }
            $candidates += Join-Path $bundled 'codex.exe'
        }
        foreach ($name in @('codex.exe', 'codex.cmd')) {
            $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($command) { $candidates += $command.Source }
        }
    }
    $versions = foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $versionText = (& $candidate --version 2>$null) -join ' '
        if ($LASTEXITCODE -eq 0 -and $versionText -match 'codex-cli\s+(\d+\.\d+\.\d+)') {
            [pscustomobject]@{ File = $candidate; Version = [version]$Matches[1]; Display = $versionText }
        }
    }
    $selected = $versions | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $selected) { throw 'Codex was not found. Open this repository in the desktop app or supply -CodexPath.' }
    return $selected
}

function Invoke-StudioPython([string[]]$Arguments) {
    $prefix = @($python.Prefix)
    & $python.File @prefix @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Studio command failed (exit $LASTEXITCODE): $($Arguments -join ' ')" }
}

$branch = & git -C $repositoryRoot branch --show-current
if ($LASTEXITCODE -ne 0 -or -not $branch) { throw 'The game must be opened from its Git repository.' }
if ($branch -in @('main', 'master')) { throw 'Use a development branch for this game.' }
$python = Resolve-Python
Push-Location -LiteralPath $repositoryRoot
try {
    switch ($Action) {
        'Doctor' {
            $bash = Resolve-GitBash
            $codex = Resolve-Codex
            Write-Host "[OK] Branch: $branch"
            Write-Host "[OK] Python $($python.Version): $($python.File)"
            Write-Host "[OK] Git Bash: $bash"
            Write-Host "[OK] $($codex.Display): $($codex.File)"
            Invoke-StudioPython @('scripts/sync_codex.py', '--check')
            Write-Host '[OK] Studio prerequisites checked. Game checks use scripts/Dev.ps1.'
        }
        'Check' {
            Invoke-StudioPython @('scripts/sync_codex.py', '--check')
            Invoke-StudioPython @('-m', 'unittest', 'discover', '-s', 'tests/template', '-v')
        }
        'Sync' { Invoke-StudioPython @('scripts/sync_codex.py') }
        'Open' {
            $codex = Resolve-Codex
            Write-Host "Opening $($codex.Display) in $repositoryRoot"
            # Interactive launch: retain the user's model, permission and trust settings.
            & $codex.File -C $repositoryRoot
            if ($LASTEXITCODE -ne 0) { throw "Codex exited with code $LASTEXITCODE." }
        }
        'CommitCheck' { Invoke-StudioPython @('scripts/studio_check.py', 'commit') }
        'PushCheck' { Invoke-StudioPython @('scripts/studio_check.py', 'push') }
    }
}
finally { Pop-Location }
