#!/usr/bin/env python3
"""Make the iAP2 identification say the car is electric (Iap2ServerApp).

usage: ev_engine.py <in classes.dex> <out classes.dex>

The head unit sends a VehicleInformation component during iAP2 identification
(Iap2InitInformationMsg.getVehicelInformationGroup). Its EngineType parameter
(id 2) is gated by an instance flag, iAP2UsedViehicleInfoEngineType, that the
stock code only ever sets to 0, so the iPhone is never told the engine type.
The value would come from the static iAP2VehicleInfoEngineType, default 0
(Gasoline).

This rewrites two instructions in that method, in place and at the same size:

    iget v1, v8, ...iAP2UsedViehicleInfoEngineType   ->  const/4 v1, 1 ; nop
    sget v3, ...iAP2VehicleInfoEngineType            ->  const/4 v3, 2 ; nop

2 is Iap2Const.EngineType.Electric (Gasoline 0, Diesel 1, Electric 2, CNG 3).
The bytes around both instructions must occur exactly once, so another build
stops the script instead of patching the wrong place. The dex checksum and
signature are recomputed.
"""
import hashlib, struct, sys, zlib


def field_index(d, cls, name):
    """Index of field <cls>-><name> in the dex field_ids table."""
    ssz, soff = struct.unpack_from('<II', d, 0x38)
    tsz, toff = struct.unpack_from('<II', d, 0x40)
    fsz, foff = struct.unpack_from('<II', d, 0x50)

    def string(i):
        o = struct.unpack_from('<I', d, soff + 4 * i)[0]
        while d[o] & 0x80:
            o += 1
        o += 1
        return d[o:d.index(b'\0', o)].decode('utf-8')

    def tname(t):
        return string(struct.unpack_from('<I', d, toff + 4 * t)[0])

    hits = [i for i in range(fsz)
            if tname(struct.unpack_from('<H', d, foff + 8 * i)[0]) == cls
            and string(struct.unpack_from('<I', d, foff + 8 * i + 4)[0]) == name]
    if len(hits) != 1:
        sys.exit('field %s->%s: %d matches' % (cls, name, len(hits)))
    return hits[0]


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    d = bytearray(open(sys.argv[1], 'rb').read())
    if d[:4] != b'dex\n':
        sys.exit('not a dex file')
    cls = 'Lcom/tcc/iap2server/Iap2InitInformationMsg;'
    used = field_index(d, cls, 'iAP2UsedViehicleInfoEngineType')
    value = field_index(d, cls, 'iAP2VehicleInfoEngineType')
    # getVehicelInformationGroup +0x18 .. +0x23:
    #   iget v1, v8, used ; if-eqz v1, +0xc ; const/4 v1, 2 ; new-array v2, v4, [I
    #   sget v3, value ; aput v3, v2, v5
    old = (bytes([0x52, 0x81]) + struct.pack('<H', used)
           + bytes([0x38, 0x01, 0x0c, 0x00, 0x12, 0x21, 0x23, 0x42]))
    tail = bytes([0x60, 0x03]) + struct.pack('<H', value) + bytes([0x4b, 0x03, 0x02, 0x05])
    hits = [i for i in range(len(d)) if d.startswith(old, i)]
    hits = [i for i in hits if d[i + 14:i + 22] == tail]
    if len(hits) != 1:
        sys.exit('anchor found %d times (expected 1): unknown Iap2ServerApp build' % len(hits))
    at = hits[0]
    d[at:at + 4] = bytes([0x12, 0x11, 0x00, 0x00])            # const/4 v1, 1 ; nop
    d[at + 14:at + 18] = bytes([0x12, 0x23, 0x00, 0x00])      # const/4 v3, 2 ; nop
    d[12:32] = hashlib.sha1(bytes(d[32:])).digest()
    d[8:12] = struct.pack('<I', zlib.adler32(bytes(d[12:])) & 0xffffffff)
    open(sys.argv[2], 'wb').write(d)
    print('EngineType Electric at dex offset 0x%x' % at)


if __name__ == '__main__':
    main()
