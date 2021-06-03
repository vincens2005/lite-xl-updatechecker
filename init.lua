-- mod-version:1 lite-xl 1.16
local core = require "core"
local command = require "core.command"
local style = require "core.style"
local json = require "plugins.updatechecker.json" -- rxi/json.lua
local config = require "core.config"

config.updatechecker_timeout = 3 -- increase this value if you get json.lua errors

-- stolen from git status
local function exec(cmd, wait)
	local tempfile = core.temp_filename()
	system.exec(string.format("%s > %q", cmd, tempfile))
	coroutine.yield(wait)
	local fp = io.open(tempfile)
	local res = fp:read("*a")
	fp:close()
	os.remove(tempfile)
	return res
end

local function fetch(url)
	local cmd = "curl "
	cmd = cmd .. url
	local result = exec(cmd, config.updatechecker_timeout)
	return result
end

local function get_os()
	if PATHSEP == "\\" then
		return "windows"
	end
	if exec("uname -s", 1):find("Linux") then
		return "linux"
	end

	return "macos"
end

local function arr_find(arr, func)
	for i, value in ipairs(arr) do
		if func(value) then
			return value
		end
	end
	return nil
end

local function check_updates()
	core.log_quiet("checking for updates...")

	core.add_thread(function()
		local raw_data = fetch("https://api.github.com/repos/franko/lite-xl/releases")
		local data = json.decode(raw_data)

		core.log_quiet(data[1].tag_name)

		local current_version = "v" .. VERSION

		if current_version == data[1].tag_name or data[1].draft or data[1].prerelease then
			core.log_quiet("lite-xl is up to date")
			return
		end

		local opt = {
			{font = style.font, text = "ignore", default_no = true},
			{font = style.font, text = "download", default_yes = true}
		}

		core.nag_view:show("new update available",
		                   "lite xl " .. data[1].tag_name .. " is ready to download", opt, function(item)

			if item.text == "download" then
				core.add_thread(function()
					local os_name = get_os()

					-- if on windows, just open release page, since multiple windows binaries exist
					if os_name == "windows" then
						system.exec("start " .. data[1].html_url)
						core.log("opening in browser...")
						return
					end

					if os_name == "linux" then
						local download_item = arr_find(data[1].assets, function(asset)
							return asset.browser_download_url:find("linux")
						end)
						core.log("opening in browser...")
						system.exec("xdg-open " .. download_item.browser_download_url)
						return
					end

					if os_name == "macos" then
						local download_item = arr_find(data[1].assets, function(asset)
							return asset.browser_download_url:find("macos")
						end)
						system.exec("open " .. download_item.browser_download_url)
						core.log("opening in browser...")
						return
					end
				end)
			end
		end)
	end)
end

command.add(nil, {["update-checker:check-for-updates"] = check_updates})

check_updates()