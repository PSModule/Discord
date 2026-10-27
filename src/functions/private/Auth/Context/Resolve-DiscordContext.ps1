function Resolve-DiscordContext {
    <#
        .SYNOPSIS
        Resolve a saved name or typed context.

        .DESCRIPTION
        Use the selected default when no context is supplied. Resolution does not refresh tokens.

        .EXAMPLE
        Resolve-DiscordContext -Context 'automation'

        .OUTPUTS
        DiscordContext

        The selected connection.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Context/Get-DiscordContext/
    #>
    [OutputType([DiscordContext])]
    [CmdletBinding()]
    param(
        # A saved name or a DiscordContext object.
        [Parameter()]
        [object] $Context
    )

    if ($null -eq $Context) {
        $resolved = Get-DiscordContext
    } elseif ($Context -is [string]) {
        $resolved = Get-DiscordContext -Context $Context
    } elseif ($Context -is [DiscordContext]) {
        $resolved = $Context
    } else {
        throw [System.ArgumentException]::new('Context must be a saved name or a DiscordContext object.')
    }

    if ($null -eq $resolved) {
        throw [System.InvalidOperationException]::new('No Discord context is selected. Run Connect-Discord or Switch-DiscordContext.')
    }
    $resolved
}
