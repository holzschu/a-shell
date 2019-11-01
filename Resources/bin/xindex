#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  xindex.lua
--  DESCRIPTION:  create an index
-- REQUIREMENTS:  
--       AUTHOR:  Herbert Voß
--      LICENSE:  LPPL 1.3
-----------------------------------------------------------------------

        xindex = xindex or { }
 local version = 0.13
xindex.version = version
--xindex.self = "xindex"

--[[doc--

xindex(1)

This file is provided under the terms of the LPPL v1.3 or
later as printed in full text in the manual (xindex.pdf).

\url{https://ctan.org/license/lppl1.3}.

Report bugs to

    \url{https://gitlab.com/hvoss49/xindex/issues}.

--doc]]--

kpse.set_program_name("luatex")

require("lualibs")  -- all part of LuaTeX
require('unicode')
require('string')
require("lpeg")


local args = require ('xindex-lapp') [[
  parameter handling
    -q,--quiet
    -h,--help
    -v...          Verbosity level; can be -v, -vv, -vvv
    -c,--config (default cfg)
    -e,--escapechar (default ")
    -n,--noheadings 
    -a,--no_casesensitive
    -o,--output (default "")
    -l,--language (default en)
    -p,--prefix (default L)
    <input> (string)
]]


--[[
    No -v flag, v is just { false }. not args.v[1] is true, so vlevel becomes 0.
    One -v flags, v is { true }
    Two -v flags, v is { true, true }
    Three -v flags, v is { true, true, true } 
]]

vlevel = not args.v[1] and 0 or #args.v
not_quiet = not args["quiet"]

local luaVersion = _VERSION
if (luaVersion < "Lua 5.3") then
  print("=========================================")
  print("Sorry. but we need at least LuaTeX 1.09")
  print("Leaving program xindex")
  print("=========================================")
  os.exit()
end

--local inspect = require 'inspect' 
--print(inspect(args))

--[[
if args.h then
print(
Syntax: xinput [options] <file>
By default the Lua program "xindex" creates a so-called
.ind file, which has the same main filename as the input file
unless you are using the option "-o <output file>"  There will 
be no log file created. 
)
end
]]


--[[
if not args["input"] then 
  io.write ("Filename: ")
  inFile = io.read()
else
  inFile = args["input"]
end
]]

require('xindex-lib')

inFile = args["input"]
if not file_exists(inFile) then
  if file_exists(inFile..".idx") then
    inFile = inFile..".idx"
  else
    writeLog(2,"Inputfile "..inFile.." or "..inFile..".idx not found!\n",0)
    os.exit()
  end
end  

local filename
local logfilename
if args["output"] == '""' then
  if inFile:sub(inFile:len()-3,inFile:len()) == ".idx" then 
    filename = inFile:sub(1,inFile:len()-3).."ind"
    logfilename = inFile:sub(1,inFile:len()-3).."ilg"
  else
    filename = inFile..".ind"
    logfilename = inFile..".ilg"
  end
else
  filename = args.output
  logfilename = filename:gsub('%p...','')..".ilg"
end

logFile = io.open(logfilename,"w+")
writeLog(2,"xindex v."..version.." (c) Herbert Voß\n",-1)
writeLog(1,"Verbose level = "..vlevel.."\n",1)

writeLog(2,"Open outputfile "..filename,0)
outFile = io.open(filename,"w+")
writeLog(2," ... done\n",0)

if vlevel > 0 then
  writeLog(1,"---------- parameter ----------\n",1)
  for k,v in pairs(args) do
    writeLog(1,tostring(k)..", "..tostring(v).."\n",1)
  end
  for k=1,#args.v do 
    writeLog(1,"v["..k.."]= "..tostring(args.v[k]).."\n",1) 
  end
  writeLog(1,"---------- parameter ----------\n",1)
end

writeLog(2,"Using input file: "..inFile.."\n",0)

labelPrefix = args.prefix
writeLog(2,"Label prefix: "..labelPrefix.."\n",-1)

writeLog(2,"Loading common config file ".."xindex-cfg-common\n",1)
Config_File_Common = kpse.find_file("xindex-cfg-common.lua") 
cfg_common = require(Config_File_Common)

local config_file = "xindex-"..args.config..".lua"
writeLog(2,"Loading local config file "..config_file,0)
Config_File = kpse.find_file(config_file) 
cfg = require(Config_File)
writeLog(2," ... done\n",0)

local esc_char = args.escapechar
writeLog(2,"Escapechar = "..esc_char.."\n",1)
escape_chars = { -- by default " is the escape char
  {esc_char..'"', '//escapedquote//', '\\"{}' },
  {esc_char..'@', '//escapedat//',    '@'    },
  {esc_char..'|', '//escapedvert//',  "|"    },
  {esc_char..'!', '//scapedexcl//',  '!'    }
}

language = string.lower(args["language"])
writeLog(2,"Language = "..language.."\n",1) 
index_header = indexheader[language]
if vlevel > 0 then for i=1,#index_header do writeLog(2,index_header[i].."\n",1) end end
page_folium = folium[language]


no_caseSensitive = args["no_casesensitive"]
if no_caseSensitive then
  writeLog(1,"Sorting will be no case sensitive\n",1)
else
  writeLog(1,"Sorting will be case sensitive\n",1)
end

no_headings = args["noheadings"]
if no_headings then
  writeLog(1,"Output with NO headings between different first letter\n",1)
else
  writeLog(1,"Output with headings between different first letter\n",1)
end

writeLog(2,"Open outputfile "..filename,0)
outFile = io.open(filename,"w+")
writeLog(2,"... done\n",0)


writeLog(1,"Starting base file ... \n",2)
BaseRunFile = kpse.find_file("xindex-base.lua") 
dofile(BaseRunFile)

logFile:close()


