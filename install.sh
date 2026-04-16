#!/usr/bin/env bash
# Main installer script for the modular development environment

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
PROFILE_CONFIG="$CONFIG_DIR/profiles"
LIB_DIR="$SCRIPT_DIR/lib"
MODULES_DIR="$SCRIPT_DIR/modules"
LOGS_DIR="$SCRIPT_DIR/logs"

# Default values
PROFILE="ml-dev"
DRY_RUN=false
FORCE=false
VERBOSE=false
LOG_LEVEL="INFO"
VALIDATE_ONLY=false
LIST_PROFILES_ONLY=false
SHOW_PROFILE=""
SETUP_VAULT=false
VAULT_ARGS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions (basic versions before library load)
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] [$level]${NC} $message"
}

log_error() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] [ERROR]${NC} $message" >&2
}

log_warn() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] [WARN]${NC} $message"
}

# List available profiles
list_profiles() {
    # Initialize YAML parser if not already done
    if [[ -z "${YAML_PARSER:-}" ]]; then
        check_yaml_parser
    fi

    echo "Available installation profiles:"
    echo
    for profile_file in "$PROFILE_CONFIG"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name
            profile_name=$(basename "$profile_file" .yaml)
            local description
            description=$(yaml_get "$profile_file" "description")
            printf "  %-15s %s\n" "$profile_name" "$description"
        fi
    done
    echo
    echo "Use --show-profile <name> for detailed information."
}

# Show detailed profile information
show_profile() {
    local profile="$1"
    local profile_file="$PROFILE_CONFIG/$profile.yaml"

    # Initialize YAML parser if not already done
    if [[ -z "${YAML_PARSER:-}" ]]; then
        check_yaml_parser
    fi

    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile '$profile' not found"
        list_profiles
        exit 1
    fi

    echo "Profile: $profile"
    echo "File: $profile_file"
    echo

    local description
    description=$(yaml_get "$profile_file" "description")
    echo "Description: $description"

    local version
    version=$(yaml_get "$profile_file" "version")
    echo "Version: $version"
    echo

    echo "Modules to install:"
    local module_count
    module_count=$(yaml_get "$profile_file" "includes | length")
    if [[ "$module_count" != "null" && "$module_count" -gt 0 ]]; then
        for ((i=0; i<module_count; i++)); do
            local module
            module=$(yaml_get "$profile_file" "includes[$i]")
            echo "  - $module"
        done
    fi
    echo

    # Show customizations if any
    local customizations
    customizations=$(yaml_get "$profile_file" "customizations")
    if [[ "$customizations" != "null" && -n "$customizations" ]]; then
        echo "Customizations:"
        yq '.customizations' "$profile_file" | sed 's/^/  /'
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Modular installer for development environments on Arch Linux.

OPTIONS:
    -p, --profile PROFILE    Installation profile (minimal, ml-dev, security-dev)
                             Default: ml-dev
    -d, --dry-run           Show what would be done without making changes
    -f, --force             Force installation even if components exist
    -v, --verbose           Enable verbose logging
    --validate              Validate system readiness without installing
    --list-profiles         List all available installation profiles
    --show-profile PROFILE  Show detailed information about a profile
    --setup-vault [ENC_DIR] [MOUNT_POINT]  Setup encrypted vault (defaults: ~/.securevaultenc ~/securevault)
    -h, --help              Show this help message

PROFILES:
    minimal      - Basic development tools (git, python, node, rust)
    ml-dev       - ML/AI development with ROCm and Python tooling
    security-dev - Security-focused with Kubernetes and monitoring

EXAMPLES:
    $0 --profile minimal --dry-run
    $0 --profile ml-dev --verbose
    $0 --profile security-dev
    $0 --validate
    $0 --setup-vault ~/.myvault ~/.vault

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                if [[ $# -lt 2 ]]; then
                    log_error "Profile name required"
                    show_usage
                    exit 1
                fi
                PROFILE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                LOG_LEVEL="DEBUG"
                shift
                ;;
            --validate)
                VALIDATE_ONLY=true
                shift
                ;;
            --list-profiles)
                LIST_PROFILES_ONLY=true
                shift
                ;;
            --show-profile)
                if [[ $# -lt 2 ]]; then
                    log_error "--show-profile requires a profile name"
                    show_usage
                    exit 1
                fi
                SHOW_PROFILE="$2"
                shift 2
                ;;
            --setup-vault)
                SETUP_VAULT=true
                VAULT_ARGS=()
                # Parse vault arguments: --setup-vault [enc_dir] [mount_point]
                if [[ $# -gt 1 && "$2" != -* ]]; then
                    VAULT_ARGS+=("$2")
                    shift
                    if [[ $# -gt 1 && "$2" != -* ]]; then
                        VAULT_ARGS+=("$2")
                        shift
                    fi
                fi
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Validate profile
validate_profile() {
    local profile_file="$PROFILE_CONFIG/$PROFILE.yaml"
    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile '$PROFILE' not found at $profile_file"
        log_error "Available profiles:"
        for profile in "$PROFILE_CONFIG"/*.yaml; do
            [[ -f "$profile" ]] && basename "$profile" .yaml
        done
        exit 1
    fi
}

# Load libraries
load_libraries() {
    # Source logger first
    if [[ -f "$LIB_DIR/logger.sh" ]]; then
        source "$LIB_DIR/logger.sh"
    else
        log_error "Logger library not found: $LIB_DIR/logger.sh"
        exit 1
    fi

    # Source installer functions
    if [[ -f "$LIB_DIR/installer.sh" ]]; then
        source "$LIB_DIR/installer.sh"
    else
        log_error "Installer library not found: $LIB_DIR/installer.sh"
        exit 1
    fi

    # Source validator
    if [[ -f "$LIB_DIR/validator.sh" ]]; then
        source "$LIB_DIR/validator.sh"
    else
        log_error "Validator library not found: $LIB_DIR/validator.sh"
        exit 1
    fi
}

# Get modules to install from profile
get_modules_to_install() {
    local profile_file="$PROFILE_CONFIG/$PROFILE.yaml"
    local modules=()

    # Check includes - get each array element
    local module_count
    module_count=$(yaml_get "$profile_file" "includes | length")
    if [[ "$module_count" != "null" && "$module_count" -gt 0 ]]; then
        for ((i=0; i<module_count; i++)); do
            local module
            module=$(yaml_get "$profile_file" "includes[$i]")
            modules+=("$module")
        done
    fi

    echo "${modules[@]}"
}

# Install module
install_module() {
    local module_spec="$1"
    # Extract module name (before dot) and category (after dot)
    local module="${module_spec%%.*}"
    local category="${module_spec#*.}"

    local module_script="$MODULES_DIR/$module/install.sh"

    if [[ ! -f "$module_script" ]]; then
        log_error "Module script not found: $module_script"
        return 1
    fi

    log_section "Installing $module module ($category)"

    # Source the module script
    source "$module_script"

    # Call the install function with category parameter
    local install_func="install_$module"
    if type "$install_func" &>/dev/null; then
        "$install_func" "$category" || {
            log_error "Failed to install $module module ($category)"
            return 1
        }
    else
        log_error "Install function $install_func not found in $module_script"
        return 1
    fi
}

# Run post-installation validation
run_validation() {
    log_section "Post-Installation Validation"

    run_validation "$PROFILE"
}

# Show completion message
show_completion() {
    log_success "Installation completed successfully!"
    echo
    echo "Profile: $PROFILE"
    echo "Log file: $LOGS_DIR/installer.log"
    echo
    echo "Next steps:"
    echo "  1. Log out and back in for group changes to take effect"
    echo "  2. Review the log file for any warnings or errors"
    echo "  3. Run validation: $0 --profile $PROFILE --validate"
    echo
    echo "For maintenance, see: maintenance/weekly-check.sh"
}

# Main installation function
main() {
    parse_args "$@"

    # Handle special modes that need libraries
    if [[ "$LIST_PROFILES_ONLY" == "true" || -n "$SHOW_PROFILE" || "$SETUP_VAULT" == "true" ]]; then
        load_libraries
        if [[ "$LIST_PROFILES_ONLY" == "true" ]]; then
            list_profiles
            exit 0
        elif [[ -n "$SHOW_PROFILE" ]]; then
            show_profile "$SHOW_PROFILE"
            exit 0
        elif [[ "$SETUP_VAULT" == "true" ]]; then
            # Source the security module to get setup_encrypted_vault function
            source "$MODULES_DIR/security/install.sh"
            setup_encrypted_vault "${VAULT_ARGS[@]}"
            exit $?
        fi
    fi

    # Handle validation-only mode early
    if [[ "$VALIDATE_ONLY" == "true" ]]; then
        validate_profile
        load_libraries
        run_validation
        exit $?
    fi

    validate_profile

    # Load libraries
    load_libraries

    log_info "🚀 Starting modular installer"
    log_info "Profile: $PROFILE"
    [[ "$DRY_RUN" == "true" ]] && log_info "Mode: DRY RUN"
    [[ "$FORCE" == "true" ]] && log_info "Mode: FORCE"
    echo

    # Initialize installer
    init_installer || exit 1

    # Get modules to install
    local modules
    IFS=' ' read -r -a modules <<< "$(get_modules_to_install)"

    if [[ ${#modules[@]} -eq 0 ]]; then
        log_warn "No modules to install for profile $PROFILE"
        exit 0
    fi

    log_info "Modules to install: ${modules[*]}"
    echo

    # Install each module
    for module in "${modules[@]}"; do
        install_module "$module" || exit 1
    done

    # Run validation
    run_validation

    # Show completion message
    show_completion
}

# Run main function
main "$@"

echo "🔨 Building the 'tinfoil' CLI binary + installing scripts..."

# Install Go if missing
sudo pacman -Sy --needed --noconfirm go 2>/dev/null || true

# Create system-wide share directory
sudo mkdir -p /usr/share/tinfoil

# Copy all necessary files so tinfoil can find them after install
sudo cp -r security-audit.sh lib modules config systemd 2>/dev/null || true
sudo cp -r . /usr/share/tinfoil/ 2>/dev/null || echo "⚠️  Some files could not be copied (normal in dev)"

# Build static Go binary
cd bin
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o /tmp/tinfoil tinfoil.go
sudo install -Dm755 /tmp/tinfoil /usr/local/bin/tinfoil
cd ..

echo "✅ tinfoil CLI installed successfully! 🎉"
echo ""
echo "Usage:"
echo "   tinfoil                  → Global investigator mode"
echo "   tinfoil .                → Audit current project"
echo "   tinfoil /path/to/project → Audit any folder"