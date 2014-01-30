--[[------------------------------------------------------
param_
  dub.LuaBinder
  -------------

  Test binding with the 'inherit' group of classes:

    * binding attributes accessor with super attributes.
    * binding methods from super classes.
    * custom bindings.
    * cast to super type when needed.

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local dub = require 'dub'

local should = lut.Test('dub.LuaBinder - inherit', {coverage = false})
local binder = dub.LuaBinder()

local ins = dub.Inspector {
  INPUT    = lub.path '|fixtures/inherit',
  doc_dir  = lub.path '|tmp',
}

local Child, Parent, Orphan

function should.setup()
  dub.warn = dub.silentWarn
end

function should.teardown()
  dub.warn = dub.printWarn
end

--=============================================== Set/Get vars.
function should.bindSetMethodWithSuperAttrs()
  -- __newindex for simple (native) types
  local Child = ins:find('Child')
  local set = Child:method(Child.SET_ATTR_NAME)
  local res = binder:bindClass(Child)
  assertMatch('__newindex.*Child__set_', res)
  local res = binder:functionBody(Child, set)
  assertMatch('self%->birth_year = luaL_checknumber%(L, 3%);', res)
end

function should.bindGetMethodWithSuperAttrs()
  -- __newindex for simple (native) types
  local Child = ins:find('Child')
  local get = Child:method(Child.GET_ATTR_NAME)
  local res = binder:bindClass(Child)
  assertMatch('__index.*Child__get_', res)
  local res = binder:functionBody(Child, get)
  assertMatch('lua_pushnumber%(L, self%->birth_year%);', res)
end

function should.bindCastWithTemplateParent()
  -- __newindex for simple (native) types
  local Orphan = ins:find('Orphan')
  local met = Orphan:method(Orphan.CAST_NAME)
  local res = binder:functionBody(Orphan, met)
  assertMatch('%*retval__ = static_cast<Foo< int > %*>%(self%);', res)
end

function should.notBindSuperStaticMethods()
  local Child = ins:find('Child')
  local res = binder:bindClass(Child)
  assertNotMatch('getName', res)
end

--=============================================== Unknown type

function should.properlyBindUnknownTypes()
  local Child = ins:find('Child')
  local met = Child:method('methodWithUnknown')
  local res = binder:functionBody(Child, met)
  assertMatch('Unk1 %*x = %*%(%(Unk1 %*%*%)dub::checksdata%(L, 2, "Unk1"%)%);', res)
  assertMatch('Unk2 %*y = %*%(%(Unk2 %*%*%)dub::checksdata%(L, 3, "Unk2"%)%);', res)
  assertMatch('methodWithUnknown%(%*x, y%)', res)
end

--=============================================== Compile

function should.bindCompileAndLoad()
  local tmp_path = lub.path '|tmp'
  -- create tmp directory
  lub.rmTree(tmp_path, true)
  os.execute('mkdir -p '..tmp_path)

  binder:bind(ins, {
    output_directory = lub.path '|tmp',
    custom_bindings  = lub.path '|fixtures/inherit',
    extra_headers = {
      Child = {
        lub.path "|fixtures/inherit_hidden/Mother.h",
      }
    }
  })

  local cpath_bak = package.cpath
  local s
  assertPass(function()
    -- Build Child.so
    --
    binder:build {
      output   = lub.path '|tmp/Child.so',
      inputs   = {
        lub.path '|tmp/dub/dub.cpp',
        lub.path '|tmp/Child.cpp',
        lub.path '|fixtures/inherit/child.cpp',
      },
      includes = {
        lub.path '|tmp',
        -- This is for lua.h
        lub.path '|tmp/dub',
        lub.path '|fixtures/inherit',
      },
    }

    -- Build Parent.so
    binder:build {
      output   = lub.path '|tmp/Parent.so',
      inputs   = {
        lub.path '|tmp/dub/dub.cpp',
        lub.path '|tmp/Parent.cpp',
      },
      includes = {
        lub.path '|tmp',
        -- This is for lua.h
        lub.path '|tmp/dub',
        lub.path '|fixtures/inherit',
      },
    }

    -- Build Orphan.so
    binder:build {
      output   = lub.path '|tmp/Orphan.so',
      inputs   = {
        lub.path '|tmp/dub/dub.cpp',
        lub.path '|tmp/Orphan.cpp',
      },
      includes = {
        lub.path '|tmp',
        -- This is for lua.h
        lub.path '|tmp/dub',
        lub.path '|fixtures/inherit',
      },
    }

    package.cpath = tmp_path .. '/?.so'
    Child  = require 'Child'
    Parent = require 'Parent'
    Orphan = require 'Orphan'
    assertType('table', Child)
  end, function()
    -- teardown
    package.loaded.Child  = nil
    package.loaded.Parent = nil
    package.cpath = cpath_bak
    if not Child then
      lut.Test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Inheritance

function should.createChildObject()
  local c = Child('Romulus', Parent.Depends, -771, 1.23, 2.34)
  assertType('userdata', c)
end

function should.readChildAttributes()
  local c = Child('Romulus', Parent.Single, -771, 1.23, 2.34)
  assertEqual(-771, c.birth_year)
  assertTrue(c.happy)
  assertEqual(Child.Single)
  assertNil(c.asdfasd)
end

function should.writeChildAttributes()
  local c = Child('Romulus', Parent.Poly, -771, 1.23, 2.34)
  assertError("invalid key 'asdfasd'", function()
    c.asdfasd = 15
  end)
  c.birth_year = 2000
  assertEqual(2000, c.birth_year)
  c.status = Parent.Single
  assertEqual(Parent.Single, c.status)
end

function should.executeSuperMethods()
  local c = Child('Romulus', Parent.Poly, -771, 1.23, 2.34)
  assertEqual(2783, c:computeAge(2012))
end

--=============================================== Cast

function should.castInCalls()
  local c = Child('Romulus', Parent.Married, -771, 1.23, 2.34)
  local p = Parent('Rhea', Parent.Single, -800)
  assertEqual('Romulus', Parent.getName(c))
  assertEqual('Rhea', Parent.getName(p))
end

--=============================================== Custom bindings

function should.useCustomBindings()
  local c = Child('Romulus', Parent.Depends, -771, 1.23, 2.34)
  local x, y = c:position()
  assertEqual(1.23, x)
  assertEqual(2.34, y)
end

function should.useCustomBindingsWithDefaultValue()
  local c = Child('Romulus', Parent.Depends, -771, 1.23, 2.34)
  assertEqual(5.23, c:addToX())
  assertEqual(2.23, c:addToX(1))
end

--=============================================== Unknown types

function should.useUnknownTypes()
  local w = dub.warn
  dub.warn = function() end
    local c = Child('Romulus', Parent.Depends, -771, 1.23, 2.34)
    local f, b = c:returnUnk1(4), c:returnUnk2(5)
  dub.warn = w
  assertEqual(9, c:methodWithUnknown(f, b))
end

should:test()

