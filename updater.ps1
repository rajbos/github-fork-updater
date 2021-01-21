$repoUrl = "https://api.github.com/repos/rajbos-actions/test-repo"


function FindRepoOrigin {
    param (
        [string] $repoUrl
    )

    $result = Invoke-WebRequest -Uri $repoUrl
        
    $info = ($result.Content | ConvertFrom-Json)

    if ($false -eq $info.fork) {
        Write-Error "The repo with url [$repoUrl] is not a fork"
        throw
    }

    Write-Host "INFO: Forks default branch = [$($info.parent.default_branch)] [$($info.parent.branches_url)] with last push [$($info.pushed_at)]"
    Write-Host "Found parent [$($info.parent.html_url)] of repo [$repoUrl], last push was on [$($info.parent.pushed_at)]"

    $defaultBranch = $info.parent.default_branch
    $parentDefaultBranchUrl = $info.parent.branches_url -replace "{/branch}", "/$($defaultBranch)"
    Write-Host "INFO: Branches url for default branch: " $parentDefaultBranchUrl

    if ($info.pushed_at -lt $info.parent.pushed_at) {
        Write-Host "There are new updates on the parent available"
    }

    # find the compare url
    # https://github.com/rajbos-actions/test-repo/compare/main...rajbos:main
    $compareUrl = "https://github.com/$($info.full_name)/compare/$defaultBranch..$($info.parent.owner.login):$defaultBranch"
    Write-Host "You can compare the default branches using this link: $compareUrl"

    return @{
        parentUrl = $info.parent.html_url
        defaultBranch = $defaultBranch
        lastPushRepo = $info.pushed_at
        lastPushParent = $info.parent.pushed_at
        updateAvailable = ($info.pushed_at -lt $info.parent.pushed_at)
    }
}


$parent = FindRepoOrigin -repoUrl $repoUrl
if ($null -ne $parent) {
    Write-Host "The repo is forked and the fork is from [$($parent.parentUrl)]"
    return $parent.updateAvailable
}

return $false