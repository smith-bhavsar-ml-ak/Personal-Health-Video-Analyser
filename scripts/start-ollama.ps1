param([string]$OllamaUrl = "http://localhost:11434")

$null = curl.exe -sf "$OllamaUrl/api/tags" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Ollama already running on $OllamaUrl"
    exit 0
}

Write-Host "  Starting Ollama..."
Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden

Write-Host "  Waiting for Ollama to be ready..."
for ($i = 1; $i -le 10; $i++) {
    Start-Sleep -Seconds 2
    $null = curl.exe -sf "$OllamaUrl/api/tags" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Ollama ready."
        exit 0
    }
}

Write-Host "ERROR: Ollama failed to start."
exit 1
