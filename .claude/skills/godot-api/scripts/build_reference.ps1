# Builds the Godot API reference used by the godot-api skill.
# Runs the installed Godot's --doctool to dump its class reference, then turns each class
# into a compact text file (one line per method, property, signal, constant, ...) in ..\reference.
# Run again whenever the project moves to a new Godot version.
#
# Usage (from anywhere):
#   .\.claude\skills\godot-api\scripts\build_reference.ps1
# Set $env:GODOT to use a different Godot executable.

param([string]$Godot = $env:GODOT)

if (-not $Godot) {
    $Godot = "C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
}
if (-not (Test-Path $Godot)) { throw "Godot not found at $Godot. Set `$env:GODOT." }

$reference = Join-Path (Split-Path -Parent $PSScriptRoot) "reference"
$dump = Join-Path $env:TEMP ("godot_doctool_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $dump | Out-Null

$version = (& $Godot --version | Out-String).Trim()
Push-Location $dump
& $Godot --headless --doctool $dump | Out-Null
Pop-Location

$xmlFiles = @(Get-ChildItem $dump -Recurse -Filter *.xml | Where-Object { $_.Directory.Name -in @("classes", "doc_classes") })
if ($xmlFiles.Count -eq 0) { throw "Godot's doctool produced no class files." }

function Format-Type($node) {
    if ($node.enum) { return $node.enum }
    return $node.type
}

function Format-Params($node, [bool]$vararg) {
    $parts = foreach ($p in @($node.param)) {
        if (-not $p) { continue }
        $s = "$($p.name): $(Format-Type $p)"
        if ($p.HasAttribute("default")) { $s += " = $($p.default)" }
        $s
    }
    if ($vararg) { $parts = @($parts) + "..." }
    return ($parts -join ", ")
}

function Format-Callable($m, [string]$prefix) {
    $qualifiers = "$($m.qualifiers)"
    $vararg = $qualifiers -match "vararg"
    $ret = if ($m.return) { Format-Type $m.return } else { "void" }
    $line = "$ret $prefix$($m.name)($(Format-Params $m $vararg))"
    $q = ($qualifiers -split " " | Where-Object { $_ -and $_ -ne "vararg" }) -join " "
    if ($q) { $line += " $q" }
    return $line
}

if (Test-Path $reference) { Remove-Item -Recurse -Force $reference }
New-Item -ItemType Directory -Force $reference | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$index = New-Object System.Collections.Generic.List[string]

foreach ($file in $xmlFiles) {
    [xml]$doc = [IO.File]::ReadAllText($file.FullName)
    $c = $doc.class
    $out = New-Object System.Collections.Generic.List[string]
    $header = "# $($c.name)"
    if ($c.inherits) { $header += " extends $($c.inherits)" }
    $out.Add("$header  (Godot $version)")
    $index.Add(($header.Substring(2)))

    if ($c.constructors) {
        $out.Add(""); $out.Add("## Constructors")
        foreach ($m in @($c.constructors.constructor)) { $out.Add("$($m.name)($(Format-Params $m $false))") }
    }
    if ($c.members) {
        $out.Add(""); $out.Add("## Properties")
        foreach ($m in @($c.members.member)) {
            $line = "$(Format-Type $m) $($m.name)"
            if ($m.HasAttribute("default")) { $line += " = $($m.default)" }
            $access = @($m.setter, $m.getter | Where-Object { $_ }) -join " / "
            if ($access) { $line += "  [$access]" }
            if ($m.overrides) { $line += "  (overrides $($m.overrides))" }
            $out.Add($line)
        }
    }
    if ($c.methods) {
        $out.Add(""); $out.Add("## Methods")
        foreach ($m in @($c.methods.method)) { $out.Add((Format-Callable $m "")) }
    }
    if ($c.annotations) {
        $out.Add(""); $out.Add("## Annotations")
        foreach ($m in @($c.annotations.annotation)) {
            $vararg = "$($m.qualifiers)" -match "vararg"
            $out.Add("$($m.name)($(Format-Params $m $vararg))")
        }
    }
    if ($c.signals) {
        $out.Add(""); $out.Add("## Signals")
        foreach ($m in @($c.signals.signal)) { $out.Add("signal $($m.name)($(Format-Params $m $false))") }
    }
    if ($c.constants) {
        $plain = New-Object System.Collections.Generic.List[string]
        $enums = [ordered]@{}
        foreach ($k in @($c.constants.constant)) {
            if ($k.enum) {
                $key = if ($k.is_bitfield -eq "true") { "flags $($k.enum)" } else { "enum $($k.enum)" }
                if (-not $enums.Contains($key)) { $enums[$key] = New-Object System.Collections.Generic.List[string] }
                $enums[$key].Add("$($k.name) = $($k.value)")
            } else {
                $plain.Add("const $($k.name) = $($k.value)")
            }
        }
        if ($enums.Count) {
            $out.Add(""); $out.Add("## Enums")
            foreach ($e in $enums.Keys) { $out.Add("$e { $($enums[$e] -join ', ') }") }
        }
        if ($plain.Count) {
            $out.Add(""); $out.Add("## Constants")
            foreach ($l in $plain) { $out.Add($l) }
        }
    }
    if ($c.operators) {
        $out.Add(""); $out.Add("## Operators")
        foreach ($m in @($c.operators.operator)) { $out.Add((Format-Callable $m "")) }
    }
    if ($c.theme_items) {
        $out.Add(""); $out.Add("## Theme items")
        foreach ($t in @($c.theme_items.theme_item)) {
            $line = "$($t.data_type) $($t.name): $($t.type)"
            if ($t.HasAttribute("default")) { $line += " = $($t.default)" }
            $out.Add($line)
        }
    }

    [IO.File]::WriteAllText((Join-Path $reference "$($c.name).txt"), ($out -join "`n") + "`n", $utf8)
}

$sorted = $index | Sort-Object
[IO.File]::WriteAllText((Join-Path $reference "_classes.txt"), "# All classes (Godot $version)`n" + ($sorted -join "`n") + "`n", $utf8)
[IO.File]::WriteAllText((Join-Path $reference "VERSION.txt"), "$version`n", $utf8)
# Keep Godot's editor from scanning these files.
[IO.File]::WriteAllText((Join-Path $reference ".gdignore"), "", $utf8)

Remove-Item -Recurse -Force $dump
Write-Host "Wrote $($xmlFiles.Count) classes for Godot $version to $reference"
