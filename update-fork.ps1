# example calls:
# .\update-fork.ps1 -orgName "rajbos-actions" -userName "xxx" -PAT $env:GitHubPAT $issueTitle "Parent repository for [rajbos/azure-docs] has updates available"
param (
    [string] $orgName,
    [string] $userName,
    [string] $PAT,
    [string] $issuesRepository,
    [string] $issueTitle
)


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

function GetForkCloneUrl {
    param (
        [string] $forkUrl,
        [string] $PAT
    )

    return "https://xx:$PAT@github.com/$fork.git"
}

function UpdateFork {
    param (
        [string] $fork,
        [string] $PAT
    )

    $forkUrl = GetForkCloneUrl -fork $fork -PAT $PAT
    mkdir source
    cd source
    git clone $forkUrl .

    # add remote to the parent

    # pull the parent

    # merge the incoming changes
}

# uncomment for local testing
#$issueTitle = "Parent repository for [rajbos/azure-docs] has updates available"; $PAT=$env:GitHubPAT

$fork = ParseIssueTitle -issueTitle $issueTitle
UpdateFork -fork $fork -PAT $PAT

Write-Host "Cleaning up"
cd ..
del source --force