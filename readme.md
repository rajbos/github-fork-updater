This repository has been created to facilitate updating your forked repository, especially when having a separate organization for your forked GitHub Actions.

# Steps
1. Fork this repository to your own organization.
1. Add a repository secret named `PAT_GITHUB` containing a GitHub Personal Access Token with these scopes: `public_repo, read:org, read:user, repo:status, repo_deployment`
1. Trigger the `check-workflow.yml` workflow manually for the first run or wait for the schedule to run

# Schedule runs
The scheduled runs are planned at weekdays, at 7 AM.

# check-workflow.yml
The check-workflow will iterate all repositories in the same organization (or user) and find the ones that are forks of another repository (called parent repository). For the forks it will check if there are updates available in the parent repository and if so, create new issues in this repository (GitHubForkUpdater) with a link to verify those changes. 

Note: This workflow can be triggered manually or will run on a schedule.

# update-workflow.yml
After reviewing the changes in the parent repository, you can decide to pull in those changes into your own fork. Adding the label `update-fork` on the issues created from the `check-workflow` workflow will trigger the `update-workflow` to pull in those changes, comment that it has been updated on the issue and then close the issue.

Note: currently only the `default branch` will be updated.
