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

        .PARAMETER Name
        This will be the name of the image once it's completed.

        .PARAMETER SysprepFile
        This is an optional parameter. This will be the location and name of the answer file during sysprep; otherwise, it's sysprepped without an answer file. 

        .PARAMETER Arch
        This is an optional parameter. The name of the folder with the drivers needed to install to the image; otherwise, driver installation is skipped.
        
    #>

    param(
        [Parameter(Mandatory = $true)][string]$VMName,
        [Parameter(Mandatory = $true)][string]$ConfigFile,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$SysprepFile,
        [string]$Arch
    )

    function revertcheckpoint {
        Get-VMSnapshot -VMName $VMName | Where-Object -Property "Name" -eq "Final" | Remove-VMSnapshot

        Get-VMSnapshot -VMName $VMName | Where-Object -Property "Name" -eq "Base Start" | Restore-VMSnapshot -Confirm:$false
    }

    function copyCoreFiles {
        if ($Arch) {
            Copy-Item -ToSession $vmSession -Path ".\files\Drivers\$($Arch)" -Destination "C:\Users\Administrator\Desktop\Drivers" -Recurse
        }

        if (Get-ChildItem -Path ".\PSWindowsUpdate") {
            Copy-Item -ToSession $vmSession -Path ".\PSWindowsUpdate" -Destination "C:\Users\Administrator\Desktop\PSWindowsUpdate" -Recurse
        }

        Copy-Item -ToSession $vmSession -Path $SysprepFile -Destination "C:\answer.xml"
    }

    function installDrivers {
        Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock { 

            foreach ($file in (Get-ChildItem -Path "C:\Users\Administrator\Desktop\Drivers" -Depth 1 | Where-Object -Property "Name" -like "*.inf" )) {
                pnputil /add-driver $file.FullName 
            }

        }
    }

    function runConfigCommands {

        . ".\Images\$($ConfigFile).ps1"

    }

    function runWindowsUpdate {

        Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock { cd "C:\Users\Administrator\Desktop\PSWindowsUpdate\"; Import-Module PSWindowsUpdate ; Get-WUInstall -AcceptAll Software -Verbose -IgnoreReboot }

    }

    function sysprepVM {
        if ($SysprepFile) {
            Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock { 
                New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Sysprep" -PropertyType "ExpandString" -Value "cmd.exe /C taskkill /IM sysprep.exe && timeout /t 5 && ""C:\Windows\system32\sysprep\sysprep.exe"" /generalize /oobe /shutdown /unattend:C:\answer.xml"
                Restart-Computer -Force
            }
        }
        else {
            Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock { 
                New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Sysprep" -PropertyType "ExpandString" -Value "cmd.exe /C taskkill /IM sysprep.exe && timeout /t 5 && ""C:\Windows\system32\sysprep\sysprep.exe"" /generalize /oobe /shutdown"
                Restart-Computer -Force
            }
        }

    }

    function createWIMFile {

        $vmLocation = Get-VM -Name $VMName | Select-Object -ExpandProperty "Path"

        $imageLocation = Get-ChildItem -Path "$($vmLocation)\Virtual Hard Disks\" | Sort-Object -Property "LastWriteTime" -Descending | Select-Object -First 1

        $mountImage = Mount-DiskImage -ImagePath $imageLocation.FullName -Access ReadOnly -StorageType VHDX -PassThru

        $driveLetter = (Get-Disk | Where-Object -Property "Location" -eq $imageLocation.FullName | Get-Partition | Sort-Object -Property "Size" -Descending | Select-Object -First 1).DriveLetter

        $driveLetter += ":\"

        New-WindowsImage -CapturePath $driveLetter -ImagePath ".\output\$($ImageName).wim" -CompressionType Maximum -Name $ConfigFile -CheckIntegrity -Setbootable -Verify -Verbose

        Dismount-DiskImage -ImagePath $imageLocation.FullName
    }
    
    . ".\SoftwareRepo.ps1"

    $creds = New-Object System.Management.Automation.PSCredential("Administrator", (New-Object System.Security.SecureString))

    revertcheckpoint
    Start-VM -Name $VMName
    Start-Sleep -Seconds 120
    $vmSession = New-PSSession -VMName "Win10" -Credential $creds
    Invoke-Command -VMName $vmName -Credential $creds -ScriptBlock { Set-ExecutionPolicy -ExecutionPolicy Bypass -Confirm:$false }
    copyCoreFiles

    if ($Arch) {
        installDrivers
    }

    runConfigCommands

    if (Get-ChildItem -Path ".\PSWindowsUpdate") {
        runWindowsUpdate
    }

    sysprepVM

    while (!((Get-VM -Name $VMName).State -eq "Off") {
        Start-Sleep -Seconds 5
    }

    Checkpoint-VM -Name $VMName -SnapshotName "Final"

    createWIMFile
}