# gh-pr-radar

[![CI](https://github.com/sandeep780049/gh-pr-radar/actions/workflows/ci.yml/badge.svg)](https://github.com/sandeep780049/gh-pr-radar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/sandeep780049/gh-pr-radar)](https://github.com/sandeep780049/gh-pr-radar/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![gh extension](https://img.shields.io/badge/gh-extension-blue)](https://cli.github.com)
[![Stars](https://img.shields.io/github/stars/sandeep780049/gh-pr-radar?style=social)](https://github.com/sandeep780049/gh-pr-radar/stargazers)

**One command to see every open PR you've authored across all of GitHub** — CI status, review state, merge blockers and staleness, sorted by what needs you most.

![gh-pr-radar demo](demo.gif)

```
$ gh pr-radar
REPO                          PR       CI        REVIEWS           STATE       AGE     TITLE
kestra-io/kestra              #20153   passing   no-reviews        clean       1d      feat(executions): add resume-from-breakpoint ...
vitest-dev/vitest             #11203   passing   no-reviews        clean       2mo     fix(benchmark): restore relative scores in ...
opensearch-project/OpenSearch #23089   mixed     awaiting-review   behind      1mo     Fix WLM monitor-mode workload group ...
```

No more clicking through 8 orgs checking dashboards. One line per PR, worst-first ordering: conflicts → changes-requested → failing CI → blocked → awaiting-review → no-reviews → behind → clean.

## Why

If you contribute to more than two or three repos, your open PRs live in eight different dashboards. `gh pr list` only covers one repo. The GitHub notifications page buries CI failures under noise. `gh-pr-radar` answers the only question that matters: **which of my PRs needs me right now?**

## Install

Requires [gh](https://cli.github.com) (authenticated) and `jq`.

```bash
gh extension install sandeep780049/gh-pr-radar
```

Then run anywhere:

```bash
gh pr-radar
```

## Usage

```bash
gh pr-radar                 # all your open PRs, worst-first
gh pr-radar --repo kestra   # only PRs in repos matching "kestra"
gh pr-radar --json          # newline-delimited JSON (pipe to jq)
gh pr-radar --limit 500     # fetch more PRs (default 200)
```

### JSON output

`--json` emits one object per PR — handy for scripting, status bars, cron digests:

```json
{"prio":2,"repo":"vitest-dev/vitest","number":11203,"ci":"failing","reviews":"no-reviews","state":"CLEAN","draft":false,"ageDays":47,"title":"fix(benchmark): ...","url":"https://github.com/..."}
```

## How ranking works

| prio | meaning |
|------|---------|
| 0 | merge conflicts (`DIRTY`) — nothing else matters until you rebase |
| 1 | `changes-requested` review — maintainer waiting on you |
| 2 | CI failing — fix before anyone reviews |
| 3 | `BLOCKED` — failing required checks or missing approvals |
| 4 | review requested but none yet |
| 5 | no reviews at all |
| 6 | `BEHIND` — safe, but a rebase would help mergeability |
| 7 | clean — nothing to do, wait patiently |

Ties broken by oldest update first.

## Limitations

- `gh search prs --author @me` covers PRs where you're the author; PRs you co-authored under another account aren't included.
- Check rollups and reviews are fetched per-PR (one API call each), so ~50 PRs ≈ a few seconds. `--limit` caps it.
- Comments/issue bodies are never fetched or displayed — the radar is metadata-only by design.

## Development

```bash
./tests/run_tests.sh   # stubbed-gh test suite, no network
```

The test suite runs the script against a stubbed `gh` + `jq` fixture, so it needs no network and no auth.

### Regenerating the demo

`demo.gif` is rendered from `demo.cast`, which replays real `gh pr-radar` output captured to `.tmp/`:

```bash
gh pr-radar --limit 5 > .tmp/out_full.txt
gh pr-radar --repo kestra --limit 3 > .tmp/out_kestra.txt
python tools/make_cast.py demo.cast
agg --font-size 15 --theme dracula demo.cast demo.gif   # agg: asciinema/agg
```

## License

MIT
