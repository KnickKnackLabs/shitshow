<div align="center">

<img src="assets/jeff.webp" alt="Nicolas Cage laughing on a toilet in a decrepit restroom" width="800">

# shitshow

**A local-first workflow for turning private meeting recordings into reviewed records.**

Turn the shitshow into a reviewed record.

![status: incubating](https://img.shields.io/badge/status-incubating-orange?style=flat)
[![tests: 16](https://img.shields.io/badge/tests-16-brightgreen?style=flat)](test/)
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

The first local workflow provides private ingestion, resumable foreground or background transcription, machine-readable status, and explicit incremental review.

The workflow grew from private internal dogfood, but this repository starts with fresh, sanitized history. No private meeting artifacts or personal paths were imported.

## Workflow

```bash
meeting_id=$(shitshow ingest recording.wav --name "Fictional planning call" --json | jq -r .meeting_id)
shitshow transcribe:start "$meeting_id"
shitshow status "$meeting_id"
shitshow review "$meeting_id" --count 1
shitshow review:advance "$meeting_id" --count 1
```

Managed meetings live under `${XDG_DATA_HOME:-$HOME/.local/share}/shitshow/meetings`. Set `SHITSHOW_DATA_DIR` to use a different private managed store.

Review never moves the cursor. Advance it only after the printed chunks have actually been reviewed. Use `shitshow status <meeting-id> --json` for automation.

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

| Task                        | Description                                                      |
| --------------------------- | ---------------------------------------------------------------- |
| `mise run doctor`           | Check local development setup                                    |
| `mise run ingest`           | Ingest local audio into a new private meeting workspace          |
| `mise run review`           | Print completed transcript chunks at the review cursor           |
| `mise run review:advance`   | Advance review state after completed collaborative review        |
| `mise run status`           | Show recording, transcription, and review state                  |
| `mise run test`             | Run BATS tests                                                   |
| `mise run transcribe`       | Transcribe a managed meeting locally in resumable chunks         |
| `mise run transcribe:start` | Start resumable local transcription in the background            |
| `mise run transcribe:stop`  | Stop verified background transcription while preserving progress |

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

The project currently has **16 tests**, **9 public tasks**, and hosted validation on **ubuntu-latest and macos-latest**.

<div align="center">

---

<sub>
Generated from `README.tsx` with [KnickKnackLabs/readme](https://github.com/KnickKnackLabs/readme).<br />A reviewed record is what remains after the shitshow.
</sub></div>
