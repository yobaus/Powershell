#13.6.2 LAB - A, Page 142, learn powershell toolmaking in a month of lunches
function Get-MOLinfo {
    <#
    .SYNOPSIS
        Retrieve Basic system information for one or more local or remote Computers. 
    .DESCRIPTION
        Using Windows Management Instrumentation (WMI) queries one or more local or remote Computers for  basic system information.
        Get-info queries Win32_ComputerSystem class for Workgroup, AdminPasswordStatus; Display as Disabled, Enabled, NA, or  Unknown; Modle, and Manufaturer.
        It also  queries Win32_BIOS class for SerialNumber and Win32_OperatingSystem class for Version, and ServicePackMajorVersion.
        It then returns one Powershell object with all the results for each Computer dictated with the -Computername parameter.
    .PARAMETER ComputerName
        One or more computer names or IP addresses.
    .PARAMETER ErrorLog 
        specifies a file which errors are written to.

    .PARAMETER LogErrors
        Specifies if Errors are logged to a file, by defalt loggs are saved to C:\Errors.txt.
    
    .EXAMPLE
        PS C:\> Get-MOLinfo -Computername 'localhost'
        Returns the information for a single computer

    .EXAMPLE
        PS C:\> Get-Content Computerlist.txt |  Get-MOLinfo
        This example shows how to pipe in Comtpuer names to get information for multiple computer with a text file

    .EXAMPLE
        PS C:\> Get-MOLinfo -Computername '192.168.1.3', 'Computer1'
        This example shows how to get information for multiple computer with hostname and IP address
    .EXAMPLE
        PS C:\> Get-MOLinfo -Computername 'localhost' -LogErrors -Errorlog log.txt
        Returns the information for a single computer, and returns any errors to a log file.
    .INPUTS
        System.Management.Automation.PSObject
        You can pipe objects in to -Comptuername parameter
    .OUTPUTS
        MOL.ComputerSystemInfo
        Get-MOLinfo  returns the objects for each Comptuer specified with the -Comptuername parameter
    .NOTES
        LAB B, from 'learn powershell toolmaking in a month of lunches'
    #>
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline=$True, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,

        [string] $Errorlog = 'C:\Errors.txt',
        [switch] $LogErrors
    )
    
    begin {
    }
    
    process {

        foreach ($Computer in $ComputerName) {
            Try {
                $ok = $True
                $system = Get-WmiObject -ComputerName $Computer -class Win32_ComputerSystem -ErrorAction Stop
                Write-Verbose "Connecting to $Computer wmi for Class Win32_ComputerSystem"
            }Catch{
                Write-Error "Get-MOLinfo Has Failed: $computer Could not be reached."
                $ok = $false
                if ($LogErrors){
                    "$Computer Has failed." | Out-File $Errorlog -Append
                    Write-Error "Error Has been logged to $Errorlog"
                }
            }

            if ($ok){
                $bois = Get-WmiObject -ComputerName $Computer -class Win32_BIOS
                Write-Verbose "Connecting to $Computer wmi for Class Win32_BIOS"
                $os = Get-WmiObject -ComputerName $Computer -class Win32_OperatingSystem
                Write-Verbose "Connecting to $Computer wmi for Class Win32_OperatingSystem"
                $props = @{
                        'ComptuerName' = $computer;
                        'WorkGroup' = $system.domain;
                        'Model' = $system.Model;
                        'Manufacturer' = $system.Manufacturer;
                        'AdminPasswordStatus' = if ($system.AdminPasswordStatus -eq 1) {"Disabled"}
                            elseif ($system.AdminPasswordStatus -eq 2) {"Enabled" }
                            elseif ($system.AdminPasswordStatus -eq 3) {"NA"}
                            elseif ($system.AdminPasswordStatus -eq 4) {"Unkown"};
                        'SerialNumber' = $bois.SerialNumber;
                        'Version' = $os.Version;
                        'ServicePackMajorVersion' = $os.ServicePackMajorVersion;
                    }
                write-verbose "Done"
                $obj = New-Object -TypeName PsObject -Property $props 
                $obj.PSObject.TypeNames.Insert(0, 'MOL.ComputerSystemInfo')
                write-output $obj 
            }
        }

    }
    
    end {
    }
}

#13.6.2 LAB - B Page 142, learn powershell toolmaking in a month of lunches

function Get-MOLDriveSpace {
    <#
    .SYNOPSIS
        Retrieve Basic local Volume information for one or more local or remote Computers. 
    .DESCRIPTION
        Using Windows Management Instrumentation (WMI) queries one or more local or remote Computers for  basic local Volume information.
        Get-DriveSpace queries win32_volume class for DriveLetter, FreeSpace, and Capacity retured in GBs.
        It then returns one Powershell object with all the results for each Volume on each computer dictated with the -Computername parameter.
    .PARAMETER ComputerName
        One or more computer names or IP addresses.
    .PARAMETER LogErrors
        Specifies if Errors are logged to a file, by defalt loggs are saved to C:\Errors.txt.
    .PARAMETER ErrorLog 
        specifies a file which errors are written to.
    
    .EXAMPLE
        PS C:\> Get-MOLDriveSpace -Computername 'localhost'
        Returns the Volume information for a single computer

    .EXAMPLE
        PS C:\> Get-Content Computerlist.txt |  Get-MOLDriveSpace
        This example shows how to pipe in Comtpuer names to get Volume information for multiple computer with a text file

    .EXAMPLE
        PS C:\> Get-MOLDriveSpace -Computername '192.168.1.3', 'Computer1'
        This example shows how to get Volume information for multiple computer with hostname and IP address
    .EXAMPLE
        PS C:\> Get-MOLDriveSpace -Computername 'localhost' -LogErrors -Errorlog log.txt
        Returns the volume information for a single computer, and returns any errors to a log file.
    .INPUTS
        System.Management.Automation.PSObject
        You can pipe objects in to -Comptuername parameter
    .OUTPUTS
        MOL.DiskInfo
        Get-DriveSpace  returns the objects for each Comptuer specified with the -Comptuername parameter
    .NOTES
        LAB B, from 'learn powershell toolmaking in a month of lunches'
    #>
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline=$True, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ComputerName,

        [string] $ErrorLog = 'C:\Errors.txt',
        [switch] $LogErrors
    )
    
    begin {

    }
    
    process {
        foreach ($computer in $Computername) {
            Try {
                $ok = $True
                $volume = Get-WmiObject -ComputerName $computer -Class win32_volume -ErrorAction Stop | Where-Object -Property drivetype -eq 3

            }
            catch {
                $ok = $false
                Write-Error "Get-MOLDriveSpace Has Failed: $computer Could not be reached."
                if ($LogErrors){
                    "$computer Has failed." | Out-File $Errorlog -Append
                    Write-Error "Error Has been logged to $ErrorLog"
                }

            }
            if ($ok){
            foreach ($drive in $volume){
                        Write-Verbose "Getting $drive on $computer"
                        $info = @{

                            'Drive' = $drive.DriveLetter;
                            'ComputerName' = $computer;
                            'FreeSpace(GB)' = ($drive.freespace / 1gb);
                            'Size(GB)' = ($drive.Capacity / 1gb)
                        }
                        $obj = New-Object -TypeName PSObject -Property $info
                        $obj.PSObject.TypeNames.Insert(0, 'MOL.DiskInfo')
                        write-output $obj
                    }
               } 
        }
        Write-Verbose "All Done"


    }
    
    end {
    }
}





#13.6.2, LAB - C Page 142, learn powershell toolmaking in a month of lunches


function Get-MOLProces {
    <#
    .SYNOPSIS
        Retrieve a list of  running processes  for one or more local or remote Computers. 
    .DESCRIPTION
        MOLProces gets all of the processes on one or more remote or local computers. MOLProces returns one Powershell object with ProcessName, VirtualMemorySize, PeakPagedMemorySize, file usage
        for each  Process on each computer dictated with the -Computername parameter.
    .PARAMETER ComputerName
        One or more computer names or IP addresses.
    .PARAMETER LogErrors
        Specifies if Errors are logged to a file, by defalt loggs are saved to C:\Errors.txt.
    .PARAMETER ErrorLog 
        specifies a file which errors are written to.
    
    .EXAMPLE
        PS C:\> Get-MOLProces -Computername 'localhost'
        Returns the running processes for a single computer

    .EXAMPLE
        PS C:\> Get-Content Computerlist.txt |  Get-MOLProces
        This example shows how to pipe in Comtpuer names to get running processes for multiple computer with a text file

    .EXAMPLE
        PS C:\> Get-MOLProces -Computername '192.168.1.3', 'Computer1'
        This example shows how to get running processes for multiple computer with hostname and IP address
    .EXAMPLE
        PS C:\> Get-MOLProces -Computername 'localhost' -LogErrors -Errorlog log.txt
        Returns the running processes for a single computer, and returns any errors to a log file.
    .INPUTS
        System.Management.Automation.PSObject
        You can pipe objects in to -Comptuername parameter
    .OUTPUTS
        MOL.ServiceProcessInfo
        Get-MOLProces  returns the objects for each Comptuer specified with the -Comptuername parameter
    .NOTES
        LAB C, from 'learn powershell toolmaking in a month of lunches'
    #>
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline=$True, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Computername,
        [string] $ErrorLog = "C:\Errors.txt",
        [switch] $LogErrors
    )
    
    begin {

    }
    
    process {
        foreach ($computer in $Computername){
            Write-Verbose "Getting Process list"
            try {
                $ok = $True
                $prosses = Get-Process -ComputerName $computer -ErrorAction stop
            }
            catch {
                $ok = $false
                Write-Error "Get-MOLProces Has Failed: $computer Could not be reached."
                if ($LogErrors){
                    Write-Error "Get-MOLProces Has Failed: $computer Error Log Save to $Errorlog"
                    "Get-MOLProces Has Failed: $computer Could not be reached." | Out-File $Errorlog -Append
                    $_ | Out-File $Errorlog -Append
                }
            }
                if ($ok){
                    ForEach ($pros in $prosses){
                        Write-Verbose "Queriering $pros on $computer"
                        $output = @{
                            'ProcessName' = $pros.ProcessName;
                            'VMSize' = $pros.VirtualMemorySize64;
                            'PeakPagedMemorySize' = $pros.VirtualMemorySize64;
                            'FileUsage' = $pros.PeakPagedMemorySize64;
                            'Thread' = $pros.threads
                            'ComptuerName' = $computer
                        }
                        $obj = New-Object -TypeName PSObject -Property $output
                        $obj.PSObject.TypeNames.Insert(0, "MOL.ServiceProcessInfo")
                        Write-Output $obj
                    }
            }
        }
        Write-Verbose "All Done"


    }
    
    end {
    }
}


#Chapter 15 Page 157, learn powershell toolmaking in a month of lunches




function Get-RemoteSmbShare {

    <#
    .SYNOPSIS
        Get-RemoteSmbShare queries one or more computers for SMB shares information.

    .DESCRIPTION
        Get-RemoteSmbShare uses PSRemoting to queries one or more computers for SMB shares information.

    .PARAMETER ComputerName
        One or more computer names or IP addresses.

    .PARAMETER Credential 
        Enable the prompting  credentials for PSRemoting

    .PARAMETER ErrorLog 
        specifies a file which errors are written to.

    .PARAMETER LogErrors
        Specifies if Errors are logged to a file, by defalt loggs are saved to C:\Errors.txt.

    .EXAMPLE
        PS C:\> Get-RemoteSmbShare  -Computername 'localhost'
        Returns the information for a single computer

    .EXAMPLE
        PS C:\> Get-Content Computerlist.txt |  Get-RemoteSmbShare 
        This example shows how to pipe in Comtpuer names to get information for multiple computer with a text file

    .EXAMPLE
        PS C:\> Get-RemoteSmbShare  -Computername '192.168.1.3', 'Computer1'
        This example shows how to get information for multiple computer with hostname and IP address

    .EXAMPLE
        PS C:\> Get-RemoteSmbShare  -Computername '192.168.1.4' -Credential
        Returns the information for a single computer, and will prompted you for your Credentials.

    .EXAMPLE
        PS C:\> Get-RemoteSmbShare -Computername '192.168.1.4' -LogErrors -Errorlog log.txt
        Returns the information for a single computer, and returns any errors to a log file.

    .INPUTS
        Inputs (if any)

    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>

    [CmdletBinding()]
    param (
        [parameter (ValueFromPipeline=$true, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateCount(1,5)]
        [alias("HostName")]
        
        [string[]] $ComputerName,
        [String] $ErrorLog =  'C:\Errors.txt',
        [switch] $LogErrors,
        [switch] $Credential

    )
    
    begin {
    }
    
    process {
        Foreach ($Computer in $ComputerName){
            Try{
                $ok = $true
                if ($Credential){
                    $Credentials = Get-Credential
                    Write-Verbose "Try $Computer"
                    $SMB = Invoke-Command -ComputerName $Computer -Credential $Credentials -ScriptBlock {Get-SmbShare} -ErrorAction Stop
                }else {
                    Write-Verbose "Try $Computer"
                    $SMB = Invoke-Command -ComputerName $Computer -ScriptBlock {Get-SmbShare} -ErrorAction Stop
                }
            }Catch{
                Write-Error "Get-RemoteSmbShare Has Failed: $computer Could not be reached."
                $ok = $false
                if ($LogErrors){
                    "$Computer Has failed." | Out-File $Errorlog -Append
                    Write-Error "Error Has been logged to $Errorlog"

                }
            }
            if ($ok){
                foreach ($share in $SMB){
                    Write-Verbose 'Compiling Data.'
                    $output = @{
                        'ComputerName' = $Computer;
                        'ShareName'  = $share.Name;
                        'Description' = $share.Description;
                        'Path' = $share.Path       
                    } 
                Write-Verbose 'All done compiling data.'
                $obj = New-Object -TypeName PSObject -Property $output
                Write-Output $obj 
                }
            }
        }
    }
    
    end {
    }
}




function sleep-computer {
    [CmdletBinding()]
    param (
        [parameter (Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $time,
        [switch] $Minutes,
        [switch] $Hours
        
    )
    
    begin {
       
    if ($Minutes) {
        $FinalTime = $time * 60
        $printout = "$time Minutes"
    }elseif ($Hours) {
        $FinalTime = $time * 3600  
        $printout = "$time Hours"     
    }else{
        $FinalTime = $time
        $printout = "$time Seconds"   
    }


    
    Write-Output "Computer will be put to sleep in, $printout"
    start-sleep -Seconds $FinalTime
    Write-verboes -ShuttingDown


    Add-Type -Assembly System.Windows.Forms
    [System.Windows.Forms.Application]::SetSuspendState("Suspend", $false, $true)
    }
    
    process {
    }
    
    end {
    }
}






#Define some aliases for the functions
New-Alias -Name grs -Value Get-RemoteSmbShare
New-Alias -Name gcd -Value Get-MOLinfo
New-Alias -Name gvi -Value Get-MOLDriveSpace
New-Alias -Name gsi -Value Get-MOLProces

#Export the functions and aliases
Export-ModuleMember -Function * -Alias *