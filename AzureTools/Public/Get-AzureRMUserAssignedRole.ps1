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
    1.1         Gene Laisne     10/25/2018      - Added the skipping of groups (by Id) which have already been checked
                                                - Better progress bar informition for groups.


    # ToDo: Make it so $Username can take an array of usernames from the pipeline.
    # ToDo: Add a progress bar for each assignment within a role.
    # toDo: Remove the inspecting of a group if the user has that role already assigned individually.

#>
function Get-AzureRMUserAssignedRole
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
        [Alias("User", "Samaccountname", "ObjectId")] 
        [string]
        $Username,
        
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

        function CreateReturnPSObject ($RoleAssignment, $Username, $RMADUser)
        {
            [PSCustomObject] [Ordered] @{
                UserPrincipalName  = $RMADUser.UserPrincipalName
                DisplayName        = $RMADUser.DisplayName
                Name               = $Username    
                RoleDefinitionName = $RoleAssignment.RoleDefinitionName
                Group              = $RoleAssignment.ObjectType -eq 'Group'
                User               = $RoleAssignment.ObjectType -eq 'User'
                GroupName          = $(If ($RoleAssignment.ObjectType -eq 'Group') {$RoleAssignment.DisplayName})
                RoleAssignmentId   = $RoleAssignment.RoleAssignmentId
            }
        }

        $GroupIdsUserIsNotAMemberOf = [System.Collections.ArrayList]::new()
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

        $RMADUser = $null

        if ($username.trim() -match $GuidRegex)
        {
            # This is a GUID and so we assume it is an ObjectId
            Write-Verbose "[$(Get-Date -format G)] username passed in is a GUID."
            Write-Verbose "[$(Get-Date -format G)] Trying to identify user by ObjectId"
            try
            {
                $RMADUser = Get-azureRMAdUser -ObjectId $Username -ErrorAction Stop
            }
            catch
            {
                $err = $_
                Write-Warning "Failed attempting to access RM AD User with GUID : $($err.exception.message)"
            }
        }

        # The provided username is not a GUID, or we failed to get the user by GUID (ObjectId)
        if ($username.trim() -notmatch $GuidRegex -or $RMADUser -eq $null)
        {
            Write-Verbose "[$(Get-Date -format G)] Trying to identify user by SearchString ($Username)"
            try
            {
                $RMADUser = Get-azureRMAdUser -SearchString $Username -ErrorAction Stop
            }
            catch
            {
                $err = $_
                Write-Warning "Failed attempting to access RM AD User with SearchString : $($err.exception.message)"
            }
        }

        if ($RMADUser -eq $null)
        {
            Write-Warning "Failed to access user ($username) in Azure AD. Continuing, but results may be incomplete."
        }

        $i = 0
        foreach ($subscription in $SubscriptionPool)
        {
            $PrecentComplete = $([math]::round($($i / $SubscriptionPool.count * 100), 2))
            Write-Progress -Id 0 -Activity "Processing user $Username in Subscription $($Subscription.Name)`..." -Status "$PrecentComplete %" -PercentComplete $PrecentComplete
        
        
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
            if ($(get-azurermcontext).subscription.id -ne $Subscription_Id)
            {
                Write-warning "Failed to set the proper context : ($($(get-azurermcontext).subscription.name))"
                continue
            }
            else
            {
                Write-Verbose "[$(Get-Date -format G)] Set the proper context $($(get-azurermcontext).subscription.name)"
            }
        

            #
            #    get Roles with this user
            #

            
            $Properties = @('DisplayName', 'SignInName', 'RoleDefinitionName', 'Scope', 'RoleAssignmentId')

            $RoleAssignment = $null
            if ($RMADUser -ne $null -and ($RMADUser | measure).count -eq 1)
            {
                Write-Verbose "[$(Get-Date -format G)] Getting Role Assignment for user ID $($RMADUser.Id)"
                $RoleAssignment = Get-AzureRmRoleAssignment -ObjectId $RMADUser.Id | select $Properties
            }
            else
            {
                Write-Verbose "[$(Get-Date -format G)] Getting Role Assignment for User by DisplayName or SignInName ($Username)."
                $RoleAssignment = Get-AzureRmRoleAssignment |? {$_.displayName -eq "$Username" -or $_.SignInName -like "$Username@*"} | select $Properties
            }

            # Return our custom object with user and assignment information.
            if ($RoleAssignment -ne $null)
            {
                CreateReturnPSObject -RoleAssignment $Group -Username $Username -RMADUser $RMADUser
            }

            
            #
            #    Check group memberships
            #

            Write-Verbose "[$(Get-Date -format G)] Checking group memberships..."
            $GroupAssignments = Get-AzureRmRoleAssignment |? {$_.ObjectType -eq 'Group'}
            $j = 0
            Foreach ($Group in $GroupAssignments)
            {
                if ($Group.ObjectId -in $GroupIdsUserIsNotAMemberOf)
                {
                    Write-Verbose "We have already checked $(Group.Name), skipping this group for now."
                    Continue
                }

                $PrecentComplete = $([math]::round($($j / $(($GroupAssignments | measure).count) * 100), 2))
                Write-Progress -Id 1 -Activity "Processing Group assignment $($Group.DisplayName)`..." -Status "$PrecentComplete %" -PercentComplete $PrecentComplete

                $Role = $Group.RoleDefinitionName
                Write-Verbose "[$(Get-Date -format G)] Checking Group Role: $Role - Group: $($Group.DisplayName)"

                foreach ($GroupMember in Get-AzureRMADGroupMember -GroupObjectId $Group.ObjectId | sort displayName)
                {
                    Write-Verbose "[$(Get-Date -format G)]  - Group member: $($GroupMember.displayName)"
                    if ($RMADUser -ne $null -and ($RMADUser | measure).count -eq 1)
                    {
                        if ($GroupMember.id -eq $RMADUser.Id)
                        {
                            #Write-Verbose "[$(Get-Date -format G)]    - $($GroupMember.id) -eq $($RMADUser.Id)"
                            #$Group
                            CreateReturnPSObject -RoleAssignment $Group -Username $Username -RMADUser $RMADUser
                            $null = $GroupIdsUserIsNotAMemberOf.Add($Group.ObjectId)
                            break
                        }
                        else 
                        {
                            #Write-Verbose "[$(Get-Date -format G)]    - $($GroupMember.id) -ne $($RMADUser.Id)"
                        }
                    }
                    else
                    {
                        if ($GroupMember.displayName -like "*$username*" -or `
                                $GroupMember.userPrincipalNAme -match "$Username@carbonite(|inc)\.com")
                        {
                            #$Group
                            CreateReturnPSObject -RoleAssignment $Group -Username $Username -RMADUser $RMADUser
                            $null = $GroupIdsUserIsNotAMemberOf.Add($Group.ObjectId)
                            break
                        }
                    }
                }

                $j++
            }
            Write-progress -id 1 -Completed -Activity "Processing Group assignment $($Group.DisplayName)`..."

            $i++
        }
    }
    end
    {
    }
}