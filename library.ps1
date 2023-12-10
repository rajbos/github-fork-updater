# pull in central calls library
. $PSScriptRoot\github-calls.ps1

function FindAllRepos {
    param (
        [string] $orgName,
        [string] $userName,
        [string] $PAT
    )

    Write-Debug "Finding all repos with orgName: [$orgName], userName: [$userName], PAT lenght: [$($PAT.length)]"

    if ($null -ne $orgName -And $orgName.Length -ne 0) { 
        Write-Debug "Finding all repos for org with name [$orgName]"      
        $url = "https://api.github.com/orgs/$orgName/repos?per_page=100"
        $info = CallWebRequest -url $url -userName $userName -PAT $PAT

        Write-Debug "info.GetType: [$($info.GetType())]"
        if ($info.GetType() -ne "System.Object[]")
        {
            Write-Warning "Error loading information from org with name [$orgName], trying with user based repository list"
            $url = "https://api.github.com/users/$orgName/repos"
            $info = CallWebRequest -url $url -userName $userName -PAT $PAT
        }
    }
    else {
        Write-Debug "Finding all repos for user with name [$userName]"
        $url = "https://api.github.com/users/$userName/repos"
        $info = CallWebRequest -url $url -userName $userName -PAT $PAT
    }

    Write-Host "Found [$($info.Count)] repositories in [$orgName]"
    Write-Debug "info.GetType: [$($info.GetType())]"
    return $info
}