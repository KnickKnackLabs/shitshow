/** @jsxImportSource jsx-md */

import {
  Bold,
  Center,
  Code,
  CodeBlock,
  Details,
  Heading,
  HR,
  Item,
  Link,
  List,
  Paragraph,
  Raw,
  Section,
  Sub,
} from "readme";

const readme = (
  <>
    <Center>
      <Raw>{`<img src="assets/jeff.webp" alt="Nicolas Cage laughing on a toilet in a decrepit restroom" width="800">\n\n`}</Raw>

      <Heading level={1}>shitshow</Heading>
      <Paragraph><Bold>Turn the shitshow into a reviewed record.</Bold></Paragraph>
      <Paragraph>Local audio. Resumable transcription. Deliberate review.</Paragraph>
    </Center>

    <Section title="A transcript is not a record.">
      <Paragraph>Speech-to-text reports what a model heard.</Paragraph>
      <Paragraph>
        Shitshow keeps the recording,
        checksum,
        chunks,
        job state,
        and review position together.
      </Paragraph>
      <Paragraph>
        Nothing becomes reviewed until you explicitly advance it.
      </Paragraph>
    </Section>

    <CodeBlock>{`audio  →  ingest  →  transcribe  →  review  →  advance`}</CodeBlock>

    <Section title="From audio to record">
      <CodeBlock lang="bash">{`result="$(mise run ingest recording.wav --name "Fictional planning call" --json)"
meeting_id="$(jq -r .meeting_id <<<"$result")"

mise run transcribe:start "$meeting_id"
mise run status "$meeting_id"
mise run review "$meeting_id"
mise run review:advance "$meeting_id"`}</CodeBlock>
      <Paragraph>
        Managed meetings live under{" "}
        <Code>{"${XDG_DATA_HOME:-$HOME/.local/share}/shitshow/meetings"}</Code>.
        Set <Code>SHITSHOW_DATA_DIR</Code> to choose another private managed store.
      </Paragraph>
    </Section>

    <Section title="Review is a state transition">
      <CodeBlock>{`review          shows what comes next
review:advance  records that review happened`}</CodeBlock>
      <Paragraph>
        Reading does not mutate review state.
        Advancement is explicit,
        locked,
        and audited.
      </Paragraph>
    </Section>

    <Details summary="Privacy and storage guarantees">
      <List>
        <Item>Recordings, transcripts, prompts, logs, credentials, and private meeting metadata stay out of Git.</Item>
        <Item>Managed directories are owner-only <Code>0700</Code>; managed files are owner-only <Code>0600</Code>.</Item>
        <Item>Ingestion copies audio atomically and verifies its SHA-256 checksum.</Item>
        <Item>Managed state does not retain absolute source-audio or prompt paths.</Item>
        <Item>Unsafe symlinks, ownership, and group or other permissions are rejected.</Item>
        <Item>Nothing implicitly uploads, archives, deletes, or writes domain conclusions.</Item>
        <Item>Recording consent and lawful use remain the operator's responsibility.</Item>
      </List>
      <Paragraph>
        See <Link href="SECURITY.md">SECURITY.md</Link> for vulnerability reporting
        and accidental sensitive-data exposure.
      </Paragraph>
    </Details>

    <Section title="One job each">
      <CodeBlock>{`voice      records
monkeys    hears
shitshow   tracks review
you        decide what becomes durable`}</CodeBlock>
    </Section>

    <Details summary="Build and verify">
      <CodeBlock lang="bash">{`gh repo clone KnickKnackLabs/shitshow
cd shitshow
mise trust
mise install
mise run test
mise run doctor`}</CodeBlock>
      <Paragraph>
        Read <Link href="CONTRIBUTING.md">CONTRIBUTING.md</Link> before changing
        product behavior,
        private-state boundaries,
        or generated documentation.
      </Paragraph>
    </Details>

    <Center>
      <HR />
      <Sub>
        Generated from <Code>README.tsx</Code> with{" "}
        <Link href="https://github.com/KnickKnackLabs/readme">KnickKnackLabs/readme</Link>.
        <Raw>{"<br />"}</Raw>
        A reviewed record is what remains after the shitshow.
      </Sub>
    </Center>
  </>
);

console.log(readme);
