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

function test_play_section_parsing()
   local result, rest = listen('play some long notes')
   lu.assertFalse(is_error(result))
   local play = result.play_section
   lu.assertEquals(play,
                   {duration = "long",
                    repetitions = "some"})


   result, rest = listen('play 3 short notes')
   lu.assertFalse(is_error(result))
   local commands = play_section(result.play_section)
   lu.assertEquals(#commands, 6)
end

os.exit(lu.LuaUnit.run())
