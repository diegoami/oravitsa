param([string]$Output = (Join-Path (Split-Path -Parent $PSScriptRoot) 'build/fal-tripo-trial'))
$ErrorActionPreference = 'Stop'
$result = Get-Content -Raw -LiteralPath (Join-Path $Output 'result.json') | ConvertFrom-Json
$model = $result.model_urls.glb
if (!$model) { $model = $result.model_mesh }
if (!$model -or !([Uri]$model.url).IsAbsoluteUri -or ([Uri]$model.url).Scheme -ne 'https') { throw 'Missing HTTPS model URL.' }
$target = Join-Path $Output 'candidate.glb'
Invoke-WebRequest -UseBasicParsing -Uri $model.url -OutFile $target -TimeoutSec 180
$reader = [IO.BinaryReader]::new([IO.File]::OpenRead($target))
try { $magic = [Text.Encoding]::ASCII.GetString($reader.ReadBytes(4)) }
finally { $reader.Dispose() }
if ($magic -ne 'glTF') { throw 'Downloaded file is not GLB.' }
if ($result.rendered_image.url) {
    if (([Uri]$result.rendered_image.url).Scheme -ne 'https') { throw 'Preview URL is not HTTPS.' }
    Invoke-WebRequest -UseBasicParsing -Uri $result.rendered_image.url -OutFile (Join-Path $Output 'provider-preview.png') -TimeoutSec 90
}
Get-Item -LiteralPath $target | Select-Object Name,Length
