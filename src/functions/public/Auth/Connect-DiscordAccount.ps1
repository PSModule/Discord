function Connect-DiscordAccount {
    <#
        .SYNOPSIS
        Connect to Discord as a bot or OAuth2 user.

        .DESCRIPTION
        Verify the authenticated identity before saving a secure Context connection.
        User sign-in uses a registered loopback redirect, state and issuer validation, and S256 PKCE with a client secret.
        Normal Discord account session tokens and self-bot authentication are not supported.

        .EXAMPLE
        ```powershell
        $token = Read-Host -Prompt 'Bot token' -AsSecureString
        Connect-DiscordAccount -BotToken $token
        ```

        .EXAMPLE
        ```powershell
        $secret = Read-Host -Prompt 'OAuth2 client secret' -AsSecureString
        $connection = @{
            ClientID = 'YOUR_APPLICATION_ID'
            ClientSecret = $secret
            RedirectUri = 'http://localhost:53682/'
        }
        Connect-DiscordAccount @connection -Name 'personal'
        ```

        .EXAMPLE
        ```powershell
        Connect-DiscordAccount -BotToken $token -Name 'automation' -NotDefault -PassThru
        ```

        .INPUTS
        None

        You can't pipe objects to Connect-DiscordAccount.

        .OUTPUTS
        DiscordContext

        The verified saved connection, only when PassThru is specified.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Connect-DiscordAccount/
    #>
    [Alias('Connect-Discord')]
    [OutputType([DiscordContext])]
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Interactive user')]
    param(
        # The raw bot token, not a normal account token or an OAuth2 client secret.
        [Parameter(Mandatory, ParameterSetName = 'Bot token')]
        [securestring] $BotToken,

        # The application ID from the Discord Developer Portal.
        [Parameter(Mandatory, ParameterSetName = 'Interactive user')]
        [ValidatePattern('^\d{1,20}$')]
        [string] $ClientID,

        # The application's OAuth2 client secret.
        [Parameter(Mandatory, ParameterSetName = 'Interactive user')]
        [securestring] $ClientSecret,

        # The exact registered HTTP loopback URI, with a trailing slash.
        [Parameter(ParameterSetName = 'Interactive user')]
        [uri] $RedirectUri = 'http://localhost:53682/',

        # User scopes; identify is required and installation scopes are not accepted.
        [Parameter(ParameterSetName = 'Interactive user')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Scope = @('identify'),

        # Display the authorization URL without starting a browser.
        [Parameter(ParameterSetName = 'Interactive user')]
        [switch] $NoBrowser,

        # The time to wait for browser consent, independent of HTTP request timeouts.
        [Parameter(ParameterSetName = 'Interactive user')]
        [ValidateRange(1, 900)]
        [int] $TimeoutSeconds = 180,

        # An exact saved name; omit for a stable type, user ID, and application-based name.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('ContextName')]
        [string] $Name,

        # Save without selecting this connection as the default.
        [Parameter()]
        [switch] $NotDefault,

        # Return the verified saved connection.
        [Parameter()]
        [switch] $PassThru
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        Assert-DiscordContextName -Name $Name
    }
    $context = [DiscordContext]::new()
    $context.ID = 'Pending'
    $context.Name = 'Pending'
    if ($PSCmdlet.ParameterSetName -eq 'Bot token') {
        if ($BotToken.Length -eq 0) {
            throw [System.ArgumentException]::new('A nonempty bot token is required.')
        }
        if (-not $PSCmdlet.ShouldProcess('Discord bot connection', 'Authenticate and save context')) {
            return
        }
        $context.Type = 'Bot'
        $context.AuthType = 'Bot'
        $context.Token = $BotToken
    } else {
        if ($ClientSecret.Length -eq 0) {
            throw [System.ArgumentException]::new('A nonempty OAuth2 client secret is required.')
        }
        $authorization = New-DiscordAuthorization -ClientID $ClientID -RedirectUri $RedirectUri -Scope $Scope
        $code = $null
        try {
            if (-not $PSCmdlet.ShouldProcess('Discord OAuth2 user connection', 'Authorize and save context')) {
                return
            }
            $code = Wait-DiscordAuthorization -Authorization $authorization -TimeoutSeconds $TimeoutSeconds -NoBrowser:$NoBrowser
            $parameters = @{
                ClientID     = $ClientID
                ClientSecret = $ClientSecret
                Code         = $code
                CodeVerifier = $authorization.CodeVerifier
                RedirectUri  = $RedirectUri
            }
            $credentials = Invoke-DiscordOAuthToken @parameters
        } finally {
            $authorization.CodeVerifier.Dispose()
            if ($null -ne $code) {
                $code.Dispose()
            }
        }
        $context.Type = 'User'
        $context.AuthType = 'Bearer'
        $context.ClientID = $ClientID
        $context.ClientSecret = $ClientSecret
        $context.RedirectUri = $RedirectUri
        $context.Token = $credentials.Token
        $context.RefreshToken = $credentials.RefreshToken
        $context.TokenExpiresAt = $credentials.TokenExpiresAt
        $context.Scope = $credentials.Scope
    }

    $viewer = Get-DiscordViewer -Context $context
    if (($context.Type -eq 'Bot' -and $viewer.bot -ne $true) -or
        ($context.Type -eq 'User' -and $viewer.bot -eq $true)) {
        throw [System.InvalidOperationException]::new('The authenticated identity does not match the selected bot or user authentication mode.')
    }
    $context.UserID = [string] $viewer.id
    $context.UserName = $viewer.username
    $context.DisplayName = $viewer.global_name
    if ([string]::IsNullOrWhiteSpace($context.DisplayName)) {
        $context.DisplayName = $context.UserName
    }

    if ($Name) {
        $context.Name = $Name
    } elseif ($context.Type -eq 'Bot') {
        $context.Name = "Bot-$($context.UserID)"
    } else {
        $context.Name = "User-$($context.UserID)-$ClientID"
    }
    $context.ID = $context.Name
    Set-DiscordContext -Context $context -Default:(-not $NotDefault) -Confirm:$false
    if ($PassThru) {
        Get-DiscordContext -Context $context.Name
    }
}
