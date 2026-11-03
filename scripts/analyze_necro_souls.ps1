[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$soulsRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$soulsData = Get-Content -LiteralPath (Join-Path $soulsRoot 'assets/data/talents.json') -Raw | ConvertFrom-Json
$soulsConfig = $soulsData.resources.necromancer
$soulsRates = @()
foreach ($spec in @('minion', 'curse', 'soul')) {
    $abilities = @($soulsData.talents.PSObject.Properties.Value | Where-Object { $_.spec -eq $spec -and $_.kind -in @('active','ultimate') })
    $rates = @($abilities | ForEach-Object { [pscustomobject]@{ id=$_.id; cost=[double]$_.cost; cooldown=[double]$_.cd; demand_per_second=[math]::Round([double]$_.cost/[double]$_.cd,3) } })
    $soulsRates += [pscustomobject]@{ branch=$spec; hypothetical_all_abilities_on_cooldown=[math]::Round(($rates | Measure-Object -Property demand_per_second -Sum).Sum,3); abilities=$rates }
}
# Conservative no-adds boss budget, base class only. It is a resource model,
# not a simulated or played boss kill, TTK measurement or DPS comparison.
$soulsSchedule = @(
    @{t=0; id='soul_14'}, @{t=4; id='soul_1'}, @{t=10; id='soul_1'},
    @{t=15; id='soul_11'}, @{t=24; id='soul_1'}, @{t=30; id='soul_1'},
    @{t=35; id='soul_11'}, @{t=44; id='soul_1'}, @{t=50; id='soul_1'}, @{t=55; id='soul_11'}
)
$soulsPool = [double]$soulsConfig.start
$soulsTime = 0.0
$soulsLastCast = @{}
$soulsTrace = @()
foreach ($action in $soulsSchedule) {
    $ability = $soulsData.talents.($action.id)
    $soulsPool = [math]::Min([double]$soulsConfig.max, $soulsPool + ([double]$action.t-$soulsTime)*[double]$soulsConfig.regen)
    if ($soulsPool -lt [double]$ability.cost) { throw "Budget exhausted at $($action.t) for $($action.id)" }
    if ($soulsLastCast.ContainsKey($action.id) -and [double]$action.t-$soulsLastCast[$action.id] -lt [double]$ability.cd) { throw 'Cooldown violation in resource model' }
    $soulsPool -= [double]$ability.cost
    $soulsLastCast[$action.id] = [double]$action.t
    $soulsTime = [double]$action.t
    $soulsTrace += [pscustomobject]@{ time=$soulsTime; talent=$action.id; cost=[double]$ability.cost; left=$soulsPool }
}
$soulsPool = [math]::Min([double]$soulsConfig.max,$soulsPool+(60.0-$soulsTime)*[double]$soulsConfig.regen)
$soulsReport = [pscustomobject]@{
    scope='Deterministic resource arithmetic only; no earned run, DPS/TTK, long-term balance or performance verdict'
    base_capacity=$soulsConfig.max; start=$soulsConfig.start; combat_per_second=$soulsConfig.regen
    normal_kill=$soulsConfig.per_kill; boss_model_seconds=60; boss_model_kills=0
    boss_model_trace=$soulsTrace; boss_model_final_souls=$soulsPool; cooldown_demand=$soulsRates
    missing='Independent numerical balance targets and longitudinal play telemetry; registry constants/formulas and system GDD are empty/absent'
}
$soulsOut = Join-Path $soulsRoot 'output/necro-souls-aggro/resource-model.json'
$soulsReport | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $soulsOut -Encoding utf8
Write-Output "SOULS_MODEL valid=true no_adds_boss_budget_final=$soulsPool output=$soulsOut"
