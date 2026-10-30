.class public final Lcom/ev6/cpwl/LeafiaAutoOpen;
.super Ljava/lang/Object;
.source "LeafiaAutoOpen.java"

# interfaces
.implements Ljava/lang/Runnable;


# instance fields
.field private final svc:Lcom/daudio/app/dipo/service/DipoService;


# direct methods
.method private constructor <init>(Lcom/daudio/app/dipo/service/DipoService;)V
    .registers 2

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/ev6/cpwl/LeafiaAutoOpen;->svc:Lcom/daudio/app/dipo/service/DipoService;

    return-void
.end method

# Called from q.onSessionStarted: open CarPlay once the new session is up.
.method public static schedule(Lcom/daudio/app/dipo/service/DipoService;)V
    .registers 5

    if-eqz p0, :cond_done

    new-instance v0, Landroid/os/Handler;

    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;

    move-result-object v1

    invoke-direct {v0, v1}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V

    new-instance v1, Lcom/ev6/cpwl/LeafiaAutoOpen;

    invoke-direct {v1, p0}, Lcom/ev6/cpwl/LeafiaAutoOpen;-><init>(Lcom/daudio/app/dipo/service/DipoService;)V

    const-wide/16 v2, 0x5dc

    invoke-virtual {v0, v1, v2, v3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z

    :cond_done
    return-void
.end method


# virtual methods
.method public run()V
    .registers 5

    const-string v0, "CarPlay_"

    :try_start
    iget-object v1, p0, Lcom/ev6/cpwl/LeafiaAutoOpen;->svc:Lcom/daudio/app/dipo/service/DipoService;

    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/DipoService;->er()Z

    move-result v2

    if-nez v2, :cond_active

    const-string v2, "Leafia: auto-open skipped, CarPlay not active"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_active
    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/DipoService;->getApplicationContext()Landroid/content/Context;

    move-result-object v1

    invoke-static {v1}, Lcom/daudio/app/dipo/i/e;->n(Landroid/content/Context;)Z

    move-result v2

    if-eqz v2, :cond_open

    const-string v2, "Leafia: auto-open skipped, CarPlay already on screen"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_open
    const-string v2, "Leafia: auto-open CarPlay"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    new-instance v2, Lcom/hkmc/mode/ModeManager;

    invoke-direct {v2, v1}, Lcom/hkmc/mode/ModeManager;-><init>(Landroid/content/Context;)V

    const/16 v1, 0x73

    const/4 v3, 0x1

    invoke-virtual {v2, v1, v3}, Lcom/hkmc/mode/ModeManager;->launchMode(IZ)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    return-void

    :catch_all
    move-exception v1

    const-string v2, "Leafia: auto-open failed"

    invoke-static {v0, v2, v1}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    return-void
.end method
