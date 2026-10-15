#!/usr/bin/env bash
# gpu-powercap.sh — apply power caps to GPUs at boot (rocm-smi power overdrive).
# Cards are found by PCI device id, not rocm-smi index, so caps keep
# following the right card when GPU indexes change between boots.
#
# Default caps (override on the command line as "DEVICEID=WATTS" pairs):
#   MI50/MI60 (gfx906):  0x66a1 / 0x66a7  -> 210 W
#   R9700    (gfx1201):  0x7551           -> 210 W
#
# Usage:
#   gpu-powercap.sh                      # default caps above
#   gpu-powercap.sh 0x7551=250           # only R9700 at 250 W
#   gpu-powercap.sh 0x66a1=180 0x7551=210
set -uo pipefail

DEFAULTS=("0x66a1=210" "0x66a7=210" "0x7551=210")
if [ $# -gt 0 ]; then
    CAPS=("$@")
else
    CAPS=("${DEFAULTS[@]}")
fi

rc=0
for spec in "${CAPS[@]}"; do
    devid=${spec%%=*}; cap=${spec##*=}
    found=0
    for path in /sys/bus/pci/devices/*/uevent; do
        # uevent line: PCI_ID=1002:7551  (vendor:device, no 0x prefix)
        if grep -qiE "PCI_ID=1002:${devid#0x}" "$path" 2>/dev/null; then
            found=1
            bdf=$(basename "$(dirname "$path")")   # e.g. 0000:43:00.0
            short=${bdf#0000:}             # e.g. 43:00.0
            # this rocm-smi takes only integer indexes: map BDF -> GPU[n]
            # via --showbus (prints "GPU[N]: PCI Bus Id ... <bdf>").
            idx=$(rocm-smi --showbus 2>/dev/null | grep -i "$short" | grep -oE "GPU\[[0-9]+\]" | grep -oE "[0-9]+" | head -1)
            if [ -z "$idx" ]; then
                echo "  $short not found in rocm-smi --showbus" >&2
                rc=1; continue
            fi
            echo "capping $devid ($short = GPU$idx) to ${cap}W"
            if ! rocm-smi -d "$idx" --setpoweroverdrive "$cap"; then
                echo "  setpoweroverdrive failed for $short" >&2
                rc=1
            fi
        fi
    done
    [ $found -eq 0 ] && echo "no PCI device $devid present" >&2
done
exit $rc
