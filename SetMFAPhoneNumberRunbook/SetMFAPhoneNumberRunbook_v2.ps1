<#
    .SYNOPSIS
        Sets, removes or updates the phoneNumber used for Multi-factor Authentication based on input from either manually provided data or from Azure AD Directory Synced value from ExtensionAttribute15.
       
        Microsoft Graph throttling is handled using best practices from this article, both with Retry-After and exponential backoff. 
        
        According to the "Note":
        "If no Retry-After header is provided by the response, we recommend implementing an exponential backoff retry policy."
        
        https://docs.microsoft.com/en-us/graph/throttling#best-practices-to-handle-throttling

    .DESCRIPTION
        This script will run off of a webhook execution - provided that it is including the correct header handshake and webhook data. 
        The webhook data must include these fields of data: 'UserPrincipalName'

        Optional field data may include 'Mobile' or 'OverwriteNull'. 

        E.g

        $uri = "<Webhook-URI>"
        $header = @{ Message = "<your-secret-handshake>" }
        $users = @(
            # Default: Payload data only sends a UserPrincipalName, that UserPrincipalName is then queried in Azure AD for extensionAttribute15 and uses it as source value for MFA phoneNumber.
            @{ UserPrincipalName="firstname1.lastname1@domain.com"}

            # Set the users phone number to the explicetly included value (override ExtensionAttribute15 value)
            @{ UserPrincipalName="firstname2.lastname2@domain.com"; Mobile="+46701234567"}

            # Explicitly overwrite current MFA number with $null, if both 'Mobile' payload data and extensionAttribute15 is empty. (this is inexplicetly the default behavior).
            @{ UserPrincipalName="firstname3.lastname3@domain.com"; Mobile=""; OverwriteNull="1"}

            # Bypass default OverwriteNull setting: If both 'Mobile' payload data and extensionAttribute15 is empty, do not overwrite the user's current MFA number with $null.
            @{ UserPrincipalName="firstname4.lastname4@domain.com"; Mobile=""; OverwriteNull="0"}
        )
        $body = ConvertTo-Json -InputObject $users

        Invoke-WebRequest -Method Post -Uri $uri -Body $body -Headers $header

        * The 'Mobile' field, if provided, will override the value of ExtensionAttribute15.

        * Optionally set 'OverwriteNull' to a value of either '1' or '0':

          If no value is present the OverwriteNull will be $True or '1', which will default to 
          removing phoneNumber from MFA if no value exists for either ExtensionAttribute15 and 
          when the manually provided 'Mobile' field value is empty. This is the default behavior.

          Set to '1' to remove phoneNumber from MFA if no value exists for either 
          ExtensionAttribute15 and if manually provided 'Mobile' field value is empty. 
          Again, this is the default behavior.

          Set to '0' to effectively bypass and disable the automatic removal of an already 
          configured mobilePhone value for MFA, even if ExtensionAttribute15 or manually 
          provided 'Mobile' field is empty.
    .EXAMPLE

    .NOTES
        Copyright (C) 2019-2022 Niklas J. MacDowall. All rights reserved.

        AUTHOR: Niklas J. MacDowall (niklasjumlin [at] gmail [dot] com)
        LASTEDIT: Jan 13, 2022

    .LINK
        http://blog.jumlin.com
#>

Param
(
    [Parameter (Mandatory= $false)]
    [Object]$WebhookData
)

# If runbook was called from Webhook, WebhookData will not be null.
if ($WebhookData) {
    # Check header for message to validate request
    if ($WebhookData.RequestHeader.message -eq '81c5988d-862a-4f15-8cda-37422722f1b6')
    {
        Write-Output "Header has required information"}
    else
    {
        Write-Output "Header missing required information";
        exit;
    }
    if (-not($WebhookData.RequestBody)) {
        $WebhookData = (ConvertFrom-Json -InputObject $WebhookData)
        Write-Verbose "$WebhookData"
    }
    $Users = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)
}

# Connect to Azure Automation
$Credentials = Get-AutomationPSCredential -Name 'Az-MFAAuthSvc'

# This function converts a given PSObject to a HashTable recursively.
# Graph returns JSON data as PSObjects. Hashtables are needed to achieve key to value pairing.
function ConvertPSObjectToHashtable {
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    process {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) { ConvertPSObjectToHashtable $object }
            )
            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }
            $hash
        }
        else {
            $InputObject
        }
    }
}

#$VerbosePreference = "Continue"

# This is the ClientID (Application ID) of registered AzureAD App
$ClientID = ""

# This is the Microsoft 365 Tenant Domain Name or Tenant Id
$TenantId = ""

$ReqTokenBody = @{
    Client_Id       =    $ClientID
    Client_Secret   =    Get-AutomationVariable -Name ClientSecret # This is the key of the registered AzureAD app
    Grant_Type      =    "Password" # Password? Yes, we are using a ROPC-flow / authentication method.
    Scope           =    "https://graph.microsoft.com/.default"
    Username        =    $Credentials.Username
    Password        =    [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credentials.Password))
}

# Connect to the tenant to retrieve the required AccessToken that will keep us authenticated and authorized.
Try {
    $OAuthReq = Invoke-RestMethod -Method POST -Uri https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token -Body $ReqTokenBody -ContentType application/x-www-form-urlencoded -ErrorAction Stop
    $TokenType = $OAuthReq.token_type
    $AccessToken = $OAuthReq.access_token
    Write-Output "Auth success! `'$TokenType`' AccessToken retrieved" 
}
Catch {
    if ($_.ErrorDetails.Message) {
        Write-Error "Unable to authenticate and/or retrieve AccessToken: $((($_.ErrorDetails.Message | ConvertFrom-Json).error_description -split "`n")[0])" 
    }
    else {
        Write-Error "Unable to authenticate and/or retrieve AccessToken: $($_.CategoryInfo.Reason): $($_.Exception.Message)" 
    }
    Break;
}

# Documentation for https://docs.microsoft.com/en-us/graph/api/resources/phoneauthenticationmethod?view=graph-rest-beta 
# This tells us that we are to receive different statusCodes for successful requests depending on the HTTP method.
$expectedResponse = @{
    "LIST"      =   "200"
    "GET"       =   "200"
    "PUT"       =   "200"
    "DELETE"    =   "204"
    "POST"      =   "201"
}

# This function will act as a wrapper for Invoke-WebRequest in order to handle throttling against 
# the Microsoft Graph API, using 'Best practices to handle throttling' from here: https://docs.microsoft.com/en-us/graph/throttling
function CalmlyIWR {
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)]
        [String]$Uri,
        [parameter(Mandatory=$false)]
        [Object]$Body,
        [parameter(Mandatory=$true)]
        [String]$Method,
        [parameter(Mandatory=$true)]
        [String]$Action
    )#End param
    
    $Retries = 10
    $Delay = 3
    $RetryCount = 0
    $Completed = $false
    $script:IWRResponse = $null

    while (-not $Completed) {
        try {
            # Build up the paramters required for Invoke-WebRequest
            $IWRParams = @{
                Headers         =   @{Authorization = "Bearer $AccessToken"}
                ContentType     =   "application/json"
                Uri             =   $Uri
                Method          =   $Method
                UseBasicParsing =   $True
            }
            #  The body parameter will only be included when its provided. A 'body' will not be required nor provided as input to the function for LIST or GET requests.
            if ($body) {
                $IWRParams.Add('Body',"$Body")
            }
            # Send/request data to/from Microsoft Graph API
            $script:IWRResponse = Invoke-WebRequest @IWRParams -ErrorAction Stop

            if ($IWRResponse.StatusCode -eq $expectedResponse.$Method) {
                Write-Verbose "Action to $Action using `($Uri`) succeeded with StatusCode: $($IWRResponse.StatusCode)"
            }
            else {
                Write-Warning "Action to $Action using `($Uri`) returned StatusCode: $($IWRResponse.StatusCode)"
            }

            $Completed = $true
            Write-Verbose $IWRResponse
        }
        catch {
            $Exception = $_.Exception
            switch ($Exception.Response.StatusCode.value__) {
                { @(429, 503, 504) -contains $_ } {
                    if ($RetryCount -ge $Retries) {
                        Write-Error "Request to `($Uri`) failed the maximum number of $RetryCount times."
                        throw
                    }
                    else {
                        #[ref]$RetryAfterHeader = $null
                        #if ($Exception.Response.Headers.TryGetValues("Retry-After", $RetryAfterHeader)) {
                        $RetryAfterHeader = $Exception.Response.Headers['Retry-After']
                        if ($RetryAfterHeader) {                        
                            # Use Retry-After response header
                            if ($RetryAfterHeader.Value) {
                                $DelayInSeconds = $RetryAfterHeader.Value
                            }
                            else {
                                $DelayInSeconds = $RetryAfterHeader
                            }
                            Write-Verbose "Applying $DelayInSeconds seconds delay using 'Retry-After'-value from header."
                        }
                        else {
                            # Use exponential backoff
                            $mPow = [Math]::Pow(2, $RetryCount)
                            $DelayInSeconds = $mPow * $Delay
                            Write-Verbose "Applying $DelayInSeconds seconds delay using exponential backoff."
                        }
                        
                        $RetryCount++
                        Write-Warning "Request to `($Uri`) failed. Retrying in $DelayInSeconds seconds. `($RetryCount`/$Retries`) retries."
                        Start-Sleep $DelayInSeconds
                    }
                }
                404 {
                    Write-Error "Request to `($Uri`) returned 404. Action will be skipped."
                    $Completed = $true
                }
                default {
                    # Get HTTP error message, Re-throw error to be handled Upstream
                    $ErrorMessage = $Exception.Message
                    Write-Error "Request to `($Uri`) failed with error message: $ErrorMessage"
                    throw
                }
            }
        }
    }
}

# Begin processing each user in the webhook payload ($Users)
foreach ($User in $Users) {
    $UserPrincipalName = $User.UserPrincipalName
    $NewPhoneNumber = $User.Mobile
    
    if (-not($User.OverwriteNull)) {
        $OverwriteNull = $true
    }
    else {
        if ($User.OverwriteNull -eq "1") {
            $OverwriteNull = $true
        }
        if ($User.OverwriteNull -eq "0") {
            $OverwriteNull = $false
        }
    }
    $NewMFA = $null
    $EA15 = $null
    $Manual = $null
    $currentMFA = $null

    # Retrieve user data with synchronized value from extensionAttribute15
    Try {
        $apiUrl = "https://graph.microsoft.com/beta/users?`$filter=UserPrincipalName eq '$UserPrincipalName'&`$select=onPremisesExtensionAttributes,mail,UserPrincipalName"
        $Action = "Retrieve user and onPremisesExtensionAttributes for $($UserPrincipalName)"
        CalmlyIWR -Uri $apiUrl -Method GET -Action $Action -ErrorAction Stop

        # The function CalmlyIWR produces the $IWRResponse output, check for content
        if (($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json).value) {
            Write-Output "Attributes for `'$(($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json).value.UserPrincipalName)`' was retrieved" 
            Write-Verbose ("{0,-25}:{1,25}" -f 'extensionAttribute15',$(($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json).value.onPremisesExtensionAttributes.extensionAttribute15))
            $EA15 = @{
                phoneSource = "onPremises:extensionAttribute15"
                phoneNumber = "$(($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json).value.onPremisesExtensionAttributes.extensionAttribute15)"
                phoneType   = "mobile"
            }
            # If the data payload included a 'Mobile' value, this will be used as "manual input" and effectivly bypass the value of the extensionAttribute15
            if ($NewPhoneNumber) {
                Write-Verbose ("{0,-25}:{1,25}" -f 'Manual phoneNumber',$NewPhoneNumber)
                $Manual = @{
                    phoneSource = "Manual input"
                    phoneNumber = "$NewPhoneNumber"
                    phoneType   = "mobile"
                }
            }
            # If no manual input, Use EA15 if its not empy
            if ( (-not($NewPhoneNumber)) -and $EA15.phoneNumber) {
                $NewMFA = @{
                    phoneSource = "$($EA15.phoneSource)"
                    phoneNumber = "$($EA15.phoneNumber)"
                    phoneType   = "mobile"
                }
            }
            # If no EA15 input, Use 'Manual input' if its not empy
            if ( (-not($EA15.phoneNumber)) -and $NewPhoneNumber) {
                $NewMFA = @{
                    phoneSource = "$($Manual.phoneSource)"
                    phoneNumber = "$($Manual.phoneNumber)"
                    phoneType   = "mobile"
                }
            }
            # if both EA15 and Manul input is provided, compare the phoneNumbers
            if ($Manual.phoneNumber -and $EA15.phoneNumber) {
                # if the Manual input and the EA15 values does NOT match, override with manual input as source.
                if ( $(($Manual.phoneNumber).Substring(($Manual.phoneNumber.Length)-9,9)) -ne $($EA15.phoneNumber).Substring(($($EA15.phoneNumber).Length)-9,9) ) {
                    Write-Warning "The user's phoneNumber `'$($Manual.phoneNumber)`' from $($Manual.phoneSource) does NOT seem to match the phoneNumber `'$($EA15.phoneNumber)`' from $($EA15.phoneSource). Overriding $($EA15.phoneSource) with $($Manual.phoneSource) for MFA" 
                    $NewMFA = @{
                        phoneSource = "$($Manual.phoneSource)"
                        phoneNumber = "$($Manual.phoneNumber)"
                        phoneType   = "mobile"
                    }
                }
                # if the Manual input and the EA15 values match, use EA15 as the source.
                if ( $(($Manual.phoneNumber).Substring(($Manual.phoneNumber.Length)-9,9)) -eq $($EA15.phoneNumber).Substring(($($EA15.phoneNumber).Length)-9,9) ) {
                    Write-Output "The user's phoneNumber `'$($Manual.phoneNumber)`' from $($Manual.phoneSource) matches the phoneNumber `'$($EA15.phoneNumber)`' from $($EA15.phoneSource). Using `'$($EA15.phoneNumber)`' from `'$($EA15.phoneSource)`' for MFA `(Any will due, one must be picked`)" 
                    $NewMFA = @{
                        phoneSource = "$($EA15.phoneSource)"
                        phoneNumber = "$($EA15.phoneNumber)"
                        phoneType   = "mobile"
                    }
                }
            }
            # check for minimum phoneNumber length
            if (($NewMFA.phoneNumber).Length -lt 11) {
                Write-Error "The user `'$UserPrincipalName`' phoneNumber `'$($NewMFA.phoneNumber)`' from $($NewMFA.phoneSource) appears to be missing some digits or does not include a country code"
                Continue;
            }
            <#
            # check for illegal starting characters in phoneNumber
            if (($NewMFA.phoneNumber).Substring(0,1) -ne "+") {
                Write-Error "The user `'$UserPrincipalName`' phoneNumber `'$($NewMFA.phoneNumber)`' from $($NewMFA.phoneSource) does not include the '+' character in the beginning."
                Continue;
            }
            #>
            # check for valid phoneNumber: https://regex101.com/r/l9KYJr/1
            if ($NewMFA.phoneNumber -notmatch "^(\+\d{1,3})\-?\s?\d{2,4}[\s-]?\d{2,4}[\s-]?\d{2,4}[\s-]?\d{2,4}$") {
                Write-Error "The phoneNumber `'$($NewMFA.phoneNumber)`' from $($NewMFA.phoneSource) for user `'$UserPrincipalName`' is not a valid phone number. Skipping."
                Continue;
            }
        }
        if (-not(($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json).value)) {
            Write-Error "The query did not return any data for user `'$UserPrincipalName`'"
            Continue;
        }
        if (-not($NewMFA.phoneNumber)) {
            Write-Verbose "No phoneNumber from either manual input or extensionAttribute15 was provided for user `'$UserPrincipalName`'"
        }
    }
    Catch {
        $FailedAction = "Unable to $Action"
        Write-Error "$FailedAction"
        Write-Verbose "Exception.Message: $($_.Exception.Message)"
        Write-Verbose "CategoryInfo.Reason: $($_.CategoryInfo.Reason)"

        Continue; # break loop
    }

    # Retrieve current authentication methods and filter for mobile type
    Try {    
        $apiUrl = "https://graph.microsoft.com/beta/users/$($UserPrincipalName)/authentication/methods"
        $Action = "Retrieve user authentication methods for $($UserPrincipalName)"
        CalmlyIWR -Uri $apiUrl -Method GET -Action $Action -ErrorAction Stop
        
        # The function CalmlyIWR produces the $IWRResponse output, check for content
        if (($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json).value) {
            $HashMethods = ($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json).value | ConvertPSObjectToHashtable
            $CurrentMFA = ($HashMethods).Where{$_.PhoneType -eq 'mobile'}.phoneNumber

            Write-Verbose ("{0,-25}:{1,25}" -f 'MFA phoneNumber',$CurrentMFA) 
        }
        # technically, if no methods are configured, this should mean that the user has no password either?!
        if (-not(($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json))) {
            Write-Error "The query did not return any AuthenticationMethods for `'$UserPrincipalName`'"
            Continue;
        }
    }
    Catch {
        $FailedAction = "Unable to $Action"
        Write-Error "$FailedAction"
        Write-Verbose "Exception.Message: $($_.Exception.Message)"
        Write-Verbose "CategoryInfo.Reason: $($_.CategoryInfo.Reason)"

        Continue; # break loop
    }

    #
    # Begin validation and updating/adding of new phoneNumber
    #
    # if MFA is already set but input data is empty
    if ( $CurrentMFA -and (-not($NewMFA.phoneNumber)) ) {
        Write-Warning "`'$UserPrincipalName`' current MFA phoneNumber is set to `'$CurrentMFA`', no new phoneNumber from either EA15 or Manul input was provided for `'$UserPrincipalName`'"
        if ($OverwriteNull -eq $true) {
            Try {
                # DELETE (Delete) phoneNumber using value from newMFA phoneNumber as source
                Write-Warning "Removing current MFA phoneNumber: `'$CurrentMFA`' for `'$UserPrincipalName`'. OverwriteNull is $OverwriteNull" 
                $apiUrl = "https://graph.microsoft.com/beta/users/$($UserPrincipalName)/authentication/phoneMethods/$(($HashMethods).Where{$_.PhoneType -eq 'mobile'}.Id)"
                $Action = "Remove current MFA phoneNumber for $($UserPrincipalName)"
                CalmlyIWR -Uri $apiUrl -Method DELETE -Action $Action -ErrorAction Stop
            }
            Catch {
                $FailedAction = "Unable to $Action"
                Write-Error "$FailedAction"
                Write-Verbose "Exception.Message: $($_.Exception.Message)"
                Write-Verbose "CategoryInfo.Reason: $($_.CategoryInfo.Reason)"

                Continue; # break loop
            }
        }
        if ($OverwriteNull -eq $false) {
            Write-Warning "Not removing current MFA phoneNumber: `'$CurrentMFA`' for `'$UserPrincipalName`'. OverwriteNull is $OverwriteNull" 
        }
    }
    # if both are empty
    if ( (-not($CurrentMFA)) -and (-not($NewMFA.phoneNumber)) ) {
        Write-Warning "`'$UserPrincipalName`' current MFA phoneNumber is NULL and no new phoneNumber from either EA15 or Manul input was provided for `'$UserPrincipalName`'"
    }
    if (($NewMFA.phoneNumber) -and ($CurrentMFA)) {
        # We do receive full phone number by having 'Privileged authentication administrator' role. Compare last 9 digits of phone numbers to find out if they match.
        # If the account is only having the 'Authentication administrator' role, we'll only receive the last 2 digits of the phoneNumber used for authentication from MS Graph
        if ( $(($NewMFA.phoneNumber).Substring(($NewMFA.phoneNumber.Length)-9,9)) -eq $CurrentMFA.Substring(($CurrentMFA.Length)-9,9) ) {
            Write-Output "`'$UserPrincipalName`' current MFA phoneNumber `'$CurrentMFA`' seems to match the value `'$($NewMFA.phoneNumber)`' from $($NewMFA.phoneSource)"
        }
        # phoneNumber does not match newMFA phoneNumber, lets update that
        else {
            Write-Warning "`'$UserPrincipalName`' current MFA phoneNumber is set to `'$CurrentMFA`', but it does NOT seem to match the value `'$($NewMFA.phoneNumber)`' from $($NewMFA.phoneSource)." 
            Try {
                # PUT (Update) phoneNumber using value from newMFA phoneNumber as source
                Write-Output "Replacing current MFA phoneNumber: `'$CurrentMFA`' with `'$($NewMFA.phoneNumber)`', according to $($NewMFA.phoneSource) for `'$UserPrincipalName`'" 
                $apiUrl = "https://graph.microsoft.com/beta/users/$($UserPrincipalName)/authentication/phoneMethods/$(($HashMethods).Where{$_.PhoneType -eq 'mobile'}.Id)"
                $body = $NewMFA | ConvertTo-JSON
                $Action = "Replace current MFA phoneNumber: `'$CurrentMFA`' with `'$($NewMFA.phoneNumber)`', according to $($NewMFA.phoneSource) for `'$UserPrincipalName`'"
                CalmlyIWR -Uri $apiUrl -Method PUT -Body $body -Action $Action -ErrorAction Stop

                # The function CalmlyIWR produces the $IWRResponse output, check for content
                if (($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json)) {
                    Write-Output "The phoneNumber for `'$($UserPrincipalName)`' was successfully replaced with `'$(($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json).phoneNumber)`'."
                }
            }
            Catch {
                $FailedAction = "Unable to $Action"
                Write-Error "$FailedAction"
                Write-Verbose "Exception.Message: $($_.Exception.Message)"
                Write-Verbose "CategoryInfo.Reason: $($_.CategoryInfo.Reason)"

                Continue; # break loop
            }
        }
    }

    # If there is currently no phoneNumber configured for MFA
    if (-not($CurrentMFA)) {
        Write-Verbose "The user `'$($UserPrincipalName)`' does not have any mobile phoneNumber for MFA configured" 
        if ($NewMFA.phoneNumber) {
            Write-Output "`'$UserPrincipalName`' current MFA phoneNumber is NULL, should be set to `'$($NewMFA.phoneNumber)`' from `'$($NewMFA.phoneSource)`'"
            Try {
                # POST (Add) phoneNumber using value from newMFA phoneNumber as source
                Write-Output "Adding phoneNumber: `'$($NewMFA.phoneNumber)`' from $($NewMFA.phoneSource) for `'$UserPrincipalName`'" 
                $apiUrl = "https://graph.microsoft.com/beta/users/$($UserPrincipalName)/authentication/phoneMethods"
                $body = $NewMFA | ConvertTo-JSON
                $Action = "Add phoneNumber: `'$($NewMFA.phoneNumber)`' from $($NewMFA.phoneSource) for `'$UserPrincipalName`'"
                CalmlyIWR -Uri $apiUrl -Method POST -Body $body -Action $Action -ErrorAction Stop
                
                # The function CalmlyIWR produces the $IWRResponse output, check for content
                if (($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json)) {
                    Write-Output "A phoneNumber for MFA to `'$($UserPrincipalName)`' was successfully added: `'$(($IWRResponse.Where{$_.Content}.Content | ConvertFrom-Json).phoneNumber)`'."
                }
            }
            Catch {
                $FailedAction = "Unable to $Action"
                Write-Error "$FailedAction"
                Write-Verbose "Exception.Message: $($_.Exception.Message)"
                Write-Verbose "CategoryInfo.Reason: $($_.CategoryInfo.Reason)"

                Continue; # break loop
            }
        }
    }
    
} # end foreach user 
