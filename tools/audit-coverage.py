#!/usr/bin/env python3
"""Report which Ocean sounds have an automatic trigger, and where it comes from.

Scans every place this plugin can decide to make a noise -- the QML rule tables,
the watcher, the hooks, the systemd units and the Hyprland keybindings -- so a
sound that quietly loses its only trigger shows up here instead of going unnoticed.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.path.expanduser('~')
svc = open(os.path.join(ROOT, 'Service.qml')).read()
used = {}

def mark(sound, how):
    used.setdefault(sound.replace('.oga', ''), []).append(how)

def table(name):
    m = re.search(r'property var %s: \[(.*?)\n  \]' % name, svc, re.S)
    return m.group(1) if m else ''

for key, snd in re.findall(r'\["([^"]+)",\s*"([^"]+\.oga)"', table('categoryRules')):
    mark(snd, 'category ' + key)
for key, snd in re.findall(r'\["([^"]+)",\s*"([^"]+\.oga)"\]', table('iconRules')):
    mark(snd, 'icon ' + key)
for line in table('glyphRules').splitlines():
    m = re.match(r'\s*\[(0x[0-9A-Fa-f]+),\s*"([^"]+)"(?:,\s*"([^"]+)")?\],?\s*//\s*(.*)', line.strip())
    if not m:
        continue
    mark(m.group(2), 'glyph ' + m.group(4).strip())
    if m.group(3):
        mark(m.group(3), 'glyph ' + m.group(4).strip() + ' [critical]')
for prop, how in [('lowSound', 'urgency low'), ('normalSound', 'urgency normal'),
                  ('criticalSound', 'urgency critical')]:
    m = re.search(r'property string %s: soundDir \+ "/([^"]+)\.oga"' % prop, svc)
    if m:
        mark(m.group(1), how)
m = re.search(r'confirmEnabled\(\) \{\n.*?soundDir \+ "/([^"]+)\.oga"', svc, re.S)
if m:
    mark(m.group(1), 'unmuting from the bar or menu')

# Anything outside the QML: the CLI is the single entry point, so grepping for
# it (and for the watcher's two-line play/notify wrappers) finds every caller.
sources = [(os.path.join(ROOT, 'bin/omarchy-sound-watch'), 'system watcher'),
           (os.path.join(ROOT, 'bin/omarchy-sound'), 'omarchy-sound outcome'),
           (os.path.join(HOME, '.config/hypr/bindings.lua'), 'keybinding')]
for d, label in [('hooks', 'hook'), ('systemd', 'systemd')]:
    for base, _, files in os.walk(os.path.join(ROOT, d)):
        for f in files:
            sources.append((os.path.join(base, f), label + ' ' + f.split('.')[0]))

# `play x` / `notify x` reach the CLI either directly or through the watcher's
# two-line wrappers, and both forms turn up mid-line inside `a && play x || play y`,
# so anchoring to line start would miss half of them. Comment lines are dropped
# first: the usage examples in the CLI header would otherwise register as
# triggers for sounds nothing actually plays.
call = re.compile(r'\b(?:omarchy-sound\s+(?:--?\S+\s+)*)?(?:play|notify|cmd_play)\s+([a-z][a-z0-9-]+)')
for path, label in sources:
    if not os.path.isfile(path):
        continue
    body = []
    for line in open(path).read().splitlines():
        stripped = line.lstrip()
        if stripped.startswith('#') or stripped.startswith('--') or stripped.startswith('//'):
            continue
        body.append(line)
    for snd in call.findall('\n'.join(body)):
        mark(snd, label)

sounds = sorted(f[:-4] for f in os.listdir(os.path.join(ROOT, 'sounds')) if f.endswith('.oga'))
orphans = []
print(f"{'SOUND':<24} {'TRIGGERS'}")
print('-' * 96)
for s in sounds:
    t = list(dict.fromkeys(used.get(s, [])))
    if not t:
        orphans.append(s)
    print(f"{s:<24} " + ('; '.join(t)[:70] if t else '** NO AUTOMATIC TRIGGER **'))
print('-' * 96)
print(f"{len(sounds) - len(orphans)}/{len(sounds)} sounds have at least one automatic trigger")
if orphans:
    print("orphans:", ', '.join(orphans))
sys.exit(1 if orphans else 0)
