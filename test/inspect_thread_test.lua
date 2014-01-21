--[[------------------------------------------------------

  dub.Inspector test
  ------------------

  Test introspective operations with the 'thread' group
  of classes.

--]]------------------------------------------------------
require 'lubyk'
local should = test.Suite('dub.Inspector - thread')

local ins = dub.Inspector {
  INPUT    = 'test/fixtures/thread',
  doc_dir  = lk.scriptDir() .. '/tmp',
  keep_xml = true,
}

local Callback = ins:find('Callback')
--=============================================== TESTS

function should.useCustomPush()
  assertEqual('dub_pushobject', Callback.dub.push)
end

test.all()


