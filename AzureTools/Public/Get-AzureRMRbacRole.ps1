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
function Get-AzureRMRbacRole
{
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [Alias()]
    [OutputType([PSCustomObject])]
    Param (
        # Param1 help description
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromRemainingArguments = $false)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("Role")] 
        $RoleName,
        
        # Param2 help description
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'All')]
        [switch]
        $All,
        
        # Param3 help description
        [Parameter(ParameterSetName = 'SubscriptionName')]
        [String[]]
        $SubscriptionName,
        
        # Param3 help description
        [Parameter(ParameterSetName = 'SubscriptionId')]
        [String[]]
        $SubscriptionId
    )
    
    begin
    {
    }
    
    process
    {
        Write-Verbose "[$(Get-Date -format G)] Getting Subscriptions"
        switch ($PSCmdlet.ParameterSetName)
        {
            'All'
            {
                $SubscriptionPool = Get-AzureRMSubscription
                break
            }
            'SubscriptionName'
            {
                $SubscriptionPool = [System.Collections.ArrayList]::new()
                foreach ($SubName in $SubscriptionName)
                {
                    try
                    {
                        $Sub = Get-AzureRmSubscription -SubscriptionName $SubName -ErrorAction Stop
                        $null = $SubscriptionPool.Add($Sub)
                    }
                    catch
                    {
                        $err = $_
                        Write-Warning "Failed to access Subscription ($SubName) : $($err.exception.Message)"
                    }
                }
                $SubscriptionPool = $SubscriptionPool.ToArray()
                break
            }
            'SubscriptionId'
            {
                $SubscriptionPool = [System.Collections.ArrayList]::new()
                foreach ($SubId in $SubscriptionId)
                {
                    try
                    {
                        $Sub = Get-AzureRmSubscription -SubscriptionId $SubId -ErrorAction Stop
                        $null = $SubscriptionPool.Add($Sub)
                    }
                    catch
                    {
                        $err = $_
                        Write-Warning "Failed to access Subscription ($SubId) : $($err.exception.Message)"
                    }
                }
                $SubscriptionPool = $SubscriptionPool.ToArray()
                break
            }
            Default { Throw 'could not find parameter name set.'}
        }

        foreach ($Subscription in $SubscriptionPool)
        {
            #
            #    Connect to the subscriptoin
            #


            Write-Verbose "[$(Get-Date -format G)] Subscription: $($Subscription.Name)"
            # Get Subscription information
            [string] $SubscriptionName = $Subscription.Name
            [string] $SubscriptionId = $Subscription.Id

            # Try up to 10 times to swich to the specific subscription
            $TryCount = 0
            while (-Not $(Test-AzureRMCurrentSubscription -Id $SubscriptionId) -or $TryCount -gt 10)
            {
                try
                {
                    Write-Verbose "[$(Get-Date -format G)] Selecting Azure Subscription $SubscriptionName"
                    $null = Select-AzureRmSubscription -SubscriptionId $SubscriptionId -erroraction Stop
                }
                catch
                {
                    $err = $_
                    Write-Warning "Failed to select Azure RM Subscription by subscriptionName $SubscriptionName : $($err.exception.message)"
                }
                $TryCount++
                start-sleep -Seconds 10
            }

            # Test if we are in the proper subscription context
            if ($(get-azurermcontext).subscription.id -ne $SubscriptionId)
            {
                Write-warning "Failed to set the proper context : ($($(get-azurermcontext).subscription.name))"
                continue
            }
            else
            {
                Write-Verbose "[$(Get-Date -format G)] Set the proper context $($(get-azurermcontext).subscription.name)"
            }


            #
            #    Get RBAC users
            #

            Write-Verbose "[$(Get-Date -format G)] Getting RBAC permissions for the role $RoleName under subscription $SubscriptionName"
            try
            {
                $Param1 = @{
                    RoleDefinitionName = $RoleName
                    Scope              = "/subscriptions/$SubscriptionID"
                }
                Get-AzureRmRoleAssignment @Param1 -ErrorAction 'Stop' | select *, @{'Name' = 'SubscriptionName' ; 'Expression' = {$SubscriptionName}}
            }
            catch
            {
                $err = $_
                Write-Warning "Failed to get Role Assignment ($RoleName) in subscription $($SubscriptionName) : $($Err.exection.Message)"
            }
        }
    }
    
    end
    {
    }
}