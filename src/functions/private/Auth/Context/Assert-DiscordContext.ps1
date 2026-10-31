function Assert-DiscordContext {
    <#
        .SYNOPSIS
        Validate the authentication contract of a Discord context.

        .DESCRIPTION
        Ensure the stored type and authentication scheme agree and credentials are available.

        .EXAMPLE
        Assert-DiscordContext -Context (Get-DiscordContext)

        .OUTPUTS
        None

        Invalid contexts raise a terminating error.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Context/Get-DiscordContext/
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param(
        # The resolved connection to validate.
        [Parameter(Mandatory)]
        [DiscordContext] $Context
    )

    Assert-DiscordContextName -Name $Context.Name
    if ($null -eq $Context.Token -or $Context.Token.Length -eq 0) {
        throw [System.InvalidOperationException]::new('The context has no access token. Run Connect-Discord again.')
    }
    if (($Context.Type -eq 'Bot' -and $Context.AuthType -ne 'Bot') -or
        ($Context.Type -eq 'User' -and $Context.AuthType -ne 'Bearer') -or
        $Context.Type -notin @('Bot', 'User')) {
        throw [System.InvalidOperationException]::new('The context authentication type is invalid. Run Connect-Discord again.')
    }
    if ($Context.Type -eq 'User' -and
        ($Context.Scope -cnotcontains 'identify' -or $null -eq $Context.TokenExpiresAt)) {
        throw [System.InvalidOperationException]::new('The OAuth2 context needs identify scope and token expiry. Run Connect-Discord again.')
    }
}
