Import-Module Pester

. ../src/sys.ps1

Describe "CoalesceWithEnvVar test" {
    It "Must return null if first param is null" {
        CoalesceWithEnvVar($null) | Should -Be $null
    }
    It "Must return null if first param is blank string" {
        CoalesceWithEnvVar("") | Should -Be $null
    }
    It "Must return value if first param is a value" {
        CoalesceWithEnvVar(4) | Should -Be 4
    }
    It "Must return string value if first param is a string value" {
        CoalesceWithEnvVar("Hello!") | Should -Be "Hello!"
    }
    It "Must return env var value if first param is null" {
        CoalesceWithEnvVar -val $null -envVarName "USERPROFILE" -defaultValue "bogus" | Should -Be $env:USERPROFILE
    }
    It "Must return env var value if first param is blank string" {
        CoalesceWithEnvVar -val "" -envVarName "USERPROFILE"  -defaultValue "bogus" | Should -Be $env:USERPROFILE
    }
    It "Must return default value if first two params are nulls" {
        CoalesceWithEnvVar -val $null -envVarName $null -defaultValue "default" | Should -Be "default"
    }
    It "Must return default value if first two params are blank" {
        CoalesceWithEnvVar -val "" -envVarName "" -defaultValue "default" | Should -Be "default"
    }
    It "Must return default value if val is balnk and env var name is null" {
        CoalesceWithEnvVar -val "" -envVarName $null -defaultValue "default" | Should -Be "default"
    }
}

Describe "FalseToNull test" {
    It "must return null when supplied with null" {
        ($null | FalseToNull) | Should -Be $null
    }
    It "must return null when supplied with blank string" {
        ("" | FalseToNull) | Should -Be $null
    }
    It "must return value when supplied with non-blank string" {
        ("Hello" | FalseToNull) | Should -Be "Hello"
    }
    It "must return value when supplied with non-blank value" {
        (4 | FalseToNull) | Should -Be 4
    }
    It "must return null when supplied with 0" {
        (0 | FalseToNull) | Should -Be $null
    }
    It "must return value when supplied with true" {
        ($true | FalseToNull) | Should -Be $true
    }
    It "must return null when supplied with false" {
        ($false | FalseToNull) | Should -Be $null
    }
}

Describe "IsWebUri test" {
    It "must return True when http URL is provided" {
        IsWebUri("http://acme.com") | Should -Be $true
    }
    It "must return True when https URL is provided" {
        IsWebUri("https://acme.com") | Should -Be $true
    }
    It "must return True when upper case URL is provided" {
        IsWebUri("HTTP://ACME.COM") | Should -Be $true
    }
    It "must return False when file path is provided" {
        IsWebUri("c:\whatever.txt") | Should -Be $false
    }
    It "must return False when null is provided" {
        IsWebUri($null) | Should -Be $false
    }
    It "must return False when input is not URI" {
        IsWebUri("Hello!") | Should -Be $false
    }
}

Describe "IsUri test" {
    It "Must return False if schema and root location are missing" {
        IsUri "file.txt" | Should -Be $false
    }
    It "Must return true if address starts with drive letter" {
        IsUri "Z:\file.txt" | Should -be $true
    }
    It "Must return True is web URL provided" {
        IsUri "http://acme.com" | Should -Be $true
    }
    It "Must return False if null is provided" {
        IsUri $null | Should -Be $false
    }
    It "Must return False if blank path is provided" {
        IsUri "" | Should -Be $false
    }
    It "Must return True if file:// schema is used explicitly" {
        IsUri "file:///etc/file.ext" | Should -Be $true
    }
}