# Pinned image digests

Every container image in `compose/docker-compose.yml` is pinned by SHA256 digest. **Do not bump a digest without a PR review and a `CHANGELOG.md` entry.**

## Current digests

| Image | Tag | Digest | Last verified |
|-------|-----|--------|---------------|
| `wazuh/wazuh-manager` | 4.9.0 | `sha256:REPLACE_WITH_DIGEST` | 2026-08-10 |
| `wazuh/wazuh-indexer` | 4.9.0 | `sha256:REPLACE_WITH_DIGEST` | 2026-08-10 |
| `wazuh/wazuh-dashboard` | 4.9.0 | `sha256:REPLACE_WITH_DIGEST` | 2026-08-10 |
| `ubuntu` | 22.04 | `sha256:REPLACE_WITH_DIGEST` | 2026-08-10 |
| `fast/talon` | dev | (built locally, no remote digest) | n/a |

## How to verify

```bash
# Pull the image and grab the digest
docker pull wazuh/wazuh-manager:4.9.0
docker inspect --format='{{index .RepoDigests 0}}' wazuh/wazuh-manager:4.9.0
```

## How to verify the running stack matches

```bash
bin/fast verify
```

`bin/fast verify` recomputes the digest for each pinned image and fails on drift. The result is appended to `logs/installer.log`.
