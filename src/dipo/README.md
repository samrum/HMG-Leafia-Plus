# CarPlay app additions (HKMC_DiPO)

Source for the Leafia code that `patches/<set>/HKMC_DiPO.bridge.lpd` adds to
the CarPlay app, on top of the upstream bridge build. Only our own code is here:
the new classes in `smali/`, and in `hooks.py` the few lines that call them from
stock methods, each tied to an anchor that must occur once.

| Feature | Class | Hooked from |
|---|---|---|
| `auto-open`: switch to CarPlay about 1.5 s after a session starts, through the car's ModeManager (`launchMode(DIPO)`, the media path: Now Playing, and playback resumes), then 1.5 s later CarPlay Home if CarPlay is on screen | `com.ev6.cpwl.LeafiaAutoOpen` | `service.q.onSessionStarted` |
| `mute`: on release of the mute key (91), when CarPlay owns main audio and there is no CarPlay call or Siri, send Pause if the car is now muted or Play if not | `com.daudio.app.dipo.service.LeafiaMuteKey` (in that package for DipoService's audio-manager accessor `B()`) | start of `service.v.onAllKeyForService` |
| `call-key`: the Call key (5) with no call, ringing call or Siri: a short press sends CarPlay Back (only while CarPlay is on screen), holding it 600 ms opens CarPlay Maps (`displayMap`, or DipoActivity mode 1 to bring CarPlay up first). Otherwise the stock answer/hang-up handling runs | `com.daudio.app.dipo.service.LeafiaButtons` | start of `service.v.onAllKeyForService` (returns early when it took the key) |
| `favorite-home`: the Favorite key set to Phone Projection also sends CarPlay Home, then the stock code opens CarPlay as before | `com.daudio.app.dipo.service.LeafiaButtons` | `service.w.onReceive`, `ACTION_SHORTCUT_DIPO_CUSTOM`, before the DipoActivity check |

Classes called from another package must be `public`, with `public` entry points.
The mock head unit doesn't run Dalvik, so a mistake there only shows on the car
(`IllegalAccessError` when the hook runs).

## Rebuilding the patch

```
tools/lpatch/build.sh                       # host lpatch
pip install --require-hashes -r tools/requirements.txt
src/dipo/rebuild.sh neev <stock HKMC_DiPO.odex>          # writes the .lpd
src/dipo/rebuild.sh neev <stock HKMC_DiPO.odex> --check  # only verifies it
```

The stock odex comes from the unit (Leafia keeps a copy in
`/data/nemesis/backup/projection.tbt/`). After writing a new `.lpd`, put the
rebuilt APK's md5 in `patches/<set>/manifest` (3_bridge HKMC_DiPO line) and run
`tools/compat-built.py`. Only the Ioniq 5 US set (`neev`) has these features so far.
