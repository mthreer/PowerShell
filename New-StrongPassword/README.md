# Description #

This script will generate a new strong password in Powershell using Special Characters, Uppercase Letters, Lowercase Letters and Numbers

## Installation/Getting Started ##

Start using the module:

```powershell
Import-Module Module.New-StrongPassword.psm1
```

### Usage examples ###

This will generate 10 strong passwords with each having the length of 32.

```powershell
New-StrongPassword -Count 10 -Length 32
```

\
This will generate 100 strong passwords and arrange the output into a multi-dimensional array, for use with CSV-exports.

```powershell
New-StrongPassword -Count 100 -ExportableOutput
```

\
This will generate a password without any special characters

```powershell
New-StrongPassword -ExcludeSpecialCharacters
```

### Parameters ###

#### **-Count** ####

Default value: 1 \
Set the desired passwords to be generated

#### **-Length** ####

Default value: 16 \
Set the desired length of the password(s)

#### **-ExportableOutput** ####

Default value: $False \
Include or set to $True to have the output organized into a multi-dimensional array, for use with CSV-exports.

Example:

```powershell
New-StrongPassword -Count 10 -ExportableOutput | Export-CSV -Path Output.csv -Encoding UTF8 -Delimiter ";"
```

#### **-ExcludeUppercaseLetters** ####

Include or set to $True to exclude any uppercase letters

#### **-ExcludeLowercaseLetters** ####

Include or set to $True to exclude any lowercase letters

#### **-ExcludeNumbers** ####

Include or set to $True to exclude any numbers

#### **-ExcludeSpecialCharacters** ####

Include or set to $True to exclude any special characters
