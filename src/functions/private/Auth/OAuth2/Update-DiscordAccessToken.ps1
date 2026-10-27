function Update-DiscordAccessToken {
    <#
        .SYNOPSIS
        Refresh an expiring OAuth2 connection.

        .DESCRIPTION
        Refresh at most 30 seconds before expiry and persist the rotated credentials before the API request continues.

        .EXAMPLE
        Update-DiscordAccessToken -Context $connection

        .OUTPUTS
        None

        The supplied connection and its saved credentials are updated when needed.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Connect-DiscordAccount/
    #>
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The already resolved user connection.
        [Parameter(Mandatory)]
        [DiscordContext] $Context
    )

    if ($Context.Type -ne 'User') {
        return
    }
    if ($null -ne $Context.TokenExpiresAt -and
        ([datetime] $Context.TokenExpiresAt).ToUniversalTime() -gt [datetime]::UtcNow.AddSeconds(30)) {
        return
    }
    if ([string]::IsNullOrWhiteSpace($Context.ClientID) -or
        $null -eq $Context.ClientSecret -or $Context.ClientSecret.Length -eq 0 -or
        $null -eq $Context.RefreshToken -or $Context.RefreshToken.Length -eq 0) {
        throw [System.InvalidOperationException]::new('The OAuth2 context cannot refresh its credentials. Run Connect-Discord again.')
    }
    if (-not $PSCmdlet.ShouldProcess($Context.Name, 'Refresh and save OAuth2 credentials')) {
        throw [System.InvalidOperationException]::new('OAuth2 refresh was not approved; no API request was sent.')
    }

    $parameters = @{
        ClientID     = $Context.ClientID
        ClientSecret = $Context.ClientSecret
        RefreshToken = $Context.RefreshToken
    }
    $fresh = Invoke-DiscordOAuthToken @parameters
    $Context.Token = $fresh.Token
    $Context.RefreshToken = $fresh.RefreshToken
    $Context.TokenExpiresAt = $fresh.TokenExpiresAt
    $Context.Scope = $fresh.Scope
    Set-DiscordContext -Context $Context -Confirm:$false
}
