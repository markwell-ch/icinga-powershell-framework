@{
    ModuleToProcess = 'icinga-powershell-framework.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'fcd7a805-a41b-49f9-afee-9d17a2b76d42'
    Author = 'Lord Hepipud'
    CompanyName = 'Icinga GmbH'
    Copyright = '(c) 2019 Icinga GmbH. All rights reserved.'
    Description = 'Icinga 2 Windows Agent Module, which allows to entirely monitor the Windows Host system.'
    PowerShellVersion = '4.0'
    FunctionsToExport = @( 'Use-Icinga', 'Import-IcingaLib', 'Publish-IcingaModuleManifests', 'Get-IcingaPluginDir', 'Get-IcingaCustomPluginDir', 'Get-IcingaCacheDir', 'Get-IcingaPowerShellConfigDir', 'Get-IcingaFrameworkRootPath', 'Get-IcingaPowerShellModuleFile' )
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @( 'icinga', 'icinga2', 'icinga 2', 'Icinga PowerShell Framework', 'Icinga PowerShell', 'Icinga for Windows', 'Icinga Windows')
            LicenseUri = 'https://github.com/Icinga/icinga-powershell-framework/blob/master/LICENSE'
            ProjectUri = 'https://github.com/Icinga/icinga-powershell-framework'
            ReleaseNotes = 'https://github.com/Icinga/icinga-powershell-framework/releases'
        };
        Version = 'v1.0.0-rc1';
    }
    HelpInfoURI = 'https://github.com/Icinga/icinga-powershell-framework'
}
