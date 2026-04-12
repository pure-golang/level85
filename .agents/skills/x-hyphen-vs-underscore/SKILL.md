---
name: "x-hyphen-vs-underscore"
description: "Используй дефисы (`-`) для внешней среды и нижние подчеркивания (`_`) для внутренних механизмов Go"
---
# Naming Priority: Hyphen vs Underscore

## 1. The "Import Rule" (Critical)
- **Use Underscore (`_`)** or **SingleWord** for any folder containing `.go` files.
- **NEVER use Hyphen (`-`)** for Go packages. It breaks the package identifier and forces manual aliasing in every import.

## 2. The "Unix Standard" (Preferred)
- **Use Hyphen (`-`)** for everything outside the Go toolchain:
    - Shell, Python, or Ruby scripts.
    - Root-level directories that don't contain code (e.g., `docs-site/`, `ci-cd/`).
    - Configuration files (YAML, TOML, JSON).
    - Deployment manifests (Kubernetes, Terraform).
    - Documentation (.md).

## 3. The "Go File Standard" (Mandatory)
- **Use Underscore (`_`)** for all `.go` files.
- Pattern: `feature_logic.go`, `processor_worker_test.go`.

## Decision Matrix
| Object | Preferred Style | Example |
| :--- | :--- | :--- |
| Go Package Folder | `lowercase` / `_` | `internal/user_api` |
| Go Source File | `underscore` | `request_handler.go` |
| CLI Scripts | `hyphen` | `scripts/db-migrate.sh` |
| DevOps / Infra | `hyphen` | `k8s/api-deployment.yaml` |
| Documentation (.md) | `hyphen` | `docs/setup-guide.md` |

