<#
.SYNOPSIS
    Finds azure RM resources among all available subscriptions and Resource Groups
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES

    ToDo: 
     - Possibly remove the sub-search by resoruce group. What is the value/requirement for this?


    History:
    Version     Who             When            What
    1.0.0       Gene Laisne     ???             - Initial version made
    1.0.1       Gene Laisne     07/05/2018      - Added better looping through Subscriptions
                                                  Added progress bars for subscriptions and Resource Groups
    1.1.0       Gene Laisne     03212019        - Added finding resources by IPAddress
                                                - Added searching IPAddress on Network Interfaces by Private IP
#>

function Find-AzureRmResource
{
    [CmdletBinding(DefaultParameterSetName = 'ResourceName')]
    [Alias()]
    [OutputType([OutputType])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true, 
            ParameterSetName = 'ResourceName',
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string[]]
        $ResourceName,

        [Parameter(Mandatory = $true, 
            ParameterSetName = 'ResourceIPAddress',
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string[]]
        $IPAddress,

        [Parameter(Mandatory = $true, 
            ParameterSetName = 'ResourceDNSName',
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string[]]
        $DNSName,

        [string[]]
        $Subscription
    )

    Begin
    {
        $ResourceTypes = [System.Collections.ArrayList]::new()
        $null = $ResourceTypes.Add('Microsoft.Network/networkInterfaces')
        $null = $ResourceTypes.Add('Microsoft.Network/publicIPAddresses')

        Write-Warning "Find-AzureRMResource will only find resources of these types:"
        $ResourceTypes | ft -AutoSize | out-string -stream | ? {-not [string]::IsnullOrEmpty($_)} | % {Write-Warning $_}
        Write-Warning "Finding resources by DNSNAme is unproven at this point."
    }
    Process
    {
        #
        #    Get Subscriptions
        #


        if ($Subscription -eq 'All' -or [string]::IsNullOrEmpty($Subscription))
        {
            Write-Verbose "Getting All accessable subscriptions to search for resoruce in."
            try
            {
                $Subscriptions = Get-AzureRmSubscription
                Write-Verbose "Found $($Subscriptions | measure | % count) Subscriptions to search"
            }
            catch
            {
                $err = $_
                Throw $err
            }
        }
        else
        {
            Write-Verbose "Subscription is a specific list."
            $Subscriptions = [System.Collections.ArrayList]::new()

            foreach ($Sub in $Subscription)
            {
                if ($Sub -notmatch "^[{(]?[0-9A-F]{8}[-]?([0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$")
                {
                    Write-Verbose "Subscription entry ($Sub) is a Subscription Name"
                    try
                    {
                        $null = $Subscriptions.Add($(Get-AzureRMSubscription -SubscriptionName $Sub -ErrorAction 'Stop'))
                    }
                    catch
                    {
                        $Err = $_
                        Write-Warning "Failed to access subscriptoin $Sub : $($Err.Exception.Message)"
                    }
                }
                else
                {
                    Write-Verbose "Subscription entry ($Sub) is a Subscription ID"
                    try
                    {
                        $null = $Subscriptions.Add($(Get-AzureRMSubscription -SubscriptionId $Sub -ErrorAction 'Stop'))
                    }
                    catch
                    {
                        $Err = $_
                        Write-Warning "Failed to access subscriptoin $Sub : $($Err.Exception.Message)"
                    }
                }
            }
        }


        #
        #    Search
        #


        $i = 0
        foreach ($Sub in $Subscriptions)
        {
            Write-Verbose "Searching Subscription $($Sub.Name) : $($Sub.Id)"

            $PrecentComplete = $([math]::round($($i / $Subscriptions.count * 100), 2))
            Write-Progress -Id 0 -Activity "Processing Subscription $($Sub.Name)`..." -Status "$PrecentComplete %" -PercentComplete $PrecentComplete
        
        
            #
            #    select the subscription
            #
        
        
            # Get Subscription information
            $SubscriptionName = $Sub.Name
            $SubscriptionId = $Sub.Id
        
            if ($SubscriptionName -in $SubscriptionExclusionList)
            {
                Continue
            }
        
            # Try up to 10 times to swich to the specific subscription
            $TryCount = 0
            while (-Not $(Test-AzureRMCurrentSubscription -Id $SubscriptionId) -or $TryCount -gt 10)
            {
                try
                {
                    $null = Select-AzureRmSubscription -SubscriptionId $SubscriptionId -erroraction Stop
                }
                catch
                {
                    $err = $_
                    Write-Warning "Failed to select Azure RM Subscription by subscriptionName $Sub : $($err.exception.message)"
                }
                $TryCount++
            }
        
            # Test if we are in the proper subscription context
            if ($(get-azurermcontext).subscription.id -ne $SubscriptionId)
            {
                Write-warning "Failed to set the proper context : ($($(get-azurermcontext).subscription.name))"
                continue
            }

            Write-Verbose "[$(Get-Date -format G)] Looping through each Resource Group in subscriptoin $SubscriptionName"
            $ResoruceGroups = Get-AzureRMResourceGroup
            $j = 0
            foreach ($ResourceGroup in $ResoruceGroups)
            {
                $PrecentComplete = $([math]::round($($j / ($ResoruceGroups | measure).count * 100), 2))
                Write-Progress -Id 1 -Activity "Processing Resoruce Groups $($ResourceGroup.ResourceGroupName)`..." -Status "$PrecentComplete %" -PercentComplete $PrecentComplete

                Write-Verbose "Searching within Resource Group $($resourceGroup.ResourceId)"


                #
                #    Find by Resource Name
                #


                if ($psBoundParameters.ContainsKey('ResourceName'))
                {
                    foreach ($Resource in $ResourceName)
                    {
                        get-AzureRmResource -ResourceGroupName $ResourceGroup.ResourceGroupName |? {$_.Name -like $Resource}
                    }
                }


                #
                #    Find by IP Address or DNS Name
                #


                if ($PSBoundParameters.ContainsKey('IPAddress') -or $PSBoundParameters.ContainsKey('DNSName'))
                {
                    $Resources = get-azurermResource -ResourceGroupName $ResourceGroup.ResourceGroupName |? {$_.ResourceType -in $ResourceTypes}

                    foreach ($Resource in $Resources)
                    {
                        switch ($Resource.ResourceType) 
                        {
                            'Microsoft.Network/networkInterfaces'
                            {
                                $Object = Get-AzureRmNetworkInterface -Name $Resource.Name -ResourceGroupName $ResourceGroup.ResourceGroupName
                                $IP = Get-NetworkInterfacePrivateIp -NetworkInterface $Object
                                if ($PSBoundParameters.ContainsKey('IPAddress'))
                                {
                                    if ($IP -eq $IPAddress)
                                    {
                                        $Object
                                    }
                                }

                                if ($PSBoundParameters.ContainsKey('DNSName'))
                                {
                                    $HostName = [System.Net.Dns]::GetHostEntry($IP).hostname
                                    if ($HostName -eq $DNSName)
                                    {
                                        $Object
                                    }
                                }
                            }
                            'Microsoft.Network/publicIPAddresses'
                            {
                                $Object = Get-AzureRmPublicIpAddress -Name $Resource.Name -ResourceGroupName $ResourceGroup.ResourceGroupName
                                $IP = Get-PublicIPAddressPublicIP -PublicIPAddress $Object
                                
                                if ($PSBoundParameters.ContainsKey('IPAddress'))
                                {
                                    if ($IP -eq $IPAddress)
                                    {
                                        $Object
                                    }
                                }

                                if ($PSBoundParameters.ContainsKey('DNSName'))
                                {
                                    $HostName = [System.Net.Dns]::GetHostEntry($IP).hostname
                                    if ($HostName -eq $DNSName)
                                    {
                                        $Object
                                    }
                                }
                            }
                            Default {}
                        }
                    }
                }


                $j++
            }
            Write-Progress -Id 1 -Completed -Activity 'Processing Resoruce Groups $($ResoruceGroups.ResourceGroupName)`...'
            $i++
        }
        Write-Progress -Id 0 -Completed -Activity 'Processing Subscription $($Sub.Name)`...'
    }
    End
    {
    }
}




