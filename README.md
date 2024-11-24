# File Integrity Monitor (FIM) Script

## Description
This PowerShell script provides a solution for monitoring the integrity of files in a specific directory. It tracks file creation, modification, and deletion events by comparing file hashes to a baseline. If any changes are detected, it logs the event and sends email alerts.

The script is designed to be flexible, allowing users to:

- **Collect a new baseline** of file hashes for later comparisons.
- **Monitor a specified directory** for file changes.
- **Generate logs** and receive notifications when changes occur.

## Features

- **File Hash Calculation**: Calculates SHA256 hashes for files to verify integrity.
- **Real-Time Monitoring**: Monitors files in real-time using `FileSystemWatcher` for file creation, changes, and deletion.
- **Email Notifications**: Sends email alerts upon detecting file modifications, creations, or deletions.
- **Log Generation**: Logs all detected events to a specified log file for later review.
