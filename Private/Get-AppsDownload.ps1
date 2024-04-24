<#
    This consumes the Download seciton of the Environment.JSON
    The URIs specified are used to download specific files and are manual scraped from their website
    if a FileName is specified, that filename will be used
    Otherwise, the URI will be used to get the file name
    If an Application has a specified ScriptBlock, that is ran prior to downloading. The SBs are used to parse a main URI for a download link
#>
Function Get-AppsDownload() {
    Param(
       [Parameter(Mandatory=$True)]
           $Applications,
       [Parameter(Mandatory=$True)]
           [System.IO.FileInfo]$DownloadPath
   )
   ForEach ($Application in $Applications) {
       $Destination = Join-Path $DownloadPath $Application.Name
       If (!(Test-Path $Destination)) { New-ItemWrapper -Path $Destination }
       ForEach ($URI in $Application.URI) {
           #Don't use Invoke-ScriptBlocks as that changes the scope
           ForEach ($ScriptBlock in $Application.PreScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
           if ($Application.FileName) {
               $OutFile = Join-Path $Destination $Application.FileName
           } else {
               $OutFile = Join-Path $Destination (Split-Path $URI -Leaf)
           }

           If (!(Test-Path $OutFile)) {
               Write-Host "Download: $($Application.Name)"
               Invoke-WebRequest -UseBasicParsing -Uri $URI -OutFile $OutFile
           }
           ForEach ($ScriptBlock in $Application.PostScriptBlocks) { Invoke-Command -ScriptBlock ([ScriptBlock]::Create($ScriptBlock)) -NoNewScope }
       }
   }
}