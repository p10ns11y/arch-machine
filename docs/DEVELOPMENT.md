# Development Guide

## Adding New Tools

### 1. Tool Definition
Add tool configuration to `config/tools.yaml`:

```yaml
tools:
  category:
    new_tool:
      description: "Tool description"
      package: "arch-package-name"           # For pacman packages
      install_command: "custom command"      # For custom installation
      source: "download-url"                 # For binary downloads
      install_path: "/usr/local/bin"         # Installation directory
```

### 2. Installation Module
Create or update installation module in `modules/`:

```bash
# modules/category/install.sh
install_new_tool() {
    # Installation logic
    install_package "$package" "description" || return 1
}
```

### 3. Profile Integration
Add to profile configurations in `config/profiles/`:

```yaml
customizations:
  category:
    new_tool: true
```

### 4. Testing
```bash
# Dry run
./install.sh --profile <profile> --dry-run

# Validate
./install.sh --validate

# Check logs
tail logs/installer.log
```

## Code Structure

### Directory Layout
```
arch-machine/
├── config/                 # Configuration files
│   ├── tools.yaml         # Tool definitions
│   └── profiles/          # Installation profiles
├── modules/               # Installation modules
│   ├── system/           # System packages/services
│   ├── development/      # Development tools
│   ├── ml_ai/           # ML/AI tools
│   └── security/         # Security tools
├── maintenance/          # Maintenance scripts
├── lib/                  # Shared libraries
│   ├── logger.sh         # Logging functions
│   ├── installer.sh      # Installation utilities
│   └── evidence.sh       # Evidence extraction
└── systemd/              # Systemd units
```

### Key Libraries

#### `lib/logger.sh`
Logging utilities for consistent output formatting.

#### `lib/installer.sh`
Core installation functions:
- `install_package()`: Install Arch packages
- `yaml_get()`: Parse YAML configurations
- `check_yaml_parser()`: YAML parser detection

#### `lib/evidence.sh`
Evidence extraction for AI optimization:
- `extract_security_evidence()`: Parse security reports
- `extract_installer_evidence()`: Extract log errors/warnings
- `create_evidence_bundle()`: Generate evidence bundles

## Development Workflow

### 1. Local Testing
```bash
# Create feature branch
git checkout -b feature/new-tool

# Test changes
./install.sh --profile minimal --dry-run
./maintenance/extract-evidence.sh --dry-run

# Run specific tests
bash -c "source lib/evidence.sh; extract_installer_evidence logs/installer.log 5"
```

### 2. Validation
```bash
# Full system validation
./install.sh --validate

# Maintenance testing
maintenance/weekly-check.sh --dry-run

# Evidence extraction testing
./maintenance/extract-evidence.sh
```

### 3. Documentation
```bash
# Update relevant docs
vim INSTALLATION.md    # For new tools/profiles
vim MAINTENANCE.md     # For new maintenance features
vim TROUBLESHOOTING.md # For common issues
```

## Testing Strategy

### Unit Testing
```bash
# Test individual functions
source lib/evidence.sh
extract_security_evidence "test-file.txt"

# Test YAML parsing
source lib/installer.sh
yaml_get "config/tools.yaml" "tools.security.tetragon.namespace"
```

### Integration Testing
```bash
# Full profile installation
./install.sh --profile test-profile

# Maintenance workflow
maintenance/security-audit.sh
./maintenance/extract-evidence.sh

# Cleanup
maintenance/backup.sh restore <pre-test-backup>
```

### Performance Testing
```bash
# Measure evidence extraction performance
time ./maintenance/extract-evidence.sh

# Check bundle sizes
ls -lh logs/evidence-bundle-*.json
ls -lh logs/evidence-bundle-*.toon
```

## Adapting for Other Distributions

### Package Manager Abstraction
The project currently uses pacman directly. To support multiple distributions:

```bash
# Create package manager abstraction
# lib/installer.sh
get_package_manager() {
    if command -v apt &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

install_package() {
    local package="$1"
    local pm
    pm=$(get_package_manager)

    case "$pm" in
        apt) sudo apt update && sudo apt install -y "$package" ;;
        dnf) sudo dnf install -y "$package" ;;
        pacman) sudo pacman -S --noconfirm "$package" ;;
        *) echo "Unsupported package manager: $pm"; return 1 ;;
    esac
}
```

### Distribution-Specific Modules
Create distribution-specific modules:

```
modules/
├── system/
│   ├── arch.sh      # Arch Linux specific
│   ├── debian.sh    # Debian/Ubuntu specific
│   └── fedora.sh    # Fedora/RHEL specific
```

### Service Management Compatibility
Most modern Linux distributions use systemd, but verify:

```bash
# Check init system
if [[ -d /run/systemd/system ]]; then
    echo "systemd detected"
else
    echo "non-systemd system - may require adaptations"
fi
```

### Testing on Other Distributions
```bash
# Create distro-specific test script
# test/distro-test.sh
run_distro_tests() {
    local distro="$1"

    echo "Testing on $distro..."
    ./install.sh --validate
    ./install.sh --profile minimal --dry-run

    # Check for distro-specific issues
    case "$distro" in
        ubuntu|debian)
            check_apt_packages
            ;;
        fedora|rhel)
            check_dnf_packages
            ;;
    esac
}
```

## Contributing Guidelines

### Code Style
- Use Bash strict mode: `set -euo pipefail`
- Consistent error handling with `|| return 1`
- Clear function names and documentation
- Follow existing patterns in the codebase

### Commit Messages
```
feat: add new tool support
fix: resolve YAML parsing issue
docs: update installation guide
refactor: improve evidence extraction
```

### Pull Request Process
1. Create feature branch from `main`
2. Implement changes with tests
3. Update documentation
4. Create backup before testing
5. Submit PR with detailed description
6. Address review feedback

### Release Process
1. Update version in profile configs
2. Test all profiles: `minimal`, `ml-dev`, `security-dev`
3. Run full maintenance cycle
4. Update changelog
5. Tag release: `git tag v1.x.x`