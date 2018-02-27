function New-WindowsBuild {
    <#
        .SYNOPSIS
        Automate the building of Windows images through Hyper-V with a WIM file as the output.

        .DESCRIPTION
        Automate the building of Windows images through Hyper-V with a WIM file as the output. This process is useful for creating specific images for an architecture or deployment location (Labs, departments, etc.).

        .PARAMETER VMName
        The name of the VM to interact with.

        .PARAMETER ConfigFile
        The name of the ConfigFile in the Images directory. This is to determine what's needed to be installed or done to a specific image.

        .PARAMETER ImageName
        This will be the name of the image once it's completed.

        .PARAMETER SysprepFile
        This is an optional parameter. This will be the location and name of the answer file during sysprep; otherwise, it's sysprepped without an answer file. 

        .PARAMETER Arch
        This is an optional parameter. The name of the folder with the drivers needed to install to the image; otherwise, driver installation is skipped.
        
    #>

    param(
        [Parameter(Mandatory = $true)][string]$VMName,
        [Parameter(Mandatory = $true)][string]$ConfigFile,
        [Parameter(Mandatory = $true)][string]$ImageName,
        [string]$SysprepFile,
        [string]$Arch
    )

    function revertcheckpoint {
        #This is to clear the checkpoint from a previous run and to restore the base checkpoint.

        Get-VMSnapshot -VMName $VMName | Where-Object -Property "Name" -eq "Final" | Remove-VMSnapshot

        Get-VMSnapshot -VMName $VMName | Where-Object -Property "Name" -eq "Base Start" | Restore-VMSnapshot -Confirm:$false
    }

    function copyCoreFiles {

        #Copying core files (If provided) for drivers, PSWindowsUpdate, and the sysprep answer file.
        #The majority of files are copied to the Administrator's desktop because they're deleted when sysprepped.

        if ($Arch) {
            Copy-Item -ToSession $vmSession -Path ".\files\Drivers\$($Arch)" -Destination "C:\Users\Administrator\Desktop\Drivers" -Recurse
        }

        if (Get-ChildItem -Path ".\PSWindowsUpdate") {
            Copy-Item -ToSession $vmSession -Path ".\PSWindowsUpdate" -Destination "C:\Users\Administrator\Desktop\PSWindowsUpdate" -Recurse
        }

        if ($SysprepFile) {
            Copy-Item -ToSession $vmSession -Path $SysprepFile -Destination "C:\answer.xml"
        }
    }

    function installDrivers {

        #Installs drivers if they were copied over.

        Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock { 

            foreach ($file in (Get-ChildItem -Path "C:\Users\Administrator\Desktop\Drivers" -Depth 1 | Where-Object -Property "Name" -like "*.inf" )) {
                pnputil /add-driver $file.FullName 
            }

        }
    }

    function runConfigCommands {

        #If a config file was provided, then it runs through the config file's commands.

        . ".\Images\$($ConfigFile).ps1"

    }

    function runWindowsUpdate {

        #If PSWindowsUpdate is provided, then it's ran. It does one pass-through of Windows Update and does not auto reboot.

        Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock { cd "C:\Users\Administrator\Desktop\PSWindowsUpdate\"; Import-Module ".\PSWindowsUpdate.psm1" ; Get-WUInstall -AcceptAll Software -Verbose -IgnoreReboot }

    }

    function sysprepVM {

        #If an answer file was provided, it uses that for the generalization process; otherwise, it's just a generic generalization. Sysprep is not done immediately as it allows any updates applied to be installed during a reboot.
        #The step disables remote console access for accounts with blank passwords. This was enabled in the environment, but is not recommended for a production image.
        #This step also disables the local administrator account.

        if ($SysprepFile) {
            Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock { 
                New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -PropertyType "DWORD" -Value "1" -Force | Out-Null
                New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Sysprep" -PropertyType "ExpandString" -Value "cmd.exe /C taskkill /IM sysprep.exe && timeout /t 5 && ""C:\Windows\system32\sysprep\sysprep.exe"" /generalize /oobe /shutdown /unattend:C:\answer.xml"
                Disable-LocalUser -Name "Administrator"
                Restart-Computer -Force
            }
        }
        else {
            Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock { 
                New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -PropertyType "DWORD" -Value "1" -Force | Out-Null
                New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Sysprep" -PropertyType "ExpandString" -Value "cmd.exe /C taskkill /IM sysprep.exe && timeout /t 5 && ""C:\Windows\system32\sysprep\sysprep.exe"" /generalize /oobe /shutdown"
                Disable-LocalUser -Name "Administrator"
                Restart-Computer -Force
            }
        }

    }

    function createWIMFile {

        #This step finds the path where the VM is stored at and mounts it to your computer as read-only. From there it gathers the drive letter assigned to it and creates a WIM image from it. Once finished, it dismounts the image.

        $vmLocation = Get-VM -Name $VMName | Select-Object -ExpandProperty "Path"

        $imageLocation = Get-ChildItem -Path "$($vmLocation)\Virtual Hard Disks\" | Sort-Object -Property "LastWriteTime" -Descending | Select-Object -First 1

        $mountImage = Mount-DiskImage -ImagePath $imageLocation.FullName -Access ReadOnly -StorageType VHDX -PassThru

        $driveLetter = (Get-Disk | Where-Object -Property "Location" -eq $imageLocation.FullName | Get-Partition | Sort-Object -Property "Size" -Descending | Select-Object -First 1).DriveLetter

        $driveLetter += ":\"

        New-WindowsImage -CapturePath $driveLetter -ImagePath ".\output\$($ImageName).wim" -CompressionType Maximum -Name $ImageName -CheckIntegrity -Setbootable -Verify -Verbose

        Dismount-DiskImage -ImagePath $imageLocation.FullName
    }
    
    . ".\SoftwareRepo.ps1" #This is to load in the repo, which houses the functions that can be called in a config file.

    $creds = New-Object System.Management.Automation.PSCredential("Administrator", (New-Object System.Security.SecureString)) #Creates a PSCredential object for the local Administrator account.

    revertcheckpoint
    Start-VM -Name $VMName
    Start-Sleep -Seconds 120 #Currently the script doesn't have any loop to detect if the VM is on.

    $vmSession = New-PSSession -VMName "Win10" -Credential $creds #Creating a PSSession to the VM for copying files and invoking commands to it.

    Invoke-Command -VMName $vmName -Credential $creds -ScriptBlock { Set-ExecutionPolicy -ExecutionPolicy Bypass -Confirm:$false } #Execution Policy is set to Bypass to allow any custom script to be loaded without issue.

    copyCoreFiles

    if ($Arch) {
        installDrivers
    }

    runConfigCommands

    if (Get-ChildItem -Path ".\PSWindowsUpdate") {
        runWindowsUpdate
    }

    sysprepVM

    #This the logic to determine when the VM has finished sysprepping.
    while (!((Get-VM -Name $VMName).State -eq "Off")) {
        Start-Sleep -Seconds 5
    }

    Checkpoint-VM -Name $VMName -SnapshotName "Final" #Creating the final checkpoint to create the WIM file from.

    createWIMFile
}