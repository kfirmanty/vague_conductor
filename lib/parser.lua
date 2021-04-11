-- UTILS

table.filter = function(t, pred)
   local out = {}
   for i, v in pairs(t) do
      if pred(v, i, t) then
         table.insert(out, v)
      end
   end
   return out
end

function is_empty(s)
   return s == nil or s == ''
end

-- PARSER

function error(reason)
   return {reason = reason}
end

function is_error(v)
   return type(v) == 'table' and v.reason ~= nil 
end

function parse_as(tag, parser)
   return function(text)
      local result, rest = parser(text)
      if(is_error(result)) then
         return result, rest
      else
         result.tag = tag
         return result, rest
      end
   end
end

function consume(tag, text, pattern)
   --print('[consume] tag: ' .. tag .. ' text: ' .. text .. ' pattern: ' .. pattern)
   local matched=string.match(text, pattern)
   local rest=string.gsub(text, pattern, '', 1)
   if( is_empty(matched)) then
      return error('failed to match ' .. tag .. ' in: ' .. text), text
   end
   --print('[consume] match = ' .. matched .. ' rest = ' .. rest)
   return {match = matched, tag = tag}, rest
end

function number(text)
   return consume('number', text, '%d+')
end

function ws(text)
   return consume('whitespace', text, '%s+')
end

function sh(parser)
   --silence output - return nil. right now should only be used inside combine_and
   return function(text)
      local result, rest = parser(text)
      if(is_error(result)) then
         return result, rest
      else
         return nil, rest
      end
   end
end

function sh_ws(text)
   return sh(ws)(text)
end

function word(tag, word)
   return function(text)
      return consume(tag, text, word)
   end
end

function sh_word(tag, word_literal)
   return sh(word(tag, word_literal))
end

function combine_or(...)
   local args = {...}
   return function (text)
      local result, rest
      for i, v in ipairs(args) do
         result, rest = v(text)
         if(not is_error(result)) then
            return result, rest
         end
      end
      return result, rest
   end
end

function combine_and(tag, ...)
   local args = {...}
   return function (text)
      local results = {}
      local result, rest
      rest = text
      for i, v in ipairs(args) do
         result, rest = v(rest)
         if(is_error(result)) then
            return result, rest
         end
         if(result ~= nil) then
            results[result.tag] = result.match
         end
      end
      return {tag = tag, match = results}, rest
   end
end

function one_of_words(tag, ...)
   local args = {...}
   local words = {}
   for i, w in ipairs(args) do
      table.insert(words, word(tag, w))
   end
   return combine_or(table.unpack(words))
end

function optional(consumer)
   return function(text)
      local result, rest = consumer(text)
      if(is_error(result)) then
         return {match= '', tag = 'unmatched_optional'}, text
      else
         return result, rest
      end
   end
end

function parse(text, ...)
   local parsers = {...}
   local result, rest
   rest = text
   results = {}
   for i, v in ipairs(parsers) do
      if(is_empty(rest)) then
         return results, rest
      end
      result,rest = v(rest)
      if(is_error(result)) then
         return result, rest
      end
      results[result.tag] = result.match
   end
   return results, rest
end

local duration_parser = one_of_words('duration', 'short', 'medium', 'long')
local quantity_parser = one_of_words('quantity', 'few', 'a lot of', 'some')

local scale_type = one_of_words('scale_type', 'minor', 'major')
local scale_key = one_of_words('scale_key', 'c', 'd', 'e', 'f', 'g', 'a', 'b',
                               'cs', 'ds', 'fs', 'gs', 'as')
local scale_parser = combine_and('scale_desc', optional(combine_and(scale_key, sh_ws)),
                                 scale_type, sh_ws, sh_word('decor', 'scale'), sh_ws)

local pause_parser = combine_and('pause_desc', duration_parser, sh_ws, sh_word('decor', 'pauses'))


local play_parser = combine_and('play_section',
                                sh_word('decor', 'play'),
                                sh_ws, parse_as('repetitions', combine_or(number, quantity_parser)), sh_ws,
                                duration_parser, sh_ws, sh_word('decor', 'notes'))

--play 3 short notes with short pauses and high volume
--play 3 long notes with short pauses
--play 10 notes with minor scale

function rand_int(min, max)
   return math.floor(math.random(min, max))
end

function duration_to_val(desc)
   local fns = {short = function() return rand_int(1, 4) end,
                medium = function() return rand_int(4, 8) end,
                long = function() return rand_int(8, 16) end}
   return fns[desc]()
end

function quantity_to_val(desc)
   local fns = {few = function() return rand_int(0, 4) end,
                some = function() return rand_int(4, 8) end}
   fns['a lot of'] = function() return rand_int(8, 16) end
   if(fns[desc]) then
      return fns[desc]()
   else
      return tonumber(desc)
   end
end

function listen(text)
   return parse(text, play_parser)
end

function scale_key_to_root(scale_key)
   if(scale_key == nil) then
      return 0
   end
   local keys = {c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11,
                 cs = 1, ds = 3, fs = 6, gs = 8, as = 10}
   return keys[scale_key]
end

function scale_mode_to_notes(scale_mode)
   if(scale_mode == nil) then
      scale_mode = 'chromatic'
   end
   local modes = {chromatic = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11},
                  minor = {0, 2, 3, 5, 7, 8, 10},
                  major = {0, 2, 4, 5, 7, 9, 11}}
   return modes[scale_mode]
end

function play_section(parsed, options)
   local repetitions = quantity_to_val(parsed.repetitions)
   local commands = {}
   for i=1,repetitions do
      table.insert(commands, {command = 'play', duration = duration_to_val(parsed.duration), note = rand_int(24, 60)})
      table.insert(commands, {command = 'pause', duration = rand_int(1, 4)})
   end
   return commands
end

--listen
--execute
