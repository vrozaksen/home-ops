# Talos SecureBoot Schematic

**Schematic ID:** `56d936e2c7919954cf5e13b2b9c06859ac5475ded8b9878bc63dc0e4bebbf854`

**Talos Version:** v1.12.1

**Bootloader:** sd-boot

## Extensions

- siderolabs/fuse3
- siderolabs/i915
- siderolabs/intel-ice-firmware
- siderolabs/intel-ucode
- siderolabs/mei
- siderolabs/nvme-cli
- siderolabs/realtek-firmware

## Download Links

### ISO (initial boot)
```
https://factory.talos.dev/image/56d936e2c7919954cf5e13b2b9c06859ac5475ded8b9878bc63dc0e4bebbf854/v1.12.1/metal-amd64-secureboot.iso
```

### Disk Image
```
https://factory.talos.dev/image/56d936e2c7919954cf5e13b2b9c06859ac5475ded8b9878bc63dc0e4bebbf854/v1.12.1/metal-amd64-secureboot.raw.zst
```

### PXE (iPXE script)
```
https://pxe.factory.talos.dev/pxe/56d936e2c7919954cf5e13b2b9c06859ac5475ded8b9878bc63dc0e4bebbf854/v1.12.1/metal-amd64-secureboot
```

## Installer Image (for talconfig.yaml)

```yaml
talosImageURL: factory.talos.dev/installer-secureboot/56d936e2c7919954cf5e13b2b9c06859ac5475ded8b9878bc63dc0e4bebbf854
```

## Usage

### BIOS Setup
1. Boot Mode: **UEFI** (not Legacy/CSM)
2. Secure Boot: **Enabled**
3. Secure Boot Mode: **Setup Mode** (for initial key enrollment)

### First Boot
1. Boot from ISO
2. Talos automatically enrolls Sidero Labs signing keys
3. System reboots into SecureBoot mode

### Verify SecureBoot
```bash
talosctl -n <node-ip> get securitystate --insecure
# Should show: secureBoot: true
```

## Target Nodes

| Node | IP | Role |
|------|-----|------|
| saga | 10.10.0.15 | Control-Plane |
| eir | 10.10.0.16 | Control-Plane |
| skuld | 10.10.0.17 | Control-Plane |
