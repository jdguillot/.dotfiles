-- Sunshine captures the scanout framebuffer through KMS and encodes it as
-- SDR, 8-bit. When gamescope drives the panel in HDR -- and Steam's Big
-- Picture asks it to, the attached C49RG9x being HDR10 -- what Sunshine
-- captures is PQ / Rec. 2020 and nothing tone-maps it on the way out, so
-- every client renders a flat, grey picture. Both a desktop Moonlight and a
-- phone showed it; the same session screenshots correctly on the host.
--
-- Nobody sits at this machine, so HDR buys it nothing locally.
gamescope.convars.hdr_enabled.value = false
