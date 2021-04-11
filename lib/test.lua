lu = require('luaunit')
require 'parser'
local inspect = require 'inspect'

function test_simple_play_notes()
   local result, rest = listen('play 3 short notes')
   lu.assertFalse(is_error(result))

   result, rest = listen('play a lot of long notes')
   lu.assertFalse(is_error(result))
end

function test_with_section()
   local result, rest = listen('play 3 short notes with short pauses')
   lu.assertFalse(is_error(result))

   result, rest = listen('play 3 short notes with major scale')
   lu.assertFalse(is_error(result))
end

function test_zero_or_more_parser()
   local result, rest = parse('test test test ', zero_or_more('tests', combine_and('test_section', word('decor', 'test'), sh_ws)))
   lu.assertFalse(is_error(result))
end

function test_play_section_parsing()
   local result, rest = listen('play 3 short notes')
   local parsed = play_section(result[1])
   lu.assertEquals(parsed.command, 'play')
   lu.assertEquals(parsed.repetitions, 3)
   lu.assertTrue(parsed.duration >= 1 and parsed.duration <= 4)
end

os.exit( lu.LuaUnit.run() )
