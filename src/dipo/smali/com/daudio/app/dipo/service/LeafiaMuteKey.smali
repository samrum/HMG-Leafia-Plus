.class public final Lcom/daudio/app/dipo/service/LeafiaMuteKey;
.super Ljava/lang/Object;
.source "LeafiaMuteKey.java"

# Leafia: the steering-wheel mute key (KEYCODE_MUTE, 91) also pauses CarPlay
# audio, and unmute resumes it. Lives in this package so it can read the
# car's mute state through DipoService's package accessor B().

# interfaces
.implements Ljava/lang/Runnable;


# instance fields
.field private final svc:Lcom/daudio/app/dipo/service/DipoService;


# direct methods
.method private constructor <init>(Lcom/daudio/app/dipo/service/DipoService;)V
    .registers 2

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput-object p1, p0, Lcom/daudio/app/dipo/service/LeafiaMuteKey;->svc:Lcom/daudio/app/dipo/service/DipoService;

    return-void
.end method

# Called first thing in v.onAllKeyForService(action, flags, deviceId, keyCode, ...).
.method public static onKey(Lcom/daudio/app/dipo/service/DipoService;IIII)V
    .registers 9

    if-eqz p0, :cond_done

    const/16 v0, 0x5b

    if-ne p3, v0, :cond_done

    const/4 v0, 0x1

    if-ne p1, v0, :cond_done

    if-nez p4, :cond_done

    # skip canceled (0x20) and long-press (0x80) releases
    and-int/lit16 v0, p2, 0xa0

    if-nez v0, :cond_done

    # give the car time to apply its own mute first
    new-instance v0, Landroid/os/Handler;

    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;

    move-result-object v1

    invoke-direct {v0, v1}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V

    new-instance v1, Lcom/daudio/app/dipo/service/LeafiaMuteKey;

    invoke-direct {v1, p0}, Lcom/daudio/app/dipo/service/LeafiaMuteKey;-><init>(Lcom/daudio/app/dipo/service/DipoService;)V

    const-wide/16 v2, 0x190

    invoke-virtual {v0, v1, v2, v3}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z

    :cond_done
    return-void
.end method


# virtual methods
.method public run()V
    .registers 7

    const-string v0, "CarPlay_"

    :try_start
    iget-object v1, p0, Lcom/daudio/app/dipo/service/LeafiaMuteKey;->svc:Lcom/daudio/app/dipo/service/DipoService;

    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/DipoService;->er()Z

    move-result v2

    if-nez v2, :cond_active

    const-string v2, "Leafia: mute key, CarPlay not active"

    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_active
    invoke-virtual {v1}, Lcom/daudio/app/dipo/service/DipoService;->fM()Lcom/daudio/app/dipo/service/i;

    move-result-object v2

    if-nez v2, :cond_modes

    return-void

    :cond_modes
    # on a CarPlay call the stock code mutes the mic; leave it alone
    invoke-virtual {v2}, Lcom/daudio/app/dipo/service/i;->getPhoneCall()I

    move-result v3

    const/4 v4, 0x1

    if-ne v3, v4, :cond_nocall

    const-string v3, "Leafia: mute key, CarPlay call, no pause"

    invoke-static {v0, v3}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_nocall
    invoke-virtual {v2}, Lcom/daudio/app/dipo/service/i;->getSpeech()I

    move-result v3

    if-ne v3, v4, :cond_nospeech

    const-string v3, "Leafia: mute key, Siri active, no pause"

    invoke-static {v0, v3}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_nospeech
    # main audio owner 1 = the phone (CarPlayOwner.Controller)
    invoke-virtual {v2}, Lcom/daudio/app/dipo/service/i;->getMainAudio()I

    move-result v3

    if-eq v3, v4, :cond_ours

    const-string v3, "Leafia: mute key, CarPlay is not the audio source"

    invoke-static {v0, v3}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    return-void

    :cond_ours
    invoke-static {v1}, Lcom/daudio/app/dipo/service/DipoService;->B(Lcom/daudio/app/dipo/service/DipoService;)Lcom/hkmc/media/MicomAudioManager;

    move-result-object v2

    if-nez v2, :cond_audio

    return-void

    :cond_audio
    invoke-virtual {v2}, Lcom/hkmc/media/MicomAudioManager;->getUserMuteState()Z

    move-result v2

    if-eqz v2, :cond_play

    sget-object v3, Lcom/daudio/app/dipo/telechips/CarPlayConsumer;->Pause:Lcom/daudio/app/dipo/telechips/CarPlayConsumer;

    const-string v2, "Leafia: muted, pausing CarPlay"

    goto :goto_send

    :cond_play
    sget-object v3, Lcom/daudio/app/dipo/telechips/CarPlayConsumer;->Play:Lcom/daudio/app/dipo/telechips/CarPlayConsumer;

    const-string v2, "Leafia: unmuted, resuming CarPlay"

    :goto_send
    invoke-static {v0, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    const/4 v2, 0x0

    invoke-virtual {v1, v3, v4, v2}, Lcom/daudio/app/dipo/service/DipoService;->a(Lcom/daudio/app/dipo/telechips/CarPlayConsumer;ZI)V

    const/4 v4, 0x0

    invoke-virtual {v1, v3, v4, v2}, Lcom/daudio/app/dipo/service/DipoService;->a(Lcom/daudio/app/dipo/telechips/CarPlayConsumer;ZI)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    return-void

    :catch_all
    move-exception v1

    const-string v2, "Leafia: mute key failed"

    invoke-static {v0, v2, v1}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I

    return-void
.end method
