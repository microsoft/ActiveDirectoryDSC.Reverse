# ReverseDSC Orchestrator for Active Directory
This module allows you to extract the current configuration Active Directory as a PowerShell Desired State Configuration (DSC) .ps1 script along with its associated .psd1 Configuration Data File. With these files you can then recreate an exact copy of AD environment.

# How to Use
The ReverseDSC Orchestrator for Active Directory needs to be installed on a server that has the AD Domain Services Role.

## Install with internet access
If your machine has internet connectivity, it can be automatically installed using PowerShell 5 and above. This will automatically install the orchestrator and all the modules it depends on. The command to run is:

```PowerShell
Install-Script ActiveDirectoryDSC.Reverse
```

## Install without internet access
If the server doesn't have internet connectivity, then you will need to run the "Install-Script ActiveDirectoryDSC.Reverse" command from a computer that has PowerShell version 5 or greater and that had internet connectivity and copy the files manually over the server. Once the command has been run on the machine with internet connectivity, copy the following files to the exact same location on the server:
* C:\Program Files\WindowsPowerShell\Modules\xActiveDirectory  [Entire Folder]
* C:\Program Files\WindowsPowerShell\Modules\ReverseDSC     [Entire Folder]
* C:\Program Files\WindowsPowerShell\Scripts\ActiveDirectoryDSC.Reverse.ps1  [If folder doesn't exist on server, create it manually]

## Run
Once you have either run Install-Script ActiveDirectoryDSC.Reverse or have copied over the files, connect to the AD server using a Domain Admin account and open a new PowerShell console as an administrator on the server. Browse to the C:\Program Files\WindowsPowerShell\Scripts folder and execute the ActiveDirectoryDSC.Reverse.ps1 script. 

## Output
As an output, the Orchestrator script will produce a .ps1 file representing the configuration logic for your environment, and a .psd1 file that will be used as Configuration Data to compile the associated MOF file. If you are planning on using ReverseDSC to replicate your AD in another environment, you will need to modify the values in the .psd1 Configuration Data file before compiling your MOF files. Any errors encountered during the extraction will be included in a file named DSC.log inside the specified folder.
