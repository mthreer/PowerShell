# Description #

This script will validate a Swedish personal number (Social Security Number) using the Luhn-algorithm (modulus-10). It will also validate that the string is a valid date.

![Example screenshot in Windows PowerShell](..\images\powershell_cWVCzeLFKc.png "Example screenshot in Windows PowerShell")

## Usage examples ##

This will validate a Swedish personal number (Social Security Number) and the persons birth place and sex/gender (Since the default value for the parameter `ValidateBirthPlaceAndSex` is `$True`)

```powershell
./Verify-SwedishPersonalNumber.ps1 -PNR 871031-7549
```

\
This will too validate a Swedish personal number (Social Security Number) and the persons birth place and sex/gender

```powershell
./Verify-SwedishPersonalNumber.ps1 -PNR 871031-7549 -ValidateBirthPlaceAndSex:$true
```

\
This will validate a Swedish personal number (Social Security Number), the persons birth place and sex/gender together with the persons star sign.

```powershell
./Verify-SwedishPersonalNumber.ps1 -PNR 871031-7549 -ValidateBirthPlaceAndSex:$true -ExtraFacts:$true 
```

## Parameters ##

### **-PNR** ###

The Swedish personal number (Social Security Number) to validate. \
Possible formats are: yyMMdd-XXXX, yyMMddXXXX, yyyyMMdd-XXXX and yyyyMMddXXXX\
The dash delimiter can be any delimiter of your choice, however usage of a plus sign as delimiter indicates the person is of age 100 or more.  

### **-ValidateBirthPlaceAndSex** ###

Default value: $True \
This will validate the persons birth place and sex/gender.

### **-Extra** ###

Default value: $False \
Evaluate extra facts based on the personal number.
