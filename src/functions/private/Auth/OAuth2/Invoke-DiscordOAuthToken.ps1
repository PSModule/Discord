function Invoke-DiscordOAuthToken {
    <#
        .SYNOPSIS
        Exchange an authorization code or refresh token.

        .DESCRIPTION
        Use form encoding and confidential application credentials, then return only secure credential values.

        .EXAMPLE
        Invoke-DiscordOAuthToken -ClientID $id -ClientSecret $secret -RefreshToken $refreshToken

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        Secure access and refresh tokens, expiry, and granted user scopes.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Connect-DiscordAccount/
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingConvertToSecureStringWithPlainText', '',
        Justification = 'OAuth2 token responses are plaintext; credentials are secured before leaving this function.'
    )]
    [OutputType([pscustomobject])]
    [CmdletBinding(DefaultParameterSetName = 'Authorization code')]
    param(
        # The Discord application ID.
        [Parameter(Mandatory)]
        [ValidatePattern('^\d{1,20}$')]
        [string] $ClientID,

        # The confidential application's client secret.
        [Parameter(Mandatory)]
        [securestring] $ClientSecret,

        # The validated callback code.
        [Parameter(Mandatory, ParameterSetName = 'Authorization code')]
        [securestring] $Code,

        # The verifier corresponding to the authorization request's S256 challenge.
        [Parameter(Mandatory, ParameterSetName = 'Authorization code')]
        [securestring] $CodeVerifier,

        # The exact URI used in the original authorization request.
        [Parameter(Mandatory, ParameterSetName = 'Authorization code')]
        [uri] $RedirectUri,

        # The stored refresh token for the existing user grant.
        [Parameter(Mandatory, ParameterSetName = 'Refresh token')]
        [securestring] $RefreshToken
    )

    if ($ClientSecret.Length -eq 0) {
        throw [System.ArgumentException]::new('A nonempty OAuth2 client secret is required.')
    }
    $form = @{
        client_id     = $ClientID
        client_secret = $ClientSecret
    }
    if ($PSCmdlet.ParameterSetName -eq 'Authorization code') {
        $form.grant_type = 'authorization_code'
        $form.code = $Code
        $form.code_verifier = $CodeVerifier
        $form.redirect_uri = $RedirectUri.AbsoluteUri
    } else {
        $form.grant_type = 'refresh_token'
        $form.refresh_token = $RefreshToken
    }

    $parameters = @{
        Uri         = [uri] 'https://discord.com/api/oauth2/token'
        Method      = 'POST'
        ContentType = 'application/x-www-form-urlencoded'
        Body        = $form
    }
    $result = Invoke-DiscordRequest @parameters
    $response = $result.Response
    $expiresIn = 0.0
    $expiryText = [System.Convert]::ToString($response.expires_in, [cultureinfo]::InvariantCulture)
    if ($null -eq $response -or $response.token_type -ine 'Bearer' -or
        [string]::IsNullOrWhiteSpace($response.access_token) -or
        [string]::IsNullOrWhiteSpace($response.refresh_token) -or
        -not [double]::TryParse(
            $expiryText, [System.Globalization.NumberStyles]::Float, [cultureinfo]::InvariantCulture, [ref] $expiresIn
        ) -or -not [double]::IsFinite($expiresIn) -or $expiresIn -le 0) {
        throw [System.InvalidOperationException]::new('Discord returned an incomplete OAuth2 token response. Sign in again.')
    }
    $scopes = @($response.scope -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($scopes -cnotcontains 'identify') {
        throw [System.InvalidOperationException]::new('Discord did not grant identify scope. Sign in again with identify.')
    }

    [pscustomobject]@{
        Token          = ConvertTo-SecureString -String $response.access_token -AsPlainText -Force
        RefreshToken   = ConvertTo-SecureString -String $response.refresh_token -AsPlainText -Force
        TokenExpiresAt = [datetime]::UtcNow.AddSeconds($expiresIn)
        Scope          = [string[]] $scopes
    }
}
