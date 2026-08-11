# Pinned image digests

Every container image in `compose/docker-compose.yml` is pinned by SHA256 digest. **Do not bump a digest without a PR review and a `CHANGELOG.md` entry.**

## Current digests

| Image | Tag | Digest | Last verified |
|-------|-----|--------|---------------|
| `wazuh/wazuh-manager` | 4.9.0 | `sha256:e0a78683d35556465d599a923ddc2eaec38110f911fc2c82e578f7c4ab038004` | 2026-08-11 |
| `wazuh/wazuh-indexer` | 4.9.0 | `sha256:a7adcac99648b73e075c4fa8daa5bd552da46ec4a7700d7faccd579a2c5e7cc2` | 2026-08-11 |
| `wazuh/wazuh-dashboard` | 4.9.0 | `sha256:9cc37f86a1efac76c0f0ddbc955dda0bdf72517b5067f384d66bcc7d95338a6c` | 2026-08-11 |
| `ubuntu` | 22.04 | `sha256:3b06811b2afd352be909dd088a004166d665dc76d38b13eada33522a9d915c6f` | 2026-08-11 |
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
