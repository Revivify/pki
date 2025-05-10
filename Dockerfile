# Stage 1: Get cfssl binaries from the official Cloudflare image
FROM cfssl/cfssl AS cfssl_source

# - ca-certificates: for general SSL/TLS functionality, good to have

# Copy cfssl and cfssljson binaries from the cfssl_source stage
# These are the tools your Makefile uses.

# Set the working directory inside the container
WORKDIR /app

# Copy your Makefile and the config directory into the container's working directory
COPY Makefile .
COPY config ./config/

# The Makefile's 'api' target starts cfssl serve with '-address 127.0.0.1'.
# For Docker, the server needs to listen on '0.0.0.0' to be accessible from outside the container.
# This command modifies the Makefile within the image to use the correct address.
RUN sed -i 's/-address 127.0.0.1/-address 0.0.0.0/' Makefile

# Set a default API_PORT environment variable.
# This value is used in the CMD directive and can be overridden when you run the container
# (e.g., using 'docker run -e API_PORT=xxxx').
ENV API_PORT=8888

# Expose the default port the application will listen on.
# This is mainly for documentation; the actual port is determined by API_PORT.
# You'll map this port when you run the container.
EXPOSE 8888

# Define the entrypoint to allow CMD to be a string that's easily processed.
ENTRYPOINT ["sh", "-c"]

# Default command to run when the container starts.
# This executes 'make api'. The 'api' target in your Makefile should handle
# the generation of necessary CA certificates and then start the cfssl server.
# We pass API_PORT=${API_PORT} to 'make' so that it uses the value of the
# API_PORT environment variable (either the default 8888 or one you provide at runtime).
CMD ["make api API_PORT=${API_PORT}"]