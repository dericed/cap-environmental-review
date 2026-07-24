#!/usr/bin/env bash
# bin/build-docs.sh — Generate HTML + Markdown docs from CAP registry XML files.
# Dependencies: xmlstarlet, bash 4+

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOLS_XML="$ROOT_DIR/registries/tools.xml"
FORMATS_XML="$ROOT_DIR/registries/formats.xml"
MECHANISMS_XML="$ROOT_DIR/registries/mechanisms.xml"
INTRO_MD="$ROOT_DIR/sections/registry_introduction.md"
DOCS_DIR="$ROOT_DIR/docs"

mkdir -p "$DOCS_DIR"

for f in "$TOOLS_XML" "$FORMATS_XML" "$MECHANISMS_XML"; do
  if ! xmlstarlet val -q "$f" 2>/dev/null; then
    echo "ERROR: $f is not valid XML:" >&2
    xmlstarlet val "$f" 2>&1 | head -10 >&2
    exit 1
  fi
done
echo "XML valid."

xval() { xmlstarlet sel -t -v "$2" "$1" 2>/dev/null | tr -s ' \t\n\r' ' ' | sed 's/^ //;s/ $//' || true; }
xcount() { xmlstarlet sel -t -v "count($2)" "$1" 2>/dev/null || echo "0"; }
fdd_url() { echo "https://www.loc.gov/preservation/digital/formats/fdd/${1,,}.shtml"; }

url_cells_html() {
  while IFS=$'\t' read -r url utype; do
    [[ -z "$url" ]] && continue
    local label="${utype:+${utype}: }"
    echo "<tr><td>URL</td><td>${label}<a href=\"${url}\">${url}</a></td></tr>"
  done < <(xmlstarlet sel -t -m "$2/url" -v "." -o $'\t' -v "concat(@type,'')" -n "$1" 2>/dev/null || true) || true
}

url_lines_md() {
  while IFS=$'\t' read -r url utype; do
    [[ -z "$url" ]] && continue
    local label="${utype:+${utype}: }"
    echo "**URL:** ${label}<${url}>  "
  done < <(xmlstarlet sel -t -m "$2/url" -v "." -o $'\t' -v "concat(@type,'')" -n "$1" 2>/dev/null || true) || true
}

url_cell_first() {
  local f="$1" b="$2" fmt="$3" url utype
  url=$(xmlstarlet sel -t -m "${b}/url[1]" -v "." -n "$f" 2>/dev/null | head -1 || true)
  utype=$(xmlstarlet sel -t -m "${b}/url[1]" -v "concat(@type,'')" -n "$f" 2>/dev/null | head -1 || true)
  [[ -z "$url" ]] && echo "—" && return
  local label="${utype:+${utype}: }"
  if [[ "$fmt" == "html" ]]; then echo "${label}<a href='${url}'>${url}</a>"
  else echo "${label}<${url}>"; fi
}

tcr_html() {
  local f="$1" b="$2"
  local aw te bi ai su io
  aw=$(xval "$f" "${b}/tcr4cap-comments/awareness")
  te=$(xval "$f" "${b}/tcr4cap-comments/tamper-evidence")
  bi=$(xval "$f" "${b}/tcr4cap-comments/binding")
  ai=$(xval "$f" "${b}/tcr4cap-comments/ai-attribution")
  su=$(xval "$f" "${b}/tcr4cap-comments/substantiation")
  io=$(xval "$f" "${b}/tcr4cap-comments/interoperability")
  [[ -z "${aw}${te}${bi}${ai}${su}${io}" ]] && return
  echo "<div class='tcr'><h3>TCR4CAP Comments</h3>"
  echo "<table><tbody><tr><th>Dimension</th><th>Observation</th></tr>"
  [[ -n "$aw" ]] && echo "<tr><td>Awareness</td><td>${aw}</td></tr>"
  [[ -n "$te" ]] && echo "<tr><td>Tamper Evidence</td><td>${te}</td></tr>"
  [[ -n "$bi" ]] && echo "<tr><td>Binding</td><td>${bi}</td></tr>"
  [[ -n "$ai" ]] && echo "<tr><td>AI Attribution</td><td>${ai}</td></tr>"
  [[ -n "$su" ]] && echo "<tr><td>Substantiation</td><td>${su}</td></tr>"
  [[ -n "$io" ]] && echo "<tr><td>Interoperability</td><td>${io}</td></tr>"
  echo "</tbody></table></div>"
}

tcr_md() {
  local f="$1" b="$2"
  local aw te bi ai su io
  aw=$(xval "$f" "${b}/tcr4cap-comments/awareness")
  te=$(xval "$f" "${b}/tcr4cap-comments/tamper-evidence")
  bi=$(xval "$f" "${b}/tcr4cap-comments/binding")
  ai=$(xval "$f" "${b}/tcr4cap-comments/ai-attribution")
  su=$(xval "$f" "${b}/tcr4cap-comments/substantiation")
  io=$(xval "$f" "${b}/tcr4cap-comments/interoperability")
  [[ -z "${aw}${te}${bi}${ai}${su}${io}" ]] && return
  echo -e "### TCR4CAP Comments\n"
  [[ -n "$aw" ]] && echo -e "**Awareness:** ${aw}\n"
  [[ -n "$te" ]] && echo -e "**Tamper Evidence:** ${te}\n"
  [[ -n "$bi" ]] && echo -e "**Binding:** ${bi}\n"
  [[ -n "$ai" ]] && echo -e "**AI Attribution:** ${ai}\n"
  [[ -n "$su" ]] && echo -e "**Substantiation:** ${su}\n"
  [[ -n "$io" ]] && echo -e "**Interoperability:** ${io}\n"
}

tcr_vals() {
  aw=$(xval "$1" "$2/tcr4cap-comments/awareness")
  te=$(xval "$1" "$2/tcr4cap-comments/tamper-evidence")
  bi=$(xval "$1" "$2/tcr4cap-comments/binding")
  ai=$(xval "$1" "$2/tcr4cap-comments/ai-attribution")
  su=$(xval "$1" "$2/tcr4cap-comments/substantiation")
  io=$(xval "$1" "$2/tcr4cap-comments/interoperability")
}

provenance_html() {
  local f="$1" b="$2" scope dur depth
  scope=$(xval "$f" "${b}/provenance/scope")
  dur=$(xval   "$f" "${b}/provenance/durability")
  depth=$(xval "$f" "${b}/provenance/depth")
  [[ -n "$scope" ]] && echo "<tr><td>Provenance Scope</td><td>${scope}</td></tr>"
  [[ -n "$dur"   ]] && echo "<tr><td>Provenance Durability</td><td>${dur}</td></tr>"
  [[ -n "$depth" ]] && echo "<tr><td>Provenance Depth</td><td>${depth}</td></tr>"
}

provenance_md() {
  local f="$1" b="$2" scope dur depth
  scope=$(xval "$f" "${b}/provenance/scope")
  dur=$(xval   "$f" "${b}/provenance/durability")
  depth=$(xval "$f" "${b}/provenance/depth")
  [[ -n "$scope" ]] && echo "**Provenance Scope:** ${scope}  "
  [[ -n "$dur"   ]] && echo "**Provenance Durability:** ${dur}  "
  [[ -n "$depth" ]] && echo "**Provenance Depth:** ${depth}  "
}

provenance_summary() {
  local f="$1" b="$2" scope dur depth
  scope=$(xval "$f" "${b}/provenance/scope")
  dur=$(xval   "$f" "${b}/provenance/durability")
  depth=$(xval "$f" "${b}/provenance/depth")
  if [[ -n "$scope" || -n "$dur" || -n "$depth" ]]; then
    echo "${scope:-—} / ${dur:-—} / ${depth:-—}"
  else
    echo "—"
  fi
}

c2pa_modes_html() {
  local f="$1" b="$2"
  local count=$(xcount "$f" "${b}/c2pa-support/mode")
  if [[ "$count" -gt 0 ]]; then
    local html="<ul>"
    while IFS= read -r mtype; do
      [[ -z "$mtype" ]] && continue
      local mtext=$(xmlstarlet sel -t -v "${b}/c2pa-support/mode[@type='${mtype}']" "$f" 2>/dev/null | tr -s ' \t\n\r' ' ' | sed 's/^ //;s/ $//' || true)
      html+="<li><strong>${mtype}:</strong> ${mtext}</li>"
    done < <(xmlstarlet sel -t -m "${b}/c2pa-support/mode" -v "@type" -n "$f" 2>/dev/null || true) || true
    html+="</ul>"
    echo "<tr><td>C2PA Support</td><td>${html}</td></tr>"
  else
    echo "<tr><td>C2PA Support</td><td><em>none</em></td></tr>"
  fi
}

c2pa_modes_md() {
  local f="$1" b="$2"
  local count=$(xcount "$f" "${b}/c2pa-support/mode")
  if [[ "$count" -gt 0 ]]; then
    echo -e "\n**C2PA Support Modes:**\n"
    while IFS= read -r mtype; do
      [[ -z "$mtype" ]] && continue
      local mtext=$(xmlstarlet sel -t -v "${b}/c2pa-support/mode[@type='${mtype}']" "$f" 2>/dev/null | tr -s ' \t\n\r' ' ' | sed 's/^ //;s/ $//' || true)
      echo "- **${mtype}:** ${mtext}"
    done < <(xmlstarlet sel -t -m "${b}/c2pa-support/mode" -v "@type" -n "$f" 2>/dev/null || true) || true
  fi
}

mech_summary_html() {
  local f="$1" b="$2"
  local count=$(xcount "$f" "${b}/mechanisms/mechanism-ref")
  if [[ "$count" -gt 0 ]]; then
    echo "<tr><td>Mechanisms</td><td>"
    echo "<table><tbody><tr><th data-sort='mname'>Mechanism</th><th data-sort='mtype'>Type</th><th data-sort='mfl'>File-level</th><th data-sort='mcl'>Content-level</th><th data-sort='mmdi'>Metadata Integrity</th></tr>"
    while IFS= read -r mid; do
      [[ -z "$mid" ]] && continue
      local mb="//mechanism[@id='${mid}']"
      local mname=$(xval "$MECHANISMS_XML" "${mb}/name")
      local mtype=$(xval "$MECHANISMS_XML" "${mb}/type")
      local mfl=$(xval   "$MECHANISMS_XML" "${mb}/editability/file-level/@type")
      local mcl=$(xval   "$MECHANISMS_XML" "${mb}/editability/content-level/@type")
      local mmdi=$(xval  "$MECHANISMS_XML" "${mb}/verifiability/metadata-integrity/@type")
      echo "<tr><td><a href='mechanisms.html#mechanism-${mid}'>${mname:-${mid}}</a></td><td>${mtype}</td><td>${mfl}</td><td>${mcl}</td><td>${mmdi}</td></tr>"
    done < <(xmlstarlet sel -t -m "${b}/mechanisms/mechanism-ref" -v "@id" -n "$f" 2>/dev/null || true) || true
    echo "</tbody></table></td></tr>"
  else
    echo "<tr><td>Mechanisms</td><td><em>none</em></td></tr>"
  fi
}

mech_summary_md() {
  local f="$1" b="$2"
  local count=$(xcount "$f" "${b}/mechanisms/mechanism-ref")
  if [[ "$count" -gt 0 ]]; then
    echo -e "\n**Mechanisms:**\n"
    echo "| Mechanism | Type | File-level | Content-level | Metadata Integrity |"
    echo "|---|---|---|---|---|"
    while IFS= read -r mid; do
      [[ -z "$mid" ]] && continue
      local mb="//mechanism[@id='${mid}']"
      local mname=$(xval "$MECHANISMS_XML" "${mb}/name")
      local mtype=$(xval "$MECHANISMS_XML" "${mb}/type")
      local mfl=$(xval   "$MECHANISMS_XML" "${mb}/editability/file-level/@type")
      local mcl=$(xval   "$MECHANISMS_XML" "${mb}/editability/content-level/@type")
      local mmdi=$(xval  "$MECHANISMS_XML" "${mb}/verifiability/metadata-integrity/@type")
      echo "| [${mname:-${mid}}](mechanisms.md#${mid}) | ${mtype} | ${mfl} | ${mcl} | ${mmdi} |"
    done < <(xmlstarlet sel -t -m "${b}/mechanisms/mechanism-ref" -v "@id" -n "$f" 2>/dev/null || true) || true
    echo ""
  fi
}

struct_row_vars() {
  local f="$1" b="$2" fmt="$3"
  url_cell=$(url_cell_first "$f" "$b" "$fmt")
  tcr_vals "$f" "$b"
}

# Convert markdown to simple HTML.
# Handles: headings, paragraphs, bullet lists, and pipe tables (including
# table rows that are wrapped across multiple physical lines).
md_to_html() {
  local in_table=false in_list=false
  local logical_line=""

  local -a lines=()
  while IFS= read -r line; do
    lines+=("$line")
  done || true

  local i=0
  local n=${#lines[@]}

  while [[ "$i" -lt "$n" ]]; do
    local line="${lines[$i]}"

    if [[ "$line" =~ ^\| ]]; then
      logical_line="$line"
      while [[ "$logical_line" != *\| ]] && [[ "$((i + 1))" -lt "$n" ]]; do
        i=$((i + 1))
        logical_line+="${lines[$i]}"
      done
      if [[ "$logical_line" =~ ^\|[[:space:]]*--- ]]; then
        i=$((i + 1))
        continue
      fi
      if ! $in_table; then
        echo "<table><tbody>"
        in_table=true
      fi
      local cells="${logical_line#|}"
      cells="${cells%|}"
      local html_row="<tr>"
      IFS='|' read -ra arr <<< "$cells"
      for cell in "${arr[@]}"; do
        cell="$(echo "$cell" | sed 's/^ *//;s/ *$//')"
        cell="${cell//\`/<code>}"
        cell="${cell//<\/code>/<\/code>}"
        html_row+="<td>${cell}</td>"
      done
      html_row+="</tr>"
      echo "$html_row"
      i=$((i + 1))
      continue
    else
      if $in_table; then echo "</tbody></table>"; in_table=false; fi
      if $in_list; then echo "</ul>"; in_list=false; fi
    fi

    if [[ "$line" =~ ^####[[:space:]]+(.*) ]]; then
      echo "<h4>${BASH_REMATCH[1]}</h4>"
    elif [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
      echo "<h3>${BASH_REMATCH[1]}</h3>"
    elif [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
      echo "<h2>${BASH_REMATCH[1]}</h2>"
    elif [[ "$line" =~ ^#[[:space:]]+(.*) ]]; then
      echo "<h1>${BASH_REMATCH[1]}</h1>"
    elif [[ "$line" =~ ^-[[:space:]]+(.*) ]]; then
      if ! $in_list; then echo "<ul>"; in_list=true; fi
      echo "<li>${BASH_REMATCH[1]}</li>"
    elif [[ -n "$line" ]]; then
      echo "<p>${line}</p>"
    fi
    i=$((i + 1))
  done

  $in_table && echo "</tbody></table>"
  $in_list && echo "</ul>"
  return 0
}

# html_head TITLE [ACTIVE_TAB]
html_head() {
  local title="$1" active="${2:-}"
  cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <style>
    body  { font-family: system-ui, sans-serif; max-width: 1100px; margin: 2rem auto; padding: 0 1.5rem; color: #1a1a1a; }
    h1    { border-bottom: 3px solid #2c3e50; padding-bottom: .5rem; }
    h2    { border-bottom: 1px solid #ccc; padding-bottom: .25rem; margin-top: 2.5rem; color: #2c3e50; }
    h3    { color: #555; margin-top: 1.5rem; }
    h4    { color: #666; margin-top: 1rem; }
    table { border-collapse: collapse; width: 100%; margin: .75rem 0 1.5rem; font-size: .88rem; }
    th    { background: #2c3e50; color: #fff; padding: .45rem .75rem; text-align: left; }
    th[data-sort] { cursor: pointer; user-select: none; }
    th[data-sort]::after { content: ' \\21C5'; opacity: .4; font-size: .8em; }
    th[data-sort].asc::after  { content: ' \\2191'; opacity: 1; }
    th[data-sort].desc::after { content: ' \\2193'; opacity: 1; }
    td    { padding: .4rem .75rem; border-bottom: 1px solid #e0e0e0; vertical-align: top; }
    tr:nth-child(even) td { background: #f8f8f8; }
    code  { background: #f0f0f0; padding: .1rem .35rem; border-radius: 3px; font-size: .85em; }
    a     { color: #2980b9; }
    .tcr  { background: #f9f9f9; border-left: 4px solid #2c3e50; padding: .6rem 1rem; margin: 1rem 0; }
    .tcr h3 { margin-top: .5rem; }
    .tcr table { margin: .5rem 0; }
    .tcr th { background: #555; }
    hr    { border: none; border-top: 1px solid #ddd; margin: 2.5rem 0; }
    nav.tabs { display: flex; gap: 0; margin-bottom: 0; border-bottom: 2px solid #2c3e50; }
    nav.tabs a { padding: .6rem 1.2rem; color: #555; text-decoration: none; font-size: .92rem; border-bottom: 3px solid transparent; margin-bottom: -2px; }
    nav.tabs a:hover { background: #f4f4f4; color: #2c3e50; }
    nav.tabs a.active { color: #2c3e50; border-bottom-color: #2c3e50; font-weight: 600; }
    nav.subtabs { display: flex; gap: 0; margin: 1rem 0 1.5rem; }
    nav.subtabs a { padding: .35rem .9rem; color: #777; text-decoration: none; font-size: .85rem; border: 1px solid #ddd; border-radius: 4px; margin-right: .5rem; }
    nav.subtabs a:hover { background: #f4f4f4; }
    nav.subtabs a.active { background: #2c3e50; color: #fff; border-color: #2c3e50; }
  </style>
  <script>
    document.addEventListener('DOMContentLoaded', function() {
      document.querySelectorAll('th[data-sort]').forEach(function(th) {
        th.addEventListener('click', function() { sortTable(th); });
      });
    });
    function sortTable(th) {
      var table = th.closest('table');
      var tbody = table.querySelector('tbody');
      if (!tbody) tbody = table;
      var colIdx = Array.prototype.indexOf.call(th.parentElement.children, th);
      var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr')).filter(function(r) {
        return !r.querySelector('th');
      });
      var asc = th.classList.toggle('asc');
      if (asc) { th.classList.remove('desc'); } else { th.classList.add('desc'); th.classList.remove('asc'); }
      rows.sort(function(a, b) {
        var va = (a.cells[colIdx] || {}).textContent || '';
        var vb = (b.cells[colIdx] || {}).textContent || '';
        va = va.trim(); vb = vb.trim();
        return asc ? va.localeCompare(vb) : vb.localeCompare(va);
      });
      rows.forEach(function(r) { tbody.appendChild(r); });
    }
  </script>
</head>
<body>
<nav class="tabs">
  <a href="index.html"$([[ "$active" == "intro" ]] && echo " class='active'")>Registry Introduction</a>
  <a href="tools.html"$([[ "$active" == "tools" ]] && echo " class='active'")>Tools</a>
  <a href="formats.html"$([[ "$active" == "formats" ]] && echo " class='active'")>Formats</a>
  <a href="mechanisms.html"$([[ "$active" == "mechanisms" ]] && echo " class='active'")>Mechanisms</a>
</nav>
<h1>${title}</h1>
HTML
}

# subtabs_html ACTIVE BASE
subtabs_html() {
  local active="$1" base="$2"
  cat <<HTML
<nav class="subtabs">
  <a href="${base}.html"$([[ "$active" == "report" ]] && echo " class='active'")>Report</a>
  <a href="${base}-table.html"$([[ "$active" == "table" ]] && echo " class='active'")>Complete Table</a>
</nav>
HTML
}

# toc_html REGISTRY_BASE ENTRY_XPATH NAME_XPATH FILE
toc_html() {
  local base="$1" xpath="$2" namepath="$3" file="$4"
  echo "<h2 id='contents'>Table of Contents</h2>"
  echo "<table><tbody><tr><th data-sort='id'>ID</th><th data-sort='name'>Name</th></tr>"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    local name=$(xval "$file" "${xpath}[@id='${id}']${namepath}")
    echo "<tr><td><a href='#${base}-${id}'><code>${id}</code></a></td><td>${name}</td></tr>"
  done < <(xmlstarlet sel -t -m "$xpath" -v "@id" -n "$file" 2>/dev/null || true) || true
  echo "</tbody></table>"
}

# toc_md REGISTRY_BASE ENTRY_XPATH NAME_XPATH FILE
toc_md() {
  local base="$1" xpath="$2" namepath="$3" file="$4"
  echo -e "## Table of Contents\n"
  echo "| ID | Name |"
  echo "|---|---|"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    local name=$(xval "$file" "${xpath}[@id='${id}']${namepath}")
    echo "| \`${id}\` | [${name}](#${base}-${id}) |"
  done < <(xmlstarlet sel -t -m "$xpath" -v "@id" -n "$file" 2>/dev/null || true) || true
  echo ""
}

# REGISTRY INTRODUCTION (index)
echo "Building registry introduction..."

{
  html_head "CAP Registry Reference" "intro"
  if [[ -f "$INTRO_MD" ]]; then
    tail -n +2 "$INTRO_MD" | md_to_html || true
  else
    echo "<p><em>registry_introduction.md not found at ${INTRO_MD}</em></p>"
  fi
  echo "</body></html>"
} > "$DOCS_DIR/index.html"

if [[ -f "$INTRO_MD" ]]; then
  cp "$INTRO_MD" "$DOCS_DIR/registry_introduction.md"
fi

echo "  -> docs/index.html, docs/registry_introduction.md"

# TOOLS
echo "Building tools docs..."

{
  html_head "Tools Registry" "tools"
  subtabs_html "report" "tools"
  toc_html "tool" "//tool" "/name" "$TOOLS_XML"

  echo "<h2 id='report'>Report</h2>"
  echo "<table id='tools-main'><tbody><tr><th data-sort='id'>ID</th><th data-sort='name'>Name</th><th data-sort='type'>Category</th><th data-sort='version'>Version</th><th data-sort='license'>License</th><th data-sort='provenance'>Provenance</th><th data-sort='c2pa'>C2PA</th></tr>"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//tool[@id='${id}']"
    name=$(xval    "$TOOLS_XML" "${b}/name")
    type=$(xval    "$TOOLS_XML" "${b}/type")
    version=$(xval "$TOOLS_XML" "string(${b}/version)")
    license=$(xval "$TOOLS_XML" "${b}/license")
    psum=$(provenance_summary "$TOOLS_XML" "$b")
    c2pa=$(xval    "$TOOLS_XML" "${b}/c2pa-support")
    echo "<tr><td><a href='#tool-${id}'><code>${id}</code></a></td><td>${name}</td><td>${type}</td><td>${version:-—}</td><td>${license:-—}</td><td>${psum}</td><td>${c2pa:-—}</td></tr>"
  done < <(xmlstarlet sel -t -m "//tool" -v "@id" -n "$TOOLS_XML" 2>/dev/null || true) || true
  echo "</tbody></table>"

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//tool[@id='${id}']"
    name=$(xval    "$TOOLS_XML" "${b}/name")
    type=$(xval    "$TOOLS_XML" "${b}/type")
    version=$(xval "$TOOLS_XML" "string(${b}/version)")
    rdate=$(xval   "$TOOLS_XML" "${b}/version/@release-date")
    license=$(xval "$TOOLS_XML" "${b}/license")
    c2pa=$(xval    "$TOOLS_XML" "${b}/c2pa-support")
    desc=$(xval    "$TOOLS_XML" "${b}/description")
    echo "<h2 id='tool-${id}'>${name}</h2>"
    echo "<table><tbody><tr><th>Attribute</th><th>Value</th></tr>"
    echo "<tr><td>ID</td><td><code>${id}</code></td></tr>"
    [[ -n "$type"    ]] && echo "<tr><td>Category</td><td>${type}</td></tr>"
    [[ -n "$version" ]] && echo "<tr><td>Version</td><td>${version}$([[ -n "$rdate" ]] && echo " <small>(${rdate})</small>")</td></tr>"
    [[ -n "$license" ]] && echo "<tr><td>License</td><td>${license}</td></tr>"
    provenance_html "$TOOLS_XML" "$b"
    [[ -n "$c2pa"    ]] && echo "<tr><td>C2PA Support</td><td>${c2pa}</td></tr>"
    url_cells_html "$TOOLS_XML" "$b"
    echo "</tbody></table>"
    [[ -n "$desc" ]] && echo "<p>${desc}</p>"
    tcr_html "$TOOLS_XML" "$b"
    echo "<hr>"
  done < <(xmlstarlet sel -t -m "//tool" -v "@id" -n "$TOOLS_XML" 2>/dev/null || true) || true
  echo "</body></html>"
} > "$DOCS_DIR/tools.html"

{
  echo -e "# Tools Registry\n"
  toc_md "tool" "//tool" "/name" "$TOOLS_XML"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//tool[@id='${id}']"
    name=$(xval    "$TOOLS_XML" "${b}/name")
    type=$(xval    "$TOOLS_XML" "${b}/type")
    version=$(xval "$TOOLS_XML" "string(${b}/version)")
    rdate=$(xval   "$TOOLS_XML" "${b}/version/@release-date")
    license=$(xval "$TOOLS_XML" "${b}/license")
    c2pa=$(xval    "$TOOLS_XML" "${b}/c2pa-support")
    desc=$(xval    "$TOOLS_XML" "${b}/description")
    echo -e "## ${name}\n"
    echo "**ID:** \`${id}\`  "
    [[ -n "$type"    ]] && echo "**Category:** ${type}  "
    [[ -n "$version" ]] && echo "**Version:** ${version}$([[ -n "$rdate" ]] && echo " (${rdate})")  "
    [[ -n "$license" ]] && echo "**License:** ${license}  "
    provenance_md "$TOOLS_XML" "$b"
    [[ -n "$c2pa"    ]] && echo "**C2PA Support:** ${c2pa}  "
    url_lines_md "$TOOLS_XML" "$b"
    echo ""
    [[ -n "$desc" ]] && echo -e "${desc}\n"
    tcr_md "$TOOLS_XML" "$b"
    echo -e "---\n"
  done < <(xmlstarlet sel -t -m "//tool" -v "@id" -n "$TOOLS_XML" 2>/dev/null || true) || true
} > "$DOCS_DIR/tools.md"

echo "  -> docs/tools.html, docs/tools.md"

# TOOLS — Complete Table
{
  html_head "Tools — Complete Table" "tools"
  subtabs_html "table" "tools"
  echo "<p>Complete table with all fields including TCR4CAP comments.</p>"
  echo "<table id='tools-full'><tbody><tr><th data-sort='id'>ID</th><th data-sort='name'>Name</th><th data-sort='type'>Category</th><th data-sort='version'>Version</th><th data-sort='license'>License</th><th data-sort='provenance'>Provenance</th><th data-sort='c2pa'>C2PA</th><th>URL</th><th>Awareness</th><th>Tamper Evidence</th><th>Binding</th><th>AI Attribution</th><th>Substantiation</th><th>Interoperability</th></tr>"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//tool[@id='${id}']"
    name=$(xval    "$TOOLS_XML" "${b}/name")
    type=$(xval    "$TOOLS_XML" "${b}/type")
    version=$(xval "$TOOLS_XML" "string(${b}/version)")
    license=$(xval "$TOOLS_XML" "${b}/license")
    psum=$(provenance_summary "$TOOLS_XML" "$b")
    c2pa=$(xval    "$TOOLS_XML" "${b}/c2pa-support")
    struct_row_vars "$TOOLS_XML" "$b" html
    echo "<tr><td><a href='tools.html#tool-${id}'><code>${id}</code></a></td><td>${name}</td><td>${type}</td><td>${version:-—}</td><td>${license:-—}</td><td>${psum}</td><td>${c2pa:-—}</td><td>${url_cell}</td><td>${aw:-—}</td><td>${te:-—}</td><td>${bi:-—}</td><td>${ai:-—}</td><td>${su:-—}</td><td>${io:-—}</td></tr>"
  done < <(xmlstarlet sel -t -m "//tool" -v "@id" -n "$TOOLS_XML" 2>/dev/null || true) || true
  echo "</tbody></table></body></html>"
} > "$DOCS_DIR/tools-table.html"

{
  echo -e "# Tools — Complete Table\n"
  echo "| ID | Name | Category | Version | License | Provenance | C2PA | URL | Awareness | Tamper Evidence | Binding | AI Attribution | Substantiation | Interoperability |"
  echo "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//tool[@id='${id}']"
    name=$(xval    "$TOOLS_XML" "${b}/name")
    type=$(xval    "$TOOLS_XML" "${b}/type")
    version=$(xval "$TOOLS_XML" "string(${b}/version)")
    license=$(xval "$TOOLS_XML" "${b}/license")
    psum=$(provenance_summary "$TOOLS_XML" "$b")
    c2pa=$(xval    "$TOOLS_XML" "${b}/c2pa-support")
    struct_row_vars "$TOOLS_XML" "$b" md
    echo "| \`${id}\` | ${name} | ${type} | ${version:-—} | ${license:-—} | ${psum} | ${c2pa:-—} | ${url_cell} | ${aw:-—} | ${te:-—} | ${bi:-—} | ${ai:-—} | ${su:-—} | ${io:-—} |"
  done < <(xmlstarlet sel -t -m "//tool" -v "@id" -n "$TOOLS_XML" 2>/dev/null || true) || true
} > "$DOCS_DIR/tools-table.md"

echo "  -> docs/tools-table.html, docs/tools-table.md"

# FORMATS
echo "Building formats docs..."

{
  html_head "Formats Registry" "formats"
  subtabs_html "report" "formats"
  toc_html "format" "//format" "/name" "$FORMATS_XML"

  echo "<h2 id='report'>Report</h2>"
  echo "<table id='formats-main'><tbody><tr><th data-sort='id'>ID</th><th data-sort='name'>Name</th><th data-sort='type'>Type</th><th data-sort='struct'>Structure</th><th data-sort='read'>Readability</th><th data-sort='verify'>Verifiability</th><th data-sort='persist'>Persistence</th></tr>"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//format[@id='${id}']"
    name=$(xval   "$FORMATS_XML" "${b}/name")
    type=$(xval   "$FORMATS_XML" "${b}/type")
    struct=$(xval "$FORMATS_XML" "${b}/structure")
    rt=$(xval     "$FORMATS_XML" "${b}/readability/@type")
    vt=$(xval     "$FORMATS_XML" "${b}/verifiability/@type")
    pt=$(xval     "$FORMATS_XML" "${b}/persistence/@type")
    echo "<tr><td><a href='#format-${id}'><code>${id}</code></a></td><td>${name}</td><td>${type}</td><td><code>${struct}</code></td><td>${rt}</td><td>${vt}</td><td>${pt:-—}</td></tr>"
  done < <(xmlstarlet sel -t -m "//format" -v "@id" -n "$FORMATS_XML" 2>/dev/null || true) || true
  echo "</tbody></table>"

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//format[@id='${id}']"
    name=$(xval   "$FORMATS_XML" "${b}/name")
    type=$(xval   "$FORMATS_XML" "${b}/type")
    struct=$(xval "$FORMATS_XML" "${b}/structure")
    r_type=$(xval "$FORMATS_XML" "${b}/readability/@type")
    r_text=$(xval "$FORMATS_XML" "${b}/readability")
    v_type=$(xval "$FORMATS_XML" "${b}/verifiability/@type")
    v_text=$(xval "$FORMATS_XML" "${b}/verifiability")
    p_type=$(xval "$FORMATS_XML" "${b}/persistence/@type")
    p_text=$(xval "$FORMATS_XML" "${b}/persistence")
    desc=$(xval   "$FORMATS_XML" "${b}/description")
    echo "<h2 id='format-${id}'>${name}</h2>"
    echo "<table><tbody><tr><th>Attribute</th><th>Value</th></tr>"
    echo "<tr><td>ID</td><td><code>${id}</code></td></tr>"
    [[ -n "$type"   ]] && echo "<tr><td>Type</td><td>${type}</td></tr>"
    [[ -n "$struct" ]] && echo "<tr><td>Structure</td><td><code>${struct}</code></td></tr>"
    echo "<tr><td>Readability</td><td><code>${r_type}</code> &mdash; ${r_text}</td></tr>"
    echo "<tr><td>Verifiability</td><td><code>${v_type}</code> &mdash; ${v_text}</td></tr>"
    [[ -n "$p_type" ]] && echo "<tr><td>Persistence</td><td><code>${p_type}</code> &mdash; ${p_text}</td></tr>"
    url_cells_html "$FORMATS_XML" "$b"
    c2pa_modes_html "$FORMATS_XML" "$b"
    mech_summary_html "$FORMATS_XML" "$b"
    echo "</tbody></table>"
    [[ -n "$desc" ]] && echo "<p>${desc}</p>"
    tcr_html "$FORMATS_XML" "$b"
    echo "<hr>"
  done < <(xmlstarlet sel -t -m "//format" -v "@id" -n "$FORMATS_XML" 2>/dev/null || true) || true
  echo "</body></html>"
} > "$DOCS_DIR/formats.html"

{
  echo -e "# Formats Registry\n"
  toc_md "format" "//format" "/name" "$FORMATS_XML"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//format[@id='${id}']"
    name=$(xval   "$FORMATS_XML" "${b}/name")
    type=$(xval   "$FORMATS_XML" "${b}/type")
    struct=$(xval "$FORMATS_XML" "${b}/structure")
    r_type=$(xval "$FORMATS_XML" "${b}/readability/@type")
    r_text=$(xval "$FORMATS_XML" "${b}/readability")
    v_type=$(xval "$FORMATS_XML" "${b}/verifiability/@type")
    v_text=$(xval "$FORMATS_XML" "${b}/verifiability")
    p_type=$(xval "$FORMATS_XML" "${b}/persistence/@type")
    p_text=$(xval "$FORMATS_XML" "${b}/persistence")
    desc=$(xval   "$FORMATS_XML" "${b}/description")
    echo -e "## ${name}\n"
    echo "**ID:** \`${id}\`  "
    [[ -n "$type"   ]] && echo "**Type:** ${type}  "
    [[ -n "$struct" ]] && echo "**Structure:** \`${struct}\`  "
    echo ""
    echo -e "| Property | Type | Notes |\n|---|---|---|"
    echo "| Readability | \`${r_type}\` | ${r_text} |"
    echo "| Verifiability | \`${v_type}\` | ${v_text} |"
    [[ -n "$p_type" ]] && echo "| Persistence | \`${p_type}\` | ${p_text} |"
    echo ""
    url_lines_md "$FORMATS_XML" "$b"
    c2pa_modes_md "$FORMATS_XML" "$b"
    mech_summary_md "$FORMATS_XML" "$b"
    echo ""
    [[ -n "$desc" ]] && echo -e "${desc}\n"
    tcr_md "$FORMATS_XML" "$b"
    echo -e "---\n"
  done < <(xmlstarlet sel -t -m "//format" -v "@id" -n "$FORMATS_XML" 2>/dev/null || true) || true
} > "$DOCS_DIR/formats.md"

echo "  -> docs/formats.html, docs/formats.md"

# FORMATS — Complete Table
{
  html_head "Formats — Complete Table" "formats"
  subtabs_html "table" "formats"
  echo "<p>Complete table with all fields including TCR4CAP comments.</p>"
  echo "<table id='formats-full'><tbody><tr><th data-sort='id'>ID</th><th data-sort='name'>Name</th><th data-sort='type'>Type</th><th data-sort='struct'>Structure</th><th data-sort='read'>Readability</th><th data-sort='verify'>Verifiability</th><th data-sort='persist'>Persistence</th><th>URL</th><th>Awareness</th><th>Tamper Evidence</th><th>Binding</th><th>AI Attribution</th><th>Substantiation</th><th>Interoperability</th></tr>"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//format[@id='${id}']"
    name=$(xval   "$FORMATS_XML" "${b}/name")
    type=$(xval   "$FORMATS_XML" "${b}/type")
    struct=$(xval "$FORMATS_XML" "${b}/structure")
    rt=$(xval     "$FORMATS_XML" "${b}/readability/@type")
    vt=$(xval     "$FORMATS_XML" "${b}/verifiability/@type")
    pt=$(xval     "$FORMATS_XML" "${b}/persistence/@type")
    struct_row_vars "$FORMATS_XML" "$b" html
    echo "<tr><td><a href='formats.html#format-${id}'><code>${id}</code></a></td><td>${name}</td><td>${type}</td><td><code>${struct}</code></td><td>${rt}</td><td>${vt}</td><td>${pt:-—}</td><td>${url_cell}</td><td>${aw:-—}</td><td>${te:-—}</td><td>${bi:-—}</td><td>${ai:-—}</td><td>${su:-—}</td><td>${io:-—}</td></tr>"
  done < <(xmlstarlet sel -t -m "//format" -v "@id" -n "$FORMATS_XML" 2>/dev/null || true) || true
  echo "</tbody></table></body></html>"
} > "$DOCS_DIR/formats-table.html"

{
  echo -e "# Formats — Complete Table\n"
  echo "| ID | Name | Type | Structure | Readability | Verifiability | Persistence | URL | Awareness | Tamper Evidence | Binding | AI Attribution | Substantiation | Interoperability |"
  echo "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//format[@id='${id}']"
    name=$(xval   "$FORMATS_XML" "${b}/name")
    type=$(xval   "$FORMATS_XML" "${b}/type")
    struct=$(xval "$FORMATS_XML" "${b}/structure")
    rt=$(xval     "$FORMATS_XML" "${b}/readability/@type")
    vt=$(xval     "$FORMATS_XML" "${b}/verifiability/@type")
    pt=$(xval     "$FORMATS_XML" "${b}/persistence/@type")
    struct_row_vars "$FORMATS_XML" "$b" md
    echo "| \`${id}\` | ${name} | ${type} | \`${struct}\` | ${rt} | ${vt} | ${pt:-—} | ${url_cell} | ${aw:-—} | ${te:-—} | ${bi:-—} | ${ai:-—} | ${su:-—} | ${io:-—} |"
  done < <(xmlstarlet sel -t -m "//format" -v "@id" -n "$FORMATS_XML" 2>/dev/null || true) || true
} > "$DOCS_DIR/formats-table.md"

echo "  -> docs/formats-table.html, docs/formats-table.md"

# MECHANISMS
echo "Building mechanisms docs..."

{
  html_head "Mechanisms Registry" "mechanisms"
  subtabs_html "report" "mechanisms"
  toc_html "mechanism" "//mechanism" "/name" "$MECHANISMS_XML"

  echo "<h2 id='report'>Report</h2>"
  echo "<table id='mech-main'><tbody><tr><th data-sort='id'>ID</th><th data-sort='name'>Name</th><th data-sort='type'>Type</th><th data-sort='fl'>File-level</th><th data-sort='cl'>Content-level</th><th data-sort='mi'>Media Integrity</th><th data-sort='mdi'>Metadata Integrity</th><th data-sort='coc'>Chain of Custody</th></tr>"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//mechanism[@id='${id}']"
    name=$(xval    "$MECHANISMS_XML" "${b}/name")
    type=$(xval    "$MECHANISMS_XML" "${b}/type")
    fl=$(xval      "$MECHANISMS_XML" "${b}/editability/file-level/@type")
    cl=$(xval      "$MECHANISMS_XML" "${b}/editability/content-level/@type")
    mi=$(xval      "$MECHANISMS_XML" "${b}/verifiability/media-integrity/@type")
    mdi=$(xval     "$MECHANISMS_XML" "${b}/verifiability/metadata-integrity/@type")
    coc=$(xval     "$MECHANISMS_XML" "${b}/verifiability/chain-of-custody/@type")
    echo "<tr><td><a href='#mechanism-${id}'><code>${id}</code></a></td><td>${name}</td><td>${type}</td><td>${fl}</td><td>${cl}</td><td>${mi}</td><td>${mdi}</td><td>${coc}</td></tr>"
  done < <(xmlstarlet sel -t -m "//mechanism" -v "@id" -n "$MECHANISMS_XML" 2>/dev/null || true) || true
  echo "</tbody></table>"

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//mechanism[@id='${id}']"
    name=$(xval  "$MECHANISMS_XML" "${b}/name")
    type=$(xval  "$MECHANISMS_XML" "${b}/type")
    desc=$(xval  "$MECHANISMS_XML" "${b}/description")
    fl_t=$(xval  "$MECHANISMS_XML" "${b}/editability/file-level/@type")
    fl_v=$(xval  "$MECHANISMS_XML" "${b}/editability/file-level")
    cl_t=$(xval  "$MECHANISMS_XML" "${b}/editability/content-level/@type")
    cl_v=$(xval  "$MECHANISMS_XML" "${b}/editability/content-level")
    mi_t=$(xval  "$MECHANISMS_XML" "${b}/verifiability/media-integrity/@type")
    mi_v=$(xval  "$MECHANISMS_XML" "${b}/verifiability/media-integrity")
    mdi_t=$(xval "$MECHANISMS_XML" "${b}/verifiability/metadata-integrity/@type")
    mdi_v=$(xval "$MECHANISMS_XML" "${b}/verifiability/metadata-integrity")
    coc_t=$(xval "$MECHANISMS_XML" "${b}/verifiability/chain-of-custody/@type")
    coc_v=$(xval "$MECHANISMS_XML" "${b}/verifiability/chain-of-custody")
    fdd_count=$(xcount "$MECHANISMS_XML" "${b}/fdd-ref[@status!='none']")
    field_count=$(xcount "$MECHANISMS_XML" "${b}/metadata-values/field")

    echo "<h2 id='mechanism-${id}'>${name}</h2>"
    echo "<table><tbody><tr><th>Attribute</th><th>Value</th></tr>"
    echo "<tr><td>ID</td><td><code>${id}</code></td></tr>"
    echo "<tr><td>Type</td><td>${type}</td></tr>"
    url_cells_html "$MECHANISMS_XML" "$b"
    echo "</tbody></table>"

    echo -e "<h3>Editability</h3>\n<table><tbody><tr><th>Level</th><th>Type</th><th>Notes</th></tr>"
    echo "<tr><td>File-level</td><td>${fl_t}</td><td>${fl_v}</td></tr>"
    echo "<tr><td>Content-level</td><td>${cl_t}</td><td>${cl_v}</td></tr>"
    echo "</tbody></table>"

    echo -e "<h3>Verifiability</h3>\n<table><tbody><tr><th>Dimension</th><th>Type</th><th>Notes</th></tr>"
    echo "<tr><td>Media integrity</td><td>${mi_t}</td><td>${mi_v}</td></tr>"
    echo "<tr><td>Metadata integrity</td><td>${mdi_t}</td><td>${mdi_v}</td></tr>"
    echo "<tr><td>Chain of custody</td><td>${coc_t}</td><td>${coc_v}</td></tr>"
    echo "</tbody></table>"

    # FDD references — no status display
    if [[ "$fdd_count" -gt 0 ]]; then
      echo "<p><strong>FDD References:</strong>"
      while IFS= read -r fid; do
        [[ -z "$fid" ]] && continue
        echo "<a href=\"$(fdd_url "$fid")\">${fid}</a>"
      done < <(xmlstarlet sel -t -m "${b}/fdd-ref[@status!='none']" -v "@id" -n "$MECHANISMS_XML" 2>/dev/null || true) || true
      echo "</p>"
    fi

    if [[ "$field_count" -gt 0 ]]; then
      echo -e "<h3>Metadata Fields</h3>\n<table><tbody><tr><th data-sort='fname'>Field</th><th data-sort='fconcept'>CAP Concept</th><th>Description</th></tr>"
      while IFS=$'\t' read -r fname fconcept fdesc; do
        [[ -z "$fname" ]] && continue
        echo "<tr><td><code>${fname}</code></td><td>${fconcept}</td><td>${fdesc}</td></tr>"
      done < <(xmlstarlet sel -t -m "${b}/metadata-values/field" -v "@name" -o $'\t' -v "@cap-concept" -o $'\t' -v "." -n "$MECHANISMS_XML" 2>/dev/null || true) || true
      echo "</tbody></table>"
    fi

    # Back-references: formats using this mechanism — as a table
    ref_count=0
    ref_html=""
    while IFS= read -r fid; do
      [[ -z "$fid" ]] && continue
      fname=$(xval "$FORMATS_XML" "//format[@id='${fid}']/name")
      ref_html+="<tr><td><a href='formats.html#format-${fid}'><code>${fid}</code></a></td><td>${fname:-${fid}}</td></tr>"
      ref_count=$((ref_count + 1))
    done < <(xmlstarlet sel -t -m "//format[mechanisms/mechanism-ref[@id='${id}']]" -v "@id" -n "$FORMATS_XML" 2>/dev/null || true) || true
    if [[ "$ref_count" -gt 0 ]]; then
      echo -e "<h3>Used by Formats</h3>\n<table><tbody><tr><th data-sort='fid'>ID</th><th data-sort='fname'>Name</th></tr>"
      echo "$ref_html"
      echo "</tbody></table>"
    fi

    [[ -n "$desc" ]] && echo "<p>${desc}</p>"
    tcr_html "$MECHANISMS_XML" "$b"
    echo "<hr>"
  done < <(xmlstarlet sel -t -m "//mechanism" -v "@id" -n "$MECHANISMS_XML" 2>/dev/null || true) || true
  echo "</body></html>"
} > "$DOCS_DIR/mechanisms.html"

{
  echo -e "# Mechanisms Registry\n"
  toc_md "mechanism" "//mechanism" "/name" "$MECHANISMS_XML"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//mechanism[@id='${id}']"
    name=$(xval  "$MECHANISMS_XML" "${b}/name")
    type=$(xval  "$MECHANISMS_XML" "${b}/type")
    desc=$(xval  "$MECHANISMS_XML" "${b}/description")
    fl_t=$(xval  "$MECHANISMS_XML" "${b}/editability/file-level/@type")
    fl_v=$(xval  "$MECHANISMS_XML" "${b}/editability/file-level")
    cl_t=$(xval  "$MECHANISMS_XML" "${b}/editability/content-level/@type")
    cl_v=$(xval  "$MECHANISMS_XML" "${b}/editability/content-level")
    mi_t=$(xval  "$MECHANISMS_XML" "${b}/verifiability/media-integrity/@type")
    mi_v=$(xval  "$MECHANISMS_XML" "${b}/verifiability/media-integrity")
    mdi_t=$(xval "$MECHANISMS_XML" "${b}/verifiability/metadata-integrity/@type")
    mdi_v=$(xval "$MECHANISMS_XML" "${b}/verifiability/metadata-integrity")
    coc_t=$(xval "$MECHANISMS_XML" "${b}/verifiability/chain-of-custody/@type")
    coc_v=$(xval "$MECHANISMS_XML" "${b}/verifiability/chain-of-custody")
    fdd_count=$(xcount "$MECHANISMS_XML" "${b}/fdd-ref[@status!='none']")
    field_count=$(xcount "$MECHANISMS_XML" "${b}/metadata-values/field")

    echo -e "## ${name}\n"
    echo "**ID:** \`${id}\`  "
    echo "**Type:** ${type}  "
    url_lines_md "$MECHANISMS_XML" "$b"
    echo ""
    echo -e "### Editability\n\n| Level | Type | Notes |\n|---|---|---|"
    echo "| File-level | ${fl_t} | ${fl_v} |"
    echo -e "| Content-level | ${cl_t} | ${cl_v} |\n"
    echo -e "### Verifiability\n\n| Dimension | Type | Notes |\n|---|---|---|"
    echo "| Media integrity | ${mi_t} | ${mi_v} |"
    echo "| Metadata integrity | ${mdi_t} | ${mdi_v} |"
    echo -e "| Chain of custody | ${coc_t} | ${coc_v} |\n"

    if [[ "$fdd_count" -gt 0 ]]; then
      echo "**FDD References:**"
      while IFS= read -r fid; do
        [[ -z "$fid" ]] && continue
        echo "- [${fid}]($(fdd_url "$fid"))"
      done < <(xmlstarlet sel -t -m "${b}/fdd-ref[@status!='none']" -v "@id" -n "$MECHANISMS_XML" 2>/dev/null || true) || true
      echo ""
    fi

    if [[ "$field_count" -gt 0 ]]; then
      echo -e "### Metadata Fields\n\n| Field | CAP Concept | Description |\n|---|---|---|"
      while IFS=$'\t' read -r fname fconcept fdesc; do
        [[ -z "$fname" ]] && continue
        echo "| \`${fname}\` | ${fconcept} | ${fdesc} |"
      done < <(xmlstarlet sel -t -m "${b}/metadata-values/field" -v "@name" -o $'\t' -v "@cap-concept" -o $'\t' -v "." -n "$MECHANISMS_XML" 2>/dev/null || true) || true
      echo ""
    fi

    # Back-references to formats — as a table
    ref_count=0
    while IFS= read -r fid; do
      [[ -z "$fid" ]] && continue
      if [[ "$ref_count" -eq 0 ]]; then
        echo -e "### Used by Formats\n\n| ID | Name |\n|---|---|"
      fi
      fname=$(xval "$FORMATS_XML" "//format[@id='${fid}']/name")
      echo "| \`${fid}\` | [${fname:-${fid}}](formats.md#${fid}) |"
      ref_count=$((ref_count + 1))
    done < <(xmlstarlet sel -t -m "//format[mechanisms/mechanism-ref[@id='${id}']]" -v "@id" -n "$FORMATS_XML" 2>/dev/null || true) || true
    [[ "$ref_count" -gt 0 ]] && echo ""

    [[ -n "$desc" ]] && echo -e "${desc}\n"
    tcr_md "$MECHANISMS_XML" "$b"
    echo -e "---\n"
  done < <(xmlstarlet sel -t -m "//mechanism" -v "@id" -n "$MECHANISMS_XML" 2>/dev/null || true) || true
} > "$DOCS_DIR/mechanisms.md"

echo "  -> docs/mechanisms.html, docs/mechanisms.md"

# MECHANISMS — Complete Table
{
  html_head "Mechanisms — Complete Table" "mechanisms"
  subtabs_html "table" "mechanisms"
  echo "<p>Complete table with all fields including TCR4CAP comments.</p>"
  echo "<table id='mech-full'><tbody><tr><th data-sort='id'>ID</th><th data-sort='name'>Name</th><th data-sort='type'>Type</th><th data-sort='fl'>File-level</th><th data-sort='cl'>Content-level</th><th data-sort='mi'>Media Integrity</th><th data-sort='mdi'>Metadata Integrity</th><th data-sort='coc'>Chain of Custody</th><th>URL</th><th>Awareness</th><th>Tamper Evidence</th><th>Binding</th><th>AI Attribution</th><th>Substantiation</th><th>Interoperability</th></tr>"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//mechanism[@id='${id}']"
    name=$(xval    "$MECHANISMS_XML" "${b}/name")
    type=$(xval    "$MECHANISMS_XML" "${b}/type")
    fl=$(xval      "$MECHANISMS_XML" "${b}/editability/file-level/@type")
    cl=$(xval      "$MECHANISMS_XML" "${b}/editability/content-level/@type")
    mi=$(xval      "$MECHANISMS_XML" "${b}/verifiability/media-integrity/@type")
    mdi=$(xval     "$MECHANISMS_XML" "${b}/verifiability/metadata-integrity/@type")
    coc=$(xval     "$MECHANISMS_XML" "${b}/verifiability/chain-of-custody/@type")
    struct_row_vars "$MECHANISMS_XML" "$b" html
    echo "<tr><td><a href='mechanisms.html#mechanism-${id}'><code>${id}</code></a></td><td>${name}</td><td>${type}</td><td>${fl}</td><td>${cl}</td><td>${mi}</td><td>${mdi}</td><td>${coc}</td><td>${url_cell}</td><td>${aw:-—}</td><td>${te:-—}</td><td>${bi:-—}</td><td>${ai:-—}</td><td>${su:-—}</td><td>${io:-—}</td></tr>"
  done < <(xmlstarlet sel -t -m "//mechanism" -v "@id" -n "$MECHANISMS_XML" 2>/dev/null || true) || true
  echo "</tbody></table></body></html>"
} > "$DOCS_DIR/mechanisms-table.html"

{
  echo -e "# Mechanisms — Complete Table\n"
  echo "| ID | Name | Type | File-level | Content-level | Media Integrity | Metadata Integrity | Chain of Custody | URL | Awareness | Tamper Evidence | Binding | AI Attribution | Substantiation | Interoperability |"
  echo "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    b="//mechanism[@id='${id}']"
    name=$(xval    "$MECHANISMS_XML" "${b}/name")
    type=$(xval    "$MECHANISMS_XML" "${b}/type")
    fl=$(xval      "$MECHANISMS_XML" "${b}/editability/file-level/@type")
    cl=$(xval      "$MECHANISMS_XML" "${b}/editability/content-level/@type")
    mi=$(xval      "$MECHANISMS_XML" "${b}/verifiability/media-integrity/@type")
    mdi=$(xval     "$MECHANISMS_XML" "${b}/verifiability/metadata-integrity/@type")
    coc=$(xval     "$MECHANISMS_XML" "${b}/verifiability/chain-of-custody/@type")
    struct_row_vars "$MECHANISMS_XML" "$b" md
    echo "| \`${id}\` | ${name} | ${type} | ${fl} | ${cl} | ${mi} | ${mdi} | ${coc} | ${url_cell} | ${aw:-—} | ${te:-—} | ${bi:-—} | ${ai:-—} | ${su:-—} | ${io:-—} |"
  done < <(xmlstarlet sel -t -m "//mechanism" -v "@id" -n "$MECHANISMS_XML" 2>/dev/null || true) || true
} > "$DOCS_DIR/mechanisms-table.md"

echo "  -> docs/mechanisms-table.html, docs/mechanisms-table.md"

echo ""
echo "Build complete. Output in docs/:"
ls "$DOCS_DIR"/*.html "$DOCS_DIR"/*.md 2>/dev/null | sed 's|.*/||' | column
