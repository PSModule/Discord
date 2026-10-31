function ConvertTo-DiscordQueryString {
    <#
        .SYNOPSIS
        Encode a dictionary as URI query parameters.

        .DESCRIPTION
        Preserve repeated values and use invariant formatting without modifying the input.

        .EXAMPLE
        ConvertTo-DiscordQueryString -Query @{ limit = 10 }

        .OUTPUTS
        System.String

        Percent-encoded query parameters without a leading question mark.

        .LINK
        https://psmodule.io/Discord/Functions/API/Invoke-DiscordAPI/
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The resolved query fields.
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Query
    )

    $pairs = [System.Collections.Generic.List[string]]::new()
    foreach ($key in ($Query.Keys | Sort-Object)) {
        $encodedKey = [uri]::EscapeDataString([string] $key)
        $values = @($Query[$key])
        if ($null -eq $Query[$key]) {
            $values = @('')
        }
        foreach ($value in $values) {
            $text = [System.Convert]::ToString($value, [cultureinfo]::InvariantCulture)
            if ($value -is [bool]) {
                $text = $text.ToLowerInvariant()
            }
            $pairs.Add("$encodedKey=$([uri]::EscapeDataString($text))")
        }
    }
    $pairs -join '&'
}
