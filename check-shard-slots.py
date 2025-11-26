
#!/usr/bin/env python3


import redis
import os
from collections import defaultdict
import binascii

def key_slot(key):
    # Redis Cluster hash slot calculation
    # If the key contains {...}, only hash what's inside
    if '{' in key and '}' in key:
        start = key.find('{') + 1
        end = key.find('}', start)
        if end > start:
            key = key[start:end]
    k = key.encode('utf-8')
    crc = binascii.crc_hqx(k, 0)  # CRC16
    return crc % 16384

def get_env_var(name, default=None):
    val = os.environ.get(name)
    if val is None:
        return default
    return val

REDIS_HOST = get_env_var("REDIS_HOST")
REDIS_PORT = int(get_env_var("REDIS_PORT", 6379))
REDIS_PASSWORD = get_env_var("REDIS_PASSWORD")
USE_SSL = get_env_var("USE_SSL", "false").lower() == "true"

# Connect to the cluster
r = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    password=REDIS_PASSWORD,
    ssl=USE_SSL
)


print("Slot Range             Num Slots   Keys in Range   Master IP:PORT")


# Collect slot ranges and master mapping
slot_ranges = []  # (slot_start, slot_end, master_id)
master_map = {}   # master_id -> (ip, port)
for slot in r.cluster('slots'):
    slot_start, slot_end = slot[0], slot[1]
    master = slot[2]
    master_ip, master_port = master[0].decode(), master[1]
    master_id = f"{master_ip}:{master_port}"
    slot_ranges.append((slot_start, slot_end, master_id))
    master_map[master_id] = (master_ip, master_port)

# Scan all keys from all master nodes
slot_key_counts = defaultdict(int)
key_slot_map = defaultdict(list)
for master_id, (master_ip, master_port) in master_map.items():
    connect_host = REDIS_HOST if USE_SSL else master_ip
    try:
        master_r = redis.Redis(
            host=connect_host,
            port=master_port,
            password=REDIS_PASSWORD,
            ssl=USE_SSL
        )
        cursor = 0
        while True:
            cursor, keys = master_r.scan(cursor, count=1000)
            for key in keys:
                if isinstance(key, bytes):
                    key = key.decode()
                slot = key_slot(key)
                slot_key_counts[slot] += 1
                key_slot_map[slot].append(key)
            if cursor == 0:
                break
    except Exception as e:
        print(f"Error scanning {master_id}: {e}")

# For each slot range, sum up keys in that range
for slot_start, slot_end, master_id in slot_ranges:
    keys_in_range = 0
    for slot in range(slot_start, slot_end + 1):
        keys_in_range += slot_key_counts.get(slot, 0)
    print(f"{slot_start:<6}-{slot_end:<6}         {slot_end-slot_start+1:<10} {keys_in_range:<15} {master_id}")
