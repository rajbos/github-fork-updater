# example calls:
# .\updater.ps1 -orgName "rajbos-actions" -userName "xxx" -PAT $env:GitHubPAT
param (
    [string] $orgName,
    [string] $userName,
    [string] $PAT,
    [string] $issuesRepository
)

# example parameters:
#$repoUrl = "https://api.github.com/repos/rajbos-actions/test-repo"
#$orgName = "rajbos-actions"

# placeholder for caching headers
$CentralHeaders
# placeholder to enable testing locally
$testingLocally = $false
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
        [string] $PAT,
        [string] $verbToUse = "Get",
        [object] $body
    )

    $Headers = Get-Headers -userName $userName -PAT $PAT

    try {

        $bodyContent = ($body | ConvertTo-Json) -replace '\\', '\'
        $result = Invoke-WebRequest -Uri $url -Headers $Headers -Method $verbToUse -Body $bodyContent -ErrorAction Stop
        
        Write-Host "  StatusCode: $($result.StatusCode)"
        Write-Host "  RateLimit-Limit: $($result.Headers["X-RateLimit-Limit"])"
        Write-Host "  RateLimit-Remaining: $($result.Headers["X-RateLimit-Remaining"])"
        Write-Host "  RateLimit-Reset: $($result.Headers["X-RateLimit-Reset"])"
        Write-Host "  RateLimit-Used: $($result.Headers["x-ratelimit-used"])"
        # convert the response json content
        $info = ($result.Content | ConvertFrom-Json)
    }
    catch {
        Write-Host "Error calling api at [$url]:"
        Write-Host "  StatusCode: $($_.Exception.Response.StatusCode)"
        Write-Host "  RateLimit-Limit: $($_.Exception.Response.Headers.GetValues("X-RateLimit-Limit"))"
        Write-Host "  RateLimit-Remaining: $($_.Exception.Response.Headers.GetValues("X-RateLimit-Remaining"))"
        Write-Host "  RateLimit-Reset: $($_.Exception.Response.Headers.GetValues("X-RateLimit-Reset"))"
        Write-Host "  RateLimit-Used: $($_.Exception.Response.Headers.GetValues("x-ratelimit-used"))"

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
        [string] $PAT,
        [string] $issuesRepository
    )

    Write-Host "Running a check on all repositories inside of organization [$orgName] with user [$userName] and a PAT that has length [$($PAT.Length)]"

    $repos = FindAllRepos -orgName $orgName -userName $userName -PAT $PAT

    # create hastable
    $reposWithUpdates = @()

    foreach ($repo in $repos) {
        # add empty line for logs readability
        Write-Host ""
        if ($repo.fork -and !$repo.archived -and !$repo.disabled) {
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
            Write-Host "Skipping repository [$($repo.full_name)] since it is not a fork or has been archived or is disabled"
        }
    }

    Write-Host "Found [$($reposWithUpdates.Count)] forks with available updates"
    return $reposWithUpdates
}

function CreateNewIssueForRepo { 
    param (
        [Object] $repoInfo,
        [string] $issuesRepositoryName,
        [string] $title,
        [string] $body,
        [string] $PAT,
        [string] $userName
    )

    $url = "https://api.github.com/repos/$issuesRepositoryName/issues"

    $data = [PSCustomObject]@{
        title = $title
        body = $body
    }

    Write-Host "Creating a new issue with title [$title] in repository [$issuesRepositoryName]"
    $result = CallWebRequest -url $url -verbToUse "POST" -body $data -PAT $PAT -userName $userName

    Write-Host "Issue has been created and can be found at this url: ($($result.html_url))"
}

function CreateIssueFor { 
    param (
        [object] $repoInfo,
        [string] $issuesRepositoryName,
        [object] $existingIssues,
        [string] $PAT,
        [string] $userName
    )

    #Write-Host "- repoName $($repoInfo.repoName)"
    #Write-Host "- parentUrl $($repoInfo.parentUrl)"
    #Write-Host "- compareUrl $($repoInfo.compareUrl)"

    $issueTitle = "Parent repository for [$($repoInfo.repoName)] has updates available"
    $existingIssueForRepo = $existingIssues | Where-Object {$_.title -eq $issueTitle}

    if ($null -eq $existingIssueForRepo) {
        $body = "The parent repository for **$($repoInfo.repoName)** has updates available. `r`n### Important!`r`nClick on this [compare link]($($repoInfo.compareUrl)) to check the incoming changes before updating the fork. `r`n `r`n### To update the fork`r`nAdd the label **update-fork** to this issue to update the fork"
        CreateNewIssueForRepo -repoInfo $repo -issuesRepositoryName $issuesRepository -title $issueTitle -body $body -PAT $PAT -userName $userName
    } 
    else {
        # the issue already exists. Doesn't make sense to update the existing issue
        # If we need to, we can send in a PATCH to the same url while adding an 'issue_number' parameter to the body
        Write-Host "Issue with title [$issueTitle] already exists"
    }
}

function CreateIssuesForReposWithUpdates {
    param(
         [object] $reposWithUpdates,
         [string] $issuesRepository,
         [string] $PAT,
         [string] $userName
    )

    # load existing issues in the issues repo    
    # https://api.github.com/repos/{owner}/{repo}/issues
    $url = "https://api.github.com/repos/$issuesRepository/issues"
    $existingIssues = CallWebRequest -url $url -userName $userName -PAT $PAT

    Write-Host "Found $($existingIssues.Count) existing issues in issues repository [$issuesRepository]"

    foreach ($repo in $reposWithUpdates) {        
        CreateIssueFor -repoInfo $repo -issuesRepository $issuesRepository -existingIssues $existingIssues -PAT $PAT -userName $userName
    }
}

function TestLocally {
    param (
        [string] $orgName,
        [string] $userName,
        [string] $PAT,
        [string] $issuesRepository
    )

    #$env:reposWithUpdates = $null
    # load the repos with updates if we don't have them available yet
    if($null -eq $env:reposWithUpdates) {
        $env:reposWithUpdates = (CheckAllReposInOrg -orgName $orgName -userName $userName -PAT $PAT -issuesRepository $issuesRepository) | ConvertTo-Json
    }

    if ($env:reposWithUpdates.Count -gt 0) {
        CreateIssuesForReposWithUpdates ($env:reposWithUpdates | ConvertFrom-Json) -issuesRepository $issuesRepository -userName $userName -PAT $PAT
    }
}

# uncomment to test locally
$orgName = "rajbos"; $userName = "xxx"; $PAT = $env:GitHubPAT; $testingLocally = $true; $issuesRepository = "rajbos/github-fork-updater"

if ($testingLocally) {
    TestLocally -orgName $orgName -userName $userName -PAT $PAT -issuesRepository $issuesRepository
}
else {
    # production flow:
    CheckAllReposInOrg -orgName $orgName -userName $userName -PAT $PAT -issuesRepository $issuesRepository
}
