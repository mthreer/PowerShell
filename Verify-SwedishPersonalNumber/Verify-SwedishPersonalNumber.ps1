<#
.SYNOPSIS
    This script will validate a Swedish personal number (Social Security Number) using the Luhn-algorithm (modulus-10). It will also validate that the string is a valid date.
.EXAMPLE
    PS C:\> ./Verify-SwedishPersonalNumber.ps1 -PNR 871031-7549
    This will validate a Swedish personal number (Social Security Number) and the persons birth place and sex/gender (Since the default value for the parameter ValidateBirthPlaceAndSex is $True)
.Example
    PS C:\> ./Verify-SwedishPersonalNumber.ps1 -PNR 871031-7549 -ValidateBirthPlaceAndSex:$true
    This will too validate a Swedish personal number (Social Security Number) and the persons birth place and sex/gender
.EXAMPLE
    PS C:\> ./Verify-SwedishPersonalNumber.ps1 -PNR 871031-7549 -ValidateBirthPlaceAndSex:$true -ExtraFacts:$true
    This will validate a Swedish personal number (Social Security Number), the persons birth place and sex/gender together with the persons star sign.
.PARAMETER PNR
    The Swedish personal number (Social Security Number) to validate. 
    Possible formats are: yyMMdd-XXXX, yyMMddXXXX, yyyyMMdd-XXXX and yyyyMMddXXXX
    The dash delimiter can be any delimiter of your choice, however usage of a plus sign as delimiter indicates the person is of age 100 or more.
.PARAMETER ValidateBirthPlaceAndSex
    Default value: $True
    This will validate the persons birth place and sex/gender. 
.PARAMETER ExtraFacts
    Default value: $False
    Evaluate extra facts based on the personal number.
    Currently Supported facts: Returns the the persons Star Sign in Swedish and English.
.NOTES
    MIT License

    Copyright (C) 2021 Niklas J. MacDowall. All rights reserved.
    
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
    LASTEDIT: Oct 21, 2021
.LINK
    http://blog.jumlin.com
#>

param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [ValidateNotNullorEmpty()]
    [String]$PNR,
    [Parameter(
        Position=1, 
        Mandatory=$false, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Switch]$ValidateBirthPlaceAndSex = $true,
    [Parameter(
        Position=2, 
        Mandatory=$false, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [Switch]$ExtraFacts = $false

)

$DateFromStr = [PSCustomObject]@{
    DigitChain  = $null
    ControlNum  = [int]::Parse($PNR[$PNR.Length -1])
    Year        =   [PSCustomObject]@{
        StringValue = $null
        Format      = $null
        AgeAdd      = $null
    }
    Month       =   [PSCustomObject]@{
        StringValue = $null
        Format      = $null
    }
    Day         =   [PSCustomObject]@{
        StringValue = $null
        Format      = $null
    }
    Date            = $null
    BirthDigits     = $PNR.Substring(($PNR.Length -4),3)
}

$BirthPlace=@{}
(00..09).foreach{ $BirthPlace."0$($_)" ="Stockholms l$([char]228)n" }
(10..13).foreach{ $BirthPlace."$($_)" = "Stockholms l$([char]228)n" }
(14..15).foreach{ $BirthPlace."$($_)" = "Uppsala l$([char]228)n" }
(16..18).foreach{ $BirthPlace."$($_)" = "S$([char]246)dermanlands l$([char]228)n" }
(19..23).foreach{ $BirthPlace."$($_)" = "$([char]214)sterg$([char]246)tlands l$([char]228)n" }
(24..26).foreach{ $BirthPlace."$($_)" = "J$([char]246)nk$([char]246)pings l$([char]228)n" }
(27..28).foreach{ $BirthPlace."$($_)" = "Kronobergs l$([char]228)n" }
(29..31).foreach{ $BirthPlace."$($_)" = "Kalmar l$([char]228)n" }
(32..32).foreach{ $BirthPlace."$($_)" = "Gotlands l$([char]228)n" }
(33..34).foreach{ $BirthPlace."$($_)" = "Blekinge l$([char]228)n" }
(35..38).foreach{ $BirthPlace."$($_)" = "Kristianstads l$([char]228)n" }
(39..45).foreach{ $BirthPlace."$($_)" = "Malm$([char]246)hus l$([char]228)n" }
(46..47).foreach{ $BirthPlace."$($_)" = "Hallands l$([char]228)n" }
(48..54).foreach{ $BirthPlace."$($_)" = "G$([char]246)teborgs och Bohus l$([char]228)n" }
(55..58).foreach{ $BirthPlace."$($_)" = "$([char]196)lvsborgs l$([char]228)n" }
(59..61).foreach{ $BirthPlace."$($_)" = "Skaraborgs l$([char]228)n" }
(62..64).foreach{ $BirthPlace."$($_)" = "V$([char]228)rmlands l$([char]228)n" }
(66..68).foreach{ $BirthPlace."$($_)" = "$([char]214)rebro l$([char]228)n" }
(69..70).foreach{ $BirthPlace."$($_)" = "V$([char]228)stmanlands l$([char]228)n" }
(71..73).foreach{ $BirthPlace."$($_)" = "Kopparbergs l$([char]228)n" }
(75..77).foreach{ $BirthPlace."$($_)" = "G$([char]228)vleborgs l$([char]228)n" }
(78..81).foreach{ $BirthPlace."$($_)" = "V$([char]228)sternorrlands l$([char]228)n" }
(82..84).foreach{ $BirthPlace."$($_)" = "J$([char]228)mtlands l$([char]228)n" }
(85..88).foreach{ $BirthPlace."$($_)" = "V$([char]228)sterbottens l$([char]228)n" }
(89..92).foreach{ $BirthPlace."$($_)" = "Norrbottens l$([char]228)n" }
(93..99).ForEach{ $BirthPlace."$($_)" = "Immigrated" }

function CountAge {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0
        )]
        [String]$DateString
    )
    BEGIN {
        $StartDate = [datetime]$DateString
        $EndDate = (Get-Date)
        $LeapYears = 0
        $LeapDays = 0
    }
    PROCESS {
        # Get the duration of time that has passed
        $Result = New-TimeSpan -Start $StartDate -End $EndDate

        # If there is more than one year
        if ($EndDate.Year - $StartDate.Year -gt 1) {
            # We need to loop through each year
            for ($i = 0; $i -le ($EndDate.Year - $StartDate.Year); $i++) {
                # To check if the year is a leap year
                if ([DateTime]::IsLeapYear($EndDate.Year - $i)) {
                    # If it is, we need to check if february is within our timeline
                    if (([DateTime]::Parse("$($EndDate.Year - $i)-1-1") -ge $StartDate) -and ([DateTime]::Parse("$($EndDate.Year - $i)-12-31") -le $EndDate)) {
                        # If it is, we can factor in the leap year
                        $LeapYears = $LeapYears + 1
                    } else {
                        # This area can be fleshed out for partial leap years
                        # In instances where the start date or end date fall in the middle of a leap year
                        # For the purposes of this fiddle, I'm not going to go that far in depth
                    }
                }
            }
        }

        if ($LeapYears -gt 0) {
            # If we have leap years, treat them as 366 days again... partial leap years aren't factored in
            $LeapDays = $LeapYears * 366
        }
        # Calculate the number of regular years by factoring out the leap year days
        $CalculatedYears = [Decimal]([Int]$Result.Days - [Int]$LeapDays) / 365.00
        # Calculate the number of total days remaining, again... partial leap years aren't factored in
        $CalculatedDays = [Decimal]".$($CalculatedYears.ToString().Split(".")[1])" * 365.00
        # Aggregate the total years
        $TotalYears = [Int]$CalculatedYears.ToString().Split(".")[0] + [Int]$LeapYears
        # Snag the total days
        $TotalDays = $CalculatedDays.ToString().Split(".")[0]

        # Calculate the number of hours
        $CalculatedHours = [Decimal]".$($CalculatedDays.ToString().Split(".")[1])" * 24 + [Decimal]$Result.Hours
        # Snag the total
        $TotalHours = $CalculatedHours.ToString().Split(".")[0]

        # Calculate the number of minutes
        $CalculatedMinutes = [Decimal]".$($CalculatedHours.ToString().Split(".")[1])" * 60 + [Decimal]$Result.Minutes
        # Snag the total
        $TotalMinutes = $CalculatedMinutes.ToString().Split(".")[0]

        # Calculate the seconds
        $CalculatedSeconds = [Decimal]".$($CalculatedMinutes.ToString().Split(".")[1])" * 60 + [Decimal]$Result.Seconds
        # Snag the total
        $TotalSeconds = $CalculatedSeconds.ToString().Split(".")[0]
    }
    END {
        # Toss the cheese
        return [PSCustomObject]@{
            "Years"     = $TotalYears
            "Days"      = $TotalDays
            "Hours"     = $TotalHours
            "Minutes"   = $TotalMinutes
            "Seconds"   = $TotalSeconds
        }
    }
}

function VerifyValidDate {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0
        )]
        [String]$String
    )
    begin {
        [Switch]$script:ValidDate = $False
        switch ($String) {
            {($String.Length -eq 10) -or ($String.Length -eq 11)} {
                Switch ($String.Length) {
                    10 {
                        # Keep all but last digit (which is the contrulNum) 
                        $DateFromStr.DigitChain = $String[0..($String.Length -2)]
                    }
                    11 { 
                        # Age 100 plus
                        if ($String.Substring(6,1) -eq "+") {
                            $DateFromStr.Year.AgeAdd = 100
                        }
                        # Remove separator and keep all but last digit (which is the contrulNum)
                        $DateFromStr.DigitChain = $String.Replace($String.Substring(6,1),'')[0..($String.Length -3)]
                    }
                }
                # Extract first 2 digits
                $DateFromStr.Year.StringValue = $String.Substring(0,2)
                $DateFromStr.Year.Format = 'yy'
                # Skip first 2 digits and extract 2 digits
                $DateFromStr.Month.StringValue = $String.Substring(2,2)
                $DateFromStr.Month.Format = 'MM'
                # Skip first 4 digits and extract 2 digits
                $DateFromStr.Day.StringValue = $String.Substring(4,2)
                $DateFromStr.Day.Format = 'dd'
                break;
            }
            {($String.Length -eq 12) -or ($String.Length -eq 13)} {
                Switch ($String.Length) {
                    12 {
                        # Keep all but last digit (which is the contrulNum) 
                        $DateFromStr.DigitChain = $String[2..($String.Length -2)]
                    }
                    13 {
                        # Remove separator and keep all but last digit (which is the contrulNum)
                        $DateFromStr.DigitChain = $String.Replace($String.Substring(8,1),'')[2..($String.Length -3)]
                    }
                }
                # Extract first 4 digits
                $DateFromStr.Year.StringValue = $String.Substring(0,4)
                $DateFromStr.Year.Format = 'yyyy'
                # Skip first 4 digits and extract 2 digits
                $DateFromStr.Month.StringValue = $String.Substring(4,2)
                $DateFromStr.Month.Format = 'MM'
                # Skip first 6 digits and extract 2 digits
                $DateFromStr.Day.StringValue = $String.Substring(6,2)
                $DateFromStr.Day.Format = 'dd'
                break;
            }
        }
    }
    process {
        [ref]$year = 0
        if ([DateTime]::TryParseExact($DateFromStr.Year.StringValue,$DateFromStr.Year.Format,$null,'None',$year)) {
            Out-Null
            if ($year.Value.Year -gt (Get-Date).Year) {
                $Result.Year = $($year.Value.Year) - 100
            }
            else {
                $Result.Year = $($year.Value.Year)
            }
            if ($DateFromStr.Year.AgeAdd) {
                $Result.Year = $($year.Value.Year) - 100
            }
        } else {
            Write-Error "Cannot parse year: '$($DateFromStr.Year.StringValue)'"
            Remove-Variable year
            break;
        }
        [ref]$month = 0
        if ([DateTime]::TryParseExact($DateFromStr.Month.StringValue,$DateFromStr.Month.Format,$null,'None',$month)) {
            Out-Null
            $Result.Month = $($month.Value.ToString('MMMM'))
        } else {
            Write-Error "Cannot parse month: '$($DateFromStr.Month.StringValue)'"
            Remove-Variable month
            break;
        }
        [ref]$day = 0
        if ([DateTime]::TryParseExact($DateFromStr.Day.StringValue,$DateFromStr.Day.Format,$null,'None',$day)) {
            Out-Null
            $Result.Day = $($day.Value.Day)
        } else {
            Write-Error "Cannot parse day: '$($DateFromStr.Day.StringValue)'"
            Remove-Variable day
            break;
        }
    }
    end {
        if ($year -and $month -and $day) {
            $DateFromStr.Date = "$($Result.Year)-$($DateFromStr.Month.StringValue)-$($DateFromStr.Day.StringValue)"
            #$Age = [datetime]([datetime]::Now.AddYears(-1).AddMonths(-1).AddDays(-1) - [datetime]$DateFromStr.Date).Ticks
            $Age = CountAge -DateString $DateFromStr.Date
            if ($Age) { $Result.Age = "$($Age.Years) years $($Age.Days) Days" }
            $script:ValidDate = $True
        } else { 
            return $False
        }
    }
}
function ValidateBirthPlaceAndSex {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0
        )]
        [String]$String
    )
    begin {
        $BirthPlaceDigits = $String.Substring(0,2)
        $SexDigit = $String.Substring(($String.Length -1),1)
        $Result | Add-Member -Name "Sex" -Type NoteProperty -Value ""
        $Result | Add-Member -Name "BirthPlace" -Type NoteProperty -Value ""
    }
    process {
        if ( ($Result.Year -gt 1946) -and ($BirthPlaceDigits -in @(93..99)) ) {
            $Result.BirthPlace = $BirthPlace."$BirthPlaceDigits"
        }
        if ( ($Result.Year -lt 1990) -and (-not($BirthPlaceDigits -in @(93..99))) ) {
            if ($BirthPlace."$BirthPlaceDigits") {
                $Result.BirthPlace = $BirthPlace."$BirthPlaceDigits"
            }
        } else {
            $Result.BirthPlace = "Not applicable (Born after 1990)"
        }

        if ($SexDigit % 2 -eq 0) {
            $Result.Sex = "Female"
        }
        if ($SexDigit % 2 -eq 1) {
            $Result.Sex = "Male"
        }
    }
    end {}
}
function ExtraFacts {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0
        )]
        [String]$String
    )
    begin {
        $DateString = [datetime]"$String"
        $thisYear = (get-date).Year
        $Result | Add-Member -Name "StarSign" -Type NoteProperty -Value ""
    }
    process {
        $starSign = switch ($DateString.DayOfYear) {
            { $_ -in @( (([datetime]"$thisYear-12-22").DayOfYear)..365; 0.. (([datetime]"$thisYear-01-19").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Capricorn"; Swe = "Stenbocken" } }
            { $_ -in @( (([datetime]"$thisYear-01-20").DayOfYear)..(([datetime]"$thisYear-02-18").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Aquarius"; Swe = "Vattumannen" } }
            { $_ -in @( (([datetime]"$thisYear-02-19").DayOfYear)..(([datetime]"$thisYear-03-20").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Pisces"; Swe = "Fiskarna" } }
            { $_ -in @( (([datetime]"$thisYear-03-21").DayOfYear)..(([datetime]"$thisYear-04-19").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Aries"; Swe = "V$([char]228)dur" } }
            { $_ -in @( (([datetime]"$thisYear-04-20").DayOfYear)..(([datetime]"$thisYear-05-20").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Taurus"; Swe = "Oxen" } }
            { $_ -in @( (([datetime]"$thisYear-05-21").DayOfYear)..(([datetime]"$thisYear-06-20").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Gemini"; Swe = "Tvillingarna" } }
            { $_ -in @( (([datetime]"$thisYear-06-21").DayOfYear)..(([datetime]"$thisYear-07-22").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Cancer"; Swe = "Kr$([char]228)ftan" } }
            { $_ -in @( (([datetime]"$thisYear-07-23").DayOfYear)..(([datetime]"$thisYear-08-22").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Leo"; Swe = "Lejonet" } }
            { $_ -in @( (([datetime]"$thisYear-08-23").DayOfYear)..(([datetime]"$thisYear-09-22").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Virgo"; Swe = "Jungfrun" } }
            { $_ -in @( (([datetime]"$thisYear-09-23").DayOfYear)..(([datetime]"$thisYear-10-22").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Libra"; Swe = "V$([char]229)gen" } }
            { $_ -in @( (([datetime]"$thisYear-10-23").DayOfYear)..(([datetime]"$thisYear-11-21").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Scorpio"; Swe = "Skorpionen" } }
            { $_ -in @( (([datetime]"$thisYear-11-22").DayOfYear)..(([datetime]"$thisYear-12-21").DayOfYear) ) } { [PSCustomObject]@{ Eng = "Sagittarius"; Swe = "Stenbocken" } }
        }
    }
    end {
        $Result.StarSign = "$($starSign.Eng) `($($starSign.Swe)`)"
    }
}
function VerifyControlNum {
    [CmdletBinding()]
    Param
    (
        [Parameter( Mandatory=$true,
                    ValueFromPipeline=$true,
                    Position=0
        )]
        [Array]$DigitChain,
        [Parameter( Mandatory=$true,
                    ValueFromPipeline=$true,
                    Position=1
        )]
        [String]$ControlNum
    )

    begin {
        $LuhnDigits = [System.Collections.Generic.List[PSCustomObject]]@()
        $c=0
    }
    process {
        ($DigitChain).Foreach{
            $c++
            [int]$num=[int]::Parse($_)
            if ($c % 2 -eq 1) {
                [int]$num = $num * 2
                ($num -split '').Where{$_}.ForEach{ $LuhnDigits.Add($_) }

            } else {
                [int]$num = $num * 1
                $LuhnDigits.Add($num)
            }
        }
        [int]$LuhnSum = ($LuhnDigits | Measure-Object -Sum).Sum
        if (($LuhnSum % 10) -eq 0) {
            [int]$Base10 = $LuhnSum
        } else {
            [int]$Base10 = $LuhnSum + (10 - ($LuhnSum % 10))
        } 
        [int]$verificationNum = $Base10 - $LuhnSum
        # [int]$verificationNum = (10 - ($LuhnSum % 10)) % 10
    }
    end {
        if ($ControlNum -eq $verificationNum) {
            Write-Verbose "CheckSum: $Base10 - $LuhnSum"
            $Result.ControlNumber = "$ControlNum"
            $Result.IsValid = "$True"
        } else {
            Write-Verbose "CheckSum: $Base10 - $LuhnSum"
            $Result.ControlNumber = "$ControlNum"
            $Result.IsValid = "$False"
        }
    }
}

$Result = [PSCustomObject]@{
    Year            = $null
    Month           = $null
    Day             = $null
    Age             = $null
    ControlNumber   = $null
    IsValid         = $null
}

VerifyValidDate -String $PNR
if ($ValidDate) {
    VerifyControlNum -DigitChain $DateFromStr.DigitChain -ControlNum $DateFromStr.ControlNum
    if ($ValidateBirthPlaceAndSex) {
        ValidateBirthPlaceAndSex -String $DateFromStr.BirthDigits
    }
    if ($ExtraFacts) {
        ExtraFacts -String "$($Result.Year)-$($DateFromStr.Month.StringValue)-$($DateFromStr.Day.StringValue)"
    }
}
[PSCustomObject]$Result

