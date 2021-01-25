

# example calls:
# .\update-fork.ps1 -orgName "rajbos-actions" -userName "xxx" -PAT $env:GitHubPAT $issueTitle "Parent repository for [rajbos/azure-docs] has updates available"

param (
    [string] $orgName,
    [string] $userName,
    [string] $PAT,
    [string] $issuesRepository,
    [string] $issueTitle
)

# include local library code
. .\github-calls.ps1

function ParseIssueTitle {
    param (
        [string] $issueTitle
    )

    $start = $issueTitle.IndexOf("[")+1;
    $end =  $issueTitle.IndexOf("]");

    $fork = $issueTitle.Substring($start, $end-$start)
    Write-Host "Found fork repo name to update [$fork]"
    return $fork
}

$sourceDirectory = "source"

function UpdateFork {
    param (
        [string] $fork,
        [string] $PAT
    )

    $forkUrl = GetForkCloneUrl -fork $fork -PAT $PAT

    # create new temp dir to hold the fork
    New-Item -ItemType Directory $sourceDirectory
    Set-Location $sourceDirectory
    git clone $forkUrl .

    #temp check
    ls

    $parent = GetParentInfo -fork $fork
    Write-Host "Found forks parent with url [$($parent.parentUrl)]"

    # add remote to the parent
    git remote add github $parent.parentUrl

    # fetch the changes from the parent
    git fetch github

    # make sure you are on the right branch
    Write-Host "Pulling all changes from the parent on branch [$($parent.parentDefaultBranch)]"
    git checkout $parent.parentDefaultBranch

    # merge in any changes from the branch
    git merge github/$($parent.parentDefaultBranch)

    # push the changes back to your repo
    Write-Host "Pushing changes back to fork"
    git push

    Write-Host "Completed fork update"
}

function Main {
    $fork = ParseIssueTitle -issueTitle $issueTitle
    UpdateFork -fork $fork -PAT $PAT

    Write-Host "Cleaning up"
    Set-Location ..
    Remove-Item -Force -Recurse $sourceDirectory
}

# uncomment for local testing
$issueTitle = "Parent repository for [rajbos/tweetinvi] has updates available"; $PAT=$env:GitHubPAT

Main
