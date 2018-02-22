<#

This is the Software Repo for what software needs to be copied and/or installed.

Important variables for commands to work:
$creds - This variable is created in the New-WindowsImage command. This is what's used to authenticate to the VM.
$VMName - This variable is defined from the VMName parameter you supply to the New-WindowsImage command. This is used in commands like Invoke-Command so those commands know what to connect to.
$VMSession - This variable is created in the New-WindowsImage command. This is used in commands like Copy-Item so those commands know what to connect to.

In order to build this Software Repo out to meet your needs, you need to learn and understand the basics of command line arguments and Start-Process. 
You will also need to supply the appropriate command line arguments for software installations, most importantly the arguments for silent installations.

Some entries in the repo will be a little complex. For example, I had to do multiple things for Visual Studio to be installed silently. Just remember this:
"Spend time automating by experimenting and perfecting the process to reduce time in the future."

There are two examples below that should help you build out your software repo file.

Note:
Software installations are not the only things you can do with this. You can create functions that apply registry changes or just to copy files.

#>

#Example for a software that doesn't need files copied over.
function NetFx {
    Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock { Add-WindowsCapability -Name "NetFx3~~~~" -Online }
}

#Example for a folder that needs to be copied over and to start an installation for.
function exampleCopy {
    #This is not a valid function, but it's the basis of what you would have to do.
    Copy-Item -ToSession $VMSession -Path ".\ExampleFolder\" -Destination "C:\Users\Administrator\Desktop\ExampleFolder\" -Recurse

    Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock { Start-Process -FilePath "C:\Users\Administrator\Desktop\ExampleFolder\setup.exe" -ArgumentList "/s" -Wait}    
}