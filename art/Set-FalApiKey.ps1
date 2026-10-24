# Run locally. Masked input avoids printing the key or placing it in shell history.
$secureFalKey = Read-Host 'Paste your fal.ai API key (input is hidden)' -AsSecureString
$falCredential = [System.Net.NetworkCredential]::new('', $secureFalKey)
try {
    if ([string]::IsNullOrWhiteSpace($falCredential.Password)) { throw 'The API key is empty.' }
    [Environment]::SetEnvironmentVariable('FAL_KEY', $falCredential.Password.Trim(), 'User')
    $env:FAL_KEY = $falCredential.Password.Trim()
    Write-Output 'FAL_KEY configured for your Windows user. The key has not been printed or saved in the repository.'
}
finally {
    $falCredential = $null
    $secureFalKey.Dispose()
}
