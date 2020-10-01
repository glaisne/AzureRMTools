<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
.INPUTS
    Inputs to this cmdlet (if any)
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
.COMPONENT
    The component this cmdlet belongs to
.ROLE
    The role this cmdlet belongs to
.FUNCTIONALITY
    The functionality that best describes this cmdlet
#>
function Get-AzureRMWebAppBackupInformation {
    [CmdletBinding()]
    Param (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        $Name
    )
    
    begin {
    }
    
    process {
        Get-AzureRmWebApp -Name $Name | Get-AzureRmWebAppBackupConfiguration

        Get-AzureRmWebApp -Name $Name | Get-AzureRmWebAppBackupList | sort Finished -desc | select ResourceGroupName, Name, Slot, StorageAccountUrl, blobName, PackupStatus, BackupSizeInBytes, Created, Finished, Log, CorrelationId
    }
    
    end {
    }
}