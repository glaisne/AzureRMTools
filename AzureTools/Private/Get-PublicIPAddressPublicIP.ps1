Function Get-PublicIPAddressPublicIP
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
        [Microsoft.Azure.Commands.Network.Models.PSPublicIpAddress[]]
        $PublicIPAddress
    )

    Begin
    {
    }
    Process
    {
        if ($PublicIPAddress.IpAddress -ne 'Not Assigned')
        {
            $PublicIPAddress.IpAddress
        }
        else
        {
            $null
        }
    }
    End
    {
    }
}