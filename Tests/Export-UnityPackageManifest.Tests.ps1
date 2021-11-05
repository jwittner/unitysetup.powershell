BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\UnitySetup\UnitySetup.psd1') -Force
}
Describe 'Export-UnityPackageManifest' {
    Context 'Input Validation' {
        It 'throws on null config'{
            { Export-UnityPackageManifest -Manifest $null -Path 'somefile.txt' } | Should -Throw "*Manifest*The argument is null*"
        }

        It 'throws on null path'{
            { Export-UnityPackageManifest -Manifest (@{}) -Path $null } | Should -Throw "*Path*The argument is null*"
        }
    }
}