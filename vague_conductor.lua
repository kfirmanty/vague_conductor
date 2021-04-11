engine.name = "PolyPerc"

local keyb = hid.connect()
local keycodes = include('lib/keycodes')
include('lib/parser')

local text = 'play 6 short notes'
local cursor = string.len(text)
local enter_text_mode = true
local commands = {}
local clock_id = -1
local command_index = 1
local shift = false

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
         clock.sync(cmd.duration/8)
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

function string.insert(str1, str2, pos)
    return str1:sub(1,pos)..str2..str1:sub(pos+1)
end

function keyb.event(typ, code, val)
   local menu = norns.menu.status()
   local k = get_key(code, val, shift)
   if(typ == 1 and code == 28 and val == 1 and enter_text_mode) then
      local parsed, rest = listen(text)
      if(not is_error(parsed)) then
         commands = play_section(parsed.play_section)
         enter_text_mode = false
      end
   elseif(code == 42) then
     shift = val > 0
   elseif(typ == 1 and code == 1 and val == 1) then
      enter_text_mode = true
   elseif(typ == 1 and code == 14 and val == 1) then
      -- text = string.sub(text, 1, -2)
      text = text:sub(1, cursor-1) .. text:sub(cursor+1)
      cursor = math.min(cursor-1, string.len(text))
   elseif(typ == 1 and (code == 106 or code == 105) and val == 1) then
      if(code == 105) then
      cursor = math.max(cursor - 1, 1)
      else 
        cursor = math.min(cursor + 1, string.len(text) + 1)
      end
   elseif(k ~= nil) then
      text = string.insert(text, k, cursor - 1)
      --text = text .. k
      cursor = cursor + 1
   end
   --print('typ ' .. typ .. ' code ' .. code .. ' val ' .. val)
end

function init()
   engine.release(0.1)
   local metro_redraw = metro.init( function() redraw() end, 1 / 30)
   screen.font_size(8)
   metro_redraw:start()
   clock.transport.start()
end

function redraw()
   screen.clear()
   if(enter_text_mode) then
local current_y = 10
     local current_x = 0
      for i=1, string.len(text) do
        if(i % 25 == 0) then
          current_y = current_y + 16
          current_x = 0
          screen.move(0, current_y)
        end
          if(i == cursor) then
                  screen.level(16)
            else
                screen.level(8)
          end
          screen.move(current_x, current_y)
          screen.text(text:sub(i,i))
          current_x = current_x + 5
      end
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
