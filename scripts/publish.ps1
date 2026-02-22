# Nuclear'd - Build and Publish to Roblox
# Usage: powershell -ExecutionPolicy Bypass -File scripts/publish.ps1

$ErrorActionPreference = "Stop"

# Fetch credentials from Hive store
$apiKey = (Invoke-RestMethod -Uri "http://100.93.55.100:8743/credentials/get/spin0580/ROBLOX_API_KEY").value
$universeId = (Invoke-RestMethod -Uri "http://100.93.55.100:8743/credentials/get/spin0580/ROBLOX_UNIVERSE_ID").value
$placeId = (Invoke-RestMethod -Uri "http://100.93.55.100:8743/credentials/get/nucleard/ROBLOX_PLACE_ID").value

if (-not $apiKey -or -not $universeId -or -not $placeId) {
    Write-Host "ERROR: Missing credentials. Check Hive credential store." -ForegroundColor Red
    exit 1
}

$buildFile = Join-Path $PSScriptRoot "..\game.rbxl"

# Build with Rojo
Write-Host "Building with Rojo..." -ForegroundColor Cyan
Push-Location (Join-Path $PSScriptRoot "..")
rojo build -o game.rbxl
Pop-Location

if (-not (Test-Path $buildFile)) {
    Write-Host "ERROR: Build failed - game.rbxl not found" -ForegroundColor Red
    exit 1
}

$fileBytes = [System.IO.File]::ReadAllBytes($buildFile)
Write-Host "Built game.rbxl ($($fileBytes.Length) bytes)" -ForegroundColor Green

# Publish via Open Cloud API
$url = "https://apis.roblox.com/universes/v1/$universeId/places/$placeId/versions?versionType=Published"

$headers = @{
    "x-api-key"    = $apiKey
    "Content-Type" = "application/octet-stream"
}

Write-Host "Publishing to Universe $universeId, Place $placeId..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $fileBytes
    Write-Host "SUCCESS! Published version: $($response.versionNumber)" -ForegroundColor Green
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host "Response: $($reader.ReadToEnd())" -ForegroundColor Red
    }
    exit 1
}
