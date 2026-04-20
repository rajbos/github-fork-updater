# Copilot Instructions for github-fork-updater

## Project Overview
This repository is a PowerShell-based tool to check and update GitHub forks. It uses the GitHub API to find forks that are behind their upstream and creates issues or updates them automatically.

## Tech Stack
- **Language**: PowerShell
- **Testing**: Pester (tests in `unittests/`)
- **CI/CD**: GitHub Actions

## Key Files
- `updater.ps1` — main entry point
- `update-fork.ps1` — fork update logic
- `github-calls.ps1` — GitHub API call wrappers
- `library.ps1` — shared utility functions
- `unittests/updater.tests.ps1` — Pester unit tests

## Conventions
- Use PowerShell best practices and follow PSScriptAnalyzer recommendations
- Keep GitHub API calls in `github-calls.ps1`
- Add Pester tests for any new functions in `unittests/`
- All workflows should pin action versions to a full SHA and include a version comment
- Use `step-security/harden-runner` in all workflow jobs
