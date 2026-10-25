param(
    [string]$Blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe',
    [string]$Godot = 'godot.cmd'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$pilotOutput = Join-Path $projectRoot 'build/blender-walk-pilot'
Push-Location $projectRoot
try {
    & $Blender --background --factory-startup --python art/render_walk_pilot.py -- --output $pilotOutput
    if ($LASTEXITCODE -ne 0) { throw 'Blender render failed.' }
    & $Blender --background --disable-autoexec (Join-Path $pilotOutput 'oravitsa-walk-pilot.blend') --python art/validate_walk_pilot.py
    if ($LASTEXITCODE -ne 0 -or !(Test-Path (Join-Path $pilotOutput 'validation.json'))) { throw 'Walk validation failed.' }
    & $Godot --headless --path $projectRoot --script art/package_walk_pilot.gd --log-file (Join-Path $pilotOutput 'package.log') -- $pilotOutput
    if ($LASTEXITCODE -ne 0 -or !(Test-Path (Join-Path $pilotOutput 'southeast-atlas.png'))) { throw 'Sprite packaging failed.' }
    & $Godot --headless --path $projectRoot --script art/preview_walk_pilot.gd --quit-after 12 --log-file (Join-Path $pilotOutput 'godot-check.log') -- $pilotOutput
    if ($LASTEXITCODE -ne 0) { throw 'Godot preview failed.' }
    Copy-Item -LiteralPath art/preview_walk_pilot.html -Destination (Join-Path $pilotOutput 'index.html')
    Copy-Item -LiteralPath scenes/forest_2d/art/oravitsa_walk_se.png -Destination (Join-Path $pilotOutput 'reference.png')
    if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
        & ffmpeg -y -hide_banner -loglevel error -framerate 10 -i (Join-Path $pilotOutput 'frames/se-%02d.png') -filter_complex '[0:v]split[a][b];[a]palettegen=reserve_transparent=1:stats_mode=full[p];[b][p]paletteuse=alpha_threshold=128' -loop 0 (Join-Path $pilotOutput 'pilot.gif')
        if ($LASTEXITCODE -ne 0) { throw 'GIF preview failed.' }
    }
    Write-Output "Walk pilot: $pilotOutput"
}
finally { Pop-Location }
