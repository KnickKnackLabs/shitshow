<div align="center">

# shitshow

**A local-first workflow for turning private meeting recordings into reviewed records.**

Turn the shitshow into a reviewed record.

![status: incubating](https://img.shields.io/badge/status-incubating-orange?style=flat)
[![tests: 4](https://img.shields.io/badge/tests-4-brightgreen?style=flat)](test/)
![lints: 9](https://img.shields.io/badge/lints-9-blue?style=flat)
![CI: ubuntu-latest + macos-latest](https://img.shields.io/badge/CI-ubuntu--latest%20%2B%20macos--latest-4EAA25?style=flat)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat)](LICENSE)

</div>

<br />

## What this is

`shitshow` is an incubating KnickKnackLabs tool for long-form recordings that deserve deliberate review instead of one-shot summarization.

The intended first release ingests a local audio source into a private managed workspace, verifies its checksum, transcribes resumable chunks locally, reports progress, and advances review state only after a human and agent have actually reviewed the material.

It does not claim that raw ASR output is authoritative meeting minutes, and it does not generate legal, medical, financial, or other domain conclusions without human review.

## Current status

The repository currently contains only the maintained KKL skeleton and its public safety boundary. Product implementation will arrive through reviewed pull requests.

The workflow grew from private internal dogfood, but this repository starts with fresh, sanitized history. No private meeting artifacts or personal paths were imported.

## Tool boundaries

| Tool         | Owns                                                                          |
| ------------ | ----------------------------------------------------------------------------- |
| `voice`      | Microphone capture and short voice-capture artifacts                          |
| `monkeys`    | Local speech-to-text engines                                                  |
| `shitshow`   | Private meeting workspace, resumable transcription, and explicit review state |
| Domain notes | Approved conclusions and durable work products                                |
| `blobs`      | Storage transport when an operator explicitly chooses it                      |

## Privacy boundary

- Never commit recordings, transcripts, prompts, logs, credentials, meeting names, or private workspace metadata.
- Use synthetic audio and fictional metadata in tests and documentation.
- Default managed state to private local permissions and reject unsafe path or symlink boundaries.
- Keep upload, archival, and destructive storage operations outside the initial product surface.
- Recording consent and lawful use remain operator responsibilities; this tool does not provide legal advice.

See [SECURITY.md](SECURITY.md) before reporting a vulnerability or handling accidental sensitive-data exposure.

## Development

```bash
gh repo clone KnickKnackLabs/shitshow
cd shitshow
mise trust
mise install
mise run test
mise run doctor
```

Edit `README.tsx`, then run `readme build`. Do not edit generated `README.md` directly.

## Tasks

| Task              | Description                   |
| ----------------- | ----------------------------- |
| `mise run doctor` | Check local development setup |
| `mise run test`   | Run BATS tests                |

<details>
<summary><b>Current convention checks</b></summary>

The repository asks [codebase](https://github.com/KnickKnackLabs/codebase) to run these checks:

```
mise-settings
bats-test-helper
bats-test-task
mcr-scope
or-true
shellcheck
gum-table
caller-pwd-contract
github-actions
```

</details>

## Validation

```bash
mise run test
codebase lint "$PWD"
readme build --check
git diff --check
```

The bootstrap currently has **4 tests**, **2 public tasks**, and hosted validation on **ubuntu-latest and macos-latest**.

<div align="center">

---

<sub>
Generated from `README.tsx` with [KnickKnackLabs/readme](https://github.com/KnickKnackLabs/readme).<br />A reviewed record is what remains after the shitshow.
</sub></div>
