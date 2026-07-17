<div align="center">

<img src="assets/jeff.webp" alt="Nicolas Cage laughing on a toilet in a decrepit restroom" width="800">

# shitshow

**Turn the shitshow into a reviewed record.**

Local audio. Resumable transcription. Deliberate review.

</div>

## A transcript is not a record.

Speech-to-text reports what a model heard.

Shitshow keeps the recording, checksum, chunks, job state, and review position together.

Nothing becomes reviewed until you explicitly advance it.

```
audio  →  ingest  →  transcribe  →  review  →  advance
```

## From audio to record

```bash
result="$(mise run ingest recording.wav --name "Fictional planning call" --json)"
meeting_id="$(jq -r .meeting_id <<<"$result")"

mise run transcribe:start "$meeting_id"
mise run status "$meeting_id"
mise run review "$meeting_id"
mise run review:advance "$meeting_id"
```

Managed meetings live under `${XDG_DATA_HOME:-$HOME/.local/share}/shitshow/meetings`. Set `SHITSHOW_DATA_DIR` to choose another private managed store.

## Review is a state transition

```
review          shows what comes next
review:advance  records that review happened
```

Reading does not mutate review state. Advancement is explicit, locked, and audited.

<details>
<summary><b>Privacy and storage guarantees</b></summary>

- Recordings, transcripts, prompts, logs, credentials, and private meeting metadata stay out of Git.
- Managed directories are owner-only `0700`; managed files are owner-only `0600`.
- Ingestion copies audio atomically and verifies its SHA-256 checksum.
- Managed state does not retain absolute source-audio or prompt paths.
- Unsafe symlinks, ownership, and group or other permissions are rejected.
- Nothing implicitly uploads, archives, deletes, or writes domain conclusions.
- Recording consent and lawful use remain the operator's responsibility.

See [SECURITY.md](SECURITY.md) for vulnerability reporting and accidental sensitive-data exposure.

</details>

## One job each

```
voice      records
monkeys    hears
shitshow   tracks review
you        decide what becomes durable
```

<details>
<summary><b>Build and verify</b></summary>

```bash
gh repo clone KnickKnackLabs/shitshow
cd shitshow
mise trust
mise install
mise run test
mise run doctor
```

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing product behavior, private-state boundaries, or generated documentation.

</details>

<div align="center">

---

<sub>
Generated from `README.tsx` with [KnickKnackLabs/readme](https://github.com/KnickKnackLabs/readme).<br />A reviewed record is what remains after the shitshow.
</sub></div>
