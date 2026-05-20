# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

#HelloID variables
#Note: when running this script inside HelloID; portalUrl and API credentials are provided automatically (generate and save API credentials first in your admin panel!)
$portalUrl = "https://CUSTOMER.helloid.com"
$apiKey = "API_KEY"
$apiSecret = "API_SECRET"
$delegatedFormAccessGroupNames = @("") #Only unique names are supported. Groups must exist!
$delegatedFormCategories = @("User Management","Entra ID") #Only unique names are supported. Categories will be created if not exists
$script:debugLogging = $false #Default value: $false. If $true, the HelloID resource GUIDs will be shown in the logging
$script:duplicateForm = $false #Default value: $false. If $true, the HelloID resource names will be changed to import a duplicate Form
$script:duplicateFormSuffix = "_tmp" #the suffix will be added to all HelloID resource names to generate a duplicate form with different resource names

#The following HelloID Global variables are used by this form. No existing HelloID global variables will be overriden only new ones are created.
#NOTE: You can also update the HelloID Global variable values afterwards in the HelloID Admin Portal: https://<CUSTOMER>.helloid.com/admin/variablelibrary
$globalHelloIDVariables = [System.Collections.Generic.List[object]]@();

#Global variable #1 >> EntraIdAppId
$tmpName = @'
EntraIdAppId
'@ 
$tmpValue = "" 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});

#Global variable #2 >> EntraIdCertificatePassword
$tmpName = @'
EntraIdCertificatePassword
'@ 
$tmpValue = "" 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "True"});

#Global variable #3 >> EntraIdTenantId
$tmpName = @'
EntraIdTenantId
'@ 
$tmpValue = ""
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});

#Global variable #4 >> AFASBaseUrl
$tmpName = @'
AFASBaseUrl
'@ 
$tmpValue = @'
https://<CUSTOMER>.afas.online/profitrestservices
'@ 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "False"});

#Global variable #5 >> AFASToken
$tmpName = @'
AFASToken
'@ 
$tmpValue = "" 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "True"});

#Global variable #6 >> EntraIdCertificateBase64String
$tmpName = @'
EntraIdCertificateBase64String
'@ 
$tmpValue = "" 
$globalHelloIDVariables.Add([PSCustomObject]@{name = $tmpName; value = $tmpValue; secret = "True"});


#make sure write-information logging is visual
$InformationPreference = "continue"

# Check for prefilled API Authorization header
if (-not [string]::IsNullOrEmpty($portalApiBasic)) {
    $script:headers = @{"authorization" = $portalApiBasic}
    Write-Information "Using prefilled API credentials"
} else {
    # Create authorization headers with HelloID API key
    $pair = "$apiKey" + ":" + "$apiSecret"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $key = "Basic $base64"
    $script:headers = @{"authorization" = $Key}
    Write-Information "Using manual API credentials"
}

# Check for prefilled PortalBaseURL
if (-not [string]::IsNullOrEmpty($portalBaseUrl)) {
    $script:PortalBaseUrl = $portalBaseUrl
    Write-Information "Using prefilled PortalURL: $script:PortalBaseUrl"
} else {
    $script:PortalBaseUrl = $portalUrl
    Write-Information "Using manual PortalURL: $script:PortalBaseUrl"
}

# Define specific endpoint URI
$script:PortalBaseUrl = $script:PortalBaseUrl.trim("/") + "/"  

# Make sure to reveive an empty array using PowerShell Core
function ConvertFrom-Json-WithEmptyArray([string]$jsonString) {
    # Running in PowerShell Core?
    if($IsCoreCLR -eq $true){
        $r = [Object[]]($jsonString | ConvertFrom-Json -NoEnumerate)
        return ,$r  # Force return value to be an array using a comma
    } else {
        $r = [Object[]]($jsonString | ConvertFrom-Json)
        return ,$r  # Force return value to be an array using a comma
    }
}

function Invoke-HelloIDGlobalVariable {
    param(
        [parameter(Mandatory)][String]$Name,
        [parameter(Mandatory)][String][AllowEmptyString()]$Value,
        [parameter(Mandatory)][String]$Secret
    )

    $Name = $Name + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        $uri = ($script:PortalBaseUrl + "api/v1/automation/variables/named/$Name")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false

        if ([string]::IsNullOrEmpty($response.automationVariableGuid)) {
            #Create Variable
            $body = @{
                name     = $Name;
                value    = $Value;
                secret   = $Secret;
                ItemType = 0;
            }    
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl + "api/v1/automation/variable")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $variableGuid = $response.automationVariableGuid

            Write-Information "Variable '$Name' created$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        } else {
            $variableGuid = $response.automationVariableGuid
            Write-Warning "Variable '$Name' already exists$(if ($script:debugLogging -eq $true) { ": " + $variableGuid })"
        }
    } catch {
        Write-Error "Variable '$Name', message: $_"
    }
}

function Invoke-HelloIDAutomationTask {
    param(
        [parameter(Mandatory)][String]$TaskName,
        [parameter(Mandatory)][String]$UseTemplate,
        [parameter(Mandatory)][String]$AutomationContainer,
        [parameter(Mandatory)][String][AllowEmptyString()]$Variables,
        [parameter(Mandatory)][String]$PowershellScript,
        [parameter()][String][AllowEmptyString()]$ObjectGuid,
        [parameter()][String][AllowEmptyString()]$ForceCreateTask,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $TaskName = $TaskName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        $uri = ($script:PortalBaseUrl +"api/v1/automationtasks?search=$TaskName&container=$AutomationContainer")
        $responseRaw = (Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false) 
        $response = $responseRaw | Where-Object -filter {$_.name -eq $TaskName}

        if([string]::IsNullOrEmpty($response.automationTaskGuid) -or $ForceCreateTask -eq $true) {
            #Create Task

            $body = @{
                name                = $TaskName;
                useTemplate         = $UseTemplate;
                powerShellScript    = $PowershellScript;
                automationContainer = $AutomationContainer;
                objectGuid          = $ObjectGuid;
                variables           = (ConvertFrom-Json-WithEmptyArray($Variables));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/automationtasks/powershell")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            $taskGuid = $response.automationTaskGuid

            Write-Information "Powershell task '$TaskName' created$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        } else {
            #Get TaskGUID
            $taskGuid = $response.automationTaskGuid
            Write-Warning "Powershell task '$TaskName' already exists$(if ($script:debugLogging -eq $true) { ": " + $taskGuid })"
        }
    } catch {
        Write-Error "Powershell task '$TaskName', message: $_"
    }

    $returnObject.Value = $taskGuid
}

function Invoke-HelloIDDatasource {
    param(
        [parameter(Mandatory)][String]$DatasourceName,
        [parameter(Mandatory)][String]$DatasourceType,
        [parameter(Mandatory)][String][AllowEmptyString()]$DatasourceModel,
        [parameter()][String][AllowEmptyString()]$DatasourceStaticValue,
        [parameter()][String][AllowEmptyString()]$DatasourcePsScript,        
        [parameter()][String][AllowEmptyString()]$DatasourceInput,
        [parameter()][String][AllowEmptyString()]$AutomationTaskGuid,
        [parameter()][String][AllowEmptyString()]$DatasourceRunInCloud,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $DatasourceName = $DatasourceName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    $datasourceTypeName = switch($DatasourceType) { 
        "1" { "Native data source"; break} 
        "2" { "Static data source"; break} 
        "3" { "Task data source"; break} 
        "4" { "Powershell data source"; break}
    }

    try {
        $uri = ($script:PortalBaseUrl +"api/v1/datasource/named/$DatasourceName")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
    
        if([string]::IsNullOrEmpty($response.dataSourceGUID)) {
            #Create DataSource
            $body = @{
                name               = $DatasourceName;
                type               = $DatasourceType;
                model              = (ConvertFrom-Json-WithEmptyArray($DatasourceModel));
                automationTaskGUID = $AutomationTaskGuid;
                value              = (ConvertFrom-Json-WithEmptyArray($DatasourceStaticValue));
                script             = $DatasourcePsScript;
                input              = (ConvertFrom-Json-WithEmptyArray($DatasourceInput));
                runInCloud         = $DatasourceRunInCloud;
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100
    
            $uri = ($script:PortalBaseUrl +"api/v1/datasource")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
            
            $datasourceGuid = $response.dataSourceGUID
            Write-Information "$datasourceTypeName '$DatasourceName' created$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        } else {
            #Get DatasourceGUID
            $datasourceGuid = $response.dataSourceGUID
            Write-Warning "$datasourceTypeName '$DatasourceName' already exists$(if ($script:debugLogging -eq $true) { ": " + $datasourceGuid })"
        }
    } catch {
        Write-Error "$datasourceTypeName '$DatasourceName', message: $_"
    }

    $returnObject.Value = $datasourceGuid
}

function Invoke-HelloIDDynamicForm {
    param(
        [parameter(Mandatory)][String]$FormName,
        [parameter(Mandatory)][String]$FormSchema,
        [parameter(Mandatory)][Ref]$returnObject
    )

    $FormName = $FormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/forms/$FormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }

        if(([string]::IsNullOrEmpty($response.dynamicFormGUID)) -or ($response.isUpdated -eq $true)) {
            #Create Dynamic form
            $body = @{
                Name       = $FormName;
                FormSchema = (ConvertFrom-Json-WithEmptyArray($FormSchema));
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/forms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body

            $formGuid = $response.dynamicFormGUID
            Write-Information "Dynamic form '$formName' created$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        } else {
            $formGuid = $response.dynamicFormGUID
            Write-Warning "Dynamic form '$FormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $formGuid })"
        }
    } catch {
        Write-Error "Dynamic form '$FormName', message: $_"
    }

    $returnObject.Value = $formGuid
}


function Invoke-HelloIDDelegatedForm {
    param(
        [parameter(Mandatory)][String]$DelegatedFormName,
        [parameter(Mandatory)][String]$DynamicFormGuid,
        [parameter()][Array][AllowEmptyString()]$AccessGroups,
        [parameter()][String][AllowEmptyString()]$Categories,
        [parameter(Mandatory)][String]$UseFaIcon,
        [parameter()][String][AllowEmptyString()]$FaIcon,
        [parameter()][String][AllowEmptyString()]$task,
        [parameter(Mandatory)][Ref]$returnObject
    )
    $delegatedFormCreated = $false
    $DelegatedFormName = $DelegatedFormName + $(if ($script:duplicateForm -eq $true) { $script:duplicateFormSuffix })

    try {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$DelegatedFormName")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        } catch {
            $response = $null
        }

        if([string]::IsNullOrEmpty($response.delegatedFormGUID)) {
            #Create DelegatedForm
            $body = @{
                name            = $DelegatedFormName;
                dynamicFormGUID = $DynamicFormGuid;
                isEnabled       = "True";
                useFaIcon       = $UseFaIcon;
                faIcon          = $FaIcon;
                task            = ConvertFrom-Json -inputObject $task;
            }
            if(-not[String]::IsNullOrEmpty($AccessGroups)) { 
                $body += @{
                    accessGroups    = (ConvertFrom-Json-WithEmptyArray($AccessGroups));
                }
            }
            $body = ConvertTo-Json -InputObject $body -Depth 100

            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body

            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Information "Delegated form '$DelegatedFormName' created$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
            $delegatedFormCreated = $true

            $bodyCategories = $Categories
            $uri = ($script:PortalBaseUrl +"api/v1/delegatedforms/$delegatedFormGuid/categories")
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $bodyCategories
            Write-Information "Delegated form '$DelegatedFormName' updated with categories"
        } else {
            #Get delegatedFormGUID
            $delegatedFormGuid = $response.delegatedFormGUID
            Write-Warning "Delegated form '$DelegatedFormName' already exists$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormGuid })"
        }
    } catch {
        Write-Error "Delegated form '$DelegatedFormName', message: $_"
    }

    $returnObject.value.guid = $delegatedFormGuid
    $returnObject.value.created = $delegatedFormCreated
}

<# Begin: HelloID Global Variables #>
foreach ($item in $globalHelloIDVariables) {
	Invoke-HelloIDGlobalVariable -Name $item.name -Value $item.value -Secret $item.secret 
}
<# End: HelloID Global Variables #>


<# Begin: HelloID Data sources #>
<# Begin: DataSource "Entra-ID-AFAS-account-update-phone | lookup-user-generate-table" #>
$tmpPsScript = @'
# Variables configured in form
$searchValue = $datasource.searchValue
if ($searchValue -eq "*") {
    $filter = "`$filter=accountEnabled eq true or accountEnabled eq false" # Get all users
}
else {
    $filter = "`$search=`"displayName:$searchValue`" OR `"userPrincipalName:$searchValue`" OR `"mail:$searchValue`""
}

# Global variables
# Outcommented as these are set from Global Variables
# $EntraIdTenantId = ""
# $EntraIdAppId = ""
# $EntraIdCertificateBase64String = ""
# $EntraIdCertificatePassword = ""

# Fixed values
$propertiesToSelect = @(
    "id",
    "userPrincipalName",
    "displayName",
    "employeeID",
    "department",
    "jobTitle",
    "companyName",
    "businessPhones",
    "mobilePhone"
) # Properties to select from Microsoft Graph API, comma separated

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

#region functions
function Resolve-MicrosoftGraphAPIError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json -ErrorAction Stop)
            if ($errorDetailsObject.error_description) {
                $httpErrorObj.FriendlyMessage = $errorDetailsObject.error_description
            }
            elseif ($errorDetailsObject.error.message) {
                $httpErrorObj.FriendlyMessage = "$($errorDetailsObject.error.code): $($errorDetailsObject.error.message)"
            }
            elseif ($errorDetailsObject.error.details.message) {
                $httpErrorObj.FriendlyMessage = "$($errorDetailsObject.error.details.code): $($errorDetailsObject.error.details.message)"
            }
            else {
                $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
            }
        }
        catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
        }
        Write-Output $httpErrorObj
    }
}

function Get-MSEntraAccessToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $Certificate,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AppId,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TenantId
    )
    try {
        # Get the DER encoded bytes of the certificate
        $derBytes = $Certificate.RawData

        # Compute the SHA-256 hash of the DER encoded bytes
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($derBytes)
        $base64Thumbprint = [System.Convert]::ToBase64String($hashBytes).Replace('+', '-').Replace('/', '_').Replace('=', '')

        # Create a JWT (JSON Web Token) header
        $header = @{
            'alg'      = 'RS256'
            'typ'      = 'JWT'
            'x5t#S256' = $base64Thumbprint
        } | ConvertTo-Json
        $base64Header = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($header))

        # Calculate the Unix timestamp (seconds since 1970-01-01T00:00:00Z) for 'exp', 'nbf' and 'iat'
        $currentUnixTimestamp = [math]::Round(((Get-Date).ToUniversalTime() - ([datetime]'1970-01-01T00:00:00Z').ToUniversalTime()).TotalSeconds)

        # Create a JWT payload
        $payload = [Ordered]@{
            'iss' = "$($AppId)"
            'sub' = "$($AppId)"
            'aud' = "https://login.microsoftonline.com/$($TenantId)/oauth2/token"
            'exp' = ($currentUnixTimestamp + 3600) # Expires in 1 hour
            'nbf' = ($currentUnixTimestamp - 300) # Not before 5 minutes ago
            'iat' = $currentUnixTimestamp
            'jti' = [Guid]::NewGuid().ToString()
        } | ConvertTo-Json
        $base64Payload = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payload)).Replace('+', '-').Replace('/', '_').Replace('=', '')

        # Extract the private key from the certificate
        $rsaPrivate = $Certificate.PrivateKey
        $rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new()
        $rsa.ImportParameters($rsaPrivate.ExportParameters($true))

        # Sign the JWT
        $signatureInput = "$base64Header.$base64Payload"
        $signature = $rsa.SignData([Text.Encoding]::UTF8.GetBytes($signatureInput), 'SHA256')
        $base64Signature = [System.Convert]::ToBase64String($signature).Replace('+', '-').Replace('/', '_').Replace('=', '')

        # Ensure the certificate has a private key
        if (-not $Certificate.HasPrivateKey -or -not $Certificate.PrivateKey) {
            throw "The certificate does not have a private key."
        }

        # Create the JWT token
        $jwtToken = "$($base64Header).$($base64Payload).$($base64Signature)"

        $createEntraAccessTokenBody = @{
            grant_type            = 'client_credentials'
            client_id             = $AppId
            client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
            client_assertion      = $jwtToken
            resource              = 'https://graph.microsoft.com'
        }

        $createEntraAccessTokenSplatParams = @{
            Uri         = "https://login.microsoftonline.com/$($TenantId)/oauth2/token"
            Body        = $createEntraAccessTokenBody
            Method      = 'POST'
            ContentType = 'application/x-www-form-urlencoded'
            Verbose     = $false
            ErrorAction = 'Stop'
        }

        $createEntraAccessTokenResponse = Invoke-RestMethod @createEntraAccessTokenSplatParams
        Write-Output $createEntraAccessTokenResponse.access_token
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-MSEntraCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $CertificateBase64String,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $CertificatePassword
    )
    try {
        $rawCertificate = [system.convert]::FromBase64String($CertificateBase64String)
        $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($rawCertificate, $CertificatePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
        Write-Output $certificate
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
#endregion functions

try {
    # Convert base64 certificate string to certificate object
    $actionMessage = "converting base64 certificate string to certificate object"
    $certificate = Get-MSEntraCertificate -CertificateBase64String $EntraIdCertificateBase64String -CertificatePassword $EntraIdCertificatePassword

    # Create access token
    $actionMessage = "creating access token"
    $entraToken = Get-MSEntraAccessToken -Certificate $certificate -AppId $EntraIdAppId -TenantId $EntraIdTenantId

    # Create headers
    $actionMessage = "creating headers"
    $headers = @{
        "Authorization"    = "Bearer $($entraToken)"
        "Accept"           = "application/json"
        "Content-Type"     = "application/json"
        "ConsistencyLevel" = "eventual" # Needed to filter on specific attributes (https://docs.microsoft.com/en-us/graph/aad-advanced-queries)
    }

    # Get Microsoft Entra ID Users
    # API docs: https://learn.microsoft.com/en-us/graph/api/user-list?view=graph-rest-1.0&tabs=http
    $actionMessage = "querying Microsoft Entra ID Users matching search value [$searchValue]"
    $microsoftEntraIDUsers = [System.Collections.ArrayList]@()
    do {
        $getMicrosoftEntraIDUsersSplatParams = @{
            Uri         = "https://graph.microsoft.com/v1.0/users?$filter&`$select=$($propertiesToSelect -join ',')&`$top=999&`$count=true"
            Headers     = $headers
            Method      = "GET"
            Verbose     = $false
            ErrorAction = "Stop"
        }
        if (-not[string]::IsNullOrEmpty($getMicrosoftEntraIDUsersResponse.'@odata.nextLink')) {
            $getMicrosoftEntraIDUsersSplatParams["Uri"] = $getMicrosoftEntraIDUsersResponse.'@odata.nextLink'
        }
        
        $getMicrosoftEntraIDUsersResponse = $null
        $getMicrosoftEntraIDUsersResponse = Invoke-RestMethod @getMicrosoftEntraIDUsersSplatParams
    
        # Select only specified properties to limit memory usage
        $getMicrosoftEntraIDUsersResponse.Value = $getMicrosoftEntraIDUsersResponse.Value | Select-Object $propertiesToSelect

        if ($getMicrosoftEntraIDUsersResponse.Value -is [array]) {
            [void]$microsoftEntraIDUsers.AddRange($getMicrosoftEntraIDUsersResponse.Value)
        }
        else {
            [void]$microsoftEntraIDUsers.Add($getMicrosoftEntraIDUsersResponse.Value)
        }
    } while (-not[string]::IsNullOrEmpty($getMicrosoftEntraIDUsersResponse.'@odata.nextLink'))
    Write-Information "Queried Microsoft Entra ID Users matching search value [$searchValue]. Result count: $(($microsoftEntraIDUsers | Measure-Object).count)"

    # Send results to HelloID
    $actionMessage = "sending results to HelloID"
    if (($microsoftEntraIDUsers | Measure-Object).count -gt 0) {
        $microsoftEntraIDUsers | ForEach-Object {
            $_.businessPhones = $_.businessPhones[0]
            Write-Output $_
        }
    }
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-MicrosoftGraphAPIError -ErrorObject $ex
        $auditMessage = "Error $($actionMessage). Error: $($errorObj.FriendlyMessage)"
        $warningMessage = "Error at Line [$($errorObj.ScriptLineNumber)]: $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
        $warningMessage = "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    Write-Warning $warningMessage
    Write-Error $auditMessage
}
  
'@ 
$tmpModel = @'
[{"key":"id","type":0},{"key":"userPrincipalName","type":0},{"key":"displayName","type":0},{"key":"employeeId","type":0},{"key":"department","type":0},{"key":"jobTitle","type":0},{"key":"companyName","type":0},{"key":"businessPhones","type":0},{"key":"mobilePhone","type":0}]
'@ 
$tmpInput = @'
[{"description":null,"translateDescription":false,"inputFieldType":1,"key":"searchValue","type":0,"options":1}]
'@ 
$dataSourceGuid_0 = [PSCustomObject]@{} 
$dataSourceGuid_0_Name = @'
Entra-ID-AFAS-account-update-phone | lookup-user-generate-table
'@ 
Invoke-HelloIDDatasource -DatasourceName $dataSourceGuid_0_Name -DatasourceType "4" -DatasourceInput $tmpInput -DatasourcePsScript $tmpPsScript -DatasourceModel $tmpModel -DataSourceRunInCloud "True" -returnObject ([Ref]$dataSourceGuid_0) 
<# End: DataSource "Entra-ID-AFAS-account-update-phone | lookup-user-generate-table" #>
<# End: HelloID Data sources #>

<# Begin: Dynamic Form "Entra ID AFAS Account - Update phone" #>
$tmpSchema = @"
[{"label":"Select user account","fields":[{"key":"searchfield","templateOptions":{"label":"Search field (wildcard search in Display name, UserPrincipalName and mail)","placeholder":"Display name, UserPrincipalName, or mail (use * to search all users)","required":true,"minLength":1},"type":"input","summaryVisibility":"Hide element","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"gridUsers","templateOptions":{"label":"Select user account","required":true,"grid":{"columns":[{"headerName":"Employee ID","field":"employeeId"},{"headerName":"Display Name","field":"displayName"},{"headerName":"User Principal Name","field":"userPrincipalName"},{"headerName":"Mobile Phone","field":"mobilePhone"},{"headerName":"Business Phones","field":"businessPhones"}],"height":300,"rowSelection":"single"},"dataSourceConfig":{"dataSourceGuid":"$dataSourceGuid_0","input":{"propertyInputs":[{"propertyName":"searchValue","otherFieldValue":{"otherFieldKey":"searchfield"}}]}},"useFilter":false,"allowCsvDownload":true},"type":"grid","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":true}]},{"label":"Details","fields":[{"templateOptions":{"title":"The mobile number entered below will be applied to both the Entra ID user and the AFAS employee.","titleField":"","bannerType":"Info","useBody":false},"type":"textbanner","summaryVisibility":"Hide element","body":"Text Banner Content","requiresTemplateOptions":false,"requiresKey":false,"requiresDataSource":false},{"key":"mobilePhone","templateOptions":{"label":"Mobile work","pattern":"^\\+316\\d{8}$","useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"mobilePhone"},"validation":{"messages":{"pattern":"Please fill in the mobile number in the following format: +31612345678"}},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false},{"key":"businessPhones","templateOptions":{"label":"Fixed work","pattern":"^(088-123)+[0-9]{4}$","useDependOn":true,"dependOn":"gridUsers","dependOnProperty":"businessPhones"},"validation":{"messages":{"pattern":"Please fill in the mobile number in the following format: 088-123xxxx"}},"type":"input","summaryVisibility":"Show","requiresTemplateOptions":true,"requiresKey":true,"requiresDataSource":false}]}]
"@ 

$dynamicFormGuid = [PSCustomObject]@{} 
$dynamicFormName = @'
Entra ID AFAS Account - Update phone
'@ 
Invoke-HelloIDDynamicForm -FormName $dynamicFormName -FormSchema $tmpSchema  -returnObject ([Ref]$dynamicFormGuid) 
<# END: Dynamic Form #>

<# Begin: Delegated Form Access Groups and Categories #>
$delegatedFormAccessGroupGuids = @()
if(-not[String]::IsNullOrEmpty($delegatedFormAccessGroupNames)){
    foreach($group in $delegatedFormAccessGroupNames) {
        try {
            $uri = ($script:PortalBaseUrl +"api/v1/groups/$group")
            $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
            $delegatedFormAccessGroupGuid = $response.groupGuid
            $delegatedFormAccessGroupGuids += $delegatedFormAccessGroupGuid
        
            Write-Information "HelloID (access)group '$group' successfully found$(if ($script:debugLogging -eq $true) { ": " + $delegatedFormAccessGroupGuid })"
        } catch {
            Write-Error "HelloID (access)group '$group', message: $_"
        }
    }
    if($null -ne $delegatedFormAccessGroupGuids){
        $delegatedFormAccessGroupGuids = ($delegatedFormAccessGroupGuids | Select-Object -Unique | ConvertTo-Json -Depth 100 -Compress)
    }
}

$delegatedFormCategoryGuids = @()
foreach($category in $delegatedFormCategories) {
    try {
        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories/$category")
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false
        $response = $response | Where-Object {$_.name.en -eq $category}
    
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid
    
        Write-Information "HelloID Delegated Form category '$category' successfully found$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    } catch {
        Write-Warning "HelloID Delegated Form category '$category' not found"
        $body = @{
            name = @{"en" = $category};
        }
        $body = ConvertTo-Json -InputObject $body -Depth 100

        $uri = ($script:PortalBaseUrl +"api/v1/delegatedformcategories")
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $script:headers -ContentType "application/json" -Verbose:$false -Body $body
        $tmpGuid = $response.delegatedFormCategoryGuid
        $delegatedFormCategoryGuids += $tmpGuid

        Write-Information "HelloID Delegated Form category '$category' successfully created$(if ($script:debugLogging -eq $true) { ": " + $tmpGuid })"
    }
}
$delegatedFormCategoryGuids = (ConvertTo-Json -InputObject $delegatedFormCategoryGuids -Depth 100 -Compress)
<# End: Delegated Form Access Groups and Categories #>

<# Begin: Delegated Form #>
$delegatedFormRef = [PSCustomObject]@{guid = $null; created = $null} 
$delegatedFormName = @'
Entra ID AFAS Account - Update phone
'@
$tmpTask = @'
{"name":"Entra ID AFAS Account - Update phone","script":"#region init\r\n\r\n# Enable TLS1.2\r\n[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12\r\n\r\n$VerbosePreference = \"SilentlyContinue\"\r\n$InformationPreference = \"Continue\"\r\n$WarningPreference = \"Continue\"\r\n\r\n# variables configured in form:\r\n$userPrincipalName = $form.gridUsers.userPrincipalName\r\n$entraidGUID = $form.gridUsers.id\r\n$displayname = $form.gridUsers.displayName\r\n$phoneMobile = $form.mobilePhone\r\n$phoneMobileOld = $form.gridUsers.mobilePhone\r\n$phoneFixed = $form.businessPhones\r\n$phoneFixedOld = $form.gridUsers.businessPhones\r\n$employeeID = $form.gridUsers.employeeId\r\n#endregion init\r\n\r\n#region Entra ID functions\r\nfunction Get-ErrorMessage {\r\n    [CmdletBinding()]\r\n    param (\r\n        [Parameter(Mandatory)]\r\n        [object]\r\n        $ErrorObject\r\n    )\r\n    process {\r\n        $httpErrorObj = [PSCustomObject]@{\r\n            ScriptLineNumber    = $ErrorObject.InvocationInfo.ScriptLineNumber\r\n            Line                = $ErrorObject.InvocationInfo.Line\r\n            VerboseErrorMessage = $ErrorObject.Exception.Message\r\n            AuditErrorMessage   = $ErrorObject.Exception.Message\r\n        }\r\n        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {\r\n            $httpErrorObj.VerboseErrorMessage = $ErrorObject.ErrorDetails.Message\r\n        }\r\n        elseif ($ErrorObject.Exception.GetType().FullName -eq \u0027System.Net.WebException\u0027) {\r\n            if ($null -ne $ErrorObject.Exception.Response) {\r\n                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()\r\n                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {\r\n                    $httpErrorObj.VerboseErrorMessage = $streamReaderResponse\r\n                }\r\n            }\r\n        }\r\n        try {\r\n            $errorDetailsObject = ($httpErrorObj.VerboseErrorMessage | ConvertFrom-Json)\r\n            # Make sure to inspect the error result object and add only the error message as a FriendlyMessage.\r\n            $httpErrorObj.VerboseErrorMessage = $errorDetailsObject.error\r\n            $httpErrorObj.AuditErrorMessage = $errorDetailsObject.error.message\r\n            if ($null -eq $httpErrorObj.AuditErrorMessage) {\r\n                $httpErrorObj.AuditErrorMessage = $errorDetailsObject.error\r\n            }\r\n        }\r\n        catch {\r\n            $httpErrorObj.AuditErrorMessage = $httpErrorObj.VerboseErrorMessage\r\n        }\r\n        Write-Output $httpErrorObj\r\n    }\r\n}\r\n\r\nfunction Get-MSEntraAccessToken {\r\n    [CmdletBinding()]\r\n    param(\r\n        [Parameter(Mandatory)]\r\n        $Certificate\r\n    )\r\n    try {\r\n        # Get the DER encoded bytes of the certificate\r\n        $derBytes = $Certificate.RawData\r\n\r\n        # Compute the SHA-256 hash of the DER encoded bytes\r\n        $sha256 = [System.Security.Cryptography.SHA256]::Create()\r\n        $hashBytes = $sha256.ComputeHash($derBytes)\r\n        $base64Thumbprint = [System.Convert]::ToBase64String($hashBytes).Replace(\u0027+\u0027, \u0027-\u0027).Replace(\u0027/\u0027, \u0027_\u0027).Replace(\u0027=\u0027, \u0027\u0027)\r\n\r\n        # Create a JWT (JSON Web Token) header\r\n        $header = @{\r\n            \u0027alg\u0027      = \u0027RS256\u0027\r\n            \u0027typ\u0027      = \u0027JWT\u0027\r\n            \u0027x5t#S256\u0027 = $base64Thumbprint\r\n        } | ConvertTo-Json\r\n        $base64Header = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($header))\r\n\r\n        # Calculate the Unix timestamp (seconds since 1970-01-01T00:00:00Z) for \u0027exp\u0027, \u0027nbf\u0027 and \u0027iat\u0027\r\n        $currentUnixTimestamp = [math]::Round(((Get-Date).ToUniversalTime() - ([datetime]\u00271970-01-01T00:00:00Z\u0027).ToUniversalTime()).TotalSeconds)\r\n\r\n        # Create a JWT payload\r\n        $payload = [Ordered]@{\r\n            \u0027iss\u0027 = \"$entraidappid\"\r\n            \u0027sub\u0027 = \"$entraidappid\"\r\n            \u0027aud\u0027 = \"https://login.microsoftonline.com/$EntraIdTenantId/oauth2/token\"\r\n            \u0027exp\u0027 = ($currentUnixTimestamp + 3600) # Expires in 1 hour\r\n            \u0027nbf\u0027 = ($currentUnixTimestamp - 300) # Not before 5 minutes ago\r\n            \u0027iat\u0027 = $currentUnixTimestamp\r\n            \u0027jti\u0027 = [Guid]::NewGuid().ToString()\r\n        } | ConvertTo-Json\r\n        $base64Payload = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payload)).Replace(\u0027+\u0027, \u0027-\u0027).Replace(\u0027/\u0027, \u0027_\u0027).Replace(\u0027=\u0027, \u0027\u0027)\r\n\r\n        # Extract the private key from the certificate\r\n        $rsaPrivate = $Certificate.PrivateKey\r\n        $rsa = [System.Security.Cryptography.RSACryptoServiceProvider]::new()\r\n        $rsa.ImportParameters($rsaPrivate.ExportParameters($true))\r\n\r\n        # Sign the JWT\r\n        $signatureInput = \"$base64Header.$base64Payload\"\r\n        $signature = $rsa.SignData([Text.Encoding]::UTF8.GetBytes($signatureInput), \u0027SHA256\u0027)\r\n        $base64Signature = [System.Convert]::ToBase64String($signature).Replace(\u0027+\u0027, \u0027-\u0027).Replace(\u0027/\u0027, \u0027_\u0027).Replace(\u0027=\u0027, \u0027\u0027)\r\n\t\r\n\t# Extract the private key from the certificate\r\n        if (-not $Certificate.HasPrivateKey -or -not $Certificate.PrivateKey) {\r\n            throw \"The certificate does not have a private key.\"\r\n        }\r\n\r\n        # Create the JWT token\r\n        $jwtToken = \"$($base64Header).$($base64Payload).$($base64Signature)\"\r\n\r\n        $createEntraAccessTokenBody = @{\r\n            grant_type            = \u0027client_credentials\u0027\r\n            client_id             = $entraidappid\r\n            client_assertion_type = \u0027urn:ietf:params:oauth:client-assertion-type:jwt-bearer\u0027\r\n            client_assertion      = $jwtToken\r\n            resource              = \u0027https://graph.microsoft.com\u0027\r\n        }\r\n\r\n        $createEntraAccessTokenSplatParams = @{\r\n            Uri         = \"https://login.microsoftonline.com/$EntraIdTenantId/oauth2/token\"\r\n            Body        = $createEntraAccessTokenBody\r\n            Method      = \u0027POST\u0027\r\n            ContentType = \u0027application/x-www-form-urlencoded\u0027\r\n            Verbose     = $false\r\n            ErrorAction = \u0027Stop\u0027\r\n        }\r\n\r\n        $createEntraAccessTokenResponse = Invoke-RestMethod @createEntraAccessTokenSplatParams\r\n        Write-Output $createEntraAccessTokenResponse.access_token\r\n    }\r\n    catch {\r\n        $PSCmdlet.ThrowTerminatingError($_)\r\n    }\r\n}\r\n\r\nfunction Get-MSEntraCertificate {\r\n    [CmdletBinding()]\r\n    param()\r\n    try {\r\n        $rawCertificate = [system.convert]::FromBase64String($EntraIdCertificateBase64String)\r\n        $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($rawCertificate, $EntraIdCertificatePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)\r\n        Write-Output $certificate\r\n    }\r\n    catch {\r\n        $PSCmdlet.ThrowTerminatingError($_)\r\n    }\r\n}\r\n\r\n#endregion Entra ID functions\r\n\r\n\r\n\r\n#region EntraID\r\ntry {\r\n    $account = [PSCustomObject]@{   \r\n        mobilePhone    = $phoneMobile\r\n        businessPhones = @($phoneFixed)\r\n    }\r\n\r\n    if ([string]::IsNullOrEmpty($account.mobilePhone)) {\r\n        $account.mobilePhone = $null\r\n    }\r\n    if ([string]::IsNullOrEmpty($account.businessPhones)) {\r\n        $account.businessPhones = @()\r\n    }\r\n\r\n    # Setup Connection with Entra/Exo\r\n    Write-Verbose \u0027connecting to MS-Entra\u0027\r\n    $certificate = Get-MSEntraCertificate\r\n    $entraToken = Get-MSEntraAccessToken -Certificate $certificate\r\n    \r\n    #Add the authorization header to the request\r\n    $authorization = @{\r\n        Authorization = \"Bearer $entraToken\";\r\n        \u0027Content-Type\u0027 = \"application/json\";\r\n        Accept = \"application/json\";\r\n    } \r\n \r\n    $baseUpdateUri = \"https://graph.microsoft.com/\"\r\n    $updateUri = $baseUpdateUri + \"v1.0/users/$($entraidGUID)\"\r\n    $body = $account | ConvertTo-Json -Depth 10\r\n \r\n    $response = Invoke-RestMethod -Uri $updateUri -Method PATCH -Headers $authorization -Body $body -Verbose:$false\r\n    \r\n    Write-Information \"Finished updating Entra ID user [$userPrincipalName] attributes [MobilePhone] from [$phoneMobileOld] to [$phoneMobile] and [BusinessPhones] from [$phoneFixedOld] to [$phoneFixed]\"\r\n    $Log = @{\r\n        Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"Entra ID\" # optional (free format text) \r\n        Message           = \"Successfully updated Entra ID user [$userPrincipalName] attributes [MobilePhone] from [$phoneMobileOld] to [$phoneMobile] and [BusinessPhones] from [$phoneFixedOld] to [$phoneFixed]\"\r\n        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $displayname # optional (free format text) \r\n        TargetIdentifier  = $([string]$entraidGUID) # optional (free format text) \r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log    \r\n}\r\ncatch {\r\n    $ex = $PSItem\r\n    $errorMessage = Get-ErrorMessage -ErrorObject $ex\r\n\r\n    Write-Verbose \"Error at Line [$($errorMessage.InvocationInfo.ScriptLineNumber)]: $($errorMessage.InvocationInfo.Line). Error: $($($errorMessage.VerboseErrorMessage))\"\r\n    Write-Error \"Could not update attribute [phoneMobile] of AD user [$userPrincipalName] to [$phoneMobile]. Error: $($errorMessage.AuditErrorMessage)\"\r\n    $Log = @{\r\n        Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"Entra ID\" # optional (free format text) \r\n        Message           = \"Failed to update Entra ID user [$userPrincipalName] attributes [MobilePhone] from [$phoneMobileOld] to [$phoneMobile] and [BusinessPhones] from [$phoneFixedOld] to [$phoneFixed]\"\r\n        IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $displayname # optional (free format text) \r\n        TargetIdentifier  = $([string]$entraidGUID) # optional (free format text) \r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log      \r\n}\r\n#endregion EntraID\r\n\r\n#region AFAS\r\nfunction Resolve-AFASErrorMessage {\r\n    [CmdletBinding()]\r\n    param (\r\n        [Parameter(ValueFromPipeline)]\r\n        [object]$ErrorObject\r\n    )\r\n    process {\r\n        try {\r\n            $errorObjectConverted = $ErrorObject | ConvertFrom-Json -ErrorAction Stop\r\n\r\n            if ($null -ne $errorObjectConverted.externalMessage) {\r\n                $errorMessage = $errorObjectConverted.externalMessage\r\n            }\r\n            else {\r\n                $errorMessage = $errorObjectConverted\r\n            }\r\n        }\r\n        catch {\r\n            $errorMessage = \"$($ErrorObject.Exception.Message)\"\r\n        }\r\n\r\n        Write-Output $errorMessage\r\n    }\r\n}\r\n\r\nfunction Resolve-HTTPError {\r\n    [CmdletBinding()]\r\n    param (\r\n        [Parameter(Mandatory,\r\n            ValueFromPipeline\r\n        )]\r\n        [object]$ErrorObject\r\n    )\r\n    process {\r\n        $httpErrorObj = [PSCustomObject]@{\r\n            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId\r\n            MyCommand             = $ErrorObject.InvocationInfo.MyCommand\r\n            RequestUri            = $ErrorObject.TargetObject.RequestUri\r\n            ScriptStackTrace      = $ErrorObject.ScriptStackTrace\r\n            ErrorMessage          = \u0027\u0027\r\n        }\r\n        if ($ErrorObject.Exception.GetType().FullName -eq \u0027Microsoft.PowerShell.Commands.HttpResponseException\u0027) {\r\n            $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message\r\n        }\r\n        elseif ($ErrorObject.Exception.GetType().FullName -eq \u0027System.Net.WebException\u0027) {\r\n            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()\r\n        }\r\n        Write-Output $httpErrorObj\r\n    }\r\n}\r\n\r\n# Used to connect to AFAS API endpoints\r\nif (-not([string]::IsNullOrEmpty($employeeID))) {\r\n    $BaseUri = $AFASBaseUrl\r\n    $Token = $AFASToken\r\n    $getConnector = \"T4E_HelloID_Users_v2\"\r\n    $updateConnector = \"KnEmployee\"\r\n\r\n    #Change mapping here\r\n    $account = [PSCustomObject]@{\r\n        \u0027AfasEmployee\u0027 = @{\r\n            \u0027Element\u0027 = @{\r\n                \u0027Objects\u0027 = @(\r\n                    @{\r\n                        \u0027KnPerson\u0027 = @{\r\n                            \u0027Element\u0027 = @{\r\n                                \u0027Fields\u0027 = @{\r\n                                    # # Telefoonnr. werk\r\n                                    #\u0027TeNr\u0027 = $phoneFixed                     \r\n                                    # Mobiel werk\r\n                                    \u0027MbNr\u0027 = $phoneMobile\r\n                                }\r\n                            }\r\n                        }\r\n                    }\r\n                )\r\n            }\r\n        }\r\n    }\r\n\r\n    $filterfieldid = \"Medewerker\"\r\n    $filtervalue = $employeeID # Has to match the AFAS value of the specified filter field ($filterfieldid)\r\n\r\n    # Get current AFAS employee and verify if a user must be either [created], [updated and correlated] or just [correlated]\r\n    try {\r\n        Write-Information \"Querying AFAS employee with $($filterfieldid) $($filtervalue)\"\r\n\r\n        # Create authorization headers\r\n        $encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token))\r\n        $authValue = \"AfasToken $encodedToken\"\r\n        $Headers = @{ Authorization = $authValue }\r\n        $Headers.Add(\"IntegrationId\", \"45963_140664\") # Fixed value - Tools4ever Partner Integration ID\r\n\r\n        $splatWebRequest = @{\r\n            Uri             = $BaseUri + \"/connectors/\" + $getConnector + \"?filterfieldids=$filterfieldid\u0026filtervalues=$filtervalue\u0026operatortypes=1\"\r\n            Headers         = $headers\r\n            Method          = \u0027GET\u0027\r\n            ContentType     = \"application/json;charset=utf-8\"\r\n            UseBasicParsing = $true\r\n        }        \r\n        $currentAccount = (Invoke-RestMethod @splatWebRequest -Verbose:$false).rows\r\n\r\n        if ($null -eq $currentAccount.Medewerker) {\r\n            throw \"No AFAS employee found with $($filterfieldid) $($filtervalue)\"\r\n        }\r\n        Write-Information \"Found AFAS employee [$($currentAccount.Medewerker)]\"\r\n        # Check if current TeNr or MbNr has a different value from mapped value. AFAS will throw an error when trying to update this with the same value\r\n        if ([string]$currentAccount.Telefoonnr_werk -ne $account.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027TeNr\u0027 -and $null -ne $account.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027TeNr\u0027) {\r\n            $propertiesChanged += @(\u0027TeNr\u0027)\r\n        }\r\n        if ([string]$currentAccount.Mobielnr_werk -ne $account.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027MbNr\u0027 -and $null -ne $account.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027MbNr\u0027) {\r\n            $propertiesChanged += @(\u0027MbNr\u0027)\r\n        }\r\n        if ($propertiesChanged) {\r\n            Write-Verbose \"Account property(s) required to update: [$($propertiesChanged -join \",\")]\"\r\n            $updateAction = \u0027Update\u0027\r\n        }\r\n        else {\r\n            $updateAction = \u0027NoChanges\u0027\r\n        }\r\n\r\n        # Update AFAS Employee\r\n        Write-Information \"Start updating AFAS employee [$($currentAccount.Medewerker)]\"\r\n        switch ($updateAction) {\r\n            \u0027Update\u0027 {\r\n                # Create custom account object for update\r\n                $updateAccount = [PSCustomObject]@{\r\n                    \u0027AfasEmployee\u0027 = @{\r\n                        \u0027Element\u0027 = @{\r\n                            \u0027@EmId\u0027   = $currentAccount.Medewerker\r\n                            \u0027Objects\u0027 = @(@{\r\n                                    \u0027KnPerson\u0027 = @{\r\n                                        \u0027Element\u0027 = @{\r\n                                            \u0027Fields\u0027 = @{\r\n                                                # Zoek op BcCo (Persoons-ID)\r\n                                                \u0027MatchPer\u0027 = 0\r\n                                                # Nummer\r\n                                                \u0027BcCo\u0027     = $currentAccount.Persoonsnummer\r\n                                            }\r\n                                        }\r\n                                    }\r\n                                })\r\n                        }\r\n                    }\r\n                }\r\n                if (\u0027TeNr\u0027 -in $propertiesChanged) {\r\n                    # Telefoonnr. werk\r\n                    $updateAccount.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027TeNr\u0027 = $account.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027TeNr\u0027\r\n                    Write-Information \"Updating TeNr \u0027$($currentAccount.Telefoonnr_werk)\u0027 with new value \u0027$($updateAccount.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027TeNr\u0027)\u0027\"\r\n                }\r\n\r\n                if (\u0027MbNr\u0027 -in $propertiesChanged) {\r\n                    # Mobiel werk\r\n                    $updateAccount.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027MbNr\u0027 = $account.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027MbNr\u0027\r\n                    Write-Information \"Updating MbNr \u0027$($currentAccount.Mobielnr_werk)\u0027 with new value \u0027$($updateAccount.\u0027AfasEmployee\u0027.\u0027Element\u0027.Objects[0].\u0027KnPerson\u0027.\u0027Element\u0027.\u0027Fields\u0027.\u0027MbNr\u0027)\u0027\"\r\n                }\r\n\r\n                $body = ($updateAccount | ConvertTo-Json -Depth 10)\r\n                $splatWebRequest = @{\r\n                    Uri             = $BaseUri + \"/connectors/\" + $updateConnector\r\n                    Headers         = $headers\r\n                    Method          = \u0027PUT\u0027\r\n                    Body            = ([System.Text.Encoding]::UTF8.GetBytes($body))\r\n                    ContentType     = \"application/json;charset=utf-8\"\r\n                    UseBasicParsing = $true\r\n                }\r\n\r\n                $updatedAccount = Invoke-RestMethod @splatWebRequest -Verbose:$false\r\n                Write-Information \"Successfully updated AFAS employee [$employeeID] attributes [MbNr] from [$phoneMobileOld] to [$phoneMobile] and [TeNr] from [$($currentAccount.Telefoonnr_werk)] to [$phoneFixed]\"\r\n                $Log = @{\r\n                    Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n                    System            = \"AFAS Employee\" # optional (free format text) \r\n                    Message           = \"Successfully updated AFAS employee [$employeeID] attributes [MbNr] from [$phoneMobileOld] to [$phoneMobile] and [TeNr] from [$($currentAccount.Telefoonnr_werk)] to [$phoneFixed]\" # required (free format text) \r\n                    IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n                    TargetDisplayName = $displayName # optional (free format text) \r\n                    TargetIdentifier  = $([string]$employeeID) # optional (free format text) \r\n                }\r\n                #send result back  \r\n                Write-Information -Tags \"Audit\" -MessageData $log  \r\n                break\r\n            }\r\n            \u0027NoChanges\u0027 {\r\n                Write-Information \"Successfully checked AFAS employee [$employeeID] attributes [MbNr] and [TeNr], no changes needed\"\r\n                $Log = @{\r\n                    Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n                    System            = \"AFAS Employee\" # optional (free format text) \r\n                    Message           = \"Successfully checked AFAS employee [$employeeID] attributes [MbNr] [$($currentAccount.Mobielnr_werk)] and [TeNr] [$($currentAccount.Telefoonnr_werk)], no changes needed\" # required (free format text) \r\n                    IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n                    TargetDisplayName = $displayName # optional (free format text) \r\n                    TargetIdentifier  = $([string]$employeeID) # optional (free format text) \r\n                }\r\n                #send result back  \r\n                Write-Information -Tags \"Audit\" -MessageData $log  \r\n                break\r\n            }\r\n        }\r\n    }\r\n    catch {\r\n        $ex = $PSItem\r\n        if ( $($ex.Exception.GetType().FullName -eq \u0027Microsoft.PowerShell.Commands.HttpResponseException\u0027) -or $($ex.Exception.GetType().FullName -eq \u0027System.Net.WebException\u0027)) {\r\n            $errorObject = Resolve-HTTPError -Error $ex\r\n\r\n            $verboseErrorMessage = $errorObject.ErrorMessage\r\n\r\n            $auditErrorMessage = Resolve-AFASErrorMessage -ErrorObject $errorObject.ErrorMessage\r\n        }\r\n\r\n        # If error message empty, fall back on $ex.Exception.Message\r\n        if ([String]::IsNullOrEmpty($verboseErrorMessage)) {\r\n            $verboseErrorMessage = $ex.Exception.Message\r\n        }\r\n        if ([String]::IsNullOrEmpty($auditErrorMessage)) {\r\n            $auditErrorMessage = $ex.Exception.Message\r\n        }\r\n\r\n        Write-Verbose \"Error at Line \u0027$($ex.InvocationInfo.ScriptLineNumber)\u0027: $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)\"\r\n\r\n        if ($auditErrorMessage -Like \"No AFAS employee found with $($filterfieldid) $($filtervalue)\") {\r\n            Write-Error \"Failed to update AFAS employee [$employeeID]: No AFAS employee found with $($filterfieldid) $($filtervalue)\"\r\n            Write-Information \"Failed to update AFAS employee [$employeeID]: No AFAS employee found with $($filterfieldid) $($filtervalue)\"\r\n            $Log = @{\r\n                Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n                System            = \"AFAS Employee\" # optional (free format text) \r\n                Message           = \"Failed to update AFAS employee [$employeeID]: No AFAS employee found with $($filterfieldid) $($filtervalue)\" # required (free format text) \r\n                IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n                TargetDisplayName = $displayName # optional (free format text) \r\n                TargetIdentifier  = $([string]$employeeID) # optional (free format text) \r\n            }\r\n            #send result back  \r\n            Write-Information -Tags \"Audit\" -MessageData $log \r\n        }\r\n        else {\r\n            Write-Verbose \"Error at Line \u0027$($ex.InvocationInfo.ScriptLineNumber)\u0027: $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)\"\r\n            Write-Error \"Error updating AFAS employee [$employeeID] attributes [MbNr] from [$($currentAccount.Mobielnr_werk)] to [$phoneMobile] and [TeNr] from [$($currentAccount.Telefoonnr_werk)] to [$phoneFixed]. Error Message: $auditErrorMessage\"\r\n            Write-Information \"Error updating AFAS employee [$employeeID] attributes [MbNr] from [$($currentAccount.Mobielnr_werk)] to [$phoneMobile] and [TeNr] from [$($currentAccount.Telefoonnr_werk)] to [$phoneFixed]. Error Message: $auditErrorMessage\"\r\n            $Log = @{\r\n                Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n                System            = \"AFAS Employee\" # optional (free format text) \r\n                Message           = \"Error updating AFAS employee [$employeeID] attributes [MbNr] from [$($currentAccount.Mobielnr_werk)] to [$phoneMobile] and [TeNr] from [$($currentAccount.Telefoonnr_werk)] to [$phoneFixed]. Error Message: $auditErrorMessage\" # required (free format text) \r\n                IsError           = $true # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n                TargetDisplayName = $displayName # optional (free format text) \r\n                TargetIdentifier  = $([string]$employeeID) # optional (free format text) \r\n            }\r\n            #send result back  \r\n            Write-Information -Tags \"Audit\" -MessageData $log \r\n        }\r\n    }\r\n}\r\nelse {\r\n    Write-Information \"Skipped update attribute [MbNr] and [TeNr] of AFAS employee [$displayName] to [$phoneMobile] and [$phoneFixed]: employeeID is empty\"\r\n    $Log = @{\r\n        Action            = \"UpdateAccount\" # optional. ENUM (undefined = default) \r\n        System            = \"AFAS Employee\" # optional (free format text) \r\n        Message           = \"Skipped update attribute [MbNr] and [TeNr] of AFAS employee [$displayName] to [$phoneMobile] and [$phoneFixed]: employeeID is empty\" # required (free format text) \r\n        IsError           = $false # optional. Elastic reporting purposes only. (default = $false. $true = Executed action returned an error) \r\n        TargetDisplayName = $displayName # optional (free format text) \r\n        TargetIdentifier  = $([string]$employeeID) # optional (free format text)\r\n    }\r\n    #send result back  \r\n    Write-Information -Tags \"Audit\" -MessageData $log \r\n}\r\n#endregion AFAS","runInCloud":true}
'@ 

Invoke-HelloIDDelegatedForm -DelegatedFormName $delegatedFormName -DynamicFormGuid $dynamicFormGuid -AccessGroups $delegatedFormAccessGroupGuids -Categories $delegatedFormCategoryGuids -UseFaIcon "True" -FaIcon "fa fa-phone" -task $tmpTask -returnObject ([Ref]$delegatedFormRef) 
<# End: Delegated Form #>

