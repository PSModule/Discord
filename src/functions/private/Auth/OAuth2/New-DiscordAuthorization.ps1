function New-DiscordAuthorization {
    <#
        .SYNOPSIS
        Prepare a scoped authorization-code request.

        .DESCRIPTION
        Validate application configuration and create independent random state and S256 PKCE values.

        .EXAMPLE
        New-DiscordAuthorization -ClientID $clientID -RedirectUri 'http://localhost:53682/' -Scope identify

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The authorization URI, callback URI, state, and secure verifier for this sign-in only.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Connect-DiscordAccount/
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'The cryptographically generated verifier enters the credential boundary as a SecureString.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creates only in-memory request values; opening a browser and saving context are guarded by the caller.'
    )]
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        # The configured Discord application ID.
        [Parameter(Mandatory)]
        [ValidatePattern('^\d{1,20}$')]
        [string] $ClientID,

        # The exact registered loopback URI.
        [Parameter(Mandatory)]
        [uri] $RedirectUri,

        # The requested user scopes, including identify.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Scope
    )

    if (-not $RedirectUri.IsAbsoluteUri -or $RedirectUri.Scheme -cne 'http' -or
        $RedirectUri.DnsSafeHost -notin @('localhost', '127.0.0.1') -or
        $RedirectUri.Port -lt 1024 -or $RedirectUri.UserInfo -ne '' -or
        $RedirectUri.Query -ne '' -or $RedirectUri.Fragment -ne '' -or
        -not $RedirectUri.AbsolutePath.EndsWith('/', [System.StringComparison]::Ordinal)) {
        throw [System.ArgumentException]::new(
            'RedirectUri must be a registered HTTP localhost or 127.0.0.1 URI with a nonprivileged port and a trailing slash.'
        )
    }
    if ($Scope -cnotcontains 'identify' -or
        @($Scope | Where-Object { $_ -cnotmatch '\A[a-z0-9._-]+\z' }).Count -gt 0 -or
        @($Scope | Where-Object { $_ -in @('bot', 'webhook.incoming', 'applications.commands') }).Count -gt 0) {
        throw [System.ArgumentException]::new('User sign-in requires identify scope and does not accept installation scopes.')
    }

    $state = [Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    $random = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
    $verifierText = [Convert]::ToBase64String($random).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $verifier = ConvertTo-SecureString -String $verifierText -AsPlainText -Force
    $verifierText = $null
    [Array]::Clear($random, 0, $random.Length)
    $query = @{
        client_id             = $ClientID
        response_type         = 'code'
        redirect_uri          = $RedirectUri.AbsoluteUri
        scope                 = ($Scope | Select-Object -Unique) -join ' '
        state                 = $state
        code_challenge        = ConvertTo-DiscordCodeChallenge -CodeVerifier $verifier
        code_challenge_method = 'S256'
        prompt                = 'consent'
    }

    [pscustomobject]@{
        Uri          = [uri] ('https://discord.com/api/oauth2/authorize?' + (ConvertTo-DiscordQueryString -Query $query))
        RedirectUri  = $RedirectUri
        State        = $state
        CodeVerifier = $verifier
    }
}
