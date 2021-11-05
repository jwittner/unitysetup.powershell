BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\UnitySetup\UnitySetup.psd1') -Force
}
Describe 'Import-UnityPackageManifest' {
    Context 'Input Validation' {
        It 'throws on null path'{
            { Import-UnityPackageManifest -Path $null } | Should -Throw "*Path*The argument is null*"
        }

        It 'throws on non-existing file'{
            { Import-UnityPackageManifest -Path "NotAFile.json" } | Should -Throw "*Path*File*must exist."
        }
    }
}