# Microsoft 365 Copilot Agent Inventory

Export Microsoft 365 Copilot agent inventory and availability assignments from the Microsoft 365 Admin Center.

This script uses the same internal API consumed by the Microsoft 365 Admin Center portal to retrieve Copilot agent data and export it to CSV.

## Features

* Exports all Microsoft 365 Copilot agents
* Automatically follows pagination using the portal's `nextLink` token
* Exports results to CSV
* Captures:

  * Agent name
  * App ID
  * Title ID
  * Publisher
  * Created by
  * Availability settings
  * Allowed users and groups
  * Assignment information
  * Deployment information
  * Version information
  * Timestamps

## Requirements

* Microsoft 365 Global Administrator, Copilot Administrator, or equivalent permissions
* Access to the Microsoft 365 Admin Center
* PowerShell 5.1 or later
* Valid browser session

## Setup

### 1. Open the Microsoft 365 Admin Center

Navigate to:

```text
Copilot > Agents > All Agents
```

### 2. Open Developer Tools

Press **F12**, then select the **Network** tab.

Refresh the page.

### 3. Find the agents request

Locate and select the request similar to:

```text
agents?workloads=SharedAgent
```

In the request details, expand:

```text
Request Headers
```

Find the **Cookie** header and copy the entire cookie value.

### 4. Save the cookie

Create this file:

```text
C:\Temp\cookie.txt
```

Paste the cookie value into the file and save it.

## Usage

Run the script:

Best run in PS v7 as Administrator

```powershell
.\Get-AgentsAvailability.ps1
```

The script will:

1. Retrieve all Copilot agents.
2. Follow all paging tokens automatically.
3. Export results to:

```text
M365-Copilot-Agent-Availability.csv
```

## Sample Output

| Title                 | AvailableTo                               | Publisher |
| --------------------- | ----------------------------------------- | --------- |
| Sales Agent           | All users in the organization can install | Microsoft |
| HR Assistant          | Specific users/groups can install         | Contoso   |
| Project Status Report | No users in the organization can install  | Fabrikam  |

## Security Notes

This script uses an authenticated browser session cookie.

Treat the cookie like a password:

* Never commit `cookie.txt`
* Never share your cookie
* Never publish exported data containing tenant information

The included `.gitignore` excludes common sensitive files such as cookies, CSV exports, and logs.

## Disclaimer

This script uses an undocumented Microsoft 365 Admin Center API. Microsoft may change or remove this endpoint at any time.


## Admin Center

![Admin Center](screenshots/admin-center-agent-list.jpg)

## Script Execution

![Script Execution](screenshots/script-success.jpg)

## CSV Output

![CSV Output](screenshots/csv-output.jpg)

Microsoft may change or remove these endpoints at any time.

Credits

Created after reverse engineering the Microsoft 365 Admin Center agent inventory experience and identifying the portal's paging mechanism (nextLink / nextToken).
