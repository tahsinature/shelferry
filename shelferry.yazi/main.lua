--- @since 25.5.31
-- Shelferry: native shelves from Yazi. Uses the CLI exclusively, never deep links.
local binary = os.getenv("SHELFERRY_BIN") or "shelferry"
local function notify(text, level)
  ya.notify({ title = "Shelferry", content = text, timeout = 4, level = level or "info" })
end
local selected_paths = ya.sync(function()
  local paths = {}
  for _, url in pairs(cx.active.selected) do paths[#paths + 1] = tostring(url) end
  if #paths == 0 and cx.active.current.hovered then paths[1] = tostring(cx.active.current.hovered.url) end
  return paths
end)
local function request(args)
  local output, err = Command(binary):arg(args):arg("--json"):output()
  if not output then notify("Could not run " .. binary .. ": " .. tostring(err), "error"); return end
  local response = ya.json_decode(output.stdout)
  if not output.status.success or not response or response.error then
    notify(response and response.error or output.stderr or "Invalid CLI response", "error"); return
  end
  return response
end
local function clean(text) return text:gsub("[\r\n\t]", " ") end
local function fzf(lines, args)
  local child = Command("fzf"):arg(args):stdin(Command.PIPED):stdout(Command.PIPED):spawn()
  if not child then return nil end
  for _, line in ipairs(lines) do child:write_all(line .. "\n") end
  child:flush()
  local output = child:wait_with_output()
  return output and output.stdout or ""
end
local function choose_shelf(shelves, allow_new)
  if #shelves == 0 then return allow_new and "new" or nil end
  local lines = {}
  for i, shelf in ipairs(shelves) do
    lines[#lines + 1] = string.format("%d\t%s (%d items)", i, clean(shelf.name), shelf.count)
  end
  if allow_new then lines[#lines + 1] = "new\tNew shelf" end
  local permit = ui.hide()
  local result = fzf(lines, { "--delimiter", "\t", "--with-nth", "2..", "--prompt", "Shelf> " })
  permit:drop()
  if result == nil then
    local page = 0
    while true do
      local cands = {}
      for i = page * 8 + 1, math.min(#shelves, page * 8 + 8) do
        cands[#cands + 1] = { on = tostring(i - page * 8), desc = shelves[i].name }
      end
      local count = #cands
      if allow_new then cands[#cands + 1] = { on = "n", desc = "New shelf" } end
      cands[#cands + 1] = { on = "]", desc = "Next page" }
      local choice = ya.which({ cands = cands })
      if not choice then return nil end
      if choice <= count then return shelves[page * 8 + choice].id end
      if allow_new and choice == count + 1 then return "new" end
      page = (page + 1) % math.ceil(#shelves / 8)
    end
  end
  local id = result:match("^([^\t]+)")
  if id == "new" then return "new" end
  return shelves[tonumber(id)] and shelves[tonumber(id)].id or nil
end
local function add()
  local paths = selected_paths()
  if #paths == 0 then return notify("Nothing selected", "warn") end
  local response = request({ "list" }); if not response then return end
  local shelf = choose_shelf(response.shelves, true); if not shelf then return end
  local mode = ya.which({ cands = {
    { on = "c", desc = "Add copies (originals stay put)" },
    { on = "o", desc = "Link to originals" },
  } })
  if not mode then return end
  -- --json must precede --; paths after -- are always literal.
  local args = { "add", "--json", "--shelf", shelf, mode == 1 and "--copy" or "--original", "--" }
  for _, path in ipairs(paths) do args[#args + 1] = path end
  local output, err = Command(binary):arg(args):output()
  local result = output and ya.json_decode(output.stdout)
  if not output or not output.status.success or not result or result.error then
    return notify(result and result.error or (output and output.stderr) or tostring(err), "error")
  end
  notify(string.format("Added %d item(s) to Shelferry", #paths))
end
local function get()
  local response = request({ "list" }); if not response then return end
  if #response.shelves == 0 then return notify("No shelves yet", "warn") end
  local shelf = choose_shelf(response.shelves, false); if not shelf then return end
  response = request({ "items", "--shelf", shelf }); if not response then return end
  if #response.items == 0 then return notify("Shelf is empty", "warn") end
  local lines = {}
  for i, item in ipairs(response.items) do lines[i] = i .. "\t" .. clean(item.path) end
  local permit = ui.hide()
  local result = fzf(lines, { "-m", "--delimiter", "\t", "--with-nth", "2..", "--prompt", "Shelf items> ", "--bind", "ctrl-a:select-all" })
  permit:drop()
  local chosen = {}
  if result == nil then
    local choice = ya.which({ cands = { { on = "a", desc = "fzf unavailable: select all items" } } })
    if not choice then return end
    chosen = response.items
  else
    for index in result:gmatch("(%d+)\t[^\n]*") do chosen[#chosen + 1] = response.items[tonumber(index)] end
  end
  if #chosen == 0 then return end
  local mode = ya.which({ cands = { { on = "c", desc = "Copy" }, { on = "x", desc = "Cut (move on paste)" } } })
  if not mode then return end
  ya.emit("escape", { select = true })
  for _, item in ipairs(chosen) do ya.emit("toggle", { Url(item.path), state = "on" }) end
  ya.emit("yank", { cut = mode == 2 })
  notify("Ready. Press p in the destination folder.")
end
return { entry = function(_, job)
  local action = job.args[1] or "add"
  if action == "get" then get()
  elseif action == "add" then add()
  elseif action == "toggle" or action == "manager" then request({ action })
  else notify("Use add, get, toggle, or manager", "error") end
end }
