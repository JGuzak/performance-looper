
local audio = require "audio"
local util = require "util"
local softcut = require "softcut"

local Mixer = {}


function Mixer:new(args)
  local m = setmetatable({}, { __index = Mixer })
  local args = args == nil and {} or args
  -- m.voice = args.voice == nil and 1 or args.voice
  m.lastIoVolumes = {}
  m.lastLoopVolumes = {}

  m:init()
  return m
end

function Mixer:init()
  audio.comp_off()
  audio.level_adc(1)
  audio.level_dac(1)
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  audio.level_cut(1)
  audio.level_tape(1)
  audio.level_tape_cut(1)
end

return Mixer