local settings = {
    display_timeout = 525,
  
    loop_cursor = true,
  
    key_moveup = "i WHEEL_UP GAMEPAD_DPAD_UP UP",
    key_movedown = "k WHEEL_DOWN GAMEPAD_DPAD_DOWN DOWN",
    key_execute = "ENTER MBTN_MID GAMEPAD_START GAMEPAD_ACTION_DOWN",
    key_closemenu = "ESC MBTN_RIGHT GAMEPAD_MENU GAMEPAD_BACK",
  }
  
  local utils = require("mp.utils")
  local msg = require("mp.msg")
  local assdraw = require("mp.assdraw")
  local opts = require("mp.options")
  opts.read_options(settings, "simplemenu")
  
  --local file = assert(io.open(mp.command_native({"expand-path", "~~/script-opts"}) .. "/menu.json"))
  --local json = file:read("*all")
  --file:close()
  function tabeltostring (tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
      formatting = string.rep("  ", indent) .. k .. ": "
      if type(v) == "table" then
        return v
      elseif type(v) == 'boolean' then
        return tostring(v)     
      else
        return v
      end
    end
  end
  
  local json = [[
    [
      {
        "label": "STATS",
        "command": ["script-binding stats/page++"],
      },
      {
        "label": "BROWSE",
        "command": ["script-binding playlist/closeplaylist ; script-binding crop/close-crop ; script-binding stats/close ; script_message close-bm ; script-binding browse-files"],
      },
      {
        "label": "PLAYLIST",
        "command": ["script-binding crop/close-crop ; script-binding stats/close ; script_message close-bm ; script-binding close-bf ; script-binding playlist/showplaylist"],
      },
      {
        "label": "BOOKMARK",
        "command": ["script-binding playlist/closeplaylist ; script-binding crop/close-crop ; script_message bookmarker-menu ; script-binding close-bf ; script-binding stats/close"],
      },
      {
        "label": "CROP",
        "command": ["script-binding playlist/closeplaylist ; script_message close-bm ; script-binding close-bf ; script-binding stats/close ; script-binding crop/toggle-crop"],
      },
      {
        "label": "VISUALISER",
        "command": ["script-binding visualizer/cycle-visualizer"],
        "keep_open": true
      },
      {
        "label": "QUIT",
        "command": ["quit"]
      },
    ]
    ]]
  local menu_items = utils.parse_json(json)

  if menu_items == nil then
    error("Invalid JSON format in menu.json. Please run it through a linter. The script is disabled.")
  end
  
  for _, item in pairs(menu_items) do
    local command_type = type(item.command)
    assert(
      command_type == "table",
      "Unexpected command type for \""..item.label.."\". Expected table, received "..command_type
    )
    -- TODO: assert nested commands
  end
  
  if #menu_items == 0 then
    msg.warn("Menu list is empty. The script is disabled.")
  end
  
  local menu_size = #menu_items
  local menu_visible = false
  local cursor = 1
  
  function execute()
    local command = menu_items[cursor].command
    local is_nested_command = type(command[1]) == "table"
  
    if is_nested_command then
      for _, cmd in ipairs(command) do
        mp.command_native(cmd)
      end
    else
      mp.command(tabeltostring(command))
    end
  
    if menu_items[cursor].keep_open then
      render()
    else
      remove_keybinds()
    end
  end
  
  function toggle_menu()
    if menu_visible then
      remove_keybinds()
      return
    end
    mp.command("script-binding crop/close-crop")
    mp.command("script-binding stats/close")
    mp.command("script_message close-bm")
    mp.command("script-binding close-bf")
    mp.command("script-binding playlist/closeplaylist")
    render()
  end
  
  function render()
    local font_size = mp.get_property("osd-font-size")
    local LTR = string.char(0xE2, 0x80, 0x8E)
    local ass = assdraw.ass_new()
    ass:new_event()
    --ass:format("{\\an3}%s", LTR)
    ass:append("{\\an2}{\\c&ffffff&}")
    --ass:pos(30, 100)
    --([[{\c&H%s&}]]):format(o.font_colour_selected)
    for index, item in ipairs(menu_items) do
      local selected = index == cursor
      local prefix = selected and "{\\c&Hfce788&}" or "{\\c&Hffffff&}"
      ass:append(prefix .. item.label .. "\\N")
    end
  
    local w, h = mp.get_osd_size()
    mp.set_osd_ass(w, h, ass.text)
  
    menu_visible = true
    add_keybinds()
    keybindstimer:kill()
    keybindstimer:resume()
  end
  
  function moveup()
    if cursor ~= 1 then
      cursor = cursor - 1
    elseif settings.loop_cursor then
      cursor = menu_size
    end
    render()
  end
  
  function movedown()
    if cursor ~= menu_size then
      cursor = cursor + 1
    elseif settings.loop_cursor then
      cursor = 1
    end
    render()
  end
  
  function bind_keys(keys, name, func, opts)
    if not keys then
      mp.add_forced_key_binding(keys, name, func, opts)
      return
    end
    local i = 1
    for key in keys:gmatch("[^%s]+") do
      local prefix = i == 1 and '' or i
      mp.add_forced_key_binding(key, name..prefix, func, opts)
      i = i + 1
    end
  end
  
  function unbind_keys(keys, name)
    if not keys then
      mp.remove_key_binding(name)
      return
    end
    local i = 1
    for key in keys:gmatch("[^%s]+") do
      local prefix = i == 1 and '' or i
      mp.remove_key_binding(name..prefix)
      i = i + 1
    end
  end
  
  function add_keybinds()
    bind_keys(settings.key_moveup, 'simplemenu-moveup', moveup, "repeatable")
    bind_keys(settings.key_movedown, 'simplemenu-movedown', movedown, "repeatable")
    bind_keys(settings.key_execute, 'simplemenu-execute', execute)
    bind_keys(settings.key_closemenu, 'simplemenu-closemenu', remove_keybinds)
  end
  
  function remove_keybinds()
    keybindstimer:kill()
    menu_visible = false
    mp.set_osd_ass(0, 0, "")
    unbind_keys(settings.key_moveup, 'simplemenu-moveup')
    unbind_keys(settings.key_movedown, 'simplemenu-movedown')
    unbind_keys(settings.key_execute, 'simplemenu-execute')
    unbind_keys(settings.key_closemenu, 'simplemenu-closemenu')
  end
  
  keybindstimer = mp.add_periodic_timer(settings.display_timeout, remove_keybinds)
  keybindstimer:kill()
  
  if menu_items and menu_size > 0 then
    mp.register_script_message("simplemenu-toggle", toggle_menu)
    mp.add_key_binding("MBTN_MID", "simplemenu-toggle", toggle_menu)
  end