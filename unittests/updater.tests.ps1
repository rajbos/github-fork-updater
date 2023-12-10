# Import the script containing the function to test
. ./updater.ps1

Describe "FindAllRepos" {
    It "returns more than 30 repositories for the user 'rajbos'" {
        $result = FindAllRepos -orgName 'rajbos' -userName 'rajbos' -PAT 'YourPAT'
        $result.Count | Should -BeGreaterThan 30
    }
}