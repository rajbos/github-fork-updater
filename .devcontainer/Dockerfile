FROM mcr.microsoft.com/powershell:7.3-alpine-3.17

# add git
RUN apk add --no-cache git

# install Pester
RUN pwsh -Command "Install-Module -Name Pester -Force -SkipPublisherCheck"