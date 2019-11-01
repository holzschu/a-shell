#!/usr/bin/env texlua
--
-- diadia [options]
--
-- loads and processes a diadia data file
--
-- License: LPPL
--
local version = "v1.0 (2015/05/15)"

local infile = ""
local outfile = ""
local mode = "*"
local startdate = ""
local enddate = ""
local columns = ""
local data = {}
function pversion()
  print("diadia.lua " .. version)
  print("(C) Josef Kleber 2015   License: LPPL")
  os.exit(0)
end
function phelp()
  print([[
diadia.lua [options]

 allows you to

 - cut a chunk out of the data file
   e.g.: -i in.dat -o out.dat -s YYYY-MM-DD -e YYYY-MM-DD

 - compose a new data file based on given columns of an
   existing data file
   e.g.: -i in.dat -o out.dat -c 1,2

 - create a new data file with date and value (1st and
   2nd column of existing file) and added value average
   columns of the last 7, 14, 30, 60 and 90 days
   e.g.: -i in.dat -o out.dat [-s YYYY-MM-DD -e YYYY-MM-DD]

 Options:

 -m  specify the mode (cut|compose|average)

 -i  specify the input file

 -o  specify the output file

 -c  specify the columns for compose mode

 -s  specify the start date (YYYY-MM-DD) in
     cut and average mode

 -e  specify the end date

 -v  prints version information

 -h  prints help information

]])
  pversion()
end
function check_date(date)
  if string.find(date, "(%d%d%d%d)-(%d%d)-(%d%d)") == nil
  then
    io.stderr:write ("Error 21: wrong date format (YYYY-MM-DD)\n")
    os.exit(11)
  end
end
function parse_date(date)
  return string.match(date, "(%d%d%d%d)%-(%d%d)%-(%d%d)")
end
function parse_dateinline(line)
  return string.match(line, "(%d%d%d%d%-%d%d%-%d%d)")
end
function daystring(unixtime)
  return os.date("%Y-%m-%d", unixtime)
end
function unixtime(year,month,day)
  return os.time{year=year, month=month, day=day}
end
function round(number)
  return math.floor(number+0.5)
end
function ptd(value)
  local val = tostring(value)
  local slen = string.len(val)
  if slen == 3
  then
    return val
  else
    return val .. " "
  end
end
function calc_avg(data,date,days)
  local sum = 0
  local wdays = 0
  local wday
  local endday = unixtime(parse_date(date))
  local startday = endday - 60*60*24*(days-1)
  while startday <= endday
  do
    wday = daystring(startday)
    if data[wday] ~= nil
    then
      sum = sum + data[wday]
      wdays = wdays + 1
    end
    startday = startday + 60*60*24
  end
  if wdays == 0
  then
    return "nan"
  else
    return tostring(round(sum/wdays))
  end
end
function read_data(file)
  local data = {}
  local date
  local startdate
  local enddate
  local dat
  local firstline = true
  for line in io.lines(file)
  do
    if string.match(line, "date")
    then
    else
      date, dat = string.match(line, "(%d%d%d%d%-%d%d%-%d%d)%s+(%S+)")
      if firstline == true
      then
        startdate = date
        firstline = false
      end
      if dat ~= "nan" and dat ~= "{}" and dat ~= ""
      then
        data[date] = dat
      end
    end
  end
  enddate = date
  return data,startdate,enddate
end
function write_avg_file(data,file,startdate,enddate)
  local sdate
  local edate
  local wday
  sdate = unixtime(parse_date(startdate))
  edate = unixtime(parse_date(enddate))
  outfile = assert(io.open(file, "w"))
  outfile:write("date        value avg07 avg14 avg30 avg60 avg90")
  while sdate <= edate+7200
  do
    wday = daystring(sdate)
    if data[wday] ~= nil
    then
      outfile:write("\n" .. wday .. "  "
                    .. ptd(data[wday]) .. "   "
                    .. ptd(calc_avg(data,wday,7)) .. "   "
                    .. ptd(calc_avg(data,wday,14)) .. "   "
                    .. ptd(calc_avg(data,wday,30)) .. "   "
                    .. ptd(calc_avg(data,wday,60)) .. "   "
                    .. ptd(calc_avg(data,wday,90)))
    end
    sdate = sdate + 60*60*24
  end
  outfile:close()
end
do
  local newarg = {}
  local i, limit = 1, #arg
  while (i <= limit) do
    if arg[i] == "-i" then
      infile = arg[i+1]
      i = i + 1
    elseif arg[i] == "-o" then
      outfile = arg[i+1]
      i = i + 1
    elseif arg[i] == "-s" then
      startdate = arg[i+1]
      i = i + 1
    elseif arg[i] == "-e" then
      enddate = arg[i+1]
      i = i + 1
    elseif arg[i] == "-c" then
      columns = arg[i+1]
      i = i + 1
    elseif arg[i] == "-m" then
      mode = arg[i+1]
      i = i + 1
    elseif arg[i] == "-v" then
      pversion()
    elseif arg[i] == "-h" then
      phelp()
    else
      newarg[#newarg+1] = arg[i]
    end
    i = i + 1
  end
  arg = newarg
end
if mode == "average"
then
  local startd
  local endd

  print("set mode to " .. mode)
  print("reading data file " .. infile)
  data,startd,endd = read_data(infile)
  if startdate ~= ""
  then
    startd = startdate
  end
  if enddate ~= ""
  then
    endd = enddate
  end
  print("writing data file " .. outfile)
  write_avg_file(data,outfile,startd,endd)
  os.exit(0)
end
if mode == "compose"
then
  local row = 0
  local column = 0
  local ofile
  local cols

  print("set mode to " .. mode)
  print("reading data file " .. infile)
  for line in io.lines(infile)
  do
    row = row + 1
    data[row] = {}
    column = 0
    for value in string.gmatch(line, "%S+")
    do
      column = column + 1
      data[row][column] = value
    end
  end
  cols = assert(load("return table.concat({"..columns:gsub("%d+","(...)[%0]").."},'  ')"))
  ofile = assert(io.open(outfile, "w"))
  print("writing data file " .. outfile)
  for irow = 1,row
  do
    if irow == row
    then
      ofile:write(cols(data[irow]))
    else
      ofile:write(cols(data[irow]).."\n")
    end
  end
  ofile:close()
  os.exit(0)
end
if mode == "cut"
then
  local ofile
  local date
  local sdate
  local edate
  local cdate

  check_date(startdate)
  check_date(enddate)
  sdate = unixtime(parse_date(startdate))
  edate = unixtime(parse_date(enddate))
  print("set mode to " .. mode)
  print("reading data file " .. infile)
  print("writing data file " .. outfile)
  ofile = assert(io.open(outfile, "w"))
  for line in io.lines(infile)
  do
    if string.match(line, "date")
    then
      ofile:write(line)
    else
      date = parse_dateinline(line)
      cdate = unixtime(parse_date(date))
      if cdate >= sdate and cdate <= edate
      then
        ofile:write("\n" .. line)
      end
    end
  end
  ofile:close()
  os.exit(0)
end
if mode == "*"
then
  io.stderr:write ("Error 11: no mode specified!")
  os.exit(11)
else
  io.stderr:write ("Error 12: invalid mode " .. mode)
  os.exit(12)
end
