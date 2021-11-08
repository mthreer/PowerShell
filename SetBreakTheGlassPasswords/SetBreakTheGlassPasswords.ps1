#Requires -Modules "AzureAD"
#Requires -Version 5

Try { 
    $null = Get-AzureADTenantDetail -ErrorAction Stop
} 
Catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] { 
    Try {
	Connect-AzureAD | Out-Null
    }
    Catch {
	exit
    }
}

$User = Get-AzureADUser -SearchString (Read-Host -Prompt "Username")
$Parts = Read-Host -Prompt "How many parts should the password consist of (1 or 2)?"

$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.EnforceChangePasswordPolicy = $False
$PasswordProfile.ForceChangePasswordNextLogin = $False
Switch ($Parts) {
	1 {
		$PasswordProfile.Password = "$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((read-host -Prompt "Password" -AsSecureString))))"
	}
	2 {
		$PasswordProfile.Password = "$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((read-host -Prompt "Password Part1" -AsSecureString))))$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((read-host -Prompt "Password Part2" -AsSecureString))))"
	}
}

Set-AzureADUser -ObjectId $User.ObjectId -PasswordProfile $PasswordProfile -PasswordPolicies DisablePasswordExpiration;$PasswordProfile.Password = ""
