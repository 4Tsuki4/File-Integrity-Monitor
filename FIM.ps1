# Define global variables
$baselineFilePath = "C:\Path\To\Your\Baseline\baseline.txt"  # Update this path
$backupBaselineFilePath = "C:\Path\To\Your\Baseline\baseline_backup.txt"  # Update this path
$logFilePath = "C:\Path\To\Your\Log\log.txt"  # Update this path
$exclusions = @("baseline.txt", "log.txt", "temp")  # Exclude these files
$processedFiles = @{}  # Track processed files for event uniqueness

# Function to calculate file hash with chosen algorithm
Function Calculate-File-Hash($filePath, $algorithm = "SHA256") {
    try {
        $fileHash = Get-FileHash -Path $filePath -Algorithm $algorithm
        return $fileHash.Hash
    }
    catch {
        Log-Message "Error calculating hash for ${filePath}: $_"
        return $null
    }
}

# Function to log messages to a log file
Function Log-Message($message) {
    $timestamp = Get-Date
    "${timestamp} - ${message}" | Out-File -FilePath $logFilePath -Append
    Write-Host $message
}

# Function to send email alerts
Function Send-EmailAlert($subject, $body) {
    # Email setup 
    $smtpServer = "smtp.example.com"  # Update with your SMTP server
    $smtpPort = 587
    $smtpUser = $env:SMTP_USER  # Use environment variable for email 
    $smtpPassword = $env:SMTP_PASSWORD  # Use environment variable for email password
    $toEmail = "your-email@example.com"  # Update with your email address
    $fromEmail = "your-email@example.com"  # Update with your email address

    try {
        $mailmessage = New-Object system.net.mail.mailmessage
        $mailmessage.from = $fromEmail
        $mailmessage.To.Add($toEmail)
        $mailmessage.Subject = $subject
        $mailmessage.Body = $body

        $smtp = New-Object Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $smtp.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPassword)
        $smtp.EnableSsl = $true
        $smtp.Send($mailmessage)
    }
    catch {
        Log-Message "Error sending email: $_"
    }
}

# Function to start monitoring files with saved baseline
Function Start-Monitoring() {
    $chosenAlgorithm = $global:chosenAlgorithm

    # Load the baseline file into a dictionary
    $fileHashDictionary = @{}
    $filePathsAndHashes = Get-Content -Path $baselineFilePath
    foreach ($f in $filePathsAndHashes) {
        $splitData = $f.Split("|")
        $fileHashDictionary[$splitData[0]] = $splitData[1]
    }

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = "C:\Path\To\Your\Monitor\Directory"  # Update this path
    $watcher.Filter = "*.*"
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    # Event for file created
    $null = Register-ObjectEvent -InputObject $watcher -EventName Created -Action {
        $filePath = $Event.SourceEventArgs.FullPath
        Log-Message "File Created Event: ${filePath}"

        if (-not $processedFiles[$filePath]) {
            $hash = Calculate-File-Hash $filePath -Algorithm $chosenAlgorithm
            if ($fileHashDictionary[$filePath] -eq $null) {
                Log-Message "${filePath} has been created!"
                Send-EmailAlert "File Created" "${filePath} has been created!"
                $processedFiles[$filePath] = "Created"
            }
        }
    }

    # Event for file changed
    $null = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action {
        $filePath = $Event.SourceEventArgs.FullPath
        # Skip logging for the log.txt file
        if ($filePath -eq $logFilePath) {
            return
        }

        # Process file change if not already processed
        if (-not $processedFiles[$filePath] -or $processedFiles[$filePath] -ne "Changed") {
            Log-Message "File Changed Event: ${filePath}"
            $processedFiles[$filePath] = "Changed"
            $hash = Calculate-File-Hash $filePath -Algorithm $chosenAlgorithm
            $baselineHash = $fileHashDictionary[$filePath]
            Log-Message "Comparing hash for ${filePath}: ${hash} vs ${baselineHash}"
            if ($baselineHash -ne $hash) {
                Log-Message "${filePath} has changed!"
                Send-EmailAlert "File Changed" "${filePath} has changed!"
            }
        }
    }

    # Event for file deleted
    $null = Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action {
        $filePath = $Event.SourceEventArgs.FullPath
        Log-Message "File Deleted Event: ${filePath}"

        if (-not $processedFiles[$filePath]) {
            if (-not (Test-Path -Path $filePath)) {
                Log-Message "${filePath} has been deleted!"
                Send-EmailAlert "File Deleted" "${filePath} has been deleted!"
                $processedFiles[$filePath] = "Deleted"
            }
        }
    }

    while ($true) {
        Start-Sleep -Seconds 1
    }
}

# Function to collect a new baseline
Function Collect-New-Baseline() {
    Erase-Baseline-If-Already-Exists
    $global:chosenAlgorithm = Select-Hashing-Algorithm  # Store the selected algorithm globally
    $files = Get-ChildItem -Path "C:\Path\To\Your\Monitor\Directory" | Where-Object { $_.Name -notin $exclusions }  # Update this path
    foreach ($f in $files) {
        $hash = Calculate-File-Hash $f.FullName -Algorithm $global:chosenAlgorithm
        "$($f.FullName)|$hash" | Out-File -FilePath $baselineFilePath -Append
    }
    Backup-Baseline
}

# Main menu
Write-Host "Choose an option: `n"
Write-Host "    1) Collect a new Baseline"
Write-Host "    2) Begin monitoring files with saved Baseline"
Write-Host "    3) Exit`n"

$input = Read-Host -Prompt "Please enter '1', '2', or '3'"

switch ($input) {
    "1" { Collect-New-Baseline }
    "2" { Start-Monitoring }
    "3" { Exit }
}
