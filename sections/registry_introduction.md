# CAP Registry Reference

This section defines the fields and controlled vocabularies used within the entries of all three CAP registries of this environmental review: **Tools**, **Formats**, and **Mechanisms**. The registries are internally managed in XML with the intention of presenting its information in transformed reports and tables.

## Common Fields (all three registries)

### Name
The human-readable display name of the tool, format, or mechanism.

### URL
One or more reference URLs. Each URL may include an optional **type** attribute to contextualize the link:

| type value  | Meaning                                              |
|-------------|------------------------------------------------------|
| `homepage`  | Official project or product homepage                 |
| `repo`      | Source code repository (e.g. GitHub)                 |
| `spec`      | Normative specification document                     |
| `fdd`       | Library of Congress Format Description Document      |
| *(none)*    | General reference with no specific type assigned     |

### Description
Descriptions are meant to be concise and factual and give an overview on what the entry represents.

### TCR4CAP Comments
This is a structured set of observations against the six TCR4CAP assessment criteria. These are intended as descriptive and observational notes, and not as scores or editorialized reviews. All six criteria are present for each entry and it is noted when the criteria is out of scope. A short summary of each of the criteria is listed here below; see FADGI's "Framework for Tiered Community Recommendations for Content Authenticity and Provenance" (TCR4CAP) documentation for more context of any of these criteria.

| Criteria         | Scope                                                                  |
|------------------|------------------------------------------------------------------------|
| Awareness        | Whether the tool/format/mechanism has any CAP awareness                |
| Tamper Evidence  | Whether modification of content or metadata can be detected            |
| Binding          | Whether metadata is cryptographically linked to the media content      |
| AI Attribution   | Whether AI generation or training provenance can be recorded           |
| Substantiation   | Whether provenance claims can be verified against external anchors     |
| Interoperability | License, standards basis, and breadth of implementation                |

## 2. Tools Registry

Tools are software applications, libraries, SDKs, online services, or reference registries relevant to content authenticity and provenance workflows.

### Category (`type`)
This is a broad functional category of the tool.

| Value                               | Meaning                                                    |
|-------------------------------------|------------------------------------------------------------|
| `Identification Tools`              | File format identification (PRONOM/FDD signatures)         |
| `Characterization Tools`            | Technical metadata extraction and format validation        |
| `Fixity Tools`                      | Checksum computation, audit, and package integrity         |
| `Metadata Editors`                  | Tools that read and write embedded metadata                |
| `Transcoding Tools`                 | Audio/video format conversion and processing               |
| `C2PA Tools`                        | Tools with native C2PA manifest support                    |
| `Digital Preservation Systems`      | End-to-end preservation workflow systems                   |
| `Watermarking Tools`                | Content-level imperceptible watermarking                   |
| `Metadata Standards and Registries` | Authoritative format or metadata registries                |

### Version
The current (as of the writing of this document) release version of the tool in ISO 8601 format (`YYYY-MM-DD`).

### License
The software license under which the tool is distributed. Examples: `Apache-2.0`, `MIT/Apache-2.0`, `GPL-2.0`, `LGPL-2.1`, `CC0-1.0`, `Public Domain`, `AGPL-3.0`, `Proprietary`

### Provenance Scope
The level at which the tool operates with respect to provenance.

| Value            | Meaning                                                         |
|------------------|-----------------------------------------------------------------|
| `file-level`     | Operates on individual files                                    |
| `package-level`  | Operates on packages or collections of files (e.g. BagIt bags)  |
| `content-level`  | Operates on the content signal itself (e.g. watermarking)       |
| `n/a`            | Not applicable                                                  |

### C2PA Support
The degree to which the tool supports the C2PA specification.

| Value            | Meaning                                                              |
|------------------|----------------------------------------------------------------------|
| `full`           | Full C2PA manifest creation, signing, embedding, and verification    |
| `detect-parse`   | Can detect and parse C2PA manifests but cannot sign or verify        |
| `none-official`  | No official C2PA support; experimental forks may exist               |
| `none`           | No C2PA support                                                      |

---

## 3. Formats Registry
Formats are file formats or metadata standards relevant to content authenticity and provenance. This includes container formats (BWF, MP4), image formats (JPEG, PNG), and metadata formats (XMP, PREMIS, BagIt).

### Type
The broad media or metadata category of the format.

| Value      | Meaning                                              |
|------------|------------------------------------------------------|
| `audio`    | Audio container or codec format                      |
| `video`    | Video container format                               |
| `image`    | Still image format                                   |
| `metadata` | Metadata standard or packaging format                |

### Structure
The internal structural model of the format.

| Value            | Meaning                                                    |
|------------------|------------------------------------------------------------|
| `binary-chunk`   | Binary format organised as named chunks (e.g. RIFF/WAVE)   |
| `binary-block`   | Binary format organised as typed blocks (e.g. FLAC)        |
| `binary-segment` | Binary format organised as typed segments (e.g. JPEG)      |
| `binary-atom`    | Binary format organised as nested atoms/boxes (e.g. MP4)   |
| `binary-ebml`    | Binary format using EBML encoding (e.g. Matroska)          |
| `binary`         | Generic binary format (e.g. TIFF IFD)                      |
| `cbor-jumbf`     | CBOR-encoded data in a JUMBF container (C2PA manifest)     |
| `xml-rdf`        | RDF/XML serialisation (XMP)                                |
| `xml-xmp`        | XMP-carried vocabulary (IPTC Photo Metadata)               |
| `xml`            | Generic XML (PREMIS, METS)                                 |
| `text-manifest`  | Plain-text manifest files (BagIt)                          |

### Readability (`type` attribute)
Whether the format specification is openly available.

| Value         | Meaning                                                               |
|---------------|-----------------------------------------------------------------------|
| `open`        | Specification is publicly available with no licensing restrictions    |
| `open-spec`   | Open published specification; reference implementation is open-source |

### Verifiability (`type` attribute)
The highest level of integrity or authenticity verification the format supports.

| Value                      | Meaning                                                        |
|----------------------------|----------------------------------------------------------------|
| `cryptographically-signed` | Cryptographic signing with hard binding to content             |
| `tamper-evident`           | Checksum-based detection of modification (no signing)          |
| `integrity-only`           | Fixity values present but no signing or provenance chain       |
| `none`                     | No integrity or authenticity mechanism                         |

### C2PA Support Modes
A format may support C2PA delivery via one or more modes. Each mode has a `type` attribute:

| type value               | Meaning                                                                       |
|--------------------------|-------------------------------------------------------------------------------|
| `embedded-app11`         | Embedded in JPEG APP11 (0xFFEB) segment                                       |
| `embedded-cabx-chunk`    | Embedded in PNG caBX chunk                                                    |
| `embedded-riff-chunk`    | Embedded in a custom C2PA RIFF chunk (BWF/WAV)                                |
| `embedded-uuid-atom`     | Embedded in MP4/ISOBMFF uuid atom                                             |
| `embedded-via-id3`       | Embedded via ID3 GEOB frame (FLAC)                                            |
| `embedded`               | Embedded via format-specific container (generic, used in C2PA manifest entry) |
| `sidecar`                | Delivered as a standalone `.c2pa` sidecar file                                |
| `none`                   | No C2PA support defined                                                       |

### Mechanisms
A list of cross-references to entries in the Mechanisms registry that describe how metadata is stored in or alongside this format. Each link resolves to the named mechanism's detail page.

## 4. Mechanisms Registry

Mechanisms are the specific technical methods by which metadata is stored in, attached to, or associated with a media asset. Since many formats rely on similar methods to store this data, mechanisms are described separately from formats with a relationship. Note also how the C2PA technical specifications group supported formats together based on shared mechanisms.

### Type
The broad category of the mechanism.

| Value               | Meaning                                                             |
|---------------------|---------------------------------------------------------------------|
| `format-specific`   | A chunk, block, or segment defined by the host format specification |
| `embedded-metadata` | A general-purpose embedded metadata standard (XMP, EXIF, IPTC)      |
| `embedded-c2pa`     | A C2PA manifest store embedded in the host file                     |
| `integrity`         | A checksum or hash stored within the file                           |
| `sidecar-c2pa`      | A C2PA manifest store delivered as a separate sidecar file          |
| `sidecar-metadata`  | A metadata document delivered as a separate sidecar file            |
| `package-integrity` | Checksum manifests at the package level (BagIt)                     |

### Editability — File-level (`type` attribute)
Whether the container that holds this mechanism can be written to.

| Value                | Meaning                                                                    |
|----------------------|----------------------------------------------------------------------------|
| `embedded-writable`  | The chunk/block/segment is embedded and can be written or updated by tools |
| `sidecar-writable`   | The mechanism lives in a sidecar file that can be written independently    |
| `package-writable`   | The mechanism lives in package-level manifest files                        |

### Editability — Content-level (`type` attribute)
How the metadata content itself behaves when updated.

| Value          | Meaning                                                                     |
|----------------|-----------------------------------------------------------------------------|
| `overwrite`    | Values are replaced in place on write; no history is preserved              |
| `append`       | New entries are conventionally appended; prior entries remain               |
| `append-only`  | The store is structurally append-only; prior entries are immutable          |
| `fixed`        | The value is computed at creation and cannot be changed without recomputing |

### Verifiability — Media Integrity (`type` attribute)
Whether the mechanism provides any integrity check over the primary media data (audio samples, image pixels, video frames).

| Value           | Meaning                                                               |
|-----------------|-----------------------------------------------------------------------|
| `signed`        | Cryptographic signature covers the media data (C2PA hard binding)     |
| `checksum`      | A hash or CRC covers the media data                                   |
| `external-only` | Integrity is recorded externally (e.g. PREMIS fixity, BagIt manifest) |
| `none`          | No media-data integrity mechanism                                     |

### Verifiability — Metadata Integrity (`type` attribute)
Whether the mechanism provides any integrity check over the metadata itself.

| Value       | Meaning                                                                 |
|-------------|-------------------------------------------------------------------------|
| `signed`    | Cryptographic signature covers the metadata (C2PA manifest signing)     |
| `checksum`  | A hash or CRC covers the metadata chunk                                 |
| `none`      | No metadata integrity mechanism; fields can be silently overwritten     |

### Verifiability — Chain of Custody (`type` attribute)
Whether the mechanism supports a verifiable provenance chain linking the asset to an external identity or signing authority.

| Value           | Meaning                                                               |
|-----------------|-----------------------------------------------------------------------|
| `signed`        | Cryptographically signed provenance chain (C2PA manifest store)       |
| `external-only` | Provenance chain exists but is held externally (PREMIS events, BagIt) |
| `none`          | No provenance chain mechanism                                         |

### FDD References
Links to Library of Congress Format Description Documents (FDDs) that describe the format or mechanism. Each reference carries a `status` attribute:

| Value     | Meaning                                                                |
|-----------|------------------------------------------------------------------------|
| `partial` | The FDD exists and is relevant but does not fully cover this mechanism |
| `none`    | No applicable FDD exists                                               |

### Metadata Fields
Where defined, a table of the noted named fields carried by the mechanism that are relevant to CAP. Many fields are defined vaguely and could be or could not be used in a manner relevant to CAP, so this list is a selection of notable fields and not intended to be exhaustive. Each field has:

- **Field** — the field name as defined in the specification
- **CAP Concept** — the provenance concept the field addresses (see vocabulary below)
- **Description** — what the field records

#### CAP Concept vocabulary

| Value                   | Meaning                                                      |
|-------------------------|--------------------------------------------------------------|
| `actor-identity`        | Identity of a person, organisation, or software agent        |
| `asset-identity`        | A unique identifier for the asset itself                     |
| `creation-datetime`     | Date and/or time of creation, capture, or origination        |
| `technical-provenance`  | Technical characteristics of the capture device or process   |
| `transformation-history`| A record of processing steps applied to the asset            |
| `provenance-chain`      | A link in a verifiable chain of custody                      |
| `media-integrity`       | A checksum or hash over the primary media data               |
| `metadata-integrity`    | A checksum or hash over the metadata itself                  |
| `ai-attribution`        | AI generation, training, or model identity information       |
| `rights`                | Copyright, licensing, or usage rights statements             |

### Used by Formats
A list of cross-references back to the Formats registry entries that reference this mechanism. Each link resolves to the named format&#x27;s detail page.
