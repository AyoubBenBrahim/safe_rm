#!/bin/bash

VERSION="2.0.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
BLUE='\033[0;34m'
WHITE='\033[0;37m'
MAGENTA='\033[0;35m'

verbose=false
dry_run=false
auto_confirm=false
interactive_mode=false
quiet=false
declare -a exclusions=()
log_file="$HOME/.safe_rm.log"
undo_file="$HOME/.safe_rm_undo.tsv"
mode="delete"
empty_days=""

TRASH_DIR="${TRASH_DIR:-${HOME}/.Trash}"

shopt -s extglob

DANGEROUS_PATHS=(
    "$HOME"
    "/"
    "/usr"
    "/etc"
    "/bin"
    "/sbin"
    "/System"
    "/Library"
    "$HOME/Library"
    "$HOME/Documents"
    "$HOME/Desktop"
    "$HOME/Downloads"
    "$HOME/Pictures"
    "$HOME/Music"
    "$HOME/Movies"
)

# ─── Logging ────────────────────────────────────────────────────────────────

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [ -w "$(dirname "$log_file")" ] || [ -w "$log_file" ]; then
        echo "[$timestamp] [$level] $message" >> "$log_file" 2>/dev/null
    fi
    rotate_log
}

rotate_log() {
    local max_lines=1000
    if [ -f "$log_file" ]; then
        local line_count
        line_count=$(wc -l < "$log_file" 2>/dev/null) || return
        if [ "$line_count" -gt "$max_lines" ]; then
            tail -n "$max_lines" "$log_file" > "${log_file}.tmp" \
                && mv "${log_file}.tmp" "$log_file"
        fi
    fi
}

# ─── Undo stack ─────────────────────────────────────────────────────────────

record_undo() {
    local original="$1"
    local trash_path="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '%s\t%s\t%s\n' "$timestamp" "$original" "$trash_path" >> "$undo_file"
}

# ─── Dangerous path guard ────────────────────────────────────────────────────

is_dangerous_path() {
    local file="${1%/}"
    local dangerous
    for dangerous in "${DANGEROUS_PATHS[@]}"; do
        dangerous="${dangerous%/}"
        [ "$file" = "$dangerous" ] && return 0
    done
    return 1
}

# ─── Help ────────────────────────────────────────────────────────────────────

display_help() {
    echo -e "${GREEN}Safe RM - Version $VERSION${NC}"
    local script_name
    script_name=$(basename "$0")
    echo
    echo -e "${GREEN}Usage:${NC}"
    echo "  $script_name [OPTIONS] FILE/DIRECTORY..."
    echo "  $script_name --restore [FILE]"
    echo "  $script_name --list"
    echo "  $script_name --empty [--days N]"
    echo "  $script_name --purge FILE"
    echo
    echo -e "${GREEN}Description:${NC}"
    echo "  Safely moves files/directories to the Trash instead of permanently deleting them."
    echo
    echo -e "${GREEN}Options:${NC}"
    echo "  -v              Enable verbose mode (show detailed output)."
    echo "  -n              Enable dry run mode (simulate moving files without actually doing it)."
    echo "  -q              Quiet mode (suppress output except errors)."
    echo "  -e PATTERN      Exclude files/directories that match the pattern."
    echo "  -E \"P1,P2,P3\"   Exclude multiple patterns (comma-separated list)."
    echo "  -y              Automatically confirm all operations without prompting."
    echo "  --help          Display this help message and exit."
    echo "  --version       Display version and exit."
    echo
    echo -e "${GREEN}Modes:${NC}"
    echo "  --restore [FILE]    Restore last trashed item, or FILE if specified."
    echo "  --list              List Trash contents with sizes and original paths."
    echo "  --empty             Permanently delete all Trash contents."
    echo "  --empty --days N    Permanently delete Trash items older than N days."
    echo "  --purge FILE        Permanently delete FILE (bypasses Trash, irreversible)."
    echo
    echo -e "${GREEN}Standard rm Compatibility:${NC}"
    echo "  -r, -R          Recursive (handled automatically, can be safely used)."
    echo "  -f              Force mode - suppress confirmations (implies -y)."
    echo "  -i              Interactive mode - ask for confirmation (opposite of -f)."
    echo "  -d              Ignore (for compatibility with rm -d)."
    echo
    echo -e "${GREEN}Examples:${NC}"
    echo "  $script_name file1.txt dir1          # Move file1.txt and dir1 to Trash."
    echo "  $script_name -v file1.txt            # Verbose mode: show detailed output."
    echo "  $script_name -n file1.txt            # Dry run: simulate moving file1.txt."
    echo "  $script_name -e \"*.txt\" *            # Exclude all .txt files."
    echo "  $script_name --restore               # Restore last trashed item."
    echo "  $script_name --restore file1.txt    # Restore specific file from Trash."
    echo "  $script_name --list                  # Show Trash contents."
    echo "  $script_name --empty                 # Empty the Trash."
    echo "  $script_name --empty --days 30       # Delete items older than 30 days."
    echo "  $script_name --purge secret.txt      # Permanently delete (no Trash)."
    echo
    echo -e "${YELLOW}Note:${NC}"
    echo "  If a file with the same name already exists in the Trash,"
    echo "  it will be renamed with a version number (e.g., file1_v1)."
    echo
    echo -e "${YELLOW}Logs are stored in:${NC} $log_file"
    echo -e "${YELLOW}Undo stack:${NC}       $undo_file"
}

# ─── Argument parsing ────────────────────────────────────────────────────────

if [ $# -eq 0 ]; then
    display_help
    exit 0
fi

while getopts ":vne:E:yrfRidq-:" opt; do
    case "${opt}" in
        -)
            case "${OPTARG}" in
                version) echo "safe_rm version $VERSION"; exit 0 ;;
                help)    display_help; exit 0 ;;
                restore) mode="restore" ;;
                list)    mode="list" ;;
                empty)   mode="empty" ;;
                purge)   mode="purge" ;;
                days=*)  empty_days="${OPTARG#*=}" ;;
                days)
                    empty_days="${!OPTIND}"
                    OPTIND=$((OPTIND + 1))
                    ;;
                force)        auto_confirm=true; interactive_mode=false ;;
                recursive)    ;;
                interactive*) interactive_mode=true; auto_confirm=false ;;
                *)
                    echo -e "${RED}Invalid option: --${OPTARG}${NC}" >&2
                    exit 1
                    ;;
            esac
            ;;
        v) verbose=true ;;
        n) dry_run=true ;;
        q) quiet=true ;;
        e) exclusions+=("$OPTARG") ;;
        E) IFS=',' read -ra PATTERNS <<< "$OPTARG"
           for pattern in "${PATTERNS[@]}"; do
               exclusions+=("$pattern")
           done ;;
        y) auto_confirm=true ;;
        r|R) ;;
        f)   auto_confirm=true; interactive_mode=false ;;
        i)   interactive_mode=true; auto_confirm=false ;;
        d)   ;;
        \?)  echo -e "${YELLOW}Warning: Unknown option -${OPTARG} ignored.${NC}" >&2 ;;
        :)   echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# ─── Trash setup ─────────────────────────────────────────────────────────────

if ! mkdir -p "$TRASH_DIR" 2>/dev/null; then
    echo -e "${RED}Error: Could not create Trash directory ($TRASH_DIR).${NC}" >&2
    exit 1
fi

# ─── Helpers ─────────────────────────────────────────────────────────────────

get_file_color() {
    local file="$1"
    if [ -d "$file" ]; then
        echo -e "${BLUE}"
    elif [[ "$file" == *.sh ]]; then
        echo -e "${MAGENTA}"
    else
        echo -e "${WHITE}"
    fi
}

get_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

generate_unique_name() {
    local base_name="$1"
    local counter=1
    local new_name="${base_name}_v${counter}"
    while [ -e "$TRASH_DIR/$new_name" ]; do
        counter=$((counter + 1))
        new_name="${base_name}_v${counter}"
    done
    echo "$new_name"
}

try_move() {
    local src="$1"
    local dest="$2"
    if mv "$src" "$dest" 2>/dev/null; then
        return 0
    fi
    $verbose && echo -e "${YELLOW}Permission denied. Trying with sudo...${NC}"
    sudo mv "$src" "$dest" 2>/dev/null
}

# ─── Mode: --restore ─────────────────────────────────────────────────────────

do_restore() {
    local target="$1"

    if [ ! -f "$undo_file" ] || [ ! -s "$undo_file" ]; then
        echo -e "${RED}No undo history found.${NC}"
        exit 1
    fi

    local match original_path trash_path

    if [ -z "$target" ]; then
        match=$(tail -n 1 "$undo_file")
    else
        match=$(grep -F "$target" "$undo_file" | tail -n 1)
        if [ -z "$match" ]; then
            echo -e "${RED}No undo record found for '$target'.${NC}"
            exit 1
        fi
    fi

    original_path=$(echo "$match" | cut -f2)
    trash_path=$(echo "$match" | cut -f3)

    if [ ! -e "$trash_path" ]; then
        echo -e "${RED}Trash file not found: $trash_path${NC}"
        exit 1
    fi

    local dest_dir
    dest_dir=$(dirname "$original_path")
    if [ ! -d "$dest_dir" ]; then
        echo -e "${RED}Original directory no longer exists: $dest_dir${NC}"
        exit 1
    fi

    if [ -e "$original_path" ] && ! $auto_confirm; then
        echo -e "${YELLOW}'$original_path' already exists. Overwrite? [y/N]${NC}"
        read -r -t 30 response
        [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]] && { echo -e "${RED}Canceled.${NC}"; exit 0; }
    fi

    if mv "$trash_path" "$original_path"; then
        $quiet || echo -e "${GREEN}Restored to '$original_path'.${NC}"
        log_message "RESTORE" "Restored '$trash_path' to '$original_path'"
        grep -vF "$trash_path" "$undo_file" > "${undo_file}.tmp" \
            && mv "${undo_file}.tmp" "$undo_file"
    else
        echo -e "${RED}Failed to restore '$trash_path'.${NC}"
        exit 1
    fi
}

# ─── Mode: --list ────────────────────────────────────────────────────────────

do_list() {
    local has_undo=false
    [ -f "$undo_file" ] && [ -s "$undo_file" ] && has_undo=true
    local find_count
    find_count=$(find "$TRASH_DIR" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l)
    if [ "$find_count" -eq 0 ] && ! $has_undo; then
        echo -e "${YELLOW}Trash is empty.${NC}"
        return
    fi

    echo -e "${YELLOW}Trash contents:${NC}"
    local total_size
    total_size=$(get_size "$TRASH_DIR" 2>/dev/null || echo "unknown")

    local items=()
    # Try find first; fall back to ls for macOS Trash permission restrictions
    while IFS= read -r item; do
        items+=("$item")
    done < <(find "$TRASH_DIR" -maxdepth 1 -mindepth 1 2>/dev/null | sort)

    if [ ${#items[@]} -eq 0 ] && [ -f "$undo_file" ] && [ -s "$undo_file" ]; then
        echo -e "${YELLOW}(Trash not directly readable — showing undo stack entries)${NC}"
        while IFS=$'\t' read -r ts original trash_path; do
            [ -e "$trash_path" ] || continue
            local basename size color
            basename=$(basename "$trash_path")
            size=$(get_size "$trash_path")
            color=$(get_file_color "$trash_path")
            echo -e "  ${color}${basename}${NC}  (${size})  ← ${original}"
        done < "$undo_file"
        echo -e "${YELLOW}Total: $(get_size "$TRASH_DIR" 2>/dev/null || echo "unknown")${NC}"
        return
    fi

    for item in "${items[@]}"; do
        local basename size color original
        basename=$(basename "$item")
        size=$(get_size "$item")
        color=$(get_file_color "$item")
        original=""
        [ -f "$undo_file" ] && original=$(grep -F "$item" "$undo_file" 2>/dev/null | tail -n1 | cut -f2)
        if [ -n "$original" ]; then
            echo -e "  ${color}${basename}${NC}  (${size})  ← ${original}"
        else
            echo -e "  ${color}${basename}${NC}  (${size})"
        fi
    done

    echo -e "${YELLOW}Total: ${total_size}${NC}"
}

# ─── Mode: --empty ───────────────────────────────────────────────────────────

do_empty() {
    local days="$1"

    if [ -z "$(ls -A "$TRASH_DIR" 2>/dev/null)" ]; then
        echo -e "${YELLOW}Trash is already empty.${NC}"
        return
    fi

    local items=()
    if [ -n "$days" ]; then
        while IFS= read -r item; do
            items+=("$item")
        done < <(find "$TRASH_DIR" -maxdepth 1 -mindepth 1 -mtime +"$days")
        if [ ${#items[@]} -eq 0 ]; then
            echo -e "${YELLOW}No items older than $days days.${NC}"
            return
        fi
        echo -e "${YELLOW}${#items[@]} items older than $days days will be permanently deleted.${NC}"
    else
        local total_size
        total_size=$(get_size "$TRASH_DIR")
        echo -e "${RED}Permanently delete ALL Trash contents (${total_size})? This cannot be undone. [y/N]${NC}"
    fi

    if ! $auto_confirm; then
        read -r -t 30 response
        [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]] && { echo -e "${RED}Canceled.${NC}"; return; }
    fi

    if [ -n "$days" ]; then
        for item in "${items[@]}"; do
            /bin/rm -rf "$item"
            log_message "PURGE" "Permanently deleted from Trash (age filter): $item"
        done
        $quiet || echo -e "${GREEN}${#items[@]} items permanently deleted.${NC}"
    else
        /bin/rm -rf "${TRASH_DIR:?}"/* 2>/dev/null
        [ -f "$undo_file" ] && > "$undo_file"
        log_message "EMPTY" "Trash emptied"
        $quiet || echo -e "${GREEN}Trash emptied.${NC}"
    fi
}

# ─── Mode: --purge ───────────────────────────────────────────────────────────

do_purge() {
    local file="$1"

    if [ -z "$file" ]; then
        echo -e "${RED}--purge requires a file argument.${NC}" >&2
        exit 1
    fi

    [[ "$file" != /* ]] && file="$PWD/$file"

    if [ ! -e "$file" ]; then
        echo -e "${RED}'$file' does not exist.${NC}"
        exit 1
    fi

    local size
    size=$(get_size "$file")

    echo -e "${RED}WARNING: Permanently delete '$file' (${size})? This CANNOT be undone. [y/N]${NC}"
    read -r -t 30 response
    [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]] && { echo -e "${RED}Canceled.${NC}"; exit 0; }

    if /bin/rm -rf "$file"; then
        $quiet || echo -e "${GREEN}Permanently deleted '$file'.${NC}"
        log_message "PURGE" "Permanently deleted: $file"
    else
        echo -e "${RED}Failed to delete '$file'.${NC}"
        exit 1
    fi
}

# ─── Dispatch modes ──────────────────────────────────────────────────────────

case "$mode" in
    restore) do_restore "$1"; exit $? ;;
    list)    do_list;         exit 0  ;;
    empty)   do_empty "$empty_days"; exit $? ;;
    purge)   do_purge "$1";   exit $? ;;
esac

# ─── Mode: delete (default) ──────────────────────────────────────────────────

move_to_trash() {
    local file="$1"
    local base_name
    base_name=$(basename "$file")
    local trash_dir_name
    trash_dir_name=$(basename "$TRASH_DIR")

    if [ ! -d "$TRASH_DIR" ] || [ ! -w "$TRASH_DIR" ]; then
        echo -e "${RED}Error: Trash directory ($TRASH_DIR) is not accessible${NC}"
        log_message "ERROR" "Trash directory not accessible: $TRASH_DIR"
        return 1
    fi

    if [ ! -e "$file" ]; then
        log_message "ERROR" "File not found: $file"
        echo -e "'$file' ${RED}does not exist or is not accessible.${NC}"
        return 1
    fi

    if [ ! -r "$file" ] || [ ! -w "$(dirname "$file")" ] || [ ! -x "$(dirname "$file")" ]; then
        $verbose && echo -e "'$file' ${YELLOW}has permission issues, attempting with sudo.${NC}"
    fi

    local dest_name="$base_name"
    local trash_path="$TRASH_DIR/$dest_name"

    if [ -e "$trash_path" ]; then
        dest_name=$(generate_unique_name "$base_name")
        trash_path="$TRASH_DIR/$dest_name"
        $verbose && echo -e "${YELLOW}Renaming '$base_name' to '/$trash_dir_name/$dest_name' to avoid conflicts.${NC}"
    else
        $verbose && echo -e "${YELLOW}Moving '$base_name' to Trash.${NC}"
    fi

    if ! $dry_run; then
        log_message "INFO" "Moving '$file' to trash"
        if ! try_move "$file" "$trash_path"; then
            echo -e "${RED}Failed to move '$file' to Trash (permission denied).${NC}"
            log_message "ERROR" "Failed to move '$file' to trash"
            return 1
        fi
        record_undo "$file" "$trash_path"
        log_message "SUCCESS" "Moved '$file' to '$trash_path'"
    else
        log_message "DRY-RUN" "Would move '$file' to '$trash_path'"
        echo -e "${YELLOW}[Dry Run] '$base_name' → '/$trash_dir_name/$dest_name'${NC}"
    fi
    return 0
}

confirm_deletion() {
    local files=("$@")
    local total_files=${#files[@]}
    local display_count=10

    echo -e "${YELLOW}The following items will be moved to Trash:${NC}"
    for ((i = 0; i < display_count && i < total_files; i++)); do
        local color size
        color=$(get_file_color "${files[i]}")
        size=$(get_size "${files[i]}")
        echo -e "  ${color}${files[i]}${NC}  (${size})"
    done

    if [ $total_files -gt $display_count ]; then
        echo -e "${YELLOW}And $((total_files - display_count)) more items.${NC}"
    fi

    if $auto_confirm; then
        $quiet || echo -e "${YELLOW}Auto-confirming deletion of $total_files items.${NC}"
        return 0
    fi

    echo -e "${YELLOW}Move these $total_files items to Trash? [y/N]${NC}"
    read -r -t 30 response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        return 0
    else
        echo -e "${RED}Operation canceled.${NC}"
        return 1
    fi
}

should_exclude() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    local relative_path="${file#$PWD/}"

    for pattern in "${exclusions[@]}"; do
        pattern="${pattern## }"
        pattern="${pattern%% }"
        [ -z "$pattern" ] && continue

        $verbose && echo -e "${YELLOW}Checking '$file' against pattern '$pattern'${NC}" >&2

        if [[ "$pattern" == */* ]]; then
            local match_pattern="${pattern%/}"
            if [[ "$file" == */"$match_pattern" || "$file" == */"$match_pattern"/* || \
                  "$relative_path" == "$match_pattern" || "$relative_path" == "$match_pattern"/* ]]; then
                $verbose && echo -e "${GREEN}Excluding: '$file' matches '$pattern'${NC}" >&2
                return 0
            fi
        elif [[ "$basename" == $pattern ]]; then
            $verbose && echo -e "${GREEN}Excluding: '$basename' matches '$pattern'${NC}" >&2
            return 0
        fi
    done

    return 1
}

files_to_delete=("$@")

if [ ${#files_to_delete[@]} -eq 0 ]; then
    echo -e "${RED}Error: No files specified.${NC}" >&2
    exit 1
fi

if $interactive_mode; then
    confirm_deletion "${files_to_delete[@]}" || exit 1
fi

moved_files=()
failed_files=()

for file in "${files_to_delete[@]}"; do
    [[ "$file" != /* ]] && file="$PWD/$file"

    if is_dangerous_path "$file"; then
        echo -e "${RED}Warning: '$file' is a protected path.${NC}"
        if ! $auto_confirm; then
            echo -e "${YELLOW}Trash this protected path anyway? [y/N]${NC}"
            read -r -t 30 confirm_resp
            if [[ ! "$confirm_resp" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                echo -e "${RED}Skipping '$file'.${NC}"
                continue
            fi
        fi
    fi

    if should_exclude "$file"; then
        $verbose && echo -e "${YELLOW}Excluding '$file' from removal.${NC}"
        continue
    fi

    if ! move_to_trash "$file"; then
        failed_files+=("$file")
    elif ! $dry_run; then
        moved_files+=("$file")
    fi
done

if $dry_run; then
    $quiet || echo -e "${YELLOW}[Dry Run] 0 items moved. Run without -n to apply.${NC}"
else
    $quiet || echo -e "${GREEN}${#moved_files[@]} items moved to Trash.${NC}"
fi
if [ ${#failed_files[@]} -gt 0 ]; then
    echo -e "${RED}${#failed_files[@]} items failed:${NC}"
    for file in "${failed_files[@]}"; do
        echo -e "  $file"
    done
    exit 1
fi

exit 0
