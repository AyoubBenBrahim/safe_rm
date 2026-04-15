# safe_rm

A drop-in `rm` replacement that moves files to Trash instead of permanently deleting them. Supports restore, Trash management, dangerous path protection, and full `rm` flag compatibility.

> `/bin/rm` is still available if you need permanent deletion. This script aliases `rm` to `safe_rm` so safe behavior is the default.

## Features

- Moves files/directories to Trash — never permanently deleted by accident
- **Restore** trashed files back to their original location
- **List** Trash contents with sizes and original paths
- **Empty** Trash (all at once or by age)
- **Purge** for intentional permanent deletion (with confirmation)
- Dangerous path guard — warns before trashing `~`, `/`, system dirs
- Undo stack (`~/.safe_rm_undo.tsv`) tracks every operation
- Log rotation — capped at 1000 lines
- Exclusion patterns with shell wildcards (`*`, `?`, `[]`)
- Dry run and verbose modes
- Full `rm` flag compatibility (`-r`, `-f`, `-i`, `-d`)
- Quiet mode for scripting
- Sudo fallback for permission-restricted files

## Installation

```bash
make install   # or: make i
```

To uninstall:

```bash
make uninstall
```

After install, reload your shell:

```bash
source ~/.zshrc   # zsh
source ~/.bashrc  # bash
```

## Usage

```bash
rm [OPTIONS] FILE/DIRECTORY...
rm --restore [FILE]
rm --list
rm --empty [--days N]
rm --purge FILE
```

## Options

| Option | Description |
|--------|-------------|
| `-v` | Verbose — show detailed output |
| `-n` | Dry run — simulate without moving anything |
| `-q` | Quiet — suppress all output except errors |
| `-y` | Auto-confirm all prompts |
| `-i` | Interactive — prompt before each operation |
| `-f` | Force — suppress confirmations (like standard `rm -f`) |
| `-r`, `-R` | Recursive (accepted for compatibility, handled automatically) |
| `-e PATTERN` | Exclude files matching pattern |
| `-E "P1,P2"` | Exclude multiple comma-separated patterns |
| `--help` | Show help and exit |
| `--version` | Show version and exit |

## Modes

| Command | Description |
|---------|-------------|
| `rm --restore` | Restore the last trashed item |
| `rm --restore FILE` | Restore a specific file by name |
| `rm --list` | List Trash contents with sizes and original paths |
| `rm --empty` | Permanently delete all Trash contents |
| `rm --empty --days N` | Permanently delete Trash items older than N days |
| `rm --purge FILE` | Permanently delete FILE — bypasses Trash, irreversible |

## Examples

```bash
# Trash a file
rm file.txt

# Trash multiple files/dirs (no prompt)
rm file1.txt dir1 node_modules

# Restore last trashed item
rm --restore

# Restore specific file
rm --restore file.txt

# List Trash contents
rm --list

# Empty Trash
rm --empty

# Delete Trash items older than 30 days
rm --empty --days 30

# Permanently delete (bypasses Trash)
rm --purge secret.txt

# Dry run — see what would be moved
rm -n file1.txt dir1

# Exclude .txt files
rm -e "*.txt" *

# Exclude multiple patterns
rm -E "*.log,*.tmp,node_modules" *

# Verbose output
rm -v file1.txt

# Quiet mode (no output, useful in scripts)
rm -q file1.txt
```

## Exclusion Patterns

Patterns support shell wildcards and are matched against filenames or paths:

| Pattern | Matches |
|---------|---------|
| `*.txt` | All `.txt` files |
| `??.md` | Any 2-char `.md` files |
| `file[1-3].log` | `file1.log`, `file2.log`, `file3.log` |
| `important.txt` | Exact filename |
| `build/` | All files inside `build/` directory |

Multiple patterns:
```bash
rm -e "*.log" -e "*.tmp" *          # chained -e
rm -E "*.log,*.tmp,build/" *         # comma-separated
```

## Protected Paths

The following paths trigger a warning and require explicit confirmation:

`~`, `/`, `/usr`, `/etc`, `/bin`, `/System`, `/Library`, `~/Documents`, `~/Desktop`, `~/Downloads`, `~/Pictures`, `~/Music`, `~/Movies`, `~/Library`

## Files

| File | Purpose |
|------|---------|
| `~/.Trash` | Trash directory |
| `~/.safe_rm.log` | Operation log (capped at 1000 lines) |
| `~/.safe_rm_undo.tsv` | Undo stack for `--restore` |

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make install` / `make i` | Install and add alias to shell config |
| `make uninstall` | Remove script, alias, log, and undo stack |
| `make test` | Run all 65 tests |
| `make verify` | Check installation status |
| `make script-help` | Show `safe_rm --help` |
| `make clean` | Remove temp files |
| `make update` | Pull latest version (requires git) |
| `make version` | Show installed version |
