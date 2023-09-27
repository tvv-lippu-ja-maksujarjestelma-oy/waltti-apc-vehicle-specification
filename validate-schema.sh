#!/bin/bash

set -Eeuo pipefail

JSON_SCHEMA_PATH='./apc-from-vehicle.schema.json'

npm_config_yes=true \
  npx \
  --package ajv-formats \
  --package ajv-cli \
  ajv \
  --spec=draft2020 \
  --strict=true \
  --strict-required=true \
  -c ajv-formats \
  compile \
  -s "${JSON_SCHEMA_PATH}" \
  -o \
  >/dev/null
