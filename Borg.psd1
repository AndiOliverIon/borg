@{
    RootModule        = 'Borg.psm1'
    ModuleVersion     = '0.1.11'
    GUID              = 'f23e3f2e-a121-4c62-8913-ef4b1c946bcc'
    Author            = 'Andi Oliver Ion'
    CompanyName       = ''
    Copyright         = '(c) Andi Oliver Ion. All rights reserved.'
    Description       = 'Modular PowerShell CLI toolkit for automating local and Docker workflows. GitHub here: https://github.com/AndiOliverIon/borg'
    PowerShellVersion = '5.1'
    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = @('borg')
    PrivateData       = @{
        PSData = @{
            Tags       = @('automation', 'cli', 'docker', 'borg')
            LicenseUri = 'https://github.com/AndiOliverIon/borg/blob/main/LICENSE'
            ProjectUri = 'https://github.com/AndiOliverIon/borg'
        }
    }
}