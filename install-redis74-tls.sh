#!/bin/bash
# Build and install Redis 7.4.x with TLS (OpenSSL) support on Ubuntu
set -e

# Install build dependencies
sudo apt-get update
sudo apt-get install -y build-essential tcl wget libssl-dev

# Download Redis 7.4.0 (update version if needed)
cd /tmp
wget https://download.redis.io/releases/redis-7.4.0.tar.gz

tar xzf redis-7.4.0.tar.gz
cd redis-7.4.0


# Clean previous build if exists, then build Redis with TLS support
make distclean || true
make BUILD_TLS=yes -j$(nproc)

# Optionally run tests (can skip if you want)
# make test


# Install binaries (redis-server, redis-cli, redis-benchmark, etc.)
sudo make install


# Verify installation
redis-server --version
redis-cli --version
redis-benchmark --help | grep tls || echo "TLS support not found!"

# Create marker file so this script only runs once if automated
touch "$HOME/.redis74_installed"
