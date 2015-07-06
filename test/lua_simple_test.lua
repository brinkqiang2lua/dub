--[[------------------------------------------------------

  dub.LuaBinder
  -------------

  Test basic binding with the 'simple' class.

--]]------------------------------------------------------
local lub = require 'lub'
local lut = require 'lut'
local should = lut.Test('dub.LuaBinder - simple', {coverage = false})

local Simple, Map, SubMap, reg

local dub = require 'dub'
local binder = dub.LuaBinder {L = 'Ls'} -- custom 'L' state name.
local custom_bindings = {
  Map = {
    -- DO NOT THROW HERE !!
    set_suffix = [[
// <self> "key" value
const char *s = luaL_checkstring(Ls, -1);
self->setVal(key, s);
]],
    get_suffix = [[
// <self> "key"
std::string v;
if (self->getVal(key, &v)) {
lua_pushlstring(Ls, v.data(), v.length());
return 1;
}
]],
  },
}

local base = lub.path('|')
local ins = dub.Inspector {
  INPUT   = base .. '/fixtures/simple/include',
  doc_dir = base .. '/tmp',
}

--=============================================== TESTS
function should.autoload()
  assertType('table', dub.LuaBinder)
end

function should.bindClass()
  local Simple = ins:find('Simple')
  local res
  assertPass(function()
    res = binder:bindClass(Simple)
  end)
  assertMatch('luaopen_Simple', res)
end

function should.bindConstructor()
  local Simple = ins:find('Simple')
  local res = binder:bindClass(Simple)
  local ctor = Simple:method('Simple')
  assertMatch('"new"[ ,]+Simple_Simple', res)
  -- garbage collect new
  local res = binder:functionBody(Simple, ctor)
  assertMatch('pushudata[^\n]+, true%);', res)
end

function should.bindDestructor()
  local Simple = ins:find('Simple')
  local dtor   = Simple:method('~Simple')
  local res = binder:bindClass(Simple)
  assertMatch('Simple__Simple', res)
  local res = binder:functionBody(Simple, dtor)
  assertMatch('DubUserdata %*userdata = [^\n]+"Simple"', res)
  assertMatch('if %(userdata%->gc%)', res)
  assertMatch('Simple %*self = %(Simple %*%)userdata%->ptr;', res)
  assertMatch('delete self;', res)
  assertMatch('userdata%->gc = false;', res)
end

function should.bindStatic()
  local Simple = ins:find('Simple')
  local met = Simple:method('pi')
  local res = binder:bindClass(Simple)
  assertMatch('pi', res)
  local res = binder:functionBody(Simple, met)
  assertNotMatch('self', res)
  assertEqual('pi', binder:bindName(met))
end

function should.buildGetSet()
  binder.custom_bindings = custom_bindings
  local Map = ins:find('Map')
  local res = binder:bindClass(Map)
  assertMatch('self%->getVal%(key, &v%)', res)
  assertMatch('self%->setVal%(key, s%)', res)
end

local function makeSignature(met)
  local res = {}
  for param in met:params() do
    table.insert(res, param.lua.type)
  end
  return res
end

function should.resolveTypes()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  binder:resolveTypes(met)
  assertValueEqual({
    'number',
    'number',
  }, makeSignature(met))
  assertEqual('number, number', met.lua_signature)

  met = Simple:method('mul')
  binder:resolveTypes(met)
  assertValueEqual({
    'userdata',
  }, makeSignature(met))
  assertEqual('Simple', met.lua_signature)
end

function should.resolveReturnValue()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  binder:resolveTypes(met)
  assertEqual('number', met.return_value.lua.type)
end

function should.useArgCountWhenDefaults()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  local res = binder:functionBody(Simple, met)
  assertMatch('lua_gettop%(Ls%)', res)
end

function should.properlyBindStructParam()
  local Simple = ins:find('Simple')
  local met = Simple:method('showBuf')
  local res = binder:functionBody(Simple, met)
  assertMatch('Simple::MyBuf %*buf = %*%(%(Simple::MyBuf %*%*%)', res)
  assertMatch('self%->showBuf%(%*buf%)', res)
end

function should.properlyBindClassByValue()
  local Simple = ins:find('Simple')
  local met = Simple:method('showSimple')
  local res = binder:functionBody(Simple, met)
  assertMatch('Simple %*p = %*%(%(Simple %*%*%)', res)
  assertMatch('self%->showSimple%(%*p%)', res)
end

function should.resolveStructTypes()
  local Simple = ins:find('Simple')
  local met = Simple:method('showBuf')
  binder:resolveTypes(met)
  assertValueEqual({
    'userdata',
  }, makeSignature(met))
  assertEqual('MyBuf', met.lua_signature)
end

local function treeTest(tree)
  local res = {}
  if tree.type == 'dub.Function' then
    return tree.argsstring
  else
    res.pos = tree.pos
    for k, v in pairs(tree.map) do
      res[k] = treeTest(v)
    end
  end
  return res
end

function should.makeOverloadedDecisionTree()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  local tree, need_top = binder:decisionTree(met.overloaded)
  assertValueEqual({
    ['1'] = {
      pos    = 1,
      number = '(MyFloat v, double w=10)',
      Simple = '(const Simple &o)',
    },
    ['2'] = '(MyFloat v, double w=10)',
  }, treeTest(tree))
  -- need_top because we have defaults
  assertTrue(need_top)
end

function should.makeOverloadedNestedResolveTree()
  local Simple = ins:find('Simple')
  local met = Simple:method('mul')
  local tree, need_top = binder:decisionTree(met.overloaded)
  assertValueEqual({
    ['2'] = {
      pos    = 2,
      number = '(double d, double d2)',
      string = '(double d, const char *c)',
    },
    ['1'] = '(const Simple &o)',
    ['0'] = '()',
  }, treeTest(tree))
  assertTrue(need_top)
end

function should.favorArgSizeInDecisionTree()
  local Simple = ins:find('Simple')
  local met = Simple:method('testA')
  local tree, need_top = binder:decisionTree(met.overloaded)
  assertValueEqual({
    ['2'] = '(Bar *b, double d)',
    ['1'] = '(Foo *f)',
  }, treeTest(tree))
  -- need_top because we have defaults
  assertTrue(need_top)
end

function should.useArgTypeToSelect()
  local Simple = ins:find('Simple')
  local met = Simple:method('testB')
  local tree, need_top = binder:decisionTree(met.overloaded)
  assertValueEqual({
    ['2'] = {
      pos = 2,
      number = {
        pos = 1,
        Foo = '(Foo *f, double d)',
        Bar = '(Bar *b, double d)',
      },
      string = '(Bar *b, const char *c)',
    },
  }, treeTest(tree))
  assertFalse(need_top)
end

--=============================================== method name

function should.useCustomNameInBindings()
  local Map = ins:find('Map')
  local m = Map:method('foo')
  local res = binder:functionBody(Map, m)
  assertMatch('self%->foo%(x%)', res)
  local res = binder:bindClass(Map)
  -- Should use bound name in error warnings.
  assertMatch("bar: %%s", res)
  assertMatch("bar: Unknown exception", res)
  assertMatch('"bar" *, Map_foo', res)
  assertMatch('"bar" *, Map_foo', res)
end

--=============================================== Overloaded

function should.haveOverloadedList()
  local Simple = ins:find('Simple')
  local met = Simple:method('mul')
  binder:resolveTypes(met)
  local res = {}
  for _, m in ipairs(met.overloaded) do
    table.insert(res, m.lua_signature)
  end
  assertValueEqual({
    'Simple',
    'number, string',
    'number, number',
    '',
  }, res)
end

function should.haveOverloadedListWithDefaults()
  local Simple = ins:find('Simple')
  local met = Simple:method('add')
  local res = {}
  for _, m in ipairs(met.overloaded) do
    table.insert(res, m.lua_signature)
  end
  assertValueEqual({
    'number, number',
    'Simple',
  }, res)
end

--=============================================== Build

function should.bindCompileAndLoad()
  local ins = dub.Inspector(base .. '/fixtures/simple/include')

  -- create tmp directory
  local tmp_path = base .. '/tmp'
  lub.rmTree(tmp_path, true)
  os.execute("mkdir -p "..tmp_path)
  binder:bind(ins, {
    output_directory = tmp_path,
    custom_bindings  = custom_bindings,
    only = {
      'Simple',
      'Map',
      'SubMap',
    },
  })
  binder:bind(ins, {
    output_directory = tmp_path,
    single_lib = 'reg',
    only = {
      'reg::Reg',
    },
  })
  
  local cpath_bak = package.cpath
  local s
  assertPass(function()
    binder:build {
      output   = base .. '/tmp/Simple.so',
      inputs   = {
        base .. '/tmp/dub/dub.cpp',
        base .. '/tmp/Simple.cpp',
      },
      includes = {
        base .. '/tmp',
        -- This is for lua.h
        base .. '/tmp/dub',
        base .. '/fixtures/simple/include',
      },
    }

    binder:build {
      output   = base .. '/tmp/Map.so',
      inputs   = {
        base .. '/tmp/dub/dub.cpp',
        base .. '/tmp/Map.cpp',
      },
      includes = {
        base .. '/tmp',
        -- This is for lua.h
        base .. '/tmp/dub',
        base .. '/fixtures/simple/include',
      },
    }

    binder:build {
      output   = base .. '/tmp/SubMap.so',
      inputs   = {
        base .. '/tmp/dub/dub.cpp',
        base .. '/tmp/SubMap.cpp',
      },
      includes = {
        base .. '/tmp',
        -- This is for lua.h
        base .. '/tmp/dub',
        base .. '/fixtures/simple/include',
      },
    }

    binder:build {
      output   = base .. '/tmp/reg.so',
      inputs   = {
        base .. '/tmp/dub/dub.cpp',
        base .. '/tmp/reg.cpp',
        base .. '/tmp/reg_Reg.cpp',
      },
      includes = {
        base .. '/tmp',
        -- This is for lua.h
        base .. '/tmp/dub',
        base .. '/fixtures/simple/include',
      },
    }
    package.cpath = base .. '/tmp/?.so'
    Simple = require 'Simple'
    assertType('table', Simple)
    Map = require 'Map'
    assertType('table', Map)
    SubMap = require 'SubMap'
    assertType('table', SubMap)
    reg = require 'reg'
    assertType('table', reg)
  end, function()
    -- teardown
    package.cpath = cpath_bak
    if not Simple or not Map then
      lut.Test.abort = true
    end
  end)
  --lk.rmTree(tmp_path, true)
end

--=============================================== Simple tests

function should.buildObjectByCall()
  local s = Simple(1.4)
  assertType('userdata', s)
  assertEqual(1.4, s:value())
  assertEqual(Simple, getmetatable(s))
end

function should.buildObjectWithNew()
  local s = Simple.new(1.4)
  assertType('userdata', s)
  assertEqual(Simple, getmetatable(s))
end

function should.haveType()
  local s = Simple(1.4)
  assertEqual("Simple", s.type)
end

function should.haveDefaultToString()
  local s = Simple(1.4)
  assertMatch('Simple: 0x[0-9a-f]+', s:__tostring())
  assertEqual("Simple", s.type)
end

function should.bindNumber()
  local s = Simple(1.4)
  assertEqual(1.4, s:value())
end

function should.bindBoolean()
  assertFalse(Simple(1):isZero())
  assertTrue(Simple(0):isZero())
end

function should.bindMethodWithoutReturn()
  local s = Simple(3.4)
  s:setValue(5)
  assertEqual(5, s:value())
end

function should.raiseErrorOnMissingParam()
  assertError('lua_simple_test.lua:[0-9]+: new: expected number, found no value', function()
    Simple()
  end)
end

function should.handleDefaultValues()
  local s = Simple(2.4)
  assertEqual(14, s:add(4))
end

function should.callOverloaded()
  local s = Simple(2.4)
  local s2 = s:add(Simple(10))
  assertEqual(0, s:mul())
  assertEqual(14.8, s:mul(s2):value())
  assertEqual(11.4, s:mul(3, 'foobar'))
  assertEqual(28, s:mul(14, 2))
  assertEqual(13, s:addAll(3, 4, 6))
  assertEqual(16, s:addAll(3, 4, 6, "foo"))
end

function should.properlyHandleErrorMessagesInOverloaded()
  local s = Simple(2.4)
  assertError('addAll: expected string, found nil', function()
    s:addAll(3, 4, 6, nil)
  end)
  assertError('addAll: expected string, found boolean', function()
    s:addAll(3, 4, 6, true)
  end)
end

function should.useCustomGetSet()
  local m = Map()
  m.animal = 'Cat'
  assertEqual('Cat', m.animal)
  assertNil(m.thing)
  m.thing  = 'Stone'
  assertEqual('Cat', m.animal)
  assertValueEqual({
    animal = 'Cat',
    thing  = 'Stone',
  }, m:map())
end

function should.useCustomGetSet()
  local m = SubMap()
  m.animal = 'Cat'
  assertEqual('Cat', m.animal)
  assertNil(m.thing)
  m.thing  = 'Stone'
  assertEqual('Cat', m.animal)
  assertValueEqual({
    animal = 'Cat',
    thing  = 'Stone',
  }, m:map())
end

--=============================================== custom name

function should.useCustomName()
  local m = Map()
  assertEqual(5, m:bar(5))
end

--=============================================== registration name

function should.registerWithRegistrationName()
  -- require done after build.
  assertNil(reg.Reg)
  assertType('table', reg.Reg_core)
  local r = reg.Reg_core('hey')
  -- Should recognize r as Reg type
  local r2 = reg.Reg_core(r)
  assertEqual('hey', r2:name())
end

should:test()
