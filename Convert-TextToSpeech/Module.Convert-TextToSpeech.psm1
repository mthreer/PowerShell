function Convert-TextToSpeech {
        <#
    .SYNOPSIS
        This script will convert text to speech and optionally write out the spoken words as they are being spoken.
    .EXAMPLE
        PS C:\> Convert-TextToSpeech -Text "Hello world."

        This will speak out the text "Hello world." using the default voice Microsoft David from SAPI 5.1.
    .Example
        PS C:\> Convert-TextToSpeech -Text "Hello world." -Voice "Zari" -TextWriter -TargetWindowTitle "MyWindow"

        This will speak out the text "Hello world." using the voice Microsoft Zari from SAPI 5.1 and simultaneously write out the spoken words to the target window title named "MyWindow"
    .PARAMETER Text
        Set the text to be spoken.
    .PARAMETER Voice
        Set the desired voice to be used. The default is Microsoft David from SAPI 5.1.
        Possible values: Male, Female, David or Zari
    .PARAMETER TextWriter
        Enables the spoken words to be simultaneously written out as the words are being spoken. For simultanous effect, have the text sent to a separate target window using $TargetWindowTitle.
    .PARAMETER TargetWindowTitle
        Set the name of the target window to receive the spoken words.
    .NOTES
        MIT License

        Copyright (C) 2022 Niklas J. MacDowall. All rights reserved.

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
        LASTEDIT: Apr 07, 2022
    .LINK
        http://blog.jumlin.com
    #>

    [CmdletBinding()]
    param ( 
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            HelpMessage = "Provide the text that you want spoken."
        )] 
        [string]$Text,
        [Parameter(
            Mandatory=$false,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            HelpMessage = "Provide the voice that you want to speak your text. Possible values: Male, Female, David or Zari. Default voice is David."
            
        )]
        [ValidateSet("Male","David","Female","Zari")]
        [string]$Voice = "David",
        [Parameter(
            Mandatory=$false,
            HelpMessage = "Provide a window title to be used for receiving the spoken text as its being spoken. This will also automatically enable `$TextWriter."
        )]
        [string]$TargetWindowTitle,
        [Parameter(
            Mandatory=$false,
            HelpMessage = "Enables the spoken text to be written out as its being spoken."
        )]
        [switch]$TextWriter = $False
    )

    Begin {
        switch ($Voice) {
            {$_ -in ("Male","David")}    { $VoiceItem = 0 }
            {$_ -in ("Female","Zari")}   { $VoiceItem = 1 }
        }
        <# TODO: 
            Dig into and compare SAPI using:
            Add-Type -AssemblyName System.Speech
            $Speech = New-Object System.Speech.Synthesis.SpeechSynthesizer
        #>

        # Create a scriptblock, that we'll use first thing in the process block
        $textToSpeech = [scriptblock]::Create{
            # collect the input that will be given to start-job -InputObject
            $payload = $input.GetEnumerator()
            $text = $payload[0]
            $VoiceItem = $payload[1]
            # create the text-to-speech (TTS) object
            $vObject = New-Object -ComObject SAPI.SpVoice
            $vObject.Voice = $vObject.GetVoices().Item($VoiceItem)
            $vObject.Speak($text)
        }

        if ($TargetWindowTitle -and (-not($TextWriter)) ) {
            $TextWriter = $True
        }

        if ($TextWriter) {
            # Define the chars that has a special meaning, we'll later need to wrap these in curly braces {} for it to be written out correctly.
            # See: https://social.technet.microsoft.com/wiki/contents/articles/5169.vbscript-sendkeys-method.aspx
            $specials = @(
                "%"
                "("
                ")"
                "{"
                "}"
                "+"
                "^"
                "~"
                "["
                "]"
            )

            # Word delimiters and how long to pause writing in milliseconds
            # Experimental findings, but as close as I could get. Timing's may still vary due to different pronunciations of sentences and words.
            $pause = @{
                " " =   50..100
                "." =   1000..1300
                "," =   600..700
                "-" =   600..700
                "!" =   1000..1300
                "?" =   950..1200
                ":" =   600..700
            }

            # Grab the current window title, we'll add focus back to the current window upon exit and failure to send keys
            $CurrentWindowTitle = $Host.UI.RawUI.WindowTitle
        } 
        if ($TextWriter -and (-not($TargetWindowTitle)) ) {
            Write-Warning "Make sure to configure a target window title when using the TextWriter switch, in order to see the text being written as its spoken."
        }
    }

    Process {
        # Start speech in a new thread, we'll clean up the job afterwards
        $Job = Start-Job $textToSpeech -InputObject @($text,$voiceItem)

        if ($TextWriter) {
            # create Windows Script Host object to send keys to specific windows by title name
            $wshell = New-Object -ComObject wscript.shell;
            if ($TargetWindowTitle) {
                $null=$wshell.AppActivate($TargetWindowTitle)
            } else {
                $null=$wshell.AppActivate($CurrentWindowTitle)
            }
            $null=$wshell.SendKeys("cls{Enter}")
            $null=$wshell.SendKeys("`"")

            # https://regex101.com/r/x8xPJH/4
            #$WordSeparators = ([regex]::matches("$text","(?<pause> - |[:.,!?] )|(?<delim>\.| )")).Captures.Groups.Where{$_.Name -notmatch "\d" -and $_.Length -ge 1}
            $WordSeparators = ([regex]::matches("$text","(?<pause> - |[.:,!?] )|(?<delim>\b\.\b| |\b\.+|\.$)")).Captures.Groups.Where{$_.Name -notmatch "\d" -and $_.Length -ge 1}
            $WordPosition=0;
            #foreach ($Word in $text -split " - |[:.,!?] |\.| ") {
            foreach ($Word in $text -split " - |[.:,!?] |\b\.\b| |\b\.+|\.$") {
                Write-Verbose "Word: '$Word'"

                $Delim = $WordSeparators[$WordPosition]
                if ($Delim.Value -and ($Delim.Name -eq "pause")) {
                    # Remove spaces
                    $DelimChar = $Delim.Value.Trim(" ")
                }
                if ($Delim.Value -and ($Delim.Name -eq "delim")) {
                    # Do not remove spaces for these word delimiters, since this delim char should contain it
                    $DelimChar = $Delim.Value
                }

                # break up a word into characters and type them out
                for ($CharPosition = 0; $CharPosition -lt $Word.Length) {
                    $Key = $Word.SubString($CharPosition,1)
                    if ($Key -in $specials) {
                        # wrap the special char in curly braces
                        $Key = "{" + $Key + "}"
                    }

                    Try {
                        # Send the key / character
                        $null=$wshell.SendKeys("$Key")
                    }
                    Catch {
                        $null=$wshell.AppActivate("$CurrentWindowTitle")
                        Write-Error "Doh! We had an error."
                        break
                    }
                    Start-Sleep -Milliseconds (10..50 | Get-Random)
                    $CharPosition += 1
                }
                # Pause/word delimiters
                if ($DelimChar -in $pause.Keys) {
                    if (($Delim.Name -eq "delim") -and ($DelimChar -eq ".")) {
                        $ms = 300
                    } else {
                        $ms=$pause[$DelimChar] | Get-Random
                    }
                    Write-Verbose "$($Delim.Name): '$DelimChar' : Pausing for $ms ms"
                    $null=$wshell.SendKeys("$($Delim.Value)")
                    Start-Sleep -Milliseconds $ms
                }
                # reset the DelimChar value before next iteration
                $DelimChar = $null

                # Set position of next word (word increment)
                $WordPosition += 1

                # speak out word per word (testing)
                #$vobject.Speak($word) | Out-Null
            }
            $null=$wshell.SendKeys("`"")
            $null=$wshell.SendKeys("{Enter}")
        } # End if TextWriter
    }
    End {
        # Add focus back to the parent window
        if ($TextWriter) {
            $null=$wshell.AppActivate("$CurrentWindowTitle")
        }
        # We promised to clean up after ourselves
        do {
            $JobState = (Get-Job -Id $Job.Id).State
        } until ($JobState -eq "Completed")
        $Job | Remove-Job
    }
}

Export-ModuleMember -Function Convert-TextToSpeech