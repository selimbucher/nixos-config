-- toggle master FX that add >= 256 samples of PDC (lookahead limiters, soothe, etc.)
local m = reaper.GetMasterTrack(0)
local heavy, anyOn = {}, false
for i = 0, reaper.TrackFX_GetCount(m) - 1 do
  local ok, pdc = reaper.TrackFX_GetNamedConfigParm(m, i, "pdc")
  if ok and tonumber(pdc) and tonumber(pdc) >= 256 then
    heavy[#heavy + 1] = i
    if reaper.TrackFX_GetEnabled(m, i) then anyOn = true end
  end
end
-- when disabled, pdc reads 0, so also remember which ones we turned off
local key = "pw_tracking_mode"
if #heavy == 0 then
  local _, saved = reaper.GetProjExtState(0, key, "fx")
  for idx in saved:gmatch("%d+") do reaper.TrackFX_SetEnabled(m, tonumber(idx), true) end
  reaper.SetProjExtState(0, key, "fx", "")
else
  local list = {}
  for _, i in ipairs(heavy) do reaper.TrackFX_SetEnabled(m, i, false); list[#list + 1] = i end
  reaper.SetProjExtState(0, key, "fx", table.concat(list, ","))
end
