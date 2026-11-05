# Wireless CarPlay/AA package (`wireless.carplay.aa`)

NEMESIS package source. It installs four parts in order, with one reboot at the end:

| Part | Folder | What it changes |
|---|---|---|
| Wireless projection | `comp/1_projection` | Wireless feature flags, region folder from `ro.mobis.targetdir` (hotspot only) |
| Turn-by-turn | `comp/2_tbt` | Projection apps (NEMESIS community package). Refuses unless the firmware has every cluster call it uses. |
| CarPlay bridge | `comp/3_bridge` | Projection apps + `libCarPlayCore` via lpatch (`carplay-core-wifi`) |
| CarPlay audio | `comp/4_audio` | `libCarPlayAudio` / `libCarPlayUtils` via lpatch, plus `libev6aac.so` where needed |

Nothing modified is shipped. The head unit patches its own files:

- **Native libraries:** `lpatch` patches them in place from the hash-only recipes in `/recipes`.
- **Projection apps** (`HKMC_DiPO`, `HKMC_GPM`, `HKMC_Navi_ExSL`, `Iap2ServerApp`) and `libautoreceiver_infobank.so`: `scripts/build.sh` rebuilds them from the unit's stock files with the patch sets in `/patches`, before any part installs. For each app, `lpatch delta` rebuilds the modified code from the stock `.odex` (only if that `.odex` is the exact expected original), and `lpatch zipadd` adds it to the stock APK. Each result must match the md5 in `patches/<car>/manifest`. If the unit's stock files are not the expected ones, nothing is written and the unknown-unit report runs.

ADB over network: the stock switch (`persist.service.adb.tcp.enable=1`, which NEMESIS's TCP ADB sets) also gives the internal `eth0` link `192.168.0.123` at boot, in the hotspot's `192.168.0.x` range. Replies to the phone then leave through `eth0`, the phone never gets an address, and sooner or later (often after about a minute) iOS gives up on the network and wireless CarPlay drops. The package runs a small NEMESIS service, `eth0-guard` (`bin/eth0-guard.sh`), that removes `eth0`'s address through netd whenever it is in `wlan0`'s range; ADB over network keeps working over Wi-Fi (adbd listens on every interface). Earlier builds switched ADB over network to `persist.adb.tcp.port=5555` instead, which turns it off on these units (US Ioniq 5); installing this build puts the stock setting back.

## Building the zip

```
tools/build-package.sh
```

Everything comes from this repository. To add a car or change an app, see `patches/README.md`.
