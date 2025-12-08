FROM mcr.microsoft.com/powershell:7.3-alpine-3.17@sha256:cfe59bc837a0194647734278b9a31ba0078849c4386fb141406bc711cc040329

# add git
RUN apk add --no-cache git

# install Pester
RUN pwsh -Command "Install-Module -Name Pester -Force -SkipPublisherCheck"