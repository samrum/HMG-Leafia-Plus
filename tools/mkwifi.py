#!/usr/bin/env python3
"""Make the Wi-Fi client fix (part 6_wifi) for one car's HKMC_WifiSettings.

usage: mkwifi.py <stock dir> [--framework DIR] [--patches DIR] [--work DIR]

  <stock dir>  a stock tree (a port kit's LEAFIA/private/stock/) with
               app/HKMC_WifiSettings.apk, app/HKMC_WifiSettings.odex and
               framework/*.odex from the same firmware (or give --framework)

The head unit's one Wi-Fi radio runs either the hotspot that wireless CarPlay/AA
use or the Wi-Fi client (opt-in, LEAFIA-WIFI-CLIENT). The stock Wi-Fi settings
screen (Settings > Data/Network > Wi-Fi):
  - stopped the projection hotspot as soon as it opened, which dropped CarPlay;
  - started the client in the same instant it stopped the hotspot, which failed
    ("Error" under the switch) and left Wi-Fi and the hotspot dead until a restart;
  - never brought the hotspot back when the client was turned off;
  - labelled its Wi-Fi tab with the "Wi-Fi Hotspot" string.
This adds com.hkmc.wifisettings.LeafiaWifi (src/wifisettings/smali) and hooks it in;
see that file for what it does. Each edit is found by its exact code and the script
stops unless every one occurs exactly as expected.

Writes patches/common/HKMC_WifiSettings.wifi.<stock md5 prefix>.lpd and adds its
line to patches/common/optional (one line per stock APK). The head unit applies
whichever line matches its own stock app.

Needs: java with baksmali/smali 2.5.2 (~/.local/share/smali, or BAKSMALI/SMALI),
the host lpatch (tools/lpatch/build.sh) and bsdiff4 (tools/requirements.txt).
"""
import argparse, hashlib, os, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, 'src', 'wifisettings', 'smali')
LPATCH = os.path.join(HERE, 'lpatch', 'lpatch-host')
MKDELTA = os.path.join(HERE, 'mkdelta.py')
SMALI_DIR = os.path.expanduser('~/.local/share/smali')
BAKSMALI = os.environ.get('BAKSMALI', os.path.join(SMALI_DIR, 'baksmali-2.5.2.jar'))
SMALI = os.environ.get('SMALI', os.path.join(SMALI_DIR, 'smali-2.5.2.jar'))
BCP = ['core', 'conscrypt', 'okhttp', 'core-junit', 'bouncycastle', 'ext', 'framework', 'framework2',
       'telephony-common', 'voip-common', 'mms-common', 'android.policy', 'services', 'apache-xml',
       'webviewchromium', 'automotive']

P = 'Lcom/hkmc/wifisettings/'
WM = 'Landroid/net/wifi/WifiManager;'
L = P + 'LeafiaWifi;'
GETSTRING = 'invoke-virtual {p0, %s}, Landroid/content/Context;->getString(I)Ljava/lang/String;'
NEWTAB = ('    const-string v1, "WiFi"\n\n'
          '    invoke-virtual {v0, v1}, Landroid/widget/TabHost;->newTabSpec(Ljava/lang/String;)Landroid/widget/TabHost$TabSpec;\n\n'
          '    move-result-object v0\n\n')
WIFI_TAB = '    const v1, 0x7f090028\n\n    ' + GETSTRING % 'v1'   # string/wifi_settings "Wi-Fi"

# (file, method header or None for the whole file, old, new, times old must occur)
EDITS = [
    # the switch (WifiClientModeEnabler.onPreferenceChange): hand it to LeafiaWifi.toggle
    ('com/hkmc/wifisettings/ac.smali',
     '.method public final onPreferenceChange(Landroid/preference/Preference;Ljava/lang/Object;)Z',
     '    invoke-virtual {v1}, Ljava/lang/Boolean;->booleanValue()Z\n\n    move-result v1\n',
     '    invoke-virtual {v1}, Ljava/lang/Boolean;->booleanValue()Z\n\n    move-result v1\n\n'
     '    # HMG Leafia Plus: switch on its own thread, waiting for the hotspot (LeafiaWifi)\n'
     '    iget-object v2, p0, ' + P + 'ac;->nF:' + P + 'ay;\n\n'
     '    invoke-static {v2}, ' + P + 'ay;->b(' + P + 'ay;)' + WM + '\n\n'
     '    move-result-object v2\n\n'
     '    if-eqz v2, :leafia_stock\n\n'
     '    iget-object v3, p0, ' + P + 'ac;->nF:' + P + 'ay;\n\n'
     '    invoke-static {v3}, ' + P + 'ay;->c(' + P + 'ay;)Landroid/preference/Preference;\n\n'
     '    move-result-object v3\n\n'
     '    invoke-static {v2, v3, v1}, ' + L + '->toggle(' + WM + 'Landroid/preference/Preference;Z)V\n\n'
     '    const/4 v0, 0x1\n\n'
     '    return v0\n\n'
     '    :leafia_stock\n',
     1),
    # opening the screen: keep the phone projection hotspot (AP mode 2)
    ('com/hkmc/wifisettings/WifiClientSettings.smali',
     '.method protected onResume()V',
     '    invoke-virtual {v0}, ' + WM + '->isWifiApEnabled()Z\n\n    move-result v0\n\n    if-eqz v0, :cond_1f\n',
     '    invoke-virtual {v0}, ' + WM + '->isWifiApEnabled()Z\n\n    move-result v0\n\n    if-eqz v0, :cond_1f\n\n'
     '    # HMG Leafia Plus: don\'t stop the phone projection hotspot just because this screen opened\n'
     '    iget-object v0, p0, ' + P + 'WifiClientSettings;->c:' + WM + '\n\n'
     '    invoke-static {v0}, ' + L + '->stopApOnOpen(' + WM + ')Z\n\n'
     '    move-result v0\n\n'
     '    if-eqz v0, :cond_1f\n',
     1),
    # the Wi-Fi tab used string/tab_menu_wifi_hotspot ("Wi-Fi Hotspot") like the hotspot tab
    ('com/hkmc/wifisettings/settings/ui/NetworkConnectionSettings.smali', None,
     NEWTAB + '    ' + GETSTRING % 'v5',
     NEWTAB + '    # HMG Leafia Plus: label the Wi-Fi tab "Wi-Fi"\n' + WIFI_TAB,
     2),
    ('com/hkmc/wifisettings/settings/ui/NetworkConnectionSettings.smali', None,
     NEWTAB + '    .line 251\n    const v1, 0x7f09005d\n\n    ' + GETSTRING % 'v1',
     NEWTAB + '    .line 251\n    # HMG Leafia Plus: label the Wi-Fi tab "Wi-Fi"\n' + WIFI_TAB,
     1),
]


def md5(p):
    return hashlib.md5(open(p, 'rb').read()).hexdigest()


def run(*a, **kw):
    subprocess.run(a, check=True, **kw)


def edit(root, rel, header, old, new, times):
    path = os.path.join(root, rel)
    s = open(path, encoding='utf-8').read()
    if header is None:
        i, j = 0, len(s)
    else:
        i = s.find(header + '\n')
        if i < 0 or s.find(header + '\n', i + 1) >= 0:
            sys.exit('%s: %s not found exactly once' % (rel, header))
        j = s.index('\n.end method', i)
    body = s[i:j]
    if body.count(old) != times:
        sys.exit('%s: expected code found %d times, not %d: merge by hand' % (rel, body.count(old), times))
    open(path, 'w', encoding='utf-8').write(s[:i] + body.replace(old, new) + s[j:])


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('stock')
    ap.add_argument('--framework', help='framework dir (default: <stock dir>/framework)')
    ap.add_argument('--patches', default=os.path.join(ROOT, 'patches'))
    ap.add_argument('--work')
    a = ap.parse_args()
    odex = os.path.join(a.stock, 'app', 'HKMC_WifiSettings.odex')
    apk = os.path.join(a.stock, 'app', 'HKMC_WifiSettings.apk')
    fw = a.framework or os.path.join(a.stock, 'framework')
    for f in (odex, apk) + tuple(os.path.join(fw, b + '.odex') for b in BCP):
        if not os.path.isfile(f):
            sys.exit('missing ' + f)
    for f in (BAKSMALI, SMALI, LPATCH):
        if not os.path.isfile(f):
            sys.exit('missing %s (see --help)' % f)
    stock_md5 = md5(odex)
    work = a.work or tempfile.mkdtemp(prefix='mkwifi.')
    smali_dir = os.path.join(work, 'smali')
    shutil.rmtree(smali_dir, ignore_errors=True)
    extra = [os.path.join(fw, f) for f in sorted(os.listdir(fw))
             if f.endswith('.odex') and f[:-5] not in BCP]
    r = subprocess.run(['java', '-jar', BAKSMALI, 'x', '-a', '18', '-j', '1', '-d', fw,
                        '-b', ':'.join(os.path.join(fw, b + '.odex') for b in BCP),
                        '-c', ':'.join(extra), '-o', smali_dir, odex],
                       capture_output=True, text=True)
    if r.returncode != 0 or 'Error occurred' in r.stdout + r.stderr:
        sys.exit('deodex failed (check the framework is from the same firmware):\n' + (r.stdout + r.stderr)[-2000:])
    if os.path.exists(os.path.join(smali_dir, 'com/hkmc/wifisettings/LeafiaWifi.smali')):
        sys.exit('this HKMC_WifiSettings already carries the fix: use the stock file')
    for e in EDITS:
        edit(smali_dir, *e)
    shutil.copytree(SRC, smali_dir, dirs_exist_ok=True)
    dex = os.path.join(work, 'classes.dex')
    run('java', '-jar', SMALI, 'a', '--api', '18', '-j', '1', '-o', dex, smali_dir)

    name = 'HKMC_WifiSettings.wifi.%s.lpd' % stock_md5[:8]
    common = os.path.join(a.patches, 'common')
    lpd = os.path.join(common, name)
    run(sys.executable, MKDELTA, odex, dex, lpd, stdout=subprocess.DEVNULL)
    rebuilt, built = os.path.join(work, 'rebuilt.dex'), os.path.join(work, 'built.apk')
    run(LPATCH, 'delta', lpd, odex, rebuilt, stdout=subprocess.DEVNULL)
    run(LPATCH, 'zipadd', apk, rebuilt, built, stdout=subprocess.DEVNULL)
    line = '6_wifi app HKMC_WifiSettings common/%s %s' % (name, md5(built))

    opt = os.path.join(common, 'optional')
    lines = open(opt).read().splitlines() if os.path.exists(opt) else []
    lines = [l for l in lines if l != line]
    lines.append(line)
    open(opt, 'w').write('\n'.join(lines) + '\n')
    print(line)


if __name__ == '__main__':
    main()
