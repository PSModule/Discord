function Get-DiscordConfig {
    <#
        .SYNOPSIS
        Get the Discord client settings.

        .DESCRIPTION
        Return a copy of the saved settings or defaults without creating a vault.

        .EXAMPLE
        Get-DiscordConfig

        .INPUTS
        None

        You can't pipe objects to Get-DiscordConfig.

        .OUTPUTS
        DiscordConfig

        The default context name, retry settings, and HTTP timeout.

        .LINK
        https://psmodule.io/Discord/Functions/Config/Get-DiscordConfig/
    #>
    [OutputType([DiscordConfig])]
    [CmdletBinding()]
    param()

    Initialize-DiscordConfig
    [DiscordConfig]::new([pscustomobject] $script:Discord.Config)
}
