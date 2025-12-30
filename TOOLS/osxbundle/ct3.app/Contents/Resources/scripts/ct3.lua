mp.register_event("file-loaded", function()

  local mp = require("mp")
  local msg = require "mp.msg"
  local utils = require "mp.utils"
  local options = require "mp.options"
  

  local cut_pos = nil
  local target_dir = mp.command_native({"expand-path", "~/ct3/"})

  -- Function to check if a directory exists
  function isdir(path)
      local f = io.open(path, "r")
      if f then
          local mode = f:read(1)
          f:close()
          return mode == "d"
      else
          return false
      end
  end
  
  -- Create directories if they don't exist
  function recdir()
      -- Check if the target directory exists
      if not isdir(target_dir) then
          -- If not, create the target directory and subdirectories
          os.execute("mkdir -p " .. target_dir .. "/aud " .. target_dir .. "/vid " .. target_dir .. "/img")
      end
  end
  
  -- Call the function to ensure the directories exist
  recdir()
  
  function osd(str)
      return mp.osd_message(str, 3)
  end
  
  function get_homedir()
    -- It would be better to do platform detection instead of fallback but
    -- it's not that easy in Lua.
    return os.getenv("HOME") or os.getenv("USERPROFILE") or ""
  end
  
  function log(str)
      local logpath = utils.join_path(
          target_dir:gsub("~", get_homedir()),
          "ct3.log")
      f = io.open(logpath, "a")
      f:write(string.format("# %s\n%s\n",
          os.date("%Y-%m-%d %H:%M:%S"),
          str))
      f:close()
  end
  
  function escape(str)
      -- FIXME(Kagami): This escaping is NOT enough, see e.g.
      -- https://stackoverflow.com/a/31413730
      -- Consider using `utils.subprocess` instead.
      return str:gsub("\\", "\\\\"):gsub('"', '\\"')
  end
  
  function trim(str)
      return str:gsub("^%s+", ""):gsub("%s+$", "")
  end
  function get_outname(shift, endpos)
      local name = mp.get_property("filename")
      local ext = name:match("^.+(%..+)$")
      if (ext == 'flac' or ext == 'wav' or ext == 'wv' or ext == 'aiff' or ext == 'mp3' or ext == 'm4a' or ext == 'aac') then 
           dir = 'aud/'
      else
           dir = 'vid/'
      end
      local dotidx = name:reverse():find(".", 1, true)
      if dotidx then name = name:sub(1, -dotidx-1) end
      name = name:gsub(" ", "_")
      name = name:gsub(":", "-")
      name = dir .. name .. string.format("-%s-%s", shift, endpos) .. ext
      return name
  end
  --print("params", mp.get_property("stream-path"))
  -- Optimized standalone encode function (Lua 5.1)
  local function encode(input_path, output_path, start_time, end_time, extra_flags)
    assert(type(input_path) == "string", "input_path required")
    assert(type(output_path) == "string", "output_path required")
  
    start_time  = tonumber(start_time) or 0
    end_time    = tonumber(end_time) or 0
    extra_flags = extra_flags or {}
  
    -- Get video resolution
    local vw = mp.get_property_number("width")
    local vh = mp.get_property_number("height")
    if not vw or not vh then
      error("Failed to retrieve video resolution from mpv.")
    end
  
    ------------------------------------------------------------------
    -- Helpers
    ------------------------------------------------------------------
    local function time_to_string(sec)
      local h = math.floor(sec / 3600)
      local m = math.floor((sec % 3600) / 60)
      local s = sec % 60
      return string.format("%02d:%02d:%06.3f", h, m, s)
    end
  
    local function quote(path)
      return path:find(" ") and ('"' .. path .. '"') or path
    end
  
    ------------------------------------------------------------------
    -- Collect active tracks
    ------------------------------------------------------------------
    local audio_tracks = mp.get_property_native("audio-list") or {}
    local video_tracks = mp.get_property_native("video-list") or {}
    local sub_tracks   = mp.get_property_native("sub-list") or {}
  
    local is_muted     = mp.get_property_bool("mute")
    local sub_visible  = mp.get_property_bool("sub-visibility")
  
    ------------------------------------------------------------------
    -- Build command
    ------------------------------------------------------------------
    local cmd = {
      mp.get_property("executable-path"),
      quote(input_path),
      "--no-config",
      "--loop-file=no",
      "--no-pause"
    }
    if start_time > 0 then
      cmd[#cmd + 1] = "--start=" .. time_to_string(start_time)
    end
  
    if end_time > start_time then
      cmd[#cmd + 1] = "--end=" .. time_to_string(end_time)
    end
  
    ------------------------------------------------------------------
    -- Audio handling
    ------------------------------------------------------------------
    if is_muted then
      cmd[#cmd + 1] = "--aid=no"
    else
      for _, t in ipairs(audio_tracks) do
        if t.current and t.id then
          cmd[#cmd + 1] = "--aid=" .. t.id
          break -- only one active audio track
        end
      end
    end
  
    ------------------------------------------------------------------
    -- Video track (first valid)
    ------------------------------------------------------------------
    for _, t in ipairs(video_tracks) do
      if t.id then
        cmd[#cmd + 1] = "--vtrack=" .. t.id
        break
      end
    end
  
    ------------------------------------------------------------------
    -- Subtitle handling
    ------------------------------------------------------------------
    if sub_visible then
      for _, t in ipairs(sub_tracks) do
        if t.id then
          cmd[#cmd + 1] = "--sid=" .. t.id
          break
        end
      end
    end
    ------------------------------------------------------------------
    -- video filter
    ------------------------------------------------------------------
    local function build_vf_string()
      local vf = mp.get_property_native("vf")
      if not vf or #vf == 0 then
        return nil
      end
    
      local filters = {}
    
      for _, f in ipairs(vf) do
        if f.name then
          if f.params then
            local params = {}
            for k, v in pairs(f.params) do
              params[#params + 1] = string.format("%s=%s", k, tostring(v))
            end
            filters[#filters + 1] =
              string.format("%s=%s", f.name, table.concat(params, ":"))
          else
            filters[#filters + 1] = f.name
          end
        end
      end
    
      return table.concat(filters, ",")
    end  
    local vf_string = build_vf_string()
    if vf_string then
      cmd[#cmd + 1] = "--vf=" .. vf_string
    end
    ------------------------------------------------------------------
    -- Encoding settings
    ------------------------------------------------------------------
    cmd[#cmd + 1] = "--ovc=libx264"
    cmd[#cmd + 1] = "--oac=aac"
  
    for i = 1, #extra_flags do
      cmd[#cmd + 1] = extra_flags[i]
    end
  
    cmd[#cmd + 1] = "--o=" .. quote(output_path)
  
    ------------------------------------------------------------------
    -- Execute
    ------------------------------------------------------------------
    local cmd_str = table.concat(cmd, " ")
    print("Executing:", cmd_str)
    log(cmd_str)
    return os.execute(cmd_str)
  end
  
  --
  local function loop()
      local pos = math.floor(mp.get_property_number("time-pos")* 10000) / 10000 
      if not mp.get_property_number("ab-loop-a") then
          mp.command("cycle-values loop-file inf no")
          osd("MISSING A")
      elseif mp.get_property_number("ab-loop-a") == pos or mp.get_property_number("ab-loop-b") == pos or type(mp.get_property_number("ab-loop-b")) == number then
          mp.set_property("ab-loop-a", "no");
          mp.set_property("ab-loop-b", "no");
          cut_pos = nil
          osd("LOOP BREAK")
      else
          cut_pos = nil
          mp.set_property_number("ab-loop-b", pos);
          mp.set_property("seek", mp.get_property_number("ab-loop-a").." exact")
          osd(string.format("LOOP A-B: %s - %s",mp.get_property_number("ab-loop-a"),mp.get_property_number("ab-loop-b")))
      end
  end
    function revert()
          mp.commandv('revert-seek')
    end
    function timestamp(duration)
      local hours = duration / 3600
      local minutes = duration % 3600 / 60
      local seconds = duration % 60
      return string.format("%02d:%02d:%02.03f", hours, minutes, seconds)
    end
    function mrk()
      local pos = math.floor(mp.get_property_number("time-pos")* 10000) / 10000 --limit to 4 after decimel
          if cut_pos then
              local shift, endpos = math.floor(cut_pos* 10000) / 10000, math.floor(pos* 10000) / 10000 
              if shift > endpos then
                  shift, endpos = endpos, shift
              end
              if shift == endpos then
                  cut_pos = nil
                  mp.set_property("ab-loop-a", "no");
                  osd("Cut fragment is empty")
              else
                  cut_pos = nil
                  osd(string.format("Cut A-B: %s - %s", timestamp(shift), timestamp(endpos)))
                  local inpath = escape(utils.join_path(utils.getcwd(), mp.get_property("stream-path")))
                  local outpath = escape(utils.join_path(target_dir:gsub("~", get_homedir()), get_outname(shift, endpos)))
                  encode(inpath, outpath, shift, endpos)
                  --print("params",Region(),shift,endpos)
                  --cut(shift, endpos)
                  mp.set_property("ab-loop-a", "no");
                  mp.set_property("ab-loop-b", "no");
              end
          else
              cut_pos = pos
              mp.set_property_number("ab-loop-a", pos);
              mp.set_property('revert-seek', 'mark-permanent')
              osd(string.format("SET A %s", timestamp(pos)))
          end
    end
    function clr()
      cut_pos = nil
      --last = nil
      mp.set_property("ab-loop-a", "no");
      mp.set_property("ab-loop-b", "no");
      osd("Cleared A-B")
    end
    mp.add_key_binding(nil, "mrk", mrk)
    mp.add_key_binding(nil, "clr", clr)
    mp.add_key_binding(nil, "loop", loop)
    mp.add_key_binding(nil, "rev", revert)
    --
  end)