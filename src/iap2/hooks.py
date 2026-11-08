#!/usr/bin/env python3
"""Add the LeafiaEv calls (src/iap2/smali) to a baksmali'd Iap2ServerApp.

usage: hooks.py <smali dir>

  Iap2Service.onCreate: LeafiaEv.start(this) right after the bridge's
      Ev6BtTrigger.register call (at its :catchall_c9 label)
  Iap2HandleNoti.sendEventToNotiHandler: LeafiaEv.onNoti(what) first

Each anchor must occur exactly once, so another build stops the script
instead of patching the wrong place. LeafiaEv also calls the synthetic
accessors Iap2Service.access$200 (mLock), access$300 (mHandleIap2) and
access$2800 (Iap2SendVehicleStatus); they are checked here too.
"""
import os, sys

D = os.path.join(sys.argv[1], 'com', 'tcc', 'iap2server')


def edit(name, anchor, add):
    p = os.path.join(D, name)
    s = open(p).read()
    if s.count(anchor) != 1:
        sys.exit('hooks.py: %s: anchor found %d times' % (name, s.count(anchor)))
    open(p, 'w').write(s.replace(anchor, anchor + add))


svc = open(os.path.join(D, 'Iap2Service.smali')).read()
for need in ('.method static synthetic access$200()Ljava/lang/Object;\n    .registers 1\n\n    .prologue\n'
             '    .line 76\n    sget-object v0, Lcom/tcc/iap2server/Iap2Service;->mLock:Ljava/lang/Object;',
             '.method static synthetic access$300()J\n    .registers 2\n\n    .prologue\n'
             '    .line 76\n    sget-wide v0, Lcom/tcc/iap2server/Iap2Service;->mHandleIap2:J',
             '.method static synthetic access$2800(Lcom/tcc/iap2server/Iap2Service;JLandroid/os/Parcel;)Z',
             '.method IsValidSvcState()Z'):
    if svc.count(need) != 1:
        sys.exit('hooks.py: Iap2Service differs: ' + need.split('\n')[0])

edit('Iap2Service.smali',
     '    invoke-static {p0, v3}, Lcom/tcc/iap2server/Ev6BtTrigger;->register'
     '(Lcom/tcc/iap2server/Iap2Service;Landroid/content/BroadcastReceiver;)V\n'
     '    :try_end_c9\n    .catchall {:try_start_c4 .. :try_end_c9} :catchall_c9\n\n'
     '    .line 408\n    :catchall_c9\n',
     '    invoke-static {p0}, Lcom/tcc/iap2server/LeafiaEv;->start(Lcom/tcc/iap2server/Iap2Service;)V\n\n')
edit('Iap2HandleNoti.smali',
     '.method public sendEventToNotiHandler(IIILjava/lang/Object;)V\n    .registers 11\n'
     '    .param p1, "what"    # I\n    .param p2, "arg1"    # I\n    .param p3, "arg2"    # I\n'
     '    .param p4, "obj"    # Ljava/lang/Object;\n\n    .prologue\n',
     '    invoke-static {p1}, Lcom/tcc/iap2server/LeafiaEv;->onNoti(I)V\n\n')
