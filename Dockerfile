FROM ubuntu:22.04

##
## TODO - reduce the number of layers in this by consolidating RUN cmds
##

# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    git \
    iputils-ping \
    gnupg \
    lsb-release \
    sudo \
  && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get -y upgrade

RUN curl -LsS https://aka.ms/InstallAzureCLIDeb | bash \
  && rm -rf /var/lib/apt/lists/*

RUN az extension add --name azure-devops

# Can be 'linux-x64', 'linux-arm64', 'linux-arm', 'rhel.6-x64'.
ENV TARGETARCH=linux-x64

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    zip \
    apt-transport-https \
    software-properties-common

# buildkit
# WORKDIR /buildkit
# RUN wget https://github.com/moby/buildkit/releases/download/v0.12.4/buildkit-v0.12.4.linux-amd64.tar.gz
# RUN tar xvf buildkit-v0.12.4.linux-amd64.tar.gz
# RUN  ln -s /buildkit/bin/buildctl /usr/local/bin/buildctl

WORKDIR /azp

# python
RUN apt-get install -y python3 python3-pip python3-setuptools && sudo ln -s /usr/bin/python3 /usr/bin/python

#install AWS cli
RUN apt-get install -y \
        groff \
        less \
    && pip3 install --upgrade pip

RUN pip3 --no-cache-dir install --upgrade awscli

# Terraform
RUN wget -O tf.zip "https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip" && \
    unzip tf.zip && \
    rm -f tf.zip && \
    mv terraform /usr/local/bin

# Terragrunt
RUN wget -O terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/v0.55.12/terragrunt_linux_amd64" && \
    chmod a+x terragrunt && \
    mv terragrunt /usr/local/bin

# Trivy
RUN wget https://github.com/aquasecurity/trivy/releases/download/v0.50.1/trivy_0.50.1_Linux-64bit.deb && \
    dpkg -i trivy_0.50.1_Linux-64bit.deb && \
    rm -rf trivy_0.50.1_Linux-64bit.deb

#install yq
RUN wget https://github.com/mikefarah/yq/releases/download/v4.30.8/yq_linux_amd64 \
    && mv ./yq_linux_amd64 /usr/bin/yq \
    && chmod +x /usr/bin/yq

#install helm
RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

#install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && mv ./kubectl /usr/bin/kubectl \
    && chmod +x /usr/bin/kubectl

# dotnet sdk
# this needs to be installed before powershell due to a bug in packages-microsoft-prod.deb
RUN sudo apt-get install -y dotnet-sdk-7.0

#install powershell core
RUN wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb
RUN apt-get update \
    && apt-get install -y powershell

# pwsh modules
RUN pwsh -c "Install-Module Az.Accounts,Az.DesktopVirtualization,Az.Resources,SqlServer -Force -Repository PSGallery -Scope AllUsers"

# enable the "universe" repositories
RUN add-apt-repository -y universe

# java
RUN apt-get install -y openjdk-17-jdk openjdk-17-jre

# postgres
RUN apt-get install -y postgresql-client

# chrome
RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
RUN apt install ./google-chrome-stable_current_amd64.deb -y
ENV CHROME_BIN=/usr/bin/google-chrome-stable

# TODO - CodeQL -- currently busted so not including

# node.js (latest stable, but maybe ought to lock it to a specific version)
RUN sudo mkdir -p /etc/apt/keyrings && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_21.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
RUN sudo apt update
RUN sudo apt install nodejs -y

#install podman
RUN apt-get -y install podman

#install docker cli
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update \
    && apt-get install -y docker-ce-cli

# Install Azure Artifacts Credential Provider
RUN curl -L https://raw.githubusercontent.com/Microsoft/artifacts-credprovider/master/helpers/installcredprovider.sh  | sh

####################################################################################################################################################

# final update
RUN apt-get update && apt-get -y upgrade

# Create and swith to non-root user
RUN groupadd -g "10000" azuredevops
RUN useradd --create-home --no-log-init -u "10000" -g "10000" azuredevops
RUN apt-get update \
    && echo azuredevops ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/azuredevops \
    && chmod 0440 /etc/sudoers.d/azuredevops
RUN sudo chown -R azuredevops /azp
RUN sudo chown -R azuredevops /home/azuredevops

USER azuredevops

# Required by Azure DevOps for running as a container job
# See: https://docs.microsoft.com/en-us/azure/devops/pipelines/process/container-phases?view=azure-devops#linux-based-containers
LABEL "com.azure.dev.pipelines.agent.handler.node.path"="/usr/local/bin/node"
