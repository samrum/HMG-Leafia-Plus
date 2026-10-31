.class public final Lcom/daudio/app/dipo/service/LeafiaFavorite;
.super Ljava/lang/Object;
.source "LeafiaFavorite.java"

# Leafia: the Favorite key set to Phone Projection shows the CarPlay Dashboard.
# CarPlay Home toggles between the Dashboard and the app grid, but from inside
# an app it always goes to the Dashboard. So: open Now Playing, then Home.
#   step 0, 0.8 s after the press (CarPlay may still be opening): Now Playing
#   step 1, 0.6 s later: CarPlay Home
# Home needs the hid-home-back hook, or the phone ignores it.

# interfaces
.implements Ljava/lang/Runnable;


# static fields
.field private static lastAt:J


# instance fields
.field private final svc:Lcom/daudio/app/dipo/service/DipoService;

.field private final step:I


# direct methods
.method private constructor <init>(Lcom/daudio/app/dipo/service/DipoService;I)V
    .registers 3

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/daudio/app/dipo/service/LeafiaFavorite;->svc:Lcom/daudio/app/dipo/service/DipoService;

    iput p2, p0, Lcom/daudio/app/dipo/service/LeafiaFavorite;->step:I

    return-void
.end method

.method private static post(Lcom/daudio/app/dipo/service/DipoService;IJ)V
    .registers 7

    new-instance v0, Landroid/os/Handler;

    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;

    move-result-object v1

    invoke-direct {v0, v1}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V

    new-instance v1, Lcom/daudio/app/dipo/service/LeafiaFavorite;

    invoke-direct {v1, p0, p1}, Lcom/daudio/app/dipo/service/LeafiaFavorite;-><init>(Lcom/daudio/app/dipo/service/DipoService;I)V

    invoke-virtual {v0, v1, p2, p3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z

    return-void
.end method

# The Favorite press can arrive twice (the key and the shortcut broadcast);
# presses within 1.5 s count once.
.method public static start(Lcom/daudio/app/dipo/service/DipoService;)V
    .registers 8

    const-class v0, Lcom/daudio/app/dipo/service/LeafiaFavorite;

    monitor-enter v0

    :try_start
    invoke-static {}, Landroid/os/SystemClock;->uptimeMillis()J

    move-result-wide v1

    sget-wide v3, Lcom/daudio/app/dipo/service/LeafiaFavorite;->lastAt:J

    sub-long v3, v1, v3

    const-wide/16 v5, 0x5dc

    cmp-long v3, v3, v5

    if-gez v3, :cond_new

    monitor-exit v0

    return-void

    :cond_new
    sput-wide v1, Lcom/daudio/app/dipo/service/LeafiaFavorite;->lastAt:J

    const-string v1, "CarPlay_"

    const-string v2, "Leafia: favorite key, CarPlay Dashboard"

    invoke-static {v1, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    const/4 v1, 0x0

    const-wide/16 v2, 0x320

    invoke-static {p0, v1, v2, v3}, Lcom/daudio/app/dipo/service/LeafiaFavorite;->post(Lcom/daudio/app/dipo/service/DipoService;IJ)V

    monitor-exit v0
    :try_end
    .catchall {:try_start .. :try_end} :catch_all

    return-void

    :catch_all
    move-exception v1

    monitor-exit v0

    throw v1
.end method


# virtual methods
.method public run()V
    .registers 7

    const-string v0, "CarPlay_"

    :try_start
    iget-object v1, p0, Lcom/daudio/app/dipo/service/LeafiaFavorite;->svc:Lcom/daudio/app/dipo/service/DipoService;

    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/DipoService;->er()Z

    move-result v2

    if-eqz v2, :cond_done

    iget v3, p0, Lcom/daudio/app/dipo/service/LeafiaFavorite;->step:I

    if-nez v3, :cond_home

    invoke-static {v1}, Lcom/daudio/app/dipo/service/DipoService;->k(Lcom/daudio/app/dipo/service/DipoService;)Lcom/daudio/app/dipo/e/b;

    move-result-object v2

    if-eqz v2, :cond_done

    invoke-virtual {v2}, Lcom/daudio/app/dipo/e/b;->r()V

    const/4 v2, 0x1

    const-wide/16 v4, 0x258

    invoke-static {v1, v2, v4, v5}, Lcom/daudio/app/dipo/service/LeafiaFavorite;->post(Lcom/daudio/app/dipo/service/DipoService;IJ)V

    return-void

    :cond_home
    const-string v2, "Leafia: favorite key, CarPlay Home"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    sget-object v2, Lcom/daudio/app/dipo/telechips/CarPlayConsumer;->ACHome:Lcom/daudio/app/dipo/telechips/CarPlayConsumer;

    const/4 v3, 0x1

    const/4 v4, 0x0

    invoke-virtual {v1, v2, v3, v4}, Lcom/daudio/app/dipo/service/DipoService;->a(Lcom/daudio/app/dipo/telechips/CarPlayConsumer;ZI)V

    invoke-virtual {v1, v2, v4, v4}, Lcom/daudio/app/dipo/service/DipoService;->a(Lcom/daudio/app/dipo/telechips/CarPlayConsumer;ZI)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    :cond_done
    return-void

    :catch_all
    move-exception v1

    const-string v2, "Leafia: favorite key failed"

    invoke-static {v0, v2, v1}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    return-void
.end method
