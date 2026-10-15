# gpu-powercap

A systemd oneshot service that re-applies GPU power caps at every boot,
using `rocm-smi --setpoweroverdrive`.

## Why this exists

I run two AMD GPUs in one workstation (a Radeon AI PRO R9700 and an Instinct
MI50) fed by a 1000 W supply. I want both cards capped at 210 W: inference
workloads barely notice, and the heat they dump into the case drops
noticeably. The problem is that ROCm has no persistence mode — power caps
set with `rocm-smi` are lost on every reboot, and the GPU index order can
change between boots, so a naive `rocm-smi -d 1 ...` script silently caps
the wrong card (or none).

## How it works

`gpu-powercap.sh` finds each card by its **PCI device id** (scanning
`/sys/bus/pci/devices/*/uevent` for `PCI_ID=1002:<devid>`), maps the PCI
bus address to the current `rocm-smi` index via `--showbus`, and applies
the cap. A missing card is not an error: the script exits 0 so the boot
never breaks when a GPU is physically absent.

Default caps:

| Card | PCI device id | Cap |
| --- | --- | --- |
| Instinct MI50 / MI60 (gfx906) | `0x66a1` / `0x66a7` | 210 W |
| Radeon AI PRO R9700 (gfx1201) | `0x7551` | 210 W |

Override on the command line:

```sh
gpu-powercap.sh 0x7551=250 0x66a1=180
```

`gpu-powercap.service` runs it once at boot (`Type=oneshot`,
`RemainAfterExit=yes`).

## Requirements

- AMD GPU on the amdgpu driver, `rocm-smi` in PATH, `/dev/kfd` usable
- systemd

## Tailor-made disclaimer

This is written for **my exact setup**: the two cards above, their device
ids, and 210 W values chosen for my PSU and case thermals. The script
assumes `rocm-smi` accepts integer device indexes (older ROCm builds do;
newer ones also accept BDF addresses). I do not guarantee it works on other
hardware or ROCm versions, and I will not adapt it to yours. Read it, steal
the PCI-id-lookup idea, and adjust the table.
