
BeforeAll {
    # Import the script containing the function to test
    . $PSScriptRoot\..\library.ps1
    # set logging to debug  
    $DebugPreference = "Continue"
}

AfterAll {
    # reset logging to normal
    $DebugPreference = "SilentlyContinue"
}

Describe "FindAllRepos" {
    It "returns more than 30 repositories for the user 'rajbos'" {
        # making sure that pagination works
        $result = FindAllRepos -userName 'rajbos' -PAT '$env:GITHUB_TOKEN'
        $result.Count | Should -BeGreaterThan 30
    }
}