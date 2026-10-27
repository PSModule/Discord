<#
    .SYNOPSIS
    Represent a saved bot or OAuth2 user connection.

    .DESCRIPTION
    ID is the Context vault key, not the Discord snowflake. UserID holds the authenticated identity.
    Credentials remain SecureString values when a stored object is reconstructed.
#>
class DiscordContext {
    [string] $ID

    [string] $Name

    [string] $DisplayName

    [ValidateSet('Bot', 'User')]
    [string] $Type

    [string] $HostName = 'discord.com'

    [string] $ApiBaseUri = 'https://discord.com/api/v10'

    [string] $ApiVersion = '10'

    [ValidateSet('Bot', 'Bearer')]
    [string] $AuthType

    [string] $UserID

    [string] $UserName

    [securestring] $Token

    [System.Nullable[datetime]] $TokenExpiresAt

    [securestring] $RefreshToken

    [string] $ClientID

    [securestring] $ClientSecret

    [uri] $RedirectUri

    [string[]] $Scope = @()

    DiscordContext() {}

    DiscordContext([pscustomobject] $Object) {
        foreach ($name in @(
                'ID', 'Name', 'DisplayName', 'Type', 'HostName', 'ApiBaseUri', 'ApiVersion',
                'AuthType', 'UserID', 'UserName', 'Token', 'TokenExpiresAt', 'RefreshToken',
                'ClientID', 'ClientSecret', 'RedirectUri', 'Scope'
            )) {
            if ($null -ne $Object.PSObject.Properties[$name]) {
                $this.$name = $Object.$name
            }
        }
    }

    [string] ToString() {
        return $this.Name
    }
}
