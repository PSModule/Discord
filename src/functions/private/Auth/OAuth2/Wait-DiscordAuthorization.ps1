function Wait-DiscordAuthorization {
    <#
        .SYNOPSIS
        Receive one interactive authorization response.

        .DESCRIPTION
        Start the loopback listener before opening a browser, validate the response, and always close the listener.

        .EXAMPLE
        Wait-DiscordAuthorization -Authorization $request -TimeoutSeconds 180

        .OUTPUTS
        System.Security.SecureString

        The validated authorization code.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Connect-DiscordAccount/
    #>
    [OutputType([securestring])]
    [CmdletBinding()]
    param(
        # The prepared request containing URI, redirect, and expected state.
        [Parameter(Mandatory)]
        [pscustomobject] $Authorization,

        # The maximum wait for browser consent.
        [Parameter()]
        [ValidateRange(1, 900)]
        [int] $TimeoutSeconds = 180,

        # Display the URL without starting a browser.
        [Parameter()]
        [switch] $NoBrowser
    )

    $listener = [System.Net.HttpListener]::new()
    try {
        $listener.Prefixes.Add($Authorization.RedirectUri.AbsoluteUri)
        try {
            $listener.Start()
        } catch [System.Net.HttpListenerException] {
            $failure = $_
            throw [System.InvalidOperationException]::new(
                'Cannot start the OAuth2 loopback listener. Check port availability and OS permissions, or register another redirect port.',
                $failure.Exception
            )
        }
        $information = @{
            MessageData       = "Authorize Discord access in a browser on this machine: $($Authorization.Uri.AbsoluteUri)"
            InformationAction = 'Continue'
        }
        Write-Information @information
        if (-not $NoBrowser) {
            Start-Process -FilePath $Authorization.Uri.AbsoluteUri -ErrorAction Stop
        }

        $pending = $listener.GetContextAsync()
        if (-not $pending.Wait([timespan]::FromSeconds($TimeoutSeconds))) {
            throw [System.TimeoutException]::new('Discord sign-in timed out. Run Connect-Discord again.')
        }
        $callback = $pending.GetAwaiter().GetResult()
        try {
            if ($callback.Request.HttpMethod -cne 'GET') {
                throw [System.InvalidOperationException]::new('The OAuth2 callback must be a GET request.')
            }
            $callbackParameters = @{
                ResponseUri = $callback.Request.Url
                RedirectUri = $Authorization.RedirectUri
                State       = $Authorization.State
            }
            $code = ConvertFrom-DiscordAuthorizationResponse @callbackParameters
            $message = [System.Text.Encoding]::UTF8.GetBytes('Discord authorization received. You can close this window.')
            $callback.Response.ContentType = 'text/plain; charset=utf-8'
            $callback.Response.ContentLength64 = $message.Length
            $callback.Response.OutputStream.Write($message, 0, $message.Length)
            $code
        } catch [System.InvalidOperationException] {
            $callback.Response.StatusCode = 400
            throw
        } finally {
            $callback.Response.Close()
        }
    } finally {
        $listener.Close()
    }
}
