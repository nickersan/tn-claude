<#
.SYNOPSIS
  Per-module JaCoCo coverage across the tn and project repos, from each module's last build.

.DESCRIPTION
  Reads target/site/jacoco/jacoco.csv in every module under -Roots and prints instruction, line and branch coverage with the age
  of the report, worst line coverage first. Modules with a pom.xml but no report are listed as not measured. Reports are only as
  current as the last `mvn verify`; the Age column says how old. -Classes also lists classes below -Below percent line coverage.

.EXAMPLE
  ./coverage.ps1
  ./coverage.ps1 -Classes -Below 80
#>
param(
  [string[]]$Roots = @('X:\Projects\tn', 'X:\Projects\okayat'),
  [switch]$Classes,
  [int]$Below = 100
)

function Percent($covered, $missed)
{
  $total = $covered + $missed
  if ($total -eq 0) { return $null }
  return [math]::Round(100.0 * $covered / $total, 1)
}

$rows = @()
$unmeasured = @()
$weak = @()

foreach ($root in $Roots)
{
  foreach ($module in Get-ChildItem $root -Directory)
  {
    if (-not (Test-Path (Join-Path $module.FullName 'pom.xml'))) { continue }

    $csv = Join-Path $module.FullName 'target\site\jacoco\jacoco.csv'
    if (-not (Test-Path $csv)) { $unmeasured += $module.Name; continue }

    $data = Import-Csv $csv
    $sum = { param($column) ($data | Measure-Object -Property $column -Sum).Sum }
    $age = [int]((Get-Date) - (Get-Item $csv).LastWriteTime).TotalDays

    $rows += [pscustomobject]@{
      Module = $module.Name
      Instr  = Percent (& $sum 'INSTRUCTION_COVERED') (& $sum 'INSTRUCTION_MISSED')
      Lines  = Percent (& $sum 'LINE_COVERED') (& $sum 'LINE_MISSED')
      Branch = Percent (& $sum 'BRANCH_COVERED') (& $sum 'BRANCH_MISSED')
      Missed = [int](& $sum 'LINE_MISSED')
      Age    = "${age}d"
    }

    foreach ($class in $data)
    {
      $line = Percent ([int]$class.LINE_COVERED) ([int]$class.LINE_MISSED)
      if ($null -ne $line -and $line -lt $Below) { $weak += [pscustomobject]@{ Module = $module.Name; Class = "$($class.PACKAGE).$($class.CLASS)"; Lines = $line; Missed = [int]$class.LINE_MISSED } }
    }
  }
}

$rows | Sort-Object { if ($null -eq $_.Lines) { 101 } else { $_.Lines } } | Format-Table -AutoSize
if ($unmeasured) { Write-Host "Not measured (no jacoco report): $($unmeasured -join ', ')" }
if ($Classes) { $weak | Sort-Object Lines, Module | Format-Table -AutoSize }
