@{
    ExcludeRules = @(
        # TidyLog is a console layout library so Write-Host use is intentional.
        # Direct console output is the product, not a side effect.
        # Write-Output, Write-Verbose and Write-Information cannot produce
        # the colour-coded, grid-aligned, in-place animated output this
        # library requires.
        'PSAvoidUsingWriteHost',

        # Set-TLLayout, Set-TLPhaseColor and Set-TLGlyphSet modify only
        # $TL, an in-memory session hashtable. No system state is changed.
        # -WhatIf/-Confirm support would be meaningless here.
        'PSUseShouldProcessForStateChangingFunctions'
    )
}