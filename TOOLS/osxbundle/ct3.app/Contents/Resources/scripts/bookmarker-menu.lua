-- // Bookmarker Menu v1.3.1 for mpv \\ --
-- See README.md for instructions

-- Maximum number of characters for bookmark name
local maxChar = 50
-- Number of bookmarks to be displayed per page
local bookmarksPerPage = 10
-- Whether to close the Bookmarker menu after loading a bookmark
local closeAfterLoad = true
-- Whether to close the Bookmarker menu after replacing a bookmark
local closeAfterReplace = true
-- Whether to ask for confirmation to replace a bookmark (Uses the Typer for confirmation)
local confirmReplace = false
-- Whether to ask for confirmation to delete a bookmark (Uses the Typer for confirmation)
local confirmDelete = true
-- The rate (in seconds) at which the bookmarker needs to refresh its interface; lower is more frequent
local rate = 1.5
-- The filename for the bookmarks file
local bookmarkerName = "bookmarker.json"
-- All the "global" variables and utilities; don't touch these
local utils = require 'mp.utils'
local styleOn = mp.get_property("osd-ass-cc/0")
local styleOff = mp.get_property("osd-ass-cc/1")
local bookmarks = {}
local currentSlot = 0
local currentPage = 1
local maxPage = 1
local active = false
local mode = "none"
local bookmarkStore = {}
local oldSlot = 0

-- // Controls \\ --

-- List of custom controls and their function
local bookmarkerControls = {
  ESC = function() abort("") end,
  k = function() jumpSlot(1) end,--
  i = function() jumpSlot(-1) end,--
  j = function() jumpPage(-1) end,--
  l = function() jumpPage(1) end,--
  RIGHT = function() seek(0.1) end,--
  LEFT = function() seek(-0.1) end,--
  UP = function() seekf(1) end,--
  DOWN = function() seekf(0) end,--
  --k = function() cycleseek() end,
  a = function() addBookmark() end,--
  --j = function() endpoint() end,--
  --l = function() jumpTostartend(currentSlot) end,--
  --L = function() jumpToLOOP(currentSlot) end,--
  --E = function() export() end,--
  --M = function() mosh() end,
  --S = function() mode="save" typerStart() end,
  ['Shift+a'] = function() mode="replace" typerStart() end,--
  --r = function() mode="rename" typerStart() end,
  --f = function() mode="filepath" typerStart() end,
  ['Ctrl+a'] = function() mode="move" moverStart() end,--
  ['Alt+a'] = function() mode="delete" typerStart() end,--
  ENTER = function() jumpToBookmark(currentSlot) end,--
  KP_ENTER = function() jumpToBookmark(currentSlot) end,--
  
  GAMEPAD_BACK = function() abort("") end,
  GAMEPAD_DPAD_DOWN = function() jumpSlot(1) end,--
  GAMEPAD_DPAD_UP = function() jumpSlot(-1) end,--
  GAMEPAD_LEFT_STICK_DOWN = function() seek(0.1) end,--
  GAMEPAD_LEFT_STICK_UP  = function() seek(-0.1) end,--
  GAMEPAD_DPAD_RIGHT = function() seekf(1) end,--
  GAMEPAD_DPAD_LEFT = function() seekf(0) end,--
  --k = function() cycleseek() end,
  ['Meta+GAMEPAD_DPAD_LEFT'] = function() jumpPage(-1) end,--
  ['Meta+GAMEPAD_DPAD_RIGHT'] = function() jumpPage(1) end,--
  GAMEPAD_ACTION_LEFT = function() addBookmark() end,--
  --j = function() endpoint() end,--
  --l = function() jumpTostartend(currentSlot) end,--
  --L = function() jumpToLOOP(currentSlot) end,--
  --E = function() export() end,--
  --M = function() mosh() end,
  --S = function() mode="save" typerStart() end,
  ['Shift+GAMEPAD_ACTION_LEFT'] = function() mode="replace" typerStart() end,--
  --r = function() mode="rename" typerStart() end,
  --f = function() mode="filepath" typerStart() end,
  ['Shift+GAMEPAD_BACK'] = function() mode="move" moverStart() end,--
  GAMEPAD_ACTION_UP = function() mode="delete" typerStart() end,--
  GAMEPAD_START = function() jumpToBookmark(currentSlot) end,--
}


local bookmarkerFlags = {
  DOWN = {repeatable = true},
  UP = {repeatable = true},
  RIGHT = {repeatable = true},
  LEFT = {repeatable = true},
  GAMEPAD_LEFT_STICK_DOWN = {repeatable = true},
  GAMEPAD_LEFT_STICK_UP  = {repeatable = true},
  GAMEPAD_LEFT_STICK_RIGHT = {repeatable = true},
  GAMEPAD_LEFT_STICK_LEFT = {repeatable = true},
}

-- Activate the custom controls
function activateControls(name, controls, flags)
  for key, func in pairs(controls) do
    
    mp.add_forced_key_binding(key, name..key, func, flags[key])

  end
end

-- Deactivate the custom controls
function deactivateControls(name, controls)
  for key, _ in pairs(controls) do
    mp.remove_key_binding(name..key)
  end
end

-- // Typer \\ --

-- Controls for the Typer
local typerControls = {
  ESC = function() typerExit() end,
  ENTER = function() typerCommit() end,
  KP_ENTER = function() typerCommit() end,
  RIGHT = function() typerCursor(1) end,
  LEFT = function() typerCursor(-1) end,
  BS = function() typer("backspace") end,
  DEL = function() typer("delete") end,
  SPACE = function() typer(" ") end,
  SHARP = function() typer("#") end,
  KP0 = function() typer("0") end,
  KP1 = function() typer("1") end,
  KP2 = function() typer("2") end,
  KP3 = function() typer("3") end,
  KP4 = function() typer("4") end,
  KP5 = function() typer("5") end,
  KP6 = function() typer("6") end,
  KP7 = function() typer("7") end,
  KP8 = function() typer("8") end,
  KP9 = function() typer("9") end,
  KP_DEC = function() typer(".") end

}

-- All standard keys for the Typer
local typerKeys = {"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","1","2","3","4","5","6","7","8","9","0","!","@","$","%","^","&","*","(",")","-","_","=","+","[","]","{","}","\\","|",";",":","'","\"",",",".","<",">","/","?","`","~"}
-- For some reason, semicolon is not possible, but it's listed there just in case anyway

local typerText = ""
local typerPos = 0
local typerActive = false

-- Function to activate the Typer
-- use typerStart() for custom controls around activating the Typer
function activateTyper()
  for key, func in pairs(typerControls) do
    mp.add_forced_key_binding(key, "typer"..key, func, {repeatable=true})
  end
  for i, key in ipairs(typerKeys) do
    mp.add_forced_key_binding(key, "typer"..key, function() typer(key) end, {repeatable=true})
  end
  typerText = ""
  typerActive = true
end

-- Function to deactivate the Typer
-- use typerExit() for custom controls around deactivating the Typer
function deactivateTyper()
  for key, _ in pairs(typerControls) do
    mp.remove_key_binding("typer"..key)
  end
  for i, key in ipairs(typerKeys) do
    mp.remove_key_binding("typer"..key)
  end
  typerActive = false
  return typerText
end

-- Function to move the cursor of the typer; can wrap around
function typerCursor(direction)
  typerPos = typerPos + direction
  if typerPos < 0 then typerPos = typerText:len() end
  if typerPos > typerText:len() then typerPos = 0 end
  typer("")
end

-- Function for handling the text as it is being typed
function typer(s)
  -- Don't touch this part
  if s == "backspace" then
    if typerPos > 0 then
      typerText = typerText:sub(1, typerPos - 1) .. typerText:sub(typerPos + 1)
      typerPos = typerPos - 1
    end
  elseif s == "delete" then
    if typerPos < typerText:len() then
      typerText = typerText:sub(1, typerPos) .. typerText:sub(typerPos + 2)
    end
  else
    if mode == "filepath" or typerText:len() < maxChar then
      typerText = typerText:sub(1, typerPos) .. s .. typerText:sub(typerPos + 1)
      typerPos = typerPos + s:len()
    end
  end

  -- Enter custom script and display message here
  local preMessage = "Enter a bookmark name:"
  if mode == "save" then
    preMessage = styleOn.."{\\b1}Save a new bookmark with custom name:{\\b0}"..styleOff
  elseif mode == "replace" then
    preMessage = styleOn.."{\\b1}Type \"y\" to replace the following bookmark:{\\b0}\n"..displayName(bookmarks[currentSlot]["name"])..styleOff
  elseif mode == "delete" then
    preMessage = styleOn.."{\\b1}Type \"y\" to delete the following bookmark:{\\b0}\n"..displayName(bookmarks[currentSlot]["name"])..styleOff
  elseif mode == "rename" then
    preMessage = styleOn.."{\\b1}Rename an existing bookmark:{\\b0}"..styleOff
  elseif mode == "filepath" then
    preMessage = styleOn.."{\\b1}Change the bookmark's filepath:{\\b0}"..styleOff
  end

  local postMessage = ""
  local split = typerPos + math.floor(typerPos / maxChar)
  local messageLines = math.floor((typerText:len() - 1) / maxChar) + 1
  for i = 1, messageLines do
    postMessage = postMessage .. typerText:sub((i-1) * maxChar + 1, i * maxChar) .. "\n"
  end
  postMessage = postMessage:sub(1,postMessage:len()-1)

  mp.osd_message(preMessage.."\n"..postMessage:sub(1,split)..styleOn.."{\\c&H00FFFF&}{\\b1}|{\\r}"..styleOff..postMessage:sub(split+1), 9999)
  
end

-- // Mover \\ --

-- Controls for the Mover
local moverControls = {
  ESC = function() moverExit() end,
  k = function() jumpSlot(1) end,
  i = function() jumpSlot(-1) end,
  l = function() jumpPage(1) end,
  j = function() jumpPage(-1) end,
  a = function() addBookmark() end,
  ENTER = function() moverCommit() end,
  KP_ENTER = function() moverCommit() end,
  GAMEPAD_BACK = function() moverExit() end,
  GAMEPAD_DPAD_DOWN = function() jumpSlot(1) end,
  GAMEPAD_DPAD_UP = function() jumpSlot(-1) end,
  GAMEPAD_DPAD_RIGHT = function() jumpPage(1) end,
  GAMEPAD_DPAD_LEFT = function() jumpPage(-1) end,
  GAMEPAD_ACTION_LEFT = function() addBookmark() end,
  GAMEPAD_START = function() moverCommit() end,
}

local moverFlags = {
  DOWN = {repeatable = true},
  UP = {repeatable = true},
  RIGHT = {repeatable = true},
  LEFT = {repeatable = true},
  GAMEPAD_DPAD_DOWN = {repeatable = true},
  GAMEPAD_DPAD_UP = {repeatable = true},
  GAMEPAD_DPAD_RIGHT = {repeatable = true},
  GAMEPAD_DPAD_LEFT = {repeatable = true},
}

-- Function to activate the Mover
function moverStart()
  if bookmarkExists(currentSlot) then
    deactivateControls("bookmarker", bookmarkerControls)
    activateControls("mover", moverControls, moverFlags)
    displayBookmarks()
  else
    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the bookmark at slot "..currentSlot)
  end
end

-- Function to commit the action of the Mover
function moverCommit()
  saveBookmarks()
  moverExit()
end

-- Function to deactivate the Mover
-- If isError is set, then it'll abort
function moverExit(isError)
  deactivateControls("mover", moverControls)
  mode = "none"
  if not isError then
    loadBookmarks()
    displayBookmarks()
    activateControls("bookmarker", bookmarkerControls, bookmarkerFlags)
  end
end

-- // General utilities \\ --

-- Check if the operating system is Mac OS
function isMacOS()
  local homedir = os.getenv("HOME")
  return (homedir ~= nil and string.sub(homedir,1,6) == "/Users")
end

-- Check if the operating system is Windows
function isWindows()
  local windir = os.getenv("windir")
  return (windir~=nil)
end

-- Check whether a certain file exists
function fileExists(path)
  local f = io.open(path,"r")
  if f~=nil then
    io.close(f)
    return true
  else
    return false
  end
end

-- Get the filepath of a file from the mpv config folder
function getFilepath(filename)
  if isWindows() then
  	return os.getenv("APPDATA"):gsub("\\", "/") .. "/mpv/" .. filename
  else	
	return os.getenv("HOME") .. "/.config/mpv/" .. filename
  end
end

-- Load a table from a JSON file
-- Returns nil if the file can't be found
function loadTable(path)
  local contents = ""
  local myTable = {}
  local file = io.open( path, "r" )
  if file then
    local contents = file:read( "*a" )
    myTable = utils.parse_json(contents);
    io.close(file)
    return myTable
  end
  return nil
end

-- Save a table as a JSON file file
-- Returns true if successful
function saveTable(t, path)
  local contents = utils.format_json(t)
  local file = io.open(path .. ".tmp", "wb")
  file:write(contents)
  io.close(file)
  os.remove(path)
  os.rename(path .. ".tmp", path)
  return true
end

-- Convert a pos (seconds) to a hh:mm:ss.mmm format
function parseTime(pos)
  local hours = math.floor(pos/3600)
  local minutes = math.floor((pos % 3600)/60)
  local seconds = math.floor((pos % 60))
  local milliseconds = math.floor(pos % 1 * 1000)
  return string.format("%02d:%02d:%02d.%03d",hours,minutes,seconds,milliseconds)
end

-- // Bookmark functions \\ --

-- Checks whether the specified bookmark exists
function bookmarkExists(slot)
  return (slot >= 1 and slot <= #bookmarks)
end

-- Calculates the current page and the total number of pages
function calcPages()
  currentPage = math.floor((currentSlot - 1) / bookmarksPerPage) + 1
  if currentPage == 0 then currentPage = 1 end
  maxPage = math.floor((#bookmarks - 1) / bookmarksPerPage) + 1
  if maxPage == 0 then maxPage = 1 end
end

-- Get the amount of bookmarks on the specified page
function getAmountBookmarksOnPage(page)
  local n = bookmarksPerPage
  if page == maxPage then n = #bookmarks % bookmarksPerPage end
  if n == 0 then n = bookmarksPerPage end
  if #bookmarks == 0 then n = 0 end
  return n
end

-- Get the index of the first slot on the specified page
function getFirstSlotOnPage(page)
  return (page - 1) * bookmarksPerPage + 1
end

-- Get the index of the last slot on the specified page
function getLastSlotOnPage(page)
  local endSlot = getFirstSlotOnPage(page) + getAmountBookmarksOnPage(page) - 1
  if endSlot > #bookmarks then endSlot = #bookmarks end
  return endSlot
end

-- Jumps a certain amount of slots forward or backwards in the bookmarks list
-- Keeps in mind if the current mode is to move bookmarks
function jumpSlot(i)
  if mode == "move" then
    oldSlot = currentSlot
    bookmarkStore = bookmarks[oldSlot]
  end

  currentSlot = currentSlot + i
  local startSlot = getFirstSlotOnPage(currentPage)
  local endSlot = getLastSlotOnPage(currentPage)

  if currentSlot < startSlot then currentSlot = endSlot end
  if currentSlot > endSlot then currentSlot = startSlot end

  if mode == "move" then
    table.remove(bookmarks, oldSlot)
    table.insert(bookmarks, currentSlot, bookmarkStore)
  end

  displayBookmarks()
end

-- Jumps a certain amount of pages forward or backwards in the bookmarks list
-- Keeps in mind if the current mode is to move bookmarks
function jumpPage(i)
  if mode == "move" then
    oldSlot = currentSlot
    bookmarkStore = bookmarks[oldSlot]
  end

  local oldPos = currentSlot - getFirstSlotOnPage(currentPage) + 1
  currentPage = currentPage + i
  if currentPage < 1 then currentPage = maxPage + currentPage end
  if currentPage > maxPage then currentPage = currentPage - maxPage end

  local bookmarksOnPage = getAmountBookmarksOnPage(currentPage)
  if oldPos > bookmarksOnPage then oldPos = bookmarksOnPage end
  currentSlot = getFirstSlotOnPage(currentPage) + oldPos - 1
--calcPages, getAmountBookmarksOnPage , getLastSlotOnPage
  if mode == "move" then
    table.remove(bookmarks, oldSlot)
    table.insert(bookmarks, currentSlot, bookmarkStore)
  end
  
  displayBookmarks()
end

-- Parses a bookmark name for storing, also trimming it
-- Replaces %t with the timestamp of the bookmark
-- Replaces %p with the time position of the bookmark
function parseName(name)
  local pos = 0
  if mode == "rename" then pos = bookmarks[currentSlot]["pos"] else pos = mp.get_property_number("time-pos") end
  name, _ = name:gsub("%%t", parseTime(pos))
  name, _ = name:gsub("%%p", pos)
  name = trimName(name)
  return name
end

-- Parses a bookmark name for displaying, also trimming it
-- Replaces all { with an escaped { so it won't be interpreted as a tag
function displayName(name)
  name, _ = name:gsub("{", "\\{")
  name = trimName(name)
  return name
end

-- Trims a name to the max number of characters
function trimName(name)
  if name:len() > maxChar then 
    --name = name:sub(1,maxChar)
    off = maxChar - 5 
    name, pos = name:match("([^@]+) @ ([^@]+)")
    ext = name:match("^.+(%..+)$")
    
    name = name:sub(1,off-ext:len()-2) .. ext .. " @ " .. pos:sub(1,5)
  end
  name, pos = name:match("([^@]+) @ ([^@]+)")
  name = name .. " @ " .. pos:sub(1,5)
  return name
end

-- Parses a Windows path with backslashes to one with normal slashes
function parsePath(path)
  if type(path) == "string" then path, _ = path:gsub("\\", "/") end
  return path
end

-- Loads all the bookmarks in the global table and sets the current page and total number of pages
-- Also checks for older versions of bookmarks and "updates" them
-- Also checks for bookmarks made by "mpv-bookmarker" and converts them
-- Also removes anything it doesn't recognize as a bookmark
function loadBookmarks()
  bookmarks = loadTable(getFilepath(bookmarkerName))
  if bookmarks == nil then bookmarks = {} end

  local doSave = false
  local doEject = false
  local doReplace = false
  local ejects = {}
  local newmarks = {}

  for key, bookmark in pairs(bookmarks) do
    if type(key) == "number" then
      if bookmark.version == nil or bookmark.version == 1 then
        if bookmark.name ~= nil and bookmark.path ~= nil and bookmark.pos ~= nil then
          bookmark.path = parsePath(bookmark.path)
          bookmark.version = 2
          doSave = true
        else
          table.insert(ejects, key)
          doEject = true
        end
      end
    else
      if bookmark.filename ~= nil and bookmark.pos ~= nil and bookmark.filepath ~= nil then
        local newmark = {
          name = trimName(""..bookmark.filename.." @ "..parseTime(bookmark.pos)),
          pos = bookmark.pos,
          path = parsePath(bookmark.filepath),
          version = 2
        }
        table.insert(newmarks, newmark)
      end
      doReplace = true
      doSave = true
    end
  end

  if doEject then
    for i = #ejects, 1, -1 do table.remove(bookmarks, ejects[i]) end
    doSave = true
  end

  if doReplace then bookmarks = newmarks end
  if doSave then saveBookmarks() end

  if #bookmarks > 0 and currentSlot == 0 then currentSlot = 1 end
  calcPages()
end

-- Save the globally loaded bookmarks to the JSON file
function saveBookmarks()
  saveTable(bookmarks, getFilepath(bookmarkerName))
end

-- Make a bookmark of the current media file, position and name
-- Name can be specified or left blank to automake a name
-- Returns the bookmark if successful or nil if it can't make a bookmark
function makeBookmark(bname)
  if mp.get_property("path") ~= nil then
     -- if bname == nil then bname = mp.get_property("filename").." @ %p" end

   bname = mp.get_property("filename").." @ %p" 
    local bookmark = {
      name = parseName(bname),
      pos = math.floor(mp.get_property_number("time-pos")* 10000) / 10000 ,
      path = parsePath(mp.get_property("path")),
      duration = mp.get_property("duration"),
      version = 2
    }
    return bookmark
  else
    return nil
  end
end

function endpoint()
  if mp.get_property("path") ~= nil then
    oname = bookmarks[currentSlot]["name"]
    opos = bookmarks[currentSlot]["pos"]
    cpos = mp.get_property_number("time-pos")
    lpos = string.match(oname, "(%d[%d.]*)$")
    pat = string.match(oname, "%@ (%d[%d.]*) %- (%d[%d.]*)$")
       
     if ( opos == cpos ) then
     local ename = mp.get_property("filename").." @ ".. cpos
     npos = editBookmark(currentSlot, "pos", cpos)
     fname = editBookmark(currentSlot, "name", ename)

     return npos, fname
     
     --end    
     
     elseif ( cpos > opos ) then
       local ename = mp.get_property("filename").." @ ".. opos .." - ".. cpos
       npos = editBookmark(currentSlot, "pos", opos)
       fname = editBookmark(currentSlot, "name", ename)
            

       return npos, fname

     --end  
     elseif ( cpos < opos ) then
       --os.execute("echo '" .. opos .. "' > ~/saa.txt ")
       local ename = mp.get_property("filename").." @ ".. cpos .." - ".. lpos
       npos = editBookmark(currentSlot, "pos", cpos)
       fname = editBookmark(currentSlot, "name", ename)
              

       return npos, fname
     end   
    
  

   else
   return nil
   end
end

-- Add the current position as a bookmark to the global table and then saves it
-- Returns the slot of the newly added bookmark
-- Returns -1 if there's an error
function addBookmark(name)
  local bookmark = makeBookmark(name)
  if bookmark == nil then
    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the media file to create the bookmark for")
    return -1
  end
  table.insert(bookmarks, bookmark)

  if #bookmarks == 1 then currentSlot = 1 end

  calcPages()
  saveBookmarks()
  displayBookmarks()
  return #bookmarks
end

-- Edit a property of a bookmark at the specified slot
-- Returns -1 if there's an error
function editBookmark(slot, property, value)
  if bookmarkExists(slot) then
    if property == "name" then value = parseName(value) end
    bookmarks[slot][property] = value
    saveBookmarks()
  else
    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the bookmark at slot "..slot)
    return -1
  end
end

-- Replaces the bookmark at the specified slot with a provided bookmark
-- Keeps the name and its position in the list
-- If the slot is not specified, picks the currently selected bookmark to replace
-- If a bookmark is not provided, generates a new bookmark
function replaceBookmark(slot)
  if slot == nil then slot = currentSlot end
  if bookmarkExists(slot) then
    local bookmark = makeBookmark(bookmarks[slot]["name"])
    if bookmark == nil then
      abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the media file to create the bookmark for")
      return -1
    end
    bookmarks[slot] = bookmark
    saveBookmarks()
    if closeAfterReplace then
      abort(styleOn.."{\\c&H00FF00&}{\\b1}Successfully replaced bookmark:{\\r}\n"..displayName(bookmark["name"]))
      return -1
    end
    return 1
  else
    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the bookmark at slot "..slot)
    return -1
  end
end

-- Quickly saves a bookmark without bringing up the menu
function quickSave()
  if not active then
    loadBookmarks()
    local slot = addBookmark()
    if slot > 0 then mp.osd_message("Saved new bookmark at slot " .. slot) end
  end
end

-- Quickly loads the last bookmark without bringing up the menu
function quickDel()
  if not active then
    loadBookmarks()
    local slot = #bookmarks
    if slot > 0 then mp.osd_message("Delete slot " .. slot) end
    table.remove(bookmarks, slot)
    if currentSlot > #bookmarks then currentSlot = #bookmarks end
    calcPages()
    saveBookmarks()
  end
end
-- Quickly loads the last bookmark without bringing up the menu
function quickLoad()
  if not active then
    loadBookmarks()
    local slot = #bookmarks
    if slot > 0 then mp.osd_message("Loaded bookmark at slot " .. slot) end
    jumpToBookmark(slot)
  end
end
-- Deletes the bookmark in the specified slot from the global table and then saves it
function deleteBookmark(slot)
  table.remove(bookmarks, slot)
  if currentSlot > #bookmarks then currentSlot = #bookmarks end
  calcPages()
  saveBookmarks()
  displayBookmarks()
end

-- Jump to the specified bookmark
-- This means loading it, reading it, and jumping to the file + position in the bookmark
function jumpToBookmark(slot)
  if bookmarkExists(slot) then
    local bookmark = bookmarks[slot]

    if fileExists(bookmark["path"]) then
    
      if parsePath(mp.get_property("path")) == bookmark["path"] then
        mp.set_property_number("time-pos", bookmark["pos"])
        mp.set_property("end", "100%")
      else
       mp.commandv("loadfile", parsePath(bookmark["path"]), "replace", "start=" .. bookmark["pos"] .. ",end=100%")
     end
      if closeAfterLoad then abort(styleOn.."{\\c&H00FF00&}{\\b1}Successfully found file for bookmark:{\\r}\n"..displayName(bookmark["name"])) end
    else
      abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find file for bookmark:\n" .. displayName(bookmark["name"]))
    end
  else
    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the bookmark at slot " .. slot)
  end
end


function jumpTostartend(slot)
  if bookmarkExists(slot) then
    local bookmark = bookmarks[slot]
    local oname = bookmarks[currentSlot]["name"]
    local lpos = string.match(oname, "(%d[%d.]*)$")
    local a, z = string.match(oname, "%@ (%d[%d.]*) %- (%d[%d.]*)$")
    
    if fileExists(bookmark["path"]) then
    if z ~= nil then
        mp.commandv("loadfile", parsePath(bookmark["path"]), "replace", "start=" .. bookmark["pos"] .. ",end=" .. z + 0.001 .. "")
      
      if closeAfterLoad then abort(styleOn.."{\\c&H00FF00&}{\\b1}Successfully found file for bookmark:{\\r}\n"..displayName(bookmark["name"])) end
      else
    --abort(styleOn.."{\\c&H0000FF&}{\\b1}no time specified as end point for:\n" .. displayName(bookmark["name"]))
    return -1
    end
    else
      abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find file for bookmark:\n" .. displayName(bookmark["name"]))
    end

  else
    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the bookmark at slot " .. slot)
  end
end
function cycleseek(slot)
    if bookmarkExists(slot) then
    local bookmark = bookmarks[slot]
--    local oname = bookmarks[currentSlot]["name"]
  --  local a, z = string.match(oname, "%@ (%d[%d.]*) %- (%d[%d.]*)$")
    if fileExists(bookmark["path"]) then
    
      if parsePath(mp.get_property("path")) == bookmark["path"] then
      
        mp.set_property_number("time-pos", bookmark["pos"])
       -- if mp.get_property_number("time-pos") == bookmark["pos"] then
       -- mp.set_property_number("time-pos", bookmark["duration"])
        --mp.set_property("end", "100%")
        --else 
        --
        --end
      else
       mp.commandv("loadfile", parsePath(bookmark["path"]), "replace", "start=" .. bookmark["pos"] .. "")
     
     end
      if closeAfterLoad then abort(styleOn.."{\\c&H00FF00&}{\\b1}Successfully found file for bookmark:{\\r}\n"..displayName(bookmark["name"])) end
      else
      abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find file for bookmark:\n" .. displayName(bookmark["name"]))
      end
    else
    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the bookmark at slot " .. slot)
    end
end
--function cycleseek(slot)
--  if bookmarkExists(slot) then
--  cpos = mp.get_property_number("time-pos")
--    local bookmark = bookmarks[slot]
--    local oname = bookmarks[currentSlot]["name"]
--    local lpos = string.match(oname, "(%d[%d.]*)$")
--    local a, z = string.match(oname, "%@ (%d[%d.]*) %- (%d[%d.]*)$")
--    
--    if fileExists(bookmark["path"]) then
--    if z ~= nil then
--        mp.commandv("loadfile", parsePath(bookmark["path"]), "replace", "start=" .. a .. "")
--     
--    if cpos == a then
--mp.commandv("loadfile", parsePath(bookmark["path"]), "replace", "start=" .. z .. "")
--end
--      if closeAfterLoad then abort(styleOn.."{\\c&H00FF00&}{\\b1}Successfully found file for bookmark:{\\r}\n"..displayName(bookmark["name"])) end
--      else
--    --abort(styleOn.."{\\c&H0000FF&}{\\b1}no time specified as end point for:\n" .. displayName(bookmark["name"]))
--    return -1
--    end
--    else
--      abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find file for bookmark:\n" .. displayName(bookmark["name"]))
--    end
--
--  else
--    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the bookmark at slot " .. slot)
--  end
--end
function jumpToLOOP(slot)
  if bookmarkExists(slot) then
    local bookmark = bookmarks[slot]
    local oname = bookmarks[currentSlot]["name"]
    local lpos = string.match(oname, "(%d[%d.]*)$")
    local a, z = string.match(oname, "%@ (%d[%d.]*) %- (%d[%d.]*)$")

    if z ~= nil then
   
    if fileExists(bookmark["path"]) then
        mp.commandv("loadfile", parsePath(bookmark["path"]), "replace", "start=" .. bookmark["pos"] .. ",end=" .. z + 0.001 .. ",loop=yes" )
      
      if closeAfterLoad then abort(styleOn.."{\\c&H00FF00&}{\\b1}Successfully found file for bookmark:{\\r}\n"..displayName(bookmark["name"])) end
    else
      abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find file for bookmark:\n" .. displayName(bookmark["name"]))
    end
     
    else
    abort(styleOn.."{\\c&H0000FF&}{\\b1}no time specified for:\n"..displayName(bookmark["name"]))
    return -1
    end
  else
    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the bookmark at slot " .. slot)
  end
end
-- Displays the current page of bookmarks
function displayBookmarks()
  -- Determine which slot is the first and last on the current page
  local startSlot = getFirstSlotOnPage(currentPage)
  local endSlot = getLastSlotOnPage(currentPage)

  -- Prepare the text to display and display it
  local display = styleOn .. "{\\an4}{\\b1}Bookmarks page " .. currentPage .. "/" .. maxPage .. ":{\\b0}"
  
  for i = startSlot, endSlot do
    local btext = displayName(bookmarks[i]["name"])
    local selection = ""
    if i == currentSlot then
      selection = "{\\b1}{\\c&H00FFFF&}>"
      if mode == "move" then btext = "----------------" end
      btext = btext
    end
    display = display .. "\n" .. selection .. i-1 .. ": " .. btext .. "{\\r}"
  end
  if currentPage == maxPage then 
    off = bookmarksPerPage - getAmountBookmarksOnPage(maxPage)   
    for i = off,1,-1 
           do 
              display = display .. "\n "
      end
  end
  mp.osd_message(display, rate)
end

local timer = mp.add_periodic_timer(rate * 0.95, displayBookmarks)
timer:kill()

 
 function seek (pos)
 mp.command("seek " .. pos .." exact")
 end
 
 function seekf (pos)
  if pos > 1 then
    mp.command("frame-step")
  else
    mp.command("frame-back-step")
  end
 end

 function seekfwf5 ()
  mp.command("seek 5 exact")
  end
  
  function seekbw5 ()
  mp.command("seek -5 exact")
  end
-- Commits the message entered with the Typer with custom scripts preceding it
-- Should typically end with typerExit()
function typerCommit()
  local status = 0
  if mode == "save" then
    status = addBookmark(typerText)
  elseif mode == "replace" and typerText == "y" then
    status = replaceBookmark(currentSlot, makeBookmark(bookmarks[currentSlot]["name"]))
  elseif mode == "delete" and typerText == "y" then
    deleteBookmark(currentSlot)
  elseif mode == "rename" then
    editBookmark(currentSlot, "name", typerText)
  elseif mode == "filepath" then
    editBookmark(currentSlot, "path", typerText)
  end
  if status >= 0 then typerExit() end
end

-- Exits the Typer without committing with custom scripts preceding it
function typerExit()
  deactivateTyper()
  displayBookmarks()
  timer:resume()
  mode = "none"
  activateControls("bookmarker", bookmarkerControls, bookmarkerFlags)
end

-- Starts the Typer with custom scripts preceding it
function typerStart()
  if (mode == "save" or mode=="replace") and mp.get_property("path") == nil then
    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the media file to create the bookmark for")
    return -1
  end
  if (mode == "replace" or mode == "rename" or mode == "filepath" or mode == "delete") and not bookmarkExists(currentSlot) then
    abort(styleOn.."{\\c&H0000FF&}{\\b1}Can't find the bookmark at slot "..currentSlot)
    return -1
  end
  if (mode == "replace" and not confirmReplace) or (mode == "delete" and not confirmDelete) then
    typerText = "y"
    typerCommit()
    return
  end

  deactivateControls("bookmarker", bookmarkerControls)
  timer:kill()
  activateTyper()
  if mode == "rename" then typerText = bookmarks[currentSlot]["name"] end
  if mode == "filepath" then typerText = bookmarks[currentSlot]["path"] end
  typerPos = typerText:len()
  typer("")
end

function export()
 
    local title = mp.get_property("filename")
    local inP = mp.get_property("path")
    local outPath = inP:match("(.+)%..+")
    local outF = title:match("(.+)%..+")

os.execute("awk '{ gsub(\",{\",\"\\n{\"); {print substr($0, 2, length($0) - 2)} }' '" .. getFilepath(bookmarkerName) .. "' | grep '" .. title .. "' | grep -Eo '\"pos\":[+-]?[0-9]+([.][0-9]+)?' | sort -t : -k 2n | sed 's/\"pos\"://' >  '" .. outPath .. "'_marx.txt")

end
function mosh()
    local title = mp.get_property("filename")
    local outF = title:match("(.+)%..+")
    local inP = mp.get_property("path")
    local outPath = inP:match("(.+)%..+") .. "_mosh" .. inP:match("^.+(%..+)$") 
    local pdir = inP:match("(.*[/\\])") .. "." .. outF
    local seg = title:match("(.+)%..+") .. "%3d" .. title:match("^.+(%..+)$")
    --local frames = mp.get_property_number("estimated-frame-count") - 90
   -- local ip = os.execute("awk '{ gsub(\",{\",\"\\n{\"); {print substr($0, 2, length($0) - 2)} }' /Users/MCYazen963/.config/mpv/bookmarker.json | grep '" .. title .. "' | grep -o '\"pos\":[[:digit:]]*.[[:digit:]]*' ")

local ip = io.popen("awk '{ gsub(\",{\",\"\\n{\"); {print substr($0, 2, length($0) - 2)} }' '" .. getFilepath(bookmarkerName) .. "' | grep '" .. title .. "' | grep -Eo '\"pos\":[+-]?[0-9]+([.][0-9]+)?' | sort -t : -k 2n | sed 's/\"pos\"://' | awk 'NF > 0' | awk '{print}' ORS=',' | sed '$s/,$//' | tr -d ' ' #| awk 'NF > 0'")
local output = ip:read('*all'):match("%d[%d.,]*")
ip:close()


local frame = io.popen("ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of default=nokey=1:noprint_wrappers=1 '" .. inP .. "'")
local fc = frame:read('*all') - 1
local frames = {frame:close()}

--os.execute("echo '" .. output .. "' > ~/saa.txt ")
os.execute("[[ -d '" .. pdir .. "' ]] || mkdir '" .. pdir .. "' && ffmpeg -nostats -hide_banner -i '" .. inP .. "' -force_key_frames '" .. output .. "' -g " .. fc .. " -x264opts \"no-scenecut\" -an -pix_fmt yuv420p -crf 2 -f segment -reset_timestamps 1 -map 0 '" .. pdir .. "/" .. seg .. "'")
os.execute("/Users/MCYazen963/aviglitch-utils-master/bin/concat.rb '" .. pdir .. "'/* -o '" .. outPath .. "' && rm -rf '" .. pdir .. "' ")
--os.execute("[[ -d '" .. pdir .. "' ]] || mkdir '" .. pdir .. "' && ffmpeg -nostats -hide_banner -i '" .. inP .. "' -force_key_frames '" .. output .. "' -g " .. fc .. " -x264opts \"no-scenecut\" -an -pix_fmt yuv420p -crf 0 '" .. pdir .. "/" .. seg .. "' && /Users/MCYazen963/aviglitch-utils-master/bin/datamosh.rb '" .. pdir .. "/" .. seg .. "' -o '" .. outPath .. "' ")


end


-- Aborts the program with an optional error message
function abort(message)
  mode = "none"
  moverExit(true)
  deactivateTyper()
  deactivateControls("bookmarker", bookmarkerControls)
  timer:kill()
  mp.osd_message(message)
  active = false
end

-- Handles the state of the bookmarker
function handler()
  if active then
    abort("")
  else
    activateControls("bookmarker", bookmarkerControls, bookmarkerFlags)
    loadBookmarks()
    displayBookmarks()
    timer:resume()
    active = true
  end
end


mp.register_script_message("bookmarker-menu", handler)
mp.register_script_message("bookmarker-save", quickSave)
mp.register_script_message("bookmarker-load", quickLoad)
mp.register_script_message("bookmarker-del", quickDel)
mp.register_script_message('close-bm', function() abort('') end)
