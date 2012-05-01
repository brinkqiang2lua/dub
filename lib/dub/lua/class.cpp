/**
 *
 * MACHINE GENERATED FILE. DO NOT EDIT.
 *
 * Bindings for class {{class.name}}
 *
 * This file has been generated by dub {{dub.VERSION}}.
 */
#include "dub/dub.h"
{% for h in self:headers(class) do %}
#include "{{self:header(h)}}"
{% end %}

{% if class:namespace() then %}
using namespace {{class:namespace().name}};
{% end %}

{% for method in class:methods() do %}
/** {{method:nameWithArgs()}}
 * {{method.location}}
 */
static int {{class.name}}_{{method.cname}}(lua_State *L) {
{% if method:neverThrows() then %}

  {| self:functionBody(class, method) |}
{% else %}
  try {
    {| self:functionBody(class, method) |}
  } catch (std::exception &e) {
    lua_pushfstring(L, "{{method.name}}: %s", e.what());
  } catch (...) {
    lua_pushfstring(L, "{{method.name}}: Unknown exception");
  }
  return dub_error(L);
{% end %}
}

{% end %}

{% if not class:method('__tostring') then %}

// --=============================================== __tostring
static int {{class.name}}___tostring(lua_State *L) {
  {| self:toStringBody(class) |}
  return 1;
}
{% end %}

// --=============================================== METHODS

static const struct luaL_Reg {{class.name}}_member_methods[] = {
{% for method in class:methods() do %}
  { {{string.format('%-15s, %-20s', '"'..self:bindName(method)..'"', class.name .. '_' .. method.cname)}} },
{% end %}
{% if not class:method('__tostring') then %}
  { {{string.format('%-15s, %-20s', '"__tostring"', class.name .. '___tostring')}} },
{% end %}
  { "deleted"      , dub_isDeleted        },
  { NULL, NULL},
};

{% if class.has_constants then %}
// --=============================================== CONSTANTS
static const struct dub_const_Reg {{class.name}}_const[] = {
{% for const in class:constants() do %}
  { {{string.format('%-15s, %-20s', '"'.. const ..'"', class.name..'::'..const)}} },
{% end %}
  { NULL, 0},
};
{% end %}

extern "C" int luaopen_{{self:openName(class)}}(lua_State *L)
{
  // Create the metatable which will contain all the member methods
  luaL_newmetatable(L, "{{self:libName(class)}}");
  // <mt>
{% if class.has_constants then %}
  // register class constants
  dub_register_const(L, {{class.name}}_const);
{% end %}

  // register member methods
  luaL_register(L, NULL, {{ class.name }}_member_methods);
  // save meta-table in {{self:libName(class.parent)}}
  dub_register(L, "{{self:libName(class.parent)}}", "{{class.dub.register or self:name(class)}}", "{{self:name(class)}}");
  // <mt>
  lua_pop(L, 1);
  return 0;
}
