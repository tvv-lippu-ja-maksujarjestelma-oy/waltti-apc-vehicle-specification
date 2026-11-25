#!/bin/bash

set -Eeuo pipefail

JSON_SCHEMA_PATH='./apc-from-vehicle.schema.json'
JSON_EXAMPLE_PATH="${1:-./example-message.json}"

npm_config_yes=true \
  npx \
  --package ajv-formats@3.0.1 \
  --package ajv-cli@5.0.0 \
  ajv \
  --spec=draft2020 \
  --strict=true \
  --strict-required=true \
  -c ajv-formats \
  validate \
  -s "${JSON_SCHEMA_PATH}" \
  -d "${JSON_EXAMPLE_PATH}"
