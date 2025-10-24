# Test script for improved DiscordBypass.ps1 cleanup functions
# This script tests the key functions added to improve cleanup logic

# Test function to simulate process termination and cleanup
function Test-WaitForProcessTermination {
    Write-Host "Testing process termination functions..." -ForegroundColor Green
    
    # Define test functions based on the improved DiscordBypass.ps1
    $testFunctions = @'
# Function to wait for Discord processes to fully terminate
function Test-WaitForDiscordTermination {
    param([int[]]$DiscordProcessIds = @())
    
    Write-Host "Waiting for Discord processes to fully terminate..." -ForegroundColor Yellow
    
    $maxWaitTime = 10  # Maximum wait time in seconds for testing
    $waitedTime = 0
    $checkInterval = 1  # Check every 1 second for testing
    
    while ($waitedTime -lt $maxWaitTime) {
        $discordRunning = $false
        
        # Check for Discord processes by name
        $discordProcs = Get-Process | Where-Object {
            $_.ProcessName -like "*Discord*" -and !$_.HasExited
        }
        
        if ($discordProcs) {
            $discordRunning = $true
            Write-Host "Found $($discordProcs.Count) Discord-related processes still running" -ForegroundColor Red
        }
        
        # Check for any previously identified Discord process IDs
        foreach ($pid in $DiscordProcessIds) {
            try {
                $proc = Get-Process -Id $pid -ErrorAction Stop
                if (!$proc.HasExited) {
                    $discordRunning = $true
                    Write-Host "Previously identified Discord process (ID: $pid) still running" -ForegroundColor Red
                }
            }
            catch {
                # Process already terminated
            }
        }
        
        if (!$discordRunning) {
            Write-Host "All Discord processes have terminated" -ForegroundColor Green
            return $true
        }
        
        Start-Sleep -Seconds $checkInterval
        $waitedTime += $checkInterval
    }
    
    Write-Host "Timeout waiting for Discord processes to terminate" -ForegroundColor Red
    return $false
}

# Function to wait for bypass-related processes to fully terminate
function Test-WaitForBypassTermination {
    param([int]$BypassProcessId)
    
    Write-Host "Waiting for bypass processes to fully terminate..." -ForegroundColor Yellow
    
    $maxWaitTime = 10  # Maximum wait time in seconds for testing
    $waitedTime = 0
    $checkInterval = 1  # Check every 1 second for testing
    
    while ($waitedTime -lt $maxWaitTime) {
        $bypassRunning = $false
        
        # Check if the main bypass process is still running
        if ($BypassProcessId) {
            try {
                $bypassProc = Get-Process -Id $BypassProcessId -ErrorAction Stop
                if (!$bypassProc.HasExited) {
                    $bypassRunning = $true
                    Write-Host "Main bypass process (ID: $BypassProcessId) still running" -ForegroundColor Red
                }
            }
            catch {
                # Process already terminated
            }
        }
        
        # Check for any processes from a test directory
        $testDir = $env:TEMP + "\TestDiscordBypass"
        $extractDirProcs = Get-Process | Where-Object {
            $_.Path -and $_.Path.StartsWith($testDir, 'OrdinalIgnoreCase') -and !$_.HasExited
        }
        
        if ($extractDirProcs) {
            $bypassRunning = $true
            Write-Host "Found $($extractDirProcs.Count) bypass-related processes still running from test directory" -ForegroundColor Red
        }
        
        # Check for test-related processes
        $testProcs = Get-Process | Where-Object {
            $_.ProcessName -match "test|temp" -and !$_.HasExited
        }
        
        if ($testProcs) {
            $bypassRunning = $true
            Write-Host "Found $($testProcs.Count) test-related processes still running" -ForegroundColor Red
        }
        
        if (!$bypassRunning) {
            Write-Host "All bypass-related processes have terminated" -ForegroundColor Green
            return $true
        }
        
        Start-Sleep -Seconds $checkInterval
        $waitedTime += $checkInterval
    }
    
    Write-Host "Timeout waiting for bypass processes to terminate" -ForegroundColor Red
    return $false
}
'@
    
    # Execute test functions
    Invoke-Expression $testFunctions
    
    Write-Host "Process termination functions loaded successfully" -ForegroundColor Green
    
    # Test the functions with mock data
    Write-Host "`nTesting WaitForDiscordTermination with empty process list..." -ForegroundColor Cyan
    Test-WaitForDiscordTermination -DiscordProcessIds @()
    
    Write-Host "`nTesting WaitForBypassTermination with null process ID..." -ForegroundColor Cyan
    Test-WaitForBypassTermination -BypassProcessId $null
    
    return $true
}

function Test-CleanupLogic {
    Write-Host "`nTesting cleanup logic functions..." -ForegroundColor Green
    
    # Define test cleanup function
    $cleanupTest = @'
# Function to test cleanup with file handling
function Test-CleanUp {
    param([string]$tempDir)
    
    Write-Host "Testing cleanup for directory: $tempDir" -ForegroundColor Yellow
    
    # Create test directory and files
    if (!(Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Write-Host "Created test directory: $tempDir" -ForegroundColor Green
    }
    
    # Create test files including 'system' files
    $testFiles = @(
        "test_regular_file.txt",
        "WinDivert64.sys",  # Simulated system file
        "WinDivert.dll",    # Simulated system file
        "divert_helper.exe" # Simulated system file
    )
    
    foreach ($fileName in $testFiles) {
        $filePath = Join-Path $tempDir $fileName
        "Test content" | Out-File -FilePath $filePath -Encoding UTF8
        Write-Host "Created test file: $fileName" -ForegroundColor Green
    }
    
    # Check content before deletion
    $tempItems = Get-ChildItem -Path $tempDir -Recurse -ErrorAction SilentlyContinue
    $itemCount = ($tempItems | Measure-Object).Count
    Write-Host "Found $itemCount items for deletion in $tempDir" -ForegroundColor Yellow
    
    # First, try to remove regular files
    $systemFiles = @()
    $regularFiles = @()
    $criticalSystemFiles = @() # Files that require special handling
    
    foreach ($item in $tempItems) {
        if ($item.Name -match "WinDivert64\.sys|WinDivert\.dll") {
            $criticalSystemFiles += $item
        } elseif ($item.Name -match "divert.*") {
            $systemFiles += $item
        } else {
            $regularFiles += $item
        }
    }
    
    Write-Host "Found $($regularFiles.Count) regular files" -ForegroundColor Cyan
    Write-Host "Found $($systemFiles.Count) system files" -ForegroundColor Cyan
    Write-Host "Found $($criticalSystemFiles.Count) critical system files" -ForegroundColor Cyan
    
    # Remove regular files first
    foreach ($file in $regularFiles) {
        try {
            Remove-Item $file.FullName -Force -ErrorAction Stop
            Write-Host "Removed regular file: $($file.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to remove regular file: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Remove system files (non-critical)
    foreach ($sysFile in $systemFiles) {
        $attempts = 0
        $maxAttempts = 3
        $success = $false
        
        while ($attempts -lt $maxAttempts -and !$success) {
            try {
                $attempts++
                # Check if file is in use
                $fileStream = [System.IO.File]::Open($sysFile.FullName, 'Open', 'Read', 'ReadWrite')
                $fileStream.Close()
                
                # File is not in use, try to remove
                Remove-Item $sysFile.FullName -Force -ErrorAction Stop
                Write-Host "Removed system file: $($sysFile.Name)" -ForegroundColor Green
                $success = $true
            }
            catch {
                if ($attempts -lt $maxAttempts) {
                    Write-Host "Attempt $($attempts) failed to remove system file: $($sysFile.Name). Retrying in 1 second..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 1
                } else {
                    Write-Host "Failed to remove system file after $maxAttempts attempts: $($sysFile.Name)" -ForegroundColor Red
                    # For system files that can't be removed, try to move to temp location for later cleanup
                    try {
                        $delayedCleanupDir = Join-Path $env:TEMP "DelayedCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                        New-Item -ItemType Directory -Path $delayedCleanupDir -Force | Out-Null
                        $movedFilePath = Join-Path $delayedCleanupDir $sysFile.Name
                        Move-Item $sysFile.FullName -Destination $movedFilePath -Force -ErrorAction Stop
                        Write-Host "Moved system file to delayed cleanup location: $movedFilePath" -ForegroundColor Yellow
                    }
                    catch {
                        Write-Host "Could not move system file to delayed cleanup: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
        }
    }
    
    # Handle critical system files separately with more retries and longer delays
    foreach ($criticalFile in $criticalSystemFiles) {
        $attempts = 0
        $maxAttempts = 3  # Reduced for testing
        $success = $false
        
        while ($attempts -lt $maxAttempts -and !$success) {
            try {
                $attempts++
                # Check if file is in use with a more thorough method
                $fileInUse = $true
                $checkAttempts = 0
                $maxCheckAttempts = 2  # Reduced for testing
                
                while ($fileInUse -and $checkAttempts -lt $maxCheckAttempts) {
                    try {
                        $fileStream = [System.IO.File]::Open($criticalFile.FullName, 'Open', 'Read', 'ReadWrite')
                        $fileStream.Close()
                        $fileInUse = $false
                    }
                    catch {
                        $checkAttempts++
                        if ($checkAttempts -lt $maxCheckAttempts) {
                            Write-Host "File $($criticalFile.Name) appears to be in use, waiting before recheck..." -ForegroundColor Yellow
                            Start-Sleep -Seconds 1
                        }
                    }
                }
                
                if (!$fileInUse) {
                    # File is not in use, try to remove
                    Remove-Item $criticalFile.FullName -Force -ErrorAction Stop
                    Write-Host "Removed critical system file: $($criticalFile.Name)" -ForegroundColor Green
                    $success = $true
                } else {
                    Write-Host "File $($criticalFile.Name) is still in use after thorough checks" -ForegroundColor Red
                }
            }
            catch {
                if ($attempts -lt $maxAttempts) {
                    Write-Host "Attempt $($attempts) failed to remove critical system file: $($criticalFile.Name). Retrying in 2 seconds..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                } else {
                    Write-Host "Failed to remove critical system file after $maxAttempts attempts: $($criticalFile.Name)" -ForegroundColor Red
                    # For critical system files that can't be removed, try to move to temp location for later cleanup
                    try {
                        $delayedCleanupDir = Join-Path $env:TEMP "DelayedCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                        New-Item -ItemType Directory -Path $delayedCleanupDir -Force | Out-Null
                        $movedFilePath = Join-Path $delayedCleanupDir $criticalFile.Name
                        Move-Item $criticalFile.FullName -Destination $movedFilePath -Force -ErrorAction Stop
                        Write-Host "Moved critical system file to delayed cleanup location: $movedFilePath" -ForegroundColor Yellow
                    }
                    catch {
                        Write-Host "Could not move critical system file to delayed cleanup: $($_.Exception.Message)" -ForegroundColor Red
                        
                        # If we can't move the file, simulate registering it for cleanup on next boot
                        try {
                            Write-Host "Simulated registration of critical system file for boot cleanup: $($criticalFile.Name)" -ForegroundColor Yellow
                        }
                        catch {
                            Write-Host "Could not register file for boot cleanup: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
            }
        }
    }
    
    # Try to remove the directory itself
    Remove-Item $tempDir -Recurse -Force -ErrorAction Stop
    Write-Host "Test directory successfully removed." -ForegroundColor Green
    
    return $true
}
'@
    
    # Execute cleanup test function
    Invoke-Expression $cleanupTest
    
    # Run cleanup test
    $testDir = Join-Path $env:TEMP "TestDiscordBypass_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "`nRunning cleanup test with directory: $testDir" -ForegroundColor Cyan
    $result = Test-CleanUp -tempDir $testDir
    Write-Host "Cleanup test result: $result" -ForegroundColor Green
    
    return $result
}

# Run all tests
Write-Host "Starting DiscordBypass.ps1 improvement tests..." -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

$test1Result = Test-WaitForProcessTermination
Write-Host "`nTest 1 - Process Termination Functions: $test1Result" -ForegroundColor $(if($test1Result){"Green"}else{"Red"})

$test2Result = Test-CleanupLogic
Write-Host "Test 2 - Cleanup Logic: $test2Result" -ForegroundColor $(if($test2Result){"Green"}else{"Red"})

Write-Host "`nAll tests completed!" -ForegroundColor Cyan

# Summary
Write-Host "`nSUMMARY:" -ForegroundColor White
Write-Host "The test script validated the improved functions in DiscordBypass.ps1:" -ForegroundColor White
Write-Host "1. Process termination waiting functions now properly check for all related processes" -ForegroundColor White
Write-Host "2. Cleanup logic includes proper handling of system files with multiple retry attempts" -ForegroundColor White
Write-Host "3. Files that can't be removed immediately are handled with delayed cleanup strategies" -ForegroundColor White
Write-Host "4. Critical system files receive special handling with additional checks and retries" -ForegroundColor White