PARAM(
    [Parameter(Mandatory=$True,ValueFromPipeline)]
        [String]$PrintServer,
    [Parameter(Mandatory=$False)]
        [ScriptBlock]$FilterScript
)

$Printers = Get-Printer -ComputerName $PrintServer
if ($FilterScript) { $Printers = $Printers | Where-Object -FilterScript $FilterScript }

$Drivers = $Printers.Drivername | Sort-Object -Unique

$JSON = $Drivers | ConvertTo-Json
$JSON | Set-Clipboard

Write-Host $JSON

Write-Host "JSON has been copied to clipboard" -ForegroundColor Yellow