This repository has been created to facilitate updating your forked repository, especially when having a separate organization for your forked GitHub Actions.

# Steps
1. Fork this repository to your own organization.
1. Add a repository secret named `PAT_GITHUB` containing a GitHub Personal Access Token with these scopes: `public_repo, read:org, read:user, repo:status, repo_deployment`