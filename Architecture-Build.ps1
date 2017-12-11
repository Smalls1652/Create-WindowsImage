$creds = New-Object System.Management.Automation.PSCredential("Administrator",(New-Object System.Security.SecureString))
$vmName = "Win10"

. "$env:USERPROFILE\Documents\ImageBuilding\SoftwareRepo.ps1"

$ArchImage = "" #Folder name for the drivers on the local machine.
$ImageName = "" #PS1 file that has the commands for what needs to be done on the specific image.

$deleteFiles = (Get-ChildItem -Path "D:\ISOCreation\install.wim"),(Get-ChildItem -Path "D:\ISOCreation\Split\"),(Get-ChildItem -Path "D:\ISOCreation\Win10\sources\" | Where-Object -Property "Name" -Like "*.swm")

foreach ($file in $deleteFiles)
{
    Remove-Item -Path $file.FullName -Force
}

Get-VMSnapshot -VMName "Win10" | Where-Object -Property "Name" -eq "Final" | Remove-VMSnapshot

Get-VMSnapshot -VMName "Win10" | Where-Object -Property "Name" -eq "Base Start" | Restore-VMSnapshot -Confirm:$false

Start-VM -Name $vmName

Start-Sleep -Seconds 120

$vmSession = New-PSSession -VMName "Win10" -Credential $creds

Copy-Item -ToSession $vmSession -Path "$env:USERPROFILE\Documents\ImageBuilding\files\Drivers\$ArchImage" -Destination "C:\Users\Administrator\Desktop\Drivers" -Recurse

Copy-Item -ToSession $vmSession -Path "$env:USERPROFILE\Desktop\win10_kms.xml" -Destination "C:\win10_kms.xml"

$vmHostName = Invoke-Command -VMName $vmName -Credential $creds -ScriptBlock { $env:COMPUTERNAME }

Invoke-Command -VMName $vmName -Credential $creds -ScriptBlock { 

    foreach ($file in (Get-ChildItem -Path "C:\Users\Administrator\Desktop\Drivers" -Depth 1 | Where-Object -Property "Name" -like "*.inf" ))
    {
        pnputil /add-driver $file.FullName 
    }

 }

. "$env:USERPROFILE\Documents\ImageBuilding\Images\$ImageName.ps1"

Invoke-Command -VMName $vmName -Credential $creds -ScriptBlock { Import-Module PSWindowsUpdate ; Get-WUInstall -AcceptAll Software -Verbose -IgnoreReboot }

Invoke-Command -VMName $vmName -Credential $creds -ScriptBlock { 

New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Sysprep" -PropertyType "ExpandString" -Value "cmd.exe /C taskkill /IM sysprep.exe && timeout /t 5 && ""C:\Windows\system32\sysprep\sysprep.exe"" /generalize /oobe /shutdown /unattend:C:\win10_kms.xml"

}

Start-Sleep -Seconds 60

while ((Get-VM -Name $vmName).State -eq "Running")
{
    Write-Output "Waiting..."
    Start-Sleep -Seconds 5
}

Write-Output "Done!"

Checkpoint-VM -Name $vmName -SnapshotName "Final"

$imageLocation = Get-ChildItem -Path "D:\HyperV\Win10\Virtual Hard Disks\" | Sort-Object -Property "LastWriteTime" -Descending | Select-Object -First 1

$mountImage = Mount-DiskImage -ImagePath $imageLocation.FullName -Access ReadOnly -StorageType VHDX -PassThru

$driveLetter = (Get-Disk | Where-Object -Property "Location" -eq $imageLocation.FullName | Get-Partition | Sort-Object -Property "Size" -Descending | Select-Object -First 1).DriveLetter

$driveLetter += ":\"

New-WindowsImage -CapturePath $driveLetter -ImagePath "D:\WIMFiles\PrecisionT1700_Employee_Base.wim" -CompressionType Maximum -Name "Nash_Win10_1703-ICERINK" -CheckIntegrity -Setbootable -Verify -Verbose

Dismount-DiskImage -ImagePath $imageLocation.FullName