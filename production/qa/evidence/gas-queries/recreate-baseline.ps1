$ErrorActionPreference = 'Stop'
# Run from the repository root. Reconstruct only the unchanged pre-optimization field.
$destination = Join-Path (Get-Location) 'output/gas-query-baseline'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$sourceLines = & git show '7c39036ec9c12a3ba5b490b9f17293075666e5ee:src/physics_kit/gas_field.gd'
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the baseline gas field.' }
$sourceText = ($sourceLines -join "`n") -replace '(?m)^class_name GasField\r?\n', ''
[System.IO.File]::WriteAllText((Join-Path $destination 'gas_field.gd'), $sourceText + "`n")
$painterLines = & git show '7c39036ec9c12a3ba5b490b9f17293075666e5ee:src/vfx/gas.gd'
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the baseline gas painter.' }
$painterText = ($painterLines -join "`n").Replace('var gas_field: GasField', 'var gas_field: RefCounted')
$painterText = $painterText.Replace('GasField.', 'BaselineField.')
$painterText = $painterText.Replace('var clouds := gas_field.clouds()', 'var clouds: Dictionary = gas_field.clouds()')
$painterText = $painterText.Replace('extends RefCounted', 'extends RefCounted' + "`n" + 'const BaselineField = preload("res://output/gas-query-baseline/gas_field.gd")')
[System.IO.File]::WriteAllText((Join-Path $destination 'gas.gd'), $painterText + "`n")
