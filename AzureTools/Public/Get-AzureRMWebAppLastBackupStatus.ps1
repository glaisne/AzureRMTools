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
#>
function Get-AzureRMWebAppLastBackupStatus
{
    [CmdletBinding()]
    Param (
        # Param1 help description
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = 'ByName')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string[]]
        $WebSiteName

        # [Parameter(Mandatory=$true,
        #            Position=0,
        #            ValueFromPipeline=$true,
        #            ParameterSetName='ByObject')]
        # [ValidateNotNull()]
        # [ValidateNotNullOrEmpty()]
        # [Microsoft.Azure.Commands.WebApps.Models.PSSite[]]
        # $Name,
        
    )
    
    begin
    {
        # Temporary storage directory for any log files we need to download
        $TargetDirectory = "$env:temp\Get-AzureRMWebAppLastBackupStatus_$(Get-random -min 1000 -max 99999)"
    }
    
    process
    {
        Foreach ($Name in $WebSiteName)
        {
            # Get the most recent WebApp backup
            $WebApp = Get-AzureRmWebApp -Name $Name

            $LastBackup = $WebApp | Get-AzureRmWebAppBackuplist | sort finished -desc | select -first 1

            if ($LastBackup -eq $null)
            {
                $BackupStatus = [PSCustomObject][Ordered] @{
                    ResourceGroupName  = $WebApp.ResourceGroup
                    Name               = $WebApp.Name
                    BackupStatus       = [string]::Empty
                    BackupCreated      = [string]::Empty
                    BackupId           = [string]::Empty
                    Note               = [string]::Empty
                    BackupLastLogError = [System.Collections.ArrayList]::new()
                }

                If ($WebApp.ContainerSize -gt 0)
                {
                    $BackupStatus.Note = "No backup found (May be an Azure Function)."
                }
                else
                {
                    $BackupStatus.Note = "No backup found."
                }

                $BackupStatus

                continue
            }
            else
            {
                $BackupStatus = [PSCustomObject][Ordered] @{
                    ResourceGroupName  = $LastBackup.ResourceGroupName
                    Name               = $LastBackup.Name
                    BackupStatus       = $LastBackup.BackupStatus
                    BackupCreated      = $LastBackup.Created
                    BackupId           = $LastBackup.BackupId
                    Note               = [string]::Empty
                    BackupLastLogError = [System.Collections.ArrayList]::new()
                }
            }

            <# Microsoft.Azure.Commands.WebApps.Cmdlets.WebApps.AzureWebAppBackup Info:

            Name               MemberType Definition
            ----               ---------- ----------
            Equals             Method     bool Equals(System.Object obj)
            GetHashCode        Method     int GetHashCode()
            GetType            Method     type GetType()
            ToString           Method     string ToString()
            BackupId           Property   System.Nullable[int] BackupId {get;set;}
            BackupName         Property   string BackupName {get;set;}
            BackupSizeInBytes  Property   System.Nullable[long] BackupSizeInBytes {get;set;}
            BackupStatus       Property   string BackupStatus {get;set;}
            BlobName           Property   string BlobName {get;set;}
            CorrelationId      Property   string CorrelationId {get;set;}
            Created            Property   System.Nullable[datetime] Created {get;set;}
            Databases          Property   Microsoft.Azure.Management.WebSites.Models.DatabaseBackupSetting[] Databases {get;set;}
            Finished           Property   System.Nullable[datetime] Finished {get;set;}
            LastRestored       Property   System.Nullable[datetime] LastRestored {get;set;}
            Log                Property   string Log {get;set;}
            Name               Property   string Name {get;set;}
            ResourceGroupName  Property   string ResourceGroupName {get;set;}
            Scheduled          Property   System.Nullable[bool] Scheduled {get;set;}
            Slot               Property   string Slot {get;set;}
            StorageAccountUrl  Property   string StorageAccountUrl {get;set;}
            WebsiteSizeInBytes Property   System.Nullable[long] WebsiteSizeInBytes {get;set;}

        #>

            If ($LastBackup.BackupStatus -ne 'Succeeded')
            {
                # Make sure our TargetDirectory for log files exists.
                if (-not (Test-path $TargetDirectory -ErrorAction 'SilentlyContinue'))
                {
                    try
                    {
                        $null = new-Item -Path $TargetDirectory -ItemType Directory -Force -ErrorAction 'Stop'
                    }
                    catch
                    {
                        $err = $_
                        $WarningMessage = "Failed to create or access the temp directory for backup log files : $($err.exception.Message)"
                        Write-Warning $WarningMessage

                        $null = $BackupStatus.BackupLastLogError.Add($WarningMessage)
                    }
                }

                # Get the name of the last log file
                $SourceFile = "$($lastbackup.BackupName)`.log"
                $StorageAccountName = $($lastbackup.StorageAccountUrl.split('/')[2].split('.')[0])
                $ContainerName = $($lastbackup.StorageAccountUrl.split('/')[3].split('?')[0])

                # Our storage directory exists, so download the log and see what went wrong.
                $StorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $LastBackup.ResourceGroupName -Name $StorageAccountName
                $Context = New-AzureStorageContext $StorageAccountName -StorageAccountKey $StorageAccountKey[0].value

                # Download the log file.
                try
                {
                    $null = Get-AzureStorageBlobContent -Blob $SourceFile -Container $ContainerName -Destination $TargetDirectory -Context $Context -Force -verbose:$False -ErrorAction 'Stop' -ev 'GetBlobContentError'
                }
                catch
                {
                    $err = $_
                    Write-Warning "Failed to get Blob content $($context.StorageAccountName)\$ContainerName\$SourceFile : $($err.exception.message)"
                }

                if (Test-path "$TargetDirectory\$sourceFile" -ErrorAction 'SilentlyContinue')
                {
                    foreach ($Line in $(gc "$TargetDirectory\$sourceFile" | select-string "File skipped|Error|Fail"))
                    {
                        $null = $BackupStatus.BackupLastLogError.Add($Line)
                    }
                }
                else
                {
                    $BackupStatus.BackupLastLogError.Add("Failed to get Blob content $($context.StorageAccountName)\$ContainerName\$SourceFile) : $($GetBlobContentError)")
                }
            }

            $BackupStatus
        }
    }
    
    end
    {
        remove-item -Path $TargetDirectory -Recurse -Force -ErrorAction 'SilentlyContinue'
    }
}

