---@brief [[
---A fancy, configurable notification manager for NeoVim
---@brief ]]

---@tag nvim-notify

local config = require("notify.config")
local stages = require("notify.stages")
local Notification = require("notify.service.notification")
local WindowAnimator = require("notify.windows")
local NotificationService = require("notify.service")

local service
---@type Notification[]
local notifications = {}

local notify = {}

---Configure nvim-notify
---<pre>
---    See: ~
---        |notify.Config|
---</pre>
---@param user_config notify.Config
---@eval { ['description'] = require('notify.config')._format_default() }
---@see notify-render
function notify.setup(user_config)
  config.setup(user_config)

  local has_telescope = (vim.fn.exists("g:loaded_telescope") == 1)
  if has_telescope then
    require("telescope").load_extension("notify")
  end

  local animator_stages = config.stages()
  animator_stages = type(animator_stages) == "string" and stages[animator_stages] or animator_stages
  local animator = WindowAnimator(animator_stages)
  service = NotificationService({ fps = config.fps() }, animator)

  vim.cmd([[command! Notifications :lua require("notify")._print_history()<CR>]])
end

local function get_render(render)
  if type(render) == "function" then
    return render
  end
  return require("notify.render")[render]
end

---@class notify.Options @Options for an individual notification
---@field title string
---@field icon string
---@field timeout number | boolean: Time to show notification in milliseconds, set to false to disable timeout.
---@field on_open function: Callback for when window opens, receives window as argument.
---@field on_close function: Callback for when window closes, receives window as argument.
---@field keep function: Function to keep the notification window open after timeout, should return boolean.
---@field render function: Function to render a notification buffer.
---@field replace integer | notify.Record: Notification record or the record `id` field. Replace an existing notification if still open. All arguments not given are inherited from the replaced notification including message and level.
---@field hide_from_history boolean: Hide this notification from the history

---@class NotificationEvents @Async events for a notification
---@field open function: Resolves when notification is opened
---@field close function: Resolved when notification is closed

---@class notify.Record @Record of a previously sent notification
---@field id integer
---@field message string[]: Lines of the message
---@field level string: Log level
---@field title string[]: Left and right sections of the title
---@field icon string: Icon used for notification
---@field time number: Time of message, as returned by `vim.fn.localtime()`
---@field render function: Function to render notification buffer

---@class notify.AsyncRecord : notify.Record
---@field events NotificationEvents

---Display a notification.
---
---You can call the module directly rather than using this:
---<pre>
--->
---  require("notify")(message, level, opts)
---</pre>
---@param message string | string[]: Notification message
---@param level string | number
---@param opts notify.Options: Notification options
---@return notify.Record
function notify.notify(message, level, opts)
  if not service then
    notify.setup()
  end
  opts = opts or {}
  if opts.replace then
    if type(opts.replace) == "table" then
      opts.replace = opts.replace.id
    end
    local existing = notifications[opts.replace]
    if not existing then
      vim.notify("Invalid notification to replace", "error", { title = "nvim-notify" })
      return
    end
    local notif_keys = {
      "title",
      "icon",
      "timeout",
      "keep",
      "on_open",
      "on_close",
      "render",
      "hide_from_history",
    }
    message = message or existing.message
    level = level or existing.level
    for _, key in ipairs(notif_keys) do
      opts[key] = opts[key] or existing[key]
    end
  end
  opts.render = get_render(opts.render or config.render())
  local id = #notifications + 1
  local notification = Notification(id, message, level, opts)
  table.insert(notifications, notification)
  local level_num = vim.lsp.log_levels[notification.level]
  if opts.replace then
    service:replace(opts.replace, notification)
  elseif level_num >= config.level() then
    service:push(notification)
  end
  return {
    id = id,
  }
end

---Display a notification asynchronously
---
---This uses plenary's async library, allowing a cleaner interface for
---open/close events. You must call this function within an async context.
---
---The `on_close` and `on_open` options are not used.
---
---@param message string | string[]: Notification message
---@param level string | number
---@param opts notify.Options: Notification options
---@return notify.AsyncRecord
function notify.async(message, level, opts)
  opts = opts or {}
  local async = require("plenary.async")
  async.util.scheduler()
  local close_cond = async.control.Condvar.new()
  local close_args = {}
  opts.on_close = function(...)
    close_args = { ... }
    close_cond:notify_all()
  end

  local open_cond = async.control.Condvar.new()
  local open_args = {}
  opts.on_open = function(...)
    open_args = { ... }
    open_cond:notify_all()
  end

  local record = notify.notify(message, level, opts)
  return vim.tbl_extend("error", record, {
    events = {
      open = function()
        open_cond:wait()
        return unpack(open_args)
      end,
      close = function()
        close_cond:wait()
        return unpack(close_args)
      end,
    },
  })
end

---Get records of all previous notifications
---
--- You can use the `:Notifications` command to display a log of previous notifications
---@param args table
---@field include_hidden boolean: Include notifications hidden from history
---@return notify.Record[]
function notify.history(args)
  args = args or {}
  local records = {}
  for _, notif in ipairs(notifications) do
    if not notif.hide_from_history or args.include_hidden then
      records[#records + 1] = notif:record()
    end
  end
  return records
end

---Dismiss all notification windows currently displayed
---@param opts table
---@field pending boolean: Clear pending notifications
---@field silent boolean: Suppress notification that pending notifications were dismissed.
function notify.dismiss(opts)
  if service then
    service:dismiss(opts or {})
  end
end

function notify._print_history()
  for _, notif in ipairs(notify.history()) do
    vim.api.nvim_echo({
      { vim.fn.strftime("%FT%T", notif.time), "NotifyLogTime" },
      { " ", "MsgArea" },
      { notif.title[1], "NotifyLogTitle" },
      { #notif.title[1] > 0 and " " or "", "MsgArea" },
      { notif.icon, "Notify" .. notif.level .. "Title" },
      { #notif.title[1] > 0 and " " or "", "MsgArea" },
      { notif.level, "Notify" .. notif.level .. "Title" },
      { " ", "MsgArea" },
      { table.concat(notif.message, "\n"), "MsgArea" },
    }, false, {})
  end
end

setmetatable(notify, {
  __call = function(_, m, l, o)
    if vim.in_fast_event() then
      vim.schedule(function()
        notify.notify(m, l, o)
      end)
    else
      return notify.notify(m, l, o)
    end
  end,
})

return notify
