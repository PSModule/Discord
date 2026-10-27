function ConvertFrom-DiscordAuthorizationResponse {
    <#
        .SYNOPSIS
        Validate a Discord authorization callback.

        .DESCRIPTION
        Require the original redirect, an exact state match, Discord's issuer, and one authorization code.

        .EXAMPLE
        ConvertFrom-DiscordAuthorizationResponse -ResponseUri $callback -RedirectUri $redirect -State $state

        .OUTPUTS
        System.Security.SecureString

        The authorization code after all callback validation succeeds.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Connect-DiscordAccount/
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'The OAuth2 callback supplies a plaintext code which must not leave the boundary as plaintext.'
    )]
    [OutputType([securestring])]
    [CmdletBinding()]
    param(
        # The callback received by the temporary listener.
        [Parameter(Mandatory)]
        [uri] $ResponseUri,

        # The original registered redirect.
        [Parameter(Mandatory)]
        [uri] $RedirectUri,

        # The nonce generated for this request.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $State
    )

    if (-not $ResponseUri.IsAbsoluteUri -or $ResponseUri.UserInfo -ne '' -or $ResponseUri.Fragment -ne '' -or
        $ResponseUri.GetLeftPart([System.UriPartial]::Path) -cne $RedirectUri.AbsoluteUri) {
        throw [System.InvalidOperationException]::new('The authorization response does not match the registered redirect.')
    }

    $query = [System.Web.HttpUtility]::ParseQueryString($ResponseUri.Query)
    foreach ($name in @('state', 'iss')) {
        $values = $query.GetValues($name)
        if ($query.AllKeys -cnotcontains $name -or $null -eq $values -or $values.Count -ne 1) {
            throw [System.InvalidOperationException]::new('The authorization response has missing or repeated security parameters.')
        }
    }
    if ($query['state'] -cne $State -or $query['iss'] -cne 'https://discord.com') {
        throw [System.InvalidOperationException]::new('The authorization response state or issuer is invalid. Sign in again.')
    }
    if ($null -ne $query.GetValues('error')) {
        throw [System.InvalidOperationException]::new('Discord authorization was denied or failed. Sign in again to continue.')
    }

    $codes = $query.GetValues('code')
    if ($query.AllKeys -cnotcontains 'code' -or $null -eq $codes -or
        $codes.Count -ne 1 -or [string]::IsNullOrWhiteSpace($codes[0])) {
        throw [System.InvalidOperationException]::new('Discord did not return one valid authorization code.')
    }
    ConvertTo-SecureString -String $codes[0] -AsPlainText -Force
}
