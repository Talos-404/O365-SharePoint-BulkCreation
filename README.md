# O365 SharePoint Bulk Creation

PowerShell automation for bulk creation of SharePoint Online sites from a CSV file, including Hub Site association and processing reports.

## Features

* Create multiple SharePoint Online sites from a CSV file
* Check whether a site already exists before creating it
* Assign a site owner during creation
* Configure the SharePoint time zone
* Configure the storage quota
* Associate newly created sites with a Hub Site
* Export a processing report to CSV
* Basic input validation and error handling

## Requirements

* SharePoint Online
* SharePoint Administrator permissions
* `Microsoft.Online.SharePoint.PowerShell` module
* A Windows PowerShell environment compatible with the SharePoint Online Management Shell

The SharePoint Online Management Shell is provided by Microsoft and contains the SharePoint Online PowerShell cmdlets used by this script.

Check whether the module is installed:

```powershell
Get-Module -Name Microsoft.Online.SharePoint.PowerShell -ListAvailable
```

Install it for the current user if necessary:

```powershell
Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
```

For PowerShell 7 on Windows, Microsoft documents importing the module through Windows PowerShell compatibility mode:

```powershell
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
```

## Repository Structure

```text
O365-SharePoint-BulkCreation/
│
├── .gitignore
├── LICENSE
│
├── examples/
│   └── sites-example.csv
│
└── src/
    └── New-BulkSharePointSite.ps1
```

## CSV Format

The script expects a CSV file using a semicolon (`;`) as the delimiter.

Required columns:

| Column     | Description                                 |
| ---------- | ------------------------------------------- |
| `title`    | Display name of the SharePoint site         |
| `url`      | Full SharePoint site URL                    |
| `owner`    | User who will be assigned as the site owner |
| `timezone` | SharePoint time zone ID                     |

Example:

```csv
title;url;owner;timezone
contoso - project1;https://contoso.sharepoint.com/sites/contoso-project1;user@contoso.com;4
contoso - project2;https://contoso.sharepoint.com/sites/contoso-project2;user@contoso.com;4
```

A complete example is available in:

`examples/sites-example.csv`

## Usage

Run the script by providing the SharePoint Admin Center URL, the CSV path, and the Hub Site URL.

```powershell
.\New-BulkSharePointSite.ps1 `
    -AdminUrl "https://contoso-admin.sharepoint.com" `
    -CsvPath ".\examples\sites-example.csv" `
    -HubSiteUrl "https://contoso.sharepoint.com/sites/project-hub"
```

### Optional parameters

The script also supports:

```text
-StorageQuota
-ResultPath
```

Example:

```powershell
.\New-BulkSharePointSite.ps1 `
    -AdminUrl "https://contoso-admin.sharepoint.com" `
    -CsvPath ".\examples\sites-example.csv" `
    -HubSiteUrl "https://contoso.sharepoint.com/sites/project-hub" `
    -StorageQuota 2048 `
    -ResultPath ".\output\results.csv"
```

The default storage quota is `1024 MB`.

The default result file is:

```text
.\output\results.csv
```

## Processing Logic

For each row in the CSV, the script:

1. Validates the input values.
2. Checks whether the SharePoint site already exists.
3. Creates the site if it does not exist.
4. Waits for the site provisioning process.
5. Associates the site with the specified Hub Site.
6. Records the result of the operation.

Existing sites are not modified by the script.

## Output

The script generates a CSV processing report containing:

* Processing date
* Site title
* Site URL
* Owner
* Status
* Processing message

Possible statuses include:

* `Success`
* `Already exists`
* `Error`

## Security

Do not store sensitive information in this repository.

Never commit:

* Passwords
* Access tokens
* Client secrets
* Private keys
* Certificates
* Production CSV files
* Real user or site lists

The repository includes a `.gitignore` rule that prevents CSV files from being committed by default.

The example CSV is explicitly allowed because it contains demonstration data only.

## Important Notes

This script performs administrative operations in SharePoint Online.

Always test the script in a non-production environment before using it in production.

Make sure the account used to run the script has the required SharePoint Online administrative permissions.

The script does not modify existing sites when they are detected.

## Disclaimer

This project is provided "as is", without warranty of any kind.

Use it at your own risk and test it thoroughly in your environment before performing administrative operations in production.

## License

This project is licensed under the MIT License.

See the `LICENSE` file for details.