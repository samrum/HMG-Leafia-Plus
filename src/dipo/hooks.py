#!/usr/bin/env python3
"""Add Leafia's hooks to a baksmali tree of the CarPlay app (HKMC_DiPO).

usage: hooks.py <smali dir> <feature> [<feature> ...]

Features:
  auto-open  q.onSessionStarted -> com.ev6.cpwl.LeafiaAutoOpen.schedule
             (switch to CarPlay about 1.5 s after a CarPlay session starts)
  mute       v.onAllKeyForService -> LeafiaMuteKey.onKey
             (mute key pauses CarPlay audio, unmute resumes it)

Each hook is inserted at one anchor in stock code that must occur exactly once
in its method, so an unexpected tree stops the build instead of patching the
wrong place. The classes themselves are in src/dipo/smali and are copied into
the tree by rebuild.sh.
"""
import os, sys

SVC = 'Lcom/daudio/app/dipo/service/DipoService;'

# feature -> (file, method header, anchor in that method, code inserted after it)
HOOKS = {
    'auto-open': (
        'com/daudio/app/dipo/service/q.smali',
        '.method public final onSessionStarted(Lcom/daudio/app/dipo/telechips/CarPlayTransportType;)V',
        '    invoke-virtual {v1, v0, v2, v3}, ' + SVC + '->a(Landroid/os/Message;J)V\n',
        '\n    iget-object v1, p0, Lcom/daudio/app/dipo/service/q;->R:' + SVC + '\n'
        '\n    invoke-static {v1}, Lcom/ev6/cpwl/LeafiaAutoOpen;->schedule(' + SVC + ')V\n',
    ),
    'mute': (
        'com/daudio/app/dipo/service/v.smali',
        '.method public final onAllKeyForService(IIIIIIIZ)V',
        '    .registers 14\n',
        '\n    iget-object v0, p0, Lcom/daudio/app/dipo/service/v;->R:' + SVC + '\n'
        '\n    invoke-static {v0, p1, p2, p4, p7}, Lcom/daudio/app/dipo/service/LeafiaMuteKey;->onKey(' + SVC + 'IIII)V\n',
    ),
}


def apply(root, feature):
    rel, header, anchor, code = HOOKS[feature]
    path = os.path.join(root, rel)
    s = open(path).read()
    i = s.find(header + '\n')
    if i < 0 or s.find(header + '\n', i + 1) >= 0:
        sys.exit('%s: method not found once in %s' % (feature, rel))
    j = s.index('\n.end method', i)
    body = s[i:j]
    if body.count(anchor) != 1:
        sys.exit('%s: anchor found %d times in %s' % (feature, body.count(anchor), rel))
    if code in body:
        sys.exit('%s: already applied' % feature)
    body = body.replace(anchor, anchor + code)
    open(path, 'w').write(s[:i] + body + s[j:])
    print('hooked %s (%s)' % (feature, rel))


def main():
    if len(sys.argv) < 3 or sys.argv[1] in ('-h', '--help'):
        sys.exit(__doc__)
    for f in sys.argv[2:]:
        if f not in HOOKS:
            sys.exit('unknown feature %s' % f)
        apply(sys.argv[1], f)


if __name__ == '__main__':
    main()
