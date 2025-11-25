#!/bin/bash
# Install memtier_benchmark on Ubuntu
set -e

sudo apt-get update
sudo apt-get install -y build-essential autoconf automake libpcre3-dev libevent-dev pkg-config zlib1g-dev git libssl-dev

cd /tmp
if [ ! -d memtier_benchmark ]; then
  git clone https://github.com/RedisLabs/memtier_benchmark.git
fi
cd memtier_benchmark

git checkout 1.4.0 || true  # Use a stable release if needed
autoreconf -ivf
./configure
make -j"$(nproc)"
sudo make install

# Verify installation
memtier_benchmark --version
