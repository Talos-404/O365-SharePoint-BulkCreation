<#
.SYNOPSIS
Creates multiple SharePoint Online sites from a CSV file.

.DESCRIPTION
This script connects to SharePoint Online, reads site definitions from a CSV file,
creates sites that do not already exist, associates them with a Hub Site, and
exports a processing report to CSV.

.NOTES
Requirements:
- SharePoint Online Management Shell / Microsoft.Online.SharePoint.PowerShell
- Appropriate SharePoint Online administrative permissions

SECURITY:
- Do not store passwords, access tokens, client secrets, certificates, or other
  credentials in this script or in the CSV file.
- The input CSV and generated results file may contain user and site information.
  Keep them outside the public Git repository.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AdminUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$HubSiteUrl,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 262144)]
    [int]$StorageQuota = 1024,

    [Parameter(Mandatory = $false)]
    [string]$ResultPath = ".\output\results.csv"
)

# ============================================================================
# CONFIGURATION AND VALIDATION
# ============================================================================

# Validate that the input CSV exists before connecting to SharePoint.
if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf))
{
    Write-Error "The CSV file was not found: $CsvPath"
    exit 1
}

# Validate the SharePoint URLs before starting the operation.
foreach ($sharePointUrl in @($AdminUrl, $HubSiteUrl))
{
    try
    {
        $uri = [System.Uri]$sharePointUrl

        if ($uri.Scheme -ne "https")
        {
            throw "The URL must use HTTPS."
        }
    }
    catch
    {
        Write-Error "Invalid SharePoint URL: $sharePointUrl"
        exit 1
    }
}

# Create the output directory when it does not exist.
$resultDirectory = Split-Path -Path $ResultPath -Parent

if ($resultDirectory -and -not (Test-Path -LiteralPath $resultDirectory))
{
    New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null
}

# ============================================================================
# CONNECT TO SHAREPOINT ONLINE
# ============================================================================

Write-Host "Connecting to SharePoint Online..." -ForegroundColor Cyan

Connect-SPOService -Url $AdminUrl -ErrorAction Stop

Write-Host "Connected successfully." -ForegroundColor Green

# ============================================================================
# IMPORT CSV
# Import the CSV using a semicolon delimiter.
# This keeps the script independent from the user's regional settings.
# ============================================================================

$sites = Import-Csv -Path $CsvPath -Delimiter ';'

if (-not $sites)
{
    Write-Error "The CSV file is empty or invalid."
    exit 1
}

# ============================================================================
# PROCESS SITES
# ============================================================================

$results = @()

foreach ($site in $sites)
{
    # Default values used for the processing report.
    $status = "Not processed"
    $message = ""

    # Initialize values so they are also available if an error occurs early.
    $title = ""
    $url = ""
    $owner = ""
    $timezone = ""

    try
    {
        # ====================================================================
        # READ AND CLEAN INPUT VALUES
        # ====================================================================

        $title = "$($site.Title)".Trim()
        $url = "$($site.Url)".Trim()
        $owner = "$($site.Owner)".Trim()
        $timezone = "$($site.TimeZone)".Trim()

        # ====================================================================
        # VALIDATE INPUT DATA
        # ====================================================================

        if ([string]::IsNullOrWhiteSpace($title))
        {
            $status = "Error"
            $message = "Title is empty."
            Write-Host "$message Row skipped." -ForegroundColor Red
            continue
        }

        if ([string]::IsNullOrWhiteSpace($url))
        {
            $status = "Error"
            $message = "URL is empty."
            Write-Host "$message Site: $title" -ForegroundColor Red
            continue
        }

        if ([string]::IsNullOrWhiteSpace($owner))
        {
            $status = "Error"
            $message = "Owner is empty."
            Write-Host "$message Site: $title" -ForegroundColor Red
            continue
        }

        if ([string]::IsNullOrWhiteSpace($timezone))
        {
            $status = "Error"
            $message = "Time zone ID is empty."
            Write-Host "$message Site: $title" -ForegroundColor Red
            continue
        }

        # New-SPOSite expects a numeric SharePoint time zone ID.
        $timezoneId = 0

        if (-not [int]::TryParse($timezone, [ref]$timezoneId))
        {
            $status = "Error"
            $message = "Time zone ID must be numeric."
            Write-Host "$message Site: $title" -ForegroundColor Red
            continue
        }

        # Validate the target site URL.
        try
        {
            $siteUri = [System.Uri]$url

            if ($siteUri.Scheme -ne "https")
            {
                throw "The site URL must use HTTPS."
            }
        }
        catch
        {
            $status = "Error"
            $message = "Invalid SharePoint site URL."
            Write-Host "$message Site: $title" -ForegroundColor Red
            continue
        }

        Write-Host "=========================================" -ForegroundColor DarkGray
        Write-Host "Processing site: $title" -ForegroundColor Cyan

        # ====================================================================
        # CHECK WHETHER THE SITE ALREADY EXISTS
        # ====================================================================

        $existingSite = $null

        try
        {
            $existingSite = Get-SPOSite `
                -Identity $url `
                -ErrorAction Stop
        }
        catch
        {
            # Get-SPOSite throws an error when the site does not exist.
            # In that case, continue with the creation process.
            $existingSite = $null
        }

        if (-not $existingSite)
        {
            # =================================================================
            # CREATE SITE
            # =================================================================

            Write-Host "Creating site..." -ForegroundColor White

            New-SPOSite `
                -Url $url `
                -Owner $owner `
                -Title $title `
                -Template "STS#3" `
                -TimeZoneId $timezoneId `
                -StorageQuota $StorageQuota `
                -ErrorAction Stop

            Write-Host "Site created: $url" -ForegroundColor Green

            # Allow SharePoint time to provision the site before associating it
            # with the Hub Site.
            Start-Sleep -Seconds 20

            # =================================================================
            # ASSOCIATE SITE WITH HUB SITE
            # =================================================================

            Write-Host "Associating site with Hub Site..." -ForegroundColor White

            Add-SPOHubSiteAssociation `
                -Site $url `
                -HubSite $HubSiteUrl `
                -ErrorAction Stop

            Write-Host "Hub Site association completed successfully." -ForegroundColor Magenta

            $status = "Success"
            $message = "Site created and associated with the Hub Site."
        }
        else
        {
            Write-Host "Site already exists: $url" -ForegroundColor Yellow

            $status = "Already exists"
            $message = "Site already exists. No changes were made."
        }
    }
    catch
    {
        $status = "Error"
        $message = $_.Exception.Message

        Write-Host "Error processing site: $title" -ForegroundColor Red
        Write-Host $message -ForegroundColor Red
    }
    finally
    {
        # ====================================================================
        # ADD RESULT TO THE PROCESSING REPORT
        # ====================================================================

        $results += [PSCustomObject]@{
            Date    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Title   = $title
            Url     = $url
            Owner   = $owner
            Status  = $status
            Message = $message
        }
    }

    # Basic delay to reduce the risk of SharePoint throttling.
    Start-Sleep -Seconds 5
}

# ============================================================================
# EXPORT RESULTS
# ============================================================================

$results | Export-Csv `
    -Path $ResultPath `
    -NoTypeInformation `
    -Encoding UTF8 `
    -Delimiter ";"

Write-Host "=========================================" -ForegroundColor DarkGray
Write-Host "Processing completed." -ForegroundColor Green
Write-Host "Results exported to: $ResultPath" -ForegroundColor Cyan
