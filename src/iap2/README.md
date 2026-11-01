# iAP2 identification change (Iap2ServerApp)

`patches/neev/Iap2ServerApp.bridge.lpd` is the upstream bridge build of the
iAP2 server with one change, made by `ev_engine.py`: the VehicleInformation
component that the head unit sends during iAP2 identification now carries
EngineType = Electric (2).

Stock code builds that component in
`com.tcc.iap2server.Iap2InitInformationMsg.getVehicelInformationGroup` but gates
the EngineType parameter on an instance flag (`iAP2UsedViehicleInfoEngineType`)
that is only ever 0, so the iPhone was never told the engine type. There is no
`persist.sys.iap2.*` property for it. The patch replaces the flag read with 1
and the value read with 2, in place (`const/4` + `nop`, same size).

This is an experiment: whether iOS does anything different for an "electric"
CarPlay head unit (Apple Maps EV routing is known to need automaker
integration as well). VehicleStatus (range, charge) is still off.

```
tools/lpatch/build.sh
pip install --require-hashes -r tools/requirements.txt
src/iap2/rebuild.sh neev <stock Iap2ServerApp.odex>           # writes the .lpd
src/iap2/rebuild.sh neev <stock Iap2ServerApp.odex> --check   # only verifies it
```

Then put the rebuilt APK's md5 (stock APK + the new classes.dex through
`lpatch zipadd`) in the 3_bridge Iap2ServerApp line of `patches/neev/manifest`
and run `tools/compat-built.py`.
