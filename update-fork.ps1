

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
    
    # set user settings
    git config --global user.email "noreply@githubupdater.com"
    git config --global user.name "GitHub Fork Updater"

    # create new temp dir to hold the fork
    New-Item -ItemType Directory $sourceDirectory
    Set-Location $sourceDirectory
    Write-Host "Clone fork from url [$forkUrl]"
    git clone $forkUrl .

    $parent = GetParentInfo -fork $fork -PAT $PAT
    Write-Host "Found forks parent with url [$($parent.parentUrl)]"

    # add remote to the parent
    git remote add github $parent.parentUrl

    # fetch the changes from the parent
    Write-Host "Fetching changes from parent repo"
    git fetch github $parent.parentDefaultBranch --tags

    # make sure you are on the right branch
    Write-Host "Pulling all changes from the parent on branch [$($parent.parentDefaultBranch)]"
    git checkout $parent.parentDefaultBranch

    # merge in any changes from the branch
    Write-Host "Merging changes from parent repo"
    git merge github/$($parent.parentDefaultBranch) --ff

    # check if there are any merge conflicts
    $mergeConflict = git status | Select-String "both modified"
    if ($mergeConflict) {
        Write-Host "Found merge conflicts, aborting the update"
        git merge --abort
        return 1
    }

    # push the changes back to your repo
    Write-Host "Pushing changes back to fork"
    git push origin $parent.parentDefaultBranch --tags

    Write-Host "Completed fork update"
}

function Main {
    param (
        [string] $issueTitle,
        [string] $PAT,
        [int] $issueId,
        [string] $issuesRepository
    )

    Write-Host "Starting the update for issue with title [$issueTitle] having number [$issueId] on repository [$issuesRepository] and a PAT that has length [$($PAT.Length)]"
    
    $workflowRunUrl = "$($env:GITHUB_SERVER_URL)/$($env:GITHUB_REPOSITORY)/actions/runs/$($env:GITHUB_RUN_ID)"
    Write-Host "Found workflowRunUrl: [$workflowRunUrl]"

    $fork = ParseIssueTitle -issueTitle $issueTitle
    AddCommentToIssue -number $issueId -message "Updating the fork with the incoming changes from the parent repository through [update-workflow]($workflowRunUrl)." -repoName $issuesRepository -PAT $PAT
    $forkResult = UpdateFork -fork $fork -PAT $PAT
    if ($forkResult -eq 1) {
        Write-Host "Error with the update of the fork, halting execution"
        AddCommentToIssue -number $issueId -message ":alert: Found merge conflicts, aborting the update" -repoName $issuesRepository -PAT $PAT
        return 1
    }

    Write-Host "Cleaning up"
    Set-Location ..
    Remove-Item -Force -Recurse $sourceDirectory

    # make sure we are back where we started (for easier local testing)
    Set-Location $PSScriptRoot
    
    AddCommentToIssue -number $issueId -message "Fork has been updated" -repoName $issuesRepository -PAT $PAT
    CloseIssue -number $issueId -issuesRepositoryName $issuesRepository -PAT $PAT
}

# uncomment for local testing
#$issueTitle = "Parent repository for [rajbos/pickles] has updates available"; $PAT=$env:GitHubPAT; $repoName = "rajbos/github-fork-updater"; $issueId = 24

$result = Main -issueTitle $issueTitle -PAT $PAT -issueId $issueId -issuesRepository $issuesRepository
if ($result -eq 1) {
    Write-Host "Error with the update of the fork, returning with failure"
    exit 1
}
