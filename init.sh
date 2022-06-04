#!/bin/bash

set -euo pipefail

ROLES=""
while getopts c:r: option; do
  case $option in
    c) CLUSTER=$OPTARG;;
    r) ROLES=$OPTARG;;
  esac
done

echo "$CLUSTER $ROLES"

# /etc/elasticsearch/elasticsearch.yml
# cluster.name
echo "cluster.name: $CLUSTER" >> /etc/elasticsearch/elasticsearch.yml

# node.name
if [ "$ROLES" != "" ]; then
  echo "node.roles: [ $(echo "$ROLES" | sed 's/,/, /') ]" >> /etc/elasticsearch/elasticsearch.yml
fi

sed -i '/^cluster.initial_master_nodes/d' elasticsearch.yml

# Check each DNS entry to see if it's a master
# cluster.initial_master_nodes ?

# Register DNS
# Wait for nodes
# Start Elasticsearch
# Wait for cluster
# Remove bootstrap