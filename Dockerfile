FROM jc21/nginx-proxy-manager:2

# Install autossh (to maintain SSH tunnels), SSH client and sshpass for password authentication.
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends -o Dpkg::Options::="--force-confold" \
    openssh-client \
    autossh \
    sshpass \
    procps \
    netcat-openbsd \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create necessary directories.
RUN mkdir -p /ssh-tunnel/keys

# Copy script and configuration.
COPY ./ssh-tunnel/script/tunnel.sh /ssh-tunnel/script/tunnel.sh

# Ensure the script is executable.
RUN chmod +x /ssh-tunnel/script/tunnel.sh

# Create s6 service for SSH tunnel initialization.
RUN mkdir -p /etc/s6-overlay/s6-rc.d/ssh-tunnel/dependencies.d
COPY ./ssh-tunnel/s6/s6-ssh-tunnel-type /etc/s6-overlay/s6-rc.d/ssh-tunnel/type
COPY ./ssh-tunnel/s6/s6-ssh-tunnel-dependencies_base /etc/s6-overlay/s6-rc.d/ssh-tunnel/dependencies.d/base
COPY ./ssh-tunnel/s6/s6-ssh-tunnel-run /etc/s6-overlay/s6-rc.d/ssh-tunnel/run

# Enable the service in the user bundle.
RUN chmod +x /etc/s6-overlay/s6-rc.d/ssh-tunnel/run && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/ssh-tunnel