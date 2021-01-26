

# example calls:
# .\update-fork.ps1 -orgName "rajbos-actions" -userName "xxx" -PAT $env:GitHubPAT $issueTitle "Parent repository for [rajbos/azure-docs] has updates available"

param (
    [string] $orgName,
    [string] $userName,
    [string] $PAT,
    [string] $issuesRepository,
    [string] $issueTitle,
    [int] $issueId,
    [string] $repoName
)

# include local library code
. $PSScriptRoot\github-calls.ps1

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
    git merge github/$($parent.parentDefaultBranch) --ff

    # push the changes back to your repo
    Write-Host "Pushing changes back to fork"
    git push

    Write-Host "Completed fork update"
}

function Main {
    param (
        [string] $issueTitle,
        [string] $PAT,
        [int] $issueId,
        [string] $repoName
    )

    Write-Host "Starting the update for issue with title [$issueTitle] having number [$issueId] on repository [$repoName] and a PAT that has length [$($PAT.Length)]"

    $fork = ParseIssueTitle -issueTitle $issueTitle
    AddCommentToIssue -number $issueId -message "Updating the fork with the incoming changes from the parent repository" -repoName $repoName -PAT $PAT
    UpdateFork -fork $fork -PAT $PAT

    Write-Host "Cleaning up"
    Set-Location ..
    Remove-Item -Force -Recurse $sourceDirectory

    # make sure we are back where we started (for easier local testing)
    Set-Location $PSScriptRoot

    AddCommentToIssue -number $issueId -message "Fork has been updated" -repoName $repoName -PAT $PAT
    CloseIssue -number $issueId -issuesRepositoryName $repoName -PAT $PAT
}

# uncomment for local testing
#$issueTitle = "Parent repository for [rajbos/pickles] has updates available"; $PAT=$env:GitHubPAT; $repoName = "rajbos/github-fork-updater"; $issueId = 24

Main -issueTitle $issueTitle -PAT $PAT -issueId $issueId -repoName $repoName