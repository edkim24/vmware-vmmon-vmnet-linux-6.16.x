#!/bin/bash

# VMware Workstation - Repack and Install Script
# For Linux Kernel 6.16.x Compatibility (All Variants)
#
# Supports VMware Workstation 17.6.4 and 25.0.0+
# Automatically detects VMware version and applies appropriate patches
#
# This script automatically detects the kernel's build compiler and applies
# the appropriate compilation strategy for maximum compatibility
#
# Supports:
# - GCC-built kernels (standard Ubuntu, Debian, etc.)
# - Clang-built kernels (CachyOS, Xanmod, custom builds)
# - Mixed environments
#
# Usage: ./repack_and_patch.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. It will use sudo when needed."
   exit 1
fi

print_status "VMware Workstation - Linux Kernel 6.16.x Compatibility Script"
echo "Target kernel: $(uname -r)"
echo

# Detect installed VMware version
if [ ! -d "/usr/lib/vmware" ]; then
    print_error "VMware Workstation is not installed!"
    print_error "Please install VMware Workstation first."
    exit 1
fi

VMWARE_VERSION=""
if command -v vmware --version >/dev/null 2>&1; then
    VMWARE_FULL_VERSION=$(vmware --version 2>/dev/null | head -1)
    VMWARE_VERSION=$(echo "$VMWARE_FULL_VERSION" | grep -oP '\d+\.\d+\.\d+' | head -1)
    print_success "Detected VMware Workstation version: $VMWARE_VERSION"
else
    print_error "Could not detect VMware version"
    exit 1
fi

# Determine which module version to use
MODULE_VERSION=""
if [[ "$VMWARE_VERSION" == 17.6.* ]]; then
    MODULE_VERSION="17.6.4"
elif [[ "$VMWARE_VERSION" == 25.* ]]; then
    MODULE_VERSION="25.0.0"
else
    print_error "Unsupported VMware version: $VMWARE_VERSION"
    print_error "This script supports VMware 17.6.4 and 25.0.0+"
    exit 1
fi

print_success "Using module patches for VMware $MODULE_VERSION"

# Check if we're in the right directory
if [ ! -d "modules/$MODULE_VERSION/source" ]; then
    print_error "Please run this script from the repository root directory"
    print_error "Expected to find: modules/$MODULE_VERSION/source/"
    exit 1
fi

# Check if the patched modules exist
if [ ! -d "modules/$MODULE_VERSION/source/vmmon-only" ] || [ ! -d "modules/$MODULE_VERSION/source/vmnet-only" ]; then
    print_error "Patched module sources not found!"
    print_error "Expected: modules/$MODULE_VERSION/source/vmmon-only and modules/$MODULE_VERSION/source/vmnet-only"
    exit 1
fi

print_status "✅ All pre-patched modules found"
print_status "✅ VMware Workstation installation detected"

echo

# Check for kernel headers
print_status "🔍 Checking kernel build environment..."

KERNEL_BUILD_DIR="/lib/modules/$(uname -r)/build"
KERNEL_MAKEFILE="$KERNEL_BUILD_DIR/Makefile"

if [ ! -f "$KERNEL_MAKEFILE" ]; then
    print_error "Kernel build directory not found. Please install kernel headers:"
    echo "  Ubuntu/Debian: sudo apt install linux-headers-\$(uname -r)"
    echo "  Fedora/RHEL: sudo dnf install kernel-devel"
    echo "  Arch: sudo pacman -S linux-headers"
    exit 1
fi

# Detect kernel compiler (for informational purposes)
KERNEL_COMPILER=""
if grep -q "clang" /proc/version 2>/dev/null; then
    KERNEL_COMPILER="clang"
    COMPILER_VERSION=$(grep -o "clang version [0-9.]*" /proc/version | head -1)
elif grep -q "gcc" /proc/version 2>/dev/null; then
    KERNEL_COMPILER="gcc"
    COMPILER_VERSION=$(grep -o "gcc version [0-9.]*" /proc/version | head -1)
fi

if [ -n "$KERNEL_COMPILER" ]; then
    print_success "🔍 Detected kernel compiler: $KERNEL_COMPILER ($COMPILER_VERSION)"
else
    print_warning "Could not detect kernel compiler"
fi

# For VMware 25.0.0, check if Clang/LLD are available if kernel uses Clang
if [[ "$MODULE_VERSION" == "25.0.0" ]] && [[ "$KERNEL_COMPILER" == "clang" ]]; then
    print_status "Clang-built kernel detected - checking for Clang/LLD..."

    if ! command -v clang >/dev/null 2>&1; then
        print_error "Clang not found! Required for Clang-built kernels."
        print_error "Install with: sudo pacman -S clang (Arch) or sudo apt install clang (Debian/Ubuntu)"
        exit 1
    fi

    if ! command -v ld.lld >/dev/null 2>&1; then
        print_error "ld.lld not found! Required for Clang-built kernels with LTO."
        print_error "Install with: sudo pacman -S lld (Arch) or sudo apt install lld (Debian/Ubuntu)"
        exit 1
    fi

    print_success "✅ Clang and ld.lld are available"
    print_status "The Makefiles will automatically use Clang and ld.lld"
fi

# Apply C code fixes if needed (mainly for 17.6.4)
if [[ "$MODULE_VERSION" == "17.6.4" ]]; then
    print_status "📝 Applying C code compatibility fixes for 17.6.4..."

    # Fix function prototypes (compatible with both GCC and Clang)
    VMNET_DRIVER_C="modules/17.6.4/source/vmnet-only/driver.c"
    SMAC_COMPAT_C="modules/17.6.4/source/vmnet-only/smac_compat.c"

    # Check and fix VNetFreeInterfaceList() if needed
    if grep -q "^VNetFreeInterfaceList()$" "$VMNET_DRIVER_C" 2>/dev/null; then
        print_status "Fixing VNetFreeInterfaceList() prototype in driver.c..."
        sed -i '/^VNetFreeInterfaceList()$/s/VNetFreeInterfaceList()/VNetFreeInterfaceList(void)/' "$VMNET_DRIVER_C"
        sed -i 's/static void VNetFreeInterfaceList();/static void VNetFreeInterfaceList(void);/' "$VMNET_DRIVER_C"
        print_success "Fixed function prototype in driver.c"
    fi

    # Check and fix SMACL_GetUptime() if needed
    if grep -q "SMACL_GetUptime()" "$SMAC_COMPAT_C" 2>/dev/null; then
        print_status "Fixing SMACL_GetUptime() prototype in smac_compat.c..."
        sed -i 's/SMACL_GetUptime()/SMACL_GetUptime(void)/g' "$SMAC_COMPAT_C"
        print_success "Fixed function prototype in smac_compat.c"
    fi
fi

# Navigate to source directory
cd modules/$MODULE_VERSION/source

# Clean any previous builds
print_status "🧹 Cleaning previous builds..."
cd vmmon-only && make clean >/dev/null 2>&1 || true
cd ../vmnet-only && make clean >/dev/null 2>&1 || true
cd ..

# Compile modules
print_status "🔨 Compiling VMware kernel modules..."
echo

COMPILE_SUCCESS=true

if [[ "$MODULE_VERSION" == "25.0.0" ]]; then
    # For VMware 25.0.0, the Makefiles handle auto-detection
    print_status "Using VMware 25.0.0 with auto-detection Makefiles..."
    print_status "The Makefiles will automatically detect and use the correct compiler/linker"
    echo

    # Compile vmmon
    print_status "Compiling vmmon..."
    cd vmmon-only
    if make -j$(nproc) 2>&1 | tee /tmp/vmmon-build.log | grep -E "(Auto-detected|error|Error|failed)"; then
        if [ -f "vmmon.ko" ]; then
            print_success "✅ vmmon compiled successfully"
        else
            print_error "vmmon compilation failed"
            COMPILE_SUCCESS=false
        fi
    else
        if [ -f "vmmon.ko" ]; then
            print_success "✅ vmmon compiled successfully"
        else
            print_error "vmmon compilation failed"
            COMPILE_SUCCESS=false
        fi
    fi

    # Compile vmnet
    cd ../vmnet-only
    if [ "$COMPILE_SUCCESS" = true ]; then
        print_status "Compiling vmnet..."
        if make -j$(nproc) 2>&1 | tee /tmp/vmnet-build.log | grep -E "(Auto-detected|error|Error|failed)"; then
            if [ -f "vmnet.ko" ]; then
                print_success "✅ vmnet compiled successfully"
            else
                print_error "vmnet compilation failed"
                COMPILE_SUCCESS=false
            fi
        else
            if [ -f "vmnet.ko" ]; then
                print_success "✅ vmnet compiled successfully"
            else
                print_error "vmnet compilation failed"
                COMPILE_SUCCESS=false
            fi
        fi
    fi

    cd ..

elif [[ "$MODULE_VERSION" == "17.6.4" ]]; then
    # For VMware 17.6.4, use the legacy approach with manual compiler detection
    print_status "Using VMware 17.6.4 with legacy build system..."

    # Determine if we should use Clang
    USE_CLANG=false
    if [ "$KERNEL_COMPILER" = "clang" ]; then
        if command -v clang >/dev/null 2>&1; then
            USE_CLANG=true
            print_status "Will use Clang for compilation"
        fi
    fi

    if [ "$USE_CLANG" = true ]; then
        # Compile with Clang
        export CC="clang"
        if command -v ld.lld >/dev/null 2>&1; then
            export LD="ld.lld"
            print_status "Using Clang with ld.lld"
        else
            print_status "Using Clang with default linker"
        fi

        # Compile vmmon
        print_status "Compiling vmmon with Clang..."
        cd vmmon-only
        if make CC="$CC" ${LD:+LD="$LD"} -j$(nproc) >/dev/null 2>&1; then
            print_success "vmmon compiled successfully"
        else
            print_error "vmmon compilation failed"
            COMPILE_SUCCESS=false
        fi

        # Compile vmnet
        cd ../vmnet-only
        if [ "$COMPILE_SUCCESS" = true ]; then
            print_status "Compiling vmnet with Clang..."
            if make CC="$CC" ${LD:+LD="$LD"} -j$(nproc) >/dev/null 2>&1; then
                print_success "vmnet compiled successfully"
            else
                print_error "vmnet compilation failed"
                COMPILE_SUCCESS=false
            fi
        fi
        cd ..
    else
        # Use GCC/vmware-modconfig
        print_status "Using GCC compilation strategy..."

        # Create tarballs
        tar -cf vmmon.tar vmmon-only
        tar -cf vmnet.tar vmnet-only

        # Backup original modules
        BACKUP_DIR="/usr/lib/vmware/modules/source/backup-$(date +%Y%m%d-%H%M%S)"
        if [ -f "/usr/lib/vmware/modules/source/vmmon.tar" ] || [ -f "/usr/lib/vmware/modules/source/vmnet.tar" ]; then
            print_status "Backing up original modules to $BACKUP_DIR"
            sudo mkdir -p "$BACKUP_DIR"
            sudo cp /usr/lib/vmware/modules/source/vmmon.tar "$BACKUP_DIR/" 2>/dev/null || true
            sudo cp /usr/lib/vmware/modules/source/vmnet.tar "$BACKUP_DIR/" 2>/dev/null || true
        fi

        # Install tarballs
        sudo cp vmmon.tar vmnet.tar /usr/lib/vmware/modules/source/

        # Try VMware's modconfig
        print_status "Running VMware modconfig..."
        if sudo vmware-modconfig --console --install-all >/dev/null 2>&1; then
            print_success "VMware modconfig completed successfully"
            COMPILE_SUCCESS=true
        else
            print_warning "VMware modconfig failed, trying manual compilation..."

            # Manual GCC compilation fallback
            cd vmmon-only
            if make CC=gcc -j$(nproc) >/dev/null 2>&1; then
                print_success "vmmon compiled successfully with GCC"
                cd ../vmnet-only
                if make CC=gcc -j$(nproc) >/dev/null 2>&1; then
                    print_success "vmnet compiled successfully with GCC"
                    COMPILE_SUCCESS=true
                else
                    COMPILE_SUCCESS=false
                fi
            else
                COMPILE_SUCCESS=false
            fi
            cd ..
        fi
    fi
fi

# Check compilation results
if [ "$COMPILE_SUCCESS" = false ]; then
    print_error "Module compilation failed!"
    echo
    echo "Troubleshooting steps:"
    echo "1. Ensure kernel headers are installed: sudo apt/dnf/pacman install linux-headers-\$(uname -r)"
    echo "2. Check if Secure Boot is disabled"
    echo "3. For Clang kernels, ensure Clang and LLD are installed"
    echo "4. Check build logs: /tmp/vmmon-build.log and /tmp/vmnet-build.log"
    exit 1
fi

# Install modules
print_status "📦 Installing compiled modules..."

if [[ "$MODULE_VERSION" == "25.0.0" ]] || [[ "$USE_CLANG" = true ]]; then
    # Manual installation for Clang builds and VMware 25.0.0
    sudo mkdir -p /lib/modules/$(uname -r)/misc/
    sudo cp vmmon-only/vmmon.ko /lib/modules/$(uname -r)/misc/
    sudo cp vmnet-only/vmnet.ko /lib/modules/$(uname -r)/misc/
    sudo depmod -a
    print_success "Modules installed to /lib/modules/$(uname -r)/misc/"
fi

# Test module loading
print_status "🧪 Testing module loading..."

# Unload any existing modules
sudo rmmod vmnet vmmon 2>/dev/null || true

# Load modules
if sudo modprobe vmmon && sudo modprobe vmnet; then
    print_success "✅ Modules loaded successfully!"

    # Verify modules are running
    if lsmod | grep -q vmmon && lsmod | grep -q vmnet; then
        print_success "✅ All VMware modules are running!"

        # Restart VMware services
        print_status "🚀 Starting VMware services..."
        if sudo systemctl restart vmware 2>/dev/null || sudo /etc/init.d/vmware restart 2>/dev/null; then
            print_success "✅ VMware services started successfully!"
        else
            print_warning "Could not restart VMware services automatically"
            echo "Try: sudo systemctl restart vmware"
        fi

        echo
        echo "🎉 Installation Complete!"
        echo "✅ VMware Workstation version: $VMWARE_VERSION"
        echo "✅ Module version: $MODULE_VERSION"
        echo "✅ Kernel compiler: $KERNEL_COMPILER"
        if [[ "$MODULE_VERSION" == "25.0.0" ]]; then
            echo "✅ Auto-detection: Makefiles automatically detected compiler/linker"
        fi
        echo "✅ Applied all kernel 6.16.x+ compatibility fixes"
        echo "✅ Modules compiled and loaded successfully"
        echo "✅ VMware services restarted"
        echo
        echo "You can now launch VMware Workstation."

    else
        print_warning "Modules compiled but not properly loaded"
        echo "Try: sudo modprobe vmmon && sudo modprobe vmnet"
    fi
else
    print_error "Failed to load modules"
    echo
    echo "Troubleshooting steps:"
    echo "1. Check dmesg for kernel module errors: dmesg | tail -20"
    echo "2. Ensure Secure Boot is disabled"
    echo "3. Check module dependencies: modinfo /lib/modules/\$(uname -r)/misc/vmmon.ko"
    exit 1
fi

# Return to original directory
cd ../../..

print_success "Script completed successfully!"
echo
echo "This script automatically detected your VMware version ($VMWARE_VERSION)"
echo "and applied the appropriate fixes for kernel 6.16.x compatibility."
