@{
    RootModule        = 'Borg.psm1'
    ModuleVersion     = '0.2.13'
    GUID              = 'f23e3f2e-a121-4c62-8913-ef4b1c946bcc'
    Author            = 'Andi Oliver Ion'
    CompanyName       = ''
    Copyright         = '(c) Andi Oliver Ion. All rights reserved.'
    Description       = 'BORG — Backup Orchestrator for Reliable Groundwork. A modular PowerShell toolkit for automating SQL Server Docker container workflows, backup and restore operations, and local dev environment setup. GitHub: https://github.com/AndiOliverIon/borg'
    PowerShellVersion = '5.1'
    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = @('borg')
    PrivateData       = @{
        PSData = @{
            Tags       = @(
                'borg', 'automation', 'cli', 'powershell', 'psmodule',
                'docker', 'container', 'sql', 'database', 'backup', 'restore',
                'jira', 'gdrive', 'devops', 'tools', 'productivity'
            )
            LicenseUri = 'https://github.com/AndiOliverIon/borg/blob/main/LICENSE'
            ProjectUri = 'https://github.com/AndiOliverIon/borg'
        }
    }
}