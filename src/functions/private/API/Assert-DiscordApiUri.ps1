function Assert-DiscordApiUri {
    <#
        .SYNOPSIS
        Validate a destination before attaching credentials.

        .DESCRIPTION
        Restrict the REST client to Discord's HTTPS v10 API, without user information or fragments.

        .EXAMPLE
        Assert-DiscordApiUri -Uri 'https://discord.com/api/v10/users/@me'

        .OUTPUTS
        None

        Unsafe destinations raise a terminating error.

        .LINK
        https://psmodule.io/Discord/Functions/API/Invoke-DiscordAPI/
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param(
        # The fully resolved destination.
        [Parameter(Mandatory)]
        [uri] $Uri
    )

    if (-not $Uri.IsAbsoluteUri -or $Uri.Scheme -cne 'https' -or
        $Uri.DnsSafeHost -ine 'discord.com' -or $Uri.Port -ne 443 -or
        $Uri.UserInfo -ne '' -or $Uri.Fragment -ne '' -or
        -not $Uri.AbsolutePath.StartsWith('/api/v10/', [System.StringComparison]::Ordinal)) {
        throw [System.ArgumentException]::new('Discord REST destinations must be HTTPS URLs under https://discord.com/api/v10/.')
    }
}
