# Appendix: embARC and Content Authenticity Provenance (CAP)

## An Evaluation of embARC and CAP metadata

embARC (Metadata Embedded for Archival Content) is the FADGI-managed, open-source, cross-platform application for auditing, validating, correcting, and extending embedded metadata in DPX and MXF files. As part of this report the authors have examined embARC as an implementation of content authenticity and provenance features and have considered what opportunities exist to expand embARC's functionality in that realm. This appendix documents the basis for those features, the options considered, the recommended approach, and implementation considerations.

embARC plays a specific role in preservation workflows surrounding the metadata embedded in DPX image sequences, generally coming from the output of a digital film scanner. DPX image sets can often be represented by hundreds of thousands of DPX image files for a feature film. As DPX image data is uncompressed each image can potentially require 50MB per image, or several terabytes per sequence, making DPX implementations often an outlier in media files in regards to per file count and total data size. The DPX header (as defined in SMPTE ST 268-1:2014 and ST 268-2:2018) carries technical and administrative metadata about the film scan and source material. The DPX metadata is stored in every file, generally containing identical data pertaining to the context of their creation. Though some fields are unique per DPX file in a sequence, such as incrementing image index numbers and embedded file names, most DPX metadata is redundantly stored across all DPX files in the sequence. FADGI has published [guidelines](https://www.digitizationguidelines.gov/guidelines/digitize-DPXembedding.html) that recommend how those fields should be populated to document digitization provenance. embARC audits DPX headers against both SMPTE conformance rules and the FADGI guidelines, and corrects non-conformant fields in batch across an entire sequence.

The FADGI guidelines for DPX embedded metadata (first published 2016, last updated April 2019) extend SMPTE ST 268 in two ways. First, they specify recommended values and clarify formatting conventions for fields that SMPTE defines structurally but leaves expression styles to implementers. Second, FADGI defines the Field 75/76 user-defined data pair as a structured digitization process history, inspired by the Broadcast WAV Coding History field.

A significant, recent refactor of embARC changes how metadata changes are applied. Rather than rewriting entire files, embARC now rewrites only the specific header byte ranges that need to change, leaving the image data region of every file untouched. In past versions of embARC, the full DPX image set was rewritten with adjusted metadata, requiring a potential rewrite of terabytes of all DPX data rather than the bytes or kilobytes of data specific to the change requested. This transition adds to the provenance and authenticity approach of embARC as the rewriting of image data is avoided where possible rather than a requirement of a metadata change process. As discussed below, this aspect of embARC's architectural design and the nature of DPX image sets relates to how C2PA support could be implemented in embARC and why some otherwise reasonable options are impractical for both embARC and for DPX.

## DPX Header Fields That Carry Provenance

embARC's metadata corrections target a defined set of DPX header fields. Several of these fields are directly scoped to content authenticity and provenance and serve as a provenance record embedded to the file and is readable by any conformant DPX parser. The table below identifies the fields with particular CAP relevance, their FADGI tier status, and the authenticity role each plays.

| Field # | Name | Byte Offset | FADGI Status | CAP Role |
|---------|------|-------------|--------------|----------|
| 9 | Image filename | 36–135 | Strongly recommended | This field is a backup of the DPX filename and associates a file to its position and order in the DPX sequence. This intentional redundancy supports auditing and checking filenames and sequence position and the discoverability of any inferred gaps in the file sequence. |
| 10 | Creation date/time | 136–159 | Strongly recommended | Records when the DPX file was created. |
| 12 | Creator | 160–259 | Strongly recommended | Identifies the institution or entity responsible for creating and preserving the DPX file. |
| 13 | Project name | 260–459 | Strongly recommended | Carries identifiers for the work represented by the sequence and may link the file to a collection management record. |
| 14 | Right to use / copyright | 460–659 | Recommended | Documents rights assertions associated with the content. |
| 37 | Source image date/time | 1532–1555 | Recommended | Records the creation date of the source material (the original film). |
| 38 | Input device name | 1556–1587 | Recommended | Scanner manufacturer and model; part of the technical provenance of the scan. |
| 39 | Input device serial number | 1588–1619 | Recommended | Scanner serial number, enabling specific identification of the capture equipment. |
| 43 | Film manufacturing ID | 1664–1665 | Optional | Encodes data from film edge codes per SMPTE ST 254; as a reference to the manufacturer of the physical film source. |
| 44 | Film type | 1666–1667 | Optional | Film stock type from edge codes. |
| 75 | User identification | 2048–2079 | Optional | This field has a local user-defined role, but in the context of the FADGI Guidelines this is a label for the "FADGI Process History" field (a FADGI recommended implementation of field 76). |
| 76 | FADGI Process History | 2080+ (up to 1MB) | Optional | Structured multi-line record encoding the complete digitization chain. This field is inspired by the Broadcast WAVE bext Coding History field and focuses on the documentation of provenace history. |

This field functions as an embedded provenance record for the digitization event. A complete Field 76 example for a scanned 16mm positive:
```
O=positive, G=16mm, C=color, S=silent, F=24, A=4:3, D=warped
O=DPXv2, L=one-light, W=10-bit, R=2K, M=RGB Log, N=VendorName, T=ScannerModelX; SN:12345; in-house
O=DPXv2, W=10-bit, R=2K, M=RGB Log
```

## C2PA and the DPX Format Support Problem

The C2PA specification defines embedding mechanisms for a specific set of formats such as JPEG, PNG, AVIF, HEIC, WebP, TIFF, MP4, MOV, PDF, WAV, MP3, and others, but not DPX. While SMPTE ST 268 does define a user-defined metadata area (Field 76), there is no standardized mechanism for embedding a JUMBF manifest store in this user section. Additionally most DPX files generated from a scanner reserve much less space for Field 76 or possibly no space at all, thus potentially adding C2PA data into Field 76 could require an existing DPX file to be rewritten. When this data rewriting is scaled over a full DPX sequence the time and data size of such a metadata addition can be far more burdensome than it would be for any of the other mentioned formats.

C2PA supports a more reasonable approach for DPX in the possibility of storing Manifest Stores external to the asset they describe, in the form of sidecar files.

### Why Embedding C2PA Data in DPX Files Is Impractical

embARC's recent refactor established that corrections are applied by rewriting only the specific header byte ranges that need to change, leaving the image data region untouched. Embedding a JUMBF manifest store in the DPX user-defined data area would require writing to a region of the file outside the specific header bytes being corrected, affecting byte offsets and potentially requiring validation of the full file structure. For a 100,000-frame sequence at roughly 50MB per frame, any approach that requires extending the metadata header can require terabytes of I/O for what would otherwise be a basic metadata operation.

There is also a challenge with C2PA manifest sizing. A collection-level C2PA manifest for 100,000 files could require 6–8MB of CBOR-encoded assertion data. Distributing manifest content across 100,000 separate file headers would require a different manifest per file, expanding every file in the sequence. A sidecar C2PA approach would achieve the same provenance goals without the burdensome costs associated with embedded this data.

## 4. Options Considered

Four options were considered for adding C2PA support to DPX.

**Option 1: Per-file sidecar manifests.** Here a separate `.c2pa` file could be generated alongside each DPX file, with the same base filename. Each sidecar could contain a C2PA manifest with a `c2pa.hash.data` assertion hashing the full DPX file (or the image data portion with appropriate exclusions), a `c2pa.actions` assertion recording what embARC did, and claim generator information identifying embARC. For a potentially 100,000 file DPX sequence this would produce 100,000 sidecar files, doubling the file count of the directory. Each sidecar would require an individual signing operation. Such an approach would be specification compliant but operationally burdensome at scale.

**Option 2: Sequence-level sidecar manifest using collection data hashing.** Here a single .c2pa sidecar could be generated for the entire DPX sequence. The manifest uses the c2pa.hash.collection.data assertion (see [C2PA spec §18.8](https://spec.c2pa.org/specifications/specifications/2.4/specs/C2PA_Specification.html#_collection_data_hash)), which hashes each file in the sequence individually and stores the results in a single signed manifest. Per the C2PA specification: "Each file in the collection shall be hashed individually using the specific hash algorithm defined in the alg field. The resultant hash value shall be stored in the hash field of the uri-hashed-data-map associated with the uri to the file."

In this approach, there is one signing operation for the entire sequence, but one hash computation per file. However, here the C2PA specification provides a significant constraint. The c2pa.hash.collection.data assertion hashes the entire content of each file as the specification says "the hash shall be over all bytes (from 0 to n) of the content item — no exceptions." The uri-hashed-data-map entries carry only the fields uri, hash, and optional size, dc:format, and data_types; however, there are no per-entry exclusions for the hasing. This is a significant difference from the single-file c2pa.hash.data assertion, which does support an exclusions array of byte-range maps to skip over defined portions of a file such as an embedded manifest or a format-specific header.

This means the DPX header cannot be excluded from the hash scope within a collection data hash assertion. As a result, any embARC operation that modifies DPX header fields will invalidate the hash for each frame, and those frames' entries in the manifest must be recomputed and the manifest re-signed after each embARC modification.

If header-exclusion is a hard requirement at the format level, the only C2PA-compliant path is c2pa.hash.data with per-file exclusions, which means one manifest (or one manifest ingredient) per DPX frame. Issues undert this scenario are detailed under Option 3.

**Option 3: Propose DPX as a C2PA-supported format.** FADGI or other entities could consider proposing including DPX in the C2PA specification to define a mechanism for embedding C2PA data. DPX's user-defined data area could accommodate a JUMBF manifest store. However, such an approach would be burdensome if it required extending the header to increase the user data section, so an efficient implementation of such an approach would require coordinating with the film scanners or tools that initiate the DPX file to reserve a sizable header section to hold the manifest.

**Option 4: Non-standard embedding in the user-defined data area.** embARC could write a JUMBF manifest store or a URI pointing to a manifest into the DPX user-defined data area as an embARC/FADGI-specific convention, without waiting for formal standardization. Beyond the operational and input/output costs described above, this creates an informal implementation that may conflict with any future formal standardization. Additionally such an approach would be largely undiscoverable by other tools.

## 5. Recommended Approach: Sequence-Level Sidecar (Option 2)

A sequence-level sidecar approach using `c2pa.hash.collection.data` seems to be the most intuitive and efficient; however the lack of byte range exclusions for hashing within `c2pa.hash.collection.data` makes hard-binding a challenge without costly hash recomputations at each metadata edit. As the C2PA specification is currently evolving there may be some opportunity to collaborate with C2PA maintainers on clarifying a strategy that balances authenticity and efficiency. Option 2 would also maps naturally to how DPX sequences are managed; as sequences rather than as individual files. The approach also produces one manageable authenticity document per sequence and is fully compliant to the related specifications and recommendations of SMPTE ST 268, the FADGI guidelines for DPX embedded metadata, and the C2PA Technical Specifications. This approach also permits per-file integrity verification without a requirement of per-file signing. Additionally this approach would not require any change to embARC's byte-range editing methodology as the sidecar C2PA file would be written alongside the sequence rather than into the DPX files.

If hard-binding is a requirement to C2PA feature development in embARC that option 2 with a coordinated resolution of the hard-binding limits would be the recommendation, else consideration could be given to the other specification compliant options.

**Example sidecar placement for Option 2:**
```
/scans/
  Example_Film_Reel1/
    Example_Film_Reel1_000001.dpx
    Example_Film_Reel1_000002.dpx
    ...
    Example_Film_Reel1_100000.dpx
    Example_Film_Reel1.wav
  Example_Film_Reel1.c2pa
```

A simplified representation of the manifest structure (actual encoding is CBOR/JUMBF):

```json
{
  "claim_generator": "embARC/2.0",
  "claim_generator_info": [
    { "name": "embARC", "version": "2.0" }
  ],
  "assertions": [
    {
      "label": "c2pa.actions",
      "data": {
        "actions": [
          {
            "action": "gov.digitizationguidelines.metadata_update",
            "description": "DPX header metadata updated per FADGI guidelines. Image data not modified.",
            "parameters": {
              "fields_modified": [
                "Field 12 Creator",
                "Field 13 Project name",
                "Field 76 FADGI Process History"
              ],
              "image_data_modified": false
            }
          }
        ]
      }
    },
    {
      "label": "c2pa.hash.collection.data",
      "data": {
        "alg": "sha256",
        "uris": [
          {
            "uri": "MyFilm_Reel1/MyFilm_Reel1_000001.dpx",
            "hash": "e3b0c44298fc1c149afb..."
          },
          {
            "uri": "MyFilm_Reel1/MyFilm_Reel1_000002.dpx",
            "hash": "a665a45920422f9d417e..."
          }
        ]
      }
    }
  ]
}
```

### The Ingredients Problem at Scale

C2PA's ingredients model provides the methods to document custody chains. A new manifest can reference prior manifests from source materials as ingredients, preserving a verifiable provenance chain across multiple operations. For DPX sequences, this creates a specific problem.

A 2-hour feature film at 24fps produces approximately 172,800 individual DPX frames. If each file were treated as a C2PA ingredient in a subsequent operation, as the C2PA specification implies, then the resulting manifest would contain 172,800 ingredient references. While the specification supports this architecturally, it can become operationally unwieldy and produces impractically-sized manifests.

A practical alternative for consideration is to treat the prior sequence-level C2PA sidecar as a single ingredient. If a DPX sequence already has a sequence-level sidecar from a prior embARC operation, a subsequent operation could reference that sidecar as a single ingredient rather than referencing each frame individually. This method could model the semantics correctly, where the ingredient is the sequence rather than its individual frames.

Such an approach requires that the prior operation must have produced a sequence-level sidecar to reference. For existing collections with no prior C2PA history, the ingredients chain simply begins with the first embARC operation that generates a manifest.

**Advantages of the ingredient model:**
- Preserves a verifiable chain of custody across multiple operations on the same DPX sequence.
- Allows validators to trace the provenance history of a sequence back through multiple embARC operations.
- Scales the C2PA's design efficiently for multi-step workflows.

**Cons at DPX scale:**
- If implemented as per-file ingredients, the process can produce unmanageable manifests for long-form content.
- Requires more consistent sidecar management discipline.
- Nearly doubles the already substantial file counts involved in DPX sequences.
- Chains that span format migrations (DPX to ProRes, for example) require C2PA support in both formats or a sidecar-to-embedded transition at the point of migration.

The sequence-as-ingredient model is the recommended approach and could be documented as a convention in embARC's C2PA implementation guidance.

## C2PA Actions in Scope for embARC

Given that the design of embARC specifically avoids any edit to image content but only focuses on edits to the DPX header metadata, only a subset of the C2PA actions vocabulary is relevant.

The C2PA standard defines a set of actions including `c2pa.created`, `c2pa.opened`, `c2pa.edited`, `c2pa.resized`, `c2pa.cropped`, `c2pa.color_adjustments`, `c2pa.transcoded`, `c2pa.repackaged`, `c2pa.placed`, `c2pa.removed`, and `c2pa.redacted`. Of these, `c2pa.repackaged` is the closest standard action to a metadata-only header edit as it is defined as changing the container file format without transcoding. However, the specification defines `repackaing` as a move from one container to another. While this defines how original versions of embARC worked, by rewriting DPX files in full upon metadata modifications; however, recent versions of embARC edit metadata in place which doesn't fit the C2PA's descriptiosn on repackaging actions.

A custom FADGI-defined action, such as `gov.digitizationguidelines.metadata_update`, could be more semantically precise for embARC's operations and would avoid the ingredient requirement that `c2pa.repackaged` imposes. Custom actions are permitted by the specifications and defining a FADGI action vocabulary for archival metadata operations could form the basis of practical community contributions or proposals to ongoing C2PA specification development.

**Actions in scope for embARC:**
- Metadata update (custom `gov.digitizationguidelines.metadata_update` or a `gov.digitizationguidelines.metadata_update`): embARC updates DPX header fields without modifying image data.
- Batch header correction: same as above, applied across a sequence as a single action.
- Audit/validation: embARC auditing and other actions to assess or report on DPX sequences without modifying them.

**Actions out of scope:**
- `c2pa.edited`: implies content modification which is out of scope to embARC.
- `c2pa.transcoded`: implies format or encoding conversion which is out of scope to embARC.
- `c2pa.color_adjustments`: implies pixel modifications that are out of scope to embARC.
- `c2pa.created`: embARC does not create DPX files, but if the DPX creator generated a sequence-level C2PA manifest sidecar, then embARC could document subsequent actions there. Additionally, initializing a C2PA manifest at the point of creation would facilitate more efficient hashing.

Action parameters should always record `image_data_modified: false` to make explicit that only header data was changed.

## embARC as Claim Generator vs. Manifest Consumer

embARC can participate in C2PA in two distinct roles.

**As a claim generator:** As embARC performs a metadata operation on a DPX sequence, it could generate a C2PA sidecar manifest documenting the action, which fields were modified, and which files were affected, with each file individually hashed. The manifest could also be signed with the institution's signing credential. This is the provenance-creating role and requires decisions about signing infrastructure and credential management.

**As a manifest consumer:** embARC could read and display existing C2PA sidecar manifests associated with DPX sequences, presenting the provenance history alongside its assessment results. This allows operators to see not just the current state of the header metadata but the history of documented operations. This role requires no signing credential.

The two roles could be considered and/or implemented seperately. Displaying existing C2PA manifests is certainly the simpler feature to develop and could be implemented first as a read-only feature in an initial release. Generating and signing manifests could follow, after institutional signing infrastructure and naming conventions are established.

## Implementation Notes and Release Considerations

The current development plans for embARC include at least one major release for all platforms and builds (Windows and Mac, CLI and GUI) with regression testing to demonstrate application stability and external user testing for overall functionality feedback. Minor versions follow as needed for bug fixes, security patches, and limited improvements.

Potential read-only manifest read and display features would be a contained change that can be regression-tested against existing audit and correction behavior with minimal risk of interference. The manifest generator feature would be an addition to the existing embARC workflows and can be controlled via a configuration option so that existing workflows that do not use C2PA are unaffected. Neither feature requires changes to embARC's byte-range editing model, which is core to its efficiency and for reducing risk to image data.

## A Draft Proposal of embARC Command Line Options for C2PA

embARC's CLI currently supports batch metadata header auditing and updating. The following proposed flags extend that interface to support both C2PA claim generation and manifest consumption, with no impact on existing option behavior.

### Options for C2PA Manifest Consumer

--c2pa-read
    Read and display any C2PA sidecar manifest associated with the input DPX
    sequence. Presents provenance history alongside embARC's standard audit
    results.

--c2pa-read-format=text|json|xml
    Output format for the manifest report produced by --c2pa-read.
      text   Human-readable summary (default)
      json   Machine-readable JSON representation of the manifest
      xml    XML representation suitable for integration with embARC's
             existing XML export pipeline

--c2pa-validate
    Verify the cryptographic signature and hash integrity of an existing C2PA
    sidecar against the current state of the DPX sequence files. Reports
    which files pass or fail their hash check and whether the manifest
    signature is valid. Exit code is non-zero if any file fails verification and the verification status is summarized.

--c2pa-sidecar=<path>
    Explicitly specify the .c2pa sidecar file to read or validate, rather
    than relying on the default discovery convention (sequence directory /
    sequence name .c2pa).

### Options for C2PA Claim Generation

```shell
--c2pa-generate
    Generate a sequence-level C2PA sidecar manifest (.c2pa) after completing
    any metadata audit or correction operation. The manifest is written
    alongside the DPX sequence directory. Requires --c2pa-sign or a configured
    signing credential in the embARC configuration file.

--c2pa-sign=<credential_path>
    Path to the signing credential (PEM-encoded certificate and private key, or
    reference to a KMS/HSM endpoint) used to sign the generated manifest.
    Required when --c2pa-generate is specified and no default credential is
    configured.

# note that --c2pa-hash-scope would only be relevant for C2PA documentation of individual DPX files and not sequences.
--c2pa-hash-scope=image-data|full-file
    Controls which portion of each DPX file is hashed in the
    c2pa.hash.collection.data assertion.
      image-data  Hash only the image data region, excluding the DPX header
                  bytes. This allows subsequent header-only edits by embARC
                  without requiring rehashing (default).
      full-file   Hash the complete DPX file including the header. Any
                  subsequent header edit will invalidate these hashes.

--c2pa-alg=sha256|sha384|sha512
    Cryptographic hash algorithm to use for the collection data hash
    assertion. Defaults to sha256.

--c2pa-action=<label>
    Override the default action label recorded in the c2pa.actions assertion.
    Defaults to gov.digitizationguidelines.metadata_update.

--c2pa-description=<text>
    Free-text description to include in the action's description field,
    supplementing the structured parameters recorded automatically.

--c2pa-ingredient=<sidecar_path>
    Reference an existing C2PA sidecar from a prior embARC operation as an
    ingredient in the new manifest. Enables chain-of-custody documentation
    across multiple operations on the same sequence. If omitted, a new chain is
    started.

--c2pa-no-sign
    Generate an unsigned manifest structure for review or testing. The
    resulting .c2pa file is not valid for verification but can be inspected
    before committing to a signing operation.

--c2pa-out=<path>
    Write the generated sidecar to an explicit path rather than the default
    (sequence directory / sequence name .c2pa).
```

### embARC C2PA Command Line Examples

```shell
# Audit sequence, correct header fields, and generate a signed C2PA sidecar:
embarc --correct --fields=12,13,76 \
       --c2pa-generate --c2pa-sign=/etc/embarc/fadgi_embarc_signing.pem \
       /scans/Example_Film_Reel1/

# Generate a sidecar that chains from a prior operation:
embarc --correct --fields=76 \
       --c2pa-generate --c2pa-sign=/etc/embarc/fadgi_embarc_signing.pem \
       --c2pa-ingredient=/scans/Example_Film_Reel1/Example_Film_Reel1.c2pa \
       /scans/Example_Film_Reel1/

# Read and display existing provenance alongside an audit report:
embarc --audit --c2pa-read /scans/Example_Film_Reel1/

# Validate sidecar integrity after transfer:
embarc --c2pa-validate /scans/Example_Film_Reel1/
```