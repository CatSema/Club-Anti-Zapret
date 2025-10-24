# Тестовый скрипт для проверки функциональности DiscordBypass.ps1
# Этот скрипт проверяет основные функции обхода ограничений

param(
    [string]$TestMode = "full"  # full, download, extract, bypass_only
)

Write-Host "=== Тестирование скрипта DiscordBypass.ps1 ===" -ForegroundColor Green

# Тест 1: Проверка загрузки архива
if ($TestMode -eq "full" -or $TestMode -eq "download") {
    Write-Host "`n1. Проверка загрузки архива..." -ForegroundColor Yellow
    
    $testTempDir = Join-Path $env:TEMP "DiscordBypass_Test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $testZipPath = Join-Path $testTempDir "test_download.zip"
    $releaseUrl = "https://github.com/Flowseal/zapret-discord-youtube/releases/download/1.8.5/zapret-discord-youtube-1.8.5.zip"
    
    try {
        if (!(Test-Path $testTempDir)) {
            New-Item -ItemType Directory -Path $testTempDir -Force | Out-Null
        }
        
        Write-Host "  Загрузка архива..."
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($releaseUrl, $testZipPath)
        
        if (Test-Path $testZipPath) {
            $zipInfo = Get-Item $testZipPath
            if ($zipInfo.Length -gt 0) {
                Write-Host "  ✓ Загрузка прошла успешно: $($zipInfo.Length) байт" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Загруженный файл пуст" -ForegroundColor Red
            }
        } else {
            Write-Host "  ✗ Файл не был загружен" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ✗ Ошибка загрузки: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        if (Test-Path $testTempDir) {
            Remove-Item $testTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Тест 2: Проверка извлечения архива
if ($TestMode -eq "full" -or $TestMode -eq "extract") {
    Write-Host "`n2. Проверка извлечения архива..." -ForegroundColor Yellow
    
    $testTempDir = Join-Path $env:TEMP "DiscordBypass_Test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $testZipPath = Join-Path $testTempDir "test_extract.zip"
    $extractDir = Join-Path $testTempDir "extracted"
    $releaseUrl = "https://github.com/Flowseal/zapret-discord-youtube/releases/download/1.8.5/zapret-discord-youtube-1.8.5.zip"
    
    try {
        if (!(Test-Path $testTempDir)) {
            New-Item -ItemType Directory -Path $testTempDir -Force | Out-Null
        }
        
        Write-Host "  Загрузка архива для теста извлечения..."
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($releaseUrl, $testZipPath)
        
        Write-Host "  Извлечение архива..."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($testZipPath)
        foreach ($entry in $zip.Entries) {
            $destinationPath = Join-Path $extractDir $entry.FullName
            $destinationDir = Split-Path $destinationPath -Parent
            
            if (!(Test-Path $destinationDir)) {
                New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            }
            
            if (!$entry.FullName.EndsWith('/')) {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destinationPath, $true)
            }
        }
        $zip.Dispose()
        
        $extractedItems = Get-ChildItem -Path $extractDir -Recurse -ErrorAction SilentlyContinue
        $itemCount = ($extractedItems | Measure-Object).Count
        
        if ($itemCount -gt 0) {
            Write-Host "  ✓ Извлечение прошло успешно: $itemCount файлов" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Архив не содержит файлов или не был корректно извлечен" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ✗ Ошибка извлечения: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        if (Test-Path $testTempDir) {
            Remove-Item $testTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Тест 3: Проверка наличия необходимых скриптов обхода
if ($TestMode -eq "full" -or $TestMode -eq "bypass_only") {
    Write-Host "`n3. Проверка наличия скриптов обхода..." -ForegroundColor Yellow
    
    $testTempDir = Join-Path $env:TEMP "DiscordBypass_Test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $testZipPath = Join-Path $testTempDir "test_bypass.zip"
    $extractDir = Join-Path $testTempDir "extracted"
    $releaseUrl = "https://github.com/Flowseal/zapret-discord-youtube/releases/download/1.8.5/zapret-discord-youtube-1.8.5.zip"
    
    try {
        if (!(Test-Path $testTempDir)) {
            New-Item -ItemType Directory -Path $testTempDir -Force | Out-Null
        }
        
        Write-Host "  Загрузка архива..."
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($releaseUrl, $testZipPath)
        
        Write-Host "  Извлечение архива..."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($testZipPath)
        foreach ($entry in $zip.Entries) {
            $destinationPath = Join-Path $extractDir $entry.FullName
            $destinationDir = Split-Path $destinationPath -Parent
            
            if (!(Test-Path $destinationDir)) {
                New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            }
            
            if (!$entry.FullName.EndsWith('/')) {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destinationPath, $true)
            }
        }
        $zip.Dispose()
        
        # Проверяем наличие основных скриптов обхода
        $bypassScripts = @("general (FAKE TLS AUTO).bat", "general.bat", "windows_service_installer.bat")
        $foundScripts = @()
        
        foreach ($script in $bypassScripts) {
            $scriptPath = Join-Path $extractDir $script
            if (Test-Path $scriptPath) {
                $foundScripts += $script
                Write-Host "  ✓ Найден скрипт: $script" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ Скрипт не найден: $script" -ForegroundColor Yellow
            }
        }
        
        if ($foundScripts.Count -gt 0) {
            Write-Host "  ✓ Найдено скриптов обхода: $($foundScripts.Count)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Не найдено ни одного скрипта обхода" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ✗ Ошибка проверки скриптов: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        if (Test-Path $testTempDir) {
            Remove-Item $testTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "`n=== Тестирование завершено ===" -ForegroundColor Green