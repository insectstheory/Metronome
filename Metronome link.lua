-- Metronome
-- Metronome light with
-- Ableton Link support
-- E1: BPM (When Link is off)
-- E2: Bar measure (2-4-8)
-- K2: Enable/D Ableton Link
-- K3: Tap tempo

engine.name = "None"

local bpm          = 120.0
local beats        = 4
local beat_num     = 0
local flash        = false
local flash_frames = 0
local link_active  = false
local flash_level  = 15

local tap_times = {}
local TAP_MAX   = 8
local TAP_RESET = 2.0

local RECT = { x=2, y=2, w=124, h=52 }

local function flash_duration()
  local beat_sec = 60.0 / bpm
  return math.max(2, math.floor(beat_sec * 0.12 * 60))
end

function redraw()
  screen.clear()

  if flash then
    if beat_num == 0 then
      screen.level(flash_level)
      screen.rect(RECT.x, RECT.y, RECT.w, RECT.h)
      screen.fill()
    else
      screen.level(math.floor(flash_level * 0.65))
      screen.rect(RECT.x, RECT.y, RECT.w, RECT.h)
      screen.stroke()
    end
  else
    screen.level(2)
    screen.rect(RECT.x, RECT.y, RECT.w, RECT.h)
    screen.stroke()
  end

  local dot_y = RECT.y + RECT.h - 6
  local dot_spacing = math.floor(RECT.w / (beats + 1))
  for i = 0, beats - 1 do
    local dot_x = RECT.x + dot_spacing * (i + 1)
    if i == beat_num then
      screen.level(flash and 0 or 15)
      screen.circle(dot_x, dot_y, 2)
      screen.fill()
    else
      screen.level(flash and 3 or 6)
      screen.circle(dot_x, dot_y, 1)
      screen.fill()
    end
  end

  screen.level(15)
  screen.font_face(1)
  screen.font_size(8)
  screen.move(127, 63)
  screen.text_right(string.format("%.1f", bpm))

  screen.level(4)
  screen.font_size(1)
  screen.move(127, 56)
  screen.text_right(link_active and "LINK" or "bpm")

  screen.update()
end

local function on_beat()
  beat_num = beat_num % beats
  flash = true
  flash_frames = flash_duration()
end

local clock_id = nil

local function clock_func()
  clock.sync(1)
  while true do
    beat_num = (beat_num + 1) % beats
    if link_active then
      bpm = params:get("clock_tempo")
    end
    on_beat()
    clock.sync(1)
  end
end

local frame_metro = nil

local function on_frame()
  if flash_frames > 0 then
    flash_frames = flash_frames - 1
    if flash_frames == 0 then
      flash = false
    end
    redraw()
  end
end

local function do_tap()
  local now = util.time()
  if #tap_times > 0 and (now - tap_times[#tap_times]) > TAP_RESET then
    tap_times = {}
  end
  table.insert(tap_times, now)
  if #tap_times > TAP_MAX then
    table.remove(tap_times, 1)
  end
  if #tap_times >= 2 then
    local intervals = {}
    for i = 2, #tap_times do
      table.insert(intervals, tap_times[i] - tap_times[i-1])
    end
    local sum = 0
    for _, v in ipairs(intervals) do sum = sum + v end
    local avg = sum / #intervals
    local new_bpm = math.max(20, math.min(300, 60.0 / avg))
    if not link_active then
      params:set("clock_tempo", new_bpm)
    end
    bpm = new_bpm
    redraw()
  end
end

function enc(n, d)
  if n == 1 then
    if not link_active then
      bpm = math.max(20, math.min(300, math.floor(bpm + 0.5) + d))
      params:set("clock_tempo", bpm)
      redraw()
    end
  elseif n == 2 then
    local allowed = {2, 4, 8}
    local cur = 2
    for i, v in ipairs(allowed) do if v == beats then cur = i end end
    cur = math.max(1, math.min(#allowed, cur + d))
    beats = allowed[cur]
    beat_num = 0
    redraw()
  end
end

function key(n, z)
  if z ~= 1 then return end
  if n == 2 then
    link_active = not link_active
    if link_active then
      params:set("clock_source", 3)
    else
      params:set("clock_source", 1)
      params:set("clock_tempo", bpm)
    end
    redraw()
  elseif n == 3 then
    do_tap()
  end
end

function init()
  screen.aa(0)
  screen.line_width(1)

  params:add_separator("metro_link")

  params:add_number("flash_level", "intensita flash", 1, 15, 15)
  params:set_action("flash_level", function(v)
    flash_level = v
    redraw()
  end)

  params:add_number("beats", "battiti per misura", 1, 3, 2, function(v)
    return ({2, 4, 8})[v]
  end)
  params:set_action("beats", function(v)
    beats = ({2, 4, 8})[v]
    beat_num = 0
    redraw()
  end)

  beat_num    = 0
  bpm         = params:get("clock_tempo")
  flash_level = params:get("flash_level")

  frame_metro = metro.init()
  frame_metro.time = 1/30
  frame_metro.event = on_frame
  frame_metro:start()

  clock_id = clock.run(clock_func)

  redraw()
end

function cleanup()
  if clock_id then clock.cancel(clock_id) end
  if frame_metro then frame_metro:stop() end
  params:set("clock_source", 1)
end
