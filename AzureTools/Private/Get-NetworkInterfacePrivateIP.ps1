function Get-NetworkInterfacePrivateIP
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([string[]])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0)]
        [Microsoft.Azure.Commands.Network.Models.PSNetworkInterface[]]
        $NetworkInterface
    )

    Begin
    {
    }
    Process
    {
        $NetworkInterface.ipconfigurations.privateIpAddress
    }
    End
    {
    }
}
