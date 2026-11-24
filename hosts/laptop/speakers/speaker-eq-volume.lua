-- Moves the speaker EQ's high-pass, loudness shelf and preamp with the
-- volume (filter in ../speakers.nix):
--   quiet: ISO 226 equal-loudness lift below ~400 Hz, reference 80 phon
--   loud:  high-pass rises until H2+H3 stays under 3 % (-30 dB)
-- TABLE comes from the 2026-11-19 measurements: listening level per volume
-- (UMIK-1, music at -14 LUFS), distortion per frequency at 88 % (it scales
-- 1:1 with level). Above 88 % the speaker gets no louder.
-- Runs on volume changes and when the filter starts, nothing else.

local SPEAKER = "@speaker@"
local FILTER = "effect_input.speaker_eq"

-- cubic volume, high-pass Hz, shelf dB, preamp dB
local TABLE = {
  { 0.00, 100, 8.0, -4.9 },
  { 0.02, 100, 8.0, -4.9 },
  { 0.04, 100, 8.0, -4.9 },
  { 0.06, 100, 8.0, -4.9 },
  { 0.08, 100, 8.0, -4.9 },
  { 0.10, 100, 8.0, -4.9 },
  { 0.12, 100, 8.0, -4.9 },
  { 0.14, 100, 8.0, -4.9 },
  { 0.16, 100, 8.0, -4.9 },
  { 0.18, 100, 8.0, -4.9 },
  { 0.20, 100, 8.0, -4.9 },
  { 0.22, 100, 8.0, -4.9 },
  { 0.24, 100, 8.0, -4.9 },
  { 0.26, 100, 8.0, -4.9 },
  { 0.28, 100, 8.0, -4.9 },
  { 0.30, 100, 8.0, -4.9 },
  { 0.32, 100, 8.0, -4.9 },
  { 0.34, 100, 8.0, -4.9 },
  { 0.36, 100, 8.0, -4.9 },
  { 0.38, 100, 8.0, -4.9 },
  { 0.40, 100, 8.0, -4.9 },
  { 0.42, 100, 8.0, -4.9 },
  { 0.44, 100, 8.0, -4.9 },
  { 0.46, 100, 8.0, -4.9 },
  { 0.48, 100, 8.0, -4.9 },
  { 0.50, 104, 8.0, -4.8 },
  { 0.52, 121, 8.0, -4.2 },
  { 0.54, 136, 8.0, -3.7 },
  { 0.56, 150, 8.0, -3.3 },
  { 0.58, 160, 7.7, -2.9 },
  { 0.60, 169, 7.4, -2.5 },
  { 0.62, 180, 7.1, -2.1 },
  { 0.64, 189, 6.8, -1.8 },
  { 0.66, 199, 6.5, -1.5 },
  { 0.68, 209, 6.3, -1.5 },
  { 0.70, 219, 6.0, -1.5 },
  { 0.72, 228, 5.8, -1.5 },
  { 0.74, 238, 5.5, -1.5 },
  { 0.76, 247, 5.3, -1.5 },
  { 0.78, 257, 5.0, -1.5 },
  { 0.80, 270, 4.8, -1.5 },
  { 0.82, 281, 4.6, -1.5 },
  { 0.84, 296, 4.4, -1.5 },
  { 0.86, 308, 4.2, -1.5 },
  { 0.88, 320, 4.0, -1.5 },
  { 0.90, 320, 4.0, -1.5 },
  { 0.92, 320, 4.0, -1.5 },
  { 0.94, 320, 4.0, -1.5 },
  { 0.96, 320, 4.0, -1.5 },
  { 0.98, 320, 4.0, -1.5 },
  { 1.00, 320, 4.0, -1.5 }
}

local log = Log.open_topic ("s-speaker-eq")

local speaker_om = ObjectManager {
  Interest { type = "node", Constraint { "node.name", "=", SPEAKER } }
}
local filter_om = ObjectManager {
  Interest { type = "node", Constraint { "node.name", "=", FILTER } }
}

-- linear volume of a node: mean of its channel volumes
local function linear_volume (node)
  for p in node:iterate_params ("Props") do
    local props = p:parse ()
    if props.pod_type == "Object" and props.properties.channelVolumes then
      local sum, n = 0, 0
      for _, v in ipairs (props.properties.channelVolumes) do
        sum, n = sum + v, n + 1
      end
      if n > 0 then
        return sum / n
      end
    end
  end
  return 1.0
end

local function lookup (v)
  if v <= TABLE[1][1] then return TABLE[1][2], TABLE[1][3], TABLE[1][4] end
  for i = 2, #TABLE do
    local a, b = TABLE[i - 1], TABLE[i]
    if v <= b[1] then
      local t = (v - a[1]) / (b[1] - a[1])
      return a[2] + t * (b[2] - a[2]), a[3] + t * (b[3] - a[3]), a[4] + t * (b[4] - a[4])
    end
  end
  local z = TABLE[#TABLE]
  return z[2], z[3], z[4]
end

local applied = nil

local function apply (force)
  local speaker, filter = speaker_om:lookup (), filter_om:lookup ()
  if not speaker or not filter then
    return
  end
  -- the volume keys act on the speaker, or on the filter if it was picked as output
  local v = (linear_volume (speaker) * linear_volume (filter)) ^ (1 / 3)
  local hp, shelf, pre = lookup (v)
  local key = string.format ("%.0f %.1f %.1f", hp, shelf, pre)
  if key == applied and not force then
    return
  end
  applied = key
  log:info (string.format ("volume %.2f: high-pass %.0f Hz, shelf %+.1f dB, preamp %+.1f dB",
      v, hp, shelf, pre))
  filter:set_param ("Props", Pod.Object {
    "Spa:Pod:Object:Param:Props", "Props",
    params = Pod.Struct {
      "hp_l:Freq", Pod.Float (hp), "hp_r:Freq", Pod.Float (hp),
      "ls_l:Gain", Pod.Float (shelf), "ls_r:Gain", Pod.Float (shelf),
      "pre_l:Gain", Pod.Float (pre), "pre_r:Gain", Pod.Float (pre),
    }
  })
end

local function watch (om)
  om:connect ("object-added", function (_, node)
    node:connect ("params-changed", function (_, id)
      if id == "Props" then
        apply (false)
      end
    end)
    -- a filter that has not run yet ignores control changes: re-apply when it starts
    node:connect ("state-changed", function (_, _, new_state)
      if new_state == "running" then
        apply (true)
      end
    end)
    apply (true)
  end)
  om:activate ()
end

watch (speaker_om)
watch (filter_om)
