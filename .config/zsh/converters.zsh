# Dateipfad: ~/.config/zsh/converters.zsh
#
####### SKRIPTEN SAMMLUNG
#
# ALIASES
alias config='/usr/bin/git --git-dir=$HOME/.dotfiles.git/ --work-tree=$HOME'
#
#
#
### My custom symlinks 
alias doc2pdf='/Applications/LibreOffice.app/Contents/MacOS/soffice --headless --convert-to pdf'


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


#
# Rekursion (**/*): Das Skript sucht jetzt in allen Unterordnern.
#
# Zähler pro Ordner (local -A counters): Da du mehrere Ordner durchsuchst, merkt sich das Skript den aktuellen Zählerstand für jeden Ordner separat.
# 
# Dateigröße & Dimensionen: Durch -resize "1920x1920>" passt sich das Bild automatisch an – egal ob Hoch- oder Querformat, die jeweils längste Seite wird auf maximal 1920 Pixel gesetzt. WebP mit -quality 80 ist ein perfekter Sweetspot: Die Bilder bleiben visuell sehr gut, landen aber erfahrungsgemäß locker unter der 500-KB-Marke.
# 
# Ablageort: Die fertigen .webp-Dateien werden direkt im selben Unterordner gespeichert, in dem auch das Originalbild liegt.
#
#
#

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



# Du führst web_export_recursive aus. Die Bilder werden konvertiert, umbenannt und bleiben vorerst direkt neben den Originalen in ihren jeweiligen Unterordnern.

# Wenn du alle konvertiert hast und sie sammeln möchtest, tippst du move_webp_export ein. Das Skript saugt alle .webp-Dateien aus den Unterordnern ab und schiebt sie in den neuen Ordner webp_export in deinem aktuellen Verzeichnis.

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


# Konvertieren von Bildern zu EINEM Pdf

# Bilder zu PDF Konverter (Bulk)
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

export PATH="$HOME/.local/bin:$PATH"
