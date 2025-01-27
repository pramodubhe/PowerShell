<#Script Synopsis
Name: 
Password and API Key Detection Script with HTML Reporting

Purpose:
This PowerShell script scans files on a local machine, including specified directories, local drives, and OneDrive (if available), for patterns that may indicate sensitive data such as passwords or API keys. It generates an HTML report summarizing the findings, including details of matched files and the regex patterns used.

Key Features:
Dynamic File Scanning:
    Scans all local drives, OneDrive, or a custom-specified directory.
    Handles multiple file types, including text files, script files, Word documents (.docx), Excel files (.xlsx), and OneNote files (.one).

Pattern Matching:
    Uses predefined regex patterns to detect passwords and API keys:
        Passwords in formats like password = "value".
            Password Pattern: "password\s*[:=]?\s*[\'""]?.{1,50}[\'""]?";
            password: Matches the keyword (case-insensitive by default in PowerShell).
            \s*: Matches any number of spaces or tabs.
            [:=]?: Matches an optional : or = character.
            \s*: Matches spaces between the Password and the value.
            [\'""]?: Matches an optional single or double quote.
            .{1,50}: Matches the actual password (1 to 50 characters).
            [\'""]?: Matches an optional closing single or double quote.
        API keys of 20–50 alphanumeric characters with underscores or dashes.
            API Key Pattern: "[a-zA-Z0-9_-]{20,50}"
            This pattern assumes API keys are alphanumeric strings of 20-50 characters, including underscores or hyphens.
            Ensure the API key format aligns with the real-world keys you're searching for (e.g., AWS, Azure, etc.). If needed, refine the pattern.


HTML Report Generation:
    Provides an easy-to-read HTML & csv report that includes:
        Total number of files scanned.
        Total matches found.
        Detailed table of matched files, including their paths and matched patterns.
        Regex patterns used for the scan.

Real-Time Progress:
    Displays the current file being scanned in the console, providing a clear indication of progress.

Error Handling:
    Skips files where the current user lacks write access.
    Gracefully handles errors during the file reading process.

Input:
$Directory: (Optional) A specific directory to scan. If not specified, all local drives and OneDrive (if available) are scanned.

Output:
HTML Report:
    Saved in the current user's Documents folder as PasswordScanReport.html.
    Contains detailed findings, regex patterns used, and summary statistics.

Dependencies:
PowerShell Version:
    Requires PowerShell 5.1 or later for optimal regex and HTML handling.
Modules:
    For Excel files: Install the ImportExcel module (optional for better performance).
Applications:
    Microsoft Office applications (Word, Excel, OneNote) must be installed for processing .docx, .xlsx, and .one files if using COM objects.

Limitations:
False Positives:
    Matches may include non-sensitive strings resembling passwords or API keys.
Performance:
    Scanning a large number of files or large directories may take time, depending on system resources.
Restricted Access:
    Files that the current user does not have write access to will be skipped.

Usage:
Run Script:
    Save the script and execute in PowerShell:
       .\PasswordScan.ps1

Specify Custom Directory:
To scan a specific folder, set $Directory before running the script:
    $Directory = "C:\Path\To\Directory"

View Report:
    Open the generated PasswordScanReport.html in your browser or PasswordScanReport.csv for detailed results.

#>


# Define target directory or scan all local drives + OneDrive
$Directory = ""

if (-not($Directory)) {
    
    Write-Host "Please enter the directory path to scan or press enter to scan all drives:" -ForegroundColor Magenta
    $Directory = Read-Host

    # Check if the path entered is invalid
    if (($Directory) -and (-not (Test-Path $Directory))) {
        
        Write-Host "Path '$Directory' is not valid. Press enter to scan all drives or type 'cancel' to stop the script" -ForegroundColor Yellow
        $confirm = Read-Host

        # If the user types "cancel", exit the script
        if ($confirm -eq "cancel") {
            Write-Host "Execution cancelled by the user." -ForegroundColor Yellow
            exit
        } else {
            Write-Host "No valid path provided. Proceeding to scan all drives." -ForegroundColor Green
            $Directory = ""
        }
    }
}



$TargetPath = @()
if ($Directory) {
    # Use a custom target path if specified
    $TargetPath += $Directory
    Write-Host "Scan started for : $Directory" -ForegroundColor Green
} else {
    Write-Host "Scanning all drives..." -ForegroundColor Green
    # Add all local drives
    $TargetPath += Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null } | ForEach-Object { $_.Root }

    # Add OneDrive path if it exists
    $OneDrivePath = "$env:USERPROFILE\OneDrive"
    if (Test-Path $OneDrivePath) {
        #$TargetPath += $OneDrivePath
    }
}

# HTML report setup
$HtmlReport = "$env:USERPROFILE\Documents\PasswordScanReport.html"
$csvReport = "$env:USERPROFILE\Documents\PasswordScanReport.csv"
$FilesWithMatches = @()  # Array to store files with matches

# File patterns to scan
$Extensions = @("*.txt", "*.ps1", "*.bat", "*.sh", "*.py", "*.conf", "*.docx", "*.xlsx", "*.one")

# Regex Patterns for passwords and API keys
$Patterns = @{
    "Password" = "password\s*[:=]?\s*[\'""]?.{1,50}[\'""]?";
    "API Key"  = "[a-zA-Z0-9_-]{20,50}";
    "Key" = "key\s*[:=]?\s*[\'""]?.{1,50}[\'""]?";
    "Secret" = "secret\s*[:=]?\s*[\'""]?.{1,50}[\'""]?";
    "Token" = "token\s*[:=]?\s*[\'""]?.{1,50}[\'""]?";
    "Pwd" = "pwd\s*[:=]?\s*[\'""]?.{1,50}[\'""]?";
    "passwd" = "passwd\s*[:=]?\s*[\'""]?.{1,50}[\'""]?";
    "auth" = "auth\s*[:=]?\s*[\'""]?.{1,50}[\'""]?";
    "credential" = "credential\s*[:=]?\s*[\'""]?.{1,50}[\'""]?";
}


# Initialize counters
$FilesScanned = 0
$PasswordMatches = 0

# Function to scan a file for keywords
function Scan-File {
    param (
        [string]$FilePath
    )
    try {
        # Skip if the user does not have write access
        if (-not (Test-Path $FilePath -PathType Leaf -ErrorAction SilentlyContinue)) {
            return
        }

        # Increment scanned files counter
        $global:FilesScanned++

        # Update progress
        Write-Host "Scanning: $FilePath"

        # Check if the file matches patterns
        $global:FileContent = ""
        if ($FilePath -match "\.txt|\.ps1|\.bat|\.sh|\.py|\.conf$") {
            $FileContent = Get-Content -Path $FilePath -ErrorAction SilentlyContinue
        }

        elseif ($FilePath -match "\.docx|\.xlsx|\.one$") {
            try {
                if ($FilePath -match "\.docx$") {
                    # Handle Word documents
                    $Word = New-Object -ComObject Word.Application
                    $Word.Visible = $false
                    $Document = $Word.Documents.Open($FilePath, $false, $true)
                    $FileContent = $Document.Content.Text
                    $Document.Close()
                    $Word.Quit()
                } elseif ($FilePath -match "\.xlsx$") {
                    # Handle Excel files
                    if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
                        Install-Module -Name ImportExcel -Force -Scope CurrentUser
                    }
                    $FileContent = Import-Excel -Path $FilePath -NoHeader | Out-String
                } elseif ($FilePath -match "\.one$") {
                    # Handle OneNote files
                    $OneNote = New-Object -ComObject OneNote.Application
                    $NotebookXml = ""
                    $OneNote.GetHierarchy("", [Microsoft.Office.Interop.OneNote.HierarchyScope]::hsPages, [ref]$NotebookXml)
                    $FileContent = $NotebookXml
                }
            } catch {
                Write-Host "Error reading file: $FilePath. Error: $_" -ForegroundColor Red
                $FileContent = ""
            }
        }

        if ($FileContent) {
            foreach ($Key in $Patterns.Keys) {
                $Pattern = $Patterns[$Key]
                if ($FileContent -match $Pattern) {
                    $global:PasswordMatches++
                    $global:FilesWithMatches += [PSCustomObject]@{
                        FileName    = $FilePath
                        MatchType   = $Key
                        Pattern     = $Pattern # $($Matches[0])
                    }
                    break
                }
            }
        }
    } catch {
        Write-Host "Error scanning file: $FilePath. Error: $_" -ForegroundColor Red
    }
}

# Scan target directories
foreach ($Path in $TargetPath) {
    Write-Host "Scanning directory: $Path"

    Get-ChildItem -Path $Path -Recurse -Include $Extensions -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            Scan-File -FilePath $_.FullName
        }
}

# Generate HTML report
$HtmlContent = @"
<html>
<head>
    <title>Password Scan Report</title>
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Password Scan Report</h1>
    <p>Computer Name: $($env:COMPUTERNAME)</p>
    <p>User Name: $($env:USERDOMAIN)\$($env:USERNAME)</p>
    <p>Scan completed: $(Get-Date)</p>
    <p>Total files scanned: $FilesScanned</p>
    <p>Total potential matches found: $PasswordMatches</p>
    <h2>Regex Patterns Used</h2>
    <table>
        <tr><th>Type</th><th>Pattern</th></tr>
"@

foreach ($Key in $Patterns.Keys) {
    $HtmlContent += "<tr><td>$Key</td><td>$($Patterns[$Key])</td></tr>"
}

$HtmlContent += @"
    </table>
    <h2>Files Containing Potential Matches</h2>
    <table>
        <tr><th>File Name</th><th>Match Type</th><th>Pattern</th></tr>
"@

foreach ($Match in $FilesWithMatches) {
    $HtmlContent += "<tr><td>$($Match.FileName)</td><td>$($Match.MatchType)</td><td>$($Match.Pattern)</td></tr>"
}

$HtmlContent += @"
    </table>
</body>
</html>
"@

# Save the HTML and csv report
$HtmlContent | Out-File -FilePath $HtmlReport -Encoding UTF8
$FilesWithMatches | ConvertTo-Csv -NoTypeInformation | Out-File $csvReport

Write-Host "Scan complete. Report saved at: 
$HtmlReport
$csvReport" -ForegroundColor Green