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
function Test-AzureNSGInboundPort
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([boolean])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [Microsoft.Azure.Commands.Network.Models.PSNetworkInterface]
        $AzureNIC,

        # Param2 help description
        [int]
        $Port
    )

    Begin
    {
    }
    Process
    {
        write-host -fore cyan -back black $nic.Id

        # skip the nic if it isn't connected to anything
        if ([string]::isNullOrEmpty($nic.VirtualMachine))
        {
            # Write-Warning "Network Interface $($nic.Name) is not connected to a virtual machine."
            throw "Network Interface $($nic.Name) is not connected to a virtual machine."
        }

        # Get the Effective Security Rules
        try
        {
            $param = @{
                NetworkInterfaceName = $Nic.name
                ResourceGroupName    = $Nic.ResourceGroupName
            }
            $NicEffectiveNetworkSecurityGroup = Get-AzureRmEffectiveNetworkSecurityGroup @param -ErrorAction Stop
        }
        catch
        {
            throw $_
        }

        # If there are no effective security rules,
        # the VM is open
        if (-Not $NicEffectiveNetworkSecurityGroup.EffectiveSecurityRules)
        {
            return $True
        }
        
        $EffectiveRules = $NicEffectiveNetworkSecurityGroup.EffectiveSecurityRules

        $AllowRules = [System.Collections.ArrayList]::new()
        $DenyRules = [System.Collections.ArrayList]::new()

        foreach ($Rule in $EffectiveRules )
        {
            if ($Rule.Direction -ne 'Inbound')
            {
                # We don't care about Outbound rules
                Continue
            }

            # parse DestinationPortRange
            $DestPortStart = [int] $rule.DestinationPortRange.split('-')[0]
            $DestPortEnd = [int] $rule.DestinationPortRange.split('-')[1]

            if ($Port -ge $DestPortStart -and $Port -le $DestPortEnd)
            {
                if ($Rule.Access -eq 'Allow')
                {
                    $null = $Allowrules.Add($rule)
                }
                else
                {
                    $null = $DenyRules.Add($rule)
                }
            }
        }

        # At this point, we have all the Allow and Deny Rules which have the given port.
        # If there are no rules which reference this port We need to check for a catchall
        # todo: look for a catch all rules
        if ($Denyrules.count -le 0 -and $AllowRules.count -le 0)
        {
            return $true    # todo: this is in accurate!
        }

        # If there are no deny rules, then the port is allowd
        if ($Denyrules.count -le 0 -and $AllowRules.count -ge 1)
        {
            return $true
        }

        # if there are no Allow rules, then return false
        if ($AllowRules.count -le 0 -and $Denyrules.count -ge 1 )
        {
            return $false
        }

        # Need to do a comparison
        $AllRules = @($AllowRules.ToArray() + $DenyRules.ToArray()) | sort Priority
        if ($AllRules[0].Access -eq 'Allow')
        {
            return $True
        }
    }
    End
    {
    }
}
