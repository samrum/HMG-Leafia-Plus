# Wi-Fi settings fix (HKMC_WifiSettings, part 6_wifi)

Source for the code that `patches/common/HKMC_WifiSettings.wifi.<md5>.lpd` adds to the
stock Wi-Fi settings app (`com.hkmc.wifisettings`). Installed whenever the unit has the
Android Wi-Fi feature (`android.hardware.wifi.xml`) after part 1: with the opt-in Wi-Fi client
(`LEAFIA-WIFI-CLIENT`), or where part 1 adds it for the hotspot (US Ioniq 5, Korean sets);
and only on a unit whose stock app matches.

The head unit's one radio runs either the hotspot that wireless CarPlay/Android Auto use
or the Wi-Fi client. Stock, the Wi-Fi screen stopped the projection hotspot as soon as it
opened, started the client at the same instant it stopped the hotspot (which ended in
"Error" with Wi-Fi and the hotspot dead until a restart), never brought the hotspot back,
and labelled its Wi-Fi tab "Wi-Fi Hotspot".

| Change | Where |
|---|---|
| Opening the screen keeps the phone projection hotspot (AP mode 2) | `WifiClientSettings.onResume` -> `LeafiaWifi.stopApOnOpen` |
| The switch runs on its own thread: on = stop the hotspot, wait for it to report stopped + 1.5 s, start the client (on "Error": client off, hotspot back); off = client off, then the projection hotspot back | `ac.onPreferenceChange` -> `LeafiaWifi.toggle` |
| After the hotspot is back, reconnect the phone's Bluetooth (not during a call): the phone is only handed the hotspot when it connects over Bluetooth, and it went back to plain Bluetooth while the client ran | `LeafiaBtReconnect` (binder calls to Broadcom's `IHfDeviceBTCMService`: 0x1c HFP device, 4 disconnect, 3 connect) |
| Wi-Fi tab label: `string/wifi_settings` ("Wi-Fi", every language the app has) instead of `tab_menu_wifi_hotspot` | `settings/ui/NetworkConnectionSettings` |

`LeafiaWifi` logs with the tag `LeafiaWifi` (the kit's `logcat-network.txt` includes it).

## Rebuilding the patch

```
tools/lpatch/build.sh                       # host lpatch
pip install --require-hashes -r tools/requirements.txt
tools/mkwifi.py <LEAFIA/private/stock>      # writes the .lpd and its line in patches/common/optional
tools/compat-built.py
```

The stock tree needs `app/HKMC_WifiSettings.apk`, `app/HKMC_WifiSettings.odex` and the
framework odex files (the port kit collects all of them). The output is reproducible.
Made from the Ioniq 5 US 260507 app (odex md5 `164039dd...`); other cars need their own line.
