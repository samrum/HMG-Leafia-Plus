.class public final Lcom/daudio/app/dipo/service/LeafiaButtons;
.super Ljava/lang/Object;
.source "LeafiaButtons.java"

# Leafia: steering-wheel buttons while CarPlay is active.
#   Call (KEYCODE_CALL, 5), no call going: short press = CarPlay Back,
#     hold 600 ms = CarPlay Maps (opens CarPlay first if needed).
#     During a call, ringing, or Siri the key is left to the stock code
#     (answer / hang up).
#   Favorite set to Phone Projection: CarPlay Home, then the stock code opens
#     CarPlay as before.

# interfaces
.implements Ljava/lang/Runnable;


# static fields
.field private static volatile held:Z

.field private static volatile longDone:Z

.field private static volatile pending:Lcom/daudio/app/dipo/service/LeafiaButtons;

.field private static handler:Landroid/os/Handler;


# instance fields
.field private final svc:Lcom/daudio/app/dipo/service/DipoService;


# direct methods
.method private constructor <init>(Lcom/daudio/app/dipo/service/DipoService;)V
    .registers 2

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/daudio/app/dipo/service/LeafiaButtons;->svc:Lcom/daudio/app/dipo/service/DipoService;

    return-void
.end method

.method private static handler()Landroid/os/Handler;
    .registers 2

    sget-object v0, Lcom/daudio/app/dipo/service/LeafiaButtons;->handler:Landroid/os/Handler;

    if-nez v0, :cond_ok

    new-instance v0, Landroid/os/Handler;

    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;

    move-result-object v1

    invoke-direct {v0, v1}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V

    sput-object v0, Lcom/daudio/app/dipo/service/LeafiaButtons;->handler:Landroid/os/Handler;

    :cond_ok
    return-object v0
.end method

# true when Leafia may take the Call key: CarPlay up, no call, no Siri.
.method private static idle(Lcom/daudio/app/dipo/service/DipoService;)Z
    .registers 5

    const-string v0, "CarPlay_"

    const/4 v3, 0x1

    invoke-virtual {p0}, Lcom/daudio/app/dipo/service/DipoService;->er()Z

    move-result v1

    if-eqz v1, :cond_no

    invoke-virtual {p0}, Lcom/daudio/app/dipo/service/DipoService;->fM()Lcom/daudio/app/dipo/service/i;

    move-result-object v1

    if-eqz v1, :cond_no

    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/i;->getPhoneCall()I

    move-result v2

    if-eq v2, v3, :cond_call

    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/i;->getCallStatus()I

    move-result v2

    if-nez v2, :cond_call

    invoke-static {}, Lcom/daudio/app/dipo/i/f;->cN()Z

    move-result v2

    if-nez v2, :cond_call

    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/i;->getSpeech()I

    move-result v2

    if-ne v2, v3, :cond_idle

    const-string v2, "Leafia: call key, Siri active, stock handling"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    goto :cond_no

    :cond_idle
    return v3

    :cond_call
    const-string v2, "Leafia: call key, call in progress, stock handling"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    :cond_no
    const/4 v1, 0x0

    return v1
.end method

.method private static send(Lcom/daudio/app/dipo/service/DipoService;Lcom/daudio/app/dipo/telechips/CarPlayConsumer;)V
    .registers 4

    const/4 v0, 0x1

    const/4 v1, 0x0

    invoke-virtual {p0, p1, v0, v1}, Lcom/daudio/app/dipo/service/DipoService;->a(Lcom/daudio/app/dipo/telechips/CarPlayConsumer;ZI)V

    invoke-virtual {p0, p1, v1, v1}, Lcom/daudio/app/dipo/service/DipoService;->a(Lcom/daudio/app/dipo/telechips/CarPlayConsumer;ZI)V

    return-void
.end method

.method private static back(Lcom/daudio/app/dipo/service/DipoService;)V
    .registers 4

    const-string v0, "CarPlay_"

    invoke-virtual {p0}, Lcom/daudio/app/dipo/service/DipoService;->getApplicationContext()Landroid/content/Context;

    move-result-object v1

    invoke-static {v1}, Lcom/daudio/app/dipo/i/e;->n(Landroid/content/Context;)Z

    move-result v1

    if-nez v1, :cond_shown

    const-string v1, "Leafia: call key, CarPlay not on screen, no Back"

    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_shown
    const-string v1, "Leafia: call key, CarPlay Back"

    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    sget-object v1, Lcom/daudio/app/dipo/telechips/CarPlayConsumer;->ACBack:Lcom/daudio/app/dipo/telechips/CarPlayConsumer;

    invoke-static {p0, v1}, Lcom/daudio/app/dipo/service/LeafiaButtons;->send(Lcom/daudio/app/dipo/service/DipoService;Lcom/daudio/app/dipo/telechips/CarPlayConsumer;)V

    return-void
.end method

# Called first thing in v.onAllKeyForService(action, flags, deviceId, keyCode, ...).
# Returns true when Leafia handled the key and the stock code must skip it.
# A press is claimed on its first DOWN, and then its repeats and its UP are
# claimed too, so the stock code never sees half a press.
.method public static onCallKey(Lcom/daudio/app/dipo/service/DipoService;IIII)Z
    .registers 9

    :try_start
    if-eqz p0, :cond_no

    const/4 v0, 0x5

    if-ne p3, v0, :cond_no

    if-nez p1, :cond_up

    # repeats and the long-press DOWN belong to whoever took the first DOWN
    if-nez p4, :cond_owned

    and-int/lit16 v0, p2, 0x80

    if-nez v0, :cond_owned

    const/4 v0, 0x0

    sput-boolean v0, Lcom/daudio/app/dipo/service/LeafiaButtons;->held:Z

    invoke-static {p0}, Lcom/daudio/app/dipo/service/LeafiaButtons;->idle(Lcom/daudio/app/dipo/service/DipoService;)Z

    move-result v0

    if-eqz v0, :cond_no

    const/4 v0, 0x1

    sput-boolean v0, Lcom/daudio/app/dipo/service/LeafiaButtons;->held:Z

    const/4 v0, 0x0

    sput-boolean v0, Lcom/daudio/app/dipo/service/LeafiaButtons;->longDone:Z

    new-instance v0, Lcom/daudio/app/dipo/service/LeafiaButtons;

    invoke-direct {v0, p0}, Lcom/daudio/app/dipo/service/LeafiaButtons;-><init>(Lcom/daudio/app/dipo/service/DipoService;)V

    sput-object v0, Lcom/daudio/app/dipo/service/LeafiaButtons;->pending:Lcom/daudio/app/dipo/service/LeafiaButtons;

    invoke-static {}, Lcom/daudio/app/dipo/service/LeafiaButtons;->handler()Landroid/os/Handler;

    move-result-object v1

    const-wide/16 v2, 0x258

    invoke-virtual {v1, v0, v2, v3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z

    const/4 v0, 0x1

    return v0

    :cond_owned
    sget-boolean v0, Lcom/daudio/app/dipo/service/LeafiaButtons;->held:Z

    return v0

    :cond_up
    const/4 v0, 0x1

    if-ne p1, v0, :cond_owned

    sget-boolean v0, Lcom/daudio/app/dipo/service/LeafiaButtons;->held:Z

    if-eqz v0, :cond_no

    const/4 v0, 0x0

    sput-boolean v0, Lcom/daudio/app/dipo/service/LeafiaButtons;->held:Z

    invoke-static {}, Lcom/daudio/app/dipo/service/LeafiaButtons;->handler()Landroid/os/Handler;

    move-result-object v1

    sget-object v2, Lcom/daudio/app/dipo/service/LeafiaButtons;->pending:Lcom/daudio/app/dipo/service/LeafiaButtons;

    if-eqz v2, :cond_removed

    invoke-virtual {v1, v2}, Landroid/os/Handler;->removeCallbacks(Ljava/lang/Runnable;)V

    :cond_removed
    sget-boolean v0, Lcom/daudio/app/dipo/service/LeafiaButtons;->longDone:Z

    if-nez v0, :cond_yes

    # canceled press
    and-int/lit8 v0, p2, 0x20

    if-nez v0, :cond_yes

    invoke-static {p0}, Lcom/daudio/app/dipo/service/LeafiaButtons;->back(Lcom/daudio/app/dipo/service/DipoService;)V

    :cond_yes
    const/4 v0, 0x1

    return v0
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    :cond_no
    const/4 v0, 0x0

    return v0

    :catch_all
    move-exception v0

    const-string v1, "CarPlay_"

    const-string v2, "Leafia: call key failed"

    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    const/4 v0, 0x0

    return v0
.end method

# Called from w.onReceive on ACTION_SHORTCUT_DIPO_CUSTOM (Favorite set to Phone
# Projection), after the stock checks and before it opens CarPlay.
.method public static onFavorite(Lcom/daudio/app/dipo/service/DipoService;)V
    .registers 4

    const-string v0, "CarPlay_"

    :try_start
    const-string v1, "Leafia: favorite key, CarPlay Home"

    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    sget-object v1, Lcom/daudio/app/dipo/telechips/CarPlayConsumer;->ACHome:Lcom/daudio/app/dipo/telechips/CarPlayConsumer;

    invoke-static {p0, v1}, Lcom/daudio/app/dipo/service/LeafiaButtons;->send(Lcom/daudio/app/dipo/service/DipoService;Lcom/daudio/app/dipo/telechips/CarPlayConsumer;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    return-void

    :catch_all
    move-exception v1

    const-string v2, "Leafia: favorite key failed"

    invoke-static {v0, v2, v1}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    return-void
.end method


# virtual methods
# The Call key has been held 600 ms: CarPlay Maps.
.method public run()V
    .registers 5

    const-string v0, "CarPlay_"

    :try_start
    sget-boolean v1, Lcom/daudio/app/dipo/service/LeafiaButtons;->held:Z

    if-eqz v1, :cond_done

    sget-object v1, Lcom/daudio/app/dipo/service/LeafiaButtons;->pending:Lcom/daudio/app/dipo/service/LeafiaButtons;

    if-ne v1, p0, :cond_done

    const/4 v1, 0x1

    sput-boolean v1, Lcom/daudio/app/dipo/service/LeafiaButtons;->longDone:Z

    iget-object v1, p0, Lcom/daudio/app/dipo/service/LeafiaButtons;->svc:Lcom/daudio/app/dipo/service/DipoService;

    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/DipoService;->getApplicationContext()Landroid/content/Context;

    move-result-object v2

    invoke-static {v2}, Lcom/daudio/app/dipo/i/e;->n(Landroid/content/Context;)Z

    move-result v2

    if-eqz v2, :cond_open

    const-string v2, "Leafia: call key held, CarPlay Maps"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/DipoService;->p()V

    goto :cond_done

    :cond_open
    const-string v2, "Leafia: call key held, opening CarPlay Maps"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    # DipoActivity mode 1 = map (DipoService.c(1, ...) -> displayMap)
    const/4 v2, 0x1

    invoke-virtual {v1, v2}, Lcom/daudio/app/dipo/service/DipoService;->Z(I)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    :cond_done
    return-void

    :catch_all
    move-exception v1

    const-string v2, "Leafia: call key Maps failed"

    invoke-static {v0, v2, v1}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    return-void
.end method
