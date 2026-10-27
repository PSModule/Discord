function Get-DiscordViewer {
    <#
        .SYNOPSIS
        Get the authenticated Discord user or bot.

        .DESCRIPTION
        Return GET /users/@me using the selected connection. OAuth2 user access requires identify scope.

        .EXAMPLE
        Get-DiscordViewer

        .EXAMPLE
        Get-DiscordViewer -Context 'automation'

        .INPUTS
        None

        You can't pipe objects to Get-DiscordViewer.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The current Discord user object, with its snowflake ID preserved as a string.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Get-DiscordViewer/
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        # A saved connection name or a DiscordContext object.
        [Parameter()]
        [object] $Context
    )

    $resolved = Resolve-DiscordContext -Context $Context
    $result = Invoke-DiscordAPI -ApiEndpoint '/users/@me' -Context $resolved
    $viewer = $result.Response
    if ($null -eq $viewer -or $viewer.id -cnotmatch '^\d{1,20}$' -or
        [string]::IsNullOrWhiteSpace($viewer.username)) {
        throw [System.InvalidOperationException]::new('Discord returned an invalid current-user response.')
    }
    if ($resolved.UserID -and $resolved.UserID -cne [string] $viewer.id) {
        throw [System.InvalidOperationException]::new('The authenticated identity differs from the saved context. Run Connect-Discord again.')
    }
    $viewer
}
