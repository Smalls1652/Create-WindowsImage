## Getting driver packages with pnputil

This is usually how I get drivers for a specific architecures:

1. Install Windows 10 onto the source machine.
2. Install all drivers needed from Windows Update and/or the manufacturer's support page.
3. Run the following command (Replacing archname with the name you want to designate the architecture as):

`pnputil /export-driver * c:\archname`

4. Copy the "C:\archname" folder to a flash drive or network share.
5. Move/copy the folder (Not the files, the folder itself) to the .\files\Drivers directory in your environment.