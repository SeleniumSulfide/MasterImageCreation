Param(
    [Parameter(Mandatory=$false)]
        $Environment="Environment.JSON",

    [Parameter(Mandatory=$false)]
        [System.IO.FileInfo]$Path = "\\contoso.com\Horizon\Software",

    [Parameter(Mandatory=$false)]
        [switch]$ClearExisting
)

If ($MyInvocation.MyCommand.Path) {
    $CommandPath = Split-Path $MyInvocation.MyCommand.Path -Parent
} elseIf (Test-Path "c:\Temp\Scripts") {
    $CommandPath = "C:\Temp\Scripts"
} else {
    $CommandPath = "\\contoso.com\Horizon\Master\Scripts"
}

Set-ExecutionPolicy Bypass -Scope Process -Force

$Modules = Get-ChildItem (Join-Path $CommandPath "*.psm1")
$Modules | %{ Import-Module $_.Fullname -ErrorAction Stop }

If (Test-Path $Environment) {
    $JSON = Get-Content $Environment
} ElseIf (Test-Path (Join-Path $CommandPath $Environment)) {
    $JSON = Get-Content (Join-Path $CommandPath $Environment)
} else {
    Throw "File not found: $Environment"
}
$Environment = $JSON | ConvertFrom-Json

if ($ClearExisting.IsPresent){
    @($Environment.Evergreen.Name + $Environment.Download.Name) | %{ Get-Item (Join-Path $Path $_) -ErrorAction SilentlyContinue | Remove-Item -Recurse }
}

Get-AppsEvergreen -Applications $Environment.Evergreen -DownloadPath $Path -Force
Get-AppsDownload -Applications $Environment.Download -DownloadPath $Path -Force