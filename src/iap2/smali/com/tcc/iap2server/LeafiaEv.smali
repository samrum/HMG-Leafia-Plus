# Leafia EV: live battery and range for CarPlay (Apple Maps EV routing),
# a trip log for tuning, and a model override file.
#
# Read-only: asks the car's own HEV service (com.hkmc.micom.hev,
# IHEVService.getHEVStatus, transaction 3) every 15 s for
#   0x19 DISPLAY_SOC   cluster battery %, 0.5 % steps
#   0x31 ENERGYMAP     remaining usable energy, 2 Wh steps (0xffff = invalid)
#   0x09 ELECTRIC_DTE  cluster range, in the cluster's unit (miles on US cars)
#   0x1f ODOMETER, 0x07 CHARGE_STATE, 0x4f climate power (raw, trip log only)
# (signal meanings: willemcvu/egmp-aa-ev-feat docs/DATA-SOURCES.md).
#
# Trip log: every changed reading is appended to ev-trips.csv in the app's
# files dir (/data/data/com.tcc.iap2server/files; at 2 MB it moves to
# ev-trips.1.csv). The kit collects it. No location.
#
# Model override: LEAFIA-EV-MODEL.json at the top of a USB drive
# (/storage/usb0 or usb1), read when it changes, checked, and kept as
# ev-model.json in the files dir so the drive can be removed. It may hold
# "charging_contract" and/or "consumption_contract" (same shape as
# src/iap2/evnative/ioniq5-contracts.json, model_id must match); a missing
# one uses the default (LeafiaEvModels, generated). A file with {} resets.
#
# While the iPhone has vehicle status updates on, sends through the stock
# Iap2SendVehicleStatus JNI call: 21 MinBatteryCharge 0 Wh, 22
# CurrentBatteryCharge, 23 MaxBatteryCharge (usable capacity, learned from
# energy / SOC at 50 % or more), 24 DisplayedBatteryPercentage (% x 1000),
# 26/27 the models; with a range: 3 Range and 11 RangeElectric (km), 6/15
# range warnings (at 20 % or less), 30 MaxRangeElectric (range scaled to
# 100 %, from 20 % up). Sent when a reading or the model changed, at most
# once a minute and at least every 5 minutes; each check is logged.
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
.field static sCharging:Ljava/lang/String;
.field static sConsumption:Ljava/lang/String;
.field static sDriveStamp:J
.field static sLoaded:Z
.field static sRowKey:Ljava/lang/String;

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
    const-wide/16 v0, 0x3a98
    invoke-static {v0, v1}, Ljava/lang/Thread;->sleep(J)V
    :try_end_sleep
    .catch Ljava/lang/InterruptedException; {:try_start_sleep .. :try_end_sleep} :woken
    :check
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
    # trip log (odometer, charge state, climate power raw) and model file
    const/16 v13, 0x1f
    invoke-static {v13}, Lcom/tcc/iap2server/LeafiaEv;->hev(I)I
    move-result v13
    const/4 v14, 0x7
    invoke-static {v14}, Lcom/tcc/iap2server/LeafiaEv;->hev(I)I
    move-result v14
    const/16 v15, 0x4f
    invoke-static {v15}, Lcom/tcc/iap2server/LeafiaEv;->hev(I)I
    move-result v15
    move v10, v0
    move v11, v1
    move v12, v2
    invoke-static/range {v10 .. v15}, Lcom/tcc/iap2server/LeafiaEv;->logRow(IIIIII)V
    invoke-static {}, Lcom/tcc/iap2server/LeafiaEv;->loadModels()V
    sget-boolean v11, Lcom/tcc/iap2server/LeafiaEv;->sStarted:Z
    if-nez v11, :phone_wants_it
    return-void
    :phone_wants_it
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
    if-eqz v11, :changed
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

    # changed: right away after a start or a new model (sLast null), else at
    # most once a minute (Maps recalculates the route on every update)
    :changed
    sget-object v11, Lcom/tcc/iap2server/LeafiaEv;->sLast:Ljava/lang/String;
    if-eqz v11, :send
    sget-wide v18, Lcom/tcc/iap2server/LeafiaEv;->sLastSent:J
    sub-long v18, v16, v18
    const-wide/32 v12, 0xea60
    cmp-long v11, v18, v12
    if-gez v11, :send
    const-string v12, "changed, sent within a minute: soc/energy/range raw "
    invoke-virtual {v12, v10}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v11
    const-string v12, "LeafiaEv"
    invoke-static {v12, v11}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void

    :send
    invoke-static {}, Landroid/os/Parcel;->obtain()Landroid/os/Parcel;
    move-result-object v4
    const/4 v11, 0x6
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
    invoke-static {v4}, Lcom/tcc/iap2server/LeafiaEv;->models(Landroid/os/Parcel;)V
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
    const-string v12, " km), models "
    invoke-virtual {v11, v12}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-static {}, Lcom/tcc/iap2server/LeafiaEv;->modelState()Ljava/lang/String;
    move-result-object v12
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

# the two models as parcel items (type 10, one String16 each)
.method static models(Landroid/os/Parcel;)V
    .registers 5
    sget-object v0, Lcom/tcc/iap2server/LeafiaEv;->sCharging:Ljava/lang/String;
    if-nez v0, :have_charging
    invoke-static {}, Lcom/tcc/iap2server/LeafiaEvModels;->charging()Ljava/lang/String;
    move-result-object v0
    :have_charging
    sget-object v1, Lcom/tcc/iap2server/LeafiaEv;->sConsumption:Ljava/lang/String;
    if-nez v1, :have_consumption
    invoke-static {}, Lcom/tcc/iap2server/LeafiaEvModels;->consumption()Ljava/lang/String;
    move-result-object v1
    :have_consumption
    const/4 v3, 0x1
    const/16 v2, 0x1a
    invoke-virtual {p0, v2}, Landroid/os/Parcel;->writeInt(I)V
    const/16 v2, 0xa
    invoke-virtual {p0, v2}, Landroid/os/Parcel;->writeInt(I)V
    invoke-virtual {p0, v3}, Landroid/os/Parcel;->writeInt(I)V
    invoke-virtual {p0, v0}, Landroid/os/Parcel;->writeString(Ljava/lang/String;)V
    const/16 v2, 0x1b
    invoke-virtual {p0, v2}, Landroid/os/Parcel;->writeInt(I)V
    const/16 v2, 0xa
    invoke-virtual {p0, v2}, Landroid/os/Parcel;->writeInt(I)V
    invoke-virtual {p0, v3}, Landroid/os/Parcel;->writeInt(I)V
    invoke-virtual {p0, v1}, Landroid/os/Parcel;->writeString(Ljava/lang/String;)V
    return-void
.end method

.method static modelState()Ljava/lang/String;
    .registers 3
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, "charging "
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, "default"
    sget-object v2, Lcom/tcc/iap2server/LeafiaEv;->sCharging:Ljava/lang/String;
    if-eqz v2, :c1
    const-string v1, "custom"
    :c1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, ", consumption "
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, "default"
    sget-object v2, Lcom/tcc/iap2server/LeafiaEv;->sConsumption:Ljava/lang/String;
    if-eqz v2, :c2
    const-string v1, "custom"
    :c2
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    return-object v0
.end method

# trip log: one CSV line per changed reading (soc, energy, range, odometer,
# charge state); climate power and whether CarPlay wants updates ride along
.method static logRow(IIIIII)V
    .registers 15
    # p0 soc, p1 energy, p2 range, p3 odometer, p4 charge state, p5 climate
    :try_start
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, ","
    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, p2}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, p3}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, p4}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v2
    sget-object v3, Lcom/tcc/iap2server/LeafiaEv;->sRowKey:Ljava/lang/String;
    invoke-virtual {v2, v3}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v3
    if-eqz v3, :changed
    return-void
    :changed
    sput-object v2, Lcom/tcc/iap2server/LeafiaEv;->sRowKey:Ljava/lang/String;
    sget-object v3, Lcom/tcc/iap2server/LeafiaEv;->sSvc:Lcom/tcc/iap2server/Iap2Service;
    invoke-virtual {v3}, Lcom/tcc/iap2server/Iap2Service;->getFilesDir()Ljava/io/File;
    move-result-object v3
    new-instance v4, Ljava/io/File;
    const-string v5, "ev-trips.csv"
    invoke-direct {v4, v3, v5}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V
    invoke-virtual {v4}, Ljava/io/File;->length()J
    move-result-wide v5
    const-wide/32 v7, 0x1e8480
    cmp-long v5, v5, v7
    if-lez v5, :rotated
    new-instance v5, Ljava/io/File;
    const-string v6, "ev-trips.1.csv"
    invoke-direct {v5, v3, v6}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V
    invoke-virtual {v4, v5}, Ljava/io/File;->renameTo(Ljava/io/File;)Z
    :rotated
    new-instance v5, Ljava/lang/StringBuilder;
    invoke-direct {v5}, Ljava/lang/StringBuilder;-><init>()V
    invoke-virtual {v4}, Ljava/io/File;->exists()Z
    move-result v6
    if-nez v6, :no_header
    const-string v6, "time_ms,soc_half_pct,energy_2wh,range_cluster_unit,odometer_raw,charge_state,climate_raw,carplay_updates\n"
    invoke-virtual {v5, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    :no_header
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v6
    invoke-virtual {v5, v6, v7}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    invoke-virtual {v5, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v5, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v5, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v5, p5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v5, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    sget-boolean v6, Lcom/tcc/iap2server/LeafiaEv;->sStarted:Z
    invoke-virtual {v5, v6}, Ljava/lang/StringBuilder;->append(Z)Ljava/lang/StringBuilder;
    const-string v6, "\n"
    invoke-virtual {v5, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v5}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v5
    const/4 v6, 0x1
    invoke-static {v4, v5, v6}, Lcom/tcc/iap2server/LeafiaEv;->write(Ljava/io/File;Ljava/lang/String;Z)V
    :try_end
    .catchall {:try_start .. :try_end} :failed
    return-void
    :failed
    move-exception v0
    const-string v1, "LeafiaEv"
    const-string v2, "trip log write failed"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void
.end method

.method static write(Ljava/io/File;Ljava/lang/String;Z)V
    .registers 5
    new-instance v0, Ljava/io/FileOutputStream;
    invoke-direct {v0, p0, p2}, Ljava/io/FileOutputStream;-><init>(Ljava/io/File;Z)V
    :try_start
    const-string v1, "UTF-8"
    invoke-virtual {p1, v1}, Ljava/lang/String;->getBytes(Ljava/lang/String;)[B
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/io/FileOutputStream;->write([B)V
    :try_end
    .catchall {:try_start .. :try_end} :failed
    invoke-virtual {v0}, Ljava/io/FileOutputStream;->close()V
    return-void
    :failed
    move-exception v1
    invoke-virtual {v0}, Ljava/io/FileOutputStream;->close()V
    throw v1
.end method

# up to 16 KB of a file as UTF-8
.method static read(Ljava/io/File;)Ljava/lang/String;
    .registers 7
    new-instance v0, Ljava/io/FileInputStream;
    invoke-direct {v0, p0}, Ljava/io/FileInputStream;-><init>(Ljava/io/File;)V
    :try_start
    const/16 v1, 0x4000
    new-array v1, v1, [B
    const/4 v2, 0x0
    :loop
    rsub-int v3, v2, 0x4000
    if-lez v3, :done
    invoke-virtual {v0, v1, v2, v3}, Ljava/io/FileInputStream;->read([BII)I
    move-result v3
    if-lez v3, :done
    add-int/2addr v2, v3
    goto :loop
    :done
    new-instance v4, Ljava/lang/String;
    const/4 v3, 0x0
    const-string v5, "UTF-8"
    invoke-direct {v4, v1, v3, v2, v5}, Ljava/lang/String;-><init>([BIILjava/lang/String;)V
    :try_end
    .catchall {:try_start .. :try_end} :failed
    invoke-virtual {v0}, Ljava/io/FileInputStream;->close()V
    return-object v4
    :failed
    move-exception v1
    invoke-virtual {v0}, Ljava/io/FileInputStream;->close()V
    throw v1
.end method

# a contract from the override file: null if absent; throws if it is wrong
.method static contract(Lorg/json/JSONObject;Ljava/lang/String;I)Ljava/lang/String;
    .registers 7
    invoke-virtual {p0, p1}, Lorg/json/JSONObject;->optJSONObject(Ljava/lang/String;)Lorg/json/JSONObject;
    move-result-object v0
    if-nez v0, :present
    const/4 v0, 0x0
    return-object v0
    :present
    const-string v1, "model_id"
    const/4 v2, -0x1
    invoke-virtual {v0, v1, v2}, Lorg/json/JSONObject;->optInt(Ljava/lang/String;I)I
    move-result v1
    if-ne v1, p2, :bad_id
    const-string v1, "vehicle_parameters"
    invoke-virtual {v0, v1}, Lorg/json/JSONObject;->optJSONObject(Ljava/lang/String;)Lorg/json/JSONObject;
    move-result-object v1
    if-eqz v1, :no_parameters
    invoke-virtual {v0}, Lorg/json/JSONObject;->toString()Ljava/lang/String;
    move-result-object v1
    const-string v2, "UTF-8"
    invoke-virtual {v1, v2}, Ljava/lang/String;->getBytes(Ljava/lang/String;)[B
    move-result-object v2
    array-length v2, v2
    const/16 v3, 0x7d0
    if-gt v2, v3, :too_long
    return-object v1
    :too_long
    const-string v2, " is longer than 2000 bytes"
    goto :fail
    :no_parameters
    const-string v2, " has no vehicle_parameters"
    goto :fail
    :bad_id
    const-string v2, " needs model_id "
    invoke-static {p2}, Ljava/lang/String;->valueOf(I)Ljava/lang/String;
    move-result-object v3
    invoke-virtual {v2, v3}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    :fail
    invoke-virtual {p1, v2}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    new-instance v3, Ljava/lang/IllegalArgumentException;
    invoke-direct {v3, v2}, Ljava/lang/IllegalArgumentException;-><init>(Ljava/lang/String;)V
    throw v3
.end method

# use a model file: from a drive (save it) or the saved copy
.method static apply(Ljava/lang/String;ZLjava/lang/String;)V
    .registers 10
    :try_start
    new-instance v0, Lorg/json/JSONObject;
    invoke-direct {v0, p0}, Lorg/json/JSONObject;-><init>(Ljava/lang/String;)V
    const-string v1, "charging_contract"
    const v2, 0xc0000a
    invoke-static {v0, v1, v2}, Lcom/tcc/iap2server/LeafiaEv;->contract(Lorg/json/JSONObject;Ljava/lang/String;I)Ljava/lang/String;
    move-result-object v3
    const-string v1, "consumption_contract"
    const v2, 0xc00009
    invoke-static {v0, v1, v2}, Lcom/tcc/iap2server/LeafiaEv;->contract(Lorg/json/JSONObject;Ljava/lang/String;I)Ljava/lang/String;
    move-result-object v4
    sput-object v3, Lcom/tcc/iap2server/LeafiaEv;->sCharging:Ljava/lang/String;
    sput-object v4, Lcom/tcc/iap2server/LeafiaEv;->sConsumption:Ljava/lang/String;
    const/4 v5, 0x0
    sput-object v5, Lcom/tcc/iap2server/LeafiaEv;->sLast:Ljava/lang/String;
    if-eqz p1, :saved
    sget-object v5, Lcom/tcc/iap2server/LeafiaEv;->sSvc:Lcom/tcc/iap2server/Iap2Service;
    invoke-virtual {v5}, Lcom/tcc/iap2server/Iap2Service;->getFilesDir()Ljava/io/File;
    move-result-object v5
    new-instance v6, Ljava/io/File;
    const-string v1, "ev-model.json"
    invoke-direct {v6, v5, v1}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V
    if-nez v3, :keep
    if-nez v4, :keep
    invoke-virtual {v6}, Ljava/io/File;->delete()Z
    goto :saved
    :keep
    const/4 v1, 0x0
    invoke-static {v6, p0, v1}, Lcom/tcc/iap2server/LeafiaEv;->write(Ljava/io/File;Ljava/lang/String;Z)V
    :saved
    const-string v1, "model file used ("
    invoke-virtual {v1, p2}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    const-string v2, "): "
    invoke-virtual {v1, v2}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    invoke-static {}, Lcom/tcc/iap2server/LeafiaEv;->modelState()Ljava/lang/String;
    move-result-object v2
    invoke-virtual {v1, v2}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    const-string v2, "LeafiaEv"
    invoke-static {v2, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    :try_end
    .catchall {:try_start .. :try_end} :failed
    return-void
    :failed
    move-exception v0
    const-string v1, "model file ignored ("
    invoke-virtual {v1, p2}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    const-string v2, "): "
    invoke-virtual {v1, v2}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0}, Ljava/lang/Throwable;->toString()Ljava/lang/String;
    move-result-object v2
    invoke-virtual {v1, v2}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    const-string v2, "LeafiaEv"
    invoke-static {v2, v1}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;)I
    return-void
.end method

# the saved model once, then LEAFIA-EV-MODEL.json on a drive whenever it changes
.method static loadModels()V
    .registers 10
    :try_start
    sget-boolean v0, Lcom/tcc/iap2server/LeafiaEv;->sLoaded:Z
    if-nez v0, :drives
    const/4 v0, 0x1
    sput-boolean v0, Lcom/tcc/iap2server/LeafiaEv;->sLoaded:Z
    sget-object v0, Lcom/tcc/iap2server/LeafiaEv;->sSvc:Lcom/tcc/iap2server/Iap2Service;
    invoke-virtual {v0}, Lcom/tcc/iap2server/Iap2Service;->getFilesDir()Ljava/io/File;
    move-result-object v0
    new-instance v1, Ljava/io/File;
    const-string v2, "ev-model.json"
    invoke-direct {v1, v0, v2}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V
    invoke-virtual {v1}, Ljava/io/File;->isFile()Z
    move-result v2
    if-eqz v2, :drives
    invoke-static {v1}, Lcom/tcc/iap2server/LeafiaEv;->read(Ljava/io/File;)Ljava/lang/String;
    move-result-object v2
    const/4 v3, 0x0
    const-string v4, "saved"
    invoke-static {v2, v3, v4}, Lcom/tcc/iap2server/LeafiaEv;->apply(Ljava/lang/String;ZLjava/lang/String;)V
    :drives
    const-string v1, "/storage/usb0/LEAFIA-EV-MODEL.json"
    invoke-static {v1}, Lcom/tcc/iap2server/LeafiaEv;->drive(Ljava/lang/String;)Z
    move-result v0
    if-nez v0, :done
    const-string v1, "/storage/usb1/LEAFIA-EV-MODEL.json"
    invoke-static {v1}, Lcom/tcc/iap2server/LeafiaEv;->drive(Ljava/lang/String;)Z
    :try_end
    .catchall {:try_start .. :try_end} :failed
    :done
    return-void
    :failed
    move-exception v0
    const-string v1, "LeafiaEv"
    const-string v2, "model file check failed"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void
.end method

# true if the file is there; applies it when it changed since last seen
.method static drive(Ljava/lang/String;)Z
    .registers 8
    new-instance v0, Ljava/io/File;
    invoke-direct {v0, p0}, Ljava/io/File;-><init>(Ljava/lang/String;)V
    invoke-virtual {v0}, Ljava/io/File;->isFile()Z
    move-result v1
    if-nez v1, :there
    const/4 v1, 0x0
    return v1
    :there
    invoke-virtual {v0}, Ljava/io/File;->lastModified()J
    move-result-wide v2
    invoke-virtual {v0}, Ljava/io/File;->length()J
    move-result-wide v4
    add-long/2addr v2, v4
    sget-wide v4, Lcom/tcc/iap2server/LeafiaEv;->sDriveStamp:J
    cmp-long v1, v2, v4
    if-eqz v1, :same
    sput-wide v2, Lcom/tcc/iap2server/LeafiaEv;->sDriveStamp:J
    invoke-static {v0}, Lcom/tcc/iap2server/LeafiaEv;->read(Ljava/io/File;)Ljava/lang/String;
    move-result-object v1
    const/4 v2, 0x1
    invoke-static {v1, v2, p0}, Lcom/tcc/iap2server/LeafiaEv;->apply(Ljava/lang/String;ZLjava/lang/String;)V
    :same
    const/4 v1, 0x1
    return v1
.end method
