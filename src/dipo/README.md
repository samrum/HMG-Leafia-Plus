# CarPlay app additions (HKMC_DiPO)

Source for the Leafia code that `patches/<set>/HKMC_DiPO.bridge.lpd` adds to
the CarPlay app, on top of the upstream bridge build. Only our own code is here:
the new classes in `smali/`, and in `hooks.py` the few lines that call them from
stock methods, each tied to an anchor that must occur once.

| Feature | Class | Hooked from |
|---|---|---|
| `auto-open`: switch to CarPlay about 1.5 s after a session starts, through the car's ModeManager (`launchMode(DIPO)`, the media path: Now Playing, and playback resumes) | `com.ev6.cpwl.LeafiaAutoOpen` | `service.q.onSessionStarted` |

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
