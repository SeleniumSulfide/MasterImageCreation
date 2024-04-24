<#
    The wraps New-Item and handles different Registry PSProvider paths differently than FileSystem
    Reason:
        HKLM:\SOFTWARE\This\That\Theother
            You have to create This, then That, then TheOther keys
        C:\This\That\TheOther
            New-Item will create each directory in the chain that doesn't exist
#>
Function New-ItemWrapper() {
    Param(
        [Parameter(Mandatory=$True)][String]$Path
    )
    
    $Parent = Split-Path $Path -Parent
    If (!(Test-path $Parent)) {
        New-ItemWrapper -Path $Parent
    }
    
    $Drive = $Path.Substring(0,$Path.Indexof(":"))
    $Provider = (Get-PSDrive -Name $Drive).Provider.Name
    
    Switch ($Provider) {
        "Registry" { New-Item $Path | Out-Null }
        "FileSystem" { New-Item $Path -ItemType Directory | Out-Null }
        Default { New-Item $Path | Out-Null }
    } 
}