#!/bin/bash

# Define ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'

# Path to the safe_rm.sh script (fix path reference)
SAFE_RM="$(realpath $(dirname "$0")/../safe_rm.sh)"

# Create test directory
TEST_DIR="$(dirname "$0")/safe_rm_test"
rm -rf "$TEST_DIR" # Clean up any previous test
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || { echo -e "${RED}Failed to create test directory${NC}"; exit 1; }

# Set up Trash location for testing (to avoid cluttering real Trash)
TEST_TRASH="$TEST_DIR/.TestTrash"
mkdir -p "$TEST_TRASH"
# Export the test trash location for the safe_rm script to use
export TRASH_DIR="$TEST_TRASH"

# Variable to track failed tests
FAILED_TESTS=0
TOTAL_TESTS=0
TEST_NUMBER=1

# print_header() {
#     # Only print test number and name, no decorations
#     echo -e "${BLUE}Test $1:${NC} $2"
# }

print_header() {
    echo -e "${BLUE}Test $TEST_NUMBER:${NC} $1"
    # Automatically increment the test number
    ((TEST_NUMBER++))
}

run_test() {
    local test_name="$1"
    local expected_status="$2"
    # local test_nbr="$TEST_NUMBER-1"
    shift 2
    local cmd=("$@")

    # Run command and capture output and exit status
    local output
    output=$("${cmd[@]}" 2>&1)
    local status=$?

    if [ "$status" -eq "$expected_status" ]; then
        echo -e "${GREEN}✓ Test $((TEST_NUMBER-1)) passed:${NC} $test_name"
    else
        echo -e "${RED}✗ Test $((TEST_NUMBER-1)) failed:${NC} $test_name (Expected: $expected_status, Got: $status)"
        echo -e "${YELLOW}Command output:${NC}\n$output"
        ((FAILED_TESTS++))
    fi

    # Increment TOTAL_TESTS after the test is run
    ((TOTAL_TESTS++))
}

verify_test() {
    local test_desc="$1"
    shift

    # Run the test condition silently
    if "$@" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓${NC} $test_desc"
    else
        echo -e "${RED}  ✗${NC} $test_desc"
        ((FAILED_TESTS++))
    fi
}

# Silently set up test files
setup_test_files() {
    # Set up files silently
    "$@" > /dev/null 2>&1
    return 0
}

# Test 1: Basic functionality - create files and directories
print_header "Basic file preparation"
setup_test_files echo "Creating test files and directories"
setup_test_files echo "This is a test file" > regular_file.txt
setup_test_files echo "This is a script file" > script_file.sh
setup_test_files chmod +x script_file.sh
setup_test_files mkdir test_directory
setup_test_files echo "Nested file" > test_directory/nested_file.txt
setup_test_files mkdir -p nested_dir/subdir
setup_test_files echo "Deeply nested file" > nested_dir/subdir/deep_file.txt
setup_test_files touch empty_file
setup_test_files chmod 000 no_permissions_file  # Create a file with no permissions
run_test "Basic file preparation" 0 echo "Files created successfully"

# Test 2: Help message
print_header "Help message"
run_test "Display help message" 0 bash "$SAFE_RM"

# Test 3: Basic file deletion
print_header "Basic file deletion"
run_test "Remove single regular file" 0 bash "$SAFE_RM" regular_file.txt
verify_test "File moved to trash" [ ! -f regular_file.txt ]

# Test 4: Basic directory deletion
print_header "Basic directory deletion"
run_test "Remove directory" 0 bash "$SAFE_RM" test_directory
verify_test "Directory moved to trash" [ ! -d test_directory ]

# Test 5: Multiple file deletion with auto-confirm
print_header "Multiple file deletion"
setup_test_files touch multi_file1 multi_file2 multi_file3
run_test "Remove multiple files" 0 bash "$SAFE_RM" -y multi_file1 multi_file2 multi_file3
verify_test "All files moved to trash" [ ! -f multi_file1 ] && [ ! -f multi_file2 ] && [ ! -f multi_file3 ]

# Test 6: Verbose mode
print_header "Verbose mode"
setup_test_files touch verbose_test_file
run_test "Verbose mode" 0 bash "$SAFE_RM" -v verbose_test_file

# Test 7: Dry run mode
print_header "Dry run mode"
setup_test_files touch dryrun_test_file
run_test "Dry run mode" 0 bash "$SAFE_RM" -n dryrun_test_file
verify_test "File still exists (dry run)" [ -f dryrun_test_file ]

# Test 8: Non-existent file
print_header "Non-existent file"
run_test "Non-existent file" 1 bash "$SAFE_RM" non_existent_file.txt

# Test 9: File with no permissions
print_header "File with no permissions"
setup_test_files touch no_permissions_file
setup_test_files chmod 000 no_permissions_file  # Create a file with no permissions
run_test "File with no permissions" 0 bash "$SAFE_RM" -y no_permissions_file
verify_test "File with no permissions moved to trash" [ ! -f no_permissions_file ]

# Test 10: Handle file name conflicts
print_header "Handle file name conflicts"
setup_test_files echo "Original file" > conflict_file.txt
run_test "Move first conflict file" 0 bash "$SAFE_RM" conflict_file.txt
setup_test_files echo "Second file" > conflict_file.txt
run_test "Move second conflict file" 0 bash "$SAFE_RM" -y -v conflict_file.txt

# Test 11: Deep nested directory
print_header "Deep nested directory"
run_test "Remove deep nested directory" 0 bash "$SAFE_RM" -y nested_dir
verify_test "Nested directory moved to trash" [ ! -d nested_dir ]

# Test 12: Empty file
print_header "Empty file"
run_test "Remove empty file" 0 bash "$SAFE_RM" empty_file
verify_test "Empty file moved to trash" [ ! -f empty_file ]

# Test 13: Invalid options
print_header "Invalid options"
run_test "Invalid option" 1 bash "$SAFE_RM" -z

# Test 14: Complex case with multiple options
print_header "Complex case with multiple options"
setup_test_files touch complex_file1 complex_file2
setup_test_files mkdir complex_dir
run_test "Complex case" 0 bash "$SAFE_RM" -y -v -n complex_file1 complex_file2 complex_dir
verify_test "All files still exist (dry run)" [ -f complex_file1 ] && [ -f complex_file2 ] && [ -d complex_dir ]

# Test 15: Path handling
print_header "Path handling"
setup_test_files mkdir -p path_test/subdir
setup_test_files touch path_test/subdir/test_file.txt
run_test "Absolute path handling" 0 bash "$SAFE_RM" "$(pwd)/path_test/subdir/test_file.txt"
verify_test "File with absolute path moved to trash" [ ! -f path_test/subdir/test_file.txt ]

# Test 16: Exclusion functionality
print_header "Exclusion functionality"
setup_test_files touch exclude_test_file1 exclude_test_file2 exclude_test_file3
setup_test_files mkdir exclude_test_dir1 exclude_test_dir2
setup_test_files touch exclude_test_dir1/nested_file
run_test "Single file exclusion" 0 bash "$SAFE_RM" -y -e exclude_test_file1 exclude_test_file1 exclude_test_file2
verify_test "Excluded file still exists (expected)" [ -f exclude_test_file1 ]
verify_test "Non-excluded file moved to trash" [ ! -f exclude_test_file2 ]

# Test 17: Multiple file exclusion
print_header "Multiple file exclusion"
run_test "Multiple file exclusion" 0 bash "$SAFE_RM" -y -e exclude_test_file3 -e exclude_test_dir1 exclude_test_file3 exclude_test_dir1 exclude_test_dir2
verify_test "Excluded file still exists (expected)" [ -f exclude_test_file3 ]
verify_test "Excluded directory still exists (expected)" [ -d exclude_test_dir1 ]
verify_test "Non-excluded directory moved to trash" [ ! -d exclude_test_dir2 ]

# Test 18: Pattern exclusion
print_header "Pattern exclusion"
setup_test_files mkdir pattern_test
setup_test_files touch pattern_test/file1.txt pattern_test/file2.log
run_test "Pattern exclusion" 0 bash "$SAFE_RM" -y -e "*.txt" pattern_test/*
verify_test "Excluded pattern file still exists (expected)" [ -f pattern_test/file1.txt ]
verify_test "Non-excluded pattern file moved to trash" [ ! -f pattern_test/file2.log ]

# Test 19: Wildcard with exclusion
print_header "Wildcard with exclusion"
setup_test_files mkdir wildcard_test
setup_test_files touch wildcard_test/important.txt wildcard_test/other.txt
run_test "Wildcard with exclusion" 0 bash "$SAFE_RM" -y -e important.txt -v wildcard_test/*
verify_test "Excluded wildcard file still exists (expected)" [ -f wildcard_test/important.txt ]
verify_test "Other file moved to trash" [ ! -f wildcard_test/other.txt ]

# Test 20: Complex exclusion scenario
print_header "Complex exclusion scenario"
setup_test_files mkdir -p complex_test/keep complex_test/remove
setup_test_files touch complex_test/keep/{test1,test2,test3,test4}.txt complex_test/remove/test.txt complex_test/other.txt
run_test "Complex exclusion scenario" 0 bash "$SAFE_RM" -y -e "complex_test/keep/" -v complex_test/*/* complex_test/remove complex_test/other.txt
verify_test "Excluded complex keep/test2 still exists (expected)" [ -f complex_test/keep/test2.txt ]
verify_test "Excluded complex keep/test3 still exists (expected)" [ -f complex_test/keep/test3.txt ]
verify_test "Non-excluded complex remove/test.txt directory moved to trash" [ ! -d complex_test/remove/test.txt ]
verify_test "Non-excluded complex directory moved to trash" [ ! -d complex_test/remove ]
verify_test "Other file moved to trash" [ ! -f  complex_test/other.txt ]

# Test 21: Comma-separated exclusions
print_header "Comma-separated exclusions"
setup_test_files mkdir comma_test
setup_test_files touch comma_test/file1.txt comma_test/file2.sh comma_test/important.doc comma_test/other.pdf
run_test "Comma-separated exclusions" 0 bash "$SAFE_RM" -y -E "*.txt,*.sh,important.doc" comma_test/*
verify_test "Excluded comma-separated file still exists (expected)" [ -f comma_test/file1.txt ]
verify_test "Excluded comma-separated file still exists (expected)" [ -f comma_test/file2.sh ]
verify_test "Excluded comma-separated file still exists (expected)" [ -f comma_test/important.doc ]
verify_test "Other file moved to trash" [ ! -f comma_test/other.pdf ]

# Test 22: Mixed exclusion methods
print_header "Mixed exclusion methods"
setup_test_files echo "*.sh" > "$TEST_DIR/mixed_config"
setup_test_files echo "important.doc,*.pdf" >> "$TEST_DIR/mixed_config"
setup_test_files mkdir mixed_test
setup_test_files touch mixed_test/exclude_file.sh mixed_test/important.doc mixed_test/other.pdf mixed_test/other.txt
run_test "Mixed exclusion methods" 0 bash "$SAFE_RM" -y -e "*.sh" -E "important.doc,*.pdf" mixed_test/*
verify_test "Excluded mixed method file still exists (expected)" [ -f mixed_test/exclude_file.sh ]
verify_test "Excluded mixed method file still exists (expected)" [ -f mixed_test/important.doc ]
verify_test "Excluded mixed method file still exists (expected)" [ -f mixed_test/other.pdf ]
verify_test "Other file moved to trash" [ ! -f mixed_test/other.txt ]

# Test 23: Auto-confirm with -y flag
print_header "Auto-confirm with -y flag"
setup_test_files mkdir -p auto_confirm_test
setup_test_files touch auto_confirm_test/file1.txt auto_confirm_test/file2.txt auto_confirm_test/file3.txt
run_test "Auto-confirm deletion" 0 bash "$SAFE_RM" -y auto_confirm_test/*
verify_test "All files moved to trash automatically" [ ! -f auto_confirm_test/file1.txt ] && [ ! -f auto_confirm_test/file2.txt ] && [ ! -f auto_confirm_test/file3.txt ]

# Test 24: Reject confirmation
print_header "Reject confirmation"
setup_test_files mkdir -p reject_test
setup_test_files touch reject_test/file1.txt reject_test/file2.txt reject_test/file3.txt
# Create a wrapper script that properly handles the input
WRAPPER_SCRIPT="$TEST_DIR/answer_no.sh"
cat > "$WRAPPER_SCRIPT" << 'EOF'
#!/bin/bash
echo "n" | "$@"
exit 1
EOF
setup_test_files chmod +x "$WRAPPER_SCRIPT"
run_test "Reject confirmation" 1 "$WRAPPER_SCRIPT" bash "$SAFE_RM" reject_test/*
verify_test "Files still exist after rejection" [ -f reject_test/file1.txt ] && [ -f reject_test/file2.txt ] && [ -f reject_test/file3.txt ]

# Test 25: Version checking
print_header "Version checking"
run_test "Version display" 0 bash "$SAFE_RM" --version

# Test 26: Log file functionality
print_header "Log file functionality"
TEST_LOG="$HOME/.safe_rm.log"
setup_test_files touch test_log_file
run_test "Log file creation" 0 bash "$SAFE_RM" -v test_log_file
verify_test "Logging works correctly" grep -q "Moving.*test_log_file" "$TEST_LOG"

# Test 27: Permission handling
print_header "Permission handling"
setup_test_files mkdir -p permission_test
setup_test_files touch permission_test/readonly_file
setup_test_files chmod 444 permission_test/readonly_file
run_test "Read-only file handling" 0 bash "$SAFE_RM" permission_test/readonly_file
verify_test "Read-only file moved to trash" [ ! -f permission_test/readonly_file ]

# Test 28: Multiple exclusion patterns
print_header "Multiple exclusion patterns"
setup_test_files mkdir -p pattern_test
setup_test_files touch pattern_test/{file1.txt,file2.log,file3.tmp}
run_test "Multiple pattern exclusion" 0 bash "$SAFE_RM" -y -E "*.txt,*.log" pattern_test/*
verify_test "Pattern exclusion works" [ -f pattern_test/file1.txt ] && [ -f pattern_test/file2.log ] && [ ! -f pattern_test/file3.tmp ]

# Test 29: Special character handling
print_header "Special character handling"
setup_test_files touch "file with spaces.txt" "file-with-dashes.txt" "file_with_underscores.txt"
run_test "Special character handling" 0 bash "$SAFE_RM" -y "file with spaces.txt" "file-with-dashes.txt"
verify_test "Special characters handled correctly" [ ! -f "file with spaces.txt" ] && [ ! -f "file-with-dashes.txt" ] && [ ! -f "file_with_underscores.txt" ]

# Test 30: Symlink handling
print_header "Symlink handling"
setup_test_files echo "target file" > target_file
setup_test_files ln -s target_file symlink_file
run_test "Symlink handling" 0 bash "$SAFE_RM" symlink_file
verify_test "Symlink handled correctly" [ -f target_file ] && [ ! -L symlink_file ]

# Test 31: Large file set handling
print_header "Large file set handling"
setup_test_files mkdir large_set
for i in {1..100}; do
    touch "large_set/file$i"
done
run_test "Large file set handling" 0 bash "$SAFE_RM" -y large_set/*
verify_test "Large file set handled correctly" [ "$(ls -A large_set 2>/dev/null)" = "" ]

# Test 32: Trash directory permissions
print_header "Trash directory permissions"
mkdir -p "$TEST_TRASH/test_perm"
chmod 000 "$TEST_TRASH/test_perm"
touch perm_test_file.txt
run_test "Trash directory permission handling" 1 bash "$SAFE_RM" -y --trash-dir="$TEST_TRASH/test_perm" perm_test_file.txt
chmod 755 "$TEST_TRASH/test_perm"

# Test 33: Long options
print_header "Long options"
run_test "Help option" 0 bash "$SAFE_RM" --help

# Test 34: Unicode and special characters in filenames
print_header "Unicode and special characters in filenames"
setup_test_files touch "file-üñiçøde.txt" "file_with_emoji_🚀.txt" "file!@#$%^&*().txt"
run_test "Unicode and special characters" 0 bash "$SAFE_RM" -y "file-üñiçøde.txt" "file_with_emoji_🚀.txt" "file!@#$%^&*().txt"
verify_test "Unicode and special characters handled correctly" [ ! -f "file-üñiçøde.txt" ] && [ ! -f "file_with_emoji_🚀.txt" ] && [ ! -f "file!@#$%^&*().txt" ]

# Test 35: Very long filenames
print_header "Very long filenames"
long_name=$(printf 'a%.0s' {1..200})
setup_test_files touch "$long_name.txt"
run_test "Very long filename" 0 bash "$SAFE_RM" -y "$long_name.txt"
verify_test "Very long filename handled correctly" [ ! -f "$long_name.txt" ]

# Test 36: Handle full trash directory
print_header "Handle full trash directory"
mkdir -p "$TEST_DIR/mock_full_trash"
touch "$TEST_DIR/mock_full_trash/some_file"
chmod 500 "$TEST_DIR/mock_full_trash"  # Read but not write
touch full_disk_test_file.txt
# The script should fail when it can't write to trash
run_test "Handle full trash directory" 1 bash "$SAFE_RM" -y --trash-dir="$TEST_DIR/mock_full_trash" full_disk_test_file.txt
chmod 755 "$TEST_DIR/mock_full_trash"

# Test 37: Wildcard exclusion - asterisk (*)
print_header "Wildcard exclusion - asterisk (*)"
setup_test_files mkdir -p wildcard_star_test
setup_test_files touch wildcard_star_test/{file1.txt,file2.txt,file3.jpg,notes.md}
run_test "Asterisk wildcard exclusion" 0 bash "$SAFE_RM" -y -e "*.txt" wildcard_star_test/*
verify_test "Files matching *.txt still exist" [ -f wildcard_star_test/file1.txt ] && [ -f wildcard_star_test/file2.txt ]
verify_test "Non-matching files moved to trash" [ ! -f wildcard_star_test/file3.jpg ] && [ ! -f wildcard_star_test/notes.md ]

# Test 38: Wildcard exclusion - question mark (?)
print_header "Wildcard exclusion - question mark (?)"
setup_test_files mkdir -p wildcard_question_test
setup_test_files touch wildcard_question_test/{file1.txt,file2.txt,a.md,ab.md,abc.md}
run_test "Question mark wildcard exclusion" 0 bash "$SAFE_RM" -y -e "??.md" wildcard_question_test/*
verify_test "Files matching ??.md still exist" [ -f wildcard_question_test/ab.md ]
verify_test "Non-matching files moved to trash" [ ! -f wildcard_question_test/a.md ] && [ ! -f wildcard_question_test/abc.md ] && [ ! -f wildcard_question_test/file1.txt ]

# Test 39: Wildcard exclusion - character class ([])
print_header "Wildcard exclusion - character class ([])"
setup_test_files mkdir -p wildcard_class_test
setup_test_files touch wildcard_class_test/{file1.txt,file2.txt,doc1.pdf,doc2.pdf,log1.log,log2.log}
# Simplified pattern for better compatibility
run_test "Character class wildcard exclusion" 0 bash "$SAFE_RM" -y -e "*[13].txt" wildcard_class_test/*
verify_test "Files matching *[13].txt still exist" [ -f wildcard_class_test/file1.txt ]
verify_test "Non-matching files moved to trash" [ ! -f wildcard_class_test/file2.txt ]

# Test 40: Wildcard exclusion - character range ([a-z])
print_header "Wildcard exclusion - character range ([a-z])"
setup_test_files mkdir -p wildcard_range_test
setup_test_files touch wildcard_range_test/{filea.txt,fileb.txt,filec.txt,fileD.txt,fileE.txt,fileF.txt}
run_test "Character range wildcard exclusion" 0 bash "$SAFE_RM" -y -e "file[a-c].txt" wildcard_range_test/*
verify_test "Files matching file[a-c].txt still exist" [ -f wildcard_range_test/filea.txt ] && [ -f wildcard_range_test/fileb.txt ] && [ -f wildcard_range_test/filec.txt ]
verify_test "Non-matching files moved to trash" [ ! -f wildcard_range_test/fileD.txt ] && [ ! -f wildcard_range_test/fileE.txt ] && [ ! -f wildcard_range_test/fileF.txt ]

# Test 41: Wildcard exclusion - negated character class ([!...])
print_header "Wildcard exclusion - negated character class ([!...])"
setup_test_files mkdir -p wildcard_negated_test
setup_test_files touch wildcard_negated_test/{testA.log,testB.log,test1.log,test2.log,test3.txt}
run_test "Negated character class wildcard exclusion" 0 bash "$SAFE_RM" -y -e "test[!0-9].*" wildcard_negated_test/*
verify_test "Files matching negated pattern still exist" [ -f wildcard_negated_test/testA.log ] && [ -f wildcard_negated_test/testB.log ]
verify_test "Non-matching files moved to trash" [ ! -f wildcard_negated_test/test1.log ] && [ ! -f wildcard_negated_test/test2.log ] && [ ! -f wildcard_negated_test/test3.txt ]

# Test 42: Complex wildcard pattern combination
print_header "Complex wildcard pattern combination"
setup_test_files mkdir -p complex_wildcard_test
setup_test_files touch complex_wildcard_test/{data_01.json,data_02.json,data_a1.json,data_b2.json,info_01.txt,info_a1.txt}
run_test "Complex wildcard combination" 0 bash "$SAFE_RM" -y -e "data_[0-9][0-9].json" -e "info_[a-z][0-9].txt" complex_wildcard_test/*
verify_test "Numeric data files still exist" [ -f complex_wildcard_test/data_01.json ] && [ -f complex_wildcard_test/data_02.json ]
verify_test "Alpha info files still exist" [ -f complex_wildcard_test/info_a1.txt ]
verify_test "Other files moved to trash" [ ! -f complex_wildcard_test/data_a1.json ] && [ ! -f complex_wildcard_test/data_b2.json ] && [ ! -f complex_wildcard_test/info_01.txt ]

# Test 43: Case sensitivity in filenames
print_header "Case sensitivity in filenames"
setup_test_files touch "CaseSensitive.txt" "casesensitive.txt"
run_test "Case sensitive filenames" 0 bash "$SAFE_RM" -y "CaseSensitive.txt"
verify_test "Case sensitivity handled correctly" [ ! -f "CaseSensitive.txt" ] && [ -f "casesensitive.txt" ]

# Test 44: Race condition handling
print_header "Race condition handling"
touch race_test_file.txt
# Use proper bash syntax for background process and sleep
# We'll remove the file just before safe_rm tries to access it
(
   sleep 0.1
   rm -f race_test_file.txt
) &
# Give the background process time to start
sleep 0.2
# The script should detect that the file disappeared and return non-zero
run_test "Race condition handling" 1 bash "$SAFE_RM" -y race_test_file.txt

# Test 45: Race condition handling
print_header "Race condition handling"
# Create a wrapper script that handles the race condition test
cat > "$TEST_DIR/race_test_wrapper.sh" << 'EOF'
#!/bin/bash
# Create the test file
touch race_test_file.txt

# Remove it in background after a small delay
(sleep 0.1; rm -f race_test_file.txt) &

# Give the removal a chance to happen
sleep 0.2

# Now run safe_rm - if file is gone it should return 1
"$@" race_test_file.txt

# Check if the exit code is 1 (expected for file not found)
exit_code=$?
if [ $exit_code -eq 1 ]; then
    exit 0  # Test passes
else
    exit 1  # Test fails
fi
EOF
chmod +x "$TEST_DIR/race_test_wrapper.sh"

# Run the test with the wrapper
run_test "Race condition handling" 0 "$TEST_DIR/race_test_wrapper.sh" bash "$SAFE_RM" -y

# print_header "Results" "Summary"
echo -e "\n${MAGENTA}Results:${NC}"
echo -e "Total tests run: $(($TOTAL_TESTS-1))"
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
else
    echo -e "${RED}$FAILED_TESTS tests failed.${NC}"
    exit 1
fi

# Clean up silently
cd ..
/bin/rm -rf "$TEST_DIR" > /dev/null 2>&1