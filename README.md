# VMware Workstation - Linux Kernel 6.16.x Compatibility Fixes

![VMware](https://img.shields.io/badge/VMware-17.6.4_|_25.0.0+-blue)
![Kernel](https://img.shields.io/badge/Linux_Kernel-6.16.x-green)
![Status](https://img.shields.io/badge/Status-✅_WORKING-success)
![Compiler](https://img.shields.io/badge/Compiler-GCC_|_Clang-orange)

This repository contains **fully patched and working** VMware host modules with all necessary fixes applied to make **VMware Workstation 17.6.4 and 25.0.0+** compatible with Linux kernel 6.16.x and potentially newer kernels.

## 🆕 What's New

### **VMware 25.0.0 Support**
- ✅ Full support for VMware Workstation 25.0.0 (latest version)
- ✅ **Built-in compiler auto-detection** in Makefiles (no script needed!)
- ✅ Automatic Clang/LLD detection for Clang-built kernels
- ✅ Universal script that detects your VMware version automatically

### **Enhanced Auto-Detection**
- 🔍 Script automatically detects VMware version (17.6.4 or 25.0.0+)
- 🔍 VMware 25.0.0 Makefiles auto-detect kernel compiler (Clang/GCC)
- 🔍 Automatic selection of appropriate build strategy

### **Fixed Issues:**

1. **Build System Changes**: `EXTRA_CFLAGS` deprecated → **Fixed with `ccflags-y`**
2. **Kernel API Changes**:
   - `del_timer_sync()` → **Fixed with `timer_delete_sync()`**
   - `rdmsrl_safe()` → **Fixed with `rdmsrq_safe()`**
3. **Module Init Deprecation**: `init_module()` deprecated → **Fixed with `module_init()` macro**
4. **Header File Issues**: Missing includes → **Fixed with proper include paths**
5. **Compiler Compatibility**: **Auto-detects kernel compiler (GCC/Clang)** and applies appropriate compilation strategy
6. **Function Prototypes**: Fixed deprecated function declarations for strict C compliance
7. **Linker Compatibility**: **NEW!** Automatic LLD linker detection for Clang-built kernels with LTO

## Supported VMware Versions

| VMware Version | Kernel 6.16.x | Auto-Detection | Status |
|----------------|---------------|----------------|---------|
| **17.6.4** | ✅ Yes | Script-based | ✅ **Fully Supported** |
| **25.0.0+** | ✅ Yes | Makefile + Script | ✅ **Fully Supported** |

## Installation

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install build-essential linux-headers-$(uname -r) git

# Fedora/RHEL
sudo dnf install kernel-devel kernel-headers gcc make git

# Arch Linux
sudo pacman -S linux-headers base-devel git

# For Clang-built kernels (CachyOS, custom kernels), also install:
sudo pacman -S clang lld     # Arch Linux
sudo apt install clang lld   # Ubuntu/Debian
sudo dnf install clang lld   # Fedora/RHEL
```

### Step 1: Clone This Pre-Patched Repository

```bash
# Clone this repository with all kernel 6.16.x fixes already applied
git clone https://github.com/ngodn/vmware-vmmon-vmnet-linux-6.16.x.git
cd vmware-vmmon-vmnet-linux-6.16.x
```

### Step 2: Install Patched Modules (Automated)

**Recommended: Use the automated script**

```bash
# Run the installation script
# - Automatically detects your VMware version (17.6.4 or 25.0.0+)
# - Auto-detects kernel compiler (GCC/Clang)
# - Applies appropriate patches and builds modules
./repack_and_patch.sh
```

The script will:
1. ✅ Detect your installed VMware version
2. ✅ Detect your kernel compiler (GCC or Clang)
3. ✅ Select the correct module source directory
4. ✅ Build modules with appropriate compiler/linker
5. ✅ Install and load the modules
6. ✅ Restart VMware services

**For VMware 25.0.0:** The Makefiles include built-in auto-detection, so they automatically use the correct compiler/linker without requiring manual intervention!

### Step 3: Manual Installation (Advanced)

**For VMware 17.6.4:**
```bash
cd modules/17.6.4/source

# Create module tarballs
tar -cf vmmon.tar vmmon-only
tar -cf vmnet.tar vmnet-only

# Install to VMware directory
sudo cp -v vmmon.tar vmnet.tar /usr/lib/vmware/modules/source/

# Build and install
sudo vmware-modconfig --console --install-all
```

**For VMware 25.0.0 (with Clang kernel):**
```bash
cd modules/25.0.0/source

# Build vmmon (Makefile auto-detects Clang/LLD)
cd vmmon-only && make -j$(nproc)

# Build vmnet (Makefile auto-detects Clang/LLD)
cd ../vmnet-only && make -j$(nproc)

# Install modules
sudo mkdir -p /lib/modules/$(uname -r)/misc/
sudo cp ../vmmon-only/vmmon.ko /lib/modules/$(uname -r)/misc/
sudo cp vmnet.ko /lib/modules/$(uname -r)/misc/
sudo depmod -a

# Load modules
sudo modprobe vmmon && sudo modprobe vmnet
```

### Step 4: Verify Installation

If successful, you should see:
```
Starting VMware services:
   Virtual machine monitor                                             done
   Virtual machine communication interface                             done
   VM communication interface socket family                            done
   Virtual ethernet                                                    done
   VMware Authentication Daemon                                        done
   Shared Memory Available                                             done
```

Check loaded modules:
```bash
lsmod | grep -E "(vmmon|vmnet)"
```

## Technical Details

### **All Kernel 6.16.x Fixes Applied**

| Issue | Old Code | New Code | Status |
|-------|----------|----------|---------|
| **Build System** | `EXTRA_CFLAGS` | `ccflags-y` | ✅ **Fixed** |
| **Timer API** | `del_timer_sync()` | `timer_delete_sync()` | ✅ **Fixed** |
| **MSR API** | `rdmsrl_safe()` | `rdmsrq_safe()` | ✅ **Fixed** |
| **Module Init** | `init_module()` function | `module_init()` macro | ✅ **Fixed** |
| **Compiler Detection** | Manual selection | Auto-detect GCC/Clang | ✅ **Fixed** |
| **Linker Detection** | Manual selection | Auto-detect LD/LLD | ✅ **NEW!** |
| **Function Prototypes** | `function()` | `function(void)` | ✅ **Fixed** |

### VMware 25.0.0 Auto-Detection Features

The VMware 25.0.0 Makefiles include **built-in compiler/linker detection**:

```makefile
# Auto-detects kernel compiler from /proc/version
ifeq ($(origin CC),default)
  KERNEL_CC := $(shell cat /proc/version | grep -o -E '(gcc|clang)')
  ifeq ($(KERNEL_CC),clang)
    override CC := clang    # Automatically use Clang
    override LD := ld.lld   # Automatically use LLVM linker
  endif
endif
```

This means:
- ✅ No manual `CC=clang LD=ld.lld` needed
- ✅ Makefile detects kernel compiler automatically
- ✅ Works seamlessly on both GCC and Clang kernels
- ✅ Handles LTO-enabled Clang kernels correctly

### Files Modified and Fixed

**VMware 17.6.4:**
- ✅ `vmmon-only/Makefile.kernel` - Build system compatibility
- ✅ `vmnet-only/Makefile.kernel` - Build system compatibility
- ✅ `vmmon-only/Makefile` - Build system compatibility
- ✅ `vmnet-only/Makefile` - Build system compatibility
- ✅ `vmmon-only/linux/driver.c` - Timer API usage
- ✅ `vmmon-only/linux/hostif.c` - Timer and MSR API usage
- ✅ `vmnet-only/driver.c` - Module initialization + function prototypes
- ✅ `vmnet-only/smac_compat.c` - Function prototype fixes

**VMware 25.0.0:**
- ✅ `vmmon-only/Makefile` - **NEW!** Auto-detection for Clang/LLD
- ✅ `vmnet-only/Makefile` - **NEW!** Auto-detection for Clang/LLD
- ✅ No source code changes needed (VMware already compatible!)

**Universal Script:**
- ✅ `repack_and_patch.sh` - **ENHANCED!** Universal multi-version support

### Compilation Test Results

**VMware 25.0.0 with Clang auto-detection:**
```bash
Auto-detected Clang kernel - using CC=clang
Auto-detected LLVM linker - using LD=ld.lld
✅ CC [M]  linux/driver.o
✅ CC [M]  linux/hostif.o
✅ CC [M]  common/*.o
✅ LD [M]  vmmon.o        # Using ld.lld automatically
✅ LD [M]  vmmon.ko
```

**vmmon module (3.7 MB):**
```bash
✅ Successfully built with Clang 21.1.5
✅ Linked with ld.lld (LLVM linker)
✅ Compatible with kernel 6.16.9 LTO build
```

**vmnet module (3.5 MB):**
```bash
✅ Successfully built with Clang 21.1.5
✅ Linked with ld.lld (LLVM linker)
✅ All network functions working
```

## Kernel Compiler Compatibility

### **Universal Support for All 6.16.x Kernels**

This repository includes **automatic compiler detection** and supports:

| Kernel Type | Compiler | VMware 17.6.4 | VMware 25.0.0 | Status |
|-------------|----------|---------------|---------------|---------|
| **Ubuntu/Debian Standard** | GCC | ✅ Script | ✅ Makefile + Script | ✅ **Supported** |
| **Fedora/RHEL Standard** | GCC | ✅ Script | ✅ Makefile + Script | ✅ **Supported** |
| **Arch Linux Standard** | GCC | ✅ Script | ✅ Makefile + Script | ✅ **Supported** |
| **CachyOS LTO** | Clang | ✅ Script | ✅ Makefile + Script | ✅ **Supported** |
| **Xanmod Kernels** | Clang | ✅ Script | ✅ Makefile + Script | ✅ **Supported** |
| **Custom Clang Builds** | Clang | ✅ Script | ✅ Makefile + Script | ✅ **Supported** |

### **How Auto-Detection Works**

**For VMware 25.0.0 (Makefile-level):**
1. Makefile checks `$(origin CC)` to see if CC was explicitly set
2. If not set, parses `/proc/version` to detect kernel compiler
3. If Clang detected, automatically sets `CC=clang` and `LD=ld.lld`
4. Exports variables to kernel build system
5. Build proceeds with correct toolchain

**For VMware 17.6.4 (Script-level):**
1. Script analyzes `/proc/version` and kernel build environment
2. Detects kernel compiler (GCC or Clang)
3. For Clang: Sets `CC=clang LD=ld.lld` environment variables
4. For GCC: Uses standard vmware-modconfig approach
5. Falls back to manual compilation if needed

### **Supported Scenarios**

- ✅ **GCC-built kernels**: Standard VMware compilation
- ✅ **Clang-built kernels**: Auto-detects and uses Clang/LLD
- ✅ **LTO-enabled kernels**: Correctly uses ld.lld linker
- ✅ **Mixed environments**: Adapts to system configuration
- ✅ **Version mismatches**: Works with different Clang versions

## Troubleshooting

### Issue: Secure Boot Enabled
**Error**: `Could not open /dev/vmmon: No such file or directory`

**Solution**: Disable Secure Boot in BIOS/UEFI settings or sign the kernel modules.

### Issue: Missing Kernel Headers
**Error**: Build fails with missing header files

**Solution**:
```bash
# Reinstall kernel headers
sudo apt install --reinstall linux-headers-$(uname -r)  # Ubuntu/Debian
sudo dnf install kernel-devel kernel-headers             # Fedora/RHEL
sudo pacman -S linux-headers                             # Arch Linux
```

### Issue: Clang/LLD Not Found (Clang Kernels)
**Error**: `clang: command not found` or `ld.lld: command not found`

**Solution**: Install Clang and LLD:
```bash
# Arch Linux / CachyOS
sudo pacman -S clang lld

# Ubuntu/Debian
sudo apt install clang lld

# Fedora/RHEL
sudo dnf install clang lld
```

### Issue: Compiler Mismatch
**Error**: `error: unrecognized command-line option '-mretpoline-external-thunk'`

**Solution**: Use the script which auto-detects and fixes mismatches:
```bash
./repack_and_patch.sh
```

For VMware 25.0.0, the Makefiles handle this automatically!

### Issue: VMware Services Won't Start
**Error**: VMware services fail to start after module installation

**Solution**:
```bash
# Manually load the modules
sudo modprobe vmmon
sudo modprobe vmnet

# Restart VMware services
sudo systemctl restart vmware
# or for older systems
sudo /etc/init.d/vmware restart
```

### Issue: Build Fails with "ld: unrecognised emulation mode"
**Error**: `ld: unrecognised emulation mode: llvm`

**Root Cause**: GNU ld doesn't understand LLVM-specific flags used by Clang-built kernels

**Solution**: The script and VMware 25.0.0 Makefiles automatically use `ld.lld` for Clang kernels. If building manually:
```bash
# Ensure ld.lld is installed
which ld.lld

# For VMware 25.0.0, just run make (auto-detection handles it)
cd modules/25.0.0/source/vmmon-only && make

# For VMware 17.6.4 manual build
make CC=clang LD=ld.lld
```

## Future Kernel Compatibility

For future kernel updates, monitor these potential breaking changes:

1. **Timer subsystem**: Further timer API modifications
2. **Memory management**: Page allocation/deallocation changes
3. **Network stack**: Networking API updates (affects vmnet)
4. **Build system**: Makefile and compilation flag changes

When new kernels are released, simply run:
```bash
./repack_and_patch.sh
```
The script will automatically detect your VMware version and kernel compiler.

## Contributing

This repository contains fully working patches for kernel 6.16.x. If you encounter issues with newer kernels or have improvements:

1. Fork this repository
2. Create a feature branch: `git checkout -b fix/kernel-6.17` or `feat/vmware-26`
3. Apply your fixes and test thoroughly
4. Submit a pull request with detailed description

## References

- [mkubecek/vmware-host-modules](https://github.com/mkubecek/vmware-host-modules) - Community patches (inspiration)
- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/) - Kernel API changes
- [VMware Knowledge Base](https://kb.vmware.com/) - Official VMware documentation
- [LLVM LLD Linker](https://lld.llvm.org/) - LLVM linker documentation

## Disclaimer

These patches are community-maintained and not officially supported by VMware/Broadcom. Use at your own risk. Always backup your system before applying kernel module patches.

## License

This project follows the same license terms as the original VMware kernel modules and community patches.

---

## **Tested Configurations:**

### Configuration 1: Ubuntu 24.04 + VMware 17.6.4
- **OS**: Ubuntu 24.04.3 LTS (Noble Numbat)
- **Kernel**: 6.16.1-x64v3-t2-noble-xanmod1
- **Compiler**: GCC
- **VMware**: Workstation Pro 17.6.4 build-24832109
- **Date**: August 2025
- **Status**: ✅ **WORKING** - All modules compile and load successfully

### Configuration 2: Custom Arch + VMware 17.6.4
- **OS**: Custom Built OS (Arch Linux based)
- **Kernel**: 6.16.9-1-cachyos-lto
- **Compiler**: Clang 20.1.8 with LLD 20.1.8 linker
- **VMware**: Workstation Pro 17.6.4 build-24832109
- **Date**: October 2025
- **Status**: ✅ **WORKING** - Auto-detected Clang toolchain, modules compile and load successfully
- **Notes**: Script automatically detects Clang-built kernel and uses appropriate `CC=clang LD=ld.lld` toolchain

### Configuration 3: CachyOS + VMware 25.0.0 (NEW!)
- **OS**: Omarchy (Arch-based)
- **Kernel**: 6.16.9-1-cachyos-lto
- **Compiler**: Clang 20.1.8 (kernel built with Clang + LTO)
- **User Clang**: Clang 21.1.5 (system clang)
- **Linker**: ld.lld (LLVM linker)
- **VMware**: Workstation Pro 25.0.0 build-24995812
- **Date**: November 2025
- **Status**: ✅ **WORKING** - Makefile auto-detection successful
- **Notes**:
  - Makefiles automatically detected Clang kernel
  - Auto-selected `CC=clang` and `LD=ld.lld`
  - Built successfully with mismatched Clang versions (20.1.8 → 21.1.5)
  - vmmon.ko: 3.7 MB, vmnet.ko: 3.5 MB
  - All modules load and VMware runs perfectly
---
