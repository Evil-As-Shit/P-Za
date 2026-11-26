param([string]$OutDir)
Add-Type -AssemblyName System.Drawing

# Each group: name, what it's for, colors light -> dark (name, hex).
$groups = @(
  @{ n='Outline'; u='outlines, darkest shadows'; c=@(@('Charcoal','2C2C2C'),@('Ink','222034'),@('Black','000000')) },
  @{ n='Steel'; u='sinks, ovens, tables, metal'; c=@(@('White','FFFFFF'),@('Steel White','DFE7EA'),@('Steel Light','BCC6CF'),@('Steel','9BADB7'),@('Steel Dark','6B6F80'),@('Steel Deep','464152')) },
  @{ n='Stone'; u='floor, warm greys'; c=@(@('Stone Light','DDD2B8'),@('Stone','AA9A80'),@('Stone Dark','7B705D'),@('Stone Deep','645949')) },
  @{ n='Slate'; u='walls, cool shadows'; c=@(@('Slate Light','B7B0BA'),@('Slate','847E87'),@('Slate Dark','6A6276'),@('Slate Deep','4A4452')) },
  @{ n='Wood'; u='racks, chairs, handles'; c=@(@('Wood Light','D9A066'),@('Wood','AE7A44'),@('Wood Mid','935F32'),@('Wood Dark','764A26'),@('Wood Deep','56361C')) },
  @{ n='Cardboard'; u='pizza boxes, supply cases'; c=@(@('Box Light','E8CFA0'),@('Box','D0AA87'),@('Box Dark','B08A62'),@('Box Deep','8A6A48')) },
  @{ n='Skin'; u='pawns and customers'; c=@(@('Skin 1','EFC6BC'),@('Skin 2','E9AFA2'),@('Skin 3','C0968C'),@('Skin 4','9C6B54'),@('Skin 5','6B4535'),@('Skin 6','3F2A22')) },
  @{ n='Staff Teal'; u='staff shirts, shop accent'; c=@(@('Teal Light','8ADBCB'),@('Teal','4AAB9C'),@('Teal Dark','017564'),@('Teal Deep','004038')) },
  @{ n='Sauce'; u='tomato sauce, red things'; c=@(@('Sauce Light','F07A5A'),@('Sauce','A53E2E'),@('Sauce Dark','810000'),@('Sauce Deep','4A0808')) },
  @{ n='Cheese'; u='cheese, yellow things'; c=@(@('Cheese Light','FFF4C2'),@('Cheese','FFD95A'),@('Cheese Melt','E8B030'),@('Cheese Dark','B07A1E')) },
  @{ n='Crust'; u='dough to burnt (doneness)'; c=@(@('Raw Dough','F5E6C8'),@('Crust Light','F3C090'),@('Crust Golden','D9944E'),@('Crust Well','A8642E'),@('Crust Burnt','5A3018')) },
  @{ n='Leaf'; u='basil, peppers, plants'; c=@(@('Leaf Light','A8E07A'),@('Leaf','5FB04A'),@('Leaf Dark','2F7A34'),@('Leaf Deep','18452A')) },
  @{ n='Blue'; u='water, glass, clean dishes'; c=@(@('Sky','CBDBFC'),@('Water','96D2E6'),@('Blue','639BFF'),@('Blue Dark','2878AA'),@('Navy','1B3F6E')) },
  @{ n='Purple'; u='accents, customer shirts'; c=@(@('Lilac','C8B8EE'),@('Purple','8A72D0'),@('Purple Dark','424782'),@('Purple Deep','26234A')) },
  @{ n='Pink'; u='accents, customer shirts'; c=@(@('Pink Pale','FFE0EF'),@('Pink','F49AC1'),@('Berry','C2457E'),@('Berry Dark','7A2350')) },
  @{ n='Grime'; u='dirt, spills, mop water'; c=@(@('Grime Light','B8A878'),@('Grime','8A7A50'),@('Grime Dark','5E5236'),@('Mud','3A3222')) },
  @{ n='UI Signals'; u='colorblind-safe: pair with an icon too'; c=@(@('Good (blue)','0072B2'),@('Info (sky)','56B4E9'),@('OK (teal)','009E73'),@('Caution (yellow)','F0E442'),@('Warn (orange)','E69F00'),@('Bad (vermillion)','D55E00'),@('Special (pink)','CC79A7')) }
)

function Get-Rgb([string]$h) { ,@([Convert]::ToInt32($h.Substring(0,2),16),[Convert]::ToInt32($h.Substring(2,2),16),[Convert]::ToInt32($h.Substring(4,2),16)) }
function Get-Lightness($rgb) {
  $lin = $rgb | ForEach-Object { $v = $_/255.0; if ($v -le 0.04045) { $v/12.92 } else { [math]::Pow(($v+0.055)/1.055,2.4) } }
  $y = 0.2126*$lin[0] + 0.7152*$lin[1] + 0.0722*$lin[2]
  if ($y -gt 0.008856) { [int][math]::Round(116*[math]::Pow($y,1/3)-16) } else { [int][math]::Round(903.3*$y) }
}

# GIMP palette (Aseprite reads the names).
$gpl = @('GIMP Palette','Name: Za','Columns: 8','#')
foreach ($g in $groups) { foreach ($c in $g.c) { $rgb = Get-Rgb $c[1]; $gpl += (("{0,3} {1,3} {2,3}`t{3} - {4}") -f $rgb[0],$rgb[1],$rgb[2],$g.n,$c[0]) } }
$gpl | Set-Content -Encoding ascii (Join-Path $OutDir 'za_palette.gpl')

# Reference sheet.
$sw = 96; $gap = 8; $labelW = 230; $rowH = $sw + 62; $pad = 20; $titleH = 70
$maxN = ($groups | ForEach-Object { $_.c.Count } | Measure-Object -Maximum).Maximum
$W = $pad*2 + $labelW + $maxN*($sw+$gap)
$H = $titleH + $groups.Count*$rowH + $pad
$bmp = New-Object System.Drawing.Bitmap ([int]$W),([int]$H)
$gr = [System.Drawing.Graphics]::FromImage($bmp)
$gr.TextRenderingHint = 'AntiAliasGridFit'
$gr.Clear([System.Drawing.Color]::FromArgb(250,248,244))
$fTitle = New-Object System.Drawing.Font 'Segoe UI',20,([System.Drawing.FontStyle]::Bold)
$fGroup = New-Object System.Drawing.Font 'Segoe UI',13,([System.Drawing.FontStyle]::Bold)
$fUse = New-Object System.Drawing.Font 'Segoe UI',9
$fName = New-Object System.Drawing.Font 'Segoe UI',9,([System.Drawing.FontStyle]::Bold)
$fHex = New-Object System.Drawing.Font 'Consolas',9
$dark = [System.Drawing.Brushes]::Black
$grey = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90,90,90))
$border = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60,60,60)),1
$gr.DrawString('Za palette', $fTitle, $dark, $pad, 12)
$gr.DrawString('Each ramp runs light to dark. The grey bar under a swatch is its brightness (L 0-100): if two bars look alike, those colors can blur together.', $fUse, $grey, $pad+150, 26)

$y = $titleH
foreach ($g in $groups) {
  $gr.DrawString($g.n, $fGroup, $dark, $pad, $y+18)
  $gr.DrawString($g.u, $fUse, $grey, (New-Object System.Drawing.RectangleF $pad,($y+44),($labelW-10),40))
  $x = $pad + $labelW
  foreach ($c in $g.c) {
    $rgb = Get-Rgb $c[1]; $L = Get-Lightness $rgb
    $col = [System.Drawing.Color]::FromArgb($rgb[0],$rgb[1],$rgb[2])
    $gv = [int][math]::Round(255*[math]::Pow(((($L+16)/116.0)),3))
    if ($L -le 8) { $gv = [int][math]::Round(255*($L/903.3)) }
    $gv = [math]::Max(0,[math]::Min(255,$gv))
    $gcol = [System.Drawing.Color]::FromArgb($gv,$gv,$gv)
    $gr.FillRectangle((New-Object System.Drawing.SolidBrush $col), $x, $y, $sw, $sw-18)
    $gr.FillRectangle((New-Object System.Drawing.SolidBrush $gcol), $x, $y+$sw-18, $sw, 18)
    $gr.DrawRectangle($border, $x, $y, $sw, $sw)
    $lb = if ($L -gt 55) { [System.Drawing.Brushes]::Black } else { [System.Drawing.Brushes]::White }
    $gr.DrawString("L $L", $fHex, $lb, $x+3, $y+$sw-17)
    $gr.DrawString($c[0], $fName, $dark, (New-Object System.Drawing.RectangleF $x,($y+$sw+3),($sw+4),18))
    $gr.DrawString('#'+$c[1], $fHex, $grey, $x, $y+$sw+19)
    $x += $sw + $gap
  }
  $y += $rowH
}
$bmp.Save((Join-Path $OutDir 'za_palette_reference.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$gr.Dispose(); $bmp.Dispose()

# Lightness check: warn when neighbours in a ramp are too close.
foreach ($g in $groups) {
  $Ls = $g.c | ForEach-Object { Get-Lightness (Get-Rgb $_[1]) }
  "{0,-12} {1}" -f $g.n, ($Ls -join ' ')
}
