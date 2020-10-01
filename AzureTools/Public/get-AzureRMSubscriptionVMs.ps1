function Get-AzureRMSubscriptionVMs
{
    [CmdletBinding()]
    Param ()
    
    $SubscriptionVMs = [System.Collections.ArrayList]::new()

    $VMsRm = get-azurermresource -ODataQuery "`$filter=ResourceType eq 'Microsoft.compute/VirtualMachines'" 
    $VMsClassic = get-azurermresource -ODataQuery "`$filter=ResourceType eq 'Microsoft.ClassicCompute/virtualMachines'" 
    $null = $SubscriptionVMs.AddRange(@($VMsRm))
    $null = $SubscriptionVMs.AddRange(@($VMsClassic))    

    $SubscriptionVMs
}
