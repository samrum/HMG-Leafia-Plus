# EV identification for CarPlay (test build, US Ioniq 5)

Goal: have the iPhone treat the car as an electric vehicle, as DiPlay (an open
CarPlay receiver for BYD head units) gets it to: the iPhone then starts vehicle
status updates (0xA100) and Apple Maps can warn at low charge and offer
chargers. Full charging-stop routing is not promised.

An iPhone decides this once, from the iAP2 identification. It needs:

| Identification component | Parameters |
|---|---|
| VehicleInformation (20) | EngineType = Electric (2), DisplayName 6 / MapsDisplayName 8, SupportedChargingConnectors (11, repeated), maximum DC (12) and AC (14) charging power in W |
| VehicleStatus (21) | Range 3, RangeWarning 6, RangeElectric 11, RangeWarningElectric 15, ElectricChargeInfo 21, MaxRangeInfo 30 |

and answers 0xA100 with a VehicleStatusUpdate (0xA101): 3, 6, 11 (u16), 15,
battery Wh 21/22/23 (min, current, max), displayed percentage x1000 (24), the
charging model (26) and consumption model (27) as compact NUL-terminated JSON
strings, and max range (30). In Apple Maps the car is then added under
profile > Vehicles, after deleting and redoing the phone's pairing.

Parameter numbers first from DiPlay (GPL-3); 12, 14, 26 and 27, the model
JSON (`evnative/ioniq5-contracts.json`) and the setup steps from Isaac
Wisdom's [egmp-carplay-ev-routing](https://github.com/isaacwisdom/egmp-carplay-ev-routing)
(GPL-3.0-or-later, which credits augard/evmaps for the model dictionaries).
No code was copied from either; this is a separate native patch.

The stock Telechips stack sends none of the EV parts. Two patches:

- `ev_engine.py` (Iap2ServerApp's dex, in place, same size): EngineType
  Electric; with `--ev-status` it also turns on the VehicleStatus component and
  its Support flags for 3, 6, 11, 15 and two unused ones whose ids become 21
  and 30.
- `evnative/ev_native.py` (`libiap2session.so`): adds two segments with code
  (`evnative/ev.S`) and bigger tables, and re-points the stock code at them:
  name "Hyundai Ioniq 5", charging connectors CCS1 (235 kW) and J1772
  (10.9 kW), EngineType always Electric, the VehicleStatus identification table
  takes ids 21 and 30, and every 0xA101 carries the eleven parameters above. No relocations are added; every patched site is checked
  against the stock bytes first. The library delta is
  `patches/neev/libiap2session.ev.lpd` (part `3_bridge`, which backs up and
  restores the stock library).

Every EV field the library writes is also logged as an error-level line with
tag `iAP2` (`Leafia EV: identification VehicleInformation param N sent`,
`... VehicleStatus param N declared`, `Leafia EV: VehicleStatusUpdate param N`),
through the library's own `iAP2InterfaceLogError`, so a capture shows whether
the fields reached the packet without turning on the library's debug logs.

**Test only:** the values are fixed (50 %, 200 km of 400 km, 38.7 of 77.4
kWh), not the car's, and the models are uncalibrated estimates. Reading them from the car (`HEVManager`, read
only) and sending updates every 30 s is the next step if this works.

Checked off-car: the patched library's packet encoder, run under an ARM
emulator (unicorn), writes the VehicleInformation and the full 0xA101 above
(`evnative/emu_check.py`); the mock head unit installs and uninstalls it
byte-exact. Not yet run on a car with the models (26, 27) and charging power.

```
tools/lpatch/build.sh
pip install --require-hashes -r tools/requirements.txt
apt install binutils-arm-linux-gnueabi
src/iap2/rebuild.sh neev <stock Iap2ServerApp.odex> <stock libiap2session.so>           # writes both .lpd
src/iap2/rebuild.sh neev <stock Iap2ServerApp.odex> <stock libiap2session.so> --check   # only verifies
```

Then put the printed md5s in the 3_bridge lines of `patches/neev/manifest`
and run `tools/compat-built.py`.
