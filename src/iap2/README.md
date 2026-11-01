# EV identification for CarPlay (test build, US Ioniq 5)

Goal: have the iPhone treat the car as an electric vehicle, as DiPlay (an open
CarPlay receiver for BYD head units) gets it to: the iPhone then starts vehicle
status updates (0xA100) and Apple Maps can warn at low charge and offer
chargers. Full charging-stop routing is not promised.

An iPhone decides this once, from the iAP2 identification. It needs:

| Identification component | Parameters |
|---|---|
| VehicleInformation (20) | EngineType = Electric (2), SupportedChargingConnectors (11, repeated) |
| VehicleStatus (21) | Range 3, RangeWarning 6, RangeElectric 11, RangeWarningElectric 15, ElectricChargeInfo 21, MaxRangeInfo 30 |

and answers 0xA100 with a VehicleStatusUpdate (0xA101): 3, 6, 11, 15, battery
Wh 21/22/23 (min, current, max), displayed percentage x1000 (24), charging (25),
max range (30). (Parameter numbers from DiPlay, GPL-3; no code taken from it.)

The stock Telechips stack sends none of the EV parts. Two patches:

- `ev_engine.py` (Iap2ServerApp's dex, in place, same size): EngineType
  Electric; with `--ev-status` it also turns on the VehicleStatus component and
  its Support flags for 3, 6, 11, 15 and two unused ones whose ids become 21
  and 30.
- `evnative/ev_native.py` (`libiap2session.so`): adds two segments with code
  (`evnative/ev.S`) and bigger tables, and re-points the stock code at them:
  charging connectors CCS1 and J1772, EngineType always Electric, the VehicleStatus
  identification table takes ids 21 and 30, and every 0xA101 carries the ten
  parameters above. No relocations are added; every patched site is checked
  against the stock bytes first. The library delta is
  `patches/neev/libiap2session.ev.lpd` (part `3_bridge`, which backs up and
  restores the stock library).

**Test only:** the values are fixed (15 %, 60 km of 400 km, 11.6 of 77.4 kWh,
not charging), not the car's. Reading them from the car (`HEVManager`, read
only) and sending updates every 30 s is the next step if this works.

Checked off-car: the patched library's packet encoder, run under an ARM
emulator (unicorn), writes VehicleInformation with EngineType 2 and connectors
0 and 2, and the full 0xA101 above; the mock head unit installs and uninstalls
it byte-exact. Not yet run on a car.

```
tools/lpatch/build.sh
pip install --require-hashes -r tools/requirements.txt
apt install binutils-arm-linux-gnueabi
src/iap2/rebuild.sh neev <stock Iap2ServerApp.odex> <stock libiap2session.so>           # writes both .lpd
src/iap2/rebuild.sh neev <stock Iap2ServerApp.odex> <stock libiap2session.so> --check   # only verifies
```

Then put the printed md5s in the 3_bridge lines of `patches/neev/manifest`
and run `tools/compat-built.py`.
