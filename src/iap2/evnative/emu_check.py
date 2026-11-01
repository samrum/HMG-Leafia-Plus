#!/usr/bin/env python3
"""Off-car check of the EV build of libiap2session.so: runs the library's own
packet encoder (iAP2SessionPacketSetParamListArrayNew) under an ARM emulator
with the patched tables and GetPointer functions, and checks what it writes.

usage: emu_check.py <patched libiap2session.so>      (pip install unicorn)
"""
import struct, sys
from unicorn import *
from unicorn.arm_const import *
so = open(sys.argv[1],'rb').read()
B = 0x10000000
mu = Uc(UC_ARCH_ARM, UC_MODE_THUMB)
mu.mem_map(B, 0x40000)
# load PT_LOADs
phoff, = struct.unpack_from('<I', so, 28); phnum, = struct.unpack_from('<H', so, 44)
for i in range(phnum):
    t,off,va,pa,fs,ms,fl,al = struct.unpack_from('<8I', so, phoff+32*i)
    if t==1: mu.mem_write(B+va, so[off:off+fs])
# relocations: R_ARM_RELATIVE only (enough for .data pointers we touch)
rel, relsz = 0xe88c, 4560
for i in range(relsz//8):
    off, info = struct.unpack_from('<II', so, rel+8*i)
    if info & 0xff == 23:
        v = struct.unpack('<I', mu.mem_read(B+off,4))[0]
        mu.mem_write(B+off, struct.pack('<I', v+B))
CTX=0x20000000; mu.mem_map(CTX, 0x60000)
STK=0x30000000; mu.mem_map(STK, 0x10000)
BUF=0x31000000; mu.mem_map(BUF, 0x1000)
STOP=0x32000000; mu.mem_map(STOP, 0x1000)
def ret(uc, r0=None):
    if r0 is not None: uc.reg_write(UC_ARM_REG_R0, r0)
    uc.reg_write(UC_ARM_REG_PC, uc.reg_read(UC_ARM_REG_LR))
def cstr(uc,a):
    s=b''
    while True:
        c=uc.mem_read(a+len(s),1)
        if c==b'\0': return s
        s+=bytes(c)
calls=[]
def hook(uc, addr, size, _):
    a = addr - B
    if a in (0x17838, 0x1785c, 0x17880, 0x178a4): ret(uc)
    elif a == 0xfe4c: ret(uc, len(cstr(uc, uc.reg_read(UC_ARM_REG_R0))))
    elif a == 0xfca8:
        d,s,n=[uc.reg_read(r) for r in (UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2)]
        uc.mem_write(d, bytes(uc.mem_read(s,n))); ret(uc,d)
    elif 0xfc7c <= a < 0xffc0: print('unhandled plt', hex(a)); uc.emu_stop()
mu.hook_add(UC_HOOK_CODE, hook, begin=B, end=B+0x40000)
def call(fn, args, stack):
    sp = STK+0x8000
    for i,v in enumerate(stack): mu.mem_write(sp+4*i, struct.pack('<I', v))
    for r,v in zip((UC_ARM_REG_R0,UC_ARM_REG_R1,UC_ARM_REG_R2,UC_ARM_REG_R3), args): mu.reg_write(r,v)
    mu.reg_write(UC_ARM_REG_SP, sp); mu.reg_write(UC_ARM_REG_LR, STOP|1)
    mu.emu_start(B+fn|1, STOP, count=2000000)
    r=mu.reg_read(UC_ARM_REG_R0); return r - (1<<32) if r>>31 else r
def parse(b):
    out=[]; i=0
    while i+4<=len(b):
        ln,pid=struct.unpack_from('>HH',b,i); out.append((pid,b[i+4:i+ln].hex())); i+=ln
    return out
SPLAEN=0x1a3b4
def build(table, count, gp):
    n = call(SPLAEN, (B+table, count, 0, 0), (CTX, 1, B+gp|1))
    m = call(SPLAEN, (B+table, count, BUF, 0x400), (CTX, 0, B+gp|1))
    return n, m, parse(bytes(mu.mem_read(BUF, m)))
which=('vinfo','send')
if 'vinfo' in which:
    tbl = struct.unpack('<I', mu.mem_read(B+0x11a8c,4))[0] + 0x11a16+4
    gp = struct.unpack('<I', mu.mem_read(B+0x11928,4))[0] + 0x1189a+4 - 1
    r = build(tbl & 0xffffffff, 6, gp & 0xffffffff)
    print('VehicleInformation', r)
    assert r[2] == [(0, '0000'), (1, '00'), (2, '02'), (6, '00'), (8, '00'), (11, '00'), (11, '02')], r
if 'send' in which:
    tbl = (struct.unpack('<I', mu.mem_read(B+0x15044,4))[0] + 0x15010+4) & 0xffffffff
    cnt = mu.mem_read(B+0x1500e,1)[0]
    gp = (struct.unpack('<I', mu.mem_read(B+0x1504c,4))[0] + 0x15014+4 - 1) & 0xffffffff
    r = build(tbl, cnt, gp)
    print('A101', r)
    assert [p for p, v in r[2]] == [3, 6, 11, 15, 21, 22, 23, 24, 25, 30], r
print('OK')
