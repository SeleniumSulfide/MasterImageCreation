Param(
    [Parameter(Mandatory=$True)][System.IO.FileInfo]$ConfigFile,
    [Parameter(Mandatory=$False)][Switch]$Confirm
)

$Services = @("ClickToRunSvc","wuauserv","edge*","MicrosoftEdge*","*adobe*","*chrome*","*google*")
$Services | ForEach-Object {
    Get-Service -Name $_ | Set-Service -StartupType Disabled
    Get-Service -Name $_ | Stop-Service
}

Install-Appstack -ConfigFile $ConfigFile -Confirm $Confirm.IsPresent