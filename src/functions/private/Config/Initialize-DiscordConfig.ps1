#Requires -Modules @{ ModuleName = 'Context'; ModuleVersion = '8.1.3' }

function Initialize-DiscordConfig {
    <#
        .SYNOPSIS
        Load saved client settings on first use.

        .DESCRIPTION
        Use in-memory defaults when no settings exist. Reads never create a vault or save defaults.

        .EXAMPLE
        Initialize-DiscordConfig

        .OUTPUTS
        None

        Settings are cached in module scope.

        .LINK
        https://psmodule.io/Discord/Functions/Config/Get-DiscordConfig/
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param()

    if ($null -ne $script:Discord.Config) {
        return
    }

    $parameters = @{
        ID            = $script:Discord.DefaultConfig.ID
        Vault         = $script:Discord.ContextVault
        ErrorAction   = 'Stop'
        WarningAction = 'Stop'
        Verbose       = $false
        Debug         = $false
    }
    $stored = Get-Context @parameters
    if ($null -eq $stored) {
        $script:Discord.Config = [DiscordConfig]::new([pscustomobject] $script:Discord.DefaultConfig)
    } else {
        $script:Discord.Config = [DiscordConfig]::new([pscustomobject] $stored)
    }
}
