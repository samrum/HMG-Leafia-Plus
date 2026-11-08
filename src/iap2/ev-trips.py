#!/usr/bin/env python3
"""Measured consumption from the EV test build's trip log (ev-trips.csv,
collected by the kit into LEAFIA/private/logs/ev/).

usage: ev-trips.py <ev-trips.csv> [ev-trips.1.csv ...] [--odo-km-per-unit X]

Each row is one changed reading, about every 15 s while the car is on:
time, SOC (0.5 %), remaining energy (2 Wh steps), cluster range, odometer
(raw), charge state, climate power (raw), whether CarPlay wanted updates.
The odometer's raw unit is not confirmed: by default 0.1 mile (US cluster);
pass --odo-km-per-unit 0.1 if it turns out to be 0.1 km.

Rows are cut into drives (a gap over 5 minutes or energy going up ends one),
each drive into 2-minute windows, and every window's energy and distance go
into a speed band. Prints Wh/km per band, per drive and overall, next to
the consumption model's values, to tune LEAFIA-EV-MODEL.json.
"""
import csv, sys

BANDS = (0, 20, 40, 60, 80, 100, 120, 999)    # km/h


def rows(paths):
    out = []
    for p in paths:
        for r in csv.DictReader(open(p)):
            try:
                out.append((int(r['time_ms']) / 1000.0, int(r['energy_2wh']), int(r['odometer_raw'])))
            except (KeyError, ValueError):
                pass
    out.sort()
    return [r for r in out if 0 < r[1] < 0xffff and r[2] > 0]


def drives(rs):
    cur = []
    for r in rs:
        if cur and (r[0] - cur[-1][0] > 300 or r[1] > cur[-1][1] + 5):
            yield cur
            cur = []
        cur.append(r)
    if cur:
        yield cur


def main():
    args = sys.argv[1:]
    k = 0.1 * 1.609344
    if '--odo-km-per-unit' in args:
        i = args.index('--odo-km-per-unit'); k = float(args[i + 1]); del args[i:i + 2]
    if not args:
        sys.exit(__doc__)
    band = {b: [0.0, 0.0, 0.0] for b in BANDS[:-1]}    # Wh, km, hours
    total = [0.0, 0.0]
    for n, d in enumerate(drives(rows(args)), 1):
        wh = (d[0][1] - d[-1][1]) * 2
        km = (d[-1][2] - d[0][2]) * k
        if km < 1:
            continue
        total[0] += wh; total[1] += km
        print('drive %d: %.1f km in %.0f min, %.2f kWh, %.0f Wh/km'
              % (n, km, (d[-1][0] - d[0][0]) / 60, wh / 1000, wh / km))
        start = d[0]
        for r in d[1:]:
            if r[0] - start[0] >= 120 or r is d[-1]:
                h = (r[0] - start[0]) / 3600
                dk = (r[2] - start[2]) * k
                if h > 0:
                    v = dk / h
                    b = max(x for x in BANDS[:-1] if x <= v)
                    band[b][0] += (start[1] - r[1]) * 2; band[b][1] += dk; band[b][2] += h
                start = r
    if total[1]:
        print('all drives: %.1f km, %.0f Wh/km' % (total[1], total[0] / total[1]))
    print('speed band   km     Wh/km')
    for i, b in enumerate(BANDS[:-1]):
        wh, km, h = band[b]
        if km >= 0.5:
            print('%3d-%-3d km/h %6.1f %6.0f' % (b, BANDS[i + 1], km, wh / km))
    print('(includes climate and electronics; the model adds vehicle_auxiliary_power_w on top of its per-distance values)')


if __name__ == '__main__':
    main()
