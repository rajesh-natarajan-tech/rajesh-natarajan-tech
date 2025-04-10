# Use a specific Ubuntu LTS version for better reproducibility
FROM ubuntu:22.04

# Set environment variables to non-interactive (avoids prompts during build)
ENV DEBIAN_FRONTEND=noninteractive

# Define argument for kubectl version (optional, defaults to latest stable)
# You can override this during build: docker build --build-arg KUBECTL_VERSION=1.28.1 .
ARG KUBECTL_VERSION="latest"

# Update package lists, install dependencies (curl, openssh-client), and clean up
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-client \
        curl  \
        jq \
        ca-certificates && \
    # Clean up APT cache to reduce image size
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -d /home/vmware-system-user  vmware-system-user
COPY   node-login.sh    /usr/local/bin/
# Download and install kubectl
RUN echo "Downloading kubectl version: ${KUBECTL_VERSION}" && \
    # Determine the actual version string (handle "latest")
    KUBECTL_ACTUAL_VERSION=$([ "${KUBECTL_VERSION}" = "latest" ] && curl -L -s https://dl.k8s.io/release/stable.txt || echo "v${KUBECTL_VERSION}") && \
    # Construct download URL
    KUBECTL_DOWNLOAD_URL="https://dl.k8s.io/release/${KUBECTL_ACTUAL_VERSION}/bin/linux/amd64/kubectl" && \
    echo "Using download URL: ${KUBECTL_DOWNLOAD_URL}" && \
    # Download kubectl binary
    curl -Lo kubectl "${KUBECTL_DOWNLOAD_URL}" && \
    # Download checksum
    curl -Lo kubectl.sha256 "${KUBECTL_DOWNLOAD_URL}.sha256" && \
    # Verify checksum
    echo "$(cat kubectl.sha256) kubectl" | sha256sum --check --status && \
    # Make kubectl executable
    chmod +x kubectl && \
    # Move kubectl to a directory in the PATH
    mv kubectl /usr/local/bin/kubectl && \
    # Remove downloaded checksum file
    rm kubectl.sha256 && \
    # Verify installation (optional)
    kubectl version --client

# Set back to default frontend
ENV DEBIAN_FRONTEND=dialog

RUN chmod +x -R  /usr/local/bin/

USER vmware-system-user
RUN echo 'source <(kubectl completion bash)' >>/home/vmware-system-user/.bashrc
RUN echo 'alias k=kubectl' >> /home/vmware-system-user/.bashrc
RUN echo 'complete -F __start_kubectl k' >> /home/vmware-system-user/.bashrc
RUN echo 'export KUBECONFIG=/secrets/kubeconfig/value' >> /home/vmware-system-user/.bashrc
RUN echo 'echo "execute  node-login.sh to login to worker nodes"'  >> /home/vmware-system-user/.bashrc
RUN echo 'bash /usr/local/bin/node-login.sh' >> /home/vmware-system-user/.bashrc

RUN mkdir -p /home/vmware-system-user/.kube/ 
# Default command to run when container starts (optional, provides a shell)
CMD ["bash"]

