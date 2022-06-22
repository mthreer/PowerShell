# Create a target window
$host.ui.RawUI.WindowTitle = 'PowerShell Demo'

# Launch powershell and create a target window
Start-Process PowerShell -ArgumentList "-noexit `$host.ui.RawUI.WindowTitle = 'PowerShell Demo'"

Convert-TextToSpeech -Text "Hello world!" -Voice Male -TextWriter -TargetWindowTitle "PowerShell Demo"

function Q: ($data) {Convert-TextToSpeech -Text $data -Voice Male }
function A: ($data) {Convert-TextToSpeech -Text $data -Voice Female }


Q: "Are you having fun yet?"

A: "Yes, we're having a blast! Haha."
A: "Text to speech is sorta fun"