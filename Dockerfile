# Use the base image for code-server
FROM ubuntu:24.04

# github-releases:argoproj/argo-cd
ARG ARGOCD_VERSION=3.1.8
# github-releases:cli/cli
ARG GHCLI_VERSION=2.81.0
# github-releases:golang/go
ARG GOLANG_VERSION=1.24.4
# github-releases:helm/helm
ARG HELM_VERSION=3.19.0
# github-releases:arttor/helmify
ARG HELMIFY_VERSION=0.4.18
# github-releases:derailed/k9s
ARG K9S_VERSION=0.50.15
# managed manually, must match the cluster :)
ARG KUBECTL_VERSION=1.33.2
# github-releases:kubernetes-sigs/kustomize
ARG KUSTOMIZE_VERSION=5.6.0
# github-releases:PowerShell/PowerShell
ARG POWERSHELL_VERSION=7.5.3
# managed manually
ARG PYTHON_VERSION=3.12
# github-releases:stern/stern
ARG STERN_VERSION=1.32.0
# github-releases:hashicorp/terraform
ARG TERRAFORM_VERSION=1.13.3
# github-releases:terraform-linters/tflint
ARG TFLINT_VERSION=0.59.1

# Install necessary tools for Dockerfile development and rootless Docker
USER root

# Set non-interactive frontend for debconf to avoid tzdata prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install additional tools and dependencies
RUN  set -eux; apt-get update && apt-get install -y \
    --no-install-recommends \
    software-properties-common \
    bash-completion \
    unzip \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION%%.*}-venv \
    python${PYTHON_VERSION%%.*}-pip \
    curl \
    git \
    vim \
    openssh-server \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    # Install k9s
    curl -fsSL https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_amd64.tar.gz | tar -C /usr/local/bin/ -xz && rm /usr/local/bin/LICENSE /usr/local/bin/README.md && \
    # Install ArgoCD CLI
    curl -fsSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64" && \
    chmod +x /usr/local/bin/argocd && \
    # Install Go
    curl -fsSL https://golang.org/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xz && \
    ln -s /usr/local/go/bin/go /usr/bin/go && \
    mkdir -p /go/bin && chmod -R 777 /go && chown -R ubuntu:ubuntu /go && \
    # Fix Python symlinks for compatibility
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    ln -sf /usr/bin/python${PYTHON_VERSION%%.*}-pip /usr/bin/pip3 && \
    # Install Helm, Helmify, kustomize, kubectl, stern
    curl -fsSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar -xz && mv linux-amd64/helm /usr/local/bin/helm && \
    curl -fsSL https://github.com/arttor/helmify/releases/download/v${HELMIFY_VERSION}/helmify_Linux_x86_64.tar.gz |tar -C /usr/local/bin/ -xz && \
    curl -fsSL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz|tar -C /usr/local/bin/ -xz && \
    curl -LO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && chmod +x kubectl && mv kubectl /usr/local/bin/ && \
    curl -fsSL https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_amd64.tar.gz|tar -C /usr/local/bin/ -xz && rm /usr/local/bin/LICENSE && \
    # Install Terraform, TFLint
    curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o terraform.zip && unzip terraform.zip && mv terraform /usr/local/bin/ && rm terraform.zip && \
    curl -fsSL https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip -o tflint.zip && unzip tflint.zip && mv tflint /usr/local/bin/ && rm tflint.zip &&\
    # Install PowerShell
    curl -fsSL https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell-${POWERSHELL_VERSION}-linux-x64.tar.gz | tar -xz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/pwsh && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    # Install Starship
    curl -sS https://starship.rs/install.sh | sh -s -- --yes && \
    # Install GitHub CLI
    curl -fsSL https://github.com/cli/cli/releases/download/v${GHCLI_VERSION}/gh_${GHCLI_VERSION}_linux_amd64.tar.gz | tar -xz -C /tmp && mv /tmp/gh_${GHCLI_VERSION}_linux_amd64/bin/gh /usr/bin/ && rm -rf /tmp/gh_${GHCLI_VERSION}_linux_amd64

# Ensure SSH runtime directory and proper configuration
RUN mkdir -p /var/run/sshd && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Add script to populate /home/ubuntu with default skeleton if necessary
COPY populate_home.sh /usr/local/bin/populate_home.sh
RUN chmod +x /usr/local/bin/populate_home.sh

# Add entrypoint script to handle authorized keys and generate host keys at runtime
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Define a volume for SSH host keys
VOLUME ["/etc/ssh"]

# Switch back to the non-root user
USER ubuntu

ENV PATH=$PATH:/go/bin
ENV GOPATH=/go

LABEL org.opencontainers.image.authors="Tim Krehan"
LABEL org.opencontainers.image.description="Development environment for infrastructure-as-code with Go, Python, Kubernetes, Terraform, and related tools."
LABEL GOLANG_VERSION=${GOLANG_VERSION} \
      HELM_VERSION=${HELM_VERSION} \
      KUBECTL_VERSION=${KUBECTL_VERSION} \
      TERRAFORM_VERSION=${TERRAFORM_VERSION} \
      TFLINT_VERSION=${TFLINT_VERSION} \
      POWERSHELL_VERSION=${POWERSHELL_VERSION} \
      ARGOCD_VERSION=${ARGOCD_VERSION} \
      K9S_VERSION=${K9S_VERSION} \
      PYTHON_VERSION=${PYTHON_VERSION}

EXPOSE 22

# Set entrypoint to handle authorized keys and run sshd
USER root

# Set default shell to bash for user ubuntu
RUN usermod -s /bin/bash ubuntu

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]