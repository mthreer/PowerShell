#Requires -Modules @{ModuleName="AzureADPreview";ModuleVersion="2.0.2.105"}
#Requires -Version 5

param (
    [CmdletBinding()]
	[Parameter(Position=0,Mandatory=$false,HelpMessage="Output results as JSON to given file path")]
    [ValidateScript({
        if(Test-Path $_ -PathType Container) {
            throw "The ExportToJson argument must be a file."
        }
        else {
            if (-not(Split-Path $_ -Parent | Test-Path -PathType Container)) {
                throw "The folder `'$(Split-Path $_ -Parent)`' does not exist"
            }
        }
        return $true
    })]
	[string]$ExportToJson
)

Try { 
	$null = Get-AzureADTenantDetail -ErrorAction Stop
} 
Catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] { 
	Connect-AzureAD
}

$CAs=Get-AzureADMSConditionalAccessPolicy
$ServicePrincipals = Get-AzureADServicePrincipal -All:$true | Select-Object AppId,DisplayName
#$AADRoles = Get-AzureADDirectoryRoleTemplate | Select-Object ObjectId,DisplayName
$AADRoles = Get-AzureADMSRoleDefinition | Select-Object Id,DisplayName

function Test-IsGuid
{
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$StringGuid
    )
 
   $ObjectGuid = [System.Guid]::empty
   return [System.Guid]::TryParse($StringGuid,[System.Management.Automation.PSReference]$ObjectGuid) # Returns True if successfully parsed
}

$PoliciesReport = [System.Collections.Generic.List[PSCustomObject]]@()
foreach ($p in $CAs) {
	$policy = [PSCustomObject]@{ 
		Name = $p.DisplayName
		Id = $p.Id
        State = $p.State
        Users = [PSCustomObject]@{
            IncludedUsers = $([array]$a=$p.Conditions.Users.IncludeUsers;$(
                if($a -ne "All"){
                    $a.ForEach{ 
                        if(Test-IsGuid $_){
                            [PSCustomObject]@{ $($_) = (Get-AzureADObjectByObjectId -ObjectIds $_).UserPrincipalName }
                        }
                        if ($_ -eq "GuestsOrExternalUsers") {
                            $a
                        }
                    } 
                }
                else{$a}
                ))
            ExcludeUsers = $([array]$a=$p.Conditions.Users.ExcludeUsers;$(
                if($a -ne "All"){
                    $a.ForEach{ 
                        if(Test-IsGuid $_){
                            [PSCustomObject]@{ $($_) = (Get-AzureADObjectByObjectId -ObjectIds $_).UserPrincipalName }
                        }
                        if ($_ -eq "GuestsOrExternalUsers") {
                            $_
                        }
                    } 
                }
                else{$a}
                ))
			IncludedGroups = $([array]$a=$p.Conditions.Users.IncludeGroups;$a.ForEach{[PSCustomObject]@{$($_) = $((Get-AzureADObjectByObjectId -ObjectIds $_).DisplayName)}})
			ExcludedGroups = $([array]$a=$p.Conditions.Users.ExcludeGroups;$a.ForEach{[PSCustomObject]@{$($_) = $((Get-AzureADObjectByObjectId -ObjectIds $_).DisplayName)}})
			IncludedRoles = $([array]$a=$p.Conditions.Users.IncludeRoles;$a.ForEach{[PSCustomObject]@{$($_) = $($v=$_;$AADRoles.Where{$_.Id -eq $v}.DisplayName)}})
			ExcludedRoles = $([array]$a=$p.Conditions.Users.ExcludeRoles;$a.ForEach{[PSCustomObject]@{$($_) = $($v=$_;$AADRoles.Where{$_.Id -eq $v}.DisplayName)}})
		}
		CloudAppOrUserActions = [PSCustomObject]@{
			IncludedCloudApp = $([array]$a=$p.Conditions.Applications.IncludeApplications;if($a -ne "All"){$a.ForEach{$v=$_;$ServicePrincipals.Where{$_.AppId -eq $v}.DisplayName}}else{$a})
			ExcludedCloudApp = $([array]$a=$p.Conditions.Applications.ExcludeApplications;$a.ForEach{$v=$_;$ServicePrincipals.Where{$_.AppId -eq $v}.DisplayName})
			IncludedUserActions = $([array]$a=$p.Conditions.Applications.IncludeUserActions;if($a){$a -join ", "}else{$a})
			IncludedProtectionLevels = $([array]$a=$p.Conditions.Applications.IncludedProtectionLevels;if($a){$a -join ", "}else{$a})
        }
        Conditions = [PSCustomObject]@{
		    Platforms = [PSCustomObject]@{
                "Not yet implemented in the script" = $null
		    }
		    Locations = [PSCustomObject]@{
                IncludedLocations = $([array]$a=$p.Conditions.Locations.IncludeLocations;if($a -ne "All"){$a.ForEach{
                    [PSCustomObject]@{
                        $((Get-AzureADMSNamedLocationPolicy -PolicyId $_).DisplayName) = $((Get-AzureADMSNamedLocationPolicy -PolicyId $_).Ipranges.CidrAddress)
                    }
                    }}else{$a})
                ExcludedLocations = $([array]$a=$p.Conditions.Locations.ExcludeLocations;if($a -ne "All"){$a.ForEach{
                    [PSCustomObject]@{
                        $((Get-AzureADMSNamedLocationPolicy -PolicyId $_).DisplayName) = $((Get-AzureADMSNamedLocationPolicy -PolicyId $_).Ipranges.CidrAddress)
                    }
                    }}else{$a})
		    }
            ClientAppTypes = @( 
                $([string[]]$a=$p.Conditions.ClientAppTypes;$a.ForEach{$_})
            )
            Devices = [PSCustomObject]@{
                "Not yet implemented in the script" = $null
            }
        }
        Grant = [PSCustomObject]@{
            Operator = $([string[]]$a=$p.GrantControls._Operator;$a.ForEach{$_})
            BuiltInControls = $([string[]]$a=$p.GrantControls.BuiltInControls;$a.ForEach{$_})
        }
	}
	$PoliciesReport.Add($policy)
}
if ($ExportToJson) {
    $PoliciesReport | ConvertTo-Json -Depth:99 | Out-File $ExportToJson -Encoding UTF8
}
else {
    return $PoliciesReport
}