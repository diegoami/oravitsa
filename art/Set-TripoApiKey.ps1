# Run locally. Input is masked; the key is never printed or put in shell history.
$secureTripoKey = Read-Host 'Tripo API key' -AsSecureString
$tripoCredential = [System.Net.NetworkCredential]::new('', $secureTripoKey)
try {
    if ([string]::IsNullOrWhiteSpace($tripoCredential.Password)) { throw 'The API key is empty.' }
    [Environment]::SetEnvironmentVariable('TRIPO_API_KEY', $tripoCredential.Password, 'User')
    $env:TRIPO_API_KEY = $tripoCredential.Password
    Write-Output 'Tripo API key configured for your Windows user. The trial runner can read it without restarting Codex.'
}
finally {
    $tripoCredential = $null
    $secureTripoKey.Dispose()
}
