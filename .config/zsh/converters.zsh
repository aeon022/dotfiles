# Dateipfad: ~/.config/zsh/converters.zsh
#
####### SKRIPTEN SAMMLUNG #######
#
# INHALTSVERZEICHNIS
#
#   EDITOR & BASICS
#     config                → git-Alias für Dotfiles-Repo ($HOME als Worktree)
#     vi / vim               → Alias auf nvim
#     $EDITOR / $VISUAL      → nvim als Standard-Editor
#
#   BILDER & FOTOS
#     foto_rename            → JPGs in Unterordnern nach Ordnername + Datum umbenennen
#     web_export              → Bilder im aktuellen Ordner umbenennen, auf 1240px skalieren, zu WebP
#     web_export_recursive    → wie web_export, aber rekursiv über alle Unterordner (JPG/JPEG/HEIC/PNG)
#     move_webp_export        → sammelt alle .webp aus Unterordnern in ./webp_export
#     imgtopdf                → alle PNG/JPG im Ordner zu einem gemeinsamen PDF zusammenfügen
#
#   PDF & DOKUMENTE
#     doc2pdf                 → Alias: LibreOffice headless, beliebiges Dokument → PDF
#     pdfconvert [-m] [datei] → PDF → DOCX (Standard) oder Markdown (-m/--markdown);
#                               ohne Dateiangabe: alle *.pdf im aktuellen Ordner
#
#   SYNC & EXTENSIONS
#     ext_pull                → git pull für alle Repos in ~/Developing/Projects/Extensions
#     claude_pull              → git pull für ~/.claude (vor dem Arbeiten)
#     claude_push              → git add/commit/push für ~/.claude (nach dem Arbeiten)
#     dev_start                → claude_pull + ext_pull in einem Rutsch
#
#   SYMLINKS
#     GhibliKitchen            → Symlink in ~/.config/zsh/links auf das moving-kitchen-tales-Projekt
#
##################################


# ── Editor & Basics ──────────────────────────────────────────────────────────

alias config='/usr/bin/git --git-dir=$HOME/.dotfiles.git/ --work-tree=$HOME'

# Neovim als Standard für vi, vim und den Git-Editor
alias vi="nvim"
alias vim="nvim"
export EDITOR="nvim"
export VISUAL="nvim"


# ── Bilder & Fotos ────────────────────────────────────────────────────────────

# Alle JPGs in Unterordnern nach Ordnername & Datum umbenennen
foto_rename() {
  setopt extendedglob
  for d in */; do
    dir_name="${d%/}"
    # Bereinigung des Namens
    clean_name="${dir_name// /}"
    clean_name="${clean_name//ä/ae}"
    clean_name="${clean_name//ö/oe}"
    clean_name="${clean_name//ü/ue}"
    clean_name="${clean_name//ß/ss}"
    clean_name="${clean_name//„/ae}"
    clean_name="${clean_name//”/oe}"

    echo "Verarbeite Ordner: $dir_name -> $clean_name"

    i=1
    # (On) sortiert nach Name (alt), (om) nach Datum.
    # Wir nutzen (om) für die zeitliche Abfolge.
    for f in "$d"*(#i)jpg(om); do
      if [ -f "$f" ]; then
        mv "$f" "$d${clean_name}_$(printf "%03d" $i).jpg"
        ((i++))
      fi
    done
    echo "Fertig: $((i-1)) Bilder umbenannt."
  done
}

# Benennt Bilder um, skaliert auf max 1240px & konvertiert zu WebP
web_export() {
  setopt extendedglob
  local i=1
  local folder="${PWD##*/}"
  local folder_clean="${folder// /_}" # Leerzeichen durch Unterstrich für saubere URLs

  echo "Starte Export für Ordner: $folder"

  # Erweitert um jpeg und png
  for f in *.(#i)(jpg|jpeg|heic|png); do
    if [[ -f "$f" ]]; then
      local base="${f%.*}"
      local base_clean="${base// /_}"

      # Zielname: Ordner_Originalname_Index.webp
      local out_name="${folder_clean}_${base_clean}_$(printf "%03d" $i).webp"

      echo "Verarbeite: $f -> $out_name"

      # -auto-orient hinzugefügt, um Rotationsfehler zu vermeiden
      magick "$f" -auto-orient -resize "1240x1240>" -density 72 -quality 80 "$out_name"

      ((i++))
    fi
  done
  echo "Fertig! $((i-1)) WebP-Dateien wurden erstellt."
}

# Wie web_export, aber rekursiv über alle Unterordner (JPG/JPEG/HEIC/PNG).
# Zähler pro Ordner (local -A counters), damit die Nummerierung je Unterordner
# separat läuft. -resize "1920x1920>" begrenzt die längste Seite auf 1920px,
# ohne kleine Bilder aufzublähen. Die .webp-Dateien landen direkt neben dem
# jeweiligen Original im selben Unterordner.
web_export_recursive() {
  setopt extendedglob
  # Assoziatives Array, um die laufenden Nummern pro Ordner zu speichern
  local -A counters
  local total=0

  echo "Starte rekursiven WebP-Export (JPG, JPEG, HEIC, PNG)..."

  # Durchsucht alle Ordner nach jpg, jpeg, heic und png (case-insensitive)
  for f in **/*.(#i)(jpg|jpeg|heic|png); do
    if [[ -f "$f" ]]; then

      # 1. Pfad und Ordnernamen extrahieren
      local dir="${f%/*}"
      [[ "$dir" == "$f" ]] && dir="."

      local folder="${dir##*/}"
      [[ "$folder" == "." ]] && folder="${PWD##*/}"

      local folder_clean="${folder// /_}"

      # 2. Dateinamen extrahieren
      local filename="${f##*/}"
      local base="${filename%.*}"
      local base_clean="${base// /_}"
      local out_name=""

      # 3. Namenslogik: Prüfung auf generische Kameranamen
      if [[ "$base" == (#i)(img|dsc|pxl|wp|sam|pic|photo|bild|dji|screenshot)* || "$base" == [0-9_\-]## ]]; then
        local i=${counters[$folder_clean]:-1}
        out_name="${folder_clean}_$(printf "%03d" $i).webp"
        counters[$folder_clean]=$((i + 1))
      else
        out_name="${folder_clean}_${base_clean}.webp"
      fi

      # 4. Ausgabepfad festlegen
      local out_path="${dir}/${out_name}"

      echo "Verarbeite: $f -> $out_path ..."

      # 5. Konvertierung mit ImageMagick
      # -auto-orient korrigiert die Rotation basierend auf EXIF-Daten
      # -resize "1920x1920>" begrenzt die Größe, ohne kleine Bilder aufzublähen
      magick "$f" -auto-orient -resize "1920x1920>" -quality 80 "$out_path"

      ((total++))
    fi
  done

  echo "Fertig! $total WebP-Dateien wurden erstellt."
}

# Workflow: erst web_export_recursive ausführen (konvertiert & benennt um,
# Dateien bleiben neben den Originalen), danach move_webp_export, um alle
# .webp-Dateien aus den Unterordnern in einen gemeinsamen Ordner webp_export
# im aktuellen Verzeichnis zu sammeln.
move_webp_export() {
  setopt extendedglob
  local export_dir="${PWD}/webp_export"
  local count=0

  echo "Suche nach WebP-Dateien zum Verschieben..."

  # Erstelle den Export-Ordner, falls er noch nicht existiert
  if [[ ! -d "$export_dir" ]]; then
    mkdir -p "$export_dir"
    echo "Ordner 'webp_export' wurde angelegt."
  fi

  # Durchsucht alle Ordner und Unterordner nach .webp Dateien
  for f in **/*.webp; do
    if [[ -f "$f" ]]; then

      # Prüfen, ob die Datei nicht ohnehin schon im Export-Ordner liegt
      if [[ "$f" != webp_export/* && "$f" != */webp_export/* ]]; then

        local filename="${f##*/}"
        local dest="${export_dir}/${filename}"

        # Überschreibschutz: Falls eine Datei mit dem Namen schon im Export-Ordner liegt
        if [[ -f "$dest" ]]; then
          local base="${filename%.*}"
          dest="${export_dir}/${base}_$(date +%s).webp"
        fi

        mv "$f" "$dest"
        echo "Verschoben: $f -> $dest"
        ((count++))
      fi

    fi
  done

  echo "Fertig! $count WebP-Dateien wurden in den Ordner 'webp_export' verschoben."
}

# Bilder zu PDF Konverter (Bulk): fügt alle PNG/JPG im Ordner zu einem PDF zusammen
imgtopdf() {
    local folder="${PWD##*/}"
    local folder_clean="${folder// /_}"
    local files=(*.(png|jpg|jpeg|PNG|JPG|JPEG)(Nn))

    if [ ${#files[@]} -gt 0 ]; then
        echo "Wandle ${#files[@]} Bilder um..."
        magick "${files[@]}" "${folder_clean}_gesamt.pdf"
        echo "✅ Datei erstellt: ${folder_clean}_gesamt.pdf"
    else
        echo "❌ Keine Bilder (PNG/JPG) im Ordner gefunden."
    fi
}


# ── PDF & Dokumente ───────────────────────────────────────────────────────────

alias doc2pdf='/Applications/LibreOffice.app/Contents/MacOS/soffice --headless --convert-to pdf'

# PDF zu DOCX (Standard) oder Markdown (-m) konvertieren
# Nutzung: pdfconvert [-m|--markdown] [datei.pdf ...]
# Ohne Dateiangabe: alle PDFs im aktuellen Ordner
pdfconvert() {
  setopt local_options extendedglob null_glob
  local mode="docx"
  local -a files

  for arg in "$@"; do
    case "$arg" in
      -m|--markdown) mode="md" ;;
      -h|--help)
        echo "Nutzung: pdfconvert [-m|--markdown] [datei.pdf ...]"
        return 0
        ;;
      *) files+=("$arg") ;;
    esac
  done

  [ ${#files[@]} -eq 0 ] && files=(*.(#i)pdf)

  if [ ${#files[@]} -eq 0 ]; then
    echo "❌ Keine PDF-Dateien gefunden."
    return 1
  fi

  echo "Konvertiere ${#files[@]} PDF(s) nach ${mode}..."

  for f in "${files[@]}"; do
    if [[ ! -f "$f" ]]; then
      echo "⚠️  Übersprungen (nicht gefunden): $f"
      continue
    fi
    local base="${f:t:r}"
    local dir="${f:h}"

    if [[ "$mode" == "docx" ]]; then
      local out="${dir}/${base}.docx"
      if pdf2docx convert "$f" "$out" >/dev/null 2>&1; then
        echo "✅ $out"
      else
        echo "❌ Fehler bei $f"
      fi
    else
      local out="${dir}/${base}.md"
      if markitdown "$f" -o "$out" >/dev/null 2>&1; then
        echo "✅ $out"
      else
        echo "❌ Fehler bei $f"
      fi
    fi
  done

  echo "Fertig."
}


# ── Sync & Extensions ─────────────────────────────────────────────────────────

# Pullt alle Git-Repos im Extensions-Ordner
ext_pull() {
  local ext_dir="$HOME/Developing/Projects/Extensions"
  echo "=== Extensions pullen ==="
  for dir in "$ext_dir"/*/; do
    if [[ -d "$dir/.git" ]]; then
      echo "\n→ ${dir##*/}"
      git -C "$dir" pull
    fi
  done
  echo "\nDone."
}

# Sync ~/.claude vor dem Arbeiten (pull)
# Claude Code schreibt laufend in history.jsonl/settings.json — lokalen Stand
# erst committen, sonst bricht der Merge mit "would be overwritten" ab.
claude_pull() {
  echo "=== Claude sync: pull ==="
  git -C "$HOME/.claude" add projects/ history.jsonl settings.json
  git -C "$HOME/.claude" diff --cached --quiet || \
    git -C "$HOME/.claude" commit -m "sync $(date '+%Y-%m-%d %H:%M')"
  git -C "$HOME/.claude" pull --no-rebase origin main
}

# Sync ~/.claude nach dem Arbeiten (push)
# settings.json trägt u.a. enabledPlugins (z.B. ponytail, superpowers) — ohne
# das hier mitzunehmen, sieht das MacBook nicht, welche Plugins aktiv sind.
claude_push() {
  echo "=== Claude sync: push ==="
  git -C "$HOME/.claude" add projects/ history.jsonl settings.json
  git -C "$HOME/.claude" commit -m "sync $(date '+%Y-%m-%d %H:%M')" && \
  git -C "$HOME/.claude" push origin main
}

# Alles auf einmal: claude pull → ext pull
dev_start() {
  claude_pull
  ext_pull
}


# ── Symlinks ──────────────────────────────────────────────────────────────────

GHIBLI_KITCHEN_PATH="$HOME/Developing/Projects/moving-kitchen-tales"
ZSH_LINK_DIR="$HOME/.config/zsh/links"
GHIBLI_LINK="$ZSH_LINK_DIR/GhibliKitchen"

mkdir -p "$ZSH_LINK_DIR"

if [ -d "$GHIBLI_KITCHEN_PATH" ]; then
  if [ -L "$GHIBLI_LINK" ] || [ -e "$GHIBLI_LINK" ]; then
    rm -rf "$GHIBLI_LINK"
  fi
  ln -s "$GHIBLI_KITCHEN_PATH" "$GHIBLI_LINK"
fi


# Archive Export Skript
#
# Exportiert Fotos und gescannte PDFs als JPG und WebP.
# Die Unterordnerstruktur wird im Zielordner gespiegelt. Dateinamen folgen
# dem Muster <prefix>_<unterordner>_<foto>.jpg/.webp.
# Generische Namen wie „Scannen 41“ werden zu „foto_41“; aussagekräftige
# Dateinamen bleiben erhalten. Mehrseitige PDFs bekommen Seitennummern.
# Originalbilder bleiben unverändert. PDFs werden standardmäßig nicht
# umbenannt; mit --rename-pdfs erst nach erfolgreichem Export.
# Nutzung: media_export <quellordner> [zielordner] [prefix] [--rename-pdfs]
# Benötigt: magick, pdfinfo und pdftoppm (Poppler).
#
# source ~/.config/zsh/converters.zsh
# media_export "$HOME/Library/CloudStorage/OneDrive-VereinDieBrücke/Büro/Media/Archive" "$HOME/Library/CloudStorage/OneDrive-VereinDieBrücke/Büro/Media/Archive/_konvertiert" archiv --rename-pdfs
#
#

_media_slug() {
  local value="${1:l}"
  value="${value//ä/ae}"
  value="${value//ö/oe}"
  value="${value//ü/ue}"
  value="${value//ß/ss}"
  value="${value//[^a-z0-9]/_}"
  while [[ "$value" == *__* ]]; do value="${value//__/_}"; done
  value="${value#_}"
  value="${value%_}"
  print -r -- "$value"
}

media_export() {
  setopt local_options extendedglob null_glob

  local src="${1:-$PWD}"
  src="${src:A}"
  if [[ ! -d "$src" ]]; then
    print -u2 "Quellordner nicht gefunden: $src"
    return 1
  fi

  local dest="${2:-$src/_konvertiert}"
  dest="${dest:A}"
  local prefix="$(_media_slug "${3:-${src:t}}")"
  local rename_pdfs="${4:-}"

  if [[ -n "$rename_pdfs" && "$rename_pdfs" != "--rename-pdfs" ]]; then
    print -u2 "Vierter Parameter muss --rename-pdfs lauten."
    return 1
  fi

  local tool
  for tool in magick pdfinfo pdftoppm; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      print -u2 "Benötigtes Programm fehlt: $tool"
      return 1
    fi
  done

  mkdir -p "$dest" || return 1

  local -a files created
  local -A counters
  files=("$src"/**/*.(#i)(jpg|jpeg|png|heic|tif|tiff|webp|pdf)(N))

  local f relative parent folder_slug outdir base stem_slug digits canonical ext
  local jpg webp pdf_dest pages page page_base tmp success next
  local converted=0 skipped=0

  for f in "${files[@]}"; do
    [[ "$f" == "$dest"/* ]] && continue

    relative="${f#$src/}"
    parent="${relative:h}"
    [[ "$parent" == "." ]] && parent=""
    folder_slug="$(_media_slug "$parent")"
    [[ -n "$folder_slug" ]] || folder_slug="hauptordner"

    outdir="$dest"
    [[ -n "$parent" ]] && outdir="$dest/$parent"
    mkdir -p "$outdir" || return 1

    base="${relative:t:r}"
    stem_slug="$(_media_slug "$base")"

    if [[ "$base" == (#i)(scan|scannen|scanner|scanned|img|dsc|pxl|wp|sam|pic|photo|bild|dji|screenshot)* ]]; then
      digits="${base//[^0-9]/}"
      if [[ -n "$digits" ]]; then
        stem_slug="foto_${digits}"
      else
        next=$(( ${counters[$folder_slug]:-0} + 1 ))
        counters[$folder_slug]=$next
        stem_slug="foto_$(printf '%03d' "$next")"
      fi
    fi
    [[ -n "$stem_slug" ]] || stem_slug="foto"

    canonical="${prefix}_${folder_slug}_${stem_slug}"
    # Name trägt Präfix und Ordner schon (früher umbenannte PDFs): nicht doppelt voranstellen
    [[ "$stem_slug" == "${prefix}_${folder_slug}_"* ]] && canonical="$stem_slug"
    ext="${f:e:l}"

    if [[ "$ext" != "pdf" ]]; then
      jpg="$outdir/${canonical}.jpg"
      webp="$outdir/${canonical}.webp"

      if [[ -e "$jpg" || -e "$webp" ]]; then
        print "Übersprungen, Ausgabe existiert bereits: $outdir/$canonical"
        skipped=$((skipped + 1))
        continue
      fi

      if ! magick "$f" -auto-orient -background white -alpha remove -alpha off -quality 90 "$jpg"; then
        print -u2 "Fehler beim Erzeugen von $jpg"
        rm -f "$jpg"
        skipped=$((skipped + 1))
        continue
      fi
      if ! magick "$jpg" -quality 82 "$webp"; then
        print -u2 "Fehler beim Erzeugen von $webp"
        rm -f "$jpg" "$webp"
        skipped=$((skipped + 1))
        continue
      fi

      print "Erstellt: $jpg und $webp"
      converted=$((converted + 1))
      continue
    fi

    pdf_dest="${f:h}/${canonical}.pdf"
    if [[ "$rename_pdfs" == "--rename-pdfs" && "$pdf_dest" != "$f" && -e "$pdf_dest" ]]; then
      print "PDF-Ziel existiert bereits, übersprungen: $pdf_dest"
      skipped=$((skipped + 1))
      continue
    fi

    pages="$(pdfinfo "$f" 2>/dev/null | awk '/^Pages:[[:space:]]/ {print $2; exit}')"
    if [[ "$pages" != <-> ]]; then
      print -u2 "PDF nicht lesbar oder Seitenzahl fehlt: $f"
      skipped=$((skipped + 1))
      continue
    fi

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/media-export.XXXXXX")" || return 1
    created=()
    success=1

    for ((page = 1; page <= pages; page++)); do
      if ! pdftoppm -f "$page" -l "$page" -singlefile -jpeg -r 180 "$f" "$tmp/page" >/dev/null 2>&1; then
        success=0
        break
      fi

      page_base="$canonical"
      (( pages > 1 )) && page_base="${canonical}_seite_$(printf '%03d' "$page")"
      jpg="$outdir/${page_base}.jpg"
      webp="$outdir/${page_base}.webp"

      if [[ -e "$jpg" || -e "$webp" ]]; then
        success=0   # vorhandene Ausgabe nie löschen
        break
      fi

      if ! magick "$tmp/page.jpg" -auto-orient -background white -alpha remove -alpha off -quality 90 "$jpg" ||
         ! magick "$jpg" -quality 82 "$webp"; then
        rm -f "$jpg" "$webp"
        success=0
        break
      fi

      created+=("$jpg" "$webp")
    done

    rm -rf "$tmp"

    if (( success )); then
      if [[ "$rename_pdfs" == "--rename-pdfs" && "$pdf_dest" != "$f" ]] && ! mv "$f" "$pdf_dest"; then
        print -u2 "Bilder exportiert, PDF konnte aber nicht umbenannt werden: $f"
        skipped=$((skipped + 1))
        continue
      fi
      print "PDF exportiert: $relative"
      converted=$((converted + 1))
    else
      (( ${#created[@]} )) && rm -f "${created[@]}"
      print -u2 "PDF-Konvertierung fehlgeschlagen oder Ausgabedatei existiert: $f"
      skipped=$((skipped + 1))
    fi
  done

  print "Fertig: $converted verarbeitet, $skipped übersprungen."
}
