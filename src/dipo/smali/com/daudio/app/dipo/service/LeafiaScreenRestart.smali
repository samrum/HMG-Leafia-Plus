.class public final Lcom/daudio/app/dipo/service/LeafiaScreenRestart;
.super Ljava/lang/Object;
.source "LeafiaScreenRestart.java"

# Leafia: restart the CarPlay video after a screen timeout.
#   When the video stream stalls, the CarPlay library reports a screen
#   timeout and stops the screen (q.onScreenTimeout, then onScreenStopped).
#   Stock DiPO only sets a flag, so the last frame stays on screen and
#   touches do nothing until the CarPlay screen is left and re-entered,
#   while audio keeps playing. Seen over wireless CarPlay on an Ioniq 5 US.
#   1 s after the timeout, if the session is still up, CarPlay is on screen
#   and the video has not come back by itself, the CarPlay SurfaceView is
#   hidden and shown again (0.5 s apart). That runs the stock
#   surfaceDestroyed/surfaceCreated path, the same as leaving the screen and
#   coming back. 3 s later the result is logged; if the video is still
#   stopped it tries again, at most 3 times per minute.
#   Every step logs "Leafia: screen ..." under CarPlay_.

# interfaces
.implements Ljava/lang/Runnable;


# static fields
.field private static handler:Landroid/os/Handler;

.field private static volatile pending:Lcom/daudio/app/dipo/service/LeafiaScreenRestart;

.field private static windowStart:J

.field private static tries:I


# instance fields
.field private final svc:Lcom/daudio/app/dipo/service/DipoService;

.field private final step:I

.field private final view:Landroid/view/View;


# direct methods
.method private constructor <init>(Lcom/daudio/app/dipo/service/DipoService;ILandroid/view/View;)V
    .registers 4

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->svc:Lcom/daudio/app/dipo/service/DipoService;

    iput p2, p0, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->step:I

    iput-object p3, p0, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->view:Landroid/view/View;

    return-void
.end method

.method private static handler()Landroid/os/Handler;
    .registers 2

    sget-object v0, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->handler:Landroid/os/Handler;

    if-nez v0, :cond_ok

    new-instance v0, Landroid/os/Handler;

    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;

    move-result-object v1

    invoke-direct {v0, v1}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V

    sput-object v0, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->handler:Landroid/os/Handler;

    :cond_ok
    return-object v0
.end method

.method private static log(Ljava/lang/String;)V
    .registers 2

    const-string v0, "CarPlay_"

    invoke-static {v0, p0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void
.end method

# Replace any pending step with this one.
.method private static post(Lcom/daudio/app/dipo/service/DipoService;ILandroid/view/View;J)V
    .registers 8

    invoke-static {}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->handler()Landroid/os/Handler;

    move-result-object v0

    sget-object v1, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->pending:Lcom/daudio/app/dipo/service/LeafiaScreenRestart;

    if-eqz v1, :cond_new

    invoke-virtual {v0, v1}, Landroid/os/Handler;->removeCallbacks(Ljava/lang/Runnable;)V

    :cond_new
    new-instance v1, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;

    invoke-direct {v1, p0, p1, p2}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;-><init>(Lcom/daudio/app/dipo/service/DipoService;ILandroid/view/View;)V

    sput-object v1, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->pending:Lcom/daudio/app/dipo/service/LeafiaScreenRestart;

    invoke-virtual {v0, v1, p3, p4}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z

    return-void
.end method

# Called from q.onScreenTimeout (CarPlay callback thread).
.method public static onTimeout(Lcom/daudio/app/dipo/service/DipoService;)V
    .registers 5

    if-nez p0, :cond_go

    return-void

    :cond_go
    # never cancel a pending "show again": the view would stay hidden
    sget-object v0, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->pending:Lcom/daudio/app/dipo/service/LeafiaScreenRestart;

    if-eqz v0, :cond_check

    iget v0, v0, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->step:I

    const/4 v1, 0x1

    if-ne v0, v1, :cond_check

    const-string v0, "Leafia: screen timeout during a restart, letting it finish"

    invoke-static {v0}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->log(Ljava/lang/String;)V

    return-void

    :cond_check
    const-string v0, "Leafia: screen timeout, CarPlay video restart check in 1 s"

    invoke-static {v0}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->log(Ljava/lang/String;)V

    const/4 v0, 0x0

    const/4 v1, 0x0

    const-wide/16 v2, 0x3e8

    invoke-static {p0, v0, v1, v2, v3}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->post(Lcom/daudio/app/dipo/service/DipoService;ILandroid/view/View;J)V

    return-void
.end method

# The SurfaceView CarPlay draws into, or null:
# svc.jV (the DipoActivity UI listener, ui.a) -> .p (DipoActivity) -> .kL
.method private static surfaceView(Lcom/daudio/app/dipo/service/DipoService;)Landroid/view/View;
    .registers 5

    :try_start
    const-class v0, Lcom/daudio/app/dipo/service/DipoService;

    const-string v1, "jV"

    invoke-virtual {v0, v1}, Ljava/lang/Class;->getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field;

    move-result-object v0

    const/4 v2, 0x1

    invoke-virtual {v0, v2}, Ljava/lang/reflect/Field;->setAccessible(Z)V

    invoke-virtual {v0, p0}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v3

    if-eqz v3, :cond_none

    invoke-virtual {v3}, Ljava/lang/Object;->getClass()Ljava/lang/Class;

    move-result-object v0

    const-string v1, "p"

    invoke-virtual {v0, v1}, Ljava/lang/Class;->getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field;

    move-result-object v0

    invoke-virtual {v0, v2}, Ljava/lang/reflect/Field;->setAccessible(Z)V

    invoke-virtual {v0, v3}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v3

    if-eqz v3, :cond_none

    const-class v0, Lcom/daudio/app/dipo/ui/DipoActivity;

    const-string v1, "kL"

    invoke-virtual {v0, v1}, Ljava/lang/Class;->getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field;

    move-result-object v0

    invoke-virtual {v0, v2}, Ljava/lang/reflect/Field;->setAccessible(Z)V

    invoke-virtual {v0, v3}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v3

    check-cast v3, Landroid/view/View;
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    return-object v3

    :catch_all
    move-exception v0

    new-instance v1, Ljava/lang/StringBuilder;

    const-string v2, "Leafia: screen restart, CarPlay view not found: "

    invoke-direct {v1, v2}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V

    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v1

    invoke-static {v1}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->log(Ljava/lang/String;)V

    :cond_none
    const/4 v0, 0x0

    return-object v0
.end method


# virtual methods
.method public final run()V
    .registers 10

    iget-object v0, p0, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->svc:Lcom/daudio/app/dipo/service/DipoService;

    iget v1, p0, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->step:I

    const/4 v2, 0x1

    if-ne v1, v2, :cond_not_show

    # step 1: show the view again (stock surfaceCreated -> setDisplay)
    iget-object v3, p0, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->view:Landroid/view/View;

    const/4 v4, 0x0

    invoke-virtual {v3, v4}, Landroid/view/View;->setVisibility(I)V

    const-string v4, "Leafia: screen restart, CarPlay view shown again"

    invoke-static {v4}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->log(Ljava/lang/String;)V

    const/4 v1, 0x2

    const/4 v3, 0x0

    const-wide/16 v4, 0xbb8

    invoke-static {v0, v1, v3, v4, v5}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->post(Lcom/daudio/app/dipo/service/DipoService;ILandroid/view/View;J)V

    return-void

    :cond_not_show
    # steps 0 (check and hide) and 2 (result, maybe try again)
    invoke-virtual {v0}, Lcom/daudio/app/dipo/service/DipoService;->er()Z

    move-result v3

    if-nez v3, :cond_session

    const-string v3, "Leafia: screen restart, CarPlay session gone, nothing to do"

    invoke-static {v3}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->log(Ljava/lang/String;)V

    return-void

    :cond_session
    # stock mCarPlayUtils.isScreenStarted (set by onScreenStarted/Stopped)
    invoke-static {v0}, Lcom/daudio/app/dipo/service/DipoService;->l(Lcom/daudio/app/dipo/service/DipoService;)Lcom/daudio/app/dipo/i/e;

    move-result-object v3

    invoke-virtual {v3}, Lcom/daudio/app/dipo/i/e;->iV()Z

    move-result v3

    if-eqz v3, :cond_stopped

    if-nez v1, :cond_restarted

    const-string v3, "Leafia: screen timeout, CarPlay video came back by itself"

    goto :goto_log_done

    :cond_restarted
    const-string v3, "Leafia: screen restart, CarPlay video is back"

    :goto_log_done
    invoke-static {v3}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->log(Ljava/lang/String;)V

    return-void

    :cond_stopped
    invoke-static {v0}, Lcom/daudio/app/dipo/i/e;->n(Landroid/content/Context;)Z

    move-result v3

    if-nez v3, :cond_on_screen

    const-string v3, "Leafia: screen restart, CarPlay not on screen; the video restarts when it opens"

    invoke-static {v3}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->log(Ljava/lang/String;)V

    return-void

    :cond_on_screen
    # at most 3 tries per minute
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J

    move-result-wide v4

    sget-wide v6, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->windowStart:J

    sub-long v6, v4, v6

    const-wide/32 v8, 0xea60

    cmp-long v3, v6, v8

    if-ltz v3, :cond_in_window

    sput-wide v4, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->windowStart:J

    const/4 v3, 0x0

    sput v3, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->tries:I

    :cond_in_window
    sget v3, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->tries:I

    const/4 v4, 0x3

    if-lt v3, v4, :cond_try

    const-string v3, "Leafia: screen restart, still no video after 3 tries this minute; giving up"

    invoke-static {v3}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->log(Ljava/lang/String;)V

    return-void

    :cond_try
    add-int/lit8 v3, v3, 0x1

    sput v3, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->tries:I

    invoke-static {v0}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->surfaceView(Lcom/daudio/app/dipo/service/DipoService;)Landroid/view/View;

    move-result-object v3

    if-eqz v3, :cond_no_view

    invoke-virtual {v3}, Landroid/view/View;->getVisibility()I

    move-result v4

    if-eqz v4, :cond_hide

    const-string v4, "Leafia: screen restart, CarPlay view is not visible; leaving it"

    invoke-static {v4}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->log(Ljava/lang/String;)V

    :cond_no_view
    return-void

    :cond_hide
    # step 0/2 -> hide (stock surfaceDestroyed -> downDisplay), show in 0.5 s
    const/4 v4, 0x4

    invoke-virtual {v3, v4}, Landroid/view/View;->setVisibility(I)V

    const-string v4, "Leafia: screen restart, CarPlay view hidden to restart the video"

    invoke-static {v4}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->log(Ljava/lang/String;)V

    const-wide/16 v4, 0x1f4

    invoke-static {v0, v2, v3, v4, v5}, Lcom/daudio/app/dipo/service/LeafiaScreenRestart;->post(Lcom/daudio/app/dipo/service/DipoService;ILandroid/view/View;J)V

    return-void
.end method
