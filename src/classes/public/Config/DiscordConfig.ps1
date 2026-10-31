<#
    .SYNOPSIS
    Represent the persisted Discord client settings.
#>
class DiscordConfig {
    [string] $ID = 'Module'

    [string] $DefaultContext = ''

    [ValidateRange(0, 10)]
    [int] $RetryCount = 3

    [ValidateRange(0, 86400)]
    [double] $RetryInterval = 1

    [ValidateRange(1, 3600)]
    [int] $TimeoutSeconds = 100

    DiscordConfig() {}

    DiscordConfig([pscustomobject] $Object) {
        foreach ($name in @('DefaultContext', 'RetryCount', 'RetryInterval', 'TimeoutSeconds')) {
            if ($null -ne $Object.PSObject.Properties[$name]) {
                $this.$name = $Object.$name
            }
        }
    }
}
