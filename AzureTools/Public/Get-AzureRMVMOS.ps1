Function Get-AzureRMVMOs
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName="Arm")]
        [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]
        $AzureVM,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0,
            ParameterSetName="Classic")]
        [Microsoft.Azure.Commands.ResourceManager.Cmdlets.SdkModels.PSResource]
        $ClassicVM
    )

    if ($PSBoundParameters.ContainsKey('AzureVM'))
    {
        # From StorageProfile.ImageReference
        if (-not [string]::IsNullOrEmpty($AzureVM.storageprofile.imagereference.Offer))
        {
            "$($AzureVM.storageprofile.imagereference.Offer) $($AzureVM.storageprofile.imagereference.Sku)"
        }
        else
        {
            # from StorageProfile.OsDisk
            $AzureVM.StorageProfile.OsDisk.OsType
        }
    }


    if ($PSBoundParameters.ContainsKey('ClassicVM'))
    {
        "Unknown_ClassicVM"
    }

}

