.class final Lcom/hkmc/wifisettings/LeafiaBtReconnect;
.super Ljava/lang/Object;
.source "LeafiaBtReconnect.java"

# interfaces
.implements Landroid/content/ServiceConnection;
.implements Ljava/lang/Runnable;

# HMG Leafia Plus: after the Wi-Fi client goes off and the projection hotspot is back,
# reconnect the phone's Bluetooth so wireless CarPlay/Android Auto start again.
# The phone is only handed the hotspot when it connects over Bluetooth (iAP2 over
# Bluetooth for CarPlay); while the client ran it fell back to plain Bluetooth, so
# with the hotspot back nothing told it to rejoin (Ioniq 5 US logs, 2026-11-01).
# Turning Bluetooth off and on on the phone did restart CarPlay; this does the same
# from the head unit through Broadcom's connection manager (BTCM, the service behind
# HfDeviceBTCMManager in com.broadcom.bt.jar, which this app doesn't load, so the
# binder calls are made by hand: transaction codes from IHfDeviceBTCMService.Stub).
# Skipped while a call is up (audio mode not normal) or with no phone on Bluetooth.
#
# In Java:
#   static void start(Context c, WifiManager wm) {
#       Context app = c.getApplicationContext(); if (app == null) app = c;
#       if (!app.bindService(new Intent(BTCM), new LeafiaBtReconnect(app, wm), 1))
#           log("Leafia: Bluetooth manager not reachable, phone not reconnected");
#   }
#   public void onServiceConnected(ComponentName n, IBinder b) {
#       if (svc != null) return;
#       svc = b; new Thread(this, "LeafiaBt").start();
#   }
#   public void run() {
#       try {
#           LeafiaWifi.waitFor(wm, true, 13, 50);          // hotspot up (10 s max)
#           String a = hfp();
#           if (a == null) { log("Leafia: no phone on Bluetooth, nothing to reconnect"); return; }
#           if (((AudioManager) ctx.getSystemService("audio")).getMode() != 0) {
#               log("Leafia: call or audio session up, not reconnecting the phone"); return; }
#           log("Leafia: reconnecting the phone's Bluetooth so wireless projection restarts");
#           call(4, a);                                    // btcmDisconnect
#           for (int i = 0; i < 40 && hfp() != null; i++) LeafiaWifi.nap(200);
#           LeafiaWifi.nap(1500);
#           log(call(3, a) ? "Leafia: phone Bluetooth reconnect requested"
#                          : "Leafia: phone Bluetooth reconnect refused");   // btcmConnect
#       } catch (Throwable t) { Log.w(TAG, "Leafia: Bluetooth reconnect failed", t); }
#       finally { try { ctx.unbindService(this); } catch (Throwable t) {} }
#   }
#   String hfp()             // btcmGetHfpConnectedDevice (0x1c): address or null
#   boolean call(int, String) // btcmDisconnect (4) / btcmConnect (3): writeString, readInt

# instance fields
.field private final ctx:Landroid/content/Context;

.field private svc:Landroid/os/IBinder;

.field private final wm:Landroid/net/wifi/WifiManager;


# direct methods
.method private constructor <init>(Landroid/content/Context;Landroid/net/wifi/WifiManager;)V
    .registers 3

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->ctx:Landroid/content/Context;

    iput-object p2, p0, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->wm:Landroid/net/wifi/WifiManager;

    return-void
.end method

.method static start(Landroid/content/Context;Landroid/net/wifi/WifiManager;)V
    .registers 6

    invoke-virtual {p0}, Landroid/content/Context;->getApplicationContext()Landroid/content/Context;

    move-result-object v0

    if-nez v0, :have_ctx

    move-object v0, p0

    :have_ctx
    new-instance v1, Landroid/content/Intent;

    const-string v2, "com.broadcom.bt.hfdevice.hfbtcm.IHfDeviceBTCMService"

    invoke-direct {v1, v2}, Landroid/content/Intent;-><init>(Ljava/lang/String;)V

    new-instance v2, Lcom/hkmc/wifisettings/LeafiaBtReconnect;

    invoke-direct {v2, v0, p1}, Lcom/hkmc/wifisettings/LeafiaBtReconnect;-><init>(Landroid/content/Context;Landroid/net/wifi/WifiManager;)V

    const/4 v3, 0x1

    invoke-virtual {v0, v1, v2, v3}, Landroid/content/Context;->bindService(Landroid/content/Intent;Landroid/content/ServiceConnection;I)Z

    move-result v3

    if-nez v3, :bound

    const-string v3, "Leafia: Bluetooth manager not reachable, phone not reconnected"

    invoke-static {v3}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    :bound
    return-void
.end method


# virtual methods
.method private call(ILjava/lang/String;)Z
    .registers 8

    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;

    move-result-object v0

    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;

    move-result-object v1

    :try_start
    const-string v2, "com.broadcom.bt.hfdevice.hfbtcm.IHfDeviceBTCMService"

    invoke-virtual {v0, v2}, Landroid/os/Parcel;->writeInterfaceToken(Ljava/lang/String;)V

    invoke-virtual {v0, p2}, Landroid/os/Parcel;->writeString(Ljava/lang/String;)V

    iget-object v2, p0, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->svc:Landroid/os/IBinder;

    const/4 v3, 0x0

    invoke-interface {v2, p1, v0, v1, v3}, Landroid/os/IBinder;->transact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z

    invoke-virtual {v1}, Landroid/os/Parcel;->readException()V

    invoke-virtual {v1}, Landroid/os/Parcel;->readInt()I

    move-result v2
    :try_end
    .catchall {:try_start .. :try_end} :catchall

    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V

    invoke-virtual {v0}, Landroid/os/Parcel;->recycle()V

    if-eqz v2, :refused

    const/4 v2, 0x1

    return v2

    :refused
    const/4 v2, 0x0

    return v2

    :catchall
    move-exception v4

    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V

    invoke-virtual {v0}, Landroid/os/Parcel;->recycle()V

    throw v4
.end method

.method private hfp()Ljava/lang/String;
    .registers 7

    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;

    move-result-object v0

    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;

    move-result-object v1

    const/4 v5, 0x0

    :try_start
    const-string v2, "com.broadcom.bt.hfdevice.hfbtcm.IHfDeviceBTCMService"

    invoke-virtual {v0, v2}, Landroid/os/Parcel;->writeInterfaceToken(Ljava/lang/String;)V

    iget-object v2, p0, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->svc:Landroid/os/IBinder;

    const/16 v3, 0x1c

    const/4 v4, 0x0

    invoke-interface {v2, v3, v0, v1, v4}, Landroid/os/IBinder;->transact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z

    invoke-virtual {v1}, Landroid/os/Parcel;->readException()V

    invoke-virtual {v1}, Landroid/os/Parcel;->readInt()I

    move-result v2

    if-eqz v2, :done

    sget-object v2, Landroid/bluetooth/BluetoothDevice;->CREATOR:Landroid/os/Parcelable$Creator;

    invoke-interface {v2, v1}, Landroid/os/Parcelable$Creator;->createFromParcel(Landroid/os/Parcel;)Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Landroid/bluetooth/BluetoothDevice;

    if-eqz v2, :done

    invoke-virtual {v2}, Landroid/bluetooth/BluetoothDevice;->getAddress()Ljava/lang/String;

    move-result-object v5
    :try_end
    .catchall {:try_start .. :try_end} :catchall

    :done
    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V

    invoke-virtual {v0}, Landroid/os/Parcel;->recycle()V

    return-object v5

    :catchall
    move-exception v4

    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V

    invoke-virtual {v0}, Landroid/os/Parcel;->recycle()V

    throw v4
.end method

.method public onServiceConnected(Landroid/content/ComponentName;Landroid/os/IBinder;)V
    .registers 5

    iget-object v0, p0, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->svc:Landroid/os/IBinder;

    if-eqz v0, :first

    return-void

    :first
    iput-object p2, p0, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->svc:Landroid/os/IBinder;

    new-instance v0, Ljava/lang/Thread;

    const-string v1, "LeafiaBt"

    invoke-direct {v0, p0, v1}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;Ljava/lang/String;)V

    invoke-virtual {v0}, Ljava/lang/Thread;->start()V

    return-void
.end method

.method public onServiceDisconnected(Landroid/content/ComponentName;)V
    .registers 2

    return-void
.end method

.method public final run()V
    .registers 8

    :try_start
    iget-object v0, p0, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->wm:Landroid/net/wifi/WifiManager;

    const/4 v1, 0x1

    const/16 v2, 0xd

    const/16 v3, 0x32

    invoke-static {v0, v1, v2, v3}, Lcom/hkmc/wifisettings/LeafiaWifi;->waitFor(Landroid/net/wifi/WifiManager;ZII)Z

    invoke-direct {p0}, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->hfp()Ljava/lang/String;

    move-result-object v4

    if-nez v4, :have_phone

    const-string v1, "Leafia: no phone on Bluetooth, nothing to reconnect"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    goto :finish

    :have_phone
    iget-object v1, p0, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->ctx:Landroid/content/Context;

    const-string v2, "audio"

    invoke-virtual {v1, v2}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Landroid/media/AudioManager;

    invoke-virtual {v1}, Landroid/media/AudioManager;->getMode()I

    move-result v1

    if-eqz v1, :idle

    const-string v1, "Leafia: call or audio session up, not reconnecting the phone"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    goto :finish

    :idle
    const-string v1, "Leafia: reconnecting the phone's Bluetooth so wireless projection restarts"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    const/4 v1, 0x4

    invoke-direct {p0, v1, v4}, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->call(ILjava/lang/String;)Z

    const/4 v5, 0x0

    :wait_down
    const/16 v1, 0x28

    if-ge v5, v1, :settle

    invoke-direct {p0}, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->hfp()Ljava/lang/String;

    move-result-object v1

    if-eqz v1, :settle

    const-wide/16 v2, 0xc8

    invoke-static {v2, v3}, Lcom/hkmc/wifisettings/LeafiaWifi;->nap(J)V

    add-int/lit8 v5, v5, 0x1

    goto :wait_down

    :settle
    const-wide/16 v2, 0x5dc

    invoke-static {v2, v3}, Lcom/hkmc/wifisettings/LeafiaWifi;->nap(J)V

    const/4 v1, 0x3

    invoke-direct {p0, v1, v4}, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->call(ILjava/lang/String;)Z

    move-result v1

    if-eqz v1, :refused

    const-string v1, "Leafia: phone Bluetooth reconnect requested"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    goto :finish

    :refused
    const-string v1, "Leafia: phone Bluetooth reconnect refused"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    :finish
    :try_start2
    iget-object v1, p0, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->ctx:Landroid/content/Context;

    invoke-virtual {v1, p0}, Landroid/content/Context;->unbindService(Landroid/content/ServiceConnection;)V
    :try_end2
    .catch Ljava/lang/Throwable; {:try_start2 .. :try_end2} :catch_unbind

    :catch_unbind
    return-void

    :catch_all
    move-exception v1

    const-string v2, "LeafiaWifi"

    const-string v3, "Leafia: Bluetooth reconnect failed"

    invoke-static {v2, v3, v1}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    goto :finish
.end method
