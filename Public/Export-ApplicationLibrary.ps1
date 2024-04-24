Function Export-ApplicationLibrary(){
    [CmdletBinding(DefaultParameterSetName = "Application")]
    Param(
        [Parameter(
            Mandatory= $True,
            ParameterSetName= "Application")]
        [Parameter(
            Mandatory= $True,
            ParameterSetName= "Template")]
        [ValidateNotNull()]
        [System.IO.FileInfo] $Path,

        [Parameter(
            Mandatory= $False,
            ParameterSetName= "Application")]
        [Parameter(
            Mandatory= $False,
            ParameterSetName= "Template")]
        [System.IO.FileInfo] $ApplicationLibraryPath,
        
        [Parameter(
            Mandatory=$False,
            ParameterSetName = "Application")]
        [String] $Name,
        
        [Parameter(
            Mandatory=$False,
            ParameterSetName = "Template")]
        [Switch] $Template
    )

    Begin {
        if (!($applicationLibraryPath)) {
            $ApplicationLibraryPath = [System.IO.Path]::Combine($MyInvocation.MyCommand.Module.ModuleBase, "Samples\ApplicationLibrary.json")
        }
        $ApplicationLibrary = Get-Content $ApplicationLibraryPath -ErrorAction Stop | ConvertFrom-Json
    }
    Process {
        Switch ($PSCmdlet.ParameterSetName) {
            "Application" {
                $Apps = $ApplicationLibrary.Applications | Where-Object { $_.Name -like "*$Name*" }
            }
            "Template" {
                $Apps = $applicationLibrary.Template
            }
        }

        If (!($Apps.Count)) {
            Write-Host "No Applications match: $Name" -ForegroundColor Red
        }

        ForEach ($App in $Apps) {
            Write-Host "Exporting: $($App.Name)"
            $OutPath = Join-Path $Path "$($App.Name).json"
            $App | ConvertTo-Json -Depth 10 | Set-Content -Path $OutPath -Force
        }
    }
}