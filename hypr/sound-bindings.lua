
-- ---------------------------------------------------------------------------
-- Ocean sound effects (virtuoso.notification-sounds)
--
-- Volume, mute and screenshots produce no notification, so the shell plugin
-- never sees them and they would stay silent. These rebind the Omarchy
-- defaults to the same commands with an omarchy-sound call appended.
--
-- Every option from the default binding is preserved: `locked` keeps the keys
-- working on the lock screen, `repeating` keeps a held key ramping.
--
-- omarchy-sound checks the mute toggle and Do Not Disturb itself, so these
-- stay quiet exactly when the rest of the system does. The --throttle guards
-- against a held key queueing a dozen overlapping copies of the sample.
-- ---------------------------------------------------------------------------

local sound = "omarchy-sound --throttle 120 play audio-volume-change"

-- Was: omarchy-audio-output-volume raise / lower / mute-toggle
hl.unbind("XF86AudioRaiseVolume")
hl.unbind("XF86AudioLowerVolume")
hl.unbind("XF86AudioMute")
o.bind("XF86AudioRaiseVolume", "Volume up", "omarchy-audio-output-volume raise; " .. sound, { locked = true, repeating = true })
o.bind("XF86AudioLowerVolume", "Volume down", "omarchy-audio-output-volume lower; " .. sound, { locked = true, repeating = true })
o.bind("XF86AudioMute", "Mute", "omarchy-audio-output-volume mute-toggle; " .. sound, { locked = true })

-- Was: omarchy-audio-output-volume +1 / -1 (precise steps)
hl.unbind("ALT + XF86AudioRaiseVolume")
hl.unbind("ALT + XF86AudioLowerVolume")
o.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", "omarchy-audio-output-volume +1; " .. sound, { locked = true, repeating = true })
o.bind("ALT + XF86AudioLowerVolume", "Volume down precise", "omarchy-audio-output-volume -1; " .. sound, { locked = true, repeating = true })

-- Was: omarchy-capture-screenshot. `&&` so a cancelled region picker, which
-- exits non-zero, stays silent instead of faking a shutter.
hl.unbind("PRINT")
o.bind("PRINT", "Screenshot", "omarchy-capture-screenshot && omarchy-sound play button-pressed")
