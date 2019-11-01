#!/usr/bin/env texlua
--[[
   File   : makeglossaries-lite.lua
   Author : Nicola Talbot
   
   Lua alternative to the makeglossaries Perl script.

   Since Lua has limitations, this script isn't an exact
   replacement to the Perl script. In particular the makeglossaries -d 
   switch isn't implemented in this Lua version.
   This also doesn't provide the more detailed diagnostics that the Perl
   version does nor does it attempt any language mappings. Since xindy
   requires Perl, don't use this script if you want to use xindy. Instead
   use the Perl makeglossaries script.
  
   This file is distributed as part of the glossaries LaTeX package.
   Copyright 2015 Nicola L.C. Talbot
   This work may be distributed and/or modified under the
   conditions of the LaTeX Project Public License, either version 1.3
   of this license or any later version.
   The latest version of this license is in
     http://www.latex-project.org/lppl.txt
   and version 1.3 or later is part of all distributions of LaTeX
   version 2005/12/01 or later.
  
   This work has the LPPL maintenance status `maintained'.

   This work consists of the files glossaries.dtx and glossaries.ins 
   and the derived files glossaries.sty, glossaries-prefix.sty,
   glossary-hypernav.sty, glossary-inline.sty, glossary-list.sty, 
   glossary-long.sty, glossary-longbooktabs.sty, glossary-longragged.sty,
   glossary-mcols.sty, glossary-super.sty, glossary-superragged.sty, 
   glossary-tree.sty, glossaries-compatible-207.sty, 
   glossaries-compatible-307.sty, glossaries-accsupp.sty, 
   glossaries-babel.sty, glossaries-polyglossia.sty, glossaries.perl.
   Also makeglossaries and makeglossaries-lite.lua.
  
   History:
   * 4.41:
     - no change.
   * 4.40:
     - no change.
   * 4.39:
     - corrected script name in version and help messages
   * 4.38:
     - no change.
   * 4.37:
     - no change.
   * 4.36:
     - fixed check for double-quotes (from \jobname when the file name 
       contains spaces).
   * 4.35:
     - no change.
   * 4.34:
     - added check for \glsxtr@resource
   * 4.33:
     - version number synchronized with glossaries.sty
   * 1.3
     - added check for \glsxtr@makeglossaries
   * 1.2 (2016-05-27)
     - added check for \@gls@extramakeindexopts
     - added check for nil codepage
   * 1.1
     - changed first line from lua to texlua
--]]

thisversion = "4.41 (2018-07-23)"

quiet = false
dryrun = false

infile = nil
outfile = nil
styfile = nil
logfile = nil

isxindy = false

isbib2gls = false

xindylang = nil
xindyexec = "xindy"

makeindex_c = false
makeindex_g = false
letterorder = false
makeindex_r = false
makeindex_p = nil
makeindex_extra = nil
makeindex_m = "makeindex"

function version()

  verYear = string.match(thisversion, "%d%d%d%d");

  print(string.format("makeglossaries-lite version %s", thisversion))
  print(string.format("Copyright (C) 2015-%s Nicola L C Talbot", verYear))
  print("This material is subject to the LaTeX Project Public License.")
end

function help()
  version()
  print([[
Syntax : makeglossaries-lite [options] <filename>

For use with the glossaries package to pass relevant
files to makeindex or xindy.

<filename>	Base name of glossary file(s). This should
		be the name of your main LaTeX document without any
		extension. If you do add an extension, only that
		glossary file will be processed.

General Options:

-o <gls>	Use <gls> as the output file.
		(Don't use -o if you have more than one glossary.)
-s <sty>	Employ <sty> as the style file.
-t <log>	Employ <log> as the transcript file.
		(Don't use -t if you have more than one glossary
		or the transcripts will be overwritten.)
-q		Quiet mode.
-l		Letter ordering.
-n		Print the command that would normally be executed,
		but don't execute it (dry run).
--help		Print this help message.
--version	Print the version.

Xindy Options:

-L <language>	Use <language>.
-x <file>	Full path to xindy executable.
		(Default assumes xindy is on the operating system's path.)

Makeindex Options:
(See makeindex documentation for further details on these options.)

-c		Compress intermediate blanks.
-g		Employ German word ordering.
-p <num>	Set the starting page number to be <num>.
-r		Disable implicit page range formation.
-m <file>	Full path to makeindex executable.
		(Default assumes makeindex is on the operating system's path.)

This is a light-weight Lua alternative to the makeglossaries Perl script.
If you want to use xindy, it's better to use the Perl makeglossaries version
instead.

]])
end

function dorun(name, glg, gls, glo, language, codepage)

  if isxindy then
    doxindy(name, glg, gls, glo, language, codepage)
  else
    domakeindex(name, glg, gls, glo)
  end

end

function doxindy(name, glg, gls, glo, language, codepage)

  if codepage == nil
  then
     codepage = "utf8"
  end

  cmd = string.format('"%s" -I xindy -L %s -C %s -M "%s" -t "%s" -o "%s"',
    xindyexec, language, codepage, styfile, glg, gls)

  if letterorder then cmd = string.format('%s -M ord/letorder', cmd) end

  if quiet then cmd = string.format('%s -q', cmd) end

  cmd = string.format('%s "%s"', cmd, glo)

  if dryrun then

    print(cmd)

  else

    assert(os.execute(cmd), 
     string.format("Failed to execute '%s'", cmd))

  end

end

function domakeindex(name, glg, gls, glo)

  cmd = string.format('"%s"', makeindex_m)

  if makeindex_c then cmd = cmd .. " -c" end

  if makeindex_g then cmd = cmd .. " -g" end

  if letterorder then cmd = cmd .. " -l" end

  if makeindex_extra then cmd = cmd .. " " .. makeindex_extra end

  if quiet then cmd = cmd .. " -q" end

  if glg ~= nil then cmd = string.format('%s -t "%s"', cmd, glg) end

  if gls ~= nil then cmd = string.format('%s -o "%s"', cmd, gls) end

  if makeindex_p ~= nil then 
    cmd = string.format("%s -p %s", cmd, makeindex_p)
  end

  if styfile ~= nil then 
    cmd = string.format('%s -s "%s"', cmd, styfile)
  end

  cmd = string.format('%s "%s"', cmd, glo)

  if dryrun then
    print(cmd)
  else
    assert(os.execute(cmd), 
     string.format("Failed to execute '%s'", cmd))
  end

end

if #arg < 1
then
  error("Syntax error: filename expected. Use --help for help.")
end

i = 1

while i <= #arg do

-- General Options
  if arg[i] == "-q" then
    quiet = true
  elseif arg[i] == "-n"
  then
    dryrun = true
  elseif arg[i] == "-o"
  then
    i = i + 1
    if i > #arg then error("-o requires a filename") end
    outfile = arg[i]
  elseif arg[i] == "-s"
  then
    i = i + 1
    if i > #arg then error("-s requires a filename") end
    styfile = arg[i]
  elseif arg[i] == "-t"
  then
    i = i + 1
    if i > #arg then error("-t requires a filename") end
    logfile = arg[i]
  elseif arg[i] == "--version"
  then
    version()
    os.exit()
  elseif arg[i] == "--help"
  then
    help()
    os.exit()
-- General options for the Perl version that aren't implemented by
-- this light-weight version:
  elseif (arg[i] == "-Q") or (arg[i] == "-k")
  then
    print(string.format("Ignoring option '%s' (only available with the Perl version).", arg[i]))
  elseif arg[i] == "-d"
  then
    error(string.format(
      "The '%s' option isn't available for this light-weight version.\nYou will need to use the Perl version instead.",
      arg[i]))

-- Xindy Options
  elseif arg[i] == "-L"
  then
    i = i + 1
    if i > #arg then error("-L requires a language name") end
    xindylang = arg[i]
  elseif arg[i] == "-x"
  then
    i = i + 1
    if i > #arg then error("-x requires a filename") end
    xindyexec = arg[i]

-- Makeindex Options
  elseif arg[i] == "-c"
  then
    makeindex_c = true
  elseif arg[i] == "-g"
  then
    makeindex_g = true
  elseif arg[i] == "-l"
  then
    letterorder = true
  elseif arg[i] == "-r"
  then
    makeindex_r = true
  elseif arg[i] == "-p"
  then
    i = i + 1
    if i > #arg then error("-p requires a page number") end
    makeindex_p = arg[i]
  elseif arg[i] == "-m"
  then
    i = i + 1
    if i > #arg then error("-m requires a filename") end
    makeindex_m = arg[i]

-- Unknown Option
  elseif string.sub(arg[i], 1, 1) == "-"
  then
    error(
      string.format("Syntax error: unknown option '%s'. Use '--help' for help.",
                    arg[i]));

-- Input file
  elseif infile == nil
  then
    infile = arg[i]
  else
    error("Syntax error: only one filename permitted");
  end

  i = i + 1
end

if not quiet then
  print(string.format("makeglossaries.lua version %s", thisversion))
end

if infile == nil
then
  error("Syntax error: missing filename")
end

i, j = string.find(infile, "%.%a*$")

ext = nil
inbase = infile

if i ~= nil
then
   ext = string.sub(infile, i, j);

   lext = string.lower(ext)

   inbase = string.sub(infile, 1, i-1);

   -- Just in case user has accidentally specified the aux or tex file
   if lext == ".aux" or lext == ".tex"
   then
     ext = nil
     infile = inbase
   end
end

auxfile = inbase..".aux"

if not quiet then print(string.format("Parsing '%s'", auxfile)) end

assert(io.input(auxfile), 
  string.format("Unable to open '%s'", auxfile))

aux = io.read("*a")

if string.find(aux, "\\glsxtr@resource") ~= nil
then
  isbib2gls = true
end

if styfile == nil
then

-- v4.36: corrected check for double-quotes

  styfile = string.match(aux, "\\@istfilename{([^}]*)}")
  styfile = string.gsub(styfile, "\"", "");

  if styfile == nil
  then
    if isbib2gls
    then
       error([[
No \@istfilename found but found \glsxtr@resource.
You need to run bib2gls not makeglossaries-lite.
  ]])
    else
       error([[
No \@istfilename found.
Did your LaTeX run fail?
Did your LaTeX run produce any output?
Did you remember to use \makeglossaries?
  ]])
    end
  end
end

i = string.len(styfile)

if string.sub(styfile, i-3, i) == ".xdy"
then
  isxindy = true
end

if not letterorder
then
  if string.match(aux, "\\@glsorder{letter}") ~= nil
  then
    letterorder = true
  end
end

makeindex_extra = string.match(aux, "\\@gls@extramakeindexopts{([^}]*%.?%a*)}")

if dryrun then print("Dry run mode. No commands will be executed.") end

onlyname = nil

glossaries = {}

for name, glg, gls, glo in 
  string.gmatch(aux, "\\@newglossary{([^}]+)}{([^}]+)}{([^}]+)}{([^}]+)}") do

  if not quiet then
    print(string.format("Found glossary type '%s' (%s,%s,%s)",
      name, glg, gls, glo))
  end

  glossaries[name] = {}

  glossaries[name].glg = glg
  glossaries[name].gls = gls
  glossaries[name].glo = glo

  if "."..glo == ext then

    onlyname = name

  end

  if isxindy then

    if xindylang == nil then
       glossaries[name].language = string.match(aux, 
         "\\@xdylanguage{"..name.."}{([^}]+)}");
    else
       glossaries[name].language = xindylang
    end

    glossaries[name].codepage = string.match(aux, 
      "\\@gls@codepage{"..name.."}{([^}]+)}");

  end

end

onlytypes = string.match(aux, "\\glsxtr@makeglossaries{([^}]+)}")

if onlytypes ~= nil
then
  if not quiet then
    print(string.format("Only process subset: '%s'", onlytypes))
  end

  onlyglossaries = {}

  for name in string.gmatch(onlytypes, '([^,]+)') do
     onlyglossaries[name] = glossaries[name]
  end

  glossaries = onlyglossaries
end

if ext == nil
then

  done = false

  for name, value in pairs(glossaries) do

    glg = value.glg
    gls = value.gls
    glo = value.glo

    if logfile == nil then
      glg = inbase .. "." .. glg
    else
      glg = logfile
    end

    if outfile == nil then
      gls = inbase .. "." .. gls
    else
      gls = outfile
    end

    glo = infile .. "." .. glo

    dorun(name, glg, gls, glo, value.language, value.codepage)

    done = true
  end

  if not done then
    error([[
No \@newglossary commands found in aux file.
Did you remember to use \makeglossaries?
Did you accidentally suppress the default glossary using "nomain"
and not provide an alternative glossary?
]])
  end

else

  if onlyname == nil then

     glo = infile
     gls = outfile
     glg = logfile

     language = xindylang
     codepage = 'utf8'

     if language == nil then language = 'english' end

     if gls == nil then gls = infile..".gls" end

  else

    value = glossaries[onlyname]

    glg = value.glg
    gls = value.gls
    glo = infile

    if logfile == nil then
      glg = inbase .. "." .. glg
    else
      glg = logfile
    end

    if outfile == nil then
      gls = inbase .. "." .. gls
    else
      gls = outfile
    end

  end

  if codepage == nil then
    codepage = 'utf8';
  end

  dorun(onlyname, glg, gls, glo, language, codepage)
end
