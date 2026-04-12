#!/bin/bash
set -euo pipefail

GOLANGCI_CONFIG=".golangci.yml"
MODULE_NAME=$(GOWORK=off go list -m)

sed "s|{{MODULE_NAME}}|${MODULE_NAME}|g" "../level85/${GOLANGCI_CONFIG}" > "$GOLANGCI_CONFIG"

golangci-lint run --config "$GOLANGCI_CONFIG" "$@"
