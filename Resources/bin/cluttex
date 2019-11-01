#!/usr/bin/env texlua
local io, os, string, table, package, require, assert, error, ipairs, type, select, arg = io, os, string, table, package, require, assert, error, ipairs, type, select, arg
local CLUTTEX_VERBOSITY, CLUTTEX_VERSION
os.type = os.type or "unix"
if lfs and not package.loaded['lfs'] then package.loaded['lfs'] = lfs end
if os.type == "windows" then
package.preload["texrunner.pathutil"] = function(...)
--[[
  Copyright 2016 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

-- pathutil module

local assert = assert
local select = select
local string = string
local string_find = string.find
local string_sub = string.sub
local string_match = string.match
local string_gsub = string.gsub
local filesys = require "lfs"

local function basename(path)
  local i = 0
  while true do
    local j = string_find(path, "[\\/]", i + 1)
    if j == nil then
      return string_sub(path, i + 1)
    elseif j == #path then
      return string_sub(path, i + 1, -2)
    end
    i = j
  end
end


local function dirname(path)
  local i = 0
  while true do
    local j = string_find(path, "[\\/]", i + 1)
    if j == nil then
      if i == 0 then
        -- No directory portion
        return "."
      elseif i == 1 then
        -- Root
        return string_sub(path, 1, 1)
      else
        -- Directory portion without trailing slash
        return string_sub(path, 1, i - 1)
      end
    end
    i = j
  end
end


local function parentdir(path)
  local i = 0
  while true do
    local j = string_find(path, "[\\/]", i + 1)
    if j == nil then
      if i == 0 then
        -- No directory portion
        return "."
      elseif i == 1 then
        -- Root
        return string_sub(path, 1, 1)
      else
        -- Directory portion without trailing slash
        return string_sub(path, 1, i - 1)
      end
    elseif j == #path then
      -- Directory portion without trailing slash
      return string_sub(path, 1, i - 1)
    end
    i = j
  end
end


local function trimext(path)
  return (string_gsub(path, "%.[^\\/%.]*$", ""))
end


local function ext(path)
  return string_match(path, "%.([^\\/%.]*)$") or ""
end


local function replaceext(path, newext)
  local newpath, n = string_gsub(path, "%.([^\\/%.]*)$", function() return "." .. newext end)
  if n == 0 then
    return newpath .. "." .. newext
  else
    return newpath
  end
end


local function joinpath2(x, y)
  local xd = x
  local last = string_sub(x, -1)
  if last ~= "/" and last ~= "\\" then
    xd = x .. "\\"
  end
  if y == "." then
    return xd
  elseif y == ".." then
    return dirname(x)
  else
    if string_match(y, "^%.[\\/]") then
      return xd .. string_sub(y, 3)
    else
      return xd .. y
    end
  end
end

local function joinpath(...)
  local n = select("#", ...)
  if n == 2 then
    return joinpath2(...)
  elseif n == 0 then
    return "."
  elseif n == 1 then
    return ...
  else
    return joinpath(joinpath2(...), select(3, ...))
  end
end


-- https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx
local function isabspath(path)
  local init = string_sub(path, 1, 1)
  return init == "\\" or init == "/" or string_match(path, "^%a:[/\\]")
end

local function abspath(path, cwd)
  if isabspath(path) then
    -- absolute path
    return path
  else
    -- TODO: relative path with a drive letter is not supported
    cwd = cwd or filesys.currentdir()
    return joinpath2(cwd, path)
  end
end

return {
  basename = basename,
  dirname = dirname,
  parentdir = parentdir,
  trimext = trimext,
  ext = ext,
  replaceext = replaceext,
  join = joinpath,
  abspath = abspath,
}
end
else
package.preload["texrunner.pathutil"] = function(...)
--[[
  Copyright 2016 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

-- pathutil module for *nix

local assert = assert
local select = select
local string = string
local string_find = string.find
local string_sub = string.sub
local string_match = string.match
local string_gsub = string.gsub
local filesys = require "lfs"

local function basename(path)
  local i = 0
  while true do
    local j = string_find(path, "/", i + 1, true)
    if j == nil then
      return string_sub(path, i + 1)
    elseif j == #path then
      return string_sub(path, i + 1, -2)
    end
    i = j
  end
end


local function dirname(path)
  local i = 0
  while true do
    local j = string_find(path, "/", i + 1, true)
    if j == nil then
      if i == 0 then
        -- No directory portion
        return "."
      elseif i == 1 then
        -- Root
        return "/"
      else
        -- Directory portion without trailing slash
        return string_sub(path, 1, i - 1)
      end
    end
    i = j
  end
end


local function parentdir(path)
  local i = 0
  while true do
    local j = string_find(path, "/", i + 1, true)
    if j == nil then
      if i == 0 then
        -- No directory portion
        return "."
      elseif i == 1 then
        -- Root
        return "/"
      else
        -- Directory portion without trailing slash
        return string_sub(path, 1, i - 1)
      end
    elseif j == #path then
      -- Directory portion without trailing slash
      return string_sub(path, 1, i - 1)
    end
    i = j
  end
end


local function trimext(path)
  return (string_gsub(path, "%.[^/%.]*$", ""))
end


local function ext(path)
  return string_match(path, "%.([^/%.]*)$") or ""
end


local function replaceext(path, newext)
  local newpath, n = string_gsub(path, "%.([^/%.]*)$", function() return "." .. newext end)
  if n == 0 then
    return newpath .. "." .. newext
  else
    return newpath
  end
end


local function joinpath2(x, y)
  local xd = x
  if string_sub(x, -1) ~= "/" then
    xd = x .. "/"
  end
  if y == "." then
    return xd
  elseif y == ".." then
    return dirname(x)
  else
    if string_sub(y, 1, 2) == "./" then
      return xd .. string_sub(y, 3)
    else
      return xd .. y
    end
  end
end

local function joinpath(...)
  local n = select("#", ...)
  if n == 2 then
    return joinpath2(...)
  elseif n == 0 then
    return "."
  elseif n == 1 then
    return ...
  else
    return joinpath(joinpath2(...), select(3, ...))
  end
end


local function abspath(path, cwd)
  if string_sub(path, 1, 1) == "/" then
    -- absolute path
    return path
  else
    cwd = cwd or filesys.currentdir()
    return joinpath2(cwd, path)
  end
end


return {
  basename = basename,
  dirname = dirname,
  parentdir = parentdir,
  trimext = trimext,
  ext = ext,
  replaceext = replaceext,
  join = joinpath,
  abspath = abspath,
}
end
end
if os.type == "windows" then
package.preload["texrunner.shellutil"] = function(...)
--[[
  Copyright 2016,2019 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

local string_gsub = string.gsub
local os_execute = os.execute

-- s: string
local function escape(s)
  return '"' .. string_gsub(string_gsub(s, '(\\*)"', '%1%1\\"'), '(\\+)$', '%1%1') .. '"'
end


local function has_command(name)
  local result = os_execute("where " .. escape(name) .. " > NUL 2>&1")
  -- Note that os.execute returns a number on Lua 5.1 or LuaTeX
  return result == 0 or result == true
end

return {
  escape = escape,
  has_command = has_command,
}
end
else
package.preload["texrunner.shellutil"] = function(...)
--[[
  Copyright 2016,2019 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

local assert = assert
local string_match = string.match
local table = table
local table_insert = table.insert
local table_concat = table.concat
local os_execute = os.execute

-- s: string
local function escape(s)
  local len = #s
  local result = {}
  local t,i = string_match(s, "^([^']*)()")
  assert(t)
  if t ~= "" then
    table_insert(result, "'")
    table_insert(result, t)
    table_insert(result, "'")
  end
  while i < len do
    t,i = string_match(s, "^('+)()", i)
    assert(t)
    table_insert(result, '"')
    table_insert(result, t)
    table_insert(result, '"')
    t,i = string_match(s, "^([^']*)()", i)
    assert(t)
    if t ~= "" then
      table_insert(result, "'")
      table_insert(result, t)
      table_insert(result, "'")
    end
  end
  return table_concat(result, "")
end


local function has_command(name)
  local result = os_execute("which " .. escape(name) .. " > /dev/null")
  -- Note that os.execute returns a number on Lua 5.1 or LuaTeX
  return result == 0 or result == true
end

return {
  escape = escape,
  has_command = has_command,
}
end
end
package.preload["texrunner.fsutil"] = function(...)
--[[
  Copyright 2016 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

local assert = assert
local os = os
local os_execute = os.execute
local os_remove = os.remove
local filesys = require "lfs"
local pathutil = require "texrunner.pathutil"
local shellutil = require "texrunner.shellutil"
local escape = shellutil.escape

local copy_command
if os.type == "windows" then
  function copy_command(from, to)
    -- TODO: What if `from` begins with a slash?
    return "copy " .. escape(from) .. " " .. escape(to) .. " > NUL"
  end
else
  function copy_command(from, to)
    -- TODO: What if `from` begins with a hypen?
    return "cp " .. escape(from) .. " " .. escape(to)
  end
end

local isfile = filesys.isfile or function(path)
  return filesys.attributes(path, "mode") == "file"
end

local isdir = filesys.isdir or function(path)
  return filesys.attributes(path, "mode") == "directory"
end

local function mkdir_rec(path)
  local succ, err = filesys.mkdir(path)
  if not succ then
    succ, err = mkdir_rec(pathutil.parentdir(path))
    if succ then
      return filesys.mkdir(path)
    end
  end
  return succ, err
end

local function remove_rec(path)
  if isdir(path) then
    for file in filesys.dir(path) do
      if file ~= "." and file ~= ".." then
        local succ, err = remove_rec(pathutil.join(path, file))
        if not succ then
          return succ, err
        end
      end
    end
    return filesys.rmdir(path)
  else
    return os_remove(path)
  end
end

return {
  copy_command = copy_command,
  isfile = isfile,
  isdir = isdir,
  mkdir_rec = mkdir_rec,
  remove_rec = remove_rec,
}
end
package.preload["texrunner.option"] = function(...)
--[[
  Copyright 2016 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

-- options_and_params, i = parseoption(arg, options)
-- options[i] = {short = "o", long = "option" [, param = true] [, boolean = true] [, allow_single_hyphen = false]}
-- options_and_params[j] = {"option", "value"}
-- arg[i], arg[i + 1], ..., arg[#arg] are non-options
local function parseoption(arg, options)
  local i = 1
  local option_and_params = {}
  while i <= #arg do
    if arg[i] == "--" then
      -- Stop handling options
      i = i + 1
      break
    elseif arg[i]:sub(1,2) == "--" then
      -- Long option
      local name,param = arg[i]:match("^([^=]+)=(.*)$", 3)
      name = name or arg[i]:sub(3)
      local opt = nil
      for _,o in ipairs(options) do
        if o.long then
          if o.long == name then
            if o.param then
              if param then
                -- --option=param
              else
                if o.default ~= nil then
                  param = o.default
                else
                  -- --option param
                  assert(i + 1 <= #arg, "argument missing after " .. arg[i] .. " option")
                  param = arg[i + 1]
                  i = i + 1
                end
              end
            else
              -- --option
              param = true
            end
            opt = o
            break
          elseif o.boolean and name == "no-" .. o.long then
            -- --no-option
            opt = o
            param = false
            break
          end
        end
      end
      if opt then
        table.insert(option_and_params, {opt.long, param})
      else
        -- Unknown long option
        error("unknown long option: " .. arg[i])
      end
    elseif arg[i]:sub(1,1) == "-" then
      local name,param = arg[i]:match("^([^=]+)=(.*)$", 2)
      name = name or arg[i]:sub(2)
      local opt = nil
      for _,o in ipairs(options) do
        if o.long and o.allow_single_hyphen then
          if o.long == name then
            if o.param then
              if param then
                -- -option=param
              else
                if o.default ~= nil then
                  param = o.default
                else
                  -- -option param
                  assert(i + 1 <= #arg, "argument missing after " .. arg[i] .. " option")
                  param = arg[i + 1]
                  i = i + 1
                end
              end
            else
              -- -option
              param = true
            end
            opt = o
            break
          elseif o.boolean and name == "no-" .. o.long then
            -- -no-option
            opt = o
            param = false
            break
          end
        elseif o.long and #name >= 2 and (o.long == name or (o.boolean and name == "no-" .. o.long)) then
          error("You must supply two hyphens (i.e. --" .. name .. ") for long option")
        end
      end
      if opt == nil then
        -- Short option
        name = arg[i]:sub(2,2)
        for _,o in ipairs(options) do
          if o.short then
            if o.short == name then
              if o.param then
                if #arg[i] > 2 then
                  -- -oparam
                  param = arg[i]:sub(3)
                else
                  -- -o param
                  assert(i + 1 <= #arg, "argument missing after " .. arg[i] .. " option")
                  param = arg[i + 1]
                  i = i + 1
                end
              else
                -- -o
                assert(#arg[i] == 2, "combining multiple short options like -abc is not supported")
                param = true
              end
              opt = o
              break
            end
          end
        end
      end
      if opt then
        table.insert(option_and_params, {opt.long or opt.short, param})
      else
        error("unknown short option: " .. arg[i])
      end
    else
      -- arg[i] is not an option
      break
    end
    i = i + 1
  end
  return option_and_params, i
end

return {
  parseoption = parseoption;
}
end
package.preload["texrunner.tex_engine"] = function(...)
--[[
  Copyright 2016 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

local table = table
local setmetatable = setmetatable
local ipairs = ipairs

local shellutil = require "texrunner.shellutil"

--[[
engine.name: string
engine.type = "onePass" or "twoPass"
engine:build_command(inputfile, options)
  options:
    halt_on_error: boolean
    interaction: string
    file_line_error: boolean
    synctex: string
    shell_escape: boolean
    shell_restricted: boolean
    jobname: string
    output_directory: string
    extraoptions: a list of strings
    output_format: "pdf" or "dvi"
    draftmode: boolean (pdfTeX / XeTeX / LuaTeX)
    fmt: string
    tex_injection: string
    lua_initialization_script: string (LuaTeX only)
engine.executable: string
engine.supports_pdf_generation: boolean
engine.dvi_extension: string
engine.supports_draftmode: boolean
engine.is_luatex: true or nil
]]

local engine_meta = {}
engine_meta.__index = engine_meta
engine_meta.dvi_extension = "dvi"
function engine_meta:build_command(inputfile, options)
  local command = {self.executable, "-recorder"}
  if options.fmt then
    table.insert(command, "-fmt=" .. options.fmt)
  end
  if options.halt_on_error then
    table.insert(command, "-halt-on-error")
  end
  if options.interaction then
    table.insert(command, "-interaction=" .. options.interaction)
  end
  if options.file_line_error then
    table.insert(command, "-file-line-error")
  end
  if options.synctex then
    table.insert(command, "-synctex=" .. shellutil.escape(options.synctex))
  end
  if options.shell_escape == false then
    table.insert(command, "-no-shell-escape")
  elseif options.shell_restricted == true then
    table.insert(command, "-shell-restricted")
  elseif options.shell_escape == true then
    table.insert(command, "-shell-escape")
  end
  if options.jobname then
    table.insert(command, "-jobname=" .. shellutil.escape(options.jobname))
  end
  if options.output_directory then
    table.insert(command, "-output-directory=" .. shellutil.escape(options.output_directory))
  end
  if self.handle_additional_options then
    self:handle_additional_options(command, options)
  end
  if options.extraoptions then
    for _,v in ipairs(options.extraoptions) do
      table.insert(command, v)
    end
  end
  if type(options.tex_injection) == "string" then
    table.insert(command, shellutil.escape(options.tex_injection .. "\\input " .. inputfile)) -- TODO: what if filename contains spaces?
  else
    table.insert(command, shellutil.escape(inputfile))
  end
  return table.concat(command, " ")
end

local function engine(name, supports_pdf_generation, handle_additional_options)
  return setmetatable({
    name = name,
    executable = name,
    supports_pdf_generation = supports_pdf_generation,
    handle_additional_options = handle_additional_options,
    supports_draftmode = supports_pdf_generation,
  }, engine_meta)
end

local function handle_pdftex_options(self, args, options)
  if options.draftmode then
    table.insert(args, "-draftmode")
  elseif options.output_format == "dvi" then
    table.insert(args, "-output-format=dvi")
  end
end

local function handle_xetex_options(self, args, options)
  if options.output_format == "dvi" or options.draftmode then
    table.insert(args, "-no-pdf")
  end
end

local function handle_luatex_options(self, args, options)
  if options.lua_initialization_script then
    table.insert(args, "--lua="..shellutil.escape(options.lua_initialization_script))
  end
  handle_pdftex_options(self, args, options)
end

local function is_luatex(e)
  e.is_luatex = true
  return e
end

local KnownEngines = {
  ["pdftex"]   = engine("pdftex", true, handle_pdftex_options),
  ["pdflatex"] = engine("pdflatex", true, handle_pdftex_options),
  ["luatex"]   = is_luatex(engine("luatex", true, handle_luatex_options)),
  ["lualatex"] = is_luatex(engine("lualatex", true, handle_luatex_options)),
  ["luajittex"] = is_luatex(engine("luajittex", true, handle_luatex_options)),
  ["xetex"]    = engine("xetex", true, handle_xetex_options),
  ["xelatex"]  = engine("xelatex", true, handle_xetex_options),
  ["tex"]      = engine("tex", false),
  ["etex"]     = engine("etex", false),
  ["latex"]    = engine("latex", false),
  ["ptex"]     = engine("ptex", false),
  ["eptex"]    = engine("eptex", false),
  ["platex"]   = engine("platex", false),
  ["uptex"]    = engine("uptex", false),
  ["euptex"]   = engine("euptex", false),
  ["uplatex"]  = engine("uplatex", false),
}

KnownEngines["xetex"].dvi_extension = "xdv"
KnownEngines["xelatex"].dvi_extension = "xdv"

return KnownEngines
end
package.preload["texrunner.reruncheck"] = function(...)
--[[
  Copyright 2016,2018 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

local io = io
local assert = assert
local filesys = require "lfs"
local md5 = require "md5"
local fsutil = require "texrunner.fsutil"
local pathutil = require "texrunner.pathutil"
local message = require "texrunner.message"

local function md5sum_file(path)
  local f = assert(io.open(path, "rb"))
  local contents = f:read("*a")
  f:close()
  return md5.sum(contents)
end

-- filelist, filemap = parse_recorder_file("jobname.fls", options [, filelist, filemap])
-- filelist[i] = {path = "...", abspath = "...", kind = "input" or "output" or "auxiliary"}
local function parse_recorder_file(file, options, filelist, filemap)
  filelist = filelist or {}
  filemap = filemap or {}
  for l in io.lines(file) do
    local t,path = l:match("^(%w+) (.*)$")
    if t == "PWD" then
      -- Ignore

    elseif t == "INPUT" then
      local abspath = pathutil.abspath(path)
      local fileinfo = filemap[abspath]
      if not fileinfo then
        if fsutil.isfile(path) then
          local kind = "input"
          local ext = pathutil.ext(path)
          if ext == "bbl" then
            kind = "auxiliary"
          end
          fileinfo = {path = path, abspath = abspath, kind = kind}
          table.insert(filelist, fileinfo)
          filemap[abspath] = fileinfo
        else
          -- Maybe a command execution
        end
      else
        if #path < #fileinfo.path then
          fileinfo.path = path
        end
        if fileinfo.kind == "output" then
          -- The files listed in both INPUT and OUTPUT are considered to be auxiliary files.
          fileinfo.kind = "auxiliary"
        end
      end

    elseif t == "OUTPUT" then
      local abspath = pathutil.abspath(path)
      local fileinfo = filemap[abspath]
      if not fileinfo then
        local kind = "output"
        local ext = pathutil.ext(path)
        if ext == "out" then
          -- hyperref bookmarks file
          kind = "auxiliary"
        elseif options.makeindex and ext == "idx" then
          -- Treat .idx files (to be processed by MakeIndex) as auxiliary
          kind = "auxiliary"
          -- ...and .ind files
        elseif ext == "bcf" then -- biber
          kind = "auxiliary"
        elseif ext == "glo" then -- makeglossaries
          kind = "auxiliary"
        end
        fileinfo = {path = path, abspath = abspath, kind = kind}
        table.insert(filelist, fileinfo)
        filemap[abspath] = fileinfo
      else
        if #path < #fileinfo.path then
          fileinfo.path = path
        end
        if fileinfo.kind == "input" then
          -- The files listed in both INPUT and OUTPUT are considered to be auxiliary files.
          fileinfo.kind = "auxiliary"
        end
      end

    else
      message.warning("Unrecognized line in recorder file '", file, "': ", l)
    end
  end
  return filelist, filemap
end

-- auxstatus = collectfileinfo(filelist [, auxstatus])
local function collectfileinfo(filelist, auxstatus)
  auxstatus = auxstatus or {}
  for i,fileinfo in ipairs(filelist) do
    local path = fileinfo.abspath
    if fsutil.isfile(path) then
      local status = auxstatus[path] or {}
      auxstatus[path] = status
      if fileinfo.kind == "input" then
        status.mtime = status.mtime or filesys.attributes(path, "modification")
      elseif fileinfo.kind == "auxiliary" then
        status.mtime = status.mtime or filesys.attributes(path, "modification")
        status.size = status.size or filesys.attributes(path, "size")
        status.md5sum = status.md5sum or md5sum_file(path)
      end
    end
  end
  return auxstatus
end

local function binarytohex(s)
  return (s:gsub(".", function(c) return string.format("%02x", string.byte(c)) end))
end

-- should_rerun, newauxstatus = comparefileinfo(auxfiles, auxstatus)
local function comparefileinfo(filelist, auxstatus)
  local should_rerun = false
  local newauxstatus = {}
  for i,fileinfo in ipairs(filelist) do
    local path = fileinfo.abspath
    if fsutil.isfile(path) then
      if fileinfo.kind == "input" then
        -- Input file: User might have modified while running TeX.
        local mtime = filesys.attributes(path, "modification")
        if auxstatus[path] and auxstatus[path].mtime then
          if auxstatus[path].mtime < mtime then
            -- Input file was updated during execution
            message.info("Input file '", fileinfo.path, "' was modified (by user, or some external commands).")
            newauxstatus[path] = {mtime = mtime}
            return true, newauxstatus
          end
        else
          -- New input file
        end

      elseif fileinfo.kind == "auxiliary" then
        -- Auxiliary file: Compare file contents.
        if auxstatus[path] then
          -- File was touched during execution
          local really_modified = false
          local modified_because = nil
          local size = filesys.attributes(path, "size")
          if auxstatus[path].size ~= size then
            really_modified = true
            if auxstatus[path].size then
              modified_because = string.format("size: %d -> %d", auxstatus[path].size, size)
            else
              modified_because = string.format("size: (N/A) -> %d", size)
            end
            newauxstatus[path] = {size = size}
          else
            local md5sum = md5sum_file(path)
            if auxstatus[path].md5sum ~= md5sum then
              really_modified = true
              if auxstatus[path].md5sum then
                modified_because = string.format("md5: %s -> %s", binarytohex(auxstatus[path].md5sum), binarytohex(md5sum))
              else
                modified_because = string.format("md5: (N/A) -> %s", binarytohex(md5sum))
              end
            end
            newauxstatus[path] = {size = size, md5sum = md5sum}
          end
          if really_modified then
            message.info("File '", fileinfo.path, "' was modified (", modified_because, ").")
            should_rerun = true
          else
            if CLUTTEX_VERBOSITY >= 1 then
              message.info("File '", fileinfo.path, "' unmodified (size and md5sum).")
            end
          end
        else
          -- New file
          if path:sub(-4) == ".aux" then
            local size = filesys.attributes(path, "size")
            if size == 8 then
              local auxfile = io.open(path, "rb")
              local contents = auxfile:read("*a")
              auxfile:close()
              if contents == "\\relax \n" then
                -- The .aux file is new, but it is almost empty
              else
                should_rerun = true
              end
              newauxstatus[path] = {size = size, md5sum = md5.sum(contents)}
            else
              should_rerun = true
              newauxstatus[path] = {size = size}
            end
          else
            should_rerun = true
          end
          if should_rerun then
            message.info("New auxiliary file '", fileinfo.path, "'.")
          else
            if CLUTTEX_VERBOSITY >= 1 then
              message.info("Ignoring almost-empty auxiliary file '", fileinfo.path, "'.")
            end
          end
        end
        if should_rerun then
          break
        end
      end
    else
      -- Auxiliary file is not really a file???
    end
  end
  return should_rerun, newauxstatus
end

-- true if src is newer than dst
local function comparefiletime(srcpath, dstpath, auxstatus)
  if not filesys.isfile(dstpath) then
    return true
  end
  local src_info = auxstatus[srcpath]
  if src_info then
    local src_mtime = src_info.mtime
    if src_mtime then
      local dst_mtime = filesys.attributes(dstpath, "modification")
      return src_mtime > dst_mtime
    end
  end
  return false
end

return {
  parse_recorder_file = parse_recorder_file;
  collectfileinfo = collectfileinfo;
  comparefileinfo = comparefileinfo;
  comparefiletime = comparefiletime;
}
end
package.preload["texrunner.auxfile"] = function(...)
--[[
  Copyright 2016 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

local string_match = string.match
local pathutil = require "texrunner.pathutil"
local filesys = require "lfs"
local fsutil = require "texrunner.fsutil"
local message = require "texrunner.message"

-- for LaTeX
local function parse_aux_file(auxfile, outdir, report, seen)
  report = report or {}
  seen = seen or {}
  seen[auxfile] = true
  for l in io.lines(auxfile) do
    local subauxfile = string_match(l, "\\@input{(.+)}")
    if subauxfile then
      if fsutil.isfile(subauxfile) then
        parse_aux_file(pathutil.join(outdir, subauxfile), outdir, report, seen)
      else
        local dir = pathutil.join(outdir, pathutil.dirname(subauxfile))
        if not fsutil.isdir(dir) then
          assert(fsutil.mkdir_rec(dir))
          report.made_new_directory = true
        end
      end
    end
  end
  return report
end

-- \citation, \bibdata, \bibstyle and \@input
local function extract_bibtex_from_aux_file(auxfile, outdir, biblines)
  biblines = biblines or {}
  for l in io.lines(auxfile) do
    local name = string_match(l, "\\([%a@]+)")
    if name == "citation" or name == "bibdata" or name == "bibstyle" then
      table.insert(biblines, l)
      if CLUTTEX_VERBOSITY >= 2 then
        message.info("BibTeX line: ", l)
      end
    elseif name == "@input" then
      local subauxfile = string_match(l, "\\@input{(.+)}")
      if subauxfile and fsutil.isfile(subauxfile) then
        extract_bibtex_from_aux_file(pathutil.join(outdir, subauxfile), outdir, biblines)
      end
    end
  end
  return biblines
end

return {
  parse_aux_file = parse_aux_file,
  extract_bibtex_from_aux_file = extract_bibtex_from_aux_file,
}
end
package.preload["texrunner.luatexinit"] = function(...)
local function create_initialization_script(filename, options)
  local initscript = assert(io.open(filename,"w"))
  if type(options.file_line_error) == "boolean" then
    initscript:write(string.format("texconfig.file_line_error = %s\n", options.file_line_error))
  end
  if type(options.halt_on_error) == "boolean" then
    initscript:write(string.format("texconfig.halt_on_error = %s\n", options.halt_on_error))
  end
  initscript:write([==[
local print = print
local io_open = io.open
local io_write = io.write
local os_execute = os.execute
local texio_write = texio.write
local texio_write_nl = texio.write_nl
]==])

  -- Packages coded in Lua doesn't follow -output-directory option and doesn't write command to the log file
  initscript:write(string.format("local output_directory = %q\n", options.output_directory))
  initscript:write([==[
local luawritelog
local function openluawritelog()
  if not luawritelog then
    luawritelog = assert(io_open(output_directory .. "/" .. tex.jobname .. ".cluttex-fls", "w"))
  end
  return luawritelog
end
io.open = function(fname, mode)
  -- luatexja-ruby
  if mode == "w" and fname == tex.jobname .. ".ltjruby" then
    fname = output_directory .. "/" .. fname
  end
  if type(mode) == "string" and string.find(mode, "w") ~= nil then
    -- write mode
    openluawritelog():write("OUTPUT " .. fname .. "\n")
  end
  return io_open(fname, mode)
end
os.execute = function(...)
  texio_write_nl("log", string.format("CLUTTEX_EXEC %s", ...), "")
  return os_execute(...)
end
]==])

  -- Silence some of the TeX output to the terminal.
  initscript:write([==[
local function start_file_cb(category, filename)
  if category == 1 then -- a normal data file, like a TeX source
    texio_write_nl("log", "("..filename)
  elseif category == 2 then -- a font map coupling font names to resources
    texio_write("log", "{"..filename)
  elseif category == 3 then -- an image file (png, pdf, etc)
    texio_write("<"..filename)
  elseif category == 4 then -- an embedded font subset
    texio_write("<"..filename)
  elseif category == 5 then -- a fully embedded font
    texio_write("<<"..filename)
  else
    print("start_file: unknown category", category, filename)
  end
end
callback.register("start_file", start_file_cb)
local function stop_file_cb(category)
  if category == 1 then
    texio_write("log", ")")
  elseif category == 2 then
    texio_write("log", "}")
  elseif category == 3 then
    texio_write(">")
  elseif category == 4 then
    texio_write(">")
  elseif category == 5 then
    texio_write(">>")
  else
    print("stop_file: unknown category", category)
  end
end
callback.register("stop_file", stop_file_cb)
texio.write = function(...)
  if select("#",...) == 1 then
    -- Suppress luaotfload's message (See src/fontloader/runtime/fontload-reference.lua)
    local s = ...
    if string.match(s, "^%(using cache: ")
       or string.match(s, "^%(using write cache: ")
       or string.match(s, "^%(using read cache: ")
       or string.match(s, "^%(load luc: ")
       or string.match(s, "^%(load cache: ") then
      return texio_write("log", ...)
    end
  end
  return texio_write(...)
end
]==])
  initscript:close()
end

return {
  create_initialization_script = create_initialization_script
}
end
package.preload["texrunner.recovery"] = function(...)
--[[
  Copyright 2018 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

local io = io
local string = string
local parse_aux_file = require "texrunner.auxfile".parse_aux_file
local pathutil       = require "texrunner.pathutil"
local fsutil         = require "texrunner.fsutil"
local shellutil      = require "texrunner.shellutil"
local message        = require "texrunner.message"

local function create_missing_directories(args)
  if string.find(args.execlog, "I can't write on file", 1, true) then
    -- There is a possibility that there are some subfiles under subdirectories.
    -- Directories for sub-auxfiles are not created automatically, so we need to provide them.
    local report = parse_aux_file(args.auxfile, args.options.output_directory)
    if report.made_new_directory then
      if CLUTTEX_VERBOSITY >= 1 then
        message.info("Created missing directories.")
      end
      return true
    end
  end
  return false
end

local function run_epstopdf(args)
  local run = false
  if args.options.shell_escape ~= false then -- (possibly restricted) \write18 enabled
    for outfile, infile in string.gmatch(args.execlog, "%(epstopdf%)%s*Command: <r?epstopdf %-%-outfile=([%w%-/]+%.pdf) ([%w%-/]+%.eps)>") do
      local infile_abs = pathutil.abspath(infile, args.original_wd)
      if fsutil.isfile(infile_abs) then -- input file exists
        local outfile_abs = pathutil.abspath(outfile, args.options.output_directory)
        if CLUTTEX_VERBOSITY >= 1 then
          message.info("Running epstopdf on ", infile, ".")
        end
        local outdir = pathutil.dirname(outfile_abs)
        if not fsutil.isdir(outdir) then
          assert(fsutil.mkdir_rec(outdir))
        end
        local command = string.format("epstopdf --outfile=%s %s", shellutil.escape(outfile_abs), shellutil.escape(infile_abs))
        message.exec(command)
        local success = os.execute(command)
        if type(success) == "number" then -- Lua 5.1 or LuaTeX
          success = success == 0
        end
        run = run or success
      end
    end
  end
  return run
end

local function check_minted(args)
  return string.find(args.execlog, "Package minted Error: Missing Pygments output; \\inputminted was") ~= nil
end

local function try_recovery(args)
  local recovered = false
  recovered = create_missing_directories(args)
  recovered = run_epstopdf(args) or recovered
  recovered = check_minted(args) or recovered
  return recovered
end

return {
  create_missing_directories = create_missing_directories,
  run_epstopdf = run_epstopdf,
  try_recovery = try_recovery,
}
end
package.preload["texrunner.handleoption"] = function(...)
local COPYRIGHT_NOTICE = [[
Copyright (C) 2016,2018-2019  ARATA Mizuki

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local pathutil     = require "texrunner.pathutil"
local shellutil    = require "texrunner.shellutil"
local parseoption  = require "texrunner.option".parseoption
local KnownEngines = require "texrunner.tex_engine"
local message      = require "texrunner.message"

local function usage(arg)
  io.write(string.format([[
ClutTeX: Process TeX files without cluttering your working directory

Usage:
  %s [options] [--] FILE.tex

Options:
  -e, --engine=ENGINE          Specify which TeX engine to use.
                                 ENGINE is one of the following:
                                     pdflatex, pdftex,
                                     lualatex, luatex, luajittex,
                                     xelatex, xetex, latex, etex, tex,
                                     platex, eptex, ptex,
                                     uplatex, euptex, uptex,
  -o, --output=FILE            The name of output file.
                                 [default: JOBNAME.pdf or JOBNAME.dvi]
      --fresh                  Clean intermediate files before running TeX.
                                 Cannot be used with --output-directory.
      --max-iterations=N       Maximum number of running TeX to resolve
                                 cross-references.  [default: 3]
      --start-with-draft       Start with draft mode.
      --[no-]change-directory  Change directory before running TeX.
      --watch                  Watch input files for change.  Requires fswatch
                                 program to be installed.
      --tex-option=OPTION      Pass OPTION to TeX as a single option.
      --tex-options=OPTIONs    Pass OPTIONs to TeX as multiple options.
      --dvipdfmx-option[s]=OPTION[s]  Same for dvipdfmx.
      --makeindex=COMMAND+OPTIONs  Command to generate index, such as
                                     `makeindex' or `mendex'.
      --bibtex=COMMAND+OPTIONs  Command for BibTeX, such as
                                     `bibtex' or `pbibtex'.
      --biber[=COMMAND+OPTIONs]  Command for Biber.
      --makeglossaries[=COMMAND+OPTIONs]  Command for makeglossaries.
  -h, --help                   Print this message and exit.
  -v, --version                Print version information and exit.
  -V, --verbose                Be more verbose.
      --color=WHEN             Make ClutTeX's message colorful. WHEN is one of
                                 `always', `auto', or `never'.  [default: auto]
      --includeonly=NAMEs      Insert '\includeonly{NAMEs}'.
      --make-depends=FILE      Write dependencies as a Makefile rule.

      --[no-]shell-escape
      --shell-restricted
      --synctex=NUMBER
      --fmt=FMTNAME
      --[no-]file-line-error   [default: yes]
      --[no-]halt-on-error     [default: yes]
      --interaction=STRING     [default: nonstopmode]
      --jobname=STRING
      --output-directory=DIR   [default: somewhere in the temporary directory]
      --output-format=FORMAT   FORMAT is `pdf' or `dvi'.  [default: pdf]

%s
]], arg[0] or 'texlua cluttex.lua', COPYRIGHT_NOTICE))
end

local option_spec = {
  -- Options for ClutTeX
  {
    short = "e",
    long = "engine",
    param = true,
  },
  {
    short = "o",
    long = "output",
    param = true,
  },
  {
    long = "fresh",
  },
  {
    long = "max-iterations",
    param = true,
  },
  {
    long = "start-with-draft",
  },
  {
    long = "change-directory",
    boolean = true,
  },
  {
    long = "watch",
  },
  {
    short = "h",
    long = "help",
    allow_single_hyphen = true,
  },
  {
    short = "v",
    long = "version",
  },
  {
    short = "V",
    long = "verbose",
  },
  {
    long = "color",
    param = true,
    default = "always",
  },
  {
    long = "includeonly",
    param = true,
  },
  {
    long = "make-depends",
    param = true
  },
  -- Options for TeX
  {
    long = "synctex",
    param = true,
    allow_single_hyphen = true,
  },
  {
    long = "file-line-error",
    boolean = true,
    allow_single_hyphen = true,
  },
  {
    long = "interaction",
    param = true,
    allow_single_hyphen = true,
  },
  {
    long = "halt-on-error",
    boolean = true,
    allow_single_hyphen = true,
  },
  {
    long = "shell-escape",
    boolean = true,
    allow_single_hyphen = true,
  },
  {
    long = "shell-restricted",
    allow_single_hyphen = true,
  },
  {
    long = "jobname",
    param = true,
    allow_single_hyphen = true,
  },
  {
    long = "fmt",
    param = true,
    allow_single_hyphen = true,
  },
  {
    long = "output-directory",
    param = true,
    allow_single_hyphen = true,
  },
  {
    long = "output-format",
    param = true,
    allow_single_hyphen = true,
  },
  {
    long = "tex-option",
    param = true,
  },
  {
    long = "tex-options",
    param = true,
  },
  {
    long = "dvipdfmx-option",
    param = true,
  },
  {
    long = "dvipdfmx-options",
    param = true,
  },
  {
    long = "makeindex",
    param = true,
  },
  {
    long = "bibtex",
    param = true,
  },
  {
    long = "biber",
    param = true,
    default = "biber",
  },
  {
    long = "makeglossaries",
    param = true,
    default = "makeglossaries",
  },
}

-- Default values for options
local function set_default_values(options)
  if options.max_iterations == nil then
    options.max_iterations = 3
  end

  if options.interaction == nil then
    options.interaction = "nonstopmode"
  end

  if options.file_line_error == nil then
    options.file_line_error = true
  end

  if options.halt_on_error == nil then
    options.halt_on_error = true
  end
end

-- inputfile, engine, options = handle_cluttex_options(arg)
local function handle_cluttex_options(arg)
  -- Parse options
  local option_and_params, non_option_index = parseoption(arg, option_spec)

  -- Handle options
  local options = {
    tex_extraoptions = {},
    dvipdfmx_extraoptions = {},
  }
  CLUTTEX_VERBOSITY = 0
  for _,option in ipairs(option_and_params) do
    local name = option[1]
    local param = option[2]

    if name == "engine" then
      assert(options.engine == nil, "multiple --engine options")
      options.engine = param

    elseif name == "output" then
      assert(options.output == nil, "multiple --output options")
      options.output = param

    elseif name == "fresh" then
      assert(options.fresh == nil, "multiple --fresh options")
      options.fresh = true

    elseif name == "max-iterations" then
      assert(options.max_iterations == nil, "multiple --max-iterations options")
      options.max_iterations = assert(tonumber(param), "invalid value for --max-iterations option")
      assert(options.max_iterations >= 1, "invalid value for --max-iterations option")

    elseif name == "start-with-draft" then
      assert(options.start_with_draft == nil, "multiple --start-with-draft options")
      options.start_with_draft = true

    elseif name == "watch" then
      assert(options.watch == nil, "multiple --watch options")
      options.watch = true

    elseif name == "help" then
      usage(arg)
      os.exit(0)

    elseif name == "version" then
      io.stderr:write("cluttex ",CLUTTEX_VERSION,"\n")
      os.exit(0)

    elseif name == "verbose" then
      CLUTTEX_VERBOSITY = CLUTTEX_VERBOSITY + 1

    elseif name == "color" then
      assert(options.color == nil, "multiple --collor options")
      options.color = param
      message.set_colors(options.color)

    elseif name == "change-directory" then
      assert(options.change_directory == nil, "multiple --change-directory options")
      options.change_directory = param

    elseif name == "includeonly" then
      assert(options.includeonly == nil, "multiple --includeonly options")
      options.includeonly = param

    elseif name == "make-depends" then
      assert(options.make_depends == nil, "multiple --make-depends options")
      options.make_depends = param

      -- Options for TeX
    elseif name == "synctex" then
      assert(options.synctex == nil, "multiple --synctex options")
      options.synctex = param

    elseif name == "file-line-error" then
      options.file_line_error = param

    elseif name == "interaction" then
      assert(options.interaction == nil, "multiple --interaction options")
      assert(param == "batchmode" or param == "nonstopmode" or param == "scrollmode" or param == "errorstopmode", "invalid argument for --interaction")
      options.interaction = param

    elseif name == "halt-on-error" then
      options.halt_on_error = param

    elseif name == "shell-escape" then
      assert(options.shell_escape == nil and options.shell_restricted == nil, "multiple --(no-)shell-escape or --shell-restricted options")
      options.shell_escape = param

    elseif name == "shell-restricted" then
      assert(options.shell_escape == nil and options.shell_restricted == nil, "multiple --(no-)shell-escape or --shell-restricted options")
      options.shell_restricted = true

    elseif name == "jobname" then
      assert(options.jobname == nil, "multiple --jobname options")
      options.jobname = param

    elseif name == "fmt" then
      assert(options.fmt == nil, "multiple --fmt options")
      options.fmt = param

    elseif name == "output-directory" then
      assert(options.output_directory == nil, "multiple --output-directory options")
      options.output_directory = param

    elseif name == "output-format" then
      assert(options.output_format == nil, "multiple --output-format options")
      assert(param == "pdf" or param == "dvi", "invalid argument for --output-format")
      options.output_format = param

    elseif name == "tex-option" then
      table.insert(options.tex_extraoptions, shellutil.escape(param))

    elseif name == "tex-options" then
      table.insert(options.tex_extraoptions, param)

    elseif name == "dvipdfmx-option" then
      table.insert(options.dvipdfmx_extraoptions, shellutil.escape(param))

    elseif name == "dvipdfmx-options" then
      table.insert(options.dvipdfmx_extraoptions, param)

    elseif name == "makeindex" then
      assert(options.makeindex == nil, "multiple --makeindex options")
      options.makeindex = param

    elseif name == "bibtex" then
      assert(options.bibtex == nil, "multiple --bibtex options")
      assert(options.biber == nil, "multiple --bibtex/--biber options")
      options.bibtex = param

    elseif name == "biber" then
      assert(options.biber == nil, "multiple --biber options")
      assert(options.bibtex == nil, "multiple --bibtex/--biber options")
      options.biber = param

    elseif name == "makeglossaries" then
      assert(options.makeglossaries == nil, "multiple --makeglossaries options")
      options.makeglossaries = param

    end
  end

  if options.color == nil then
    message.set_colors("auto")
  end

  -- Handle non-options (i.e. input file)
  if non_option_index > #arg then
    -- No input file given
    usage(arg)
    os.exit(1)
  elseif non_option_index < #arg then
    message.error("Multiple input files are not supported.")
    os.exit(1)
  end
  local inputfile = arg[non_option_index]

  -- If run as 'cllualatex', then the default engine is lualatex
  if options.engine == nil and type(arg[0]) == "string" then
    local basename = pathutil.trimext(pathutil.basename(arg[0]))
    local engine_part = string.match(basename, "^cl(%w+)$")
    if engine_part and KnownEngines[engine_part] then
      options.engine = engine_part
    end
  end

  if options.engine == nil then
    message.error("Engine not specified.")
    os.exit(1)
  end
  local engine = KnownEngines[options.engine]
  if not engine then
    message.error("Unknown engine name '", options.engine, "'.")
    os.exit(1)
  end

  set_default_values(options)

  return inputfile, engine, options
end

return {
  usage = usage,
  handle_cluttex_options = handle_cluttex_options,
}
end
package.preload["texrunner.isatty"] = function(...)
--[[
  Copyright 2018 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

if os.type == "unix" then
  -- Try LuaJIT-like FFI
  local succ, M = pcall(function()
      local ffi = require "ffi"
      ffi.cdef[[
int isatty(int fd);
int fileno(void *stream);
]]
      local isatty = assert(ffi.C.isatty, "isatty not found")
      local fileno = assert(ffi.C.fileno, "fileno not found")
      return {
        isatty = function(file)
          -- LuaJIT converts Lua's file handles into FILE* (void*)
          return isatty(fileno(file)) ~= 0
        end
      }
  end)
  if succ then
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: isatty found via FFI (Unix)\n")
    end
    return M
  else
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: FFI (Unix) not found: ", M, "\n")
    end
  end

  -- Try luaposix
  local succ, M = pcall(function()
      local isatty = require "posix.unistd".isatty
      local fileno = require "posix.stdio".fileno
      return {
        isatty = function(file)
          return isatty(fileno(file)) == 1
        end,
      }
  end)
  if succ then
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: isatty found via luaposix\n")
    end
    return M
  else
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: luaposix not found: ", M, "\n")
    end
  end

else
  -- Try LuaJIT
  -- TODO: Try to detect MinTTY using GetFileInformationByHandleEx
  local succ, M = pcall(function()
      local ffi = require "ffi"
      local bitlib = assert(bit32 or bit, "Neither bit32 (Lua 5.2) nor bit (LuaJIT) found") -- Lua 5.2 or LuaJIT
      ffi.cdef[[
int _isatty(int fd);
int _fileno(void *stream);
void *_get_osfhandle(int fd); // should return intptr_t
typedef int BOOL;
typedef uint32_t DWORD;
typedef int FILE_INFO_BY_HANDLE_CLASS; // ???
typedef struct _FILE_NAME_INFO {
DWORD FileNameLength;
uint16_t FileName[?];
} FILE_NAME_INFO;
DWORD GetFileType(void *hFile);
BOOL GetFileInformationByHandleEx(void *hFile, FILE_INFO_BY_HANDLE_CLASS fic, void *fileinfo, DWORD dwBufferSize);
BOOL GetConsoleMode(void *hConsoleHandle, DWORD* lpMode);
BOOL SetConsoleMode(void *hConsoleHandle, DWORD dwMode);
DWORD GetLastError();
]]
      local isatty = assert(ffi.C._isatty, "_isatty not found")
      local fileno = assert(ffi.C._fileno, "_fileno not found")
      local get_osfhandle = assert(ffi.C._get_osfhandle, "_get_osfhandle not found")
      local GetFileType = assert(ffi.C.GetFileType, "GetFileType not found")
      local GetFileInformationByHandleEx = assert(ffi.C.GetFileInformationByHandleEx, "GetFileInformationByHandleEx not found")
      local GetConsoleMode = assert(ffi.C.GetConsoleMode, "GetConsoleMode not found")
      local SetConsoleMode = assert(ffi.C.SetConsoleMode, "SetConsoleMode not found")
      local GetLastError = assert(ffi.C.GetLastError, "GetLastError not found")
      local function wide_to_narrow(array, length)
        local t = {}
        for i = 0, length - 1 do
          table.insert(t, string.char(math.min(array[i], 0xff)))
        end
        return table.concat(t, "")
      end
      local function is_mintty(fd)
        local handle = get_osfhandle(fd)
        local filetype = GetFileType(handle)
        if filetype ~= 0x0003 then -- not FILE_TYPE_PIPE (0x0003)
          -- mintty must be a pipe
          if CLUTTEX_VERBOSITY >= 4 then
            io.stderr:write("ClutTeX: is_mintty: not a pipe\n")
          end
          return false
        end
        local nameinfo = ffi.new("FILE_NAME_INFO", 32768)
        local FileNameInfo = 2 -- : FILE_INFO_BY_HANDLE_CLASS
        if GetFileInformationByHandleEx(handle, FileNameInfo, nameinfo, ffi.sizeof("FILE_NAME_INFO", 32768)) ~= 0 then
          local filename = wide_to_narrow(nameinfo.FileName, math.floor(nameinfo.FileNameLength / 2))
          -- \(cygwin|msys)-<hex digits>-pty<N>-(from|to)-master
          if CLUTTEX_VERBOSITY >= 4 then
            io.stderr:write("ClutTeX: is_mintty: GetFileInformationByHandleEx returned ", filename, "\n")
          end
          local a, b = string.match(filename, "^\\(%w+)%-%x+%-pty%d+%-(%w+)%-master$")
          return (a == "cygwin" or a == "msys") and (b == "from" or b == "to")
        else
          if CLUTTEX_VERBOSITY >= 4 then
            io.stderr:write("ClutTeX: is_mintty: GetFileInformationByHandleEx failed\n")
          end
          return false
        end
      end
      return {
        isatty = function(file)
          -- LuaJIT converts Lua's file handles into FILE* (void*)
          local fd = fileno(file)
          return isatty(fd) ~= 0 or is_mintty(fd)
        end,
        enable_virtual_terminal = function(file)
          local fd = fileno(file)
          if is_mintty(fd) then
            -- MinTTY
            if CLUTTEX_VERBOSITY >= 4 then
              io.stderr:write("ClutTeX: Detected MinTTY\n")
            end
            return true
          elseif isatty(fd) ~= 0 then
            -- Check for ConEmu or ansicon
            if os.getenv("ConEmuANSI") == "ON" or os.getenv("ANSICON") then
              if CLUTTEX_VERBOSITY >= 4 then
                io.stderr:write("ClutTeX: Detected ConEmu or ansicon\n")
              end
              return true
            else
              -- Try native VT support on recent Windows
              local handle = get_osfhandle(fd)
              local modePtr = ffi.new("DWORD[1]")
              local result = GetConsoleMode(handle, modePtr)
              if result == 0 then
                if CLUTTEX_VERBOSITY >= 3 then
                  local err = GetLastError()
                  io.stderr:write(string.format("ClutTeX: GetConsoleMode failed (0x%08X)\n", err))
                end
                return false
              end
              local ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
              result = SetConsoleMode(handle, bitlib.bor(modePtr[0], ENABLE_VIRTUAL_TERMINAL_PROCESSING))
              if result == 0 then
                -- SetConsoleMode failed: Command Prompt on older Windows
                if CLUTTEX_VERBOSITY >= 3 then
                  local err = GetLastError()
                  -- Typical error code: ERROR_INVALID_PARAMETER (0x57)
                  io.stderr:write(string.format("ClutTeX: SetConsoleMode failed (0x%08X)\n", err))
                end
                return false
              end
              if CLUTTEX_VERBOSITY >= 4 then
                io.stderr:write("ClutTeX: Detected recent Command Prompt\n")
              end
              return true
            end
          else
            -- Not a TTY
            return false
          end
        end,
      }
  end)
  if succ then
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: isatty found via FFI (Windows)\n")
    end
    return M
  else
    if CLUTTEX_VERBOSITY >= 3 then
      io.stderr:write("ClutTeX: FFI (Windows) not found: ", M, "\n")
    end
  end
end

return {
  isatty = function(file)
    return false
  end,
}
end
package.preload["texrunner.message"] = function(...)
--[[
  Copyright 2018 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

local use_colors = false

local function set_colors(mode)
  local M
  if mode == "always" then
    M = require "texrunner.isatty"
    use_colors = true
    if use_colors and M.enable_virtual_terminal then
      local succ = M.enable_virtual_terminal(io.stderr)
      if not succ and CLUTTEX_VERBOSITY >= 2 then
        io.stderr:write("ClutTeX: Failed to enable virtual terminal\n")
      end
    end
  elseif mode == "auto" then
    M = require "texrunner.isatty"
    use_colors = M.isatty(io.stderr)
    if use_colors and M.enable_virtual_terminal then
      use_colors = M.enable_virtual_terminal(io.stderr)
      if not use_colors and CLUTTEX_VERBOSITY >= 2 then
        io.stderr:write("ClutTeX: Failed to enable virtual terminal\n")
      end
    end
  elseif mode == "never" then
    use_colors = false
  else
    error "The value of --color option must be one of 'auto', 'always', or 'never'."
  end
end

-- ESCAPE: hex 1B = dec 27 = oct 33

local CMD = {
  reset      = "\027[0m",
  underline  = "\027[4m",
  fg_black   = "\027[30m",
  fg_red     = "\027[31m",
  fg_green   = "\027[32m",
  fg_yellow  = "\027[33m",
  fg_blue    = "\027[34m",
  fg_magenta = "\027[35m",
  fg_cyan    = "\027[36m",
  fg_white   = "\027[37m",
  fg_reset   = "\027[39m",
  bg_black   = "\027[40m",
  bg_red     = "\027[41m",
  bg_green   = "\027[42m",
  bg_yellow  = "\027[43m",
  bg_blue    = "\027[44m",
  bg_magenta = "\027[45m",
  bg_cyan    = "\027[46m",
  bg_white   = "\027[47m",
  bg_reset   = "\027[49m",
  fg_x_black   = "\027[90m",
  fg_x_red     = "\027[91m",
  fg_x_green   = "\027[92m",
  fg_x_yellow  = "\027[93m",
  fg_x_blue    = "\027[94m",
  fg_x_magenta = "\027[95m",
  fg_x_cyan    = "\027[96m",
  fg_x_white   = "\027[97m",
  bg_x_black   = "\027[100m",
  bg_x_red     = "\027[101m",
  bg_x_green   = "\027[102m",
  bg_x_yellow  = "\027[103m",
  bg_x_blue    = "\027[104m",
  bg_x_magenta = "\027[105m",
  bg_x_cyan    = "\027[106m",
  bg_x_white   = "\027[107m",
}

local function exec_msg(commandline)
  if use_colors then
    io.stderr:write(CMD.fg_x_white, CMD.bg_red, "[EXEC]", CMD.reset, " ", CMD.fg_red, commandline, CMD.reset, "\n")
  else
    io.stderr:write("[EXEC] ", commandline, "\n")
  end
end

local function error_msg(...)
  local message = table.concat({...}, "")
  if use_colors then
    io.stderr:write(CMD.fg_x_white, CMD.bg_red, "[ERROR]", CMD.reset, " ", CMD.fg_red, message, CMD.reset, "\n")
  else
    io.stderr:write("[ERROR] ", message, "\n")
  end
end

local function warn_msg(...)
  local message = table.concat({...}, "")
  if use_colors then
    io.stderr:write(CMD.fg_x_white, CMD.bg_red, "[WARN]", CMD.reset, " ", CMD.fg_blue, message, CMD.reset, "\n")
  else
    io.stderr:write("[WARN] ", message, "\n")
  end
end

local function diag_msg(...)
  local message = table.concat({...}, "")
  if use_colors then
    io.stderr:write(CMD.fg_x_white, CMD.bg_red, "[DIAG]", CMD.reset, " ", CMD.fg_blue, message, CMD.reset, "\n")
  else
    io.stderr:write("[DIAG] ", message, "\n")
  end
end

local function info_msg(...)
  local message = table.concat({...}, "")
  if use_colors then
    io.stderr:write(CMD.fg_x_white, CMD.bg_red, "[INFO]", CMD.reset, " ", CMD.fg_magenta, message, CMD.reset, "\n")
  else
    io.stderr:write("[INFO] ", message, "\n")
  end
end

return {
  set_colors = set_colors,
  exec  = exec_msg,
  error = error_msg,
  warn  = warn_msg,
  diag  = diag_msg,
  info  = info_msg,
}
end
package.preload["texrunner.fswatcher_windows"] = function(...)
--[[
  Copyright 2019 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

local ffi = require "ffi"
local bitlib = assert(bit32 or bit, "Neither bit32 (Lua 5.2) nor bit (LuaJIT) found") -- Lua 5.2 or LuaJIT

ffi.cdef[[
typedef int BOOL;
typedef unsigned int UINT;
typedef uint32_t DWORD;
typedef void *HANDLE;
typedef uintptr_t ULONG_PTR;
typedef uint16_t WCHAR;
typedef struct _OVERLAPPED {
  ULONG_PTR Internal;
  ULONG_PTR InternalHigh;
  union {
    struct {
      DWORD Offset;
      DWORD OffsetHigh;
    };
    void *Pointer;
  };
  HANDLE hEvent;
} OVERLAPPED;
typedef struct _FILE_NOTIFY_INFORMATION {
  DWORD NextEntryOffset;
  DWORD Action;
  DWORD FileNameLength;
  WCHAR FileName[?];
} FILE_NOTIFY_INFORMATION;
typedef void (__stdcall *LPOVERLAPPED_COMPLETION_ROUTINE)(DWORD dwErrorCode, DWORD dwNumberOfBytesTransfered, OVERLAPPED *lpOverlapped);
DWORD GetLastError();
BOOL CloseHandle(HANDLE hObject);
HANDLE CreateFileA(const char *lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, void *lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
HANDLE CreateIoCompletionPort(HANDLE fileHandle, HANDLE existingCompletionPort, ULONG_PTR completionKey, DWORD numberOfConcurrentThreads);
BOOL ReadDirectoryChangesW(HANDLE hDirectory, void *lpBuffer, DWORD nBufferLength, BOOL bWatchSubtree, DWORD dwNotifyFilter, DWORD *lpBytesReturned, OVERLAPPED *lpOverlapped, LPOVERLAPPED_COMPLETION_ROUTINE lpOverlappedCompletionRoutine);
BOOL GetQueuedCompletionStatus(HANDLE CompletionPort, DWORD *lpNumberOfBytes, ULONG_PTR *lpCompletionKey, OVERLAPPED **lpOverlapped, DWORD dwMilliseconds);
int MultiByteToWideChar(UINT CodePage, DWORD dwFlags, const char *lpMultiByteStr, int cbMultiByte, WCHAR *lpWideCharStr, int cchWideChar);
int WideCharToMultiByte(UINT CodePage, DWORD dwFlags, const WCHAR *lpWideCharStr, int cchWideChar, char *lpMultiByteStr, int cbMultiByte, const char *lpDefaultChar, BOOL *lpUsedDefaultChar);
DWORD GetFullPathNameA(const char *lpFileName, DWORD nBufferLength, char *lpBuffer, char **lpFilePart);
uint64_t GetTickCount64();
]]

-- LuaTeX's FFI does not equate a null pointer with nil.
-- On LuaJIT, ffi.NULL is just nil.
local NULL = ffi.NULL

-- GetLastError
local ERROR_FILE_NOT_FOUND         = 0x0002
local ERROR_PATH_NOT_FOUND         = 0x0003
local ERROR_ACCESS_DENIED          = 0x0005
local ERROR_INVALID_PARAMETER      = 0x0057
local ERROR_INSUFFICIENT_BUFFER    = 0x007A
local WAIT_TIMEOUT                 = 0x0102
local ERROR_ABANDONED_WAIT_0       = 0x02DF
local ERROR_NOACCESS               = 0x03E6
local ERROR_INVALID_FLAGS          = 0x03EC
local ERROR_NOTIFY_ENUM_DIR        = 0x03FE
local ERROR_NO_UNICODE_TRANSLATION = 0x0459
local KnownErrors = {
  [ERROR_FILE_NOT_FOUND] = "ERROR_FILE_NOT_FOUND",
  [ERROR_PATH_NOT_FOUND] = "ERROR_PATH_NOT_FOUND",
  [ERROR_ACCESS_DENIED] = "ERROR_ACCESS_DENIED",
  [ERROR_INVALID_PARAMETER] = "ERROR_INVALID_PARAMETER",
  [ERROR_INSUFFICIENT_BUFFER] = "ERROR_INSUFFICIENT_BUFFER",
  [ERROR_ABANDONED_WAIT_0] = "ERROR_ABANDONED_WAIT_0",
  [ERROR_NOACCESS] = "ERROR_NOACCESS",
  [ERROR_INVALID_FLAGS] = "ERROR_INVALID_FLAGS",
  [ERROR_NOTIFY_ENUM_DIR] = "ERROR_NOTIFY_ENUM_DIR",
  [ERROR_NO_UNICODE_TRANSLATION] = "ERROR_NO_UNICODE_TRANSLATION",
}

-- CreateFile
local FILE_FLAG_BACKUP_SEMANTICS = 0x02000000
local FILE_FLAG_OVERLAPPED       = 0x40000000
local OPEN_EXISTING              = 3
local FILE_SHARE_READ            = 0x00000001
local FILE_SHARE_WRITE           = 0x00000002
local FILE_SHARE_DELETE          = 0x00000004
local FILE_LIST_DIRECTORY        = 0x1
local INVALID_HANDLE_VALUE       = ffi.cast("void *", -1)

-- ReadDirectoryChangesW / FILE_NOTIFY_INFORMATION
local FILE_NOTIFY_CHANGE_FILE_NAME   = 0x00000001
local FILE_NOTIFY_CHANGE_DIR_NAME    = 0x00000002
local FILE_NOTIFY_CHANGE_ATTRIBUTES  = 0x00000004
local FILE_NOTIFY_CHANGE_SIZE        = 0x00000008
local FILE_NOTIFY_CHANGE_LAST_WRITE  = 0x00000010
local FILE_NOTIFY_CHANGE_LAST_ACCESS = 0x00000020
local FILE_NOTIFY_CHANGE_CREATION    = 0x00000040
local FILE_NOTIFY_CHANGE_SECURITY    = 0x00000100
local FILE_ACTION_ADDED              = 0x00000001
local FILE_ACTION_REMOVED            = 0x00000002
local FILE_ACTION_MODIFIED           = 0x00000003
local FILE_ACTION_RENAMED_OLD_NAME   = 0x00000004
local FILE_ACTION_RENAMED_NEW_NAME   = 0x00000005

-- WideCharToMultiByte / MultiByteToWideChar
local CP_ACP  = 0
local CP_UTF8 = 65001

local C = ffi.C

local function format_error(name, lasterror, extra)
  local errorname = KnownErrors[lasterror] or string.format("error code %d", lasterror)
  if extra then
    return string.format("%s failed with %s (0x%04x) [%s]", name, errorname, lasterror, extra)
  else
    return string.format("%s failed with %s (0x%04x)", name, errorname, lasterror)
  end
end
local function wcs_to_mbs(wstr, wstrlen, codepage)
  -- wstr: FFI uint16_t[?]
  -- wstrlen: length of wstr, or -1 if NUL-terminated
  if wstrlen == 0 then
    return ""
  end
  codepage = codepage or CP_ACP
  local dwFlags = 0
  local result = C.WideCharToMultiByte(codepage, dwFlags, wstr, wstrlen, nil, 0, nil, nil)
  if result <= 0 then
    -- Failed
    local lasterror = C.GetLastError()
    -- Candidates: ERROR_INSUFFICIENT_BUFFER, ERROR_INVALID_FLAGS, ERROR_INVALID_PARAMETER, ERROR_NO_UNICODE_TRANSLATION
    return nil, format_error("WideCharToMultiByte", lasterror)
  end
  local mbsbuf = ffi.new("char[?]", result)
  result = C.WideCharToMultiByte(codepage, dwFlags, wstr, wstrlen, mbsbuf, result, nil, nil)
  if result <= 0 then
    -- Failed
    local lasterror = C.GetLastError()
    -- Candidates: ERROR_INSUFFICIENT_BUFFER, ERROR_INVALID_FLAGS, ERROR_INVALID_PARAMETER, ERROR_NO_UNICODE_TRANSLATION
    return nil, format_error("WideCharToMultiByte", lasterror)
  end
  return ffi.string(mbsbuf, result)
end
local function mbs_to_wcs(str, codepage)
  -- str: Lua string
  if str == "" then
    return ffi.new("WCHAR[0]")
  end
  codepage = codepage or CP_ACP
  local dwFlags = 0
  local result = C.MultiByteToWideChar(codepage, dwFlags, str, #str, nil, 0)
  if result <= 0 then
    local lasterror = C.GetLastError()
    -- ERROR_INSUFFICIENT_BUFFER, ERROR_INVALID_FLAGS, ERROR_INVALID_PARAMETER, ERROR_NO_UNICODE_TRANSLATION
    return nil, format_error("MultiByteToWideChar", lasterror)
  end
  local wcsbuf = ffi.new("WCHAR[?]", result)
  result = C.MultiByteToWideChar(codepage, dwFlags, str, #str, wcsbuf, result)
  if result <= 0 then
    local lasterror = C.GetLastError()
    return nil, format_error("MultiByteToWideChar", lasterror)
  end
  return wcsbuf, result
end


local function get_full_path_name(filename)
  local bufsize = 1024
  local buffer
  local filePartPtr = ffi.new("char*[1]")
  local result
  repeat
    buffer = ffi.new("char[?]", bufsize)
    result = C.GetFullPathNameA(filename, bufsize, buffer, filePartPtr)
    if result == 0 then
      local lasterror = C.GetLastError()
      return nil, format_error("GetFullPathNameA", lasterror, filename)
    elseif bufsize < result then
      -- result: buffer size required to hold the path + terminating NUL
      bufsize = result
    end
  until result < bufsize
  local fullpath = ffi.string(buffer, result)
  local filePart = ffi.string(filePartPtr[0])
  local dirPart = ffi.string(buffer, ffi.cast("intptr_t", filePartPtr[0]) - ffi.cast("intptr_t", buffer)) -- LuaTeX's FFI doesn't support pointer subtraction
  return fullpath, filePart, dirPart
end

--[[
  dirwatche.dirname : string
  dirwatcher._rawhandle : cdata HANDLE
  dirwatcher._overlapped : cdata OVERLAPPED
  dirwatcher._buffer : cdata char[?]
]]
local dirwatcher_meta = {}
dirwatcher_meta.__index = dirwatcher_meta
function dirwatcher_meta:close()
  if self._rawhandle ~= nil then
    C.CloseHandle(ffi.gc(self._rawhandle, nil))
    self._rawhandle = nil
  end
end
local function open_directory(dirname)
  local dwShareMode = bitlib.bor(FILE_SHARE_READ, FILE_SHARE_WRITE, FILE_SHARE_DELETE)
  local dwFlagsAndAttributes = bitlib.bor(FILE_FLAG_BACKUP_SEMANTICS, FILE_FLAG_OVERLAPPED)
  local handle = C.CreateFileA(dirname, FILE_LIST_DIRECTORY, dwShareMode, nil, OPEN_EXISTING, dwFlagsAndAttributes, nil)
  if handle == INVALID_HANDLE_VALUE then
    local lasterror = C.GetLastError()
    print("Failed to open "..dirname)
    return nil, format_error("CreateFileA", lasterror, dirname)
  end
  return setmetatable({
    dirname = dirname,
    _rawhandle = ffi.gc(handle, C.CloseHandle),
    _overlapped = ffi.new("OVERLAPPED"),
    _buffer = ffi.new("char[?]", 1024),
  }, dirwatcher_meta)
end
function dirwatcher_meta:start_watch(watchSubtree)
  local dwNotifyFilter = bitlib.bor(FILE_NOTIFY_CHANGE_FILE_NAME, FILE_NOTIFY_CHANGE_DIR_NAME, FILE_NOTIFY_CHANGE_ATTRIBUTES, FILE_NOTIFY_CHANGE_SIZE, FILE_NOTIFY_CHANGE_LAST_WRITE, FILE_NOTIFY_CHANGE_LAST_ACCESS, FILE_NOTIFY_CHANGE_CREATION, FILE_NOTIFY_CHANGE_SECURITY)
  local buffer = self._buffer
  local bufferSize = ffi.sizeof(buffer)
  local result = C.ReadDirectoryChangesW(self._rawhandle, buffer, bufferSize, watchSubtree, dwNotifyFilter, nil, self._overlapped, nil)
  if result == 0 then
    local lasterror = C.GetLastError()
    return nil, format_error("ReadDirectoryChangesW", lasterror, self.dirname)
  end
  return true
end
local ActionTable = {
  [FILE_ACTION_ADDED] = "added",
  [FILE_ACTION_REMOVED] = "removed",
  [FILE_ACTION_MODIFIED] = "modified",
  [FILE_ACTION_RENAMED_OLD_NAME] = "rename_from",
  [FILE_ACTION_RENAMED_NEW_NAME] = "rename_to",
}
function dirwatcher_meta:process(numberOfBytes)
  -- self._buffer received `numberOfBytes` bytes
  local buffer = self._buffer
  numberOfBytes = math.min(numberOfBytes, ffi.sizeof(buffer))
  local ptr = ffi.cast("char *", buffer)
  local structSize = ffi.sizeof("FILE_NOTIFY_INFORMATION", 1)
  local t = {}
  while numberOfBytes >= structSize do
    local notifyInfo = ffi.cast("FILE_NOTIFY_INFORMATION*", ptr)
    local nextEntryOffset = notifyInfo.NextEntryOffset
    local action = notifyInfo.Action
    local fileNameLength = notifyInfo.FileNameLength
    local fileName = notifyInfo.FileName
    local u = { action = ActionTable[action], filename = wcs_to_mbs(fileName, fileNameLength / 2) }
    table.insert(t, u)
    if nextEntryOffset == 0 or numberOfBytes <= nextEntryOffset then
      break
    end
    numberOfBytes = numberOfBytes - nextEntryOffset
    ptr = ptr + nextEntryOffset
  end
  return t
end

--[[
  watcher._rawport : cdata HANDLE
  watcher._pending : array of {
    action = ..., filename = ...
  }
  watcher._directories[dirname] = {
    dir = directory watcher,
    dirname = dirname,
    files = { [filename] = user-supplied path } -- files to watch
  }
  watcher[i] = i-th directory (_directories[dirname] for some dirname)
]]

local fswatcher_meta = {}
fswatcher_meta.__index = fswatcher_meta
local function new_watcher()
  local port = C.CreateIoCompletionPort(INVALID_HANDLE_VALUE, nil, 0, 0)
  if port == NULL then
    local lasterror = C.GetLastError()
    return nil, format_error("CreateIoCompletionPort", lasterror)
  end
  return setmetatable({
    _rawport = ffi.gc(port, C.CloseHandle), -- ?
    _pending = {},
    _directories = {},
  }, fswatcher_meta)
end
local function add_directory(self, dirname)
  local t = self._directories[dirname]
  if not t then
    local dirwatcher, err = open_directory(dirname)
    if not dirwatcher then
      return dirwatcher, err
    end
    t = { dirwatcher = dirwatcher, dirname = dirname, files = {} }
    table.insert(self, t)
    local i = #self
    local result = C.CreateIoCompletionPort(dirwatcher._rawhandle, self._rawport, i, 0)
    if result == NULL then
      local lasterror = C.GetLastError()
      return nil, format_error("CreateIoCompletionPort", lasterror, dirname)
    end
    self._directories[dirname] = t
    local result, err = dirwatcher:start_watch(false)
    if not result then
      return result, err
    end
  end
  return t
end
function fswatcher_meta:add_file(path, ...)
  local fullpath, filename, dirname = get_full_path_name(path)
  local t, err = add_directory(self, dirname)
  if not t then
    return t, err
  end
  t.files[filename] = path
  return true
end
local INFINITE = 0xFFFFFFFF
local function get_queued(self, timeout)
  local startTime = C.GetTickCount64()
  local timeout_ms
  if timeout == nil then
    timeout_ms = INFINITE
  else
    timeout_ms = timeout * 1000
  end
  local numberOfBytesPtr = ffi.new("DWORD[1]")
  local completionKeyPtr = ffi.new("ULONG_PTR[1]")
  local lpOverlapped = ffi.new("OVERLAPPED*[1]")
  repeat
    local result = C.GetQueuedCompletionStatus(self._rawport, numberOfBytesPtr, completionKeyPtr, lpOverlapped, timeout_ms)
    if result == 0 then
      local lasterror = C.GetLastError()
      if lasterror == WAIT_TIMEOUT then
        return nil, "timeout"
      else
        return nil, format_error("GetQueuedCompletionStatus", lasterror)
      end
    end
    local numberOfBytes = numberOfBytesPtr[0]
    local completionKey = tonumber(completionKeyPtr[0])
    local dir_t = assert(self[completionKey], "invalid completion key: " .. tostring(completionKey))
    local t = dir_t.dirwatcher:process(numberOfBytes)
    dir_t.dirwatcher:start_watch(false)
    local found = false
    for i,v in ipairs(t) do
      local path = dir_t.files[v.filename]
      if path then
        found = true
        table.insert(self._pending, {path = path, action = v.action})
      end
    end
    if found then
      return true
    end
    if timeout_ms ~= INFINITE then
      local tt = C.GetTickCount64()
      timeout_ms = timeout_ms - (tt - startTime)
      startTime = tt
    end
  until timeout_ms < 0
  return nil, "timeout"
end
function fswatcher_meta:next(timeout)
  if #self._pending > 0 then
    local result = table.remove(self._pending, 1)
    get_queued(self, 0) -- ignore error
    return result
  else
    local result, err = get_queued(self, timeout)
    if result == nil then
      return nil, err
    end
    return table.remove(self._pending, 1)
  end
end
function fswatcher_meta:close()
  if self._rawport ~= nil then
    for i,v in ipairs(self) do
      v.dirwatcher:close()
    end
    C.CloseHandle(ffi.gc(self._rawport, nil))
    self._rawport = nil
  end
end
--[[
local watcher = require("fswatcher_windows").new()
assert(watcher:add_file("rdc-sync.c"))
assert(watcher:add_file("sub2/hoge"))
for i = 1, 10 do
    local result, err = watcher:next(2)
    if err == "timeout" then
        print(os.date(), "timeout")
    else
        assert(result, err)
        print(os.date(), result.path, result.action)
    end
end
watcher:close()
]]
return {
  new = new_watcher,
}
end
--[[
  Copyright 2016,2018-2019 ARATA Mizuki

  This file is part of ClutTeX.

  ClutTeX is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  ClutTeX is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with ClutTeX.  If not, see <http://www.gnu.org/licenses/>.
]]

CLUTTEX_VERSION = "v0.3"

-- Standard libraries
local coroutine = coroutine
local tostring = tostring

-- External libraries (included in texlua)
local filesys = require "lfs"
local md5     = require "md5"
-- local kpse = require "kpse"

-- My own modules
local pathutil    = require "texrunner.pathutil"
local fsutil      = require "texrunner.fsutil"
local shellutil   = require "texrunner.shellutil"
local reruncheck  = require "texrunner.reruncheck"
local luatexinit  = require "texrunner.luatexinit"
local recoverylib = require "texrunner.recovery"
local message     = require "texrunner.message"
local extract_bibtex_from_aux_file = require "texrunner.auxfile".extract_bibtex_from_aux_file
local handle_cluttex_options = require "texrunner.handleoption".handle_cluttex_options

os.setlocale("", "ctype") -- Workaround for recent Universal CRT

-- arguments: input file name, jobname, etc...
local function genOutputDirectory(...)
  -- The name of the temporary directory is based on the path of input file.
  local message = table.concat({...}, "\0")
  local hash = md5.sumhexa(message)
  local tmpdir = os.getenv("TMPDIR") or os.getenv("TMP") or os.getenv("TEMP")
  if tmpdir == nil then
    local home = os.getenv("HOME") or os.getenv("USERPROFILE") or error("environment variable 'TMPDIR' not set!")
    tmpdir = pathutil.join(home, ".latex-build-temp")
  end
  return pathutil.join(tmpdir, 'latex-build-' .. hash)
end

local inputfile, engine, options = handle_cluttex_options(arg)

local jobname = options.jobname or pathutil.basename(pathutil.trimext(inputfile))
assert(jobname ~= "", "jobname cannot be empty")

if options.output_format == nil then
  options.output_format = "pdf"
end
local output_extension
if options.output_format == "dvi" then
  output_extension = engine.dvi_extension or "dvi"
else
  output_extension = "pdf"
end

if options.output == nil then
  options.output = jobname .. "." .. output_extension
end

-- Prepare output directory
if options.output_directory == nil then
  local inputfile_abs = pathutil.abspath(inputfile)
  options.output_directory = genOutputDirectory(inputfile_abs, jobname, options.engine)

  if not fsutil.isdir(options.output_directory) then
    assert(fsutil.mkdir_rec(options.output_directory))

  elseif options.fresh then
    -- The output directory exists and --fresh is given:
    -- Remove all files in the output directory
    if CLUTTEX_VERBOSITY >= 1 then
      message.info("Cleaning '", options.output_directory, "'...")
    end
    assert(fsutil.remove_rec(options.output_directory))
    assert(filesys.mkdir(options.output_directory))
  end

elseif options.fresh then
  message.error("--fresh and --output-directory cannot be used together.")
  os.exit(1)
end

local pathsep = ":"
if os.type == "windows" then
  pathsep = ";"
end

local original_wd = filesys.currentdir()
if options.change_directory then
  local TEXINPUTS = os.getenv("TEXINPUTS") or ""
  filesys.chdir(options.output_directory)
  options.output = pathutil.abspath(options.output, original_wd)
  os.setenv("TEXINPUTS", original_wd .. pathsep .. TEXINPUTS)
end
if options.bibtex or options.biber then
  local BIBINPUTS = os.getenv("BIBINPUTS") or ""
  options.output = pathutil.abspath(options.output, original_wd)
  os.setenv("BIBINPUTS", original_wd .. pathsep .. BIBINPUTS)
end

-- Set `max_print_line' environment variable if not already set.
if os.getenv("max_print_line") == nil then
  os.setenv("max_print_line", "65536")
end
-- TODO: error_line, half_error_line
--[[
  According to texmf.cnf:
    45 < error_line < 255,
    30 < half_error_line < error_line - 15,
    60 <= max_print_line.
]]

local function path_in_output_directory(ext)
  return pathutil.join(options.output_directory, jobname .. "." .. ext)
end

local recorderfile = path_in_output_directory("fls")
local recorderfile2 = path_in_output_directory("cluttex-fls")

local tex_options = {
  interaction = options.interaction,
  file_line_error = options.file_line_error,
  halt_on_error = options.halt_on_error,
  synctex = options.synctex,
  output_directory = options.output_directory,
  shell_escape = options.shell_escape,
  shell_restricted = options.shell_restricted,
  jobname = options.jobname,
  fmt = options.fmt,
  extraoptions = options.tex_extraoptions,
}
if options.output_format ~= "pdf" and engine.supports_pdf_generation then
  tex_options.output_format = options.output_format
end

-- Setup LuaTeX initialization script
if engine.is_luatex then
  local initscriptfile = path_in_output_directory("cluttexinit.lua")
  luatexinit.create_initialization_script(initscriptfile, tex_options)
  tex_options.lua_initialization_script = initscriptfile
end

-- Run TeX command (*tex, *latex)
-- should_rerun, newauxstatus = single_run([auxstatus])
-- This function should be run in a coroutine.
local function single_run(auxstatus, iteration)
  local minted = false
  local bibtex_aux_hash = nil
  local mainauxfile = path_in_output_directory("aux")
  if fsutil.isfile(recorderfile) then
    -- Recorder file already exists
    local filelist, filemap = reruncheck.parse_recorder_file(recorderfile, options)
    if engine.is_luatex and fsutil.isfile(recorderfile2) then
      filelist, filemap = reruncheck.parse_recorder_file(recorderfile2, options, filelist, filemap)
    end
    auxstatus = reruncheck.collectfileinfo(filelist, auxstatus)
    for _,fileinfo in ipairs(filelist) do
      if string.match(fileinfo.path, "minted/minted%.sty$") then
        minted = true
        break
      end
    end
    if options.bibtex then
      local biblines = extract_bibtex_from_aux_file(mainauxfile, options.output_directory)
      if #biblines > 0 then
        bibtex_aux_hash = md5.sum(table.concat(biblines, "\n"))
      end
    end
  else
    -- This is the first execution
    if auxstatus ~= nil then
      message.error("Recorder file was not generated during the execution!")
      os.exit(1)
    end
    auxstatus = {}
  end
  --local timestamp = os.time()

  if options.includeonly then
    tex_options.tex_injection = string.format("%s\\includeonly{%s}", tex_options.tex_injection or "", options.includeonly)
  end

  if minted and not (tex_options.tex_injection and string.find(tex_options.tex_injection,"minted") == nil) then
    tex_options.tex_injection = string.format("%s\\PassOptionsToPackage{outputdir=%s}{minted}", tex_options.tex_injection or "", options.output_directory)
  end

  local current_tex_options, lightweight_mode = tex_options, false
  if iteration == 1 and options.start_with_draft then
    current_tex_options = {}
    for k,v in pairs(tex_options) do
      current_tex_options[k] = v
    end
    if engine.supports_draftmode then
      current_tex_options.draftmode = true
      options.start_with_draft = false
    end
    current_tex_options.interaction = "batchmode"
    lightweight_mode = true
  else
    current_tex_options.draftmode = false
  end

  local command = engine:build_command(inputfile, current_tex_options)

  local execlog -- the contents of .log file

  local recovered = false
  local function recover()
    -- Check log file
    if not execlog then
      local logfile = assert(io.open(path_in_output_directory("log")))
      execlog = logfile:read("*a")
      logfile:close()
    end
    recovered = recoverylib.try_recovery{
      execlog = execlog,
      auxfile = path_in_output_directory("aux"),
      options = options,
      original_wd = original_wd,
    }
    return recovered
  end
  coroutine.yield(command, recover) -- Execute the command
  if recovered then
    return true, {}
  end

  local filelist, filemap = reruncheck.parse_recorder_file(recorderfile, options)
  if engine.is_luatex and fsutil.isfile(recorderfile2) then
    filelist, filemap = reruncheck.parse_recorder_file(recorderfile2, options, filelist, filemap)
  end

  if not execlog then
    local logfile = assert(io.open(path_in_output_directory("log")))
    execlog = logfile:read("*a")
    logfile:close()
  end

  if options.makeindex then
    -- Look for .idx files and run MakeIndex
    for _,file in ipairs(filelist) do
      if pathutil.ext(file.path) == "idx" then
        -- Run makeindex if the .idx file is new or updated
        local idxfileinfo = {path = file.path, abspath = file.abspath, kind = "auxiliary"}
        local output_ind = pathutil.replaceext(file.abspath, "ind")
        if reruncheck.comparefileinfo({idxfileinfo}, auxstatus) or reruncheck.comparefiletime(file.abspath, output_ind, auxstatus) then
          local idx_dir = pathutil.dirname(file.abspath)
          local makeindex_command = {
            "cd", shellutil.escape(idx_dir), "&&",
            options.makeindex, -- Do not escape options.makeindex to allow additional options
            "-o", pathutil.basename(output_ind),
            pathutil.basename(file.abspath)
          }
          coroutine.yield(table.concat(makeindex_command, " "))
          table.insert(filelist, {path = output_ind, abspath = output_ind, kind = "auxiliary"})
        else
          local succ, err = filesys.touch(output_ind)
          if not succ then
            message.warn("Failed to touch " .. output_ind .. " (" .. err .. ")")
          end
        end
      end
    end
  else
    -- Check log file
    if string.find(execlog, "No file [^\n]+%.ind%.") then
      message.diag("You may want to use --makeindex option.")
    end
  end

  if options.makeglossaries then
    -- Look for .glo files and run makeglossaries
    for _,file in ipairs(filelist) do
      if pathutil.ext(file.path) == "glo" then
        -- Run makeglossaries if the .glo file is new or updated
        local glofileinfo = {path = file.path, abspath = file.abspath, kind = "auxiliary"}
        local output_gls = pathutil.replaceext(file.abspath, "gls")
        if reruncheck.comparefileinfo({glofileinfo}, auxstatus) or reruncheck.comparefiletime(file.abspath, output_gls, auxstatus) then
          local makeglossaries_command = {
            options.makeglossaries,
            "-d", shellutil.escape(options.output_directory),
            pathutil.trimext(pathutil.basename(file.path))
          }
          coroutine.yield(table.concat(makeglossaries_command, " "))
          table.insert(filelist, {path = output_gls, abspath = output_gls, kind = "auxiliary"})
        else
          local succ, err = filesys.touch(output_gls)
          if not succ then
            message.warn("Failed to touch " .. output_ind .. " (" .. err .. ")")
          end
        end
      end
    end
  else
    -- Check log file
    if string.find(execlog, "No file [^\n]+%.gls%.") then
      message.diag("You may want to use --makeglossaries option.")
    end
  end

  if options.bibtex then
    local biblines2 = extract_bibtex_from_aux_file(mainauxfile, options.output_directory)
    local bibtex_aux_hash2
    if #biblines2 > 0 then
      bibtex_aux_hash2 = md5.sum(table.concat(biblines2, "\n"))
    end
    local output_bbl = path_in_output_directory("bbl")
    if bibtex_aux_hash ~= bibtex_aux_hash2 or reruncheck.comparefiletime(mainauxfile, output_bbl, auxstatus) then
      -- The input for BibTeX command has changed...
      local bibtex_command = {
        "cd", shellutil.escape(options.output_directory), "&&",
        options.bibtex,
        pathutil.basename(mainauxfile)
      }
      coroutine.yield(table.concat(bibtex_command, " "))
    else
      if CLUTTEX_VERBOSITY >= 1 then
        message.info("No need to run BibTeX.")
      end
      local succ, err = filesys.touch(output_bbl)
      if not succ then
        message.warn("Failed to touch " .. output_bbl .. " (" .. err .. ")")
      end
    end
  elseif options.biber then
    for _,file in ipairs(filelist) do
      if pathutil.ext(file.path) == "bcf" then
        -- Run biber if the .bcf file is new or updated
        local bcffileinfo = {path = file.path, abspath = file.abspath, kind = "auxiliary"}
        local output_bbl = pathutil.replaceext(file.abspath, "bbl")
        if reruncheck.comparefileinfo({bcffileinfo}, auxstatus) or reruncheck.comparefiletime(file.abspath, output_bbl, auxstatus) then
          local bbl_dir = pathutil.dirname(file.abspath)
          local biber_command = {
            options.biber, -- Do not escape options.biber to allow additional options
            "--output-directory", shellutil.escape(options.output_directory),
            pathutil.basename(file.abspath)
          }
          coroutine.yield(table.concat(biber_command, " "))
          table.insert(filelist, {path = output_bbl, abspath = output_bbl, kind = "auxiliary"})
        else
          local succ, err = filesys.touch(output_bbl)
          if not succ then
            message.warn("Failed to touch " .. output_bbl .. " (" .. err .. ")")
          end
        end
      end
    end
  else
    -- Check log file
    if string.find(execlog, "No file [^\n]+%.bbl%.") then
      message.diag("You may want to use --bibtex or --biber option.")
    end
  end

  if string.find(execlog, "No pages of output.") then
    return "No pages of output."
  end

  local should_rerun, auxstatus = reruncheck.comparefileinfo(filelist, auxstatus)
  return should_rerun or lightweight_mode, auxstatus
end

-- Run (La)TeX (possibly multiple times) and produce a PDF file.
-- This function should be run in a coroutine.
local function do_typeset_c()
  local iteration = 0
  local should_rerun, auxstatus
  repeat
    iteration = iteration + 1
    should_rerun, auxstatus = single_run(auxstatus, iteration)
    if should_rerun == "No pages of output." then
      message.warn("No pages of output.")
      return
    end
  until not should_rerun or iteration >= options.max_iterations

  if should_rerun then
    message.warn("LaTeX should be run once more.")
  end

  -- Successful
  if options.output_format == "dvi" or engine.supports_pdf_generation then
    -- Output file (DVI/PDF) is generated in the output directory
    local outfile = path_in_output_directory(output_extension)
    local oncopyerror
    if os.type == "windows" then
      oncopyerror = function()
        message.error("Failed to copy file.  Some applications may be locking the ", string.upper(options.output_format), " file.")
        return false
      end
    end
    coroutine.yield(fsutil.copy_command(outfile, options.output), oncopyerror)
    if #options.dvipdfmx_extraoptions > 0 then
      message.warn("--dvipdfmx-option[s] are ignored.")
    end

  else
    -- DVI file is generated, but PDF file is wanted
    local dvifile = path_in_output_directory("dvi")
    local dvipdfmx_command = {"dvipdfmx", "-o", shellutil.escape(options.output)}
    for _,v in ipairs(options.dvipdfmx_extraoptions) do
      table.insert(dvipdfmx_command, v)
    end
    table.insert(dvipdfmx_command, shellutil.escape(dvifile))
    coroutine.yield(table.concat(dvipdfmx_command, " "))
  end

  -- Copy SyncTeX file if necessary
  if options.output_format == "pdf" then
    local synctex = tonumber(options.synctex or "0")
    local synctex_ext = nil
    if synctex > 0 then
      -- Compressed SyncTeX file (.synctex.gz)
      synctex_ext = "synctex.gz"
    elseif synctex < 0 then
      -- Uncompressed SyncTeX file (.synctex)
      synctex_ext = "synctex"
    end
    if synctex_ext then
      coroutine.yield(fsutil.copy_command(path_in_output_directory(synctex_ext), pathutil.replaceext(options.output, synctex_ext)))
    end
  end

  -- Write dependencies file
  if options.make_depends then
    local filelist, filemap = reruncheck.parse_recorder_file(recorderfile, options)
    if engine.is_luatex and fsutil.isfile(recorderfile2) then
      filelist, filemap = reruncheck.parse_recorder_file(recorderfile2, options, filelist, filemap)
    end
    local f = assert(io.open(options.make_depends, "w"))
    f:write(options.output, ":")
    for _,fileinfo in ipairs(filelist) do
      if fileinfo.kind == "input" then
        f:write(" ", fileinfo.path)
      end
    end
    f:write("\n")
    f:close()
  end
end

local function do_typeset()
  -- Execute the command string yielded by do_typeset_c
  for command, recover in coroutine.wrap(do_typeset_c) do
    message.exec(command)
    local success, termination, status_or_signal = os.execute(command)
    if type(success) == "number" then -- Lua 5.1 or LuaTeX
      local code = success
      success = code == 0
      termination = nil
      status_or_signal = code
    end
    if not success and not (recover and recover()) then
      if termination == "exit" then
        message.error("Command exited abnormally: exit status ", tostring(status_or_signal))
      elseif termination == "signal" then
        message.error("Command exited abnormally: signal ", tostring(status_or_signal))
      else
        message.error("Command exited abnormally: ", tostring(status_or_signal))
      end
      return false, termination, status_or_signal
    end
  end
  -- Successful
  if CLUTTEX_VERBOSITY >= 1 then
    message.info("Command exited successfully")
  end
  return true
end

if options.watch then
  -- Watch mode
  local success, status = do_typeset()
  -- TODO: filenames here can be UTF-8 if command_line_encoding=utf-8
  local filelist, filemap = reruncheck.parse_recorder_file(recorderfile, options)
  if engine.is_luatex and fsutil.isfile(recorderfile2) then
    filelist, filemap = reruncheck.parse_recorder_file(recorderfile2, options, filelist, filemap)
  end
  local input_files_to_watch = {}
  for _,fileinfo in ipairs(filelist) do
    if fileinfo.kind == "input" then
      table.insert(input_files_to_watch, fileinfo.abspath)
    end
  end
  local fswatcherlib
  if os.type == "windows" then
    -- Windows: Try built-in filesystem watcher
    local succ, result = pcall(require, "texrunner.fswatcher_windows")
    if not succ and CLUTTEX_VERBOSITY >= 1 then
      message.warn("Failed to load texrunner.fswatcher_windows: " .. result)
    end
    fswatcherlib = result
  end
  if fswatcherlib then
    if CLUTTEX_VERBOSITY >= 2 then
      message.info("Using built-in filesystem watcher for Windows")
    end
    local watcher = assert(fswatcherlib.new())
    for _,path in ipairs(input_files_to_watch) do
      assert(watcher:add_file(path))
    end
    while true do
      local result = assert(watcher:next())
      if CLUTTEX_VERBOSITY >= 2 then
        message.info(string.format("%s %s"), result.action, result.path)
      end
      local success, status = do_typeset()
      if not success then
        -- Not successful
      end
    end
  elseif shellutil.has_command("fswatch") then
    local fswatch_command = {"fswatch", "--event=Updated", "--"}
    for _,path in ipairs(input_files_to_watch) do
      table.insert(fswatch_command, shellutil.escape(path))
    end
    local fswatch_command_str = table.concat(fswatch_command, " ")
    if CLUTTEX_VERBOSITY >= 1 then
      message.exec(fswatch_command_str)
    end
    local fswatch = assert(io.popen(fswatch_command_str, "r"))
    for l in fswatch:lines() do
      local found = false
      for _,path in ipairs(input_files_to_watch) do
        if l == path then
          found = true
          break
        end
      end
      if found then
        local success, status = do_typeset()
        if not success then
          -- Not successful
        end
      end
    end
  elseif shellutil.has_command("inotifywait") then
    local inotifywait_command = {"inotifywait", "--monitor", "--event=modify", "--event=attrib", "--format=%w", "--quiet"}
    for _,path in ipairs(input_files_to_watch) do
      table.insert(inotifywait_command, shellutil.escape(path))
    end
    local inotifywait_command_str = table.concat(inotifywait_command, " ")
    if CLUTTEX_VERBOSITY >= 1 then
      message.exec(inotifywait_command_str)
    end
    local inotifywait = assert(io.popen(inotifywait_command_str, "r"))
    for l in inotifywait:lines() do
      local found = false
      for _,path in ipairs(input_files_to_watch) do
        if l == path then
          found = true
          break
        end
      end
      if found then
        local success, status = do_typeset()
        if not success then
          -- Not successful
        end
      end
    end
  else
    message.error("Could not watch files because neither `fswatch' nor `inotifywait' was installed.")
    message.info("See ClutTeX's manual for details.")
    os.exit(1)
  end

else
  -- Not in watch mode
  local success, status = do_typeset()
  if not success then
    os.exit(1)
  end
end
