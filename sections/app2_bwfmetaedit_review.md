# Appendix: BWF MetaEdit and Content Authenticity Provenance (CAP)

## An Evaluation of BWF MetaEdit and CAP Metadata

BWF MetaEdit is the FADGI-managed, open-source, cross-platform application for importing, editing, embedding, and exporting metadata in Broadcast WAVE Format (BWF) audio files. BWF MetaEdit supports editing the embedded metadata elements of the bext (Broadcast Extension) chunk as defined by EBU Technical Document 3285, LIST-INFO chunks, the cues chunk, aXML chunk, iXML chunk, and a selection of others. BWF MetaEdit integrates a number of metadata policies and recommendations (particularly the FADGI Guidelines for Embedded Metadata in Broadcast WAVE Files) and permits to user to select which policies to adhere to. Unlike DPX sequences, which may span hundreds of thousands of individual image files, a BWF audio file is a single self-contained file, making C2PA integration more feasible. The C2PA Technical Specifications also define how to embed C2PA manifests into a BWF file.

## BWF's Embedded Metadata and Provenance Fields

The bext chunk carries several fields directly relevant to provenance documentation:

| Field               | Role |
|---------------------|------|
| Description         | Free-text description of the audio content or the digitization event. |
| Originator          | Institution or entity responsible for the file. |
| OriginatorReference | Unique identifier for the file within the originator's system. |
| OriginationDate / OriginationTime | When the file was created or captured in time. |
| TimeReference       | A timeline reference or expression of timecode. |
| CodingHistory       | A multi-line structured record of the signal chain and processing history. |
| UMID                | A Unique Material IDentifier, ideally providing globally unique identification. |

BWF MetaEdit also supports evaluating and embedding an MD5 checksum of the audio data chunk (the data chunk payload only, not the full file), providing a built-in integrity binding to the audio bitstream independent of the surrounding RIFF/WAVE structure. This MD5 feature is directly analogous to C2PA's hard-binding hash assertion.

## C2PA and the WAV Format

Unlike DPX, WAV (and by extension BWF) is a C2PA-supported format. The C2PA Technical Specification defines an embedding mechanism for WAV files, allowing a JUMBF manifest store to be embedded directly in the file.

BWF MetaEdit's current architecture applies metadata edits by rewriting the metadata chunks in place or, moving the metadata chunk to the end of the file when more space is needed, or, in certain cases, by rewriting the full file. The last option is generally avoidable as a full file rewrite significantly increase the amount of time for a metadata operation in BWF MetaEdit, but if a user opts to follow an EBU requirement that the bext chunk precede the data chunk (selected via a preference setting) then oftentimes a full rewrite of the file is required. An embedded C2PA manifest is sensitive to any file rewrite, since the manifest's hard-binding hash covers a defined byte range of the file. Any subsequent bext edit that rewrites the file would invalidate a previously embedded manifest unless the manifest is regenerated as part of that operation.

## Options Considered

**Option 1: Embedded C2PA manifest in the WAV JUMBF box.** Since WAV is a supported C2PA format, BWF MetaEdit could embed a full JUMBF manifest store directly in the file. This is specification-compliant and allows any C2PA-capable validator to verify the file without requiring a sidecar. The challenge here would be that any metadata edit to the BWF file that would require a rewrite of the data chunk would require the manifest to also be regenerated and re-signed as the data offsets of the hashed audio data would change even if the hash did not. BWF MetaEdit's own MD5 chunk feature anticipates this pattern (metadata edits don't affect the audio data chunk, so the MD5 stays valid), but a C2PA hash for the audio data of the file would also have to properly manage byte exclusion ranges to clarify where the audio data is. A potential version of BWF MetaEdit with features to embed and maintain C2PA manifests could include information to the user on the consequences of editing metadata within BWF files while attempting to adhere to the EBU policy to store the bext chunk before the data chunk.

The C2PA Technical Specification requires that the C2PA chunk be placed last within the overall RIFF chunk of the BWF file. This implies that any metadata edit which requires additional space than what is stored would require BWF MetaEdit to both rewrite the full C2PA chunk and update the byte exclusion ranges.

With this option, BWF MetaEdit could also manage a preference on whether a metadata edit should be noted in an existing C2PA chunk or not. For example, for a BWF with embedded C2PA, a user could edit a bext field and the C2PA data could still be verified as per its signature and hard binding to the audio data. However, to participate fully in the provenance chain of C2PA, BWF MetaEdit should add claims to the C2PA manifest to document its action to modify metadata. It is recommended that BWF MetaEdit's claim generation be a feature that can be disabled or enabled, as metadata modifications would require the hash of the audio data to be re-computed.

**Option 2: WAV sidecar manifest.** A sidecar with the audio data hashing keeps the original manifest cryptographically valid across bext edits (the audio bytes it bound to are unchanged), but C2PA's provenance model expects each editing action to be documented by a new signed update manifest. So while the original manifest doesn't break, a fully C2PA-compliant workflow still produces a new update manifest, and recomputes the audio-data hash, for each bext edit. The re-signing operation itself is cheap (milliseconds), but the hash re-computation requires one full audio-data read per edit. For workflows with iterative bext refinement, batching edits and generating one update manifest per session, or generating the manifest only at workflow completion, is recommended to avoid per-edit hash overhead.

**Option 3: Hybrid — sidecar for initial operations, embedded for finalization.** For active working files undergoing iterative bext corrections, another option could be to maintain a sidecar manifest that hashes the audio data chunk. Then at the point of final delivery or deposit, the full manifest could be regenerated and embedded in the WAV file itself, covering the complete final state of the file. This provides the benefits of embedded provenance for long-term preservation while avoiding re-sign overhead during active editing.

## Recommended Approach

Option 1 is recommended for BWF MetaEdit's initial C2PA implementation. This would require the definition of an action label for BWF MetaEdit operations, such as `gov.digitizationguidelines.metadata_update`, (ideally kept in sync with the proposed embARC action). Options would need to be added in order to coordinate the relationship between user preferences to follow or ignore the EBU recommendation to place the bext chunk before the data chunk and to whether or not to use C2PA to document metadata changes. Also whereas DPX would set `image_data_modified` to false, BWF MetaEdit would set `audio_data_modified` to false.

## Relationship Between BWF MetaEdit's MD5 and C2PA Hard Binding

BWF MetaEdit can already embed a MD5 checksum to document the data chunk, providing integrity verification of the audio bitstream scoped to the same region C2PA's audio-data-scoped hash would cover. These two mechanisms are complementary rather than redundant:

| Feature   | BWF MetaEdit MD5                              | C2PA Hard Binding                                      |
|-----------|-----------------------------------------------|--------------------------------------------------------|
| Scope     | Audio data chunk only                         | Configurable (full file or audio data chunk only)      |
| Algorithm | MD5 (legacy; collision vulnerabilities known) | SHA-256 or stronger                                    |
| Signed    | No — embedded hash only, no signature         | Yes, cryptographically signed by a credentialed actor  |
| Verifiable by third parties | Only with the file and knowledge of the convention     | Yes, by any C2PA validator  |
| Chain of custody            | No                                                     | Yes, ingredients model supports multi-step provenance |

BWF MetaEdit could document this relationship explicitly in its C2PA output; for example, recording the existing MD5 value as an assertion parameter alongside the C2PA hash, for cross-reference by validators who know the BWF MetaEdit convention.

## Proposed Command Line Options for BWF MetaEdit C2PA Integration

### Claim Generator Options

```bash
--c2pa-embed
    Generate and embed a C2PA manifest (.wav.c2pa) after completing the
    requested metadata operation. Requires a configured signing credential.

--c2pa-sign=<credential_path>
    Path to the signing credential (PEM-encoded certificate and private key,
    or reference to a KMS/HSM endpoint). Required when --c2pa-generate is
    specified without a configured default.

--c2pa-alg=sha256|sha384|sha512
    Hash algorithm for the hard-binding assertion. Defaults to sha256.

--c2pa-action=<label>
    Override the default action label. Defaults to
    gov.digitizationguidelines.metadata_update.

--c2pa-description=<text>
    Free-text description for the action's description field.

--c2pa-include-md5
    Include the existing BWF MetaEdit MD5 value (if present in the bext
    chunk) as an assertion parameter in the generated manifest, for
    cross-reference by validators.

--c2pa-ingredient=<sidecar_path>
    Reference an existing C2PA sidecar from a prior BWF operation as an
    ingredient. Enables chain-of-custody when using BWF across a range of
    applications which include C2PA sidecar generation.

--c2pa-no-sign
    Generate an unsigned manifest for review. Not valid for verification.

--c2pa-out=<path>
    Write the sidecar to an explicit path.
```

### Manifest Consumer Options

```bash
--c2pa-read
    Read and display any C2PA sidecar or embedded manifest associated with
    the input WAV file(s). Presented alongside BWF MetaEdit's standard
    metadata report. Read-only; no file modification. No signing credential
    required.

--c2pa-read-format=text|json|xml|csv
    Output format for the manifest report.
      text   Human-readable summary (default)
      json   Machine-readable JSON
      xml    XML, suitable for inclusion in BWF MetaEdit's existing XML
             export pipeline
      csv    CSV row(s) appended to BWF MetaEdit's standard CORE export

--c2pa-validate
    Verify the cryptographic signature and hash integrity of an existing
    C2PA manifest against the current state of the WAV file(s). Reports
    pass/fail per file and overall signature validity. Exit code is non-zero
    if any file fails.

--c2pa-sidecar=<path>
    Explicitly specify the .c2pa sidecar file to read or validate.
```

### Example Commands

```bash
# Edit bext fields and generate a signed C2PA sidecar:
bwfmetaedit --Originator="Library of Congress" \
            --CodingHistory="A=ANALOGUE,M=mono,T=Studer A810;SN:12345" \
            --c2pa-generate --c2pa-sign=/etc/bwfmetaedit/loc_signing.pem \
            Example_Recording_001.wav

# Embed MD5 (audio data) and generate a C2PA sidecar in the same pass:
bwfmetaedit --MD5-embed --c2pa-generate --c2pa-include-md5 \
            --c2pa-sign=/etc/bwfmetaedit/loc_signing.pem \
            Example_Recording_001.wav

# Generate a session-level collection sidecar across a batch:
bwfmetaedit --c2pa-generate --c2pa-batch-sidecar \
            --c2pa-sign=/etc/bwfmetaedit/loc_signing.pem \
            /audio/Example_Session/*.wav

# Read existing provenance alongside standard metadata report:
bwfmetaedit --out-core --c2pa-read Example_Recording_001.wav

# Validate integrity after transfer:
bwfmetaedit --c2pa-validate /audio/Example_Session/*.wav
```
