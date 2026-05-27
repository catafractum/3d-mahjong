#!/usr/bin/env sh
set -eu

for file in index.wasm index.pck index.js; do
  if [ ! -f "$file" ]; then
    echo "Missing $file" >&2
    exit 1
  fi

  brotli -f -q 11 "$file"
  gzip -k -9 -f "$file"
done
