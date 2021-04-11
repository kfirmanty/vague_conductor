engine.name = "PolyPerc"

local keyb = hid.connect()
local keycodes = include('lib/keycodes')
include('lib/parser')

local text = 'play 6 medium notes'
local enter_text_mode = true
local commands = {}
local clock_id = -1
local command_index = 1

local function midi_to_hz(note)
   return (440 / 32) * (2 ^ ((note - 9) / 12))
end

local function execute_commands()
   while true do
      for i, cmd in ipairs(commands) do
         command_index = i
         if(cmd.command == 'play') then
            print('play note ' .. cmd.note .. ' with duration ' .. cmd.duration)
            engine.release(cmd.duration/4)
            engine.hz(midi_to_hz(cmd.note))
         end
         clock.sync(cmd.duration/4)
      end
      commands = {}
      enter_text_mode = true
      clock.sync(1/4)
   end
end

function clock.transport.start()
   clock_id = clock.run(execute_commands)
end

function clock.transport.stop()
   clock.cancel(clock_id)
end

local function get_key(code, val, shift)
   local c, s = keycodes.keys[code], keycodes.shifts[code]
   if c ~= nil and val == 1 then
      if shift then if s ~= nil then return s
      else return c end
      else return string.lower(c) end
   end
end

function keyb.event(typ, code, val)
   local menu = norns.menu.status()
   local k = get_key(code, val, false)
   if(typ == 1 and code == 28 and val == 1 and enter_text_mode) then
      local parsed, rest = listen(text)
      if(not is_error(parsed)) then
         commands = play_section_sequence(parsed[1])
         enter_text_mode = false
      end
   elseif(typ == 1 and code == 1 and val == 1) then
      enter_text_mode = true
   elseif(typ == 1 and code == 14 and val == 1) then
      text = string.sub(text, 1, -2)
   elseif(k ~= nil) then
      text = text .. k
   end
   -- print('typ ' .. typ .. ' code ' .. code .. ' val ' .. val)
end

function init()
   engine.release(0.1)
   local metro_redraw = metro.init( function() redraw() end, 1 / 30)
   metro_redraw:start()
   clock.transport.start()
end

function redraw()
   screen.clear()
   if(enter_text_mode) then
      screen.move(0,40)
      screen.level(15)
      screen.text(text)
   else
      local x = 0
      for i, cmd in ipairs(commands) do
         if(cmd.command == 'play') then
            screen.rect(x, 0, cmd.duration, cmd.note)
         end
         local level = 5
         if(cmd.command == 'play') then
            level = level + 5
         end 
         if(command_index == i) then
            level = level + 5
         end
         screen.level(level)
         screen.stroke()
         x = x + cmd.duration + 2
      end
   end
   screen.update()
end
