function New-CVSADUser {
    <#
    .SYNOPSIS
       New-CVSADUser, imports a CSV file with users data and creates the user accounts on an Active Direct server. 
    .DESCRIPTION
        Imports a CSV File  with users data and creates the user accounts on an  Active Direct server Useing PSremoting.
        New-CVSADUser will add them to a Group dictated by the department column, and if a existing group is not found a new group is created.
     .PARAMETER ComputerName
        One or more computer names or IP addresses.
    .PARAMETER ErrorLog 
        specifies a file which errors are written to.
    .PARAMETER LogErrors
        Specifies if Errors are logged to a file, by defalt loggs are saved to C:\Errors.txt.       
    .PARAMETER Path
        Specifies the Path to the Csv File. defaults to current path users.csv.
    .PARAMETER Credential
        If set New-CVSADUser prompt you for username and password, the same credentials are used on all computers.        
    .PARAMETER Force
        When set, if New-CVSADUser finds a username that currently exist it will add the id as a prefix to the username.
        ID column must be present in order to work, by default User name is the first character of the first name and last name.
    .PARAMETER PasswordPrefix
        Sets the Password Prefix for the user's accounts, by default it is username Plus 1234A. FYI user is required to change password upon login.
    .EXAMPLE
        PS C:\> New-CVSADUser -ComputerName 'localhost'
        Will Run New-CVSADUser on the local Computer with the path to the CSV file being C:\users.csv
    .EXAMPLE
        PS C:\> New-CVSADUser -ComputerName 'localhost' -path 'E:\UsersToBeAdded' 
        Will Run New-CVSADUser on the local Computer with the path to the CSV file being E:\UsersToBeAdded
    .EXAMPLE
        PS C:\> New-CVSADUser -ComputerName 'localhost' -LogErrors -Errorlog 'E:\CVSADUser-ErrorsLog.txt'
        Will Run New-CVSADUser on the local Computer with the path to the CSV file being C:\users.csv
    .NOTES
        The CSV file must have these columns: First, Last
        Optional columns: Middle, Suffix, Department, Email, ID
        The Department column Will be used as the group that the user is in.
        The ID column must be present if using the Force parameter.
        By default User name is the first character of the first name and last name.
        By default the password is user name Plus 1234A. 
        User is required to change password upon login.
        PS sessions must be enable and working on the server duh.

    #>

    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $True, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,
        [string] $Path = '.\users.csv',
        [string] $Errorlog = 'C:\Errors.txt',
        [string] $PasswordPrefix = '1234A',
        [switch] $LogErrors,
        [switch] $Credential,
        [switch] $Force

        
    )
    begin {
    }
    
    process {
        if ($LogErrors) {
            Write-Output  "New-CVSADUser Error Log `n    Ran At $(Get-Date -Format g) Local Time`n`n`n" | Out-File $Errorlog -Append
        }
        Try {
            $users = Import-Csv $path  -ErrorAction Stop
            Write-Verbose "Getting CSV File"
        }
        Catch {
            Write-Error "Could not load CSV file, please check typed path: $path"
            if ($LogErrors) {
                Write-Output "Could not load CSV file, please check typed path: $path" | out-file $Errorlog -Append
                Write-Error "Error Has been logged to $Errorlog"
            }
            exit
        }
        Write-Verbose 'Loaded CSV File'
        :Computerloop
        foreach ($Computer in $ComputerName) {
            if ($LogErrors) {
                Write-Output  "$Computer Log Ran At $(Get-Date -Format g) Local Time`n`n" | Out-File $Errorlog -Append
            }
            function Check-UserName {
                Try {
                    $Available = $false
                    Get-ADUser -Filter "Name -eq '$UserName' " -ErrorAction Stop
                }
                Catch {
                    $Available = $True
                    Write-Verbose "'$UserName is Available"
                }
                
            }
            if ($LogErrors) {
                Write-Output "Running On $Computer." | Out-File $Errorlog -Append
                Write-Error "Error Has been logged to $Errorlog"
            }

            if ($Credential) {
                Write-Verbose 'Getting credentials'
                $Credentials = Get-Credential 
                try {
                    Enter-PSSession -ComputerName $Computer -Credential $Credentials -ErrorAction Stop
                }
                Catch {
                    Write-Error "$Computer Could not be reached"
                    if ($LogErrors) {
                        Write-Output "$Computer Could not be reached" | out-file $Errorlog -Append
                        Write-Error "Error Has been logged to $Errorlog"
                    }
                    Continue Computerloop
                }
            }
            else {
                try {
                    Write-Verbose "Setting up PSSession with $computer"
                    Enter-PSSession -ComputerName $Computer -ErrorAction Stop
                }
                Catch {
                    Write-Error "$Computer Could not be reached"
                    if ($LogErrors) {
                        Write-Output "$Computer Could not be reached" | out-file $Errorlog -Append
                        Write-Error "Error Has been logged to $Errorlog"
                    }
                    Continue Computerloop
                }
            }
            Write-Verbose "PSession to $computer connected"
            Write-Verbose "Loading ActiveDirectory Module"
            Import-Module ActiveDirectory

            :Userloop
            foreach ($user in $users) {
                Write-Verbose "checking user: $($user.First) $($user.Last)"
                $UserName = ($($User.First).SubString(0, 1)) + ($User.Last)
                $FullName = (($user.first) + ' ' + ($user.Middle) + ' ' + ($user.Last) + ' ' + ($user.Suffix))
                $GroupName = $user.Department
                $password = "$($UserName.ToString())$($PasswordPrefix.ToString())" | ConvertTo-SecureString  -AsPlainText -Force

                Check-UserName #Functions#####

                Write-Verbose "Checking if there a group named: $GroupName  "
                Try {
                    $GroupAvailable = $false
                    Get-ADGroup -Filter "Name -eq '$GroupName' "  -ErrorAction Stop
                }
                Catch {
                    $GroupAvailable = $True
                    Write-Verbose "$GroupName hasn't been created yet"
                }
                if ($Available -eq $false -And $Force -eq $false) {

                    write-error "The User Name: $UserName is Unavailable and has been skiped. If you like to use user name the same use the -Force parameter."
                    if ($LogErrors) {
                        Write-Output "The User Name: $UserName is Unavailable and has been skiped. If you like to use user name the same use the -Force parameter." | out-file $Errorlog -Append
                        Write-Error "Error Has been logged to $Errorlog"
                    }
                    Continue Userloop
                }
                elseif ($Available -eq $false -And $Force -eq $True) {
                    if (-not ([string]::IsNullOrEmpty($User.ID))) {
                        $UserName = $UserName + $User.ID
                    }
                    else {
                        Write-Error "When Force Parameter is Set ID must be present. User $UserName Has Been Skipped "
                        if ($LogErrors) {
                            Write-Output "When Force Parameter is Set ID must be present. User $UserName Has Been Skipped" | out-file $Errorlog -Append
                            Write-Error "Error Has been logged to $Errorlog"
                        }
                        Continue Userloop
                    }
                    Check-UserName #Functions#####
                }


                Write-Host "Setting up Users AD Prammters"
                $UserPram = @{
                    'ChangePasswordAtLogon' = $true;
                    'AccountPassword'       = $password
                }
                if (-not ([string]::IsNullOrEmpty($GroupName))) {
                    $UserPram += @{'Department' = $GroupName } 
                }
                if (-not ([string]::IsNullOrEmpty($UserName))) {
                    $UserPram += @{'Name' = $UserName } 
                    $UserPram += @{'SamAccountName' = $UserName } 
                    
                }
                if (-not ([string]::IsNullOrEmpty($user.First))) {
                    $UserPram += @{'GivenName' = $user.First } 
                }
                if (-not ([string]::IsNullOrEmpty($user.Last))) {
                    $UserPram += @{'Surname' = $user.Last } 
                }
                if (-not ([string]::IsNullOrEmpty($FullName))) {
                    $UserPram += @{'DisplayName' = $FullName } 
                }
                if (-not ([string]::IsNullOrEmpty($user.ID))) {
                    $UserPram += @{'EmployeeID' = $user.ID } 
                }
                if (-not ([string]::IsNullOrEmpty($user.Email))) {
                    $UserPram += @{'EmailAddress' = $user.Email } 
                }
                if ($GroupAvailable) {
                    try {
                        Write-Verbose "Making group: $GroupName For user: $UserName "
                        New-ADGroup -Name $user.Department -DisplayName $user.Department -ErrorAction Stop
                    }
                    Catch {
                        Write-Error "Could not create Group: $GroupName Skipping user: $UserName "
                        if ($LogErrors) {
                            Write-Output "Could not create Group: $GroupName Skipping user: $UserName " | out-file $Errorlog -Append
                            Write-Error "Error Has been logged to $Errorlog"
                        }
                        Continue Userloop
                    }
                }
                Try {
                    Write-Verbose "Making user: $UserName"
                    New-New-ADUser $UserPram  -ErrorAction Stop
                }
                Catch {
                    Write-Error "Could not Create User: $UserName "
                    if ($LogErrors) {
                        Write-Output "Could not Create User: $UserName " | out-file $Errorlog -Append
                        Write-Error "Error Has been logged to $Errorlog"
                    }
                    Continue Userloop
                }
                if (-not ([string]::IsNullOrEmpty($GroupName))) {
                    Try {
                        Write-Verbose "Adding User: $UserName To Group $GroupName"
                        Add-ADGroupMember -Identity $GroupName -Members $UserName -ErrorAction Stop
                    }
                    Catch {
                        Write-Error "Could not Add User: $UserName to Group: $GroupName"
                        if ($LogErrors) {
                            Write-Output ""Could not Add User: $UserName to Group: $GroupName"" | out-file $Errorlog -Append
                            Write-Error "Error Has been logged to $Errorlog"
                        }
                    }
                }
                Write-Outputput "$UserName Has been Made!"


            }
            Exit-PSSession
        }       

    }
    
    end {
    }
}
