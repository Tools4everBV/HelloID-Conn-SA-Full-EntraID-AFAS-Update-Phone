#######################################################################
# Template: HelloID SA Powershell data source
# Name:     EntraID-AFAS-account-update-phone-lookup-user-generate-table
# Date:     01-11-2024
#######################################################################

# For basic information about powershell data sources see:
# https://docs.helloid.com/en/service-automation/dynamic-forms/data-sources/powershell-data-sources/add,-edit,-or-remove-a-powershell-data-source.html#add-a-powershell-data-source

# Service automation variables:
# https://docs.helloid.com/en/service-automation/service-automation-variables/service-automation-variable-reference.html

#region init

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

# global variables (Automation --> Variable libary):

# variables configured in form:
$searchValue = $dataSource.searchUser
$searchQuery = "*$searchValue*"

#endregion init

#region functions
function Get-ErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber    = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line                = $ErrorObject.InvocationInfo.Line
            VerboseErrorMessage = $ErrorObject.Exception.Message
            AuditErrorMessage   = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.VerboseErrorMessage = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.VerboseErrorMessage = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.VerboseErrorMessage | ConvertFrom-Json)
            # Make sure to inspect the error result object and add only the error message as a FriendlyMessage.
            $httpErrorObj.VerboseErrorMessage = $errorDetailsObject.error
            $httpErrorObj.AuditErrorMessage = $errorDetailsObject.error.message
            if ($null -eq $httpErrorObj.AuditErrorMessage) {
                $httpErrorObj.AuditErrorMessage = $errorDetailsObject.error
            }
        }
        catch {
            $httpErrorObj.AuditErrorMessage = $httpErrorObj.VerboseErrorMessage
        }
        Write-Output $httpErrorObj
    }
}
#endregion functions

#region lookup
try {          
    Write-Verbose "Generating Microsoft Graph API Access Token.."
    $baseUri = "https://login.microsoftonline.com/"
    $authUri = $baseUri + "$EntraTenantId/oauth2/token"
    $body = @{
        grant_type    = "client_credentials"
        client_id     = "$EntraAppId"
        client_secret = "$EntraAppSecret"
        resource      = "https://graph.microsoft.com"
    }

    $Response = Invoke-RestMethod -Method POST -Uri $authUri -Body $body -ContentType 'application/x-www-form-urlencoded'
    $accessToken = $Response.access_token;
    Write-Information "Searching for: $searchQuery"
    
    #Add the authorization header to the request
    $authorization = @{
        Authorization  = "Bearer $accesstoken";
        'Content-Type' = "application/json";
        Accept         = "application/json";
    }

    $baseSearchUri = "https://graph.microsoft.com/"
    $searchUri = $baseSearchUri + "v1.0/users" + '?$select=Id,UserPrincipalName,displayName,EmployeeID,department,jobTitle,companyName,businessPhones,mobilePhone' + '&$top=999'

    $entraIDUsersResponse = Invoke-RestMethod -Uri $searchUri -Method Get -Headers $authorization -Verbose:$false
    $entraIDUsers = $entraIDUsersResponse.value
    while (![string]::IsNullOrEmpty($entraIDUsersResponse.'@odata.nextLink')) {
        $entraIDUsersResponse = Invoke-RestMethod -Uri $entraIDUsersResponse.'@odata.nextLink' -Method Get -Headers $authorization -Verbose:$false
        $entraIDUsers += $entraIDUsersResponse.value
    }  

    $users = foreach ($entraIDUser in $entraIDUsers) {
        if ($entraIDUser.displayName -like $searchQuery -or $entraIDUser.userPrincipalName -like $searchQuery) {
            $entraIDUser
        }
    }
    $users = $users | Sort-Object -Property DisplayName
    $resultCount = @($users).Count
    Write-Information "Result count: $resultCount"
        
    if ($resultCount -gt 0) {
        foreach ($user in $users) {
            $returnObject = @{
                Id                = $user.Id
                UserPrincipalName = $user.UserPrincipalName
                DisplayName       = $user.DisplayName
                EmployeeID        = $user.EmployeeID
                Department        = $user.Department
                Title             = $user.JobTitle
                Company           = $user.CompanyName
                BusinessPhones    = $user.BusinessPhones[0]
                MobilePhone       = $user.MobilePhone
            }
            Write-Output $returnObject
        }
    }
}
catch {
    $ex = $PSItem

    $errorMessage = Get-ErrorMessage -ErrorObject $ex

    Write-Verbose "Error at Line [$($errorMessage.InvocationInfo.ScriptLineNumber)]: $($errorMessage.InvocationInfo.Line). Error: $($($errorMessage.VerboseErrorMessage))" 
    Write-Error "Error searching for Entra ID users. Error: $($errorMessage.AuditErrorMessage)"
}
#endregion lookup
