function Test-AzureRMCurrentSubscription
{
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Id",
            Position = 0)]
        [alias("Id","SubscriptionId")]
        [string]
        $Identity,
        
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ParameterSetName = "Name",
            Position = 0)]
        [alias("SubscriptionName")]
        [string]
        $Name

    )

    $context = get-azurermContext
    switch ($PSCmdlet.ParameterSetName)
    {
        'Id'
        {
            Write-Verbose "[$(Get-Date -format G)] Testing current subscription id $($context.subscription.id) -eq $Identity"
            if ($context.subscription.id -eq $Identity)
            {
                $true
            }
            else
            {
                $false
            }
            break
        }
        'Name'
        {
            Write-Verbose "[$(Get-Date -format G)] Testing current subscription id $($context.subscription.Name) -eq $Name"
            if ($context.subscription.Name -eq $Name)
            {
                $true
            }
            else
            {
                $false
            }
            break
        }
    }
}