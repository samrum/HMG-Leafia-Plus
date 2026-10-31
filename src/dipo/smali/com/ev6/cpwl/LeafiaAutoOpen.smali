.class public final Lcom/ev6/cpwl/LeafiaAutoOpen;
.super Ljava/lang/Object;
.source "LeafiaAutoOpen.java"

# Opens CarPlay when a CarPlay session starts, then shows CarPlay Home.
#   step 0, 0.5 s after the session starts: switch to CarPlay through the
#     car's ModeManager (media path: Now Playing, playback resumes).
#   step 3, 0.4 s after that switch asks the phone for Now Playing
#     (afterNowPlaying, hooked in e.b.r()): CarPlay Home.
#   step 1, 2.5 s after the switch, if Home hasn't been sent: Home if
#     CarPlay is on screen, or else switch once more.
#   step 2, 2.5 s after the retry: Home if CarPlay is on screen, then stop.
#   step 4, 0.7 s after Home: Play, so playback resumes even when Home came
#     before the phone started it.

# interfaces
.implements Ljava/lang/Runnable;


# static fields
.field private static volatile pending:Z

.field private static volatile pendingSvc:Lcom/daudio/app/dipo/service/DipoService;


# instance fields
.field private final svc:Lcom/daudio/app/dipo/service/DipoService;

.field private final step:I


# direct methods
.method private constructor <init>(Lcom/daudio/app/dipo/service/DipoService;I)V
    .registers 3

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/ev6/cpwl/LeafiaAutoOpen;->svc:Lcom/daudio/app/dipo/service/DipoService;

    iput p2, p0, Lcom/ev6/cpwl/LeafiaAutoOpen;->step:I

    return-void
.end method

.method private static post(Lcom/daudio/app/dipo/service/DipoService;IJ)V
    .registers 7

    new-instance v0, Landroid/os/Handler;

    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;

    move-result-object v1

    invoke-direct {v0, v1}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V

    new-instance v1, Lcom/ev6/cpwl/LeafiaAutoOpen;

    invoke-direct {v1, p0, p1}, Lcom/ev6/cpwl/LeafiaAutoOpen;-><init>(Lcom/daudio/app/dipo/service/DipoService;I)V

    invoke-virtual {v0, v1, p2, p3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z

    return-void
.end method

# The car's own switch to CarPlay; Home is now pending.
.method private static launch(Lcom/daudio/app/dipo/service/DipoService;Landroid/content/Context;)V
    .registers 5

    sput-object p0, Lcom/ev6/cpwl/LeafiaAutoOpen;->pendingSvc:Lcom/daudio/app/dipo/service/DipoService;

    const/4 v0, 0x1

    sput-boolean v0, Lcom/ev6/cpwl/LeafiaAutoOpen;->pending:Z

    new-instance v1, Lcom/hkmc/mode/ModeManager;

    invoke-direct {v1, p1}, Lcom/hkmc/mode/ModeManager;-><init>(Landroid/content/Context;)V

    const/16 v2, 0x73

    invoke-virtual {v1, v2, v0}, Lcom/hkmc/mode/ModeManager;->launchMode(IZ)V

    return-void
.end method

.method private static home(Lcom/daudio/app/dipo/service/DipoService;)V
    .registers 5

    const-string v0, "CarPlay_"

    const-string v1, "Leafia: auto-open CarPlay Home"

    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    sget-object v1, Lcom/daudio/app/dipo/telechips/CarPlayConsumer;->ACHome:Lcom/daudio/app/dipo/telechips/CarPlayConsumer;

    const/4 v2, 0x1

    const/4 v3, 0x0

    invoke-virtual {p0, v1, v2, v3}, Lcom/daudio/app/dipo/service/DipoService;->a(Lcom/daudio/app/dipo/telechips/CarPlayConsumer;ZI)V

    invoke-virtual {p0, v1, v3, v3}, Lcom/daudio/app/dipo/service/DipoService;->a(Lcom/daudio/app/dipo/telechips/CarPlayConsumer;ZI)V

    const/4 v1, 0x4

    const-wide/16 v2, 0x2bc

    invoke-static {p0, v1, v2, v3}, Lcom/ev6/cpwl/LeafiaAutoOpen;->post(Lcom/daudio/app/dipo/service/DipoService;IJ)V

    return-void
.end method

# Called from q.onSessionStarted: open CarPlay once the new session is up.
.method public static schedule(Lcom/daudio/app/dipo/service/DipoService;)V
    .registers 4

    if-eqz p0, :cond_done

    const/4 v0, 0x0

    const-wide/16 v1, 0x1f4

    invoke-static {p0, v0, v1, v2}, Lcom/ev6/cpwl/LeafiaAutoOpen;->post(Lcom/daudio/app/dipo/service/DipoService;IJ)V

    :cond_done
    return-void
.end method

# Called from e.b.r() right after it sends requestUI("nowplaying:").
.method public static afterNowPlaying()V
    .registers 4

    sget-boolean v0, Lcom/ev6/cpwl/LeafiaAutoOpen;->pending:Z

    if-eqz v0, :cond_done

    sget-object v0, Lcom/ev6/cpwl/LeafiaAutoOpen;->pendingSvc:Lcom/daudio/app/dipo/service/DipoService;

    if-eqz v0, :cond_done

    const/4 v1, 0x3

    const-wide/16 v2, 0x190

    invoke-static {v0, v1, v2, v3}, Lcom/ev6/cpwl/LeafiaAutoOpen;->post(Lcom/daudio/app/dipo/service/DipoService;IJ)V

    :cond_done
    return-void
.end method


# virtual methods
.method public run()V
    .registers 8

    const-string v0, "CarPlay_"

    :try_start
    iget-object v1, p0, Lcom/ev6/cpwl/LeafiaAutoOpen;->svc:Lcom/daudio/app/dipo/service/DipoService;

    iget v3, p0, Lcom/ev6/cpwl/LeafiaAutoOpen;->step:I

    const/4 v2, 0x4

    if-ne v3, v2, :cond_not_play

    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/DipoService;->er()Z

    move-result v2

    if-eqz v2, :cond_done

    const-string v2, "Leafia: auto-open resume, Play"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    sget-object v2, Lcom/daudio/app/dipo/telechips/CarPlayConsumer;->Play:Lcom/daudio/app/dipo/telechips/CarPlayConsumer;

    const/4 v4, 0x1

    const/4 v5, 0x0

    invoke-virtual {v1, v2, v4, v5}, Lcom/daudio/app/dipo/service/DipoService;->a(Lcom/daudio/app/dipo/telechips/CarPlayConsumer;ZI)V

    invoke-virtual {v1, v2, v5, v5}, Lcom/daudio/app/dipo/service/DipoService;->a(Lcom/daudio/app/dipo/telechips/CarPlayConsumer;ZI)V

    return-void

    :cond_not_play
    if-eqz v3, :cond_active_check

    # steps 1-3 only while Home is still pending
    sget-boolean v2, Lcom/ev6/cpwl/LeafiaAutoOpen;->pending:Z

    if-nez v2, :cond_active_check

    return-void

    :cond_active_check
    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/DipoService;->er()Z

    move-result v2

    if-nez v2, :cond_active

    const/4 v2, 0x0

    sput-boolean v2, Lcom/ev6/cpwl/LeafiaAutoOpen;->pending:Z

    const-string v2, "Leafia: auto-open skipped, CarPlay not active"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_active
    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/DipoService;->getApplicationContext()Landroid/content/Context;

    move-result-object v4

    invoke-static {v4}, Lcom/daudio/app/dipo/i/e;->n(Landroid/content/Context;)Z

    move-result v2

    if-nez v3, :cond_follow_up

    # step 0
    if-eqz v2, :cond_open

    const-string v2, "Leafia: auto-open skipped, CarPlay already on screen"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_open
    const-string v2, "Leafia: auto-open CarPlay"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    invoke-static {v1, v4}, Lcom/ev6/cpwl/LeafiaAutoOpen;->launch(Lcom/daudio/app/dipo/service/DipoService;Landroid/content/Context;)V

    const/4 v2, 0x1

    const-wide/16 v5, 0x9c4

    invoke-static {v1, v2, v5, v6}, Lcom/ev6/cpwl/LeafiaAutoOpen;->post(Lcom/daudio/app/dipo/service/DipoService;IJ)V

    return-void

    :cond_follow_up
    if-eqz v2, :cond_not_shown

    const/4 v2, 0x0

    sput-boolean v2, Lcom/ev6/cpwl/LeafiaAutoOpen;->pending:Z

    invoke-static {v1}, Lcom/ev6/cpwl/LeafiaAutoOpen;->home(Lcom/daudio/app/dipo/service/DipoService;)V

    return-void

    :cond_not_shown
    const/4 v2, 0x1

    if-ne v3, v2, :cond_give_up

    const-string v2, "Leafia: auto-open CarPlay not on screen, retrying"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    invoke-static {v1, v4}, Lcom/ev6/cpwl/LeafiaAutoOpen;->launch(Lcom/daudio/app/dipo/service/DipoService;Landroid/content/Context;)V

    const/4 v2, 0x2

    const-wide/16 v5, 0x9c4

    invoke-static {v1, v2, v5, v6}, Lcom/ev6/cpwl/LeafiaAutoOpen;->post(Lcom/daudio/app/dipo/service/DipoService;IJ)V

    return-void

    :cond_give_up
    const/4 v2, 0x2

    if-ne v3, v2, :cond_done

    const/4 v2, 0x0

    sput-boolean v2, Lcom/ev6/cpwl/LeafiaAutoOpen;->pending:Z

    const-string v2, "Leafia: auto-open gave up, CarPlay not on screen"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    :cond_done
    return-void

    :catch_all
    move-exception v1

    const/4 v2, 0x0

    sput-boolean v2, Lcom/ev6/cpwl/LeafiaAutoOpen;->pending:Z

    const-string v2, "Leafia: auto-open failed"

    invoke-static {v0, v2, v1}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    return-void
.end method
