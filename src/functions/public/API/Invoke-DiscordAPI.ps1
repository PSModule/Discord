function Invoke-DiscordAPI {
    <#
        .SYNOPSIS
        Call the Discord REST API with a saved connection.

        .DESCRIPTION
        Resolve bot or scoped user credentials, refresh expiring OAuth2 tokens, and return a response envelope.
        Only official HTTPS v10 API destinations are accepted. Mutating requests support WhatIf.

        .EXAMPLE
        ```powershell
        Invoke-DiscordAPI -ApiEndpoint '/users/@me'
        ```

        .EXAMPLE
        ```powershell
        Invoke-DiscordAPI -ApiEndpoint '/users/@me/guilds' -Query @{ limit = 10 } -Context 'personal'
        ```

        .EXAMPLE
        ```powershell
        Invoke-DiscordAPI -Uri 'https://discord.com/api/v10/users/@me' -Context (Get-DiscordContext)
        ```

        .INPUTS
        None

        You can't pipe objects to Invoke-DiscordAPI.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        Request, Response, Headers, StatusCode, and StatusDescription, without request headers or bodies.

        .LINK
        https://psmodule.io/Discord/Functions/API/Invoke-DiscordAPI/
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'API endpoint')]
    param(
        # The relative API endpoint, including any existing query string.
        [Parameter(Mandatory, ParameterSetName = 'API endpoint')]
        [ValidateNotNullOrEmpty()]
        [string] $ApiEndpoint,

        # An absolute official Discord API v10 URI.
        [Parameter(Mandatory, ParameterSetName = 'Full URI')]
        [uri] $Uri,

        # GET by default; only HTTP 429 responses are retried.
        [Parameter()]
        [ValidateSet('GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS')]
        [string] $Method = 'GET',

        # A query dictionary for GET/HEAD, or the body for other methods.
        [Parameter()]
        [AllowNull()]
        [Alias('Query')]
        [object] $Body,

        # JSON by default; use application/x-www-form-urlencoded for form data.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ContentType = 'application/json',

        # Override the configured number of additional HTTP 429 attempts.
        [Parameter()]
        [ValidateRange(0, 10)]
        [System.Nullable[int]] $RetryCount,

        # Override the configured fallback rate-limit delay.
        [Parameter()]
        [ValidateRange(0, 86400)]
        [System.Nullable[double]] $RetryInterval,

        # A saved name or DiscordContext object; omit to use the default.
        [Parameter()]
        [object] $Context
    )

    if ($PSCmdlet.ParameterSetName -eq 'API endpoint') {
        if ($ApiEndpoint -match '^(?:[a-z][a-z0-9+.-]*:|//|\\)' -or $ApiEndpoint.Contains('#')) {
            throw [System.ArgumentException]::new('ApiEndpoint must be a relative Discord API path without a fragment.')
        }
        $Uri = [uri] ('https://discord.com/api/v10/' + $ApiEndpoint.TrimStart('/'))
    }
    Assert-DiscordApiUri -Uri $Uri

    if ($Method -in @('GET', 'HEAD') -and $PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
        if ($Body -isnot [System.Collections.IDictionary]) {
            throw [System.ArgumentException]::new('GET and HEAD query bodies must be dictionaries.')
        }
        $query = ConvertTo-DiscordQueryString -Query $Body
        if ($query) {
            $builder = [System.UriBuilder]::new($Uri)
            $existing = $builder.Query.TrimStart('?')
            if ($existing) {
                $builder.Query = "$existing&$query"
            } else {
                $builder.Query = $query
            }
            $Uri = $builder.Uri
        }
    }

    if ($Method -notin @('GET', 'HEAD', 'OPTIONS') -and
        -not $PSCmdlet.ShouldProcess($Uri.GetLeftPart([System.UriPartial]::Path), "$Method Discord API request")) {
        return
    }

    $resolved = Resolve-DiscordContext -Context $Context
    Assert-DiscordContext -Context $resolved
    if ($resolved.Type -eq 'User') {
        Update-DiscordAccessToken -Context $resolved -Confirm:$false
    }
    Initialize-DiscordConfig
    if ($null -eq $RetryCount) {
        $RetryCount = $script:Discord.Config.RetryCount
    }
    if ($null -eq $RetryInterval) {
        $RetryInterval = $script:Discord.Config.RetryInterval
    }

    $parameters = @{
        Uri            = $Uri
        Method         = $Method
        AuthType       = $resolved.AuthType
        Token          = $resolved.Token
        ContentType    = $ContentType
        RetryCount     = $RetryCount
        RetryInterval  = $RetryInterval
        TimeoutSeconds = $script:Discord.Config.TimeoutSeconds
    }
    if ($Method -notin @('GET', 'HEAD') -and $PSBoundParameters.ContainsKey('Body')) {
        if ($ContentType -match '^application/(?:[^;]+\+)?json(?:;|$)' -and $Body -isnot [string]) {
            $parameters.Body = ConvertTo-Json -InputObject $Body -Depth 100 -Compress
        } else {
            $parameters.Body = $Body
        }
    }
    Invoke-DiscordRequest @parameters
}
