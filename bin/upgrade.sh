#!/bin/bash
# Mole - Upgrade command.
# Updates package managers: Homebrew, pip, npm, nvm.
# Supports --dry-run.

set -euo pipefail
export LC_ALL=C
export LANG=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core/common.sh"
trap cleanup_temp_files EXIT INT TERM

DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
    --dry-run | -n)
        DRY_RUN=true
        export MOLE_DRY_RUN=1
        ;;
    *)
        echo "Unknown option: $arg"
        echo "Usage: mo upgrade [--dry-run]"
        exit 1
        ;;
    esac
done

print_header() {
    printf '\n'
    echo -e "${PURPLE_BOLD}Upgrade Package Managers${NC}"
}

run_upgrade_step() {
    local label="$1"
    local check_cmd="$2"
    local run_cmd="$3"
    local dryrun_cmd="$4"

    echo -ne "  ${PURPLE_BOLD}${ICON_ARROW}${NC} ${label}... "

    if ! eval "$check_cmd" >/dev/null 2>&1; then
        echo -e "${GRAY}skipped (not installed)${NC}"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}${ICON_DRY_RUN}${NC}"
        local output
        output=$(eval "$dryrun_cmd" 2>&1 || true)
        if [[ -n "$output" ]]; then
            printf '%s\n' "$output" | sed 's/^/    /'
        else
            echo -e "    ${GRAY}All packages up to date${NC}"
        fi
        return 0
    fi

    if [[ -t 1 ]]; then
        start_inline_spinner "Running..."
    fi

    local output exit_code=0
    output=$(eval "$run_cmd" 2>&1) || exit_code=$?

    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}${ICON_SUCCESS}${NC}"
    else
        echo -e "${RED}${ICON_ERROR}${NC}"
        if [[ -n "$output" ]]; then
            printf '%s\n' "$output" | sed 's/^/    /'
        fi
    fi
}

upgrade_homebrew() {
    run_upgrade_step "Homebrew" \
        "command -v brew" \
        "brew update && brew upgrade" \
        "brew outdated"
}

upgrade_pip() {
    local pip_cmd=""
    if command -v pip3 >/dev/null 2>&1; then
        pip_cmd="pip3"
    elif command -v pip >/dev/null 2>&1; then
        pip_cmd="pip"
    else
        pip_cmd=""
    fi

    if [[ -z "$pip_cmd" ]]; then
        echo -e "  ${PURPLE_BOLD}${ICON_ARROW}${NC} pip... ${GRAY}skipped (not installed)${NC}"
        return 0
    fi

    echo -ne "  ${PURPLE_BOLD}${ICON_ARROW}${NC} ${pip_cmd}... "

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}${ICON_DRY_RUN}${NC}"
        local output
        output=$($pip_cmd list --outdated 2>&1 || true)
        if [[ -n "$output" ]]; then
            printf '%s\n' "$output" | sed 's/^/    /'
        else
            echo -e "    ${GRAY}All packages up to date${NC}"
        fi
        return 0
    fi

    if [[ -t 1 ]]; then
        start_inline_spinner "Running..."
    fi

    local output exit_code=0
    output=$($pip_cmd list --outdated --format=freeze 2>/dev/null |
        grep -v '^\-e' | cut -d = -f 1 |
        xargs -n1 "$pip_cmd" install --upgrade 2>/dev/null || true)
    exit_code=$?

    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}${ICON_SUCCESS}${NC}"
    else
        echo -e "${RED}${ICON_ERROR}${NC}"
    fi
}

upgrade_npm() {
    run_upgrade_step "npm" \
        "command -v npm" \
        "npm update -g" \
        "npm outdated -g || true"
}

upgrade_nvm() {
    local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
    local nvm_sh="$nvm_dir/nvm.sh"

    echo -ne "  ${PURPLE_BOLD}${ICON_ARROW}${NC} nvm... "

    if [[ ! -s "$nvm_sh" ]]; then
        echo -e "${GRAY}skipped (not installed)${NC}"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}${ICON_DRY_RUN}${NC}"
        export NVM_DIR="$nvm_dir"
        # shellcheck source=/dev/null
        source "$nvm_sh"
        local current
        current=$(nvm version current 2>/dev/null || echo "system")
        local latest
        latest=$(nvm version-remote --lts 2>/dev/null || echo "unknown")
        echo -e "    Current: ${GRAY}${current}${NC}, Latest LTS: ${GRAY}${latest}${NC}"
        return 0
    fi

    if [[ -t 1 ]]; then
        start_inline_spinner "Running..."
    fi

    export NVM_DIR="$nvm_dir"
    # shellcheck source=/dev/null
    source "$nvm_sh"
    local output exit_code=0
    output=$(nvm install --lts 2>&1) || exit_code=$?

    if [[ -t 1 ]]; then
        stop_inline_spinner
    fi

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}${ICON_SUCCESS}${NC}"
    else
        echo -e "${RED}${ICON_ERROR}${NC}"
    fi
}

main() {
    print_header

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}${ICON_DRY_RUN} DRY RUN MODE${NC}, no packages will be updated\n"
    fi

    upgrade_homebrew
    upgrade_pip
    upgrade_npm
    upgrade_nvm

    printf '\n'
}

main "$@"
