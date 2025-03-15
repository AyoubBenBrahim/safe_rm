#!/bin/bash

# Version information
VERSION="1.0.0"

# Define ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
BLUE='\033[0;34m'
WHITE='\033[0;37m'
MAGENTA='\033[0;35m'

# Initialize flags
verbose=false
dry_run=false
auto_confirm=false
declare -a exclusions=()
log_file="$HOME/.safe_rm.log"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$log_file"
}

# Validate configuration file
validate_config() {
    local file="$1"
    local valid=true
    local line_num=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        
        # Check for invalid patterns
        if [[ "$line" =~ [^a-zA-Z0-9_.*\-\/\[\]\{\}\(\)\?\+] ]]; then
            echo -e "${RED}Invalid pattern at line $line_num: '$line'${NC}"
            valid=false
        fi
    done < "$file"
    
    $valid
}

display_help() {
    echo -e "${GREEN}Safe RM - Version $VERSION${NC}"
    # Get the script name from $0
    local script_name=$(basename "$0")
    
    echo
    echo -e "${GREEN}Usage:${NC}"
    echo "  $script_name [OPTIONS] FILE/DIRECTORY..."
    echo
    echo -e "${GREEN}Description:${NC}"
    echo "  Safely moves files/directories to the Trash instead of permanently deleting them."
    echo
    echo -e "${GREEN}Options:${NC}"
    echo "  -v              Enable verbose mode (show detailed output)."
    echo "  -n              Enable dry run mode (simulate moving files without actually doing it)."
    echo "  -e PATTERN      Exclude files/directories that match the pattern."
    echo "  -E \"P1,P2,P3\"   Exclude multiple patterns (comma-separated list)."
    echo "  -y              Automatically confirm all operations without prompting."
    echo "  --help              Display this help message and exit."
    echo
    echo -e "${GREEN}Examples:${NC}"
    echo "  $script_name file1.txt dir1         # Move file1.txt and dir1 to Trash."
    echo "  $script_name -v file1.txt           # Verbose mode: show detailed output."
    echo "  $script_name -n file1.txt           # Dry run mode: simulate moving file1.txt."
    echo "  $script_name -e \"*.txt\" *           # Exclude all .txt files from removal."
    echo "  $script_name -E \"file1,*.log,dir1\" * # Exclude multiple patterns."
    echo
    echo -e "${YELLOW}Note:${NC}"
    echo "  If a file/directory with the same name already exists in the Trash,"
    echo "  it will be renamed with a version number (e.g., file1_v1)."
    echo
    echo -e "${GREEN}Additional Info:${NC}"
    echo -e "${GREEN}Exclusion patterns support:${NC}"
    echo "  - Shell wildcards (*, ?, [])"
    echo "  - Full paths or file names"
    echo "  - Directory patterns with trailing slash (dir/)"
    echo
    echo -e "${YELLOW}Logs are stored in:${NC} $log_file"
}

# If no arguments are provided, display help message and exit
if [ $# -eq 0 ]; then
    display_help
    exit 0
fi

# Parse command-line options
while getopts ":vne:E:y-:" opt; do
    case "${opt}" in
        -)
            case "${OPTARG}" in
                version)
                    echo "safe_rm version $VERSION"
                    exit 0
                    ;;
                help)
                    display_help
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Invalid option: --${OPTARG}${NC}" >&2
                    exit 1
                    ;;
            esac
            ;;
        v) verbose=true ;;
        n) dry_run=true ;;
        e) exclusions+=("$OPTARG") ;;
        E) IFS=',' read -ra PATTERNS <<< "$OPTARG"
           for pattern in "${PATTERNS[@]}"; do
               exclusions+=("$pattern")
           done ;;
        y) auto_confirm=true ;;
        \?) echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
           exit 1 ;;
        :)  echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2
            exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# Ensure the Trash directory exists
TRASH_DIR="${HOME}/.Trash"
mkdir -p "$TRASH_DIR"
# mkdir -p "$(dirname "$log_file")"




# Function to generate a unique name with version numbers
generate_unique_name() {
    local base_name="$1"
    local counter=1
    local new_name="${base_name}_v${counter}"

    # Increment the counter until we find a unique name
    while [ -e "$TRASH_DIR/$new_name" ]; do
        counter=$((counter + 1))
        new_name="${base_name}_v${counter}"
    done

    echo "$new_name"
}

# Function to determine the type of file and set the appropriate color
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

# Function to move files/directories
move_to_trash() {
    local file="$1"
    local base_name=$(basename "$file")
    local trash_dir_name=$(basename "$TRASH_DIR")
    local use_sudo=false

    # Check if Trash directory exists and is writable
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

    # Check if we have sufficient permissions to move the file
    if [ ! -r "$file" ] || [ ! -w "$(dirname "$file")" ]; then
        if $verbose; then
            echo -e "'$file' ${YELLOW}has permission issues.${NC}"
        fi
        use_sudo=true
    fi

    if [ -e "$TRASH_DIR/$base_name" ]; then
        local new_name=$(generate_unique_name "$base_name")
        if [ $? -ne 0 ]; then
            return 1 # generate_unique_name failed
        fi
        if $verbose; then
            echo -e "${YELLOW}Renaming '$base_name' to '/$trash_dir_name/$new_name' to avoid conflicts.${NC}"
        fi
        if ! $dry_run; then
            log_message "INFO" "Moving '$file' to trash"
            if $use_sudo; then
                if ! sudo mv "$file" "$TRASH_DIR/$new_name" 2> /dev/null; then
                    if $verbose; then
                        echo -e "${RED}Failed to move '$file' to Trash (permission denied).${NC}"
                    fi
                    log_message "ERROR" "Failed to move '$file' to trash (permission denied)"
                    return 1
                fi
            else
                if ! mv "$file" "$TRASH_DIR/$new_name" 2> /dev/null; then
                    # If normal move fails, try with sudo
                    if $verbose; then
                        echo -e "${YELLOW}Permission denied. Trying with sudo...${NC}"
                    fi
                    if ! sudo mv "$file" "$TRASH_DIR/$new_name" 2> /dev/null; then
                        if $verbose; then
                            echo -e "${RED}Failed to move '$file' to Trash (permission denied).${NC}"
                        fi
                        log_message "ERROR" "Failed to move '$file' to trash (permission denied)"
                        return 1
                    fi
                fi
            fi
            log_message "SUCCESS" "Successfully moved '$file' to trash"
        else
            log_message "DRY-RUN" "Would move '$file' to trash"
            echo -e "${YELLOW}[Dry Run] Renaming '$base_name' to '/$trash_dir_name/$new_name'${NC}"
        fi
    else
        if $verbose; then
            echo -e "${YELLOW}Moving '$base_name' to Trash.${NC}"
        fi
        if ! $dry_run; then
            log_message "INFO" "Moving '$file' to trash"
            if $use_sudo; then
                if ! sudo mv "$file" "$TRASH_DIR/" 2> /dev/null; then
                    if $verbose; then
                        echo -e "${RED}Failed to move '$file' to Trash (permission denied).${NC}"
                    fi
                    log_message "ERROR" "Failed to move '$file' to trash (permission denied)"
                    return 1
                fi
            else
                if ! mv "$file" "$TRASH_DIR/" 2> /dev/null; then
                    echo -e "${RED}Error: Failed to move file to trash${NC}"
                    log_message "ERROR" "Move operation failed for: $file"
                    return 1
                fi
            fi
            log_message "SUCCESS" "Successfully moved '$file' to trash"
        else
            log_message "DRY-RUN" "Would move '$file' to trash"
            echo -e "${YELLOW}[Dry Run] Moving '$base_name' to '/$trash_dir_name/'${NC}"
        fi
    fi
    return 0
}

confirm_deletion() {
    local files=("$@")
    local total_files=${#files[@]}
    local display_count=10  # Display more files in confirmation

    echo -e "${YELLOW}The following items will be moved to Trash:${NC}"
    for ((i = 0; i < $display_count && i < total_files; i++)); do
        local color=$(get_file_color "${files[i]}")
        echo -e "  ${color}${files[i]}${NC}"
    done

    if [ $total_files -gt $display_count ]; then
        echo -e "${YELLOW}And $((total_files - $display_count)) more items.${NC}"
    fi
    
    # Skip confirmation if auto_confirm is enabled
    if $auto_confirm; then
        echo -e "${YELLOW}Auto-confirming deletion of $total_files items.${NC}"
        return 0
    fi

    echo -e "${YELLOW}Are you sure you want to move these $total_files items to Trash? [y/N]${NC}"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        return 0
    else
        echo -e "${RED}Operation canceled.${NC}"
        return 1
    fi
}

# Function to check if a file should be excluded
# should_exclude() {
#     local file="$1"
#     local basename=$(basename "$file")
    
#     for pattern in "${exclusions[@]}"; do
#         # Trim whitespace
#         pattern="${pattern## }"
#         pattern="${pattern%% }"
        
#         # Skip empty patterns
#         [ -z "$pattern" ] && continue
        
#         # Use shell pattern matching
#         if [[ "$basename" == $pattern || "$file" == $pattern ]]; then
#             return 0 # Should exclude
#         fi
#     done
    
#     return 1 # Should not exclude
# }

# Function to check if a file should be excluded
should_exclude() {
    local file="$1"
    local basename=$(basename "$file")
    local relative_path="${file#$PWD/}"  # Convert to relative path if possible
    
    for pattern in "${exclusions[@]}"; do
        # Trim whitespace
        pattern="${pattern## }"
        pattern="${pattern%% }"
        
        # Skip empty patterns
        [ -z "$pattern" ] && continue
        
        # Debug output if verbose mode is enabled
        if $verbose; then
            echo -e "${YELLOW}Checking if '$file' matches exclusion pattern '$pattern'${NC}" >&2
            echo -e "${YELLOW}Using relative path: '$relative_path'${NC}" >&2
        fi
        
        # Check if the file path matches the pattern (either absolute or relative)
        shopt -s extglob
        
        # Handle pattern with directory path
        if [[ "$pattern" == */* ]]; then
            # If pattern ends with /, add * to match all files in that directory
            if [[ "$pattern" == */ ]]; then
                pattern="${pattern}*"
            fi
            
            # Try matching against both absolute path and relative path
            if [[ "$file" == *"$pattern"* || "$relative_path" == $pattern || "$relative_path" == ${pattern}* ]]; then
                if $verbose; then
                    echo -e "${GREEN}Excluding: '$file' matches pattern '$pattern'${NC}" >&2
                fi
                return 0 # Should exclude
            fi
        # For simple filename patterns
        elif [[ "$basename" == $pattern ]]; then
            if $verbose; then
                echo -e "${GREEN}Excluding: '$basename' matches basename pattern '$pattern'${NC}" >&2
            fi
            return 0 # Should exclude
        fi
    done
    
    return 1 # Should not exclude
}

# Get list of files/directories to delete
files_to_delete=("$@")

# If multiple files/directories are provided, ask for confirmation
if [ ${#files_to_delete[@]} -gt 1 ]; then
    confirm_deletion "${files_to_delete[@]}" || exit 1
fi

# Arrays to store the status of moved files
moved_files=()
failed_files=()

# Loop through all provided arguments
for file in "${files_to_delete[@]}"; do
    # Input validation: Check if the file is an absolute path or relative
    if [[ "$file" != /* ]]; then
        file="$PWD/$file" # Convert to absolute path
    fi
    
    # Skip excluded files
    if should_exclude "$file"; then
        if $verbose; then
            echo -e "${YELLOW}Excluding '$file' from removal.${NC}"
        fi
        continue
    fi

    if ! move_to_trash "$file"; then
        failed_files+=("$file")
    else
        moved_files+=("$file")
    fi
done

# Print summary message
echo -e "${GREEN}${#moved_files[@]} items moved to Trash.${NC}"
if [ ${#failed_files[@]} -gt 0 ]; then
    echo -e "${RED}${#failed_files[@]} items failed to move to Trash (likely due to permissions).${NC}"
    echo -e "${RED}Failed items:${NC}"
    for file in "${failed_files[@]}"; do
        echo -e "  $file"
    done
    exit 1
fi

exit 0