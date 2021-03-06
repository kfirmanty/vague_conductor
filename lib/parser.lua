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
   local matched = string.match(text, pattern)
   local rest = string.gsub(text, pattern, '', 1)
   local index_of = string.find(text,pattern)
   if(is_empty(matched) or index_of ~= 1) then
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
         if(result ~= nil and result.tag ~= 'unmatched_optional') then
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

function zero_or_more(tag, parser)
   return function (text)
      local results = {}
      local result, rest
      rest = text
      repeat
         result, rest = parser(rest)
         if(not is_error(result) and result ~= nil and result.tag ~= 'unmatched_optional') then
            results[result.tag] = result.match
         end
         if(is_error(result) or rest == nil or is_empty(rest)) then
            return {tag = tag, match = results}, rest
         end
      until(false)
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
      if(result ~= nil and result.tag ~= 'unmatched_optional') then
         results[result.tag] = result.match
      end
   end
   return results, rest
end

duration_parser = one_of_words('duration', 'short', 'medium', 'long')
quantity_parser = one_of_words('quantity', 'few', 'a lot of', 'some')

scale_type = one_of_words('scale_type', 'minor', 'major', 'phrygian', 'majpent', 'minpent')
scale_key = one_of_words('key', 'C', 'D', 'E', 'F', 'G', 'A', 'B',
                         'CS', 'DS', 'FS', 'GS', 'AS')
scale_parser = combine_and('scale_desc',
                           optional(sh_ws), optional(sh_word('decor', 'and')), optional(sh_ws),
                           optional(combine_and('scale_key', scale_key, sh_ws)),
                           scale_type, sh_ws, sh_word('decor', 'scale'))

pause_parser = combine_and('pause_desc',
                           optional(sh_ws), optional(sh_word('decor', 'and')), optional(sh_ws),
                           duration_parser, sh_ws, sh_word('decor', 'pauses'))
                         
octave_parser = combine_and('octave_desc',
                           optional(sh_ws), optional(sh_word('decor', 'and')), optional(sh_ws),
                           optional(one_of_words('frequency', 'low', 'middle', 'high')), optional(sh_ws),
                           one_of_words('span', 'narrow', 'medium', 'wide'), sh_ws, 
                           sh_word('decor', 'octave'), sh_ws, sh_word('decor', 'span'))

options_parser = zero_or_more('options', combine_or(scale_parser, pause_parser, octave_parser))

play_parser = combine_and('play_section',
                          sh_word('decor', 'play'),
                          sh_ws, parse_as('repetitions', combine_or(number, quantity_parser)), sh_ws,
                          duration_parser, sh_ws, sh_word('decor', 'notes'),
                          optional(sh_ws), optional(sh_word('decor', 'with')), optional(sh_ws),
                          options_parser)

--play 3 short notes with short pauses and high volume
--play 3 long notes with short pauses
--play 10 notes with minor scale

function rand_int(min, max)
   return math.floor(math.random(min, max))
end

function duration_to_val(desc)
   local fns = {short = function() return rand_int(1, 4) end,
                medium = function() return rand_int(4, 12) end,
                long = function() return rand_int(12, 24) end}
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

function octave_frequency_to_val(desc)
   local fns = {low = function() return rand_int(0, 1) end,
                middle = function() return rand_int(2, 3) end,
                high = function() return rand_int(4, 5) end}
      return fns[desc]()
end

function octave_span_to_val(desc)
   local fns = {narrow = function() return rand_int(0, 1) end,
                medium = function() return rand_int(2, 3) end,
                wide = function() return rand_int(4, 5) end}
      return fns[desc]()
end

function listen(text)
   return parse(text, play_parser)
end

function scale_key_to_root(scale_key)
   if(scale_key == nil) then
      return 0
   end
   local keys = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11,
                 CS = 1, DS = 3, FS = 6, GS = 8, AS = 10}
   return keys[scale_key]
end

function scale_type_to_scale(scale_type)
   if(scale_type == nil) then
      scale_type = 'chromatic'
   end
   local modes = {chromatic = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11},
                  minor = {0, 2, 3, 5, 7, 8, 10},
                  major = {0, 2, 4, 5, 7, 9, 11},
                  phrygian = {0, 1, 4, 5, 7, 8, 10},
                  minpent = {0, 3, 5, 7, 10},
                  majpent = {0, 4, 5, 7, 11}}
   return modes[scale_type]
end

function rand_note(scale, root, base_octave, octave_span)
   local octave = rand_int(0, octave_span)
   local index = rand_int(1, #scale)
   return (root + scale[index]) + (base_octave * 12) + (octave * 12)
end

function play_section(parsed)
   local repetitions = quantity_to_val(parsed.repetitions)
   local commands = {}
   local options = parsed.options
   local default_scale_desc = {scale_type = 'chromatic',
                               scale_key = {key = 'C'}}
   local default_pause_desc = {duration = 'short'}
   local default_octave_desc = {frequency = 'low',
                                span = 'narrow'}
   if(options == nil) then
      options = {scale_desc = default_scale_desc,
                 pause_desc = default_pause_desc,
                 octave_desc = default_octave_desc}
   end
   local scale_desc = options.scale_desc
   if(scale_desc == nil) then
      scale_desc = default_scale_desc
   end
   
   if(scale_desc.scale_key == nil) then
      scale_desc.scale_key = default_scale_desc.scale_key
   end
   
   local scale = scale_type_to_scale(scale_desc.scale_type)
   local scale_root = scale_key_to_root(scale_desc.scale_key.key)
   
   local pause_desc = options.pause_desc
   if(pause_desc == nil) then
      pause_desc = default_pause_desc
   end
   
   local octave_desc = options.octave_desc
   if(octave_desc == nil) then
      octave_desc = default_octave_desc
   elseif(octave_desc.frequency == nil) then
      octave_desc.frequency = default_octave_desc.frequency
   end
   for i=1,repetitions do
      table.insert(commands, {command = 'play',
                              duration = duration_to_val(parsed.duration),
                              note = rand_note(scale, scale_root,
                                               octave_frequency_to_val(octave_desc.frequency),
                                               octave_span_to_val(octave_desc.span))})
      table.insert(commands, {command = 'pause', duration = duration_to_val(pause_desc.duration)})
   end
   return commands
end

--listen
--execute
