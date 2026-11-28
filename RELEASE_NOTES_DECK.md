## Rift Play for Steam Deck (beta)

PlayStation Remote Play for the Steam Deck and x86_64 Linux PCs, based on Rift Play v0.3.0.

- Hardware video decoding on the Deck's AMD GPU (Vulkan Video, VA-API fallback)
- Low-latency decoding and multithreaded software fallback
- Console-style home screen, picture presets (Battery / Balanced / Sharp / Max / TV), Wi-Fi Saver
- Built for `x86-64-v3` and tuned for the Deck's Zen 2 CPU (needs an x86 CPU with AVX2, roughly 2015 or newer)

**Install:** in Desktop Mode, download `RiftPlay-x86_64.flatpak`, open a terminal in the download folder and run
`flatpak install --user -y RiftPlay-x86_64.flatpak`, then add `flatpak run io.github.riftplay.RiftPlay` to Steam as a non-Steam game.

**Update:** install the new bundle from each Deck release the same way. Your consoles and settings are kept.

Problems? Attach the newest log from `~/.var/app/io.github.riftplay.RiftPlay/data/log` to an issue.
