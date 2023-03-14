local util = require "util"
local softcut = require "softcut"

local Looper = {}

BufferWaveFormSize = 128
LoopLengths = {2, 4, 8, 16}
NumLoopLengths = 4

function Looper:new(args)
  local l = setmetatable({}, { __index = Looper })
  local args = args == nil and {} or args
  l.inputLevel = args.inputLevel == nil and 1 or args.inputLevel
  l.overdubLevel = args.overdubLevel == nil and 1 or args.overdubLevel
  l.chL = args.chL == nil and 1 or args.chL
  l.chR = args.chR == nil and 2 or args.chR
  l.voiceL = args.voiceL == nil and 1 or args.voiceL
  l.voiceR = args.voiceR == nil and 2 or args.voiceR
  l.bufferL = args.bufferL == nil and 1 or args.bufferL
  l.bufferR = args.bufferR == nil and 2 or args.bufferR
  l.loopLength = 1
  l.recordingPattern = nil
  l.isRecording = false
  l.lastVolumeL = 0
  l.lastVolumeR = 0
  l.lastPlaybackPosition = 1
  l.bufferSamplesL = {}
  l.bufferSamplesR = {}

  l:init()
  return l
end

function Looper:init()
  softcut.enable(self.voiceL, 1)
  softcut.enable(self.voiceR, 1)
  softcut.buffer(self.voiceL, self.bufferL)
  softcut.buffer(self.voiceR, self.bufferR)
  softcut.level(self.voiceL, 1.0)
  softcut.level(self.voiceR, 1.0)
  softcut.pan(self.voiceL, -1)
  softcut.pan(self.voiceR, 1)
  softcut.voice_sync(self.voiceL, self.voiceR, 0)

  self:setRecordLevel(1)
  self:setRate(1)
  self:enableLoop()
  self:resetBufferPosition()
  self:setInputLevel(1)
  self:setOverdubLevel(0)
end

function Looper:setInputLevel(newLevel)
  self.inputLevel = util.clamp(newLevel, 0, 1.0)
  print("input level = ", self.inputLevel)
  softcut.level_input_cut(self.chL, self.voiceL, self.inputLevel)
  softcut.level_input_cut(self.chR, self.voiceR, self.inputLevel)
end

function Looper:setOverdubLevel(newLevel)
  self.overdubLevel = util.clamp(newLevel, 0, 1.0)
  print("overdub level = ", self.overdubLevel)
  softcut.pre_level(self.voiceL, util.clamp(self.overdubLevel, 0, 1))
  softcut.pre_level(self.voiceR, util.clamp(self.overdubLevel, 0, 1))
end

function Looper:setLoopLength(newLength)
  self.loopLength = util.clamp(newLength, 1, NumLoopLengths)
  self.recordingPattern:set_division(LoopLengths[self.loopLength])
  softcut.loop_start(self.voiceL, 1)
  softcut.loop_start(self.voiceR, 1)
  softcut.loop_end(self.voiceL, clock.get_beat_sec() * LoopLengths[self.loopLength] * 4)
  softcut.loop_end(self.voiceR, clock.get_beat_sec() * LoopLengths[self.loopLength] * 4)
end

function Looper:startRecordingBuffer()
  print("Starting record buffer")
  self.isRecording = true
  softcut.rec(self.voiceL, 1)
  softcut.rec(self.voiceR, 1)
end

function Looper:stopRecordingBuffer()
  print("Stopping record buffer")
  self.isRecording = false
  softcut.rec(self.voiceL, 0)
  softcut.rec(self.voiceR, 0)
end

function Looper:resetBufferPosition()
  print("Reset buffer position")
  softcut.position(self.voiceL, 1)
  softcut.position(self.voiceR, 1)
end

function Looper:startPlayingBuffer()
  print("Playing buffer")
  softcut.play(self.voiceL, 1)
  softcut.play(self.voiceR, 1)
end

function Looper:stopPlayingBuffer()
  print("Stopping buffer")
  softcut.play(self.voiceL, 0)
  softcut.play(self.voiceR, 0)
end

function Looper:setRecordLevel(amp)
  softcut.rec_level(self.voiceL, util.clamp(amp, 0, 1))
  softcut.rec_level(self.voiceR, util.clamp(amp, 0, 1))
end

function Looper:enableLoop()
  softcut.loop(self.voiceL, 1)
  softcut.loop(self.voiceR, 1)
end

function Looper:disableLoop()
  softcut.play(self.voiceL, 0)
  softcut.play(self.voiceR, 0)
end

function Looper:getPlayheadPosition()
  softcut.query_position(self.voiceL)
end

function Looper:setRate(newRate)
  softcut.rate(self.voiceL, util.clamp(newRate, -1, 2))
  softcut.rate(self.voiceR, util.clamp(newRate, -1, 2))
end

function Looper:getBufferWaveforms()
  -- LoopLengths[self.loopLength]
  softcut.render_buffer(self.bufferL, 1, clock.get_beat_sec() * LoopLengths[self.loopLength] * 4, BufferWaveFormSize)
  softcut.render_buffer(self.bufferR, 1, clock.get_beat_sec() * LoopLengths[self.loopLength] * 4, BufferWaveFormSize)
end

function Looper:clearBuffer()
  print("cleared buffers", self.chL, " and ", self.chR)
  softcut.buffer_clear_channel(self.chL)
  softcut.buffer_clear_channel(self.chR)
end

return Looper