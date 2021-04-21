function New-CSVADUser {
    <#
    .SYNOPSIS
       New-CSVADUser, imports a CSV file with users data and creates the user accounts on an Active Direct server. 
    .DESCRIPTION
        Imports a CSV File  with users data and creates the user accounts on an  Active Direct server Useing PSremoting.
        New-CSVADUser will add them to a Group dictated by the department column, and if a existing group is not found a new group is created.
     .PARAMETER ComputerName
        One or more computer names or IP addresses.
    .PARAMETER ErrorLog 
        specifies a file which errors are written to.
    .PARAMETER LogErrors
        Specifies if Errors are logged to a file, by defalt loggs are saved to C:\Errors.txt.       
    .PARAMETER FilePath
        Specifies the File Path to the Csv File. defaults to current directory\ users.csv.
    .PARAMETER Credential
        If set New-CSVADUser prompt you for username and password, the same credentials are used on all computers.        
    .PARAMETER Force
        When set, if New-CSVADUser finds a username that currently exist it will add the id as a prefix to the username.
        ID column must be present in order to work, by default User name is the first character of the first name and last name.
    .PARAMETER Password
        Sets the Password for all the user's accounts, by default it is username Plus P@ssw0rd!. FYI user is required to change password upon login.
    .PARAMETER PasswordField
        Sets if you have a Password field on the CSV for each users.
    .PARAMETER DontRequirePasswordChange
        Sets if you don't want the users to have to change their on login.
    .PARAMETER Path
        Sets the path PARAMETER  must formated exactly like this 'DC=<your domain>,DC=<your top level domain>' (This is how you make all the users in a certain OU)
    .EXAMPLE
        PS C:\> New-CSVADUser -ComputerName 'localhost'
        Will Run New-CSVADUser on the local Computer with the File Path to the CSV file being C:\users.csv
    .EXAMPLE
        PS C:\> New-CSVADUser -ComputerName 'localhost' -FilePath 'E:\UsersToBeAdded' 
        Will Run New-CSVADUser on the local Computer with the FilePath to the CSV file being E:\UsersToBeAdded
    .EXAMPLE
        PS C:\> New-CSVADUser -ComputerName 'localhost' -LogErrors -Errorlog 'E:\CSVADUser-ErrorsLog.txt'
        Will Run New-CSVADUser on the local Computer with the File Path to the CSV file being C:\users.csv
    .NOTES
        The CSV file must have these columns: First, Last
        Optional columns: Middle, Suffix, Department, Email, ID, Password
        The Department column Will be used as the group that the user is in.
        The ID column must be present if using the Force parameter.
        By default User name is the first character of the first name and last name.
        By default the password is P@ssw0rd!. 
        User is required to change password upon login.
        PS sessions must be enable and working on the server duh.

    #>

    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline=$True, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,
        [string] $FilePath = '.\users.csv',
        [string] $Errorlog = 'C:\Errors.txt',
        [string] $path = $null,
        [string] $Password = 'P@ssw0rd!',
        [switch] $Passwordfield,
        [switch] $DontRequirePasswordChange,
        [switch] $LogErrors,
        [switch] $Credential,
        [switch] $Force  
    )
    begin {
    }
    
    process {
        if ($LogErrors) {
            Write-Output  "New-CSVADUser Error Log `n    Ran At $(Get-Date -Format g) Local Time`n`n`n" | Out-File $Errorlog -Append
        }


        Write-Verbose 'Loaded CSV File'
        :Computerloop
        foreach ($Computer in $ComputerName){
            $count = 0
            if ($LogErrors) {
                Write-Output  "$Computer Log Ran At $(Get-Date -Format g) Local Time`n`n" | Out-File $Errorlog -Append
            }
            function Check-UserName {
                Try {
                    $Script:Available = $false
                    $UserCheck = Invoke-Command -Session $Session -ScriptBlock {Get-ADUser -Filter "Name -eq '$using:UserName' "} -ErrorAction Stop
                    if (([string]::IsNullOrEmpty($UserCheck))) {
                        $Script:Available = $True
                    }    
                    }Catch{    
                        if ($LogErrors) {
                            Write-Output "Could not Get Active Directory User for $UserName." | Out-File $Errorlog -Append
                            Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                    }
                }
            }

            if ($Credential){
                Write-Verbose 'Getting credentials'
                $Credentials = Get-Credential -Message "Please Type the login info for the Servers!"
                try{
                    $Session = New-PSSession -ComputerName $Computer -Credential $Credentials -ErrorAction Stop
                }Catch{
                    Write-Error "$Computer Could not be reached"
                    if ($LogErrors){
                        Write-Output "$Computer Could not be reached" | out-file $Errorlog -Append
                        Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                    }
                    Continue Computerloop
                }
            }else {
                try{
                    Write-Verbose "Setting up PSSession with $computer"
                    $Session = New-PSSession -ComputerName $Computer -ErrorAction Stop
                }Catch{
                    Write-Error "$Computer Could not be reached"
                    if ($LogErrors){
                        Write-Output "$Computer Could not be reached" | out-file $Errorlog -Append
                        Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                    }
                    Continue Computerloop
                }
            }
            Write-Verbose "PSession to $computer connected"

            Try {
                Write-Verbose "Loading ActiveDirectory Module"
                Invoke-Command -Session $Session -ScriptBlock { Import-Module ActiveDirectory}
            }Catch{
                Write-Error "Could not Load ActiveDirectory Module Skipping Server: $Computer "
                if ($LogErrors){
                    Write-Output "Could not Load ActiveDirectory Module Skipping Server: $Computer" | out-file $Errorlog -Append
                    Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                }
                Continue Computerloop                
            }

            :Userloop
            foreach ($user in $users){
                $count++
                Write-Verbose "checking user: $($user.First) $($user.Last)"
                if ( ([string]::IsNullOrEmpty($user.First)) -eq $true -or ([string]::IsNullOrEmpty($user.last) -eq $true )) {
                    Write-Error "Cannot process this user, First or Last column is empty Skiped"
                    if ($LogErrors){
                        Write-Output "Cannot process this user; First or Last column is empty. Verify line $count in the CSV File" | out-file $Errorlog -Append
                        Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                        
                    }     
                    Continue Userloop               
                }


                $UserName  = ($($User.First).SubString(0,1)) + ($User.Last)
                $FullName = (($user.first) + ' ' + ($user.Middle) + ' ' + ($user.Last) + ' ' + ($user.Suffix))
                $GroupName = $user.Department
                if ($Passwordfield){
                    $Userpassword =  $user.password | ConvertTo-SecureString  -AsPlainText -Force
                }else {
                    $Userpassword =  "$Password" | ConvertTo-SecureString  -AsPlainText -Force
                }
                $UserPram = $null

                Check-UserName #Functions#####

                Write-Verbose "Checking if there a group named: $GroupName  "
                if (-not ([string]::IsNullOrEmpty($GroupCheck))) {
                    $GroupAvailable = $false
                    $GroupCheck = Invoke-Command -Session $Session -ScriptBlock  {Get-ADGroup -Filter "Name -eq '$using:GroupName' "  } -ErrorAction Stop #Checks To See if there a Group with that name
                    If (([string]::IsNullOrEmpty($GroupCheck))) {
                        $GroupAvailable = $True
                        Write-Verbose "$GroupName Name is Available"
                    }
                }

                if ($Available -eq $false -And $Force -eq $false){ 
                    write-error "The User Name: $UserName is Unavailable and has been skiped. If you like to use user name the same use the -Force parameter."
                    if ($LogErrors){
                        Write-Output "The User Name: $UserName is Unavailable and has been skiped. If you like to use user name the same use the -Force parameter." | out-file $Errorlog -Append
                        Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                    }
                    Continue Userloop
                }elseif ($Available -eq $false -And $Force -eq $True) { #Set up the users name if the it was taken
                    if (-not ([string]::IsNullOrEmpty($User.ID))) {
                        $UserName = $UserName + $User.ID
                    }else{
                        Write-Error "When Force Parameter is Set ID must be present. User $UserName Has Been Skipped "
                        if ($LogErrors){
                            Write-Output "When Force Parameter is Set ID must be present. User $UserName Has Been Skipped" | out-file $Errorlog -Append
                            Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                        }
                        Continue Userloop
                    }
                    Check-UserName #Functions#####
                }


                Write-Verbose "Setting up Users AD Prammters"
                
                if ($DontRequirePasswordChange){
                    $ChangePasswordAtLogon = $false
                }else {
                    $ChangePasswordAtLogon = $True
                }
                

                $UserPram = @{
                    ChangePasswordAtLogon = $ChangePasswordAtLogon;
                    AccountPassword = $UserPassword
                }
                if (-not ([string]::IsNullOrEmpty($GroupName))) {
                    $UserPram += @{Department = $GroupName} 
                }
                if (-not ([string]::IsNullOrEmpty($UserName))) {
                    $UserPram += @{Name = $UserName} 
                    $UserPram += @{SamAccountName = $UserName} 
                    
                }
                if (-not ([string]::IsNullOrEmpty($user.First))) {
                    $UserPram += @{GivenName = $user.First} 
                }
                if (-not ([string]::IsNullOrEmpty($user.Last))) {
                    $UserPram += @{Surname = $user.Last} 
                }
                if (-not ([string]::IsNullOrEmpty($FullName))) {
                    $UserPram += @{DisplayName = $FullName} 
                }
                if (-not ([string]::IsNullOrEmpty($user.ID))) {
                    $UserPram += @{EmployeeID = $user.ID} 
                }
                if (-not ([string]::IsNullOrEmpty($user.Email))) {
                    $UserPram += @{EmailAddress = $user.Email} 
                }
                if (-not ([string]::IsNullOrEmpty($path))) {
                    $UserPram += @{Path = $Path} 
                }
                #Invoke-Command -Session $Session -ScriptBlock  {$UserPram}
                
                
                if ($GroupAvailable -and -not ([string]::IsNullOrEmpty($GroupName))){
                    try{
                        Write-Verbose "Making group: $GroupName For user: $UserName "
                        Invoke-Command -Session $Session -ScriptBlock {New-ADGroup -Name $Using:GroupName -DisplayName $Using:GroupName -GroupScope Global } -ErrorAction Stop              #Makes the Group
                    }Catch{
                        Write-Error "Could not create Group: $GroupName Skipping user: $UserName "
                        if ($LogErrors){
                            Write-Output "Could not create Group: $GroupName Skipping user: $UserName " | out-file $Errorlog -Append
                            Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                        }
                        Continue Userloop
                    }
                }
                Try {
                    Write-Verbose "Making user: $UserName"
                    Invoke-Command -Session $Session -ScriptBlock {New-ADUser @Using:UserPram}    #Add The new user

                    Invoke-Command -Session $Session -ScriptBlock {get-aduser -Identity  $Using:UserName} | Out-Null #Checks To user was made
                }Catch{
                    Write-Error "Could not Create User: $UserName "
                    if ($LogErrors){
                        Write-Output "Could not Create User: $UserName " | out-file $Errorlog -Append
                        Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                    }
                    Continue Userloop
                }
                if (-not ([string]::IsNullOrEmpty($GroupName))) {
                    Try {
                        Write-Verbose "Adding User: $UserName To Group $GroupName"
                        Invoke-Command -Session $Session -ScriptBlock {Add-ADGroupMember -Identity $Using:GroupName -Members $Using:UserName} -ErrorAction Stop #Adds the user to the Group
                    }Catch{
                        Write-Error "Could not Add User: $UserName to Group: $GroupName"
                        if ($LogErrors){
                            Write-Output ""Could not Add User: $UserName to Group: $GroupName"" | out-file $Errorlog -Append
                            Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                        }
                   } 
                } 
                Write-Output "$UserName Has been Made!"
                


            }
            Exit-PSSession
        }       

    }
    
    end {
    }
}

#-------------------------------------------------------------------------------------------------------------------
function Remove-CSVADUser {
    <#
    .SYNOPSIS
       Remove-CSVADUser, Remove Users for one or more  Active Direct server by importing a CSV file with users data and removing the user accounts. 
    .DESCRIPTION
        Imports a CSV File  with users data and Remove the user accounts on an  Active Direct server Useing PSremoting.
     .PARAMETER ComputerName
        One or more computer names or IP addresses.
    .PARAMETER ErrorLog 
        specifies a file which errors are written to.
    .PARAMETER LogErrors
        Specifies if Errors are logged to a file, by defalt loggs are saved to C:\Errors.txt.       
    .PARAMETER FilePath
        Specifies the File Path to the CSV File. defaults to current directory. users.csv.
    .PARAMETER Credential
        If set Remove-CSVADUser will prompt you for username and password, the same credentials are used on all computers.        
    .EXAMPLE
        PS C:\> Remove-CSVADUser -ComputerName 'localhost'
        Will Run New-CSVADUser on the local Computer with the File Path to the CSV file being C:\users.csv
    .EXAMPLE
        PS C:\> Remove-CSVADUser -ComputerName 'localhost' -FilePath 'E:\UsersToBeRemoved' 
        Will Run Remove-CSVADUser on the local Computer with the FilePath to the CSV file being E:\UsersToBeRemoved
    .EXAMPLE
        PS C:\> Remove-CSVADUser -ComputerName 'localhost' -LogErrors -Errorlog 'E:\CSVADUser-ErrorsLog.txt'
        Will Run Remove-CSVADUser on the local Computer with the FilePath to the CSV file being C:\users.csv
    .NOTES
        The CSV file must have these columns: Username or both aFirst, and Last
        PS sessions must be enable and working on the server duh.

    #>
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline=$True, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,
        [string] $FilePath = '.\users.csv',
        [string] $Errorlog = 'C:\Errors.txt',
        [switch] $LogErrors,
        [switch] $Credential
        
    )
    
    begin {
    }
    
    process {
        if ($LogErrors) {
            Write-Output  "New-CSVADUser Error Log `n    Ran At $(Get-Date -Format g) Local Time`n`n`n" | Out-File $Errorlog -Append
        }
        Try{
            $users = Import-Csv $FilePath  -ErrorAction Stop
            Write-Verbose "Getting CSV File"
        }
        Catch{
            Write-Error "Could not load CSV file, please check FilePath parameter: $FilePath"
            if ($LogErrors){
                Write-Output "Could not load CSV file, please check FilePath parameter: $FilePath" | out-file $Errorlog -Append
                Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
            }
            exit
        }
        Write-Verbose 'Loaded CSV File'
        :Computerloop
        foreach ($Computer in $ComputerName){
            $count = 0
            if ($LogErrors) {
                Write-Output  "$Computer Log Ran At $(Get-Date -Format g) Local Time`n`n" | Out-File $Errorlog -Append

            }
            if ($Credential){
                Write-Verbose 'Getting credentials'
                $Credentials = Get-Credential -Message "Please Type the login info for the Servers!" 
                try{
                    $Session = New-PSSession -ComputerName $Computer -Credential $Credentials -ErrorAction Stop
                }Catch{
                    Write-Error "$Computer Could not be reached"
                    if ($LogErrors){
                        Write-Output "$Computer Could not be reached" | out-file $Errorlog -Append
                        Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                    }
                    Continue Computerloop
                }
            }else {
                try{
                    Write-Verbose "Setting up PSSession with $computer"
                    $Session = New-PSSession -ComputerName $Computer -ErrorAction Stop
                }Catch{
                    Write-Error "$Computer Could not be reached"
                    if ($LogErrors){
                        Write-Output "$Computer Could not be reached" | out-file $Errorlog -Append
                        Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                    }
                    Continue Computerloop
                }
            }
            Write-Verbose "PSession to $computer connected"

            Try {
                Write-Verbose "Loading ActiveDirectory Module"
                Invoke-Command -Session $Session -ScriptBlock { Import-Module ActiveDirectory}
            }Catch{
                Write-Error "Could not Load ActiveDirectory Module Skipping Server: $Computer "
                if ($LogErrors){
                    Write-Output "Could not Load ActiveDirectory Module Skipping Server: $Computer" | out-file $Errorlog -Append
                    Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                }
                Continue Computerloop                
            }

            :Userloop
            foreach ($user in $users){
                $count++
                Write-Verbose "checking user: $($user.First) $($user.Last)"

                If ([string]::IsNullOrEmpty($user.username) -eq $true){
                    if ( ([string]::IsNullOrEmpty($user.First)) -eq $true -or ([string]::IsNullOrEmpty($user.last) -eq $true )) {
                        Write-Error "Cannot process this user, First or Last column is empty Skiped"
                        if ($LogErrors){
                            Write-Output "Cannot process this user; First or Last column is empty. Verify line $count in the CSV File" | out-file $Errorlog -Append
                            Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                            
                        }     
                        Continue Userloop               
                    }
                }

                
                Write-Verbose "Setting UserName"

                if (-not [string]::IsNullOrEmpty($user.username) -eq $true) {
                    $UserName = $User.username
                    
                }else{
                    $UserName  = ($($User.First).SubString(0,1)) + ($User.Last)
                }
                Write-Verbose "$username"

                Try{
                    Write-Verbose "Removing $username"
                    Invoke-Command -Session $Session -ScriptBlock  {get-aduser -Identity $using:UserName | Remove-ADUser  -Confirm:$false} -ErrorAction Stop
                }Catch{
                    Write-Error "Could not Remove $UserName, please verify username"
                    if ($LogErrors){
                        Write-Output "Could not Remove $UserName, verify username" | out-file $Errorlog -Append
                        Write-Host -ForegroundColor Green "Error Has been logged to $Errorlog"
                    }
                                    
                }
                Write-Output "$username Has been deleted!"
            }



        }
    }
    
    
    end {
    }
}

