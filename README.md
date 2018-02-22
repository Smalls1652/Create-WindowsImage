#Automate the building of images with New-WindowsImage.
The development of this script was because of the lack of funding for SCCM licensing and no WDS/MDT infrastructure. You should be able to utilize the WIM files generated from this to use in a WDS/MDT setup, but it has not been tested yet. I personally store the WIM files on a network share and utilize WinPE to deploy an image and then clone that drive, but that's a temporary setup until I can get WDS/MDT set up.

##Prereqs##

- A computer/server that supports virtualization. **(Pretty much any modern hardware will support it)**
- Hyper-V enabled. **(Please note that any other hypervisors will not work when Hyper-V is enabled)**
- Powershell 5.1 **(May potentially work on older and newer versions, but I've only tested it on Windows 10 with PS 5.1)**
 
##Recommended##

*These are not required, but recommended if you want to make things smoother.*

- PSWindowsUpdate (https://www.powershellgallery.com/packages/PSWindowsUpdate/1.5.2.2)
- Drivers for specific computer architectures. (I use pnputility to grab drivers from machines. See down below for more info.)

##Set up the environment##

**Note: This has been tested and built for Windows 10 deployments, but in theory it should work for 7/8 as well.**

1. Either git clone or extract the ZIP file of this repository. (If you want to rename the folder, you can. I personally call the root folder "ImageBuilding".)
2. **Optional** Move/copy any driver folders for a specific architecture to .\files\Drivers\ folder.
3. **Optional** Move/copy the PSWindowsUpdate folder to the root of your environment.
4. Create a Windows 10 VM in Hyper-V, install Windows 10 (Either Education, Enterprise, or Pro), and once Cortana starts talking press Shift + Ctrl + F3. It will reboot to Audit mode. **(If you plan on doing Windows Updates or software that requires a network connection to download, create an external switch in Hyper-V and assign it to the VM)**
5. Once it gets to the desktop (A sysprep window should be open when you get to the desktop), create a snapshot called "Base Start".
6. Either shut down the VM or leave it running.

###Software Repo and Config Files###

To automate the entire process, I'd suggest you create these files. Inside of *SoftwareRepo.ps1* and the *Base.ps1* files are generic examples and HowTos on how to build them out. Config files are necessary for the script to work at this time.

Always make sure that you update the *SoftwareRepo.ps1* file with any software you want to install. Make it so that each software install is it's own function.

The *Base.ps1* file is just an example, but it can be used. General guidelines for config files is to make a PS1 file, add in the functions you created in *SoftwareRepo.ps1* into the file, and name the file what the config is for. Config files will go into the .\Images\ folder.

This setup should help leverage a lot of modularity into what you want to build an image for. It's easy to customize and automate.

##Usage##

Once you're done building the environment, you can now start making images. Here's how to get it all ready:

1. Launch Powershell (As an Administrator).
2. Change your current directory to the root of your environment.
3. Run the following code (You may have to modify your execution policy):
`Import-Module .\New-WindowsImage.ps1`

From here, you will be able to run the *New-WindowsImage* command. If you need help with the parameters, type in `Get-Help -Full New-WindowsImage`.

Here are two examples of how to use it:

1. Create an image with no specific architecure in mind:
`New-WindowsImage -VMName "Win10" -ConfigFile "Base" -Name "MaintenanceImage"`

2. Create an image with a specific architecure and an answer file for sysprep:
`New-WindowsImage -VMName "Win10" -ConfigFile "Base" -Name "Employees" -Arch "Optiplex3040" -SysprepFile ".\win10.xml"`

##Getting driver packages with pnputil##

This is usually how I get drivers for a specific architecures:

1. Install Windows 10 onto the source machine.
2. Install all drivers needed from Windows Update and/or the manufacturer's support page.
3. Run the following command (Replacing archname with the name you want to designate the architecture as):
`pnputil /export-driver * c:\archname`
4. Copy the "C:\archname" folder to a flash drive or network share.
5. Move/copy the folder (Not the files, the folder itself) to the .\files\Drivers directory in your environment.

##Notes##

This is a growing script and I hope to just turn it into a full blown module at some point, but I will take any issues, suggestions, etc. I can get. Even if you think my documentation for installation and whatnot is bad, please let me know what I need to change or if something doesn't make sense. I will work with you and change it as best as I can. This went from being a thrown together script to automate my image building into a fully modularized setup that anyone could potentially use. It isn't perfect, but I hope it helps anybody out there.