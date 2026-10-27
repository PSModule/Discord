function Assert-DiscordContextName {
    <#
        .SYNOPSIS
        Validate an exact saved-context name.

        .DESCRIPTION
        Reject empty names, wildcard selection, and the reserved module settings key.

        .EXAMPLE
        Assert-DiscordContextName -Name 'automation'

        .OUTPUTS
        None

        Invalid names raise a terminating error.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Context/Get-DiscordContext/
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param(
        # The exact vault key, not a wildcard expression.
        [Parameter(Mandatory)]
        [string] $Name
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or
        [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Name) -or
        $Name -eq $script:Discord.DefaultConfig.ID) {
        throw [System.ArgumentException]::new('Context names must be nonempty, contain no wildcards, and not be Module.')
    }
}
