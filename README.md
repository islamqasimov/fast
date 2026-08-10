# F.A.S.T. - Fully Automated SIEM & Threat-intel

> Holberton capstone project: a Docker Compose-based deployment that turns one Ubuntu VM into a self-contained SOC lab (Wazuh + in-house T.A.L.O.N. threat-intel pipeline).

This README is for humans. **For AI agents, see [CONTEXT.md](./CONTEXT.md).**

## What's in the repo

```
fast/
├── compose/             Docker Compose stack (T1.2)
├── installer/           Bash installer + secret/cron/firewall helpers
├── bin/fast             Thin CLI wrapper (up, down, reset, status, demo, doctor, ...)
├── etc/                 Configuration templates (rules, decoders, fast.env)
├── secrets/             Generated secrets, mode 0600 (gitignored)
├── var/                 Mounted volumes (gitignored)
├── logs/                Installer and runtime logs (gitignored)
├── docs/                Runbook, demo script, upgrade guide
├── sim/                 Incident simulation scripts
├── tests/               Unit, integration, acceptance tests
└── README.md, CONTEXT.md
```

## Quickstart on a fresh Ubuntu VM

```bash
git clone https://github.com/<team>/fast.git
cd fast
sudo ./install.sh --mode interactive
bin/fast status
```

The installer:
1. Verifies Docker Engine 24.x and Docker Compose v2 are installed.
2. Generates secrets under `secrets/` (mode 0600, length 20+, 3 character classes).
3. Copies `etc/fast.env.example` to `etc/fast.env` if missing.
4. Installs `/etc/cron.d/talon` for daily IOC pipeline runs.
5. Sets up iptables rules so only the `talon` container has outbound access.
6. Pulls and starts the Wazuh + T.A.L.O.N. stack.

Open the dashboard at `https://<vm-host>` (or `https://localhost` if you SSH-tunneled 443).

## Daily usage

```bash
bin/fast up          # bring the stack online
bin/fast down        # stop, preserve data
bin/fast status      # container health
bin/fast demo        # run all four simulations and print pass/fail
bin/fast doctor      # run T.A.L.O.N. self-check
bin/fast verify      # recompute image digests; fail on drift
bin/fast reset --yes # destroy data volumes
```

## Architecture

One-liner: **Wazuh (manager + indexer + dashboard) + Wazuh agent on a `agent-linux` test container + an in-house Python T.A.L.O.N. pipeline that pulls from four OSINT feeds (Feodo Tracker, URLhaus, MalwareBazaar, Spamhaus DROP) and writes a Wazuh CDB list.**

```
agent-linux  ---1514--->  wazuh-manager  ---9200--->  wazuh-indexer
                                ^
                                | manager reads CDB list from
                                |
                              talon  --- writes to shared volume ---
```

For the full spec, see [docs/spec.md](./docs/spec.md) (mirrors the parent `knowledge.md` at the repo root level).

## Status

Week 1 of 4. The compose skeleton is in place; the Wazuh stack and T.A.L.O.N. are scaffolded but the `talon/` package is still to be built by Nihat.

## Team

| Person | Role | Owns |
|--------|------|------|
| Islam | Project Manager | L1 installer + CLI + cron, weekly risk register |
| Elmir | Developer | L2 Wazuh rules, decoders, dashboards |
| Nihat | Developer | L3 T.A.L.O.N. core + L4 dashboard |
| Ramin | Technical Writer | L5 simulations, runbook, demo slides |

## License

Internal capstone project.
