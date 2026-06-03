# Get-AgentsAvailability.ps1

$CookieFile = "C:\Temp\cookie.txt"

if (-not (Test-Path $CookieFile)) {
    throw "Cookie file not found: $CookieFile"
}

$Cookie = (Get-Content $CookieFile -Raw).Trim()

$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$Cookie -split ';' | ForEach-Object {
    $parts = $_.Trim() -split '=', 2

    if ($parts.Count -eq 2) {
        $c = New-Object System.Net.Cookie
        $c.Name = $parts[0]
        $c.Value = $parts[1]
        $c.Domain = "admin.cloud.microsoft"
        $c.Path = "/"
        $Session.Cookies.Add($c)
    }
}

$Headers = @{
    Accept  = "application/json"
    Referer = "https://admin.cloud.microsoft/"
}

$AllAgentsByKey = @{}
$Page = 1
$Limit = 50

$NextUrl = "https://admin.cloud.microsoft/fd/addins/api/agents?workloads=SharedAgent&scopes=Shared%2CPublic%2CTenant&limit=$Limit&sortBy=Name&sortOrder=Asc"

do {
    Write-Host "Getting page $Page..."

    try {
        $WebResponse = Invoke-WebRequest `
            -Method GET `
            -Uri $NextUrl `
            -Headers $Headers `
            -WebSession $Session

        $Response = $WebResponse.Content | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to call Admin Center endpoint. URL was: $NextUrl"
        Write-Error "Error: $($_.Exception.Message)"
        break
    }

    $Agents = @()
    $Agents += @($Response.apps)
    $Agents += @($Response.external3PAgents)

    foreach ($Agent in $Agents) {
        $Key = if ($Agent.titleId) {
            $Agent.titleId
        }
        elseif ($Agent.observabilityId) {
            $Agent.observabilityId
        }
        elseif ($Agent.appId) {
            $Agent.appId
        }
        else {
            [guid]::NewGuid().Guid
        }

        if (-not $AllAgentsByKey.ContainsKey($Key)) {
            $AllAgentsByKey[$Key] = $Agent
        }
    }

    Write-Host "Returned apps: $(@($Response.apps).Count). External3P: $(@($Response.external3PAgents).Count). Total agents: $($AllAgentsByKey.Count)."

    $NextLink = $Response.nextLink

    if ([string]::IsNullOrWhiteSpace($NextLink)) {
        Write-Host "No nextLink returned. Finished."
        break
    }

    if ($NextLink -like "v3.*") {
        $EncodedNextToken = [System.Net.WebUtility]::UrlEncode($NextLink)
        $NextUrl = "https://admin.cloud.microsoft/fd/addins/api/agents?workloads=SharedAgent&scopes=Shared%2CPublic%2CTenant&limit=$Limit&nextToken=$EncodedNextToken&sortBy=Name&sortOrder=Asc"
    }
    elseif ($NextLink -like "/fd/*") {
        $NextUrl = "https://admin.cloud.microsoft" + $NextLink
    }
    elseif ($NextLink -like "http*") {
        $NextUrl = $NextLink
    }
    else {
        throw "Unexpected nextLink format: $NextLink"
    }

    $Page++
    Start-Sleep -Milliseconds 300
}
while ($true)

$Report = $AllAgentsByKey.Values |
    Sort-Object title |
    ForEach-Object {
        $allowedTargets = if ($_.allowedUsersAndGroups) {
            ($_.allowedUsersAndGroups | ForEach-Object {
                $name = $_.name
                $email = $_.emailId
                $type = $_.type

                if ($email) {
                    "$name <$email> [$type]"
                }
                else {
                    "$name [$type]"
                }
            }) -join "; "
        }
        else {
            ""
        }

        [pscustomobject]@{
            Title                      = $_.title
            AppId                      = $_.appId
            TitleId                    = $_.titleId
            ObservabilityId            = $_.observabilityId
            AppType                    = $_.appType
            Publisher                  = $_.developerName
            CreatedBy                  = $_.createdBy.name
            CreatedByEmail             = $_.createdBy.emailId
            AppBlockStatus             = $_.appBlockStatus
            AvailableToRaw             = $_.allowedUsersCategory
            AvailableTo                = switch ($_.allowedUsersCategory) {
                "Everyone" { "All users in the organization can install" }
                "NoOne"    { "No users in the organization can install" }
                "Specific" { "Specific users/groups can install" }
                "Selected" { "Specific users/groups can install" }
                default    { $_.allowedUsersCategory }
            }
            AllowedUsersAndGroups      = $allowedTargets
            IsAssigned                 = $_.isAssigned
            UserAssignmentCategory     = $_.userAssignmentCategory
            IsUserAssignmentApplicable = $_.isUserAssignmentApplicable
            IsDeployed                 = $_.isDeployed
            IsDeployedForEveryone      = $_.isDeployedForEveryone
            CurrentVersion             = $_.currentVersion
            CreatedDateTime            = $_.createdDateTime
            LastModifiedDateTime       = $_.lastModifiedDateTime
            IngestionDate              = $_.ingestionDate
        }
    }

$OutFile = Join-Path $PWD "M365-Copilot-Agent-Availability.csv"

$Report | Export-Csv $OutFile -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Exported $($Report.Count) agents to:"
Write-Host $OutFile