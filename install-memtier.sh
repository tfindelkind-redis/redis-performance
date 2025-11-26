#!/bin/bash
# Install memtier_benchmark on Ubuntu
set -e

sudo apt-get update
sudo apt-get install -y build-essential autoconf automake libpcre3-dev libevent-dev pkg-config zlib1g-dev git libssl-dev


# Always install memtier_benchmark version 2.1.4 from source
cd /tmp
rm -rf memtier_benchmark
git clone https://github.com/RedisLabs/memtier_benchmark.git
cd memtier_benchmark
git checkout 2.1.4
autoreconf -ivf
./configure
make -j"$(nproc)"
sudo make install

# Verify installation
memtier_benchmark --version
