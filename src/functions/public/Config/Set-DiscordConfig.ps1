#Requires -Modules @{ ModuleName = 'Context'; ModuleVersion = '8.1.3' }

function Set-DiscordConfig {
    <#
        .SYNOPSIS
        Save Discord client settings.

        .DESCRIPTION
        Change only specified settings. A nonempty default must identify an existing saved context.

        .EXAMPLE
        Set-DiscordConfig -RetryCount 3 -RetryInterval 1 -TimeoutSeconds 100

        .EXAMPLE
        Set-DiscordConfig -DefaultContext 'automation' -PassThru

        .INPUTS
        None

        You can't pipe objects to Set-DiscordConfig.

        .OUTPUTS
        DiscordConfig

        The saved settings, only when PassThru is specified.

        .LINK
        https://psmodule.io/Discord/Functions/Config/Set-DiscordConfig/
    #>
    [OutputType([DiscordConfig])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The saved default name, or an empty string to clear the selection.
        [Parameter()]
        [AllowEmptyString()]
        [string] $DefaultContext,

        # The number of additional attempts after an HTTP 429 response.
        [Parameter()]
        [ValidateRange(0, 10)]
        [int] $RetryCount,

        # The fallback delay when a 429 response omits its retry delay.
        [Parameter()]
        [ValidateRange(0, 86400)]
        [double] $RetryInterval,

        # The timeout for each HTTP request, in seconds.
        [Parameter()]
        [ValidateRange(1, 3600)]
        [int] $TimeoutSeconds,

        # Return the saved configuration.
        [Parameter()]
        [switch] $PassThru
    )

    Initialize-DiscordConfig
    if ($PSBoundParameters.ContainsKey('DefaultContext') -and $DefaultContext -ne '') {
        $null = Get-DiscordContext -Context $DefaultContext
    }

    $config = [DiscordConfig]::new([pscustomobject] $script:Discord.Config)
    foreach ($name in @('DefaultContext', 'RetryCount', 'RetryInterval', 'TimeoutSeconds')) {
        if ($PSBoundParameters.ContainsKey($name)) {
            $config.$name = $PSBoundParameters[$name]
        }
    }

    if ($PSCmdlet.ShouldProcess('Discord module settings', 'Save configuration')) {
        $parameters = @{
            ID          = $config.ID
            Context     = $config
            Vault       = $script:Discord.ContextVault
            ErrorAction = 'Stop'
            Verbose     = $false
            Debug       = $false
            Confirm     = $false
        }
        Set-Context @parameters
        $script:Discord.Config = $config
        if ($PassThru) {
            Get-DiscordConfig
        }
    }
}
