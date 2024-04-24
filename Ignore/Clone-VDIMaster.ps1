Function Clone-VDIMaster() {
    Param(
        [Parameter(Mandatory=$True)]
        [String]$CloneName,
        [Parameter(Mandatory=$True)]
        [VMware.VimAutomation.ViCore.Impl.V1.VIServerImpl]$Server
    )
    $DC = $CloneName[0]
    Switch ($DC)
    {
        "i" {
            $DSName = "Masters_VS6"
            $RPName = "Masters-IN"
            $FolderName = "Deployed"
            $MasterTemplate = "Master-Template-IN"
        }
        "c" {
            $DSName = "Masters_Local"
            $RPName = "Masters-CO"
            $FolderName = "Deployed"
            $MasterTemplate = "Master-Template-CO"
        }
    }
    $DS = get-datastore -Name $DSName -Server $Server
    $ResourcePool = Get-ResourcePool -Name $RPName -Server $Server
    $Folder = get-folder -name $FolderName -Server $Server
    $Master = Get-Template -Name $MasterTemplate -Server $Server
    New-VM -Server $Server -Template $Master -Datastore $DS -Name $CloneName -ResourcePool $ResourcePool -Location $Folder -RunAsync 
}
