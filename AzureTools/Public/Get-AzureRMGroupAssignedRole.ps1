#Requires -Version 5

<#
.SYNOPSIS
    finds a users Assignment Role in an Azure Subscription (at the subscription level).
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
.NOTES
    History:
    Version     Who             When            What
    1.0         Gene Laisne     05/25/2018      - Initial version made


    # ToDo: Make it so $Groupname can take an array of groupnames from the pipeline.
    # ToDo: Add a progress bar for each assignment within a role.

#>
function Get-AzureRMGroupAssignedRole
{
    [CmdletBinding(DefaultParameterSetName = 'AllSubscriptions')]
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
        [Alias("Group", "ObjectId")]
        [string]
        $Groupname,

        # Param2 help description
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'AllSubscriptions')]
        [Alias("All")]
        [switch]
        $AllSubscriptions,

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
        $GuidRegex = "^[{(]?[0-9A-F]{8}[-]?([0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$"
        $SubscriptionPool = [System.Collections.ArrayList]::new()

        function CreateReturnPSObject ($RoleAssignment, $Groupname, $SubscriptionName)
        {
            [PSCustomObject] [Ordered] @{
                RoleDisplayName    = $RoleAssignment.DisplayName
                GroupName          = $Groupname
                Subscription       = $SubscriptionName
                RoleDefinitionName = $RoleAssignment.RoleDefinitionName
                Group              = $RoleAssignment.ObjectType -eq 'Group'
                RoleAssignmentId   = $RoleAssignment.RoleAssignmentId
            }
        }
    }

    process
    {
        Write-Verbose "[$(Get-Date -format G)] Getting Subscriptions"
        switch ($PSCmdlet.ParameterSetName)
        {
            'AllSubscriptions'
            {
                $SubscriptionPool.AddRange(@($(Get-AzureRMSubscription)))
                break
            }
            'SubscriptionName'
            {

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

        $RMADGroup = $null

        if ($Groupname.trim() -match $GuidRegex)
        {
            # This is a GUID and so we assume it is an ObjectId
            Write-Verbose "[$(Get-Date -format G)] groupname passed in is a GUID."
            Write-Verbose "[$(Get-Date -format G)] Trying to identify group by ObjectId"
            try
            {
                $RMADGroup = Get-azureRmAdGroup -ObjectId $Groupname -ErrorAction Stop
            }
            catch
            {
                $err = $_
                Write-Warning "Failed attempting to access RM AD Group with GUID : $($err.exception.message)"
            }
        }

        # The provided groupname is not a GUID, or we failed to get the group by GUID (ObjectId)
        if ($Groupname.trim() -notmatch $GuidRegex -or $RMADGroup -eq $null)
        {
            Write-Verbose "[$(Get-Date -format G)] Trying to identify group by SearchString ($Groupname)"
            try
            {
                $RMADGroup = Get-azureRMAdGroup -DisplayName $Groupname -ErrorAction Stop
            }
            catch
            {
                $err = $_
                Write-Warning "Failed attempting to access RM AD Group with SearchString : $($err.exception.message)"
            }
        }

        if ($RMADGroup -eq $null)
        {
            Write-Warning "Failed to access group ($Groupname) in Azure AD. Continuing, but results may be incomplete."
        }

        $i = 0
        foreach ($subscription in $SubscriptionPool)
        {
            $PrecentComplete = $([math]::round($($i / $SubscriptionPool.count * 100), 2))
            Write-Progress -Id 0 -Activity "Processing group $Groupname in Subscription $($Subscription.Name)`..." -Status "$PrecentComplete %" -PercentComplete $PrecentComplete


            #
            #    select the subscription
            #


            # Get Subscription information
            $Subscription_Name = $Subscription.Name
            $Subscription_Id = $Subscription.Id

            Write-Verbose "[$(Get-Date -format G)] Subscription: $Subscription_Name"

            # if ($SubscriptionName -in $SubscriptionExclusionList)
            # {
            #     Continue
            # }

            # Try up to 10 times to swich to the specific subscription
            $TryCount = 0
            while (-Not $(Test-AzureRMCurrentSubscription -Id $Subscription_Id) -or $TryCount -gt 10)
            {
                try
                {
                    Write-Verbose "[$(Get-Date -format G)] Attempting to set subscription context (Try $TryCount)"
                    $null = Select-AzureRmSubscription -SubscriptionId $Subscription_Id -erroraction Stop
                }
                catch
                {
                    $err = $_
                    Write-Warning "Failed to select Azure RM Subscription by subscriptionName $Subscription : $($err.exception.message)"
                }
                $TryCount++
            }

            # Test if we are in the proper subscription context
            if ($(Get-AzureRMcontext).subscription.id -ne $Subscription_Id)
            {
                Write-warning "Failed to set the proper context : ($($(Get-AzureRMcontext).subscription.name))"
                continue
            }
            else
            {
                Write-Verbose "[$(Get-Date -format G)] Set the proper context $($(Get-AzureRMcontext).subscription.name)"
            }


            #
            #    get Roles with this group
            #


            $Properties = @('DisplayName', 'SignInName', 'RoleDefinitionName', 'Scope', 'RoleAssignmentId')

            $RoleAssignment = $null
            if ($RMADGroup -ne $null -and ($RMADGroup | measure).count -eq 1)
            {
                Write-Verbose "[$(Get-Date -format G)] Getting Role Assignment for group ID $($RMADGroup.Id)"
                $RoleAssignment = Get-AzureRmRoleAssignment -ObjectId $RMADGroup.Id | select $Properties
            }
            else
            {
                Write-Verbose "[$(Get-Date -format G)] Getting Role Assignment for Group by DisplayName or SignInName ($Groupname)."
                $RoleAssignment = Get-AzureRmRoleAssignment |? {$_.displayName -eq "$Groupname" -or $_.SignInName -like "$Groupname@*"} | select $Properties
            }

            # Return our custom object with group and assignment information.
            if ($RoleAssignment -ne $null)
            {
                CreateReturnPSObject -RoleAssignment $RoleAssignment -Groupname $Groupname -SubscriptionName $Subscription_Name
            }


            #
            #    Check group memberships
            #

            # Write-Verbose "[$(Get-Date -format G)] Checking group memberships..."
            # $GroupAssignments = Get-AzureRmRoleAssignment |? {$_.ObjectType -eq 'Group'}
            # $j = 0
            # Foreach ($Group in $GroupAssignments)
            # {
            #     $PrecentComplete = $([math]::round($($j / $(($GroupAssignments | measure).count) * 100), 2))
            #     Write-Progress -Id 1 -Activity "Processing Group assignment $($Group.DisplayName)`..." -Status "$PrecentComplete %" -PercentComplete $PrecentComplete

            #     $Role = $Group.RoleDefinitionName
            #     Write-Verbose "[$(Get-Date -format G)] Checking Group Role: $Role - Group: $($Group.DisplayName)"

            #     foreach ($GroupMember in Get-AzureRMADGroupMember -GroupObjectId $Group.ObjectId | sort displayName)
            #     {
            #         Write-Verbose "[$(Get-Date -format G)]  - Group member: $($GroupMember.displayName)"
            #         if ($RMADGroup -ne $null -and ($RMADGroup | measure).count -eq 1)
            #         {
            #             if ($GroupMember.id -eq $RMADGroup.Id)
            #             {
            #                 #Write-Verbose "[$(Get-Date -format G)]    - $($GroupMember.id) -eq $($RMADGroup.Id)"
            #                 #$Group
            #                 CreateReturnPSObject -RoleAssignment $Group -Username $Groupname -RMADUser $RMADGroup
            #             }
            #             else
            #             {
            #                 #Write-Verbose "[$(Get-Date -format G)]    - $($GroupMember.id) -ne $($RMADGroup.Id)"
            #             }
            #         }
            #         else
            #         {
            #             if ($GroupMember.displayName -like "*$Groupname*" -or `
            #                     $GroupMember.userPrincipalNAme -match "$Groupname@carbonite(|inc)\.com")
            #             {
            #                 #$Group
            #                 CreateReturnPSObject -RoleAssignment $Group -Username $Groupname -RMADUser $RMADGroup
            #             }
            #         }
            #     }

            #     $j++
            # }
        }
    }
    end
    {
    }
}