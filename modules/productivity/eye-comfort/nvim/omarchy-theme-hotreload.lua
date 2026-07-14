-- Eye-comfort / Omarchy theme hotreload for open Neovim sessions.
-- Replaces stock omarchy-nvim hotreload that forced vim.o.background = "dark"
-- on every LazyReload (leaving mixed light/dark UI after theme switches).
return {
	{
		name = "theme-hotreload",
		dir = vim.fn.stdpath("config"),
		lazy = false,
		priority = 1000,
		config = function()
			local transparency_file = vim.fn.stdpath("config") .. "/plugin/after/transparency.lua"
			local light_mode_file = vim.fn.expand("~/.config/omarchy/current/theme/light.mode")
			local theme_name_file = vim.fn.expand("~/.config/omarchy/current/theme.name")
			local reloading = false
			local last_token = nil

			local function theme_background()
				-- Omarchy marks light themes with an empty light.mode sentinel.
				if vim.fn.filereadable(light_mode_file) == 1 then
					return "light"
				end
				return "dark"
			end

			local function theme_token()
				local name = ""
				if vim.fn.filereadable(theme_name_file) == 1 then
					name = vim.fn.readfile(theme_name_file)[1] or ""
				end
				local mode = theme_background()
				local mtime = vim.fn.getftime(theme_name_file)
				return name .. ":" .. mode .. ":" .. tostring(mtime)
			end

			local function apply_gruvbox_opts(theme_spec)
				for _, spec in ipairs(theme_spec) do
					if spec[1] == "ellisonleao/gruvbox.nvim" and type(spec.opts) == "table" then
						local ok, gruvbox = pcall(require, "gruvbox")
						if ok and gruvbox.setup then
							gruvbox.setup(spec.opts)
						end
						return
					end
				end
			end

			local function refresh_statusline()
				local ok_lualine, lualine = pcall(require, "lualine")
				if ok_lualine and lualine.refresh then
					pcall(lualine.refresh)
				end
			end

			local function apply_theme()
				if reloading then
					return
				end
				reloading = true
				package.loaded["plugins.theme"] = nil

				vim.schedule(function()
					local ok, theme_spec = pcall(require, "plugins.theme")
					if not ok then
						reloading = false
						return
					end

					local theme_plugin_name = nil
					for _, spec in ipairs(theme_spec) do
						if spec[1] and spec[1] ~= "LazyVim/LazyVim" then
							theme_plugin_name = spec.name or spec[1]
							break
						end
					end

					vim.cmd("highlight clear")
					if vim.fn.exists("syntax_on") == 1 then
						vim.cmd("syntax reset")
					end

					vim.o.background = theme_background()

					if theme_plugin_name then
						local plugin = require("lazy.core.config").plugins[theme_plugin_name]
						if plugin and plugin.dir then
							local plugin_dir = plugin.dir .. "/lua"
							require("lazy.core.util").walkmods(plugin_dir, function(modname)
								package.loaded[modname] = nil
								package.preload[modname] = nil
							end)
						end
					end

					for _, spec in ipairs(theme_spec) do
						if spec[1] == "LazyVim/LazyVim" and spec.opts and spec.opts.colorscheme then
							local colorscheme = spec.opts.colorscheme
							require("lazy.core.loader").colorscheme(colorscheme)

							vim.defer_fn(function()
								apply_gruvbox_opts(theme_spec)
								vim.o.background = theme_background()
								pcall(vim.cmd.colorscheme, colorscheme)
								vim.cmd("redraw!")

								local function finish()
									vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
									refresh_statusline()
									vim.cmd("redraw!")
									last_token = theme_token()
									reloading = false
								end

								if vim.fn.filereadable(transparency_file) == 1 then
									vim.defer_fn(function()
										pcall(vim.cmd.source, transparency_file)
										finish()
									end, 5)
								else
									finish()
								end
							end, 5)
							return
						end
					end

					reloading = false
				end)
			end

			-- Ensure listen socket so omarchy theme-set hook can --remote-send
			local run = vim.fn.stdpath("run")
			if vim.fn.isdirectory(run) == 0 then
				pcall(vim.fn.mkdir, run, "p")
			end
			if vim.v.servername == nil or vim.v.servername == "" then
				pcall(vim.fn.serverstart, run .. "/nvim-" .. vim.fn.getpid() .. ".sock")
			end

			-- Cold start: match Omarchy light.mode before first paint settles
			vim.api.nvim_create_autocmd("VimEnter", {
				once = true,
				callback = function()
					vim.o.background = theme_background()
					last_token = theme_token()
				end,
			})

			vim.api.nvim_create_autocmd("User", {
				pattern = "LazyReload",
				callback = function()
					apply_theme()
				end,
			})

			-- Fallback when remote-send never arrives (no socket / hook miss)
			vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
				callback = function()
					local token = theme_token()
					if last_token and token ~= last_token then
						apply_theme()
					else
						last_token = token
					end
				end,
			})

			-- Watch theme.name rewritten by omarchy-theme-set
			local ok_uv, uv = pcall(function()
				return vim.uv or vim.loop
			end)
			if ok_uv and uv and uv.new_fs_event then
				local handle = uv.new_fs_event()
				if handle then
					local watching = theme_name_file
					handle:start(watching, {}, function(err)
						if err then
							return
						end
						vim.schedule(function()
							local token = theme_token()
							if token ~= last_token then
								apply_theme()
							end
						end)
					end)
				end
			end
		end,
	},
}
