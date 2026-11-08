# Leafia EV: live battery and range for CarPlay (Apple Maps EV routing).
#
# Read-only: asks the car's own HEV service (com.hkmc.micom.hev,
# IHEVService.getHEVStatus, transaction 3) for
#   0x19 DISPLAY_SOC   cluster battery %, 0.5 % steps
#   0x31 ENERGYMAP     remaining usable energy, 2 Wh steps (0xffff = invalid)
#   0x09 ELECTRIC_DTE  cluster range, in the cluster's unit (miles on US cars)
# (signal meanings: willemcvu/egmp-aa-ev-feat docs/DATA-SOURCES.md)
# and, while the iPhone has vehicle status updates on, sends them through the
# stock Iap2SendVehicleStatus JNI call. The EV build of libiap2session.so
# (src/iap2/evnative) stores them and sends the VehicleStatusUpdate.
#
# Sent: 21 MinBatteryCharge 0 Wh, 22 CurrentBatteryCharge, 23 MaxBatteryCharge
# (usable capacity, learned from energy / SOC at 50 % or more), 24
# DisplayedBatteryPercentage (% x 1000); with a range: 3 Range and 11
# RangeElectric (km), 6/15 range warnings (at 20 % or less), 30
# MaxRangeElectric (range scaled to 100 %, from 20 % up).
# Checked every 30 s (each check logged), sent when a reading changed or
# every 5 min.
#
# Hooks (src/iap2/hooks.py): Iap2Service.onCreate -> start(this),
# Iap2HandleNoti.sendEventToNotiHandler -> onNoti(what).
.class public final Lcom/tcc/iap2server/LeafiaEv;
.super Ljava/lang/Object;
.implements Ljava/lang/Runnable;

.field static sSvc:Lcom/tcc/iap2server/Iap2Service;
.field static volatile sStarted:Z
.field static sThread:Ljava/lang/Thread;
.field static sCapWh:I
.field static sLast:Ljava/lang/String;
.field static sLastSent:J

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

.method public static start(Lcom/tcc/iap2server/Iap2Service;)V
    .registers 4
    :try_start
    sget-object v0, Lcom/tcc/iap2server/LeafiaEv;->sThread:Ljava/lang/Thread;
    if-nez v0, :done
    sput-object p0, Lcom/tcc/iap2server/LeafiaEv;->sSvc:Lcom/tcc/iap2server/Iap2Service;
    new-instance v0, Ljava/lang/Thread;
    new-instance v1, Lcom/tcc/iap2server/LeafiaEv;
    invoke-direct {v1}, Lcom/tcc/iap2server/LeafiaEv;-><init>()V
    const-string v2, "LeafiaEv"
    invoke-direct {v0, v1, v2}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;Ljava/lang/String;)V
    const/4 v1, 0x1
    invoke-virtual {v0, v1}, Ljava/lang/Thread;->setDaemon(Z)V
    sput-object v0, Lcom/tcc/iap2server/LeafiaEv;->sThread:Ljava/lang/Thread;
    invoke-virtual {v0}, Ljava/lang/Thread;->start()V
    const-string v1, "LeafiaEv"
    const-string v2, "battery and range reader started"
    invoke-static {v1, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    :try_end
    .catchall {:try_start .. :try_end} :failed
    :done
    return-void
    :failed
    move-exception v0
    const-string v1, "LeafiaEv"
    const-string v2, "start failed"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void
.end method

# every iAP2 notification passes here; 0xf vehicleStatusStart, 0x10 vehicleStatusStop
.method public static onNoti(I)V
    .registers 3
    const/16 v0, 0xf
    if-ne p0, v0, :not_start
    const/4 v0, 0x1
    sput-boolean v0, Lcom/tcc/iap2server/LeafiaEv;->sStarted:Z
    const/4 v0, 0x0
    sput-object v0, Lcom/tcc/iap2server/LeafiaEv;->sLast:Ljava/lang/String;
    const-string v0, "LeafiaEv"
    const-string v1, "phone started vehicle status updates"
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    sget-object v0, Lcom/tcc/iap2server/LeafiaEv;->sThread:Ljava/lang/Thread;
    if-eqz v0, :ret
    invoke-virtual {v0}, Ljava/lang/Thread;->interrupt()V
    :ret
    return-void
    :not_start
    const/16 v0, 0x10
    if-ne p0, v0, :ret
    const/4 v0, 0x0
    sput-boolean v0, Lcom/tcc/iap2server/LeafiaEv;->sStarted:Z
    const-string v0, "LeafiaEv"
    const-string v1, "phone stopped vehicle status updates"
    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void
.end method

.method public run()V
    .registers 5
    :loop
    :try_start_sleep
    const-wide/16 v0, 0x7530
    invoke-static {v0, v1}, Ljava/lang/Thread;->sleep(J)V
    :try_end_sleep
    .catch Ljava/lang/InterruptedException; {:try_start_sleep .. :try_end_sleep} :woken
    :check
    sget-boolean v0, Lcom/tcc/iap2server/LeafiaEv;->sStarted:Z
    if-eqz v0, :loop
    :try_start_tick
    invoke-static {}, Lcom/tcc/iap2server/LeafiaEv;->tick()V
    :try_end_tick
    .catchall {:try_start_tick .. :try_end_tick} :tick_failed
    goto :loop
    # started: give the phone a second, then send right away
    :woken
    move-exception v0
    :try_start_settle
    const-wide/16 v0, 0x3e8
    invoke-static {v0, v1}, Ljava/lang/Thread;->sleep(J)V
    :try_end_settle
    .catch Ljava/lang/InterruptedException; {:try_start_settle .. :try_end_settle} :woken_again
    goto :check
    :woken_again
    move-exception v0
    goto :check
    :tick_failed
    move-exception v0
    const-string v1, "LeafiaEv"
    const-string v2, "reading battery and range failed"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    goto :loop
.end method

# IHEVService.getHEVStatus(flag): -1 when the service is missing
.method static hev(I)I
    .registers 7
    const-string v0, "com.hkmc.micom.hev"
    invoke-static {v0}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;
    move-result-object v0
    if-nez v0, :have
    const/4 v0, -0x1
    return v0
    :have
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v1
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v2
    :try_start
    const-string v3, "com.hkmc.hev.IHEVService"
    invoke-virtual {v1, v3}, Landroid/os/Parcel;->writeInterfaceToken(Ljava/lang/String;)V
    invoke-virtual {v1, p0}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v3, 0x3
    const/4 v4, 0x0
    invoke-interface {v0, v3, v1, v2, v4}, Landroid/os/IBinder;->transact(ILandroid/os/Parcel;Landroid/os/Parcel;I)Z
    invoke-virtual {v2}, Landroid/os/Parcel;->readException()V
    invoke-virtual {v2}, Landroid/os/Parcel;->readInt()I
    move-result v3
    :try_end
    .catchall {:try_start .. :try_end} :failed
    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V
    invoke-virtual {v2}, Landroid/os/Parcel;->recycle()V
    return v3
    :failed
    move-exception v3
    invoke-virtual {v1}, Landroid/os/Parcel;->recycle()V
    invoke-virtual {v2}, Landroid/os/Parcel;->recycle()V
    throw v3
.end method

# one parcel item as iAP2Parcel2NativeMsg reads it: id, type, count 1, value
.method static item(Landroid/os/Parcel;III)V
    .registers 5
    invoke-virtual {p0, p1}, Landroid/os/Parcel;->writeInt(I)V
    invoke-virtual {p0, p2}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v0, 0x1
    invoke-virtual {p0, v0}, Landroid/os/Parcel;->writeInt(I)V
    invoke-virtual {p0, p3}, Landroid/os/Parcel;->writeInt(I)V
    return-void
.end method

# what Iap2Service$2.Iap2SvcSendVehicleStatusData does, with our parcel
.method static send(Landroid/os/Parcel;)Z
    .registers 8
    sget-object v0, Lcom/tcc/iap2server/LeafiaEv;->sSvc:Lcom/tcc/iap2server/Iap2Service;
    if-eqz v0, :no
    invoke-virtual {v0}, Lcom/tcc/iap2server/Iap2Service;->IsValidSvcState()Z
    move-result v1
    if-eqz v1, :no
    invoke-static {}, Lcom/tcc/iap2server/Iap2InitInformationMsg;->getInstance()Lcom/tcc/iap2server/Iap2InitInformationMsg;
    move-result-object v1
    invoke-virtual {v1}, Lcom/tcc/iap2server/Iap2InitInformationMsg;->GetSupportVehicleStatus()Z
    move-result v1
    if-eqz v1, :no
    const/4 v6, 0x0
    invoke-static {}, Lcom/tcc/iap2server/Iap2Service;->access$200()Ljava/lang/Object;
    move-result-object v1
    monitor-enter v1
    :try_start
    invoke-static {}, Lcom/tcc/iap2server/Iap2Service;->access$300()J
    move-result-wide v2
    const-wide/16 v4, 0x0
    cmp-long v4, v2, v4
    if-eqz v4, :unlock
    invoke-static {v0, v2, v3, p0}, Lcom/tcc/iap2server/Iap2Service;->access$2800(Lcom/tcc/iap2server/Iap2Service;JLandroid/os/Parcel;)Z
    move-result v6
    :unlock
    monitor-exit v1
    :try_end
    .catchall {:try_start .. :try_end} :failed
    return v6
    :failed
    move-exception v2
    monitor-exit v1
    throw v2
    :no
    const/4 v0, 0x0
    return v0
.end method

.method static tick()V
    .registers 20
    # v0 soc (0.5 %), v1 energy (2 Wh), v2 range (cluster unit), v3 Wh now,
    # v4 estimate / parcel, v5 capacity Wh, v6 km, v7 km at 100 %, v8 warning,
    # v9 % x 1000, v10 reading key, v11-v13 temp, v16/v17 now
    const/16 v11, 0x19
    invoke-static {v11}, Lcom/tcc/iap2server/LeafiaEv;->hev(I)I
    move-result v0
    const/16 v11, 0x31
    invoke-static {v11}, Lcom/tcc/iap2server/LeafiaEv;->hev(I)I
    move-result v1
    const/16 v11, 0x9
    invoke-static {v11}, Lcom/tcc/iap2server/LeafiaEv;->hev(I)I
    move-result v2
    if-lez v0, :invalid
    const/16 v11, 0xc8
    if-gt v0, v11, :invalid
    if-lez v1, :invalid
    mul-int/lit16 v9, v0, 0x1f4
    mul-int/lit8 v3, v1, 0x2
    const v11, 0x13880
    if-gt v3, v11, :invalid

    # estimate = Wh now / SOC, from 20 % up
    const/4 v4, 0x0
    const/16 v11, 0x28
    if-lt v0, v11, :have_estimate
    mul-int/lit16 v4, v3, 0xc8
    div-int/2addr v4, v0
    :have_estimate
    sget v5, Lcom/tcc/iap2server/LeafiaEv;->sCapWh:I
    const/16 v11, 0x64
    if-lt v0, v11, :not_learning
    if-eqz v5, :first
    mul-int/lit8 v5, v5, 0x3
    add-int/2addr v5, v4
    div-int/lit8 v5, v5, 0x4
    goto :clamp
    :first
    move v5, v4
    goto :clamp
    :not_learning
    if-nez v5, :clamp
    move v5, v4
    if-nez v5, :clamp
    const v5, 0x12e58
    :clamp
    const v11, 0x9c40
    if-ge v5, v11, :not_low
    move v5, v11
    :not_low
    const v11, 0x12e58
    if-le v5, v11, :not_high
    move v5, v11
    :not_high
    if-ge v5, v3, :not_below_now
    move v5, v3
    :not_below_now
    const/16 v11, 0x64
    if-lt v0, v11, :range
    sput v5, Lcom/tcc/iap2server/LeafiaEv;->sCapWh:I

    # range: miles -> km
    :range
    const/4 v6, 0x0
    if-lez v2, :no_km
    const/16 v11, 0x3e8
    if-ge v2, v11, :no_km
    mul-int/lit16 v6, v2, 0x649
    div-int/lit16 v6, v6, 0x3e8
    :no_km
    const/4 v7, 0x0
    if-lez v6, :no_full
    const/16 v11, 0x28
    if-lt v0, v11, :no_full
    mul-int/lit16 v7, v6, 0xc8
    div-int/2addr v7, v0
    if-lt v7, v6, :bad_full
    const/16 v11, 0x2bc
    if-le v7, v11, :no_full
    :bad_full
    const/4 v7, 0x0
    :no_full
    const/4 v8, 0x0
    const/16 v11, 0x4e20
    if-gt v9, v11, :no_warning
    const/4 v8, 0x1
    :no_warning

    # send when a reading changed, or every 5 minutes
    new-instance v11, Ljava/lang/StringBuilder;
    invoke-direct {v11}, Ljava/lang/StringBuilder;-><init>()V
    invoke-virtual {v11, v0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v12, "/"
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v2}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v11}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v10
    invoke-static {}, Landroid/os/SystemClock;->elapsedRealtime()J
    move-result-wide v16
    sget-object v11, Lcom/tcc/iap2server/LeafiaEv;->sLast:Ljava/lang/String;
    invoke-virtual {v10, v11}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v11
    if-eqz v11, :send
    sget-wide v18, Lcom/tcc/iap2server/LeafiaEv;->sLastSent:J
    sub-long v18, v16, v18
    const-wide/32 v12, 0x493e0
    cmp-long v11, v18, v12
    if-gez v11, :send
    const-string v12, "unchanged, not sent: soc/energy/range raw "
    invoke-virtual {v12, v10}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v11
    const-string v12, "LeafiaEv"
    invoke-static {v12, v11}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void

    :send
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v4
    const/4 v11, 0x4
    if-lez v6, :count_full
    add-int/lit8 v11, v11, 0x4
    :count_full
    if-lez v7, :counted
    add-int/lit8 v11, v11, 0x1
    :counted
    invoke-virtual {v4, v11}, Landroid/os/Parcel;->writeInt(I)V
    const/4 v12, 0x6
    const/16 v11, 0x15
    const/4 v13, 0x0
    invoke-static {v4, v11, v12, v13}, Lcom/tcc/iap2server/LeafiaEv;->item(Landroid/os/Parcel;III)V
    const/16 v11, 0x16
    invoke-static {v4, v11, v12, v3}, Lcom/tcc/iap2server/LeafiaEv;->item(Landroid/os/Parcel;III)V
    const/16 v11, 0x17
    invoke-static {v4, v11, v12, v5}, Lcom/tcc/iap2server/LeafiaEv;->item(Landroid/os/Parcel;III)V
    const/16 v11, 0x18
    invoke-static {v4, v11, v12, v9}, Lcom/tcc/iap2server/LeafiaEv;->item(Landroid/os/Parcel;III)V
    if-lez v6, :items_full
    const/4 v12, 0x5
    const/4 v11, 0x3
    invoke-static {v4, v11, v12, v6}, Lcom/tcc/iap2server/LeafiaEv;->item(Landroid/os/Parcel;III)V
    const/16 v11, 0xb
    invoke-static {v4, v11, v12, v6}, Lcom/tcc/iap2server/LeafiaEv;->item(Landroid/os/Parcel;III)V
    const/16 v12, 0x9
    const/4 v11, 0x6
    invoke-static {v4, v11, v12, v8}, Lcom/tcc/iap2server/LeafiaEv;->item(Landroid/os/Parcel;III)V
    const/16 v11, 0xf
    invoke-static {v4, v11, v12, v8}, Lcom/tcc/iap2server/LeafiaEv;->item(Landroid/os/Parcel;III)V
    :items_full
    if-lez v7, :items_done
    const/4 v12, 0x5
    const/16 v11, 0x1e
    invoke-static {v4, v11, v12, v7}, Lcom/tcc/iap2server/LeafiaEv;->item(Landroid/os/Parcel;III)V
    :items_done
    invoke-static {v4}, Lcom/tcc/iap2server/LeafiaEv;->send(Landroid/os/Parcel;)Z
    move-result v13
    invoke-virtual {v4}, Landroid/os/Parcel;->recycle()V
    if-eqz v13, :log
    sput-object v10, Lcom/tcc/iap2server/LeafiaEv;->sLast:Ljava/lang/String;
    sput-wide v16, Lcom/tcc/iap2server/LeafiaEv;->sLastSent:J
    :log
    new-instance v11, Ljava/lang/StringBuilder;
    invoke-direct {v11}, Ljava/lang/StringBuilder;-><init>()V
    const-string v12, "sent "
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v13}, Ljava/lang/StringBuilder;->append(Z)Ljava/lang/StringBuilder;
    const-string v12, ": soc/energy/range raw "
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v10}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v12, " -> "
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v3}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v12, " of "
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v12, " Wh, "
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v9}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v12, " %x1000, "
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v12, " km (full "
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v7}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v12, " km)"
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v11
    const-string v12, "LeafiaEv"
    invoke-static {v12, v11}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void

    :invalid
    new-instance v11, Ljava/lang/StringBuilder;
    invoke-direct {v11}, Ljava/lang/StringBuilder;-><init>()V
    const-string v12, "no valid battery reading: soc/energy/range raw "
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v12, "/"
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v11, v2}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v11}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v11
    const-string v12, "LeafiaEv"
    invoke-static {v12, v11}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;)I
    return-void
.end method
