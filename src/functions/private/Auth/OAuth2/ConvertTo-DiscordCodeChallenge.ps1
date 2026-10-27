function ConvertTo-DiscordCodeChallenge {
    <#
        .SYNOPSIS
        Derive an S256 PKCE challenge.

        .DESCRIPTION
        Hash the verifier and encode the result with unpadded base64url.

        .EXAMPLE
        ConvertTo-DiscordCodeChallenge -CodeVerifier $verifier

        .OUTPUTS
        System.String

        The public S256 challenge, not the secret verifier.

        .LINK
        https://psmodule.io/Discord/Functions/Auth/Connect-DiscordAccount/
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        # The generated PKCE verifier.
        [Parameter(Mandatory)]
        [securestring] $CodeVerifier
    )

    $bytes = [System.Text.Encoding]::ASCII.GetBytes(
        (ConvertFrom-SecureString -SecureString $CodeVerifier -AsPlainText)
    )
    try {
        $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
        [Convert]::ToBase64String($hash).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
    }
}
