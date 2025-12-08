FROM mcr.microsoft.com/powershell:7.5-alpine-3.20@sha256:a6beeddb2fcf45547c9099fba091ce231e51aa374fe62ecc182f7c28b69a6cbf

# add git
RUN apk add --no-cache git

# install Pester
RUN pwsh -Command "Install-Module -Name Pester -Force -SkipPublisherCheck"