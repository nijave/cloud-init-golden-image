#!/bin/bash

set -euo pipefail

# /etc/elasticsearch/elasticsearch.yml
# cluster.name
# node.name
# cluster.initial_master_nodes

# Check each DNS entry to see if it's a master
# Register DNS
# Wait for nodes
# Start Elasticsearch
# Wait for cluster
# Remove bootstrap