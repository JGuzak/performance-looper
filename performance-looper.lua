-- performance looper
--
-- version: 0.0.1
-- author: Jordan Guzak
--
-- Stereo performance
-- looper prototype

--[[
Pages:
  1- overview
  2- mixer
  3- buffer
  4- fx
]]

local audio = require "audio"
local util = require "util"
local UI = require "ui"
local lattice = require "lattice"
local Looper = include "performance-looper/lib/looper"
local Transport = include "performance-looper/lib/transport"
local Mixer = include "performance-looper/lib/mixer"
local GridEvent = include "performance-looper/lib/gridEvent"

-- -------------------------
-- Debug/dev functions
function rerun()
  norns.script.load(norns.state.script)
end

-- screen constants
local MaxPages = 4
local MaxHeight = 63
local MaxWidth = 126

-- globals
local captureBufferPattern
local transport
local mixer
local gridEvents = {}
local screenTimer
local looper
local volumePolls = {}
local isClickTrackEnabled = false
local clickTrackPattern
local activePage = 3
local pages
local playIcon
local isScreenDirty
local shift

local g = grid.connect()

------------------------------------------
-- UI
screen_levels = {}
screen_levels["o"] = 0
screen_levels["l"] = 5
screen_levels["m"] = 10
screen_levels["h"] = 15

screen.level(screen_levels["h"])
screen.line_cap("square")
screen.font_face(1)
screen.font_size(8)

pages = UI.Pages.new(activePage, MaxPages)
playIcon = UI.PlaybackIcon.new(1, 1, 7, 4)
playIcon:set_active(true)

screenTimer = clock.run(
  function()
    while true do
      clock.sleep(1/30)
      if isScreenDirty then
        redraw()
        isScreenDirty = false
      end
    end
  end
)

function init()
  -- Params
  params:add_separator("performance_looper", "performance looper")
  -- params:add_option()

  audio.level_cut(1)
  audio.level_tape(1)
  audio.pitch_off()
  audio.comp_off()

  softcut.reset()
  softcut.buffer_clear()

  ------------------------------------------
  -- Defaults for internal state
  isScreenDirty = true
  shift = false

  -- transport and mixer
  transport = Transport:new()
  mixer = Mixer:new()

  ------------------------------------------
  -- Input and output VU callbacks
  volumePolls[1] = poll.set("amp_in_l")
  volumePolls[2] = poll.set("amp_in_r")
  volumePolls[3] = poll.set("amp_out_l")
  volumePolls[4] = poll.set("amp_out_r")

  for i = 1, 4 do
    volumePolls[i].callback = function(x)
      if i < 5 then
        mixer.lastIoVolumes[i] = util.round(x, 0 , 1)
      end

      if activePage == 2 then
        isScreenDirty = true
      end
    end

    volumePolls[i].time = 0.15
    volumePolls[i]:start()
  end

  -- looper
  looper = Looper.new({
    inputLevel = 1.0,
    overdubLevel = 0.0,
    chL = 1,
    chR = 2,
    voiceL = 1,
    voiceR = 2,
    bufferL = 1,
    bufferR = 2
  })

  looper.recordingPattern = transport:createPattern()
  looper.recordingPattern:set_division(1/4)
  looper.recordingPattern:set_action(function ()
    if looper.isRecording then
      looper:stopRecording()
      looper.recordingPattern:stop()
      looper:playLooper()
    else
      looper:setLoop(looper.loopLength)
      looper:startRecording()
    end
  end)
  looper:setLoopLength(2)
  looper.recordingPattern:stop()

  clickTrackPattern = transport:createPattern()
  clickTrackPattern:set_division(1)
  clickTrackPattern:set_action(function()
    if isClickTrackEnabled then
      print("click")
    end
  end)

  clickTrackPattern:start()

  ------------------------------------------
  -- Softcut callbacks
  softcut.phase_quant(1,0.01)
  softcut.event_phase(function(i, pos)
    bufferPosition = (pos - 1) / 100
    if activePage == 3 then
      isScreenDirty = true
    end
  end)
  softcut.poll_start_phase()
  softcut.event_position(function(i, pos)
    if i == looper.voiceL then
      looper.lastPlaybackPosition = pos
      isScreenDirty = true
    end
  end)

  softcut.event_render(function(ch, start, dur, samples)
    if ch == looper.bufferL then
      looper.bufferSamplesL = samples
    elseif ch == looper.bufferR then
      looper.bufferSamplesR = samples
    end
    isScreenDirty = true
  end)

  initGridEvents()

  gridRedrawTimer = metro.init(function() setGridLeds() end, 1/30, -1)
  gridRedrawTimer:start()

  screenRedrawTimer = metro.init(function() redraw() end, 1/30, -1)
  screenRedrawTimer:start()

  -- Reset transport to get all lattice patterns to trigger correctly
  transport:reset()
  transport:stop()
end

function clock.tempo_change_handler()
  looper:setLoopLength(looper.loopLength)
end

function key(n,z)
  -- key actions: n = number, z = state
  if z == 1 then
    if n == 2 then
    elseif n == 3 then
    end
  end
  isScreenDirty = true
end

function enc(n,d)
  -- encoder actions: n = number, d = delta
  if n == 1 then
    activePage = util.clamp(activePage + d, 1, MaxPages)
    pages:set_index_delta(d, false)
  else
    if n == 2 then
    else
    end

  end
  redraw()
end

function initGridEvents()
  -- shift button
  table.insert(gridEvents, GridEvent:new({
    positions = {{8, 8}},
    actionStates = {1, 0},
    shiftStates = {true, false},
    action = function(x, y, state)
      shift = not shift
    end,
    render = function()
      if shift == true then
        g:led(8, 8, 10)
      else
        g:led(8, 8, 5)
      end
    end
  }))

  -- play button
  table.insert(gridEvents, GridEvent:new({
    positions = {{1, 8}},
    actionStates = {1},
    shiftStates = {false},
    action = function(x, y, state)
      playIcon:set_status(1)
      if not transport.isPlaying then
        looper:startRecordingBuffer()
        transport:play()
      end
    end,
    render = function()
      if transport.isPlaying then
        if transport:getPosition() // 96 % 2 == 0 then
          g:led(1, 8, 15)
        else
          g:led(1, 8, 10)
        end
      else
        g:led(1, 8, 4)
      end
    end
  }))

  -- pause/stop button
  table.insert(gridEvents, GridEvent:new({
    positions = {{2, 8}},
    actionStates = {1},
    shiftStates = {false},
    action = function(x, y, state)
      if transport.isPlaying == false then
        playIcon:set_status(4)
        transport:reset()
        looper:resetBufferPosition()
      else
        playIcon:set_status(3)
        transport:stop()
        if looper.isRecording then
          looper:stopRecordingBuffer()
        else
          looper:stopPlayingBuffer()
        end
      end
    end,
    render = function()
      if transport.isPlaying then
        g:led(2, 8, 4)
      else
        g:led(2, 8, 15)
        if transport:getPosition() == 0 then
          g:led(2, 8, 2)
        end
      end
    end
  }))

  -- clear buffer
  table.insert(gridEvents, GridEvent:new({
    positions = {{2, 8}},
    actionStates = {1},
    shiftStates = {true},
    action = function(x, y, state)
      looper:clearBuffer()
    end,
    render = function()
      g:led(2, 8, 10)
    end
  }))

  -- loop size
  table.insert(gridEvents, GridEvent:new({
    positions = {{1, 1}, {2, 1}, {3, 1}, {4, 1}},
    actionStates = {1},
    shiftStates = {false},
    action = function(x, y, state)
      -- looper:setLoopLength(x)
      print("loop length ", LoopLengths[looper.loopLength], "bars")
    end,
    render = function()
      for i = 1, NumLoopLengths, 1 do
        if i ~= looper.loopLength then
          g:led(i, 1, 4)
        end
        g:led(looper.loopLength, 1, 10)
      end
    end
  }))

  -- mixer controls
  table.insert(gridEvents, GridEvent:new({
    positions = {{1, 1}, {2, 1}, {3, 1}, {4, 1},
                 {1, 2}, {2, 2}, {3, 2}, {4, 2},
                 {1, 3}, {2, 3}, {3, 3}, {4, 3},
                 {1, 4}, {2, 4}, {3, 4}, {4, 4},
                 {1, 5}, {2, 5}, {3, 5}, {4, 5},
                },
    actionStates = {1},
    shiftStates = {true},
    action = function(x, y, state)
      if x == 1 and state == 1 then
        -- mute/monitor button?
        if y <= 6 then
          looper:setInputLevel(1 - util.linlin(1, 6, 0.0, 1.0, y))
        end
      end
      if x == 2 and state == 1 then
        -- mute/monitor button?
        if y <= 6 then
          looper:setOverdubLevel(1 - util.linlin(1, 6, 0.0, 1.0, y))
        end
      end
    end,
    render = function()
      for x = 1, 6, 1 do
        for y = 1, 5 do
          g:led(x, y, 4)
          g:led(x, y, 4)
        end
      end
      -- local faderHeight = util.linlin(0.0, 1.0, 6, 1, looper.inputLevel)
      -- for i = 6, faderHeight, -1 do
      --   g:led(1, i, 13)
      -- end
      -- faderHeight = util.linlin(0.0, 1.0, 6, 1, looper.overdubLevel)
      -- for i = 6, faderHeight, -1 do
      --   g:led(2, i, 13)
      -- end
    end
  }))

  setGridLeds()
end

g.key = function(x, y, state)
  GridEvent:handleActions(gridEvents, x, y, state, shift)

  -- -- shift context menu
  -- if shift then
  -- else
  --     -- mixer


  --   -- Capture buffer controls
  --   if x == 7 and y == 8 and state == 1 then
  --     print("Triggering a buffer capture")
  --     if captureBufferPattern ~= nil then
  --       captureBufferPattern:destroy()
  --     end

  --     captureBufferPattern = transport:createPattern()
  --     captureBufferPattern:set_division(LoopLengths[looper.loopLength])
  --     captureBufferPattern:set_action(function ()
  --       print("Switched from recording to playing back the buffer")
  --       looper:stopRecordingBuffer()
  --       looper:startPlayingBuffer()
  --       captureBufferPattern:destroy()
  --       captureBufferPattern = nil
  --     end)
  --     captureBufferPattern:start()
  --   end
  -- end

  isScreenDirty = true
end

function setGridLeds()
  g:all(0)
  GridEvent:handleRender(gridEvents, shift)

  -- -- capture loop
  -- if captureBufferPattern ~= nil then
  --   g:led(7, 8, 2)
  -- else
  --   g:led(7, 8, 10)
  -- end
  g:refresh()
end

function drawVuMeter(xPos, yPos, meterHeight, meterWidth, signalPeak)
  local numTicks = 5
  local tickHeight = meterHeight/numTicks

  -- vertical left bar
  screen.move(xPos, yPos)
  screen.line_rel(0, meterHeight)
  screen.stroke()
  screen.close()

  -- top horizontal bar
  screen.move(xPos, yPos)
  screen.line_rel(meterWidth/2, 0)
  screen.stroke()
  screen.close()

  -- bottom horizontal bar
  screen.move(xPos, yPos + meterHeight)
  screen.line_rel(meterWidth/2, 0)
  screen.stroke()
  screen.close()

  -- ticks
  for i = 1, numTicks, 1 do
    screen.move(xPos, yPos + (tickHeight * i))
    screen.line_rel(meterWidth/4, 0)
  end

  -- volume
  screen.move(xPos + meterWidth/2, yPos + meterHeight)
  screen.line_rel(0, -signalPeak * meterHeight * 2.5)
  screen.stroke()
  screen.close()
end

function drawBuffer(xPos, yPos, height, width, samples)
  if samples ~= nil then
    -- scale waveform buffers to box size
    local scaledSamples = samples
    -- print(scaledSamples)

    local heightOffset = util.round(yPos + (height / 2), 1)
    local sampleXPos = xPos + 1
    local sampleHeight = 0
    screen.level(screen_levels["l"])
    for i, s in ipairs(scaledSamples) do
      -- scale sample height
      sampleHeight = util.clamp(math.abs(scaledSamples[i]) * height, 0,  height / 2 - 1)

      screen.move(sampleXPos, heightOffset)
      screen.line_rel(0, sampleHeight)
      screen.stroke()

      sampleXPos = sampleXPos + 1
    end
  end
end

function drawPageContent(index)
  screen.move(10, 7)
  screen.text(string.format("%g", clock.get_tempo()))
  screen.stroke()

  if activePage == 1 then
    -- header
    screen.move(MaxWidth, 5)
    screen.text_right("Overview")

    -- border
    screen.rect(1, 10, MaxWidth - 5, MaxHeight - 10)
    screen.stroke()
  elseif activePage == 2 then
    -- header
    screen.move(MaxWidth, 5)
    screen.text_right("Mixer")

    -- Input
    drawVuMeter(MaxWidth * 1/12, MaxHeight / 4 - 5, 40, 6, mixer.lastInVolumeL)
    drawVuMeter(MaxWidth * 2/12, MaxHeight / 4 - 5, 40, -6, mixer.lastInVolumeR)
    screen.move(MaxWidth * 3/24, MaxHeight)
    screen.text_center("In")
    
    -- Looper
    drawVuMeter(MaxWidth * 3/12, MaxHeight / 4 - 5, 40, 6, mixer.lastLoopVolumeL)
    drawVuMeter(MaxWidth * 4/12, MaxHeight / 4 - 5, 40, -6, mixer.lastLoopVolumeR)
    screen.move(MaxWidth * 7/24, MaxHeight)
    screen.text_center("Buff")

    -- Output
    drawVuMeter(MaxWidth * 5/12, MaxHeight / 4 - 5, 40, 6, mixer.lastOutVolumeL)
    drawVuMeter(MaxWidth * 6/12, MaxHeight / 4 - 5, 40, -6, mixer.lastOutVolumeR)
    screen.move(MaxWidth * 11/24, MaxHeight)
    screen.text_center("Out")

    -- Cue
    drawVuMeter(MaxWidth * 7/12, MaxHeight / 4 - 5, 40, 6,  mixer.lastOutVolumeL)
    drawVuMeter(MaxWidth * 8/12, MaxHeight / 4 - 5, 40, -6, mixer.lastOutVolumeR)
    screen.move(MaxWidth * 15/24, MaxHeight)
    screen.text_center("Cue")

  elseif activePage == 3 then
    -- header
    screen.move(MaxWidth, 5)
    screen.text_right("Buffer")

    screen.move(15, MaxHeight / 4 + MaxHeight / 8)
    screen.text_center(string.format("%d bars", LoopLengths[looper.loopLength]))

    looper:getPlayheadPosition()
    looper:getBufferWaveforms()

    -- draw border
    screen.rect(MaxWidth * 1/24, MaxHeight * 5/10, MaxWidth * 22/24, MaxHeight * 5/10)
    screen.stroke()

    drawBuffer(MaxWidth * 1/24, MaxHeight * 5/10, MaxHeight * 5/10, MaxWidth * 22/24, looper.bufferSamplesL)
    drawBuffer(MaxWidth * 1/24, MaxHeight * 5/10, MaxHeight * 5/10, MaxWidth * 22/24, looper.bufferSamplesR)

    -- playhead
    screen.level(screen_levels["h"])
    screen.move(MaxWidth * 1/24 + util.linlin(0, clock.get_beat_sec(), 0, MaxWidth * 22/24, looper.lastPlaybackPosition), MaxHeight * 5/10)
    screen.line_rel(0, MaxHeight * 5/10)
    screen.stroke()

  elseif activePage == 4 then
    screen.move(MaxWidth, 5)
    screen.text_right("FX")
  end
end

function redraw()
  -- screen redraw
  screen.clear()
  pages:redraw()
  playIcon:redraw()
  drawPageContent(activePage)
  screen.update()
  setGridLeds()
end
