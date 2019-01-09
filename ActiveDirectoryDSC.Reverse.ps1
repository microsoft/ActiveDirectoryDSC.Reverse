<#PSScriptInfo

.VERSION 1.0.0.0

.GUID b9050077-a667-4db6-a115-65999ebc4797

.AUTHOR Microsoft Corporation

.COMPANYNAME Microsoft

.ICONURI https://github.com/Microsoft/ActiveDirectoryDSC.Reverse/raw/master/Images/ActiveDirectoryDSC.Reverse.png

.EXTERNALMODULEDEPENDENCIES

.TAGS Technology,ReverseDSC

.RELEASENOTES

* Initial Release;
#>

#Requires -Modules @{ModuleName="ReverseDSC";ModuleVersion="1.9.3.0"},@{ModuleName="xActiveDirectory";ModuleVersion="2.22.0.0"}

<# 

.DESCRIPTION 
 Extracts the DSC Configuration of an existing ActiveDirectoryDSC environment, allowing you to analyze it or to replicate it.

#> 

param()

<## Script Settings #>
$VerbosePreference = "SilentlyContinue"

<## Scripts Variables #>
$Script:dscConfigContent = "" # Core Variable that will contain the content of your DSC output script. Leave empty;
$DSCSource = "C:\Program Files\WindowsPowerShell\Modules\xActiveDirectory\" # Path to the root folder of your technology's DSC Module (e.g. C:\Program Files\WindowsPowerShell\SharePointDSC);
$DSCVersion = "2.22.0.0" # Version of the DSC module for the technology (e.g. 1.0.0.0);
$Script:DSCPath = $DSCSource + $DSCVersion # Dynamic path to include the version number as a folder;
$Script:configName = "ADConfig" # Name of the output configuration. This will be the name that follows the Configuration keyword in the output script;
$Script:ADUsers = @()

<# Retrieves Information about the current script from the PSScriptInfo section above #>
try {
    $currentScript = Test-ScriptFileInfo $SCRIPT:MyInvocation.MyCommand.Path
    $Script:version = $currentScript.Version.ToString()
}
catch {
    $Script:version = "N/A"
}

<## This is the main function for this script. It acts as a call dispatcher, calling the various functions required in the proper order to 
    get the full picture of the environment; #>
function Orchestrator
{        
    <# Import the ReverseDSC Core Engine #>
    $ReverseDSCModule = "ReverseDSC.Core.psm1"
    $module = (Join-Path -Path $PSScriptRoot -ChildPath $ReverseDSCModule -Resolve -ErrorAction SilentlyContinue)
    if($module -eq $null)
    {
        $module = "ReverseDSC"
    }    
    Import-Module -Name $module -Force
    
    
    $Script:dscConfigContent += "<# Generated with ActiveDirectoryDSC.Reverse " + $script:version + " #>`r`n"   
    $Script:dscConfigContent += "Configuration $Script:configName`r`n"
    $Script:dscConfigContent += "{`r`n"

    Write-Host "Configuring Dependencies..." -BackgroundColor DarkGreen -ForegroundColor White
    Set-Imports

    $Script:dscConfigContent += "    Node $env:COMPUTERNAME`r`n"
    $Script:dscConfigContent += "    {`r`n"
    
    Write-Host "Scanning ADUser..." -BackgroundColor DarkGreen -ForegroundColor White
    Read-ADUser

    Write-Host "Configuring Local Configuration Manager (LCM)..." -BackgroundColor DarkGreen -ForegroundColor White
    Set-LCM

    $Script:dscConfigContent += "`r`n    }`r`n"           
    $Script:dscConfigContent += "}`r`n"

    Write-Host "Setting Configuration Data..." -BackgroundColor DarkGreen -ForegroundColor White
    Set-ConfigurationData

    $Script:dscConfigContent += "$Script:configName -ConfigurationData `$ConfigData"
}

#region Reverse Functions
function Read-ADUser()
{
    $Script:ADUsers = Get-ADUser -Filter *

    $module = Resolve-Path ($Script:DSCPath + "\DSCResources\MSFT_xADUser\MSFT_xADUser.psm1")
    Import-Module $module
    $params = @{
        DomainName = $null
        UserName = $null
    }

    $total = $Script:ADUsers.Length
    $index = 1
    foreach ($ADUser in $Script:ADUsers)
    {
        Write-Host "Scanning ADUser $($ADUser) [$($index)/$($total)]"

        <# Setting Primary Keys #>
        if ($ADUser.SAMAccountName -ne $null)
        {
            $params.DomainName = Get-DomainNameFromCN -CN $ADUSer.DistinguishedName
            $params.UserName = $ADUser.SamAccountName
            $results = Get-TargetResource @params

            $Script:dscConfigContent += "        xADUser " + [System.Guid]::NewGuid().toString() + "`r`n"
            $Script:dscConfigContent += "        {`r`n"
            $Script:dscConfigContent += Get-DSCBlock -Params $results -ModulePath $module
            $Script:dscConfigContent += "        }`r`n"
        }
        $index++
    }
}
#endregion

#region Helpers Functions
function Get-DomainNameFromCN
{
    param(
        [string] $CN
    )

    $parts = $CN.Split(',')
    $domainName = $null
    foreach ($part in $parts)
    {
        if ($part.IndexOf("DC=") -eq 0)
        {
            $domainName += $part.SubString(3, $part.Length - 3) + "."
        }
    }
    $domainName = $domainName.Remove(1, $domainName.Length -1)
    return $domainName
}
#endregion

# Sets the DSC Configuration Data for the current server;
function Set-ConfigurationData
{
    $Script:dscConfigContent += "`$ConfigData = @{`r`n"
    $Script:dscConfigContent += "    AllNodes = @(`r`n"    

    $tempConfigDataContent += "    @{`r`n"
    $tempConfigDataContent += "        NodeName = `"$env:COMPUTERNAME`";`r`n"
    $tempConfigDataContent += "        PSDscAllowPlainTextPassword = `$true;`r`n"
    $tempConfigDataContent += "        PSDscAllowDomainUser = `$true;`r`n"
    $tempConfigDataContent += "    }`r`n"    

    $Script:dscConfigContent += $tempConfigDataContent
    $Script:dscConfigContent += ")}`r`n"
}

<## This function ensures all required DSC Modules are properly loaded into the current PowerShell session. #>
function Set-Imports
{
    $Script:dscConfigContent += "    Import-DscResource -ModuleName PSDesiredStateConfiguration`r`n"
    $Script:dscConfigContent += "    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion `"" + $DSCVersion  + "`"`r`n"
}

<## This function sets the settings for the Local Configuration Manager (LCM) component on the server we will be configuring using our resulting DSC Configuration script. The LCM component is the one responsible for orchestrating all DSC configuration related activities and processes on a server. This method specifies settings telling the LCM to not hesitate rebooting the server we are configurating automatically if it requires a reboot (i.e. During the SharePoint Prerequisites installation). Setting this value helps reduce the amount of manual interaction that is required to automate the configuration of our SharePoint farm using our resulting DSC Configuration script. #>
function Set-LCM
{
    $Script:dscConfigContent += "        LocalConfigurationManager"  + "`r`n"
    $Script:dscConfigContent += "        {`r`n"
    $Script:dscConfigContent += "            RebootNodeIfNeeded = `$True`r`n"
    $Script:dscConfigContent += "        }`r`n"
}


<# This function is responsible for saving the output file onto disk. #>
function Get-ReverseDSC()
{
    <# Check to make sure the AD Role is assigned to the current server #>
    try
    {
        Import-Module "ServerManager" -ErrorAction SilentlyContinue
        $addsFeature = Get-WindowsFeature "AD-Domain-Services"
        if ($addsFeature.InstallState -ne "Installed")
        {
            throw "ActiveDirectoryDSC.Reverse needs to be run from a server that has the Active Directory Domain Services Roles installed."
        }
    }
    catch
    {
        throw "ActiveDirectoryDSC.Reverse needs to be run from a server that has the Active Directory Domain Services Roles installed."
    }

    <## Call into our main function that is responsible for extracting all the information about our environment; #>
    Orchestrator

    <## Prompts the user to specify the FOLDER path where the resulting PowerShell DSC Configuration Script will be saved. #>
    $fileName = "ActiveDirectoryDSC.DSC.ps1"
    $OutputDSCPath = Read-Host "Please enter the full path of the output folder for DSC Configuration (will be created as necessary)"
    
    <## Ensures the specified output folder path actually exists; if not, tries to create it and throws an exception if we can't. ##>
    while (!(Test-Path -Path $OutputDSCPath -PathType Container -ErrorAction SilentlyContinue))
    {
        try
        {
            Write-Output "Directory `"$OutputDSCPath`" doesn't exist; creating..."
            New-Item -Path $OutputDSCPath -ItemType Directory | Out-Null
            if ($?) {break}
        }
        catch
        {
            Write-Warning "$($_.Exception.Message)"
            Write-Warning "Could not create folder $OutputDSCPath!"
        }
        $OutputDSCPath = Read-Host "Please Enter Output Folder for DSC Configuration (Will be Created as Necessary)"
    }
    <## Ensures the path we specify ends with a Slash, in order to make sure the resulting file path is properly structured. #>
    if(!$OutputDSCPath.EndsWith("\") -and !$OutputDSCPath.EndsWith("/"))
    {
        $OutputDSCPath += "\"
    }

    <## Save the content of the resulting DSC Configuration file into a file at the specified path. #>
    $outputDSCFile = $OutputDSCPath + $fileName
    $Script:dscConfigContent | Out-File $outputDSCFile
    Write-Output "Done."
    <## Wait a couple of seconds, then open our $outputDSCPath in Windows Explorer so we can review the glorious output. ##>
    Start-Sleep 2
    Invoke-Item -Path $OutputDSCPath
}

Get-ReverseDSC