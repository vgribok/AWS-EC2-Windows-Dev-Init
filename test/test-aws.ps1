Import-Module Pester

$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Path)
Push-Location
Set-Location $scriptLocation
. ../src/aws.ps1
Pop-Location

Describe "RIP related tests" {
    It "Must return empty collection if argument is null" {
        EnsureStringArray($null) | Should be @()
    }
    It "Must return empty collection if argument is blank string" {
        EnsureStringArray("") | Should be @()
    }
    It "Must return the string argument if the argument is not comma-delimited" {
        EnsureStringArray("one;two") | Should be "one;two"
    }
    It "Must return string collection if the argument is comma-delimited" {
        EnsureStringArray("one,two") | Should be @("one", "two")
    }
    It "Must not have blank string if blank string is present in comma-delimited string argument" {
        EnsureStringArray("one,,two") | Should be @("one", "two")
    }
    It "Must not have entries with leading or trailing spaces" {
        EnsureStringArray(" one,two , three ") | Should be @("one", "two", "three")
    }

    It "Must not puke when attempting to delete single non-existing ECR repos" {
        $result = DeleteEcrRepos("bogus-repo")
    }
    It "Must not puke when attempting to delete multiple non-existing ECR repos" {
        $result = DeleteEcrRepos("bogus-repo-1, bougs-repo-2")
    }
    It "Must not puke when attempting to delete multiple non-existing CFN stacks" {
        DeleteCfnStacks("bogus-stack-1, bougs-stack-2")
    }
    It "Must not puke when attempting to delete a single non-existing CFN stacks" {
        DeleteCfnStacks("bogus-stack")
    }    
}