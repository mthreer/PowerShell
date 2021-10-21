<#
    .SYNOPSIS
        This script will query a given user's (by UserPrincipalName or ObjectId) assigned licenses, mailbox usage statistics and mailbox transport statisics.

    .DESCRIPTION
        Provide either a UserPrincipalName or ObjectId to begin collecting data.

        ./Get-AADUserUsageDetails.ps1 -UserPrincipalName dummy.user@contoso.com
        ./Get-AADUserUsageDetails.ps1 -ObjectId 48ab99af-594c-4059-8a7c-4c4b860c52d4

        You may also provide a StartDate to look for emails sent/received from a specific date (up until today's date).

        ./Get-AADUserUsageDetails.ps1 -UserPrincipalName dummy.user@contoso.com -StartDate "yyyy-MM-dd"

        The values returned for MailboxTotalItemSize and MailboxTotalDeletedItemSize is converted into KilBytes, MegaBytes and GigaBytes automatically.

    .NOTES
        Copyright (C) 2021 Niklas J. MacDowall. All rights reserved.

        MIT License

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the ""Software""), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
        
        AUTHOR: Niklas J. MacDowall (niklasjumlin [at] gmail [dot] com)
        LASTEDIT: Oct 11, 2021

    .LINK
        http://blog.jumlin.com
#>

[CmdletBinding()]
param (
    [Parameter(
        Position = 0,
        Mandatory = $False, 
        ValueFromPipeline = $True,
        ValueFromPipelineByPropertyName = $True,
        HelpMessage = "Provide the UserPrincipalName for whom to retrieve data for"
    )]
    [ValidateNotNullorEmpty()]
    [string]$UserPrincipalName,
    [Parameter(
        Position = 0,
        Mandatory = $False, 
        ValueFromPipeline = $True,
        ValueFromPipelineByPropertyName = $True,
        HelpMessage = "Provide an ObjectId of a user for whom to retrieve data for"
    )]
    [ValidateScript({
        return [guid]::TryParse("$($_)", $([ref][guid]::Empty))
    })]
    [string]$ObjectId,
    [Parameter(
        Mandatory = $False,
        HelpMessage = "Provide a start date (yyyy-MM-dd) for mail sent and received"
    )]
    [datetime]$StartDate,
    [Parameter(
        Mandatory = $False,
        HelpMessage = "Provide an end date (yyyy-MM-dd) for mail sent and received"
    )]
    [datetime]$EndDate
)

if ($StartDate) {
    [string]$StartDate = $StartDate.ToString("yyyy-MM-dd")
}
if ($EndDate) {
    [string]$EndDate = $EndDate.ToString("yyyy-MM-dd")
}
if (-not($EndDate)) {
    [string]$EndDate = (Get-Date).ToString("yyyy-MM-dd")
}

if (-not($UserPrincipalName -or $ObjectId)) {
    throw "You need to provide either an UserPrincipalName or ObjectId"
}

#FriendlyName list for license plan 
$FriendlyNameHash=@()
$FriendlyNameHash=Get-Content -Raw -Path $PSScriptRoot\LicenseFriendlyName.txt -ErrorAction Stop | ConvertFrom-StringData

$Subscriptions = @{}
Get-AzureADSubscribedSku | ForEach-Object {
    $Subscriptions."$($_.SkuPartNumber)" = @{
        SubscriptionName    = $_.SkuPartNumber
        ConsumedUnits       = $_.ConsumedUnits
        Status              = $_.CapabilityStatus
        FriendlyName        = $(if ($FriendlyNameHash[$_.SkuPartNumber]){$FriendlyNameHash[$_.SkuPartNumber]}else{$_.SkuPartNumber})
    }
}

<#
if ($UserPrincipalName -match "#EXT#") {
    #$UserPrincipalName = $UserPrincipalName.Split("#")[0].Replace("_","@")
    Break;
}
#>

$ParamAADUser = @{
    ErrorAction = "Stop"
}
if ($ObjectId) { $ParamAADUser."ObjectId" = $ObjectId }
if ($UserPrincipalName) { $ParamAADUser."SearchString" = $UserPrincipalName }

Try {
    # get the user
    $User = Get-AzureADUser @ParamAADUser
    if (-not($User)) {
        throw "Could not find the user: $($ParamAADUser.Keys.ForEach{if($_ -ne "ErrorAction"){$ParamAADUser[$_]}})"
    }
}
Catch {
    Write-Verbose "Get-AzureADUser:"
    Write-Error $_.Exception.Message
}
if ($User) {
    # get licenses
    Try {
        $UserLicenses = Get-AzureADUserLicenseDetail -ObjectId $User.ObjectId -ErrorAction Stop
    }
    Catch {
        Write-Verbose "Get-AzureADUserLicenseDetail:"
        Write-Output "Could not fetch AzureADUserLicenseDetail for '$($User.UserPrincipalName)'"
        Write-Error $_.Exception.Message
    }

     # get mailbox statistics
     Try {
         $Mailbox = Get-ExOMailbox -Identity $User.UserPrincipalName -ErrorAction Stop
     }
     Catch {
        Write-Error "Could not fetch Mailbox for '$($User.UserPrincipalName)'"
        #Write-Error $_.Exception.Message
     }
    
    if ($Mailbox) {
        # get mailbox statistics
        Try {
            $MailboxStatistics = Get-MailboxStatistics -Identity $User.UserPrincipalName -ErrorAction Stop
        }
        Catch {
            Write-Error "Could not fetch MailboxStatistics for '$($User.UserPrincipalName)'"
            #Write-Error $_.Exception.Message
        }

        # get message statistics
        $ParamMessageTrace = @{
            ErrorAction = "Stop"
        }
        if ($StartDate) {
            $ParamMessageTrace."StartDate" = "$StartDate 00:00:00"
            $ParamMessageTrace."EndDate" = "$EndDate 23:59:59"
        }
        else {
            $ParamMessageTrace."StartDate" = (Get-Date).AddDays(-10).ToString("yyyy-MM-dd 00:00:00")
            $ParamMessageTrace."EndDate" = (Get-Date).ToString("yyyy-MM-dd 23:59:59")
        }
        Try {
             # Count Sent e-mails
            $sentCount = (Get-MessageTrace @ParamMessageTrace -SenderAddress $User.Mail).Count
        }
        Catch {
            Write-Error $_.Exception.Message
        }
        Try {
            # Count Received e-mails
            $receivedCount = (Get-MessageTrace @ParamMessageTrace -RecipientAddress $User.Mail).Count
        }
        Catch {
            Write-Error $_.Exception.Message
        }
    }
}

$Result = [PSCustomObject]@{
    DisplayName                     = $User.DisplayName
    UserPrincipalName               = $User.UserPrincipalName
    Mail                            = $( if ($User.Mail) { $User.Mail } )
    ObjectId                        = $User.ObjectId
    LicensesSKU                     = $( if ($UserLicenses) { foreach ($UserLicense in $UserLicenses) { if ($UserLicense.SkuPartNumber) { $UserLicense.SkuPartNumber } } } ) -join ", "
    LicensesFriendlyName            = $( if ($UserLicenses) { foreach ($UserLicense in $UserLicenses) { $Subscriptions[$UserLicense.SkuPartNumber].FriendlyName } } ) -join ", "
    RecipientTypeDetails            = $( if ($Mailbox) {$Mailbox.RecipientTypeDetails })
    SentEmails                      = $( if ($sentCount) { $sentCount } )
    ReceivedEmails                  = $( if ($receivedCount) { $receivedCount } )
    MailboxItemCount                = $( if ($MailboxStatistics) { $MailboxStatistics.ItemCount } )
    MailboxTotalItemSize            = $( if ($MailboxStatistics) { $MailboxStatistics.TotalItemSize.Value } )
    MailboxTotalDeletedItemSize     = $( if ($MailboxStatistics) { $MailboxStatistics.TotalDeletedItemSize.Value } )
    MailboxLastLogon                = $( if ($MailboxStatistics.LastLogonTime) { ($MailboxStatistics.LastLogonTime).ToString("yyyy-MM-dd hh:mm:ss") } else { "Never" } )
}
if ($User) {
    return $Result
}
else {
    return $null
}
    