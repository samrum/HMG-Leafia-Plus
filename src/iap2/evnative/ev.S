@ Leafia EV status for libiap2session.so (Telechips iAP2 session library).
@ Linked at fixed addresses by ev_native.py: .text in a new R+X segment,
@ .data in a new R+W segment. Reached only through PC-relative literals in
@ the stock code that ev_native.py re-points; no relocations are needed.
@
@ TEST VALUES ONLY: fixed numbers, not read from the car.

    .syntax unified
    .thumb
    .text

@ ---------------------------------------------------------------------------
@ VehicleInformation identification: GetPointer wrapper.
@ (id, type, u16 *idx, session *ctx, [sp] int *more) -> value pointer
@ id 2  EngineType: Electric (2)
@ id 11 SupportedChargingConnectors: repeated, one value per call; *more = 1
@        until the last one, so the packet encoder repeats the entry.
@ Every other id goes to the stock iAP2ControlIden_VehicleInfoIdenGetPointer.
    .global ev_vinfo_getptr
    .type ev_vinfo_getptr, %function
    .thumb_func
ev_vinfo_getptr:
    cmp     r0, #2
    beq     1f
    cmp     r0, #11
    beq     2f
    ldr     ip, 6f
7:  add     ip, pc
    bx      ip                      @ tail call, arguments untouched
1:  ldr     r2, [sp]
    movs    r1, #0
    str     r1, [r2]
    adr     r0, ev_engine_type
    bx      lr
2:  ldr     r2, [sp]
    ldr     r3, 3f
4:  add     r3, pc                  @ r3 = &ev_conn_index
    ldr     r1, [r3]
    adr     r0, ev_connectors
    add     r0, r1                  @ r0 = &ev_connectors[index]
    adds    r1, #1
    cmp     r1, #EV_CONNECTOR_COUNT
    bge     5f
    str     r1, [r3]
    movs    r1, #1
    str     r1, [r2]                @ more to come
    bx      lr
5:  movs    r1, #0
    str     r1, [r3]                @ last one: start over next time
    str     r1, [r2]
    bx      lr
    .p2align 2
3:  .word   ev_conn_index - (4b + 4)
6:  .word   STOCK_VINFO_IDEN_GETPTR - (7b + 4)

@ ---------------------------------------------------------------------------
@ VehicleStatusUpdate (0xA101): GetPointer wrapper for the update builders.
@ (id, type, u16 *idx, session *ctx, [sp] int *more) -> value pointer
@ Ids in ev_status_ids come from ev_status_values; everything else from the
@ stock iAP2ControlVehicleStatusGetUpdatesPointer.
    .global ev_status_getptr
    .type ev_status_getptr, %function
    .thumb_func
ev_status_getptr:
    push    {r4, r5}
    adr     r4, ev_status_ids
    movs    r5, #0
1:  ldrh    r1, [r4, r5]
    cmp     r1, #0
    beq     3f                      @ end of list: not ours
    cmp     r1, r0
    beq     2f
    adds    r5, #2
    b       1b
2:  ldr     r2, [sp, #8]
    movs    r1, #0
    str     r1, [r2]
    ldr     r0, 5f
4:  add     r0, pc                  @ r0 = ev_status_values
    lsls    r5, r5, #1              @ id index * 4
    add     r0, r5
    pop     {r4, r5}
    bx      lr
3:  pop     {r4, r5}
    ldr     ip, 6f
7:  add     ip, pc
    bx      ip                      @ tail call, arguments untouched
    .p2align 2
5:  .word   ev_status_values - (4b + 4)
6:  .word   STOCK_STATUS_UPDATES_GETPTR - (7b + 4)

    .p2align 2
ev_engine_type:
    .byte   2                       @ Iap2Const.EngineType.Electric
    .p2align 2
ev_connectors:
    .byte   0, 2                    @ CCS1 (DC), J1772 (AC)
    .equ    EV_CONNECTOR_COUNT, 2
    .p2align 2
@ order matches ev_status_values; 0 ends the list
ev_status_ids:
    .hword  3, 6, 11, 15, 21, 22, 23, 24, 25, 30, 0

@ ---------------------------------------------------------------------------
    .data
    .p2align 2
    .global ev_conn_index
ev_conn_index:
    .word   0

@ one 4-byte slot per id in ev_status_ids (the encoder reads u16/u32/bool
@ from the start of the slot, little endian)
    .global ev_status_values
ev_status_values:
    .word   EV_RANGE_KM             @ 3  Range (km)
    .word   0                       @ 6  RangeWarning
    .word   EV_RANGE_KM             @ 11 RangeElectric (km)
    .word   0                       @ 15 RangeWarningElectric
    .word   0                       @ 21 MinBatteryCharge (Wh)
    .word   EV_CHARGE_WH            @ 22 CurrentBatteryCharge (Wh)
    .word   EV_CAPACITY_WH          @ 23 MaxBatteryCharge (Wh)
    .word   EV_PERCENT_X1000        @ 24 DisplayedBatteryPercentage (% x 1000)
    .word   0                       @ 25 isCharging
    .word   EV_MAX_RANGE_KM         @ 30 MaxRangeElectric (km)

@ The tables (filled in by ev_native.py) follow in .data at ev_tables.
    .p2align 3
    .global ev_tables
ev_tables:
