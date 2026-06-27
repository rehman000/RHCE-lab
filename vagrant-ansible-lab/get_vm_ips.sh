#!/bin/bash

for vm in $(vagrant status | awk '/running/ {print $1}'); do
  echo -n "$vm: "
  vagrant ssh $vm -c "hostname -I" 2>/dev/null | tr -d '\r'
done
