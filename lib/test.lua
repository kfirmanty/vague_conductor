lu = require('luaunit')
require 'parser'
local inspect = require 'inspect'

function test_scale_parser()
   local result, rest = parse('C minor scale', scale_parser)
   lu.assertFalse(is_error(result))
   lu.assertEquals(result, {
                      scale_desc = {
                         scale_key = {
                            scale_key = "C"
                         },
                         scale_type = "minor"
   }})

   result, rest = parse('minor scale', scale_parser)
   lu.assertFalse(is_error(result))
   lu.assertEquals(result, {
                      scale_desc = {
                         scale_type = "minor"}})
end

function test_zero_or_more_parser()
   local result, rest = parse('F minor scale and short pauses and low medium octave span', options_parser)
   print('options ' .. inspect(result))
end

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
   lu.assertEquals(result.play_section,
                   {duration = "long",
                    repetitions = "some"})

   result, rest = listen('play 3 short notes')
   print(inspect(result))
   lu.assertFalse(is_error(result))
   local commands = play_section(result.play_section)
   lu.assertEquals(#commands, 6)

   result, rest = listen('play 3 short notes with C minor scale')
   lu.assertFalse(is_error(result))
   print(inspect(result))
   local commands = play_section(result.play_section)
   lu.assertEquals(#commands, 6)

   result, rest = listen('play 2 short notes with long pauses')
   lu.assertFalse(is_error(result))
   print(inspect(result))
   local commands = play_section(result.play_section)
   lu.assertEquals(#commands, 4)


   result, rest = listen('play some long notes with C major scale and short pauses')
   lu.assertFalse(is_error(result))
   print(inspect(result))
   lu.assertEquals(result.play_section,
                   {
                      duration = "long",
                      options = {
                         pause_desc = {
                            duration = "short"
                         },
                         scale_desc = {
                            scale_key = {
                               key = "C"
                            },
                            scale_type = "major"
                         }
                      },
                      repetitions = "some"})
end

os.exit(lu.LuaUnit.run())
