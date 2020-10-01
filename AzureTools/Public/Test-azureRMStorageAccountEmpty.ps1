<#
.Synopsis
Short description
.DESCRIPTION
Long description
.EXAMPLE
Example of how to use this cmdlet
.EXAMPLE
Another example of how to use this cmdlet
#>
function Test-azureRMStorageAccountEmpty
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([boolean])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string[]]
        $ResourceGroupName,

        [string[]]
        $Name
    )

    Begin
    {
    }
    Process
    {
        try
        {
            $sa = Get-AzureRMstorageAccount -ResourceGroupName $ResourceGroupName -Name $Name
        }
        catch
        {
            throw $_
        }

        
    }
    End
    {
    }
}