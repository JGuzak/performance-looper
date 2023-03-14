-- key
-- grid x trigger
-- grid y trigger
-- shift action state
-- action callback
-- render action state
-- render callback

-- gridMap = {
--   ["channel_A_loop_size_4"]  = {4,1},
--   ["play_button"]    = {1,8},
--   ["pause_button"]    = {1,8},
--   ["channel_A_clear_buffer"] = {15,12},
-- }

local GridEvent = {}


function GridEvent:new(args)
  local gridEvent = setmetatable({}, { __index = GridEvent })
  local args = args == nil and {} or args
  gridEvent.positions = args.positions == nil and {{1, 1}} or args.positions
  gridEvent.actionStates = args.actionStates == nil and {1} or args.actionStates
  gridEvent.shiftStates = args.shiftStates == nil and {false} or args.shiftStates
  gridEvent.action = args.action == nil and function() end or args.action
  gridEvent.render = args.render == nil and function() end or args.render
  return gridEvent
end

function GridEvent:containsPosition(x, y)
  for k, coordinates in ipairs(self.positions) do
    if coordinates[1] == x and coordinates[2] == y then
        return true
    end
end
return false
end

function GridEvent:containsActionState(state)
  for i, value in ipairs(self.actionStates) do
      if value == state then
          return true
      end
  end
  return false
end

function GridEvent:containsShiftState(state)
  for i, value in ipairs(self.shiftStates) do
      if value == state then
          return true
      end
  end
  return false
end

function GridEvent:handleActions(events, x, y, state, shift)
  for i, v in ipairs(events) do
    if events[i]:containsPosition(x, y) and
       events[i]:containsActionState(state) and
       events[i]:containsShiftState(shift) then
        events[i].action()
    end
  end
end

function GridEvent:handleRender(events, shift)
  for i, v in ipairs(events) do
    if events[i]:containsShiftState(shift) then
      events[i].render()
    end
  end
end

return GridEvent