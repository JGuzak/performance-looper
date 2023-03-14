-- Transport holds info on 
lattice = require "lattice"

local Transport = {}

function Transport:new()
  local t = setmetatable({}, { __index = Transport })
  t.isPlaying = false
  -- TODO: add other lattice for pattern loop length
  t.tLattice = lattice:new()
  t.tLattice:stop()

  t.sendClock = false
  t.quarterNoteHearbeat = t.tLattice:new_pattern()
  t.quarterNoteHearbeat:set_division(1/4)
  t.quarterNoteHearbeat:set_action(function ()
    -- print(t:getPosition())
    if t:getPosition() % 384 == 0 then
      print("bar")
    else
      print("1/4")
    end
  end)
  return t
end

function Transport:playStop()
  if self.isPlaying then
    print("stopping transport lattice")
    self.isPlaying = false
    self.tLattice:stop()
  else
    print("starting transport lattice")
    self.isPlaying = true
    self.tLattice:start()
  end
end

function Transport:play()
  print("starting transport lattice")
  self.tLattice:start()
  self.isPlaying = true
end

function Transport:stop()
  print("stopping transport lattice")
  self.tLattice:stop()
  self.isPlaying = false
end

function Transport:reset()
  print("resetting transport lattice")
  self.tLattice:reset()
  self.isPlaying = false
  self.quarterNoteHearbeat:start()
end

function Transport:createPattern()
  return self.tLattice:new_pattern{}
end

function Transport:getPosition()
  return self.tLattice.transport
end

function Transport:hardReset()
  self.tLattice.hard_restart()
end

return Transport