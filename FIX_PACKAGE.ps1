$ErrorActionPreference = "Stop"

Write-Host "Fixing Package Path..."

# Paths
$baseDir = "android\app\src\main\kotlin"
$wrongPath = "$baseDir\com\example\ransh_app"
$rightPath = "$baseDir\com\ransh\app"
$correctPackage = "package com.ransh.app"

# Create correct directory
if (-not (Test-Path $rightPath)) {
    New-Item -ItemType Directory -Force -Path $rightPath | Out-Null
}

# Move MainActivity.kt
if (Test-Path "$wrongPath\MainActivity.kt") {
    Move-Item "$wrongPath\MainActivity.kt" "$rightPath\MainActivity.kt" -Force
    Write-Host "Moved MainActivity.kt"
}

# Update MainActivity.kt content
$ktFile = "$rightPath\MainActivity.kt"
if (Test-Path $ktFile) {
    (Get-Content $ktFile) -replace "package com.example.ransh_app", "package com.ransh.app" | Set-Content $ktFile
    Write-Host "Updated MainActivity.kt package declaration"
}

# Clean up wrong directory
if (Test-Path "$baseDir\com\example") {
    Remove-Item "$baseDir\com\example" -Recurse -Force
    Write-Host "Removed incorrect path"
}

Write-Host "Package Fix Complete!"
