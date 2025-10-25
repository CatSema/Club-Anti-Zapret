# Configuration
$GitHubScriptUrl = "https://raw.githubusercontent.com/CatSema/Club-Anti-Zapret/refs/heads/main/DiscordEnhancedConnectivity.ps1"
$LocalScriptDir = "$env:LOCALAPPDATA\DiscordEnhancedConnectivity"
$LocalScriptPath = "$LocalScriptDir\DiscordEnhancedConnectivity.ps1"
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = "$DesktopPath\Discord.lnk"
$PowerShellPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

Write-Host "=== Discord Enhanced Connectivity Setup ===" -ForegroundColor Cyan

# Step 1: Create directory if it doesn't exist
Write-Host "`n[1/5] Creating script directory..." -ForegroundColor Yellow
if (!(Test-Path $LocalScriptDir)) {
    New-Item -ItemType Directory -Path $LocalScriptDir -Force | Out-Null
    Write-Host "[OK] Directory created: $LocalScriptDir" -ForegroundColor Green
} else {
    Write-Host "[OK] Directory already exists: $LocalScriptDir" -ForegroundColor Green
}

# Step 2: Download script from GitHub
Write-Host "`n[2/5] Downloading DiscordEnhancedConnectivity.ps1 from GitHub..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $GitHubScriptUrl -OutFile $LocalScriptPath -UseBasicParsing -TimeoutSec 30

    # Verify successful download
    if ((Test-Path $LocalScriptPath) -and (Get-Item $LocalScriptPath).Length -gt 0) {
        $fileSize = [math]::Round((Get-Item $LocalScriptPath).Length / 1KB, 2)
        Write-Host "[OK] Script downloaded successfully ($fileSize KB)" -ForegroundColor Green
        Write-Host "  Path: $LocalScriptPath" -ForegroundColor Gray
    } else {
        throw "File was not downloaded or is empty"
    }
} catch {
    Write-Host "[ERROR] Download failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Function to check and convert file encoding to UTF-8 with BOM if necessary
function Convert-ToUTF8WithBOM {
    param(
        [string]$FilePath
    )
    
    # Read the file as bytes to check for BOM
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    
    # Check if file starts with UTF-8 BOM (0xEF, 0xBB, 0xBF)
    $hasBOM = ($bytes.Length -ge 3) -and
              ($bytes[0] -eq 0xEF) -and
              ($bytes[1] -eq 0xBB) -and
              ($bytes[2] -eq 0xBF)
    
    if (-not $hasBOM) {
        Write-Host "[INFO] File is not encoded in UTF-8 with BOM, converting..." -ForegroundColor Yellow
        
        # Read the content with auto-detection of encoding
        $content = Get-Content -Path $FilePath -Encoding UTF8 -Raw
        
        # Write the content back with UTF-8 BOM
        [System.IO.File]::WriteAllText($FilePath, $content, [System.Text.Encoding]::UTF8)
        
        Write-Host "[OK] File converted to UTF-8 with BOM: $FilePath" -ForegroundColor Green
    } else {
        Write-Host "[OK] File is already encoded in UTF-8 with BOM: $FilePath" -ForegroundColor Green
    }
}

# Check and convert encoding if necessary
Write-Host "`n[2.5/5] Checking file encoding..." -ForegroundColor Yellow
Convert-ToUTF8WithBOM -FilePath $LocalScriptPath

# Step 3: Remove existing Discord shortcut
Write-Host "`n[3/5] Removing existing Discord shortcut..." -ForegroundColor Yellow
if (Test-Path $ShortcutPath) {
    try {
        Remove-Item -Path $ShortcutPath -Force
        Write-Host "[OK] Old Discord shortcut removed" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to remove old shortcut: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "[INFO] Existing Discord shortcut not found" -ForegroundColor Gray
}

# Step 4: Find Discord icon
Write-Host "`n[4/5] Searching for Discord icon..." -ForegroundColor Yellow
$DiscordIconPath = $null

# Search for Discord in various locations
$discordSearchPaths = @(
    "$env:LOCALAPPDATA\Discord\app-*\Discord.exe",
    "$env:LOCALAPPDATA\DiscordPTB\app-*\Discord.exe",
    "$env:LOCALAPPDATA\DiscordCanary\app-*\Discord.exe",
    "${env:ProgramFiles}\Discord\Discord.exe",
    "${env:ProgramFiles(x86)}\Discord\Discord.exe"
)

foreach ($searchPath in $discordSearchPaths) {
    $foundPath = Get-ChildItem -Path $searchPath -ErrorAction SilentlyContinue |
                 Sort-Object Name -Descending |
                 Select-Object -First 1 -ExpandProperty FullName

    if ($foundPath) {
        $DiscordIconPath = $foundPath
        Write-Host "[OK] Discord icon found: $DiscordIconPath" -ForegroundColor Green
        break
    }
}

if (!$DiscordIconPath) {
    Write-Host "[WARN] Discord not found, using system icon" -ForegroundColor Yellow
    $DiscordIconPath = "C:\Windows\System32\shell32.dll"
    $iconIndex = 13
} else {
    $iconIndex = 0
}

# Step 5: Create new shortcut
Write-Host "`n[5/5] Creating new Discord shortcut..." -ForegroundColor Yellow
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)

    # Configure shortcut
    $Shortcut.TargetPath = $PowerShellPath
    $Shortcut.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$LocalScriptPath`""
    $Shortcut.WorkingDirectory = $LocalScriptDir
    $Shortcut.Description = "Discord with enhanced connectivity"
    $Shortcut.IconLocation = "$DiscordIconPath, $iconIndex"

    # Save shortcut
    $Shortcut.Save()

    Write-Host "[OK] Shortcut created successfully on desktop" -ForegroundColor Green
    Write-Host "  Path: $ShortcutPath" -ForegroundColor Gray

} catch {
    Write-Host "[ERROR] Failed to create shortcut: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host "`n=== Setup completed successfully ===" -ForegroundColor Cyan
Write-Host "`nInformation:" -ForegroundColor White
Write-Host "  Script: $LocalScriptPath" -ForegroundColor Gray
Write-Host "  Shortcut: $ShortcutPath" -ForegroundColor Gray
Write-Host "  Icon: $DiscordIconPath" -ForegroundColor Gray
Write-Host "`nYou can now launch Discord using the desktop shortcut!" -ForegroundColor Green
