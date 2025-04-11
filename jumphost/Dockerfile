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
# Set back to default frontend
ENV DEBIAN_FRONTEND=dialog

RUN chmod +x -R  /usr/local/bin/

USER vmware-system-user

# Default command to run when container starts (optional, provides a shell)
CMD ["bash"]

