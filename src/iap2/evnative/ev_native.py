#!/usr/bin/env python3
"""Make libiap2session.so declare an electric car to the iPhone (TEST BUILD).

usage: ev_native.py <stock libiap2session.so> <out libiap2session.so>

Needs binutils for ARM (`apt install binutils-arm-linux-gnueabi`).

The Telechips iAP2 library builds the identification and the vehicle status
messages from fixed tables (24-byte entries: used flag, parameter id, type,
callbacks) in .data, and reads the values through per-group GetPointer
functions. The stock tables lack what an iPhone needs to treat the car as an
EV (see src/iap2/README.md). This adds two segments to the library:

  R+X: a new program header table, then the code in ev.S (two GetPointer
       wrappers) and its constants
  R+W: the wrappers' state and values, then bigger copies of two tables

and re-points PC-relative literals in the stock code at them:

  VehicleInformation (identification param 20): a 6th entry,
      SupportedChargingConnectors (11), repeated: CCS1 (0) and J1772 (2);
      EngineType (2) always Electric. Table 5 -> 6 entries.
  VehicleStatus (identification param 21): ids 9 and 12, which the car never
      uses (gasoline and CNG range), become 21 (ElectricChargeInfo) and 30
      (MaxRangeInfo) in place. Iap2ServerApp (ev_engine.py --ev-status) turns
      them on and sends the new ids.
  VehicleStatusUpdate (0xA101): the send list becomes 7 entries the phone and
      Iap2ServerApp can switch (4, 9, 10, 12, 13, 14, 16, as before) followed
      by 10 that are always sent: Range 3, RangeWarning 6, RangeElectric 11,
      RangeWarningElectric 15, battery Wh 21/22/23, percentage x1000 24,
      charging 25, MaxRangeElectric 30. Parsers see only the first 7, so
      nothing clears the always-sent ones.

The values are FIXED TEST VALUES (below), not the car's. No relocations are
added: every new pointer is PC-relative. Every patched site is checked
against the stock bytes first.
"""
import hashlib, os, struct, subprocess, sys, tempfile

STOCK_MD5 = 'fc7cb675b46a44bd893a1edc054c5e71'   # US Ioniq 5 / EV6 260507

# fixed test values
VALUES = dict(EV_RANGE_KM=60, EV_CHARGE_WH=11610, EV_CAPACITY_WH=77400,
              EV_PERCENT_X1000=15000, EV_MAX_RANGE_KM=400)

# stock addresses
VINFO_IDEN_TABLE = 0x30cec      # idenInfoVehicleInfoGroupList, 5 entries
VSTAT_TABLE = 0x30b54           # idInfoVehicleStatusGroupList, 13 entries
SEND_TABLE = 0x31d9c            # iAP2VehicleStatusSendList, 12 entries
VINFO_IDEN_GETPTR = 0x11b3c     # iAP2ControlIden_VehicleInfoIdenGetPointer
UPDATES_GETPTR = 0x14970        # iAP2ControlVehicleStatusGetUpdatesPointer
DATA_DELTA = 0x1000             # .data: file offset = va - 0x1000

NEW_RX_OFF, NEW_RX_VA = 0x35000, 0x37000
NEW_RW_OFF, NEW_RW_VA = 0x36000, 0x38000
PHNUM = 10

ENTRY = 24
TYPE_INT16, TYPE_UINT16, TYPE_UINT32, TYPE_ENUM, TYPE_BOOL = 1, 5, 6, 8, 9
SEND_SWITCHED = (4, 9, 10, 12, 13, 14, 16)
SEND_ALWAYS = ((3, TYPE_UINT16), (6, TYPE_BOOL), (11, TYPE_UINT16), (15, TYPE_BOOL),
               (21, TYPE_UINT32), (22, TYPE_UINT32), (23, TYPE_UINT32), (24, TYPE_UINT32),
               (25, TYPE_BOOL), (30, TYPE_UINT16))

HERE = os.path.dirname(os.path.abspath(__file__))


def die(msg):
    sys.exit('ev_native: ' + msg)


def entry(used, pid, typ):
    return struct.pack('<HHH', used, pid, typ) + bytes(ENTRY - 6)


def build_code(tmp):
    o, elf = os.path.join(tmp, 'ev.o'), os.path.join(tmp, 'ev.elf')
    asm = ['arm-linux-gnueabi-as', '-mthumb', '-march=armv7-a', '-o', o]
    for k, v in VALUES.items():
        asm += ['--defsym', '%s=%d' % (k, v)]
    subprocess.run(asm + [os.path.join(HERE, 'ev.S')], check=True)
    subprocess.run(['arm-linux-gnueabi-ld', '-T', os.path.join(HERE, 'ev.ld'),
                    '--defsym', 'EV_TEXT=0x%x' % (NEW_RX_VA + 32 * PHNUM),
                    '--defsym', 'EV_DATA=0x%x' % NEW_RW_VA,
                    '--defsym', 'STOCK_VINFO_IDEN_GETPTR=0x%x' % (VINFO_IDEN_GETPTR | 1),
                    '--defsym', 'STOCK_STATUS_UPDATES_GETPTR=0x%x' % (UPDATES_GETPTR | 1),
                    '-o', elf, o], check=True)
    syms = {}
    for line in subprocess.run(['arm-linux-gnueabi-nm', elf], check=True,
                               capture_output=True, text=True).stdout.split('\n'):
        p = line.split()
        if len(p) == 3:
            syms[p[2]] = int(p[0], 16)
    sec = {}
    for name in ('.text', '.data'):
        out = os.path.join(tmp, name[1:] + '.bin')
        subprocess.run(['arm-linux-gnueabi-objcopy', '-O', 'binary', '-j', name, elf, out], check=True)
        sec[name] = open(out, 'rb').read()
    return syms, sec


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    d = bytearray(open(sys.argv[1], 'rb').read())
    if hashlib.md5(d).hexdigest() != STOCK_MD5:
        die('not the stock library this patch was made for')

    def expect(off, hexbytes, what):
        if d[off:off + len(hexbytes) // 2] != bytes.fromhex(hexbytes):
            die('unexpected bytes at 0x%x (%s)' % (off, what))

    def put(off, hexbytes, old, what):
        expect(off, old, what)
        d[off:off + len(hexbytes) // 2] = bytes.fromhex(hexbytes)

    def lit(lit_va, add_va, old_target, new_target, what):
        """re-point `ldr rX, [pc, #n]` (literal at lit_va) + `add rX, pc` at add_va"""
        old = (old_target - (add_va + 4)) & 0xffffffff
        new = (new_target - (add_va + 4)) & 0xffffffff
        if struct.unpack_from('<I', d, lit_va)[0] != old:
            die('literal at 0x%x is not %s' % (lit_va, what))
        struct.pack_into('<I', d, lit_va, new)

    def imm8(va, reg, old, new, what):
        """movs rX, #imm8"""
        expect(va, '%02x%02x' % (old, 0x20 | reg), what)
        d[va] = new

    # --- the new tables (in the R+W segment, after ev.S's .data) ---
    stock_vinfo = d[VINFO_IDEN_TABLE - DATA_DELTA:VINFO_IDEN_TABLE - DATA_DELTA + 5 * ENTRY]
    vinfo = bytearray()
    for i in range(5):
        e = bytearray(stock_vinfo[i * ENTRY:(i + 1) * ENTRY])
        pid, typ = struct.unpack_from('<HH', e, 2)
        if (pid, typ) != ((0, 5), (1, 10), (2, 8), (6, 10), (8, 10))[i]:
            die('VehicleInformation table differs from stock')
        e[8:] = bytes(ENTRY - 8)      # EngineType's init callback: ev.S serves id 2
        vinfo += e
    vinfo += entry(1, 11, TYPE_ENUM)  # SupportedChargingConnectors
    stock_send = d[SEND_TABLE - DATA_DELTA:SEND_TABLE - DATA_DELTA + 12 * ENTRY]
    want = ((3, 5), (4, 1), (4, 1), (6, 9)) + tuple((i, 9) for i in range(9, 17))
    for i in range(12):
        if struct.unpack_from('<HH', stock_send, i * ENTRY + 2) != want[i]:
            die('VehicleStatus send list differs from stock')
    send = b''.join(entry(0, pid, TYPE_INT16 if pid == 4 else TYPE_BOOL) for pid in SEND_SWITCHED)
    send += b''.join(entry(1, pid, typ) for pid, typ in SEND_ALWAYS)
    n_switched, n_send = len(SEND_SWITCHED), len(SEND_SWITCHED) + len(SEND_ALWAYS)

    with tempfile.TemporaryDirectory() as tmp:
        syms, sec = build_code(tmp)
    tables = syms['ev_tables']
    vinfo_va = tables
    send_va = tables + len(vinfo)
    rw = sec['.data'] + bytes(tables - NEW_RW_VA - len(sec['.data'])) + vinfo + send
    rx_code = sec['.text']

    # --- VehicleInformation: 6-entry table and the wrapper ---
    lit(0x11a8c, 0x11a16, VINFO_IDEN_TABLE, vinfo_va, 'Iden group list')
    imm8(0x11a12, 1, 5, 6, 'Iden VehicleInformation count')
    lit(0x12800, 0x127dc, VINFO_IDEN_TABLE, vinfo_va, 'SetVehicleInfoInit table')
    lit(0x12834, 0x1280c, VINFO_IDEN_TABLE, vinfo_va, 'SetVehicleInfoDone table')
    lit(0x11928, 0x1189a, VINFO_IDEN_GETPTR | 1, syms['ev_vinfo_getptr'] | 1, 'Iden GetPointer')

    # --- VehicleStatus identification: ids 9 -> 21, 12 -> 30 in place ---
    for idx, old, new in ((5, 9, 21), (8, 12, 30)):
        off = VSTAT_TABLE - DATA_DELTA + idx * ENTRY + 2
        if struct.unpack_from('<HH', d, off) != (old, 12):
            die('VehicleStatus table entry %d differs from stock' % idx)
        struct.pack_into('<H', d, off, new)

    # --- VehicleStatusUpdate send list ---
    lit(0x14ee4, 0x14ede, SEND_TABLE, send_va, 'GetStatusGroup')
    imm8(0x14ed8, 3, 12, n_switched, 'GetStatusGroup count')
    lit(0x14efc, 0x14ef0, SEND_TABLE, send_va, 'StatusFirst')
    imm8(0x14ef2, 2, 12, n_switched, 'StatusFirst count')
    lit(0x14fc8, 0x14fba, SEND_TABLE, send_va, 'UpdatesSetParam')
    imm8(0x14fbc, 3, 12, n_switched, 'UpdatesSetParam count')
    lit(0x14fa8, 0x14f6e, SEND_TABLE, send_va, 'UpdatesAfterStart')
    imm8(0x14f6c, 2, 12, n_send, 'UpdatesAfterStart count')
    lit(0x15044, 0x15010, SEND_TABLE, send_va, 'Updates')
    imm8(0x1500e, 2, 12, n_send, 'Updates count')
    # the two builders read values through the wrapper (the parser keeps the stock one)
    lit(0x14fac, 0x14f72, UPDATES_GETPTR | 1, syms['ev_status_getptr'] | 1, 'UpdatesAfterStart GetPointer')
    lit(0x1504c, 0x15014, UPDATES_GETPTR | 1, syms['ev_status_getptr'] | 1, 'Updates GetPointer')

    # --- ELF: program headers moved into the new R+X segment, two PT_LOADs added ---
    e_phoff, = struct.unpack_from('<I', d, 28)
    phentsize, phnum = struct.unpack_from('<HH', d, 42)
    if (e_phoff, phentsize, phnum) != (52, 32, 8) or len(d) > NEW_RX_OFF:
        die('ELF layout differs from stock')
    ph = [list(struct.unpack_from('<8I', d, e_phoff + 32 * i)) for i in range(phnum)]
    if [p[0] for p in ph] != [6, 3, 1, 1, 2, 0x6474e551, 0x70000001, 0x6474e552]:
        die('program headers differ from stock')
    phsize = 32 * PHNUM
    rx_size = phsize + len(rx_code)
    ph[0][1:6] = [NEW_RX_OFF, NEW_RX_VA, NEW_RX_VA, phsize, phsize]       # PT_PHDR
    new_rx = [1, NEW_RX_OFF, NEW_RX_VA, NEW_RX_VA, rx_size, rx_size, 5, 0x1000]
    new_rw = [1, NEW_RW_OFF, NEW_RW_VA, NEW_RW_VA, len(rw), len(rw), 6, 0x1000]
    ph = ph[:4] + [new_rx, new_rw] + ph[4:]                 # PT_LOADs in address order
    struct.pack_into('<I', d, 28, NEW_RX_OFF)
    struct.pack_into('<H', d, 44, PHNUM)
    d += bytes(NEW_RX_OFF - len(d))
    d += b''.join(struct.pack('<8I', *p) for p in ph) + rx_code
    d += bytes(NEW_RW_OFF - len(d)) + rw
    open(sys.argv[2], 'wb').write(d)
    print('libiap2session EV test build: connectors CCS1+J1772, %d%% charge, %d km of %d km'
          % (VALUES['EV_PERCENT_X1000'] // 1000, VALUES['EV_RANGE_KM'], VALUES['EV_MAX_RANGE_KM']))


if __name__ == '__main__':
    main()
