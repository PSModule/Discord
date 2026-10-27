function Switch-DiscordContext {
    <#
        .SYNOPSIS
        Select a saved Discord connection.

        .DESCRIPTION
        Persist the default selection without authenticating or refreshing the connection.

        .EXAMPLE
        Switch-DiscordContext -Context 'personal'

        .INPUTS
        System.String

        The name of a saved connection.

        .OUTPUTS
        DiscordContext

        The selected connection, only when PassThru is specified.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Context/Switch-DiscordContext/
    #>
    [OutputType([DiscordContext])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The exact saved name, or the Name property of a piped context.
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string] $Context,

        # Return the selected connection.
        [Parameter()]
        [switch] $PassThru
    )

    process {
        $resolved = Get-DiscordContext -Context $Context
        if ($PSCmdlet.ShouldProcess($resolved.Name, 'Select default Discord context')) {
            Set-DiscordConfig -DefaultContext $resolved.Name -Confirm:$false
            if ($PassThru) {
                $resolved
            }
        }
    }
}
