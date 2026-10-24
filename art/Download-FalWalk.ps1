$ErrorActionPreference = 'Stop'
$output = Join-Path (Split-Path -Parent $PSScriptRoot) 'build/fal-walk'
$result = Get-Content -Raw -LiteralPath (Join-Path $output 'result.json') | ConvertFrom-Json
$files = @{
    'rigged.glb' = $result.rigged_character_glb
    'walking.glb' = $result.basic_animations.walking_glb
    'walking-armature.glb' = $result.basic_animations.walking_armature_glb
}
if (!$files['walking.glb']) { throw 'Rig completed without an included walking clip. Inspect result.json before any further paid call.' }
foreach ($name in $files.Keys) {
    $file = $files[$name]
    if (!$file) { continue }
    if (([Uri]$file.url).Scheme -ne 'https') { throw 'Output URL is not HTTPS.' }
    $target = Join-Path $output $name
    Invoke-WebRequest -UseBasicParsing -Uri $file.url -OutFile $target -TimeoutSec 180
    $reader = [IO.BinaryReader]::new([IO.File]::OpenRead($target))
    try { $magic = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) }
    finally { $reader.Dispose() }
    if ($magic -ne 'glTF') { throw "Output $name is not GLB." }
    Get-Item -LiteralPath $target | Select-Object Name,Length
}
