param([string]$OllamaUrl = "http://localhost:11434")

$curl = if ($IsWindows) { "curl.exe" } else { "curl" }

& $curl -sf "$OllamaUrl/api/tags" 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Ollama already running on $OllamaUrl"
    exit 0
}

Write-Host "  Starting Ollama..."
if ($IsWindows) {
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
} else {
    Start-Process -FilePath "ollama" -ArgumentList "serve" -RedirectStandardOutput "/dev/null" -RedirectStandardError "/dev/null"
}

Write-Host "  Waiting for Ollama to be ready..."
for ($i = 1; $i -le 10; $i++) {
    Start-Sleep -Seconds 2
    & $curl -sf "$OllamaUrl/api/tags" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Ollama ready."
        exit 0
    }
}

Write-Host "ERROR: Ollama failed to start."
exit 1
