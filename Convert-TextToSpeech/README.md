# Convert-TextToSpeech

## Description

This script will convert text to speech and optionally write out thespoken words as they are being spoken. It will use the SAPI speechsynthesis API in the ComObject SAPI.SpVoice. 

For writing out text, it uses the wscript.shell ComObject to sendkeys using Windows Script Host.

## Examples

### Example

    PS C:\> Convert-TextToSpeech -Text "Hello world."
>This will speak out the text "Hello world." using the default voice Microsoft David from SAPI.

### Example 2

    PS C:\> Convert-TextToSpeech -Text "Hello world." -Voice "Zari" -TextWriter -TargetWindowTitle "MyWindow"
>This will speak out the text "Hello world." using the voice Microsoft Zari from SAPI and simultaneously write out the spoken words to the targetwindow title named "MyWindow"

## Parameters

### -Text

Set the text to be spoken.

### -Voice

Set the desired voice to be used. The default is Microsoft David from SAPI 5.1.

Possible values: Male, Female, David or Zari

### -TextWriter

Enables the spoken words to be simultaneously written out as the words are being spoken. For simultanous effect, have the text sent to a separate targetwindow using $TargetWindowTitle.

### -TargetWindowTitle

Set the name of the target window to receive the spoken words.

## Notes

- Author: Niklas J. MacDowall (niklasjumlin [at] gmail [dot] com)
- Website: [http://blog.jumlin.com](http://blog.jumlin.com)
