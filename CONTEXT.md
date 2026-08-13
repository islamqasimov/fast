# F.A.S.T. - CONTEXT for AI Agents

> **Read this file first**, before doing anything else. You are an AI assistant working on the F.A.S.T. capstone project. This file is the canonical ruleset. The longer `docs/spec.md` (and the parent `knowledge.md`) gives the *why*; this file gives the *what you must never violate*.

## Project in one screen

F.A.S.T. (Fully Automated SIEM & Threat-intel) is a Holberton capstone. It ships two deliverables in four weeks:

1. **Deployment automation** - Docker Compose stack, installer, and `bin/fast` CLI on one Ubuntu VM.
2. **T.A.L.O.N. module** - in-house Python threat-intel pipeline (fetch / normalize / dedup / export) + dashboard.

Four people. One `dev` branch as the integration branch, feature branches off `dev`. **Never push to `main` directly.**

## Hard rules (NEVER violate, even if asked)

1. **Never edit `talon/pipeline.py` after Week 1 contract lock.** It is a fixed thin orchestrator (~30 LOC). Add new feeds in `talon/fetchers/` and new exporters in `talon/exporters/`.
2. **Never put plaintext secrets anywhere.** All secrets live under `secrets/` with mode 0600 and are referenced by file path from `etc/fast.env`.
3. **Never commit generated secrets or runtime data.** `secrets/`, `var/`, `logs/`, `etc/fast.env` are gitignored. The only env file in git is `etc/fast.env.example`.
4. **Never pin images by tag alone.** Every container image is pinned by SHA256 digest. If you add a new image, compute the digest with `docker inspect --format='{{index .RepoDigests 0}}' <image>` and record it in `docs/image-digests.md`.
5. **Never grant outbound network access to any container except `talon`.** Enforced at the host firewall (see `installer/lib/firewall.sh`). If you need a new outbound container, justify it in a PR and update the firewall script.
6. **Never touch parts of the stack you don't own.** L1 = Islam, L2 = Elmir, L3 + L4 = Nihat, L5 = Ramin. Cross-lane edits require a PR review from the lane owner.
7. **Never add a JS build step, a separate visualization stack, or a T.A.L.O.N.-specific v2 UI.** The Wazuh dashboard + T.A.L.O.N. dashboard (Flask + HTMX, port 9516) are the only UIs.
8. **Never replace cron with a long-running scheduler.** Cron is the only scheduled trigger for the T.A.L.O.N. pipeline. Cron entry is rewritten by `install.sh` on every install.
9. **Never promise HA, multi-host, or cloud-autoscaling.** The capstone target is a single VM.
10. **Never bump a dependency version without**: (a) updating `docs/image-digests.md` if it's a container image, (b) updating `CHANGELOG.md`, (c) getting a second reviewer's approval.

## Vocabulary (do not confuse)

| Term | Meaning |
|------|---------|
| **F.A.S.T.** | The capstone product (deployment automation + T.A.L.O.N.). |
| **T.A.L.O.N.** | The in-house Python threat-intel module under `talon/`. |
| **CDB list** | Wazuh constant database format for high-speed IOC lookups. |
| **Mode** | `online` (live feeds), `offline` (fixtures, default for demo), `diff` (manual diagnostic). |
| **Feed** | One of four OSINT sources: Feodo Tracker, URLhaus, MalwareBazaar, Spamhaus DROP. |
| **Cron** | Host-level scheduler at `/etc/cron.d/talon`. The only scheduled trigger. |
| **Run summary** | The JSON blob returned by `python -m talon run`. |

## How to ask a good question

If you are unsure about scope, naming, or a hard rule, **ask before editing**. Specifically:

- Question scope before adding a new feed or a new exporter.
- Question scope before changing `talon/pipeline.py`.
- Question scope before adding a dependency.
- Question scope before bumping an image digest.

## What NOT to do

- Do not "modernize" the codebase by rewriting it in a different language or framework.
- Do not add a database other than SQLite. The pipeline is stateless between runs.
- Do not skip the SECRET_POLICY check. If `bin/fast verify-secrets` fails, fix the cause.
- Do not commit `var/`, `secrets/`, or `logs/`. They are gitignored for a reason.
- Do not write integration tests that depend on the host network. Use fixtures under `tests/fixtures/`.

## Where to read next

- `docs/spec.md` - the long-form spec (mirrors the parent `knowledge.md`).
- `../tasks.md` - all 16 numbered tasks with subtasks.
- `docs/runbook.md` - operational guide (added in T4.5).
- `docs/demo.md` - 20-minute demo walkthrough (added in T4.5).
