function Get-WindowsUpdates {
    Param(
        [Parameter(Mandatory=$True)]$Session,
        [Parameter(Mandatory=$False)][Switch]$IncludeDrivers
    )
    $Searcher = $Session.CreateUpdateSearcher()
    Write-Host "Searching for Windows Updates"
    #$searcher.serviceid = '9482f4b4-e343-43b6-b170-9a65bc822c77'
    If ($IncludeDrivers.IsPresent) {
        $Criteria = "IsInstalled=0 and IsHidden=0"
    } else {
        $Criteria = "IsInstalled=0 and IsHidden=0 and Type='Software'"
    }
    
    $SearchResult = $Searcher.Search($Criteria)
    $Updates = $SearchResult.Updates
    return , $Updates 
}
