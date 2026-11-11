# HMG-API mods

Our tweaks as mods for [HMG-API](https://github.com/Open-HMG/HMG-API) (the successor of
HMG Leafia Plus), on top of its Wireless CarPlay + Android Auto mod.

## carplay-tweaks

| Version | What |
|---|---|
| 0.1.0 | Wi-Fi client: turns on the car's Wi-Fi tab (`"wifi": {"client": true}`) and installs the Wi-Fi screen fix from `src/wifisettings` (the same `.lpd` as Leafia's part `6_wifi`, so the same app bytes, md5 `ae427e14...`, that were tested on a US Ioniq 5): opening Wi-Fi keeps the CarPlay/AA hotspot, no "Error" when switching, the phone reconnects over Bluetooth when the client goes off, and the tab is labelled "Wi-Fi". |

US Ioniq 5 (NEEV.USA, 260507) only: the delta fits the stock `HKMC_WifiSettings.odex`
`164039dd...` and HMG-API refuses anything else.

Planned: CarPlay auto-open on connect (`dipo.carplay.session_started`) and the frozen-picture
restart (`dipo.carplay.screen_timeout`) as Java hooks.

### Build

From an HMG-API checkout (1.1.0-beta.1 or later):

```
tools/mkmodpkg.sh <this repo>/hmgapi/carplay-tweaks <author key>
```

The package goes to `out/packages/carplay-tweaks-<version>.zip`. Keep the author key out of
the repo: only packages signed with the same key update the mod.

### Install

Copy the zip to a USB stick under `HMGAPI/updates/` and install it from the HMG-API app,
then restart the head unit. Removing the mod in the app puts the stock Wi-Fi app back.

### Tested

Off-car with HMG-API's engine (`hmgapi.engine.Engine apply`, then `remove` + `apply`) on a
fake unit with the US Ioniq 5's stock Wi-Fi app: the app comes out as `ae427e14...`, the
`android.hardware.wifi` feature and `persist.wifi.state=3` are set, and removal restores the
stock apk and odex byte for byte. Not yet on a car through HMG-API.
