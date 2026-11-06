$ErrorActionPreference = 'Stop'
$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Run this from the project checkout.' }
$fixtureRoot = Join-Path $repoRoot 'output/enemy-index-baseline'
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
$encoding = [System.Text.UTF8Encoding]::new($false)
foreach ($name in @('hell_monsters.gd', 'hell_talents.gd', 'hell_game.gd')) {
    $source = & git show "7c39036e:src/hell/$name"
    if ($LASTEXITCODE -ne 0) { throw "Cannot read baseline $name" }
    $body = $source -join "`n"
    if ($name -eq 'hell_game.gd') {
        $body = $body.Replace('res://src/hell/hell_monsters.gd', 'res://output/enemy-index-baseline/hell_monsters.gd')
        $body = $body.Replace('res://src/hell/hell_talents.gd', 'res://output/enemy-index-baseline/hell_talents.gd')
    }
    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot $name), $body + "`n", $encoding)
}
Write-Output 'Baseline 7c39036e recreated under output/enemy-index-baseline; checkout unchanged.'
