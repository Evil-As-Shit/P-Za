# Runs every tests/test_*.gd headless and reports which pass. A test fails if it says so,
# exits with an error, or prints any engine error (script errors, leaks at exit).
#
# Usage (from the project folder):
#   .\tests\run_tests.ps1                  # all tests
#   .\tests\run_tests.ps1 single_order     # tests whose name contains "single_order"
# Set $env:GODOT to use a different Godot executable.

param([string]$Filter = "")

$godot = $env:GODOT
if (-not $godot) {
    $godot = "C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
}
$project = Split-Path -Parent $PSScriptRoot
$failed = 0
$tests = Get-ChildItem (Join-Path $PSScriptRoot "test_*.gd") | Where-Object { $_.Name -ne "test_base.gd" -and $_.BaseName -like "*$Filter*" }

foreach ($test in $tests) {
    $start = Get-Date
    $output = & $godot --headless --path $project --fixed-fps 60 --script "res://tests/$($test.Name)" 2>&1 | Out-String
    $code = $LASTEXITCODE
    $seconds = [int]((Get-Date) - $start).TotalSeconds
    $errors = $output -split "`n" | Where-Object { $_ -match "SCRIPT ERROR|^ERROR:|leaked" }
    $result = ($output -split "`n" | Where-Object { $_ -match "^(PASS|FAIL)" } | Select-Object -First 1)
    if ($code -eq 0 -and -not $errors -and $result -match "^PASS") {
        Write-Host "ok    $($test.BaseName) ($seconds s): $($result.Trim())" -ForegroundColor Green
    } else {
        $failed++
        Write-Host "FAIL  $($test.BaseName) ($seconds s)" -ForegroundColor Red
        if ($result) { Write-Host "      $($result.Trim())" }
        $errors | Select-Object -First 8 | ForEach-Object { Write-Host "      $($_.Trim())" }
    }
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "All $($tests.Count) tests passed." -ForegroundColor Green
} else {
    Write-Host "$failed of $($tests.Count) tests failed." -ForegroundColor Red
}
exit $failed
