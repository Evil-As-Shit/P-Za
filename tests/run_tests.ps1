# Runs every tests/test_*.gd headless and reports which pass. A test fails if it says so,
# exits with an error, or prints any engine error (script errors, leaks at exit).
# Tests named test_visual_*.gd check rendered pixels, so they run with a window instead.
#
# Usage (from the project folder):
#   .\tests\run_tests.ps1                  # all tests
#   .\tests\run_tests.ps1 single_order     # tests whose name contains "single_order"
#   .\tests\run_tests.ps1 -Quiet           # print only failures and the summary
#   .\tests\run_tests.ps1 -Detail oven     # failures also show the last 40 lines of output
# Set $env:GODOT to use a different Godot executable.

param([string]$Filter = "", [switch]$Quiet, [switch]$Detail)

$godot = $env:GODOT
if (-not $godot) {
    $godot = "C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
}
$project = Split-Path -Parent $PSScriptRoot
$failed = 0
$tests = Get-ChildItem (Join-Path $PSScriptRoot "test_*.gd") | Where-Object { $_.Name -ne "test_base.gd" -and $_.BaseName -like "*$Filter*" }

foreach ($test in $tests) {
    $start = Get-Date
    $godotArgs = @("--path", $project, "--fixed-fps", "60", "--script", "res://tests/$($test.Name)")
    if ($test.BaseName -notlike "test_visual_*") {
        $godotArgs = @("--headless") + $godotArgs
    }
    # "$_" turns stderr records into plain lines, so engine errors start with "ERROR:".
    $output = & $godot $godotArgs 2>&1 | ForEach-Object { "$_" } | Out-String
    $code = $LASTEXITCODE
    $seconds = [int]((Get-Date) - $start).TotalSeconds
    $errors = $output -split "`n" | Where-Object { $_ -match "SCRIPT ERROR|^ERROR:|leaked" }
    $result = ($output -split "`n" | Where-Object { $_ -match "^(PASS|FAIL)" } | Select-Object -First 1)
    if ($code -eq 0 -and -not $errors -and $result -match "^PASS") {
        if (-not $Quiet) {
            Write-Host "ok    $($test.BaseName) ($seconds s): $($result.Trim())" -ForegroundColor Green
        }
    } else {
        $failed++
        Write-Host "FAIL  $($test.BaseName) ($seconds s)" -ForegroundColor Red
        if ($result) { Write-Host "      $($result.Trim())" }
        if ($code -ne 0 -and -not $result) { Write-Host "      exited with code $code" }
        $errors | Select-Object -First 8 | ForEach-Object { Write-Host "      $($_.Trim())" }
        if ($Detail) {
            Write-Host "      --- last 40 lines of output ---"
            $output.TrimEnd() -split "`n" | Select-Object -Last 40 | ForEach-Object { Write-Host "      $($_.TrimEnd())" }
        }
    }
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "All $($tests.Count) tests passed." -ForegroundColor Green
} else {
    Write-Host "$failed of $($tests.Count) tests failed." -ForegroundColor Red
}
exit $failed
