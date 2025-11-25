# Use official Redis image which includes redis-benchmark
FROM redis:7-alpine


# Install bash, python3, pip, and other utilities
RUN apk add --no-cache bash coreutils grep findutils python3 py3-pip

# Create app directory
WORKDIR /app

# Copy benchmark scripts
COPY run-benchmark.sh /app/
COPY config.sh /app/
COPY profiles/ /app/profiles/

# Copy two-step test script
COPY run-two-step-test.sh /app/


# Make scripts executable
RUN chmod +x /app/run-benchmark.sh /app/run-two-step-test.sh
# Set up Python venv and install redis-py
RUN python3 -m venv /app/.venv && \
	/app/.venv/bin/pip install --upgrade pip && \
	/app/.venv/bin/pip install redis

# Set environment variable so scripts use venv by default
ENV PATH="/app/.venv/bin:$PATH"

# Create results directory
RUN mkdir -p /app/results

# Set the entrypoint
ENTRYPOINT ["/bin/bash"]
CMD ["/app/run-benchmark.sh"]
