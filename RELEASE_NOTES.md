First Rift Play build for the Retroid Pocket 6 on ArmadaOS. Experimental, still being tested on hardware.

- Hardware video decoding via V4L2 mem2mem (Qualcomm video engine), picked automatically when available
- Multithreaded low-latency software decoding as fallback
- Compiler tuning for Snapdragon 8 Gen 2
- Installs alongside chiaki-ng from Flathub (`io.github.riftplay.RiftPlay`)

Install: `flatpak install --user RiftPlay-aarch64.flatpak` — full instructions in the README.
Based on chiaki-ng v1.10.1.
