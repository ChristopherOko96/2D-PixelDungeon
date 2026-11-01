[CmdletBinding()]
param(
    [ValidateSet('Doctor', 'Open', 'Run', 'Host', 'Join', 'Check', 'Tests', 'DungeonEditor', 'AnimationStudio', 'HellDungeon')]
    [string]$Action = 'Doctor',
    [string]$GodotPath,
    [ValidatePattern('^[A-Za-z0-9_.:\-\[\]]+$')]
    [string]$Address = '127.0.0.1',
    [ValidateRange(1, 65535)]
    [int]$Port = 7777,
    [string]$DungeonFile,
    # Tests: how many suites run at once, the time limit of one suite, which suites
    # (a wildcard on the file name without .gd, e.g. 'talent_*'), whether to skip the
    # import that registers class_name scripts first, and whether suites that need a
    # real window (a line "# test: window" in the suite: it awaits
    # RenderingServer.frame_post_draw) run in one instead of being listed as skipped.
    [ValidateRange(1, 32)]
    [int]$Jobs = 4,
    [ValidateRange(10, 3600)]
    [int]$TimeoutSeconds = 300,
    [ValidatePattern('^[A-Za-z0-9_*?]+$')]
    [string]$Only = '*',
    [switch]$SkipImport,
    [switch]$Windowed
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

function Stop-ProcessTree([System.Diagnostics.Process]$Process) {
    # The console executable starts the real Godot process as a child; kill the tree.
    # cmd does the redirection, so taskkill's messages never reach PowerShell's error stream.
    & cmd.exe /c "taskkill /PID $($Process.Id) /T /F >nul 2>&1"
    $null = $Process.WaitForExit(5000)
}

function Read-TestResult($Job, [bool]$TimedOut) {
    # One suite's verdict from its output: it fails on a timeout, an exit code other
    # than 0, a missing summary line (checked=), a summary with failures above 0, or
    # any _FAIL / SCRIPT ERROR / Parse Error line. Pattern matching is case-sensitive,
    # so a JSON "parse error" warning does not count as a GDScript Parse Error.
    $seconds = ((Get-Date) - $Job.Start).TotalSeconds
    $lines = @(@($Job.Out, $Job.Err) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        ForEach-Object { Get-Content -LiteralPath $_ -Encoding UTF8 })
    $kept = @($lines | Where-Object { $_ -cmatch 'checked=|_FAIL|SCRIPT ERROR|Parse Error|failed=' })
    $code = $null
    if (-not $TimedOut) {
        $Job.Process.WaitForExit()
        $Job.Process.Refresh()
        $code = $Job.Process.ExitCode
    }
    $reasons = @()
    if ($TimedOut) { $reasons += "Zeitlimit $TimeoutSeconds s" }
    elseif ($null -eq $code -or $code -ne 0) { $reasons += "Exit-Code $code" }
    $summaries = @($kept | Where-Object { $_ -cmatch 'checked=' })
    if ($summaries.Count -eq 0) { $reasons += 'keine Zusammenfassung (checked=)' }
    foreach ($line in $summaries) {
        if ($line -cmatch '(?:failures|failed)=(\d+)' -and [int]$Matches[1] -gt 0) { $reasons += "failures=$($Matches[1])" }
    }
    if (@($kept | Where-Object { $_ -cmatch '_FAIL' }).Count -gt 0) { $reasons += '_FAIL' }
    if (@($kept | Where-Object { $_ -cmatch 'SCRIPT ERROR' }).Count -gt 0) { $reasons += 'SCRIPT ERROR' }
    if (@($kept | Where-Object { $_ -cmatch 'Parse Error' }).Count -gt 0) { $reasons += 'Parse Error' }
    return [pscustomobject]@{
        Name = $Job.Name; Passed = ($reasons.Count -eq 0); Skipped = $false; Reasons = ($reasons | Select-Object -Unique)
        Kept = $kept; Summary = ($summaries -join ' | '); Seconds = [math]::Round($seconds, 1)
    }
}

function Write-TestReport($Results, [datetime]$Started, [string]$ImportNote) {
    # production/qa/tests-latest.md in German. The script stays ASCII (Windows
    # PowerShell 5.1 reads a .ps1 without BOM as ANSI), so umlauts come from char codes.
    # Variable names ignore case in PowerShell: $Ue would overwrite $ue, hence $UeBig.
    $ae = [char]0x00E4; $ue = [char]0x00FC; $UeBig = [char]0x00DC
    $passed = @($Results | Where-Object { $_.Passed } | Sort-Object Name)
    $skipped = @($Results | Where-Object { $_.Skipped } | Sort-Object Name)
    $failed = @($Results | Where-Object { -not $_.Passed -and -not $_.Skipped } | Sort-Object Name)
    $duration = (Get-Date) - $Started
    $maxLines = 40
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add("# Testlauf $($Started.ToString('yyyy-MM-dd HH:mm'))")
    $out.Add('')
    $out.Add("Erzeugt von ``scripts/Dev.ps1 Tests`` (alle ``tests/*_test.gd`` headless, je Suite ein eigener ``user://``-Ordner).")
    $out.Add('')
    $out.Add("- Dauer: $([math]::Floor($duration.TotalMinutes)) min $($duration.Seconds) s")
    $out.Add("- Suiten: $($Results.Count) (Auswahl ``$Only``), $Jobs gleichzeitig, Zeitlimit $TimeoutSeconds s je Suite")
    $out.Add("- Bestanden: $($passed.Count)")
    $out.Add("- Fehlgeschlagen: $($failed.Count)")
    $out.Add("- $($UeBig)bersprungen (brauchen ein Fenster, mit ``-Windowed`` laufen sie): $($skipped.Count)")
    $out.Add("- Import vorab: $ImportNote")
    $out.Add('')
    $out.Add('## Fehlgeschlagen')
    $out.Add('')
    if ($failed.Count -eq 0) { $out.Add('Keine.'); $out.Add('') }
    foreach ($result in $failed) {
        $out.Add("### $($result.Name)")
        $out.Add('')
        $out.Add("Gr$($ue)nde: $($result.Reasons -join ', ') ($($result.Seconds) s). Volle Ausgabe: ``Logs/tests/$($result.Name).stdout.log`` und ``.stderr.log``.")
        $out.Add('')
        if ($result.Kept.Count -gt 0) {
            $out.Add('```text')
            foreach ($line in @($result.Kept | Select-Object -First $maxLines)) { $out.Add($line) }
            if ($result.Kept.Count -gt $maxLines) { $out.Add("... $($result.Kept.Count - $maxLines) weitere Zeilen") }
            $out.Add('```')
            $out.Add('')
        }
    }
    if ($skipped.Count -gt 0) {
        $out.Add("## $($UeBig)bersprungen")
        $out.Add('')
        $out.Add("Diese Suiten tragen die Zeile ``# test: window``: sie warten auf ``RenderingServer.frame_post_draw``, das headless nie kommt. ``scripts/Dev.ps1 Tests -Windowed`` startet sie in einem Fenster.")
        $out.Add('')
        foreach ($result in $skipped) { $out.Add("- $($result.Name)") }
        $out.Add('')
    }
    $out.Add('## Bestanden')
    $out.Add('')
    $out.Add('| Suite | Zusammenfassung | Sekunden |')
    $out.Add('|---|---|---|')
    foreach ($result in $passed) { $out.Add("| $($result.Name) | $($result.Summary) | $($result.Seconds) |") }
    $report = Join-Path $repositoryRoot 'production/qa/tests-latest.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $report) -Force | Out-Null
    [IO.File]::WriteAllText($report, (($out -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding $false))
    Write-Host "$($UeBig)bersicht: $report"
}

function Invoke-TestSuite {
    # Runs every tests/*_test.gd (filtered by -Only) headless, -Jobs at a time, each
    # with -TimeoutSeconds. APPDATA points every suite at its own scratch folder, so
    # user:// is empty and private per suite: no suite touches the real profile,
    # settings or saves, and parallel suites never share user://profile_test.json.
    # Sets $script:testFailures to the number of failed suites.
    $started = Get-Date
    $importNote = 'ok'
    if ($SkipImport) {
        $importNote = "$([char]0x00FC)bersprungen (-SkipImport)"
    } else {
        # registers class_name scripts (.godot/global_script_class_cache.cfg) as Check does
        try { Invoke-GodotCheck @('--editor', '--import', '--quit') 'import' }
        catch { $importNote = "Warnung: $($_.Exception.Message)"; Write-Warning $_.Exception.Message }
    }
    $files = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'tests') -Filter '*_test.gd' -File |
        Where-Object { $_.BaseName -like $Only } | Sort-Object Name)
    if ($files.Count -eq 0) { throw "No test suite matches tests/$Only.gd" }
    $runLogs = Join-Path $logDirectory 'tests'
    if (Test-Path -LiteralPath $runLogs) { Remove-Item -LiteralPath $runLogs -Recurse -Force }
    New-Item -ItemType Directory -Path $runLogs -Force | Out-Null
    $sandbox = Join-Path ([IO.Path]::GetTempPath()) ('delve-tests-' + [guid]::NewGuid().ToString('N'))
    $queue = New-Object System.Collections.Queue
    foreach ($file in $files) { $queue.Enqueue($file) }
    $running = New-Object System.Collections.ArrayList
    $results = New-Object System.Collections.ArrayList
    $savedAppData = $env:APPDATA
    Write-Host "Running $($files.Count) test suite(s), $Jobs at a time, $TimeoutSeconds s limit each."
    try {
        while ($queue.Count -gt 0 -or $running.Count -gt 0) {
            while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) {
                $file = $queue.Dequeue()
                $name = $file.BaseName
                # a suite that reads back a drawn frame needs a real renderer (no --headless);
                # it says so with a line "# test: window" (headless, frame_post_draw never comes)
                $needsWindow = (Get-Content -LiteralPath $file.FullName -Raw) -match '(?m)^#\s*test:\s*window'
                if ($needsWindow -and -not $Windowed) {
                    [void]$results.Add([pscustomobject]@{ Name = $name; Passed = $false; Skipped = $true; Reasons = @('braucht ein Fenster')
                        Kept = @(); Summary = ''; Seconds = 0 })
                    Write-Host "[SKIP] $name (needs a window: -Windowed)"
                    continue
                }
                $appData = Join-Path $sandbox $name
                New-Item -ItemType Directory -Path $appData -Force | Out-Null
                $stdout = Join-Path $runLogs "$name.stdout.log"
                $stderr = Join-Path $runLogs "$name.stderr.log"
                $arguments = @('--path', $repositoryRoot, '--script', "res://tests/$($file.Name)")
                if (-not $needsWindow) { $arguments = @('--headless') + $arguments }
                $env:APPDATA = $appData
                try {
                    $process = Start-Process -FilePath $editorPath -ArgumentList (ConvertTo-ProcessArguments $arguments) `
                        -WorkingDirectory $repositoryRoot -PassThru -WindowStyle Hidden `
                        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
                } finally {
                    $env:APPDATA = $savedAppData
                }
                # keep a native handle so Windows PowerShell 5.1 keeps the exit code
                $null = $process.Handle
                [void]$running.Add([pscustomobject]@{ Name = $name; Process = $process; Start = Get-Date; Out = $stdout; Err = $stderr })
            }
            foreach ($job in @($running)) {
                $timedOut = $false
                if (-not $job.Process.HasExited) {
                    if (((Get-Date) - $job.Start).TotalSeconds -lt $TimeoutSeconds) { continue }
                    Stop-ProcessTree $job.Process
                    $timedOut = $true
                }
                $result = Read-TestResult $job $timedOut
                [void]$results.Add($result)
                [void]$running.Remove($job)
                $mark = if ($result.Passed) { '[OK]  ' } else { '[FAIL]' }
                Write-Host ("{0} {1} ({2} s) {3}" -f $mark, $result.Name, $result.Seconds, ($result.Reasons -join ', '))
            }
            if ($running.Count -gt 0) { Start-Sleep -Milliseconds 200 }
        }
    } finally {
        $env:APPDATA = $savedAppData
        foreach ($job in @($running)) { if (-not $job.Process.HasExited) { Stop-ProcessTree $job.Process } }
        if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-TestReport $results $started $importNote
    $script:testFailures = @($results | Where-Object { -not $_.Passed -and -not $_.Skipped }).Count
    $skippedCount = @($results | Where-Object { $_.Skipped }).Count
    Write-Host "$(@($results | Where-Object { $_.Passed }).Count) passed, $script:testFailures failed, $skippedCount skipped."
}

Assert-Project
$editorPath = Resolve-GodotEditor
Write-Host "[OK] Executable: $editorPath"

switch ($Action) {
    'Doctor' {
        Write-Host '[OK] Development prerequisites found. This is not a gameplay or multiplayer test.'
    }
    'Tests' {
        # every tests/*_test.gd; summary in production/qa/tests-latest.md; exit 1 on any failure
        $script:testFailures = 0
        Invoke-TestSuite
        if ($script:testFailures -gt 0) { exit 1 }
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
        # The game opens straight into the Dungeon-Werkstatt (main menu EDITOR).
        $arguments = @('--path', $repositoryRoot, '--windowed', '--', '--werkstatt')
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
