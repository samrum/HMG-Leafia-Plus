.class public final Lcom/hkmc/wifisettings/LeafiaWifi;
.super Ljava/lang/Object;
.source "LeafiaWifi.java"

# interfaces
.implements Ljava/lang/Runnable;

# HMG Leafia Plus: the Wi-Fi client switch and the phone projection hotspot.
# The unit's one radio runs either the hotspot that wireless CarPlay/Android Auto
# use (WifiManager AP mode 2, "Connectivity") or the Wi-Fi client, never both.
#
# toggle(): runs the Wi-Fi client switch on its own thread (replaces the stock
#   handler in WifiClientModeEnabler, class ac).
#   on:  stop the hotspot, wait until it reports stopped (state 11) plus 1.5 s,
#        then start the client. Stock started the client in the same instant,
#        which failed 6 times ("Failed to setup control channel") and ended in
#        "Error" with Wi-Fi and the hotspot both dead until a restart. If it still
#        ends in "Error", turn the client off and bring the hotspot back.
#   off: stop the client, wait until it reports off, then bring the projection
#        hotspot back (stock left it off until the phone's next Bluetooth connection)
#        and reconnect the phone's Bluetooth (LeafiaBtReconnect): wireless CarPlay/AA
#        only hand the phone the hotspot when it connects over Bluetooth, and by then
#        it has long been back on Bluetooth.
# stopApOnOpen(): stock WifiClientSettings.onResume stopped any running hotspot;
#   this keeps the phone projection one, so just opening the screen doesn't drop CarPlay.
#
# In Java:
#   public static void toggle(WifiManager wm, Preference p, boolean on) {
#       p.setEnabled(false);   // stock did this too; the Wi-Fi state receiver re-enables it
#       new Thread(new LeafiaWifi(wm, p.getContext(), on), "LeafiaWifi").start();
#   }
#   public static boolean stopApOnOpen(WifiManager wm) {
#       if (wm.getWifiApMode() != 2) return true;
#       Log.i(TAG, "Leafia: Wi-Fi screen opened, keeping the phone projection hotspot");
#       return false;
#   }
#   public void run() {
#       try {
#           if (on) {
#               int ap = wm.getWifiApState();
#               if (ap == 12 || ap == 13) {
#                   Log.i(TAG, "Leafia: stopping the hotspot before starting Wi-Fi");
#                   wm.setWifiApEnabled(null, false);
#                   if (!waitFor(wm, true, 11, 50)) Log.w(TAG, "Leafia: hotspot not stopped after 10 s");
#                   nap(1500);
#               }
#               Log.i(TAG, "Leafia: starting Wi-Fi");
#               wm.setWifiEnabled(true);
#               for (int i = 0; i < 450; i++) {        // 90 s
#                   int s = wm.getWifiState();
#                   if (s == 3) { Log.i(TAG, "Leafia: Wi-Fi on"); return; }
#                   if (s == 4) break;
#                   nap(200);
#               }
#               if (wm.getWifiState() != 4) return;
#               Log.w(TAG, "Leafia: Wi-Fi failed (Error); turning it off and bringing the hotspot back");
#           }
#           wm.setWifiEnabled(false);
#           waitFor(wm, false, 1, 50);
#           nap(500);
#           restoreAp();
#       } catch (Throwable t) { Log.w(TAG, "Leafia: Wi-Fi switch failed", t); }
#   }
#   void restoreAp() {
#       if (wm.isWifiApEnabled()) return;
#       PackageManager pm = ctx.getPackageManager();
#       if (!pm.hasSystemFeature(CARPLAY_WIRELESS) && !pm.hasSystemFeature(AA_WIRELESS)) return;
#       Log.i(TAG, "Leafia: bringing the phone projection hotspot back");
#       wm.setWifiApEnabledForConnectivity(wm.getWifiApConfiguration(), true);
#       LeafiaBtReconnect.start(ctx, wm);   // the phone only rejoins after a Bluetooth reconnect
#   }

# instance fields
.field private final ctx:Landroid/content/Context;

.field private final on:Z

.field private final wm:Landroid/net/wifi/WifiManager;


# direct methods
.method private constructor <init>(Landroid/net/wifi/WifiManager;Landroid/content/Context;Z)V
    .registers 4

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/hkmc/wifisettings/LeafiaWifi;->wm:Landroid/net/wifi/WifiManager;

    iput-object p2, p0, Lcom/hkmc/wifisettings/LeafiaWifi;->ctx:Landroid/content/Context;

    iput-boolean p3, p0, Lcom/hkmc/wifisettings/LeafiaWifi;->on:Z

    return-void
.end method

.method static log(Ljava/lang/String;)V
    .registers 2

    const-string v0, "LeafiaWifi"

    invoke-static {v0, p0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void
.end method

.method static nap(J)V
    .registers 2

    :try_start_0
    invoke-static {p0, p1}, Ljava/lang/Thread;->sleep(J)V
    :try_end_3
    .catch Ljava/lang/InterruptedException; {:try_start_0 .. :try_end_3} :catch_4

    :catch_4
    return-void
.end method

# waitFor(wm, ap, want, tries): poll the hotspot state (ap) or the Wi-Fi state
# every 200 ms until it is <want>; false after <tries> polls
.method static waitFor(Landroid/net/wifi/WifiManager;ZII)Z
    .registers 8

    const/4 v0, 0x0

    :loop
    if-ge v0, p3, :timeout

    if-eqz p1, :wifi

    invoke-virtual {p0}, Landroid/net/wifi/WifiManager;->getWifiApState()I

    move-result v1

    goto :check

    :wifi
    invoke-virtual {p0}, Landroid/net/wifi/WifiManager;->getWifiState()I

    move-result v1

    :check
    if-ne v1, p2, :next

    const/4 v0, 0x1

    return v0

    :next
    const-wide/16 v2, 0xc8

    invoke-static {v2, v3}, Lcom/hkmc/wifisettings/LeafiaWifi;->nap(J)V

    add-int/lit8 v0, v0, 0x1

    goto :loop

    :timeout
    const/4 v0, 0x0

    return v0
.end method

.method public static stopApOnOpen(Landroid/net/wifi/WifiManager;)Z
    .registers 3

    invoke-virtual {p0}, Landroid/net/wifi/WifiManager;->getWifiApMode()I

    move-result v0

    const/4 v1, 0x2

    if-eq v0, v1, :keep

    const/4 v0, 0x1

    return v0

    :keep
    const-string v0, "Leafia: Wi-Fi screen opened, keeping the phone projection hotspot"

    invoke-static {v0}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    const/4 v0, 0x0

    return v0
.end method

.method public static toggle(Landroid/net/wifi/WifiManager;Landroid/preference/Preference;Z)V
    .registers 6

    const/4 v0, 0x0

    invoke-virtual {p1, v0}, Landroid/preference/Preference;->setEnabled(Z)V

    invoke-virtual {p1}, Landroid/preference/Preference;->getContext()Landroid/content/Context;

    move-result-object v0

    new-instance v1, Ljava/lang/Thread;

    new-instance v2, Lcom/hkmc/wifisettings/LeafiaWifi;

    invoke-direct {v2, p0, v0, p2}, Lcom/hkmc/wifisettings/LeafiaWifi;-><init>(Landroid/net/wifi/WifiManager;Landroid/content/Context;Z)V

    const-string v0, "LeafiaWifi"

    invoke-direct {v1, v2, v0}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;Ljava/lang/String;)V

    invoke-virtual {v1}, Ljava/lang/Thread;->start()V

    return-void
.end method


# virtual methods
.method private restoreAp()V
    .registers 5

    iget-object v0, p0, Lcom/hkmc/wifisettings/LeafiaWifi;->wm:Landroid/net/wifi/WifiManager;

    invoke-virtual {v0}, Landroid/net/wifi/WifiManager;->isWifiApEnabled()Z

    move-result v1

    if-eqz v1, :check_feature

    return-void

    :check_feature
    iget-object v1, p0, Lcom/hkmc/wifisettings/LeafiaWifi;->ctx:Landroid/content/Context;

    invoke-virtual {v1}, Landroid/content/Context;->getPackageManager()Landroid/content/pm/PackageManager;

    move-result-object v1

    const-string v2, "com.hkmc.software.connectivity.carplay_wireless"

    invoke-virtual {v1, v2}, Landroid/content/pm/PackageManager;->hasSystemFeature(Ljava/lang/String;)Z

    move-result v2

    if-nez v2, :start

    const-string v2, "com.hkmc.software.connectivity.androidauto_wireless"

    invoke-virtual {v1, v2}, Landroid/content/pm/PackageManager;->hasSystemFeature(Ljava/lang/String;)Z

    move-result v2

    if-nez v2, :start

    const-string v1, "Leafia: wireless projection is off, leaving the hotspot off"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    return-void

    :start
    const-string v1, "Leafia: bringing the phone projection hotspot back"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    invoke-virtual {v0}, Landroid/net/wifi/WifiManager;->getWifiApConfiguration()Landroid/net/wifi/WifiConfiguration;

    move-result-object v1

    const/4 v2, 0x1

    invoke-virtual {v0, v1, v2}, Landroid/net/wifi/WifiManager;->setWifiApEnabledForConnectivity(Landroid/net/wifi/WifiConfiguration;Z)Z

    iget-object v1, p0, Lcom/hkmc/wifisettings/LeafiaWifi;->ctx:Landroid/content/Context;

    invoke-static {v1, v0}, Lcom/hkmc/wifisettings/LeafiaBtReconnect;->start(Landroid/content/Context;Landroid/net/wifi/WifiManager;)V

    return-void
.end method

.method public final run()V
    .registers 8

    const/4 v6, 0x0

    const/4 v5, 0x1

    iget-object v0, p0, Lcom/hkmc/wifisettings/LeafiaWifi;->wm:Landroid/net/wifi/WifiManager;

    :try_start
    iget-boolean v1, p0, Lcom/hkmc/wifisettings/LeafiaWifi;->on:Z

    if-eqz v1, :turn_off

    invoke-virtual {v0}, Landroid/net/wifi/WifiManager;->getWifiApState()I

    move-result v1

    const/16 v2, 0xc

    if-eq v1, v2, :stop_ap

    const/16 v2, 0xd

    if-ne v1, v2, :start_client

    :stop_ap
    const-string v1, "Leafia: stopping the hotspot before starting Wi-Fi"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    const/4 v1, 0x0

    invoke-virtual {v0, v1, v6}, Landroid/net/wifi/WifiManager;->setWifiApEnabled(Landroid/net/wifi/WifiConfiguration;Z)Z

    const/16 v1, 0xb

    const/16 v2, 0x32

    invoke-static {v0, v5, v1, v2}, Lcom/hkmc/wifisettings/LeafiaWifi;->waitFor(Landroid/net/wifi/WifiManager;ZII)Z

    move-result v1

    if-nez v1, :settle

    const-string v1, "Leafia: hotspot not reported stopped after 10 s"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    :settle
    const-wide/16 v2, 0x5dc

    invoke-static {v2, v3}, Lcom/hkmc/wifisettings/LeafiaWifi;->nap(J)V

    :start_client
    const-string v1, "Leafia: starting Wi-Fi"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    invoke-virtual {v0, v5}, Landroid/net/wifi/WifiManager;->setWifiEnabled(Z)Z

    const/4 v4, 0x0

    :watch
    const/16 v1, 0x1c2

    if-ge v4, v1, :watched

    invoke-virtual {v0}, Landroid/net/wifi/WifiManager;->getWifiState()I

    move-result v1

    const/4 v2, 0x3

    if-ne v1, v2, :not_on

    const-string v1, "Leafia: Wi-Fi on"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    return-void

    :not_on
    const/4 v2, 0x4

    if-eq v1, v2, :watched

    const-wide/16 v2, 0xc8

    invoke-static {v2, v3}, Lcom/hkmc/wifisettings/LeafiaWifi;->nap(J)V

    add-int/lit8 v4, v4, 0x1

    goto :watch

    :watched
    invoke-virtual {v0}, Landroid/net/wifi/WifiManager;->getWifiState()I

    move-result v1

    const/4 v2, 0x4

    if-eq v1, v2, :failed

    return-void

    :failed
    const-string v1, "Leafia: Wi-Fi failed (Error); turning it off and bringing the hotspot back"

    invoke-static {v1}, Lcom/hkmc/wifisettings/LeafiaWifi;->log(Ljava/lang/String;)V

    :turn_off
    invoke-virtual {v0, v6}, Landroid/net/wifi/WifiManager;->setWifiEnabled(Z)Z

    const/4 v1, 0x1

    const/16 v2, 0x32

    invoke-static {v0, v6, v1, v2}, Lcom/hkmc/wifisettings/LeafiaWifi;->waitFor(Landroid/net/wifi/WifiManager;ZII)Z

    const-wide/16 v2, 0x1f4

    invoke-static {v2, v3}, Lcom/hkmc/wifisettings/LeafiaWifi;->nap(J)V

    invoke-direct {p0}, Lcom/hkmc/wifisettings/LeafiaWifi;->restoreAp()V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    return-void

    :catch_all
    move-exception v1

    const-string v2, "LeafiaWifi"

    const-string v3, "Leafia: Wi-Fi switch failed"

    invoke-static {v2, v3, v1}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    return-void
.end method
