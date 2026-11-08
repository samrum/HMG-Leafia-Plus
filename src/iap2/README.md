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
  takes ids 21 and 30, and every 0xA101 carries the two models plus whatever
  battery and range values Iap2ServerApp last sent (below). The stock
  vehicle status parser now covers those entries and stores what it gets
  through our GetPointer. No relocations are added; every patched site is
  checked against the stock bytes first. The library delta is
  `patches/neev/libiap2session.ev.lpd` (part `3_bridge`, which backs up and
  restores the stock library).

- `smali/com/tcc/iap2server/LeafiaEv.smali` + `hooks.py` (Iap2ServerApp):
  live battery and range. Read-only: every 30 s, while the iPhone has
  vehicle status updates on (iAP2 notification 0xf, until 0x10), it asks the
  car's HEV service (`com.hkmc.micom.hev`, `getHEVStatus`, no permission
  needed) for the cluster SOC (0x19, 0.5 % steps), remaining usable energy
  (0x31, 2 Wh steps, 0xffff invalid) and cluster range (0x09, **miles** on US
  cars). Signal meanings from willemcvu/egmp-aa-ev-feat (docs/DATA-SOURCES.md).
  It sends through the stock `Iap2SendVehicleStatus` JNI call (same checks
  and lock as the unused stock `Iap2SvcSendVehicleStatusData`):
  - 22 current energy (Wh) and 24 percentage (x 1000),
  - 23 usable capacity: energy / SOC, learned (smoothed) at 50 % or more,
    estimated from 20 %, otherwise 77.4 kWh; kept within 40-77.4 kWh,
  - 21 minimum 0 Wh,
  - with a range reading: 3 and 11 range (km), 6 and 15 range warning at
    20 % or less, 30 range at 100 % (range / SOC, from 20 %, at most 700 km).
  A reading is sent when it changes, at least every 5 minutes, and a second
  after the phone turns updates on. Each send is logged with tag `LeafiaEv`
  (`sent true: soc/energy/range raw 47/7170/46 -> 14340 of 61021 Wh, ...`).

Every EV field the library writes in the identification is also logged as an
error-level line with tag `iAP2` (`Leafia EV: identification
VehicleInformation param N sent`, `... VehicleStatus param N declared`, and
`Leafia EV: building VehicleStatusUpdate (param 26)` for each update), through
the library's own `iAP2InterfaceLogError`, so a capture shows whether the
fields reached the packet without turning on the library's debug logs.

**Test build:** the charging and consumption models are Isaac Wisdom's
estimates, with the per-distance consumption values scaled by 0.6
(`CONSUMPTION_SCALE` in `evnative/ev_native.py`: on a 16-mile mixed trip his
values predicted twice the battery use), the car name and charging power are fixed, and the range unit is
assumed to be miles (US cars). Tested on a car with fixed values only
(2026-11-08, US Ioniq 5: Maps offered the car under Vehicles and planned
charging stops); the live values are not yet car-tested.

Checked off-car: the patched library's packet encoder and the stock vehicle
status parser, run under an ARM emulator (unicorn), write the
VehicleInformation and the 0xA101 above, before and after a fake Iap2ServerApp
update with and without range (`evnative/emu_check.py`); the Iap2ServerApp dex
passes `dexdump -c`; the mock head unit installs and uninstalls it byte-exact.
Dalvik's verifier has not seen the new class off-car.

```
tools/lpatch/build.sh
pip install --require-hashes -r tools/requirements.txt
apt install binutils-arm-linux-gnueabi   # and java, for smali
src/iap2/rebuild.sh neev <stock Iap2ServerApp.odex> <stock libiap2session.so>           # writes both .lpd
src/iap2/rebuild.sh neev <stock Iap2ServerApp.odex> <stock libiap2session.so> --check   # only verifies
```

Then put the printed md5s in the 3_bridge lines of `patches/neev/manifest`
and run `tools/compat-built.py`.
