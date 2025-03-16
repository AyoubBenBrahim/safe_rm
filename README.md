# Safe RM

A safer alternative to the standard `rm` command that moves files to trash instead of permanently deleting them.

> **Note:** You can still use the original `/bin/rm` command if needed. This script works by aliasing the `rm` command to `safe_rm`, ensuring safer file deletion by default.

## Features

- Moves files to trash instead of permanent deletion
- Confirmation before deletion
- Dry run mode
- Verbose output
- Exclusion patterns
- Handling of file conflicts
- Permission handling
- Logging of operations
- Special character and Unicode support

## Installation

You can install `safe_rm` using the provided Makefile. Run the following commands:

```bash
make install
```
or simply 
```bash
make i
```

To uninstall, use:

```bash
make uninstall
```

## Usage

```bash
safe_rm [OPTIONS] FILE/DIRECTORY...
```

## Options

| Option | Description |
| ------ | ----------- |
| `-v` | Enable verbose mode (show detailed output). |
| `-n` | Enable dry run mode (simulate moving files without actually doing it). |
| `-e PATTERN` | Exclude files/directories that match the pattern. |
| `-E LIST` | Exclude multiple patterns (comma-separated list). |
| `-y` | Automatically confirm all operations without prompting. |
| `--help` | Display this help message and exit. |
| `--version` | Display version information and exit. |

## Examples

```bash
# Move a single file to Trash
safe_rm file.txt

# Move multiple files and directories to Trash with verbose output
safe_rm -v file1.txt dir1

# Exclude all .txt files from removal
safe_rm -e "*.txt" *

# Exclude multiple patterns (e.g., .txt files, .log files, and a specific directory)
safe_rm -E "*.txt,*.log,dir1" *

# Use dry run mode to simulate the operation
safe_rm -n file1.txt

# Automatically confirm deletion without prompting
safe_rm -y file1.txt dir1
```

## Makefile Targets

The Makefile includes several useful targets:

- `help`: Show help message
- `install` or just `i`
- `uninstall`
- `test`: Run all tests
- `clean`: Remove temporary files
- `verify`: Check if the script is properly installed
- `update`: Update to the latest version (if using git)

## Exclusion Patterns

The exclusion patterns support:
- Shell wildcards (`*`, `?`, `[]`)
- Full paths or file names
- Directory patterns with trailing slash (`dir/`)
- Multiple exclusions using `-e` or `-E` options

## Logging

By default, logs are stored in `~/.safe_rm.log`. You can change the log file location by setting the `SAFE_RM_LOG` environment variable.

## Special Cases

- **Permissions:** The script handles read-only files and directories by prompting for sudo if necessary.
- **Special Characters:** Files with spaces, dashes, underscores, and Unicode characters are handled correctly.
- **Symlinks:** The script moves the symlink itself, not the target file.

## Examples of Exclusion

1. **Exclude a specific file:**
   ```bash
   safe_rm -e "important.txt" *
   ```

2. **Exclude all .txt files in a directory:**
   ```bash
   safe_rm -e "*.txt" documents/*
   ```

3. **Exclude multiple patterns:**
   ```bash
   safe_rm -E "file1,*.log,documents/private" *
   ```

4. **Exclude a directory and its contents:**
   ```bash
   safe_rm -e "downloads/" *
   ```