<div align="center">

<img src="assets/jeff.webp" alt="Nicolas Cage laughing on a toilet in a decrepit restroom" width="800">

# shitshow

![status: incubating](https://img.shields.io/badge/status-incubating-orange?style=flat)
[![tests: 16](https://img.shields.io/badge/tests-16-brightgreen?style=flat)](test/)
![lints: 9](https://img.shields.io/badge/lints-9-blue?style=flat)
![CI: ubuntu-latest + macos-latest](https://img.shields.io/badge/CI-ubuntu--latest%20%2B%20macos--latest-4EAA25?style=flat)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat)](LICENSE)

</div>

Long recordings are copied into private, checksum-bound workspaces and transcribed locally in resumable chunks. Transcription state and review state are separate: completed ASR means text exists; cursor advancement means someone checked it.

## Install

```bash
gh repo clone KnickKnackLabs/shitshow
cd shitshow
mise trust
mise install
```

## Run

```bash
result="$(mise run ingest recording.wav --name "Fictional planning call" --json)"
meeting_id="$(jq -r .meeting_id <<<"$result")"

mise run transcribe:start "$meeting_id"
mise run status "$meeting_id"
mise run review "$meeting_id"
mise run review:advance "$meeting_id"
```

<details>
<summary><b>Operational notes</b></summary>

- Managed meetings default to `${XDG_DATA_HOME:-$HOME/.local/share}/shitshow/meetings`.
- Directories use `0700`; files use `0600`; ingestion verifies SHA-256.
- `review` is read-only. Only `review:advance` moves the audited cursor.
- `status --json` exposes the same state to other programs.
- Never commit recordings, transcripts, prompts, logs, credentials, meeting names, or private workspace metadata.
- Recording consent and lawful use remain the operator's responsibility.

</details>

## Documentation

Public tasks include examples in `--help`. See [CONTRIBUTING.md](CONTRIBUTING.md) for the implementation and validation contract, and [SECURITY.md](SECURITY.md) for private-state and disclosure handling.

<div align="center">

---

<sub>
Generated with [KnickKnackLabs/readme](https://github.com/KnickKnackLabs/readme).
</sub></div>
