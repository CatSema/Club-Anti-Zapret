# PowerShell script for launching Discord with restrictions bypass
# Architecture: automatic download, launch and bypass completion
# Version: zapret-discord-youtube-1.8.5

param(
    [string]$DiscordPath = $null,
    [string]$BypassScript = "general (FAKE TLS AUTO).bat"
)

# Adding duplicate protection
$mutexName = "DiscordBypass_SingleInstance"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)

if (!$mutex.WaitOne(100)) {
    Write-Host "Another instance of the script is already running"
    exit 1
}

# Configuration
$ReleaseUrl = "https://github.com/Flowseal/zapret-discord-youtube/releases/download/1.8.5/zapret-discord-youtube-1.8.5.zip"
$TempDir = Join-Path $env:TEMP "DiscordBypass_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$ZipPath = Join-Path $TempDir "zapret-discord-youtube-1.8.5.zip"
$ExtractDir = Join-Path $TempDir "zapret-discord-youtube-1.8.5"

# Function to create and show modal notification with Discord dark theme and modern design
function Show-ModalNotification {
    param(
        [string]$Message = "Подготовка Discord к запуску...",
        [ref]$FormReference
    )
    
    # Set UTF-8 encoding for proper Cyrillic display
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    # Add assembly for Windows Forms
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    # Discord dark theme colors
    $darkBackground = [System.Drawing.Color]::FromArgb(47, 49, 54)      # #2F3136 - Discord background
    $darkText = [System.Drawing.Color]::FromArgb(220, 221, 222)         # #DCDDDE - Discord text
    $darkAccent = [System.Drawing.Color]::FromArgb(88, 101, 242)        # #5865F2 - Discord Blurple
    
    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Discord"
    $form.Size = New-Object System.Drawing.Size(400, 150)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true
    $form.FormBorderStyle = "None"  # Modern borderless design
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.ShowInTaskbar = $false
    $form.BackColor = $darkBackground
    
    # Add rounded corners effect (optional, for Windows 11 style)
    try {
        # This requires Windows 10 version 1809 or later
        Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class RoundedCorners {
            [DllImport("dwmapi.dll")]
            public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
            public const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
            public const int DWMWCP_ROUND = 2;
        }
"@
        $hwnd = $form.Handle
        $preference = 2  # DWMWCP_ROUND
        [RoundedCorners]::DwmSetWindowAttribute($hwnd, 33, [ref]$preference, 4)
    }
    catch {
        # Ignore if rounded corners are not supported
    }
    
    # Create accent bar at the top (Discord style)
    $accentBar = New-Object System.Windows.Forms.Panel
    $accentBar.Size = New-Object System.Drawing.Size(400, 4)
    $accentBar.Location = New-Object System.Drawing.Point(0, 0)
    $accentBar.BackColor = $darkAccent
    $form.Controls.Add($accentBar)
    
    # Create label with message
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
    $label.ForeColor = $darkText
    $label.Location = New-Object System.Drawing.Point(20, 40)
    $label.Size = New-Object System.Drawing.Size(360, 80)
    $label.AutoSize = $false
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $form.Controls.Add($label)
    
    # Variables for dragging
    $script:isDragging = $false
    $script:dragStartPoint = New-Object System.Drawing.Point(0, 0)
    
    # Add mouse down event for dragging
    $form.Add_MouseDown({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $script:isDragging = $true
            $script:dragStartPoint = $e.Location
        }
    })
    
    # Add mouse move event for dragging
    $form.Add_MouseMove({
        param($sender, $e)
        if ($script:isDragging) {
            $currentLocation = $form.Location
            $newX = $currentLocation.X + ($e.X - $script:dragStartPoint.X)
            $newY = $currentLocation.Y + ($e.Y - $script:dragStartPoint.Y)
            $form.Location = New-Object System.Drawing.Point($newX, $newY)
        }
    })
    
    # Add mouse up event to stop dragging
    $form.Add_MouseUp({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $script:isDragging = $false
        }
    })
    
    # Allow dragging from label as well
    $label.Add_MouseDown({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $script:isDragging = $true
            # Calculate relative position to form
            $formLocation = $form.PointToClient([System.Windows.Forms.Cursor]::Position)
            $script:dragStartPoint = $formLocation
        }
    })
    
    $label.Add_MouseMove({
        param($sender, $e)
        if ($script:isDragging) {
            $currentScreenPos = [System.Windows.Forms.Cursor]::Position
            $currentLocation = $form.Location
            $formClientPoint = $form.PointToClient($currentScreenPos)
            $newX = $currentLocation.X + ($formClientPoint.X - $script:dragStartPoint.X)
            $newY = $currentLocation.Y + ($formClientPoint.Y - $script:dragStartPoint.Y)
            $form.Location = New-Object System.Drawing.Point($newX, $newY)
        }
    })
    
    $label.Add_MouseUp({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $script:isDragging = $false
        }
    })
    
    # Store form reference
    $FormReference.Value = $form
    
    # Show form
    $form.Show() | Out-Null
    $form.Refresh()
    
    # Return form object
    return $form
}

# Function to hide modal notification
function Hide-ModalNotification {
    param(
        [System.Windows.Forms.Form]$Form
    )
    
    if ($Form) {
        $Form.Close()
        $Form.Dispose()
    }
}
# Create temporary directory before using it
if (!(Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

# Setting maximum download size (50 MB)
$maxDownloadSize = 50MB

# Function to wait for Discord processes to fully terminate
function WaitForDiscordTermination {
    param([int[]]$DiscordProcessIds = @())
    
    Write-LogMessage "Waiting for Discord processes to fully terminate..." "INFO"
    
    $maxWaitTime = 60  # Increased maximum wait time to 60 seconds
    $waitedTime = 0
    $checkInterval = 1 # Check every 1 second for more responsive checking
    
    while ($waitedTime -lt $maxWaitTime) {
        $discordRunning = $false
        
        # Comprehensive check for Discord processes by name patterns
        $discordProcs = Get-Process | Where-Object {
            ($_.ProcessName -match "^Discord(\.exe)?$" -or
             $_.ProcessName -match "^Discord.*$" -or
             ($_.Path -and $_.Path -match "\\Discord(\\|\.exe$)")) -and
            !$_.HasExited
        } | Select-Object -ExpandProperty Id
        
        # Additionally check for Discord-related processes that might have different names but are part of Discord installation
        $discordProcs += Get-Process | Where-Object {
            $_.Path -and $_.Path -match "\\Discord" -and
            !$_.HasExited
        } | Select-Object -ExpandProperty Id
        
        # Check for Discord processes by command line arguments (more comprehensive check)
        $allProcesses = Get-CimInstance -ClassName Win32_Process
        $discordByCmdLine = $allProcesses | Where-Object {
            $_.CommandLine -and $_.CommandLine -match "Discord" -and
            ($_.Name -notmatch "^Discord(\.exe)?$" -or $_.Name -match "^Discord.*$")
        } | Select-Object -ExpandProperty ProcessId
        
        if ($discordByCmdLine) {
            $discordProcs += $discordByCmdLine
        }
        
        # Remove duplicates
        $discordProcs = $discordProcs | Sort-Object -Unique
        
        if ($discordProcs.Count -gt 0) {
            $discordRunning = $true
            Write-LogMessage "Found $($discordProcs.Count) Discord-related processes still running: $($discordProcs -join ', ')" "INFO"
        }
        
        # Check for processes from Discord installation directory
        if ($DiscordPath) {
            $discordDir = Split-Path $DiscordPath -Parent
            $procsFromDiscordDir = Get-Process | Where-Object {
                $_.Path -and $_.Path.StartsWith($discordDir, 'OrdinalIgnoreCase') -and
                ($_.ProcessName -match "^Discord(\.exe)?$" -or
                 $_.ProcessName -match "^Discord.*$" -or
                 $_.Path -match "\\Discord(\\|\.exe$)") -and
                !$_.HasExited
            } | Select-Object -ExpandProperty Id
            
            if ($procsFromDiscordDir.Count -gt 0) {
                $discordRunning = $true
                Write-LogMessage "Found $($procsFromDiscordDir.Count) processes from Discord directory still running: $($procsFromDiscordDir -join ', ')" "INFO"
            }
        }
        
        # Check for any previously identified Discord process IDs
        foreach ($processId in $DiscordProcessIds) {
            try {
                $proc = Get-Process -Id $processId -ErrorAction Stop
                if (!$proc.HasExited) {
                    $discordRunning = $true
                    Write-LogMessage "Previously identified Discord process (ID: $processId) still running" "INFO"
                }
            }
            catch {
                # Process already terminated
            }
        }
        
        # Additional check: look for any processes that contain "Discord" in their executable path
        $discordPathMatches = Get-Process | Where-Object {
            $_.Path -and $_.Path -match "AppData.*Discord|Local.*Discord|Program.*Discord" -and
            !$_.HasExited
        } | Select-Object -ExpandProperty Id
        
        if ($discordPathMatches.Count -gt 0) {
            $discordRunning = $true
            Write-LogMessage "Found $($discordPathMatches.Count) processes with Discord in path still running: $($discordPathMatches -join ', ')" "INFO"
        }
        
        if (!$discordRunning) {
            Write-LogMessage "All Discord processes have terminated" "INFO"
            return $true
        }
        
        Start-Sleep -Seconds $checkInterval
        $waitedTime += $checkInterval
    }
    
    Write-LogMessage "Timeout waiting for Discord processes to terminate" "WARN"
    return $false
}

# Function to wait for bypass-related processes to fully terminate
function WaitForBypassTermination {
    param([int]$BypassProcessId)
    
    Write-LogMessage "Waiting for bypass processes to fully terminate..." "INFO"
    
    $maxWaitTime = 30  # Maximum wait time in seconds
    $waitedTime = 0
    $checkInterval = 2  # Check every 2 seconds
    
    while ($waitedTime -lt $maxWaitTime) {
        $bypassRunning = $false
        
        # Check if the main bypass process is still running
        if ($BypassProcessId) {
            try {
                $bypassProc = Get-Process -Id $BypassProcessId -ErrorAction Stop
                if (!$bypassProc.HasExited) {
                    $bypassRunning = $true
                    Write-LogMessage "Main bypass process (ID: $BypassProcessId) still running" "INFO"
                }
            }
            catch {
                # Process already terminated
            }
        }
        
        # Check for any bypass processes from the extract directory (excluding Discord processes)
        $extractDirProcs = Get-Process | Where-Object {
            $_.Path -and $_.Path.StartsWith($ExtractDir, 'OrdinalIgnoreCase') -and $_.ProcessName -notmatch "^Discord(\.exe)?$" -and !$_.HasExited
        }
        
        if ($extractDirProcs) {
            $bypassRunning = $true
            Write-LogMessage "Found $($extractDirProcs.Count) bypass-related processes still running from extract directory" "INFO"
        }
        
        # Check for WinDivert-related processes (excluding Discord processes)
        $divertProcs = Get-Process | Where-Object {
            $_.ProcessName -match "divert|WinDivert|zapret" -and $_.ProcessName -notmatch "^Discord(\.exe)?$" -and !$_.HasExited
        }
        
        if ($divertProcs) {
            $bypassRunning = $true
            Write-LogMessage "Found $($divertProcs.Count) WinDivert-related processes still running" "INFO"
        }
        
        if (!$bypassRunning) {
            Write-LogMessage "All bypass-related processes have terminated" "INFO"
            return $true
        }
        
        Start-Sleep -Seconds $checkInterval
        $waitedTime += $checkInterval
    }
    
    Write-LogMessage "Timeout waiting for bypass processes to terminate" "WARN"
    return $false
}

# Function to check zapret initialization
function Test-ZapretInitialized {
    param($ExtractDir, $ProcessId)
    
    # Checking network activity on standard ports
    try {
        $netstat = netstat -ano | Select-String ":8080|:1080|:3128"
        if ($netstat) { return $true }
    }
    catch {
        Write-LogMessage "Error checking network activity: $($_.Exception.Message)" "WARN"
    }
    
    # Checking for WinDivert files which are critical indicators
    $divertFiles = @("WinDivert64.sys", "WinDivert.dll", "windivert.exe")
    foreach ($divertFile in $divertFiles) {
        $foundFiles = Get-ChildItem -Path $ExtractDir -Name $divertFile -Recurse -ErrorAction SilentlyContinue
        if ($foundFiles) {
            # Check if these files are actually loaded/active
            foreach ($file in $foundFiles) {
                $fullPath = Join-Path $ExtractDir $file
                # If file exists and is not locked (meaning it's not actively used), initialization might not be complete
                try {
                    $fileInfo = Get-Item $fullPath -ErrorAction Stop
                    return $true
                }
                catch {
                    # File might be locked by system, which indicates active usage
                    continue
                }
            }
        }
    }
    
    # Checking log files and process indicators
    $logIndicators = @("*.log", "*.pid", "winws.exe", "zapret.exe", "divert-*")
    foreach ($pattern in $logIndicators) {
        if (Get-ChildItem -Path $ExtractDir -Filter $pattern -Recurse -ErrorAction SilentlyContinue) {
            return $true
        }
    }
    
    # Checking child processes
    try {
        $childProcesses = Get-CimInstance Win32_Process | Where-Object {
            $_.ParentProcessId -eq $ProcessId
        }
        
        if ($childProcesses.Count -gt 0) {
            return $true
        }
    }
    catch {
        Write-LogMessage "Error checking child processes: $($_.Exception.Message)" "WARN"
    }
    
    # Additional check: look for running bypass processes from extract directory (excluding Discord)
    $runningProcs = Get-Process | Where-Object {
        $_.Path -and $_.Path.StartsWith($ExtractDir, 'OrdinalIgnoreCase') -and $_.ProcessName -notmatch "^Discord(\.exe)?$"
    }
    
    return $runningProcs.Count -gt 0
}

# Structured error logging
function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Output to console with color
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
        default { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # Write to file (optional)
    if ($env:DISCORD_BYPASS_LOG) {
        Add-Content -Path $env:DISCORD_BYPASS_LOG -Value $logEntry
    }
}

# Improved function to modify batch file for hidden execution of winws.exe
function Modify-BatchFileForHiddenExecution {
    param(
        [string]$BatchFilePath
    )
    
    Write-LogMessage "Modifying batch file for hidden execution: $BatchFilePath" "INFO"
    
    try {
        # Read the content of the batch file
        $batchContent = Get-Content -Path $BatchFilePath -Encoding Default -Raw
        
        # Check if modification already exists
        if ($batchContent -match 'start\s+""\s+/b\s+"%BIN%winws\.exe"') {
            Write-LogMessage "Batch file already modified for hidden execution" "INFO"
            return $true
        }
        
        # Find the winws.exe launch command
        # Pattern: start "title" /min "%BIN%winws.exe" <arguments>
        if ($batchContent -match 'start\s+"[^"]*"\s+/min\s+"%BIN%winws\.exe"') {
            Write-LogMessage "Found winws.exe start command, modifying for hidden execution..." "INFO"
            
            # Create a backup of the original file
            $backupPath = "$BatchFilePath.backup"
            Copy-Item -Path $BatchFilePath -Destination $backupPath -Force
            Write-LogMessage "Created backup: $backupPath" "INFO"
            
            # Replace the start command - simply change /min to /b for background execution
            # /b starts application without creating a new window
            $modifiedContent = $batchContent -replace 'start\s+"[^"]*"\s+/min\s+"%BIN%winws\.exe"', 'start "" /b "%BIN%winws.exe"'
            
            # Write modified content back to file
            Set-Content -Path $BatchFilePath -Value $modifiedContent -Encoding Default -Force
            
            Write-LogMessage "Successfully modified batch file for hidden execution" "INFO"
            return $true
            
        } else {
            Write-LogMessage "Could not find winws.exe start command in batch file" "WARN"
            return $false
        }
    }
    catch {
        Write-LogMessage "Error modifying batch file: $($_.Exception.Message)" "ERROR"
        
        # Restore from backup in case of error
        $backupPath = "$BatchFilePath.backup"
        if (Test-Path $backupPath) {
            Copy-Item -Path $BatchFilePath -Destination $backupPath -Force
            Write-LogMessage "Restored batch file from backup" "INFO"
        }
        
        return $false
    }
}

# Error handling
$ErrorActionPreference = "Stop"

# Show modal notification at the very beginning
$notificationForm = $null
Show-ModalNotification -Message "Подготовка Discord к запуску..." -FormReference ([ref]$notificationForm)

try {
    # Check for and terminate any existing bypass processes before starting new ones
    Write-LogMessage "Checking for existing bypass processes..." "INFO"
    
    # Find and terminate any existing bypass-related processes
    $existingBypassProcs = Get-Process | Where-Object {
        $_.ProcessName -match "winws|zapret|divert|WinDivert|windivert" -or
        ($_.Path -and $_.Path -match "\\zapret|\\windivert")
    }
    
    if ($existingBypassProcs) {
        Write-LogMessage "Found $($existingBypassProcs.Count) existing bypass processes (PID: $($existingBypassProcs.Id -join ', '))" "WARN"
        Write-LogMessage "Force closing existing bypass processes..." "INFO"
        
        $existingBypassProcs | ForEach-Object {
            $proc = $_
            try {
                # Check if process has already exited before attempting to terminate
                if (!$proc.HasExited) {
                    Write-LogMessage "Closing bypass process (ID: $($proc.Id), Name: $($proc.ProcessName))" "INFO"
                    $proc.CloseMainWindow()
                } else {
                    Write-LogMessage "Bypass process (ID: $($proc.Id)) already terminated" "INFO"
                }
            }
            catch {
                Write-LogMessage "Error closing bypass process (ID: $($proc.Id)): $($_.Exception.Message)" "WARN"
            }
        }
        
        Start-Sleep 3  # Wait to allow processes to close gracefully
        
        # Double-check that processes have actually closed
        $stillRunning = $existingBypassProcs | Where-Object {
            try {
                $p = Get-Process -Id $_.Id -ErrorAction Stop
                return !$p.HasExited
            }
            catch {
                # Process no longer exists
                return $false
            }
        }
        
        if ($stillRunning) {
            Write-LogMessage "Some bypass processes did not close gracefully, attempting force termination" "WARN"
            $stillRunning | ForEach-Object {
                $proc = $_
                try {
                    # Check if process has already exited before attempting to terminate
                    if (!$proc.HasExited) {
                        $proc.Kill()
                        Write-LogMessage "Force terminated bypass process (ID: $($proc.Id), Name: $($proc.ProcessName))" "INFO"
                    } else {
                        Write-LogMessage "Bypass process (ID: $($proc.Id)) already terminated" "INFO"
                    }
                }
                catch {
                    Write-LogMessage "Failed to terminate bypass process (ID: $($proc.Id))" "WARN"
                    # If Kill() fails, try Stop-Process as fallback
                    try {
                        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                        Write-LogMessage "Force terminated bypass process using Stop-Process (ID: $($proc.Id))" "INFO"
                    }
                    catch {
                        Write-LogMessage "Failed to terminate bypass process with Stop-Process (ID: $($proc.Id))" "WARN"
                    }
                }
            }
            Start-Sleep 2
        }
        
        Write-LogMessage "Existing bypass processes terminated" "INFO"
    } else {
        Write-LogMessage "No existing bypass processes found" "INFO"
    }

    # Download archive
    Write-LogMessage "Downloading bypass archive..." "INFO"
    try {
        # Check URL availability
        $request = [System.Net.WebRequest]::Create($ReleaseUrl)
        $request.Method = "HEAD"
        $response = $request.GetResponse()
        
        # Check file size
        $fileSize = $response.ContentLength
        if ($fileSize -gt $maxDownloadSize) {
            throw "File size exceeds the allowed limit: $fileSize bytes"
        }
        
        Write-LogMessage "Archive size: $fileSize bytes" "INFO"
        $response.Close()
        
        # Download file using Invoke-WebRequest with timeout
        Invoke-WebRequest -Uri $ReleaseUrl -OutFile $ZipPath -TimeoutSec 30
    }
    catch {
        Write-LogMessage "Error downloading archive: $($_.Exception.Message)" "ERROR"
        throw "Error downloading archive: $($_.Exception.Message)"
    }
    
    # Check that the file was actually downloaded
    if (!(Test-Path $ZipPath)) {
        throw "File was not downloaded: $ZipPath"
    }
    
    # Check file size
    $zipInfo = Get-Item $ZipPath
    if ($zipInfo.Length -eq 0) {
        throw "Downloaded file is empty: $ZipPath"
    }
    
    Write-LogMessage "Archive successfully downloaded: $($zipInfo.Length) bytes" "INFO"

    # Extract archive
    Write-LogMessage "Extracting archive..." "INFO"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        $entryCount = 0
        foreach ($entry in $zip.Entries) {
            $destinationPath = Join-Path $ExtractDir $entry.FullName
            $destinationDir = Split-Path $destinationPath -Parent
            
            if (!(Test-Path $destinationDir)) {
                New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            }
            
            if (!$entry.FullName.EndsWith('/')) {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destinationPath, $true)
                $entryCount++
            }
        }
        $zip.Dispose()
        Write-LogMessage "Extracted $entryCount files from archive" "INFO"
    }
    catch {
        Write-LogMessage "Error extracting archive: $($_.Exception.Message)" "ERROR"
        throw "Error extracting archive: $($_.Exception.Message)"
    }
    
    # Check that the extraction directory contains files
    if ((Get-ChildItem -Path $ExtractDir -Recurse | Measure-Object).Count -eq 0) {
        throw "Archive contains no files or was not extracted correctly"
    }

    # Launch bypass script in background mode
    Write-LogMessage "Launching bypass script..." "INFO"
    $bypassScriptPath = Join-Path $ExtractDir $BypassScript
    
    if (!(Test-Path $bypassScriptPath)) {
        throw "Bypass script not found: $bypassScriptPath"
    }

    # Modify batch file for hidden execution
    Write-LogMessage "Preparing batch file for hidden execution..." "INFO"
    $modifyResult = Modify-BatchFileForHiddenExecution -BatchFilePath $bypassScriptPath
    if (!$modifyResult) {
        Write-LogMessage "Failed to modify batch file, continuing with default execution" "WARN"
    }

    # Launch bypass in background mode without window display
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "cmd.exe"
    $processInfo.Arguments = "/c `"$bypassScriptPath`""
    $processInfo.WorkingDirectory = $ExtractDir
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true

    try {
        $bypassProcess = [System.Diagnostics.Process]::Start($processInfo)
        
        # Save process ID for more accurate tracking
        $bypassProcessId = $bypassProcess.Id
        Write-LogMessage "Bypass process launched with ID: $bypassProcessId" "INFO"
    }
    catch {
        Write-LogMessage "Error launching bypass script: $($_.Exception.Message)" "ERROR"
        throw "Error launching bypass script: $($_.Exception.Message)"
    }

    # Wait for bypass initialization
    Write-LogMessage "Waiting for bypass initialization..." "INFO"
    
    # Check that bypass process is still running
    if (!$bypassProcess.HasExited) {
        Write-LogMessage "Bypass process is running, waiting for initialization..." "INFO"
        
        # Wait up to 60 seconds or until initialization signal (increased from 30)
        $initComplete = $false
        $maxWaitTime = 60
        $waitedTime = 0
        $checkInterval = 2
        
        while ($waitedTime -lt $maxWaitTime -and !$initComplete) {
            Start-Sleep -Seconds $checkInterval
            $waitedTime += $checkInterval
            
            # Check if process is still running
            if ($bypassProcess.HasExited) {
                # Process might have exited but system services could still be running
                # Check if bypass is actually initialized despite process exit
                $initComplete = Test-ZapretInitialized -ExtractDir $ExtractDir -ProcessId $bypassProcessId
                if ($initComplete) {
                    Write-LogMessage "Bypass initialized but process terminated (system services running)" "INFO"
                } else {
                    Write-Warning "Bypass process terminated before initialization completed"
                }
                break
            }
            
            # Use improved initialization check function
            $initComplete = Test-ZapretInitialized -ExtractDir $ExtractDir -ProcessId $bypassProcessId
            
            if ($initComplete) {
                Write-LogMessage "Bypass initialized in $($waitedTime) seconds" "INFO"
            }
        }
        
        if (!$initComplete) {
            Write-LogMessage "Bypass initialization timeout ($maxWaitTime seconds)" "WARN"
            # Check one more time if bypass is actually working despite timeout
            $initComplete = Test-ZapretInitialized -ExtractDir $ExtractDir -ProcessId $bypassProcessId
            if ($initComplete) {
                Write-LogMessage "Bypass is active despite timeout" "INFO"
            } else {
                Write-LogMessage "Bypass might not be active, continuing anyway" "WARN"
            }
        }
    } else {
        Write-LogMessage "Bypass process terminated earlier than expected" "WARN"
        # Check if bypass is still active despite process exit
        $initComplete = Test-ZapretInitialized -ExtractDir $ExtractDir -ProcessId $bypassProcessId
        if ($initComplete) {
            Write-LogMessage "Bypass services still active despite process exit" "INFO"
        }
    }

    # Determine Discord path
    if ([string]::IsNullOrEmpty($DiscordPath)) {
        # Search standard Discord paths
        $standardPaths = @(
            "${env:ProgramFiles}\Discord\Discord.exe",
            "${env:ProgramFiles(x86)}\Discord\Discord.exe",
            "$env:LOCALAPPDATA\Discord\app-*\Discord.exe",  # For portable version
            "${env:ProgramFiles}\Discord PTB\Discord.exe",
            "${env:ProgramFiles(x86)}\Discord PTB\Discord.exe",
            "$env:LOCALAPPDATA\DiscordPTB\app-*\Discord.exe",
            "${env:ProgramFiles}\Discord Canary\Discord.exe",
            "${env:ProgramFiles(x86)}\Discord Canary\Discord.exe",
            "$env:LOCALAPPDATA\DiscordCanary\app-*\Discord.exe"
        )

        foreach ($pattern in $standardPaths) {
            $matchingPaths = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Sort-Object Name -Descending
            if ($matchingPaths) {
                $DiscordPath = $matchingPaths[0].FullName
                break
            }
        }

        if ([string]::IsNullOrEmpty($DiscordPath)) {
            throw "Discord not found in standard directories"
        }
    }

    # Check that Discord file exists
    if (!(Test-Path $DiscordPath)) {
        throw "Discord file not found: $DiscordPath"
    }

    # Check that this is an executable file
    $discordFileInfo = Get-Item $DiscordPath
    if ($discordFileInfo.Extension -ne ".exe") {
        throw "Discord file is not executable: $DiscordPath"
    }

    # More accurate check for existing Discord processes
    $existingDiscord = Get-Process | Where-Object {
        ($_.ProcessName -match "^Discord(\.exe)?$" -or ($_.Path -and $_.Path -match "\\Discord(\\|\.exe$)")) -and
        !$_.HasExited
    }
    
    if ($existingDiscord) {
        Write-LogMessage "Discord is already running (PID: $($existingDiscord.Id -join ', '))" "WARN"
        Write-LogMessage "Force closing existing processes..." "INFO"
        $existingDiscord | ForEach-Object {
            $proc = $_
            try {
                # Check if process has already exited before attempting to terminate
                if (!$proc.HasExited) {
                    Write-LogMessage "Closing Discord process (ID: $($proc.Id))" "INFO"
                    $proc.CloseMainWindow()
                } else {
                    Write-LogMessage "Discord process (ID: $($proc.Id)) already terminated" "INFO"
                }
            }
            catch {
                Write-LogMessage "Error closing Discord process (ID: $($proc.Id)): $($_.Exception.Message)" "WARN"
            }
        }
        
        Start-Sleep 5  # Increased sleep time to allow processes to close properly
        
        # Double-check that processes have actually closed
        $stillRunning = $existingDiscord | Where-Object {
            try {
                $p = Get-Process -Id $_.Id -ErrorAction Stop
                return !$p.HasExited
            }
            catch {
                # Process no longer exists
                return $false
            }
        }
        
        if ($stillRunning) {
            Write-LogMessage "Some Discord processes did not close gracefully, attempting force termination" "WARN"
            $stillRunning | ForEach-Object {
                $proc = $_
                try {
                    # Check if process has already exited before attempting to terminate
                    if (!$proc.HasExited) {
                        $proc.Kill()
                        Write-LogMessage "Force terminated Discord process (ID: $($proc.Id))" "INFO"
                    } else {
                        Write-LogMessage "Discord process (ID: $($proc.Id)) already terminated" "INFO"
                    }
                }
                catch {
                    Write-LogMessage "Failed to terminate Discord process (ID: $($proc.Id))" "WARN"
                    # If Kill() fails, try Stop-Process as fallback
                    try {
                        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                        Write-LogMessage "Force terminated Discord process using Stop-Process (ID: $($proc.Id))" "INFO"
                    }
                    catch {
                        Write-LogMessage "Failed to terminate Discord process with Stop-Process (ID: $($proc.Id))" "WARN"
                    }
                }
            }
            Start-Sleep 2
        }
    }
    
    # Hide modal notification after Discord is launched
    if ($notificationForm) {
        Hide-ModalNotification -Form $notificationForm
    }

    # Launch Discord
    Write-LogMessage "Launching Discord via Update.exe..." "INFO"
    try {
        # Determine Update.exe path
        $updateExePath = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"
        
        # Check Update.exe existence
        if (!(Test-Path $updateExePath)) {
            throw "Update.exe not found: $updateExePath"
        }
        
        # Launch Discord via Update.exe with --processStart argument
        $discordProcess = Start-Process -FilePath $updateExePath -ArgumentList "--processStart Discord.exe" -PassThru
        Write-LogMessage "Discord launched with ID: $($discordProcess.Id) via Update.exe" "INFO"
    }
    catch {
        Write-LogMessage "Error launching Discord: $($_.Exception.Message)" "ERROR"
        throw "Error launching Discord: $($_.Exception.Message)"
    }

    # Wait for Discord to finish
    Write-LogMessage "Waiting for Discord to finish..." "INFO"
    $discordProcess.WaitForExit()
    Write-LogMessage "Discord finished with exit code: $($discordProcess.ExitCode)" "INFO"
    
    # Wait for bypass processes to finish naturally after Discord closes
    Start-Sleep -Seconds 3

    # After Discord finishes, wait a bit before terminating bypass processes
    Write-LogMessage "Discord finished, preparing to terminate bypass..." "INFO"
    Start-Sleep -Seconds 2
}
catch {
    # Hide notification in case of error
    if ($notificationForm) {
        Hide-ModalNotification -Form $notificationForm
    }

    Write-LogMessage "Error: $($_.Exception.Message)" "ERROR"
    # In case of error, no cleanup is performed as per requirements
    # Temporary files will remain on disk and be cleaned up by the system automatically
    # Re-throwing exception for proper handling
    throw
}
finally {
    # Terminate bypass process if it's still running
    if ($bypassProcess) {
        try {
            # Check if process has already exited before attempting to terminate
            if (!$bypassProcess.HasExited) {
                # First, try graceful termination
                $bypassProcess.CloseMainWindow()
                if (!$bypassProcess.WaitForExit(5000)) {
                    # If graceful termination fails, force kill
                    $bypassProcess.Kill()
                    $bypassProcess.WaitForExit(200)
                }
            }
        }
        catch {
            # Try to terminate process via system command
            try {
                # Check if process still exists before attempting to stop
                if ($bypassProcessId -and (Get-Process -Id $bypassProcessId -ErrorAction SilentlyContinue)) {
                    Stop-Process -Id $bypassProcessId -Force -ErrorAction Stop
                }
            }
            catch {
            }
        }
    }
    
    # Check for and terminate any WinDivert-related bypass processes (excluding Discord)
    $divertProcs = Get-Process | Where-Object {
        $_.ProcessName -match "divert|WinDivert|zapret" -and $_.ProcessName -notmatch "^Discord(\.exe)?$"
    }
    
    if ($divertProcs) {
        foreach ($proc in $divertProcs) {
            try {
                # Check if process has already exited before attempting to terminate
                if (!$proc.HasExited) {
                    $proc.Kill()
                    $proc.WaitForExit(200)
                }
            }
            catch {
                try {
                    # If Kill() fails, try Stop-Process as fallback
                    # Check again if process exists before attempting to stop
                    if (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue) {
                        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                    }
                }
                catch {
                }
            }
        }
    }
    
    # Release mutex
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}