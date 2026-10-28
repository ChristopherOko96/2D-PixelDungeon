[CmdletBinding()]
param(
    [ValidateSet('Doctor', 'Open', 'Run', 'Host', 'Join', 'Check', 'DungeonEditor', 'AnimationStudio', 'HellDungeon')]
    [string]$Action = 'Doctor',
    [string]$GodotPath,
    [ValidatePattern('^[A-Za-z0-9_.:\-\[\]]+$')]
    [string]$Address = '127.0.0.1',
    [ValidateRange(1, 65535)]
    [int]$Port = 7777,
    [string]$DungeonFile
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $PSScriptRoot 'godot-environment.json'
if (-not (Test-Path -LiteralPath $environmentFile -PathType Leaf)) {
    throw "Missing Godot configuration: $environmentFile"
}
$configuration = Get-Content -LiteralPath $environmentFile -Raw | ConvertFrom-Json
$expectedPrefix = [string]$configuration.versionPrefix
if ([string]::IsNullOrWhiteSpace($expectedPrefix)) {
    throw 'scripts/godot-environment.json must specify versionPrefix.'
}
$logDirectory = Join-Path $repositoryRoot 'Logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

function ConvertTo-ProcessArguments([string[]]$Values) {
    # No shell interprets these arguments. Quoting preserves repository paths
    # containing spaces when Start-Process assembles the Windows command line.
    foreach ($value in $Values) {
        if ($value.Contains('"') -or $value.EndsWith('\')) {
            throw "Unsupported quote or trailing slash in process argument: $value"
        }
    }
    return (($Values | ForEach-Object { '"' + $_ + '"' }) -join ' ')
}

function Assert-Project {
    $branch = & git -C $repositoryRoot branch --show-current
    if ($LASTEXITCODE -ne 0) { throw 'Git could not inspect the project repository.' }
    if ([string]::IsNullOrWhiteSpace($branch) -or $branch -in @('main', 'master')) {
        throw 'Use a feature branch before development: git switch -c codex/your-feature'
    }
    foreach ($relativePath in @('project.godot', 'src/main.tscn', 'src/game.gd')) {
        if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath) -PathType Leaf)) {
            throw "Missing Godot project file: $relativePath"
        }
    }
    Write-Host "[OK] Git branch: $branch"
    Write-Host '[OK] Godot project: project.godot; entry scene: src/main.tscn'
}

function Get-GodotVersion([string]$Executable) {
    $stdout = Join-Path $logDirectory 'godot-version.stdout.log'
    $stderr = Join-Path $logDirectory 'godot-version.stderr.log'
    $probe = Start-Process -FilePath $Executable -ArgumentList '--version' -PassThru `
        -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    # Keep a native handle before waiting. Windows PowerShell 5.1 can otherwise
    # lose a short-lived process's exit code after Start-Process returns it.
    $null = $probe.Handle
    if (-not $probe.WaitForExit(15000)) {
        $probe.Kill()
        throw "Godot version probe timed out: $Executable"
    }
    $probe.WaitForExit()
    $probe.Refresh()
    if ($null -eq $probe.ExitCode -or $probe.ExitCode -ne 0) { throw "Godot version probe failed: $Executable" }
    return (Get-Content -LiteralPath $stdout -Raw).Trim()
}

function Resolve-GodotEditor {
    $requestedPath = $GodotPath
    if (-not $requestedPath) { $requestedPath = $env:GODOT_PATH }
    $localFile = Join-Path $PSScriptRoot 'godot.local.json'
    if (-not $requestedPath -and (Test-Path -LiteralPath $localFile -PathType Leaf)) {
        $requestedPath = (Get-Content -LiteralPath $localFile -Raw | ConvertFrom-Json).godotPath
    }
    if ($requestedPath) {
        if (-not (Test-Path -LiteralPath $requestedPath -PathType Leaf)) {
            throw "Godot executable does not exist: $requestedPath"
        }
        $candidates = @($requestedPath)
    } else {
        $portable = [IO.Path]::GetFullPath((Join-Path $repositoryRoot `
            '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'))
        $candidates = @($portable)
        foreach ($name in @('godot', 'godot4', 'Godot_v4.7.2-stable_win64_console.exe')) {
            $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($command) { $candidates += $command.Source }
        }
    }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $version = Get-GodotVersion $candidate
        if ($version -match ('^' + [regex]::Escape($expectedPrefix) + '(?:\.|$)')) {
            Write-Host "[OK] Godot version: $version"
            return (Resolve-Path -LiteralPath $candidate).Path
        }
        if ($requestedPath) {
            throw "Godot '$version' does not match required '$expectedPrefix'. Do not upgrade silently."
        }
    }
    throw "Godot $expectedPrefix was not found. Use -GodotPath '<path>/Godot_v4.7.2-stable_win64_console.exe' or set GODOT_PATH."
}

function Invoke-GodotCheck([string[]]$ExtraArguments, [string]$LogName) {
    $logFile = Join-Path $logDirectory "godot-$LogName.log"
    $stdout = Join-Path $logDirectory "godot-$LogName.stdout.log"
    $stderr = Join-Path $logDirectory "godot-$LogName.stderr.log"
    if (Test-Path -LiteralPath $logFile -PathType Leaf) { Remove-Item -LiteralPath $logFile }
    $godotArguments = @('--headless', '--path', $repositoryRoot, '--log-file', $logFile) + $ExtraArguments
    Write-Host "Running Godot $LogName. Log: $logFile"
    $process = Start-Process -FilePath $editorPath `
        -ArgumentList (ConvertTo-ProcessArguments $godotArguments) -WorkingDirectory $repositoryRoot `
        -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $process.Handle
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw "Godot $LogName timed out after 60 seconds. Inspect $logFile."
    }
    $process.WaitForExit()
    $process.Refresh()
    $output = (@($logFile, $stdout, $stderr) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        ForEach-Object { Get-Content -LiteralPath $_ -Raw }) -join "`n"
    # Godot can return 0 after a script error. Check its output as well.
    $fatalPattern = '(?im)^\s*(?:SCRIPT ERROR|ERROR:|PARSE FAIL:|Parse Error)'
    if ($null -eq $process.ExitCode -or $process.ExitCode -ne 0 -or -not $output -or $output -match $fatalPattern) {
        @($logFile, $stderr) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            ForEach-Object { Get-Content -LiteralPath $_ -Tail 20 | Write-Host }
        throw "Godot $LogName failed (exit $($process.ExitCode)). Inspect $logFile."
    }
    Write-Host "[OK] Godot $LogName completed."
}

Assert-Project
$editorPath = Resolve-GodotEditor
Write-Host "[OK] Executable: $editorPath"

switch ($Action) {
    'Doctor' {
        Write-Host '[OK] Development prerequisites found. This is not a gameplay or multiplayer test.'
    }
    'Open' {
        $arguments = @('--path', $repositoryRoot, '--editor')
        Start-Process -FilePath $editorPath -ArgumentList (ConvertTo-ProcessArguments $arguments) `
            -WorkingDirectory $repositoryRoot | Out-Null
    }
    'Run' {
        $arguments = @('--path', $repositoryRoot, '--windowed')
        if ($DungeonFile) { $arguments += @('--', '--dungeon', $DungeonFile) }
        Start-Process -FilePath $editorPath -ArgumentList (ConvertTo-ProcessArguments $arguments) `
            -WorkingDirectory $repositoryRoot | Out-Null
    }
    'Host' {
        $arguments = @('--path', $repositoryRoot, '--windowed', '--', '--host', '--port', [string]$Port)
        if ($DungeonFile) { $arguments += @('--dungeon', $DungeonFile) }
        $process = Start-Process -FilePath $editorPath -ArgumentList (ConvertTo-ProcessArguments $arguments) `
            -WorkingDirectory $repositoryRoot -PassThru
        Write-Host "Started host process $($process.Id), UDP port $Port."
    }
    'DungeonEditor' {
        $arguments = @('--path', $repositoryRoot, '--windowed', 'res://src/dungeon_editor.tscn', '--', '--blank')
        if ($DungeonFile) { $arguments = @('--path', $repositoryRoot, '--windowed', 'res://src/dungeon_editor.tscn', '--', '--draft', $DungeonFile) }
        # Explicit interactive authoring window, also used by Dungeon-Editor.cmd.
        Start-Process -FilePath $editorPath -ArgumentList (ConvertTo-ProcessArguments $arguments) `
            -WorkingDirectory $repositoryRoot -WindowStyle Normal | Out-Null
    }
    'AnimationStudio' {
        $arguments = @('--path', $repositoryRoot, '--windowed', 'res://src/animation_studio.tscn')
        # Explicit interactive preview window, also used by Animation-Studio.cmd.
        Start-Process -FilePath $editorPath -ArgumentList (ConvertTo-ProcessArguments $arguments) `
            -WorkingDirectory $repositoryRoot -WindowStyle Normal | Out-Null
    }
    'HellDungeon' {
        $arguments = @('--path', $repositoryRoot, '--windowed', 'res://src/hell/hell_dungeon.tscn')
        # Single-player hell floors, also used by Hell-Dungeon.cmd.
        Start-Process -FilePath $editorPath -ArgumentList (ConvertTo-ProcessArguments $arguments) `
            -WorkingDirectory $repositoryRoot -WindowStyle Normal | Out-Null
    }
    'Join' {
        $arguments = @('--path', $repositoryRoot, '--windowed', '--', '--join', $Address, '--port', [string]$Port)
        $process = Start-Process -FilePath $editorPath -ArgumentList (ConvertTo-ProcessArguments $arguments) `
            -WorkingDirectory $repositoryRoot -PassThru
        Write-Host "Started client process $($process.Id), connecting to ${Address}:$Port."
    }
    'Check' {
        Invoke-GodotCheck @('--editor', '--import', '--quit') 'import'
        $sourceRoot = Join-Path $repositoryRoot 'src'
        $scripts = @(Get-ChildItem -LiteralPath $sourceRoot -Filter '*.gd' -Recurse -File | ForEach-Object {
            'res://' + $_.FullName.Substring($repositoryRoot.Length + 1).Replace('\', '/')
        })
        if ($scripts.Count -eq 0) { throw 'No GDScript files found under src/. Nothing was checked.' }
        $parseRunner = Join-Path $repositoryRoot '.claude/scripts/godot-parse-check.gd'
        if (-not (Test-Path -LiteralPath $parseRunner -PathType Leaf)) {
            throw 'Missing .claude/scripts/godot-parse-check.gd.'
        }
        Invoke-GodotCheck (@('--script', 'res://.claude/scripts/godot-parse-check.gd', '--') + $scripts) 'parse'
        Write-Host "[OK] Import and parse check completed for $($scripts.Count) script(s). Gameplay, exported builds and multiplayer are not covered by this check."
    }
}
