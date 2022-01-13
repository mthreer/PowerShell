function Write-Color {
    [CmdletBinding()]
    param (
        [Parameter(
            Position=0, 
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [ValidateNotNullOrEmpty()]
        [String]$Text,

        [Parameter(
            Position=1, 
            Mandatory=$false, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [ValidateSet("Green","Red","Blue")]
        [String]$ForegroundColor,

        [Parameter(
            Position=2, 
            Mandatory=$false, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [ValidateSet("White","Black","Yellow")]
        [String]$BackgroundColor
    )
    
    begin {
        if (-Not($BackgroundColor)) {
            $BackgroundColor = "Black"
        }
        if (-Not($ForegroundColor)) {
            $ForegroundColor = "Green"
        }
    }
    
    process {
        Write-Host "$Text" -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
    }
    
    end {
        
    }
}

Function Write-Hello ($Name) {
    if ($Name) {
        Write-Host "Hello, $Name!"
    } else {
        Write-Host "Hello!"
    }
}

Export-ModuleMember -Function Write-Color, Write-Hello