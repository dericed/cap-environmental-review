# CAP Registries

These registries are part of the FADGI environmental review report pertaining to Content Authenticity and Provenance (CAP). Each registry evaluates and documentes content capabilities of open-source multimedia tools as well as audiovisual and CAP-metadata formats. The registry also samples a few recording devices to review the relationship between tools that create and manipulate audiovisual data the tools and formats that they rely on.

## Structure

This repository is, at least preliminarily, organized into the following structure listed below. The intent of this design is to gather environmental metadata into a consistent machine-readible form and then use a build script to convert that data into usable formats, such as a component of the overall environmental report as well as information tables that can be used to better compare evaluated objects against one another. This build process is inspired by the methodology used in the IETF Cellar Working Group for establishing standards documents for Matroska and FFV1.

A directory of registries documents tools, formats, and devices according to a consistent evaluation criteria. 

```
registries/
  tools.xml
  formats.xml
  devices.xml
```

The various manifestations of these registries is presented in the docs folder. From here the intent is that these documents are concatenated against the larger content of the environmental report, while supporting at-a-glance representations. Since the underlying data is managed in the registries, this eludes the challenges of trying to synchronize updates against various manifestations of the same data. The current (as of 4/10/26) output of the docs folder is as follows:

```
docs/
  tools-full.md        # Full tool documentation
  formats-full.md      # Full format documentation
  devices-full.md      # Full device documentation
  tools-overview.md    # Tools summary table
  formats-overview.md  # Formats summary table
  heatmap.md           # TCR4CAP heatmap across all registries
```

And finally a build script is made to use the registries as an input to generate all the needed outputs. The script requires bash version 3.2+ and xmlstarlet for processing the xml-based registries.

```
bin/
  build-docs.sh  # Convert XML registries to Markdown docs
```

## Usage

There is an intention to update the documents in this repository periodically as the underlying registries are developed. To update the documents as one edits or extends the registries, just run:

```
    bash bin/build-docs.sh
```

## TCR4CAP Comments

The registries, and their derivative documents, utilize work from FADGI's Tiered Community Recommendations for Content Authenticity and Provenance (TCR4CAP) project. A major collaborative deliverable of that project is an extension of the NDSA Levels of Preservation matrix to add in consideration of Content Authenticity and Provenance concepts. While a work-in-progress that extension includes a scoring system to how a given tools or workflow may be evaluating to increasingly comprehensive principles of Content Authenticity and Provenance. That scoring system lists values from 1 to 4. For the registries here, two additional values are added "0" and "n/a" in order to convey when something is not evaluated by the registry authors or simply not applicable in a given context.

## License

TBD (CC0?)
