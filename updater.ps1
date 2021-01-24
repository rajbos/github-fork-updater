# example calls:
# .\updater.ps1 -orgName "rajbos-actions" -userName "xxx" -PAT $env:GitHubPAT
param (
    [string] $orgName,
    [string] $userName,
    [string] $PAT
)

# example parameters:
#$repoUrl = "https://api.github.com/repos/rajbos-actions/test-repo"
#$orgName = "rajbos-actions"

# placeholder for caching headers
$CentralHeaders
function Get-Headers {
    param (        
        [string] $userName,
        [string] $PAT
    )

    if ($null -ne $CentralHeaders) {
        return $CentralHeaders
    }

    $pair = "$($userName):$($PAT)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"

    $CentralHeaders = @{
        Authorization = $basicAuthValue
    }

    return $CentralHeaders
}

function CallWebRequest {
    param (
        [string] $url,
        [string] $userName,
        [string] $PAT
    )

    $Headers = Get-Headers

    try {
        $result = Invoke-WebRequest -Uri $url -Headers $Headers       
        $info = ($result.Content | ConvertFrom-Json)
    }
    catch {
        $messageData = $_.ErrorDetails.Message | ConvertFrom-Json
        Write-Host "$($_.ErrorDetails.Message)"
        if ($messageData.message.StartsWith("API rate limit exceeded")) {
            Write-Error "Rate limit exceeded. Halting execution"
            throw
        }

        if ($messageData.message -eq "Not Found") {
            Write-Warning "Call to GitHub Api [$url] had [not found] result with documentation url [$($messageData.documentation_url)]"
            return $messageData.documentation_url
        }
        
        Write-Host "$messageData"
    }

    return $info

}

function FindAllRepos {
    param (
        [string] $orgName,
        [string] $userName,
        [string] $PAT
    )

    $url = "https://api.github.com/orgs/$orgName/repos"
    $info = CallWebRequest -url $url -userName $userName -PAT $PAT

    if ($info -eq "https://docs.github.com/rest/reference/repos#list-organization-repositories") {
        
        Write-Warning "Error loading information from org with name [$orgName], trying with user based repository list"
        $url = "https://api.github.com/users/$orgName/repos"
        $info = CallWebRequest -url $url -userName $userName -PAT $PAT
    }

    Write-Host "Found [$($info.Count)] repositories in [$orgName]"
    return $info
}

function FindRepoOrigin {
    param (
        [string] $repoUrl,
        [string] $userName,
        [string] $PAT
    )

    $info = CallWebRequest -url $repoUrl -userName $userName -PAT $PAT
        
    if ($false -eq $info.fork) {
        Write-Error "The repo with url [$repoUrl] is not a fork"
        throw
    }

    Write-Host "Forks default branch = [$($info.parent.default_branch)] [$($info.parent.branches_url)] with last push [$($info.pushed_at)]"
    Write-Host "Found parent [$($info.parent.html_url)] of repo [$repoUrl], last push was on [$($info.parent.pushed_at)]"

    $defaultBranch = $info.parent.default_branch
    $parentDefaultBranchUrl = $info.parent.branches_url -replace "{/branch}", "/$($defaultBranch)"
    Write-Host "Branches url for default branch: " $parentDefaultBranchUrl

    if ($info.pushed_at -lt $info.parent.pushed_at) {
        Write-Host "There are new updates on the parent available"
    }

    # build the compare url
    $compareUrl = "https://github.com/$($info.full_name)/compare/$defaultBranch..$($info.parent.owner.login):$defaultBranch"
    Write-Host "You can compare the default branches using this link: $compareUrl"

    return [PSCustomObject]@{
        parentUrl = $info.parent.html_url
        defaultBranch = $defaultBranch
        lastPushRepo = $info.pushed_at
        lastPushParent = $info.parent.pushed_at
        updateAvailable = ($info.pushed_at -lt $info.parent.pushed_at)
        compareUrl = $compareUrl
    }
}


function GetParentHasUpdatesAvailable {
    param (
        [string] $repoUrl,
        [string] $userName,
        [string] $PAT
    )

    $parent = FindRepoOrigin -repoUrl $repoUrl -userName $userName -PAT $PAT
    if ($null -ne $parent) {
        Write-Host "The repo is forked and the fork is from [$($parent.parentUrl)]"
        return $parent.updateAvailable
    }

    return $false
}


function CheckAllReposInOrg {
    param (
        [string] $orgName,
        [string] $userName,
        [string] $PAT
    )

    Write-Host "Running a check on all repositories inside of organization [$orgName] with user [$userName] and a PAT that has length [$($PAT.Length)]"

    $repos = FindAllRepos -orgName $orgName -userName $userName -PAT $PAT

    # create hastable
    $reposWithUpdates = @()

    foreach ($repo in $repos) {
        # add empty line for logs readability
        Write-Host ""
        if ($repo.fork) {
            Write-Host "Checking repository [$($repo.full_name)]"
            $repoInfo = FindRepoOrigin -repoUrl $repo.url
            if ($repoInfo.updateAvailable) {
                Write-Host "Found new updates in the parent repository [$($repoInfo.parentUrl)], compare the changes with [$($repoInfo.compareUrl)]"

                $repoData = [PSCustomObject]@{
                    repoName = $repo.full_name
                    parentUrl = $repoInfo.parentUrl
                    compareUrl = $repoInfo.compareUrl
                }

                $reposWithUpdates += $repoData
            } 
            else {
                Write-Host "No updates available from parent"
            }
        }
        else {
            Write-Host "Skipping repository [$($repo.full_name)] since it is not a fork"
        }
    }

    Write-Host "Found [$($reposWithUpdates.Count)] forks with available updates"
    return $reposWithUpdates
}

# uncomment to test locally
# $orgName = "rajbos"; $userName = "xxx"; $PAT = $env:GitHubPAT;

CheckAllReposInOrg -orgName $orgName -userName $userName -PAT $PAT
