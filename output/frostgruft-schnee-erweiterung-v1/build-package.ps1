param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sourceRoot = Join-Path $ProjectRoot 'assets\sprites\frost'
$assetRoot = Join-Path $PSScriptRoot 'assets'
$propRoot = Join-Path $assetRoot 'props'
$structureRoot = Join-Path $assetRoot 'structures'
$previewRoot = Join-Path $PSScriptRoot 'preview'

foreach ($path in @($assetRoot, $propRoot, $structureRoot, $previewRoot)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

$variants = @(
    @{ Source='barrel_a.png'; Target='barrel_a_snowfoot.png'; Group='props'; Drift=0; Cap=$true },
    @{ Source='barrel_b.png'; Target='barrel_b_snowfoot.png'; Group='props'; Drift=1; Cap=$true },
    @{ Source='barrel_c.png'; Target='barrel_c_snowfoot.png'; Group='props'; Drift=2; Cap=$true },
    @{ Source='crate_a.png'; Target='crate_a_snowfoot.png'; Group='props'; Drift=3; Cap=$true },
    @{ Source='crate_b.png'; Target='crate_b_snowfoot.png'; Group='props'; Drift=4; Cap=$true },
    @{ Source='crate_c.png'; Target='crate_c_snowfoot.png'; Group='props'; Drift=5; Cap=$true },
    @{ Source='crate_pile.png'; Target='crate_pile_snowfoot.png'; Group='props'; Drift=0; Cap=$true },
    @{ Source='urn_a.png'; Target='urn_a_snowfoot.png'; Group='props'; Drift=1; Cap=$true },
    @{ Source='urn_b.png'; Target='urn_b_snowfoot.png'; Group='props'; Drift=2; Cap=$true },
    @{ Source='urn_c.png'; Target='urn_c_snowfoot.png'; Group='props'; Drift=3; Cap=$true },
    @{ Source='urn_d.png'; Target='urn_d_snowfoot.png'; Group='props'; Drift=4; Cap=$true },
    @{ Source='urn_e.png'; Target='urn_e_snowfoot.png'; Group='props'; Drift=5; Cap=$true },
    @{ Source='table_a.png'; Target='table_a_snowfoot.png'; Group='props'; Drift=0; Cap=$true },
    @{ Source='table_b.png'; Target='table_b_snowfoot.png'; Group='props'; Drift=1; Cap=$true },
    @{ Source='table_c.png'; Target='table_c_snowfoot.png'; Group='props'; Drift=2; Cap=$true },
    @{ Source='bench.png'; Target='bench_snowfoot.png'; Group='props'; Drift=3; Cap=$true },
    @{ Source='shelf.png'; Target='shelf_snowfoot.png'; Group='props'; Drift=4; Cap=$true },
    @{ Source='shop_table.png'; Target='shop_table_snowfoot.png'; Group='props'; Drift=5; Cap=$true },
    @{ Source='skull_heap.png'; Target='skull_heap_snowfoot.png'; Group='props'; Drift=0; Cap=$true },
    @{ Source='skull_pile.png'; Target='skull_pile_snowfoot.png'; Group='props'; Drift=1; Cap=$true },
    @{ Source='skull_obelisk.png'; Target='skull_obelisk_snowfoot.png'; Group='props'; Drift=2; Cap=$true },
    @{ Source='boulders.png'; Target='boulders_snowfoot.png'; Group='props'; Drift=3; Cap=$true },
    @{ Source='rubble.png'; Target='rubble_snowfoot.png'; Group='props'; Drift=4; Cap=$true },
    @{ Source='candelabra.png'; Target='candelabra_snowfoot.png'; Group='props'; Drift=5; Cap=$false },
    @{ Source='altar.png'; Target='altar_snowfoot.png'; Group='structures'; Drift=0; Cap=$true },
    @{ Source='wall_h.png'; Target='wall_h_snowfoot.png'; Group='structures'; Drift=1; Cap=$false },
    @{ Source='wall_v.png'; Target='wall_v_snowfoot.png'; Group='structures'; Drift=2; Cap=$false },
    @{ Source='wall_skull_a.png'; Target='wall_skull_a_snowfoot.png'; Group='structures'; Drift=3; Cap=$true },
    @{ Source='wall_skull_b.png'; Target='wall_skull_b_snowfoot.png'; Group='structures'; Drift=4; Cap=$true }
)

$snowHighlight = [System.Drawing.Color]::FromArgb(255, 244, 249, 255)
$snowMid = [System.Drawing.Color]::FromArgb(255, 207, 229, 249)
$snowShadow = [System.Drawing.Color]::FromArgb(255, 151, 191, 232)

function New-PixelGraphics([System.Drawing.Bitmap]$bitmap) {
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    return $graphics
}

function Get-TopOpaqueY([System.Drawing.Bitmap]$bitmap, [int]$x) {
    $left = [Math]::Max(0, [Math]::Min($bitmap.Width - 1, $x))
    $right = [Math]::Min($bitmap.Width - 1, $left + 2)
    for ($y = 0; $y -lt $bitmap.Height; $y++) {
        for ($scanX = $left; $scanX -le $right; $scanX++) {
            if ($bitmap.GetPixel($scanX, $y).A -gt 127) { return $y }
        }
    }
    return -1
}

function Add-TopSnowCap(
    [System.Drawing.Graphics]$graphics,
    [System.Drawing.Bitmap]$source,
    [int]$offsetX,
    [int]$offsetY
) {
    $start = [Math]::Max(3, [int]($source.Width * 0.18))
    $end = [Math]::Min($source.Width - 4, [int]($source.Width * 0.82))
    $column = 0
    for ($x = $start; $x -le $end; $x += 3) {
        $top = Get-TopOpaqueY $source $x
        if ($top -lt 0) { continue }
        $wave = @(0, 0, 3, 0, -3, 0)[$column % 6]
        $capY = [Math]::Max(0, $offsetY + $top - 3 + $wave)
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($snowShadow)), $offsetX + $x, $capY + 3, 3, 3)
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($snowMid)), $offsetX + $x, $capY, 3, 3)
        if (($column % 4) -eq 1) {
            $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($snowHighlight)), $offsetX + $x, $capY, 3, 3)
        }
        $column++
    }
}

function Add-FootSnow(
    [System.Drawing.Graphics]$graphics,
    [int]$offsetX,
    [int]$sourceWidth,
    [int]$baseY
) {
    $left = $offsetX + 3
    $right = $offsetX + $sourceWidth - 6
    $column = 0
    for ($x = $left; $x -le $right; $x += 3) {
        $rise = @(0, -3, 0, 0, -6, -3, 0)[$column % 7]
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($snowShadow)), $x, $baseY + $rise + 3, 3, 3)
        $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($snowMid)), $x, $baseY + $rise, 3, 3)
        if (($column % 5) -eq 2) {
            $graphics.FillRectangle((New-Object System.Drawing.SolidBrush($snowHighlight)), $x, $baseY + $rise, 3, 3)
        }
        $column++
    }
}

$manifestRows = @()

foreach ($variant in $variants) {
    $sourcePath = Join-Path $sourceRoot $variant.Source
    $driftPath = Join-Path $sourceRoot ("drift_{0}.png" -f $variant.Drift)
    $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
    $drift = [System.Drawing.Bitmap]::FromFile($driftPath)
    try {
        # The source drift sprites contain a few alpha-90 edge pixels. The
        # expansion deliberately uses hard alpha so nearest filtering cannot
        # produce a soft fringe around the new snow banks.
        for ($driftY = 0; $driftY -lt $drift.Height; $driftY++) {
            for ($driftX = 0; $driftX -lt $drift.Width; $driftX++) {
                $pixel = $drift.GetPixel($driftX, $driftY)
                if ($pixel.A -gt 0 -and $pixel.A -lt 255) {
                    $drift.SetPixel($driftX, $driftY, [System.Drawing.Color]::FromArgb(255, $pixel.R, $pixel.G, $pixel.B))
                }
            }
        }
        $topPad = if ($variant.Cap) { 9 } else { 3 }
        $sidePad = 9
        $bottomPad = 15
        $canvasWidth = [Math]::Max($source.Width + (2 * $sidePad), 48)
        $canvasHeight = $topPad + $source.Height + $bottomPad
        $bitmap = New-Object System.Drawing.Bitmap($canvasWidth, $canvasHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = New-PixelGraphics $bitmap
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $sourceX = [int](($canvasWidth - $source.Width) / 2)
            $sourceY = $topPad
            $driftY = $topPad + $source.Height - 9
            for ($driftX = -12; $driftX -lt $canvasWidth; $driftX += 42) {
                $graphics.DrawImageUnscaled($drift, $driftX, $driftY)
            }
            $graphics.DrawImageUnscaled($source, $sourceX, $sourceY)
            Add-FootSnow $graphics $sourceX $source.Width ($topPad + $source.Height - 6)
            if ($variant.Cap) {
                Add-TopSnowCap $graphics $source $sourceX $sourceY
            }
        }
        finally {
            $graphics.Dispose()
        }

        $groupRoot = if ($variant.Group -eq 'props') { $propRoot } else { $structureRoot }
        $targetPath = Join-Path $groupRoot $variant.Target
        $bitmap.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        $manifestRows += [ordered]@{
            file = "assets/$($variant.Group)/$($variant.Target)"
            source = "assets/sprites/frost/$($variant.Source)"
            category = $variant.Group
            treatment = if ($variant.Cap) { 'snow_foot_and_top_cap' } else { 'snow_foot' }
            source_preserved = $true
        }
    }
    finally {
        $source.Dispose()
        $drift.Dispose()
    }
}

$manifest = [ordered]@{
    package = 'frostgruft-schnee-erweiterung-v1'
    version = 1
    generated = '2026-10-30'
    grid = '32px world grid; source sprites retain their original 3px pixel blocks'
    filtering = 'nearest'
    alpha = 'transparent PNG'
    mode = 'additive variants; no source asset replaced'
    asset_count = $manifestRows.Count
    assets = $manifestRows
}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 (Join-Path $PSScriptRoot 'manifest.json')

# Build a large nearest-neighbor overview without altering any deliverable sprite.
$thumbScale = 3
$cellWidth = 330
$cellHeight = 240
$columns = 5
$rows = [Math]::Ceiling($manifestRows.Count / $columns)
$sheet = New-Object System.Drawing.Bitmap(($columns * $cellWidth), ($rows * $cellHeight), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$sheetGraphics = New-PixelGraphics $sheet
try {
    $sheetGraphics.Clear([System.Drawing.Color]::FromArgb(255, 16, 23, 42))
    for ($index = 0; $index -lt $manifestRows.Count; $index++) {
        $row = [int]($index / $columns)
        $column = $index % $columns
        $entry = $manifestRows[$index]
        $imagePath = Join-Path $PSScriptRoot ($entry.file -replace '/', '\')
        $image = [System.Drawing.Bitmap]::FromFile($imagePath)
        try {
            $maxWidth = $cellWidth - 24
            $maxHeight = $cellHeight - 45
            $scale = [Math]::Min($thumbScale, [Math]::Min([Math]::Floor($maxWidth / $image.Width), [Math]::Floor($maxHeight / $image.Height)))
            $scale = [Math]::Max(1, $scale)
            $drawWidth = $image.Width * $scale
            $drawHeight = $image.Height * $scale
            $drawX = ($column * $cellWidth) + [int](($cellWidth - $drawWidth) / 2)
            $drawY = ($row * $cellHeight) + 8
            $sheetGraphics.DrawImage($image, (New-Object System.Drawing.Rectangle($drawX, $drawY, $drawWidth, $drawHeight)), 0, 0, $image.Width, $image.Height, [System.Drawing.GraphicsUnit]::Pixel)
            $font = New-Object System.Drawing.Font('Consolas', 11, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
            $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 222, 235, 251))
            $sheetGraphics.DrawString($entry.file.Split('/')[-1], $font, $brush, ($column * $cellWidth) + 8, (($row + 1) * $cellHeight) - 25)
            $font.Dispose()
            $brush.Dispose()
        }
        finally {
            $image.Dispose()
        }
    }
}
finally {
    $sheetGraphics.Dispose()
}
$sheet.Save((Join-Path $previewRoot 'frostgruft-schnee-erweiterung-v1-overview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()

Write-Output ("Built {0} additive Frost Crypt snow variants in {1}" -f $manifestRows.Count, $PSScriptRoot)
