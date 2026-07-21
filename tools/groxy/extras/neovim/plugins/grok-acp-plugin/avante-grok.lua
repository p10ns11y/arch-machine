-- grok-acp-plugin — representative LazyVim/lazy.nvim spec for Grok ACP over stdio.
--
-- In-tree SoT (example / packaging reference):
--   tools/groxy/extras/neovim/plugins/grok-acp-plugin/avante-grok.lua
-- Host install (typical):
--   cp …/avante-grok.lua  ~/.config/nvim/lua/plugins/avante-grok.lua
-- Docs: docs/groxy.md · tools/groxy/README.md
--
-- This is NOT a Grok CLI plugin (not under plugins/arch-machine). It is a
-- Neovim Lazy *spec* that spawns:  grok agent … stdio
-- Daily path does NOT need `groxy acp serve` (that is WebSocket / remote).
--
-- Grok proprietary ACP notifications (`_x.ai/*`): stock avante only handles
-- session/* and fs/* and otherwise WARNs. We **consume** known methods for UI
-- (progress / server status / server list / structured toasts) instead of
-- ignoring or spamming Unknown notification method.
--
-- Invalid-buffer toast (nvim_buf_get_name in vim.schedule):
-- Stock avante often calls nvim_buf_get_name on a stale code.bufnr after ACP
-- location-follow / buffer wipe. On Neovim 0.12 that raises a red Error popup
-- (stack: vim/_core/editor → avante.utils.*). We harden hot paths below.
return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    -- Pin deliberately (review): floating `version = false` alone tracks tip and
    -- can break our host patches. Bump commit after re-testing ACP stdio.
    -- Verified: release-v0.1-32-gff3fc33 (ff3fc33) on host 2026-07-21.
    version = false,
    commit = "ff3fc33b7deeb35a277a211d95d6f2b599fbdf19", -- pin: re-test before bumping
    build = "make",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      {
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = { insert_mode = true },
            use_absolute_path = true,
          },
        },
      },
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
          -- Avante rewrites the result buffer often; higher debounce cuts races
          -- that show as: Context.get → "missing request context" red Error.
          debounce = 120,
          code = {
            -- Keep stock style; only soften via highlight groups we set below.
            width = "block",
            min_width = 0,
            border = "hide",
          },
        },
        ft = { "markdown", "Avante" },
      },
    },
    cmd = {
      "AvanteAsk",
      "AvanteBuild",
      "AvanteChat",
      "AvanteChatNew",
      "AvanteClear",
      "AvanteEdit",
      "AvanteFocus",
      "AvanteHistory",
      "AvanteModels",
      "AvanteRefresh",
      "AvanteShowRepoMap",
      "AvanteStop",
      "AvanteSwitchProvider",
      "AvanteToggle",
      "AvanteZen",
    },
    keys = {
      { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
      { "<leader>aa", "<cmd>AvanteAsk<CR>", desc = "Ask Avante" },
      { "<leader>ac", "<cmd>AvanteChat<CR>", desc = "Chat with Avante" },
      { "<leader>ae", "<cmd>AvanteEdit<CR>", desc = "Edit Avante" },
      { "<leader>af", "<cmd>AvanteFocus<CR>", desc = "Focus Avante" },
      { "<leader>ah", "<cmd>AvanteHistory<CR>", desc = "Avante History" },
      { "<leader>am", "<cmd>AvanteModels<CR>", desc = "Select Avante Model" },
      { "<leader>an", "<cmd>AvanteChatNew<CR>", desc = "New Avante Chat" },
      { "<leader>ap", "<cmd>AvanteSwitchProvider<CR>", desc = "Switch Avante Provider" },
      { "<leader>ar", "<cmd>AvanteRefresh<CR>", desc = "Refresh Avante" },
      { "<leader>as", "<cmd>AvanteStop<CR>", desc = "Stop Avante" },
      { "<leader>at", "<cmd>AvanteToggle<CR>", desc = "Toggle Avante" },
      -- Zen / full-view: hide code pane so Avante fills the editor
      { "<leader>az", "<cmd>AvanteZen<CR>", desc = "Avante zen / full view toggle", mode = { "n", "v" } },
      { "<leader>aZ", "<cmd>AvanteZen force_open<CR>", desc = "Avante open in zen (full view)", mode = { "n", "v" } },
    },
    opts = {
      provider = "grok-acp",
      acp_providers = {
        ["grok-acp"] = {
          -- Prefer PATH; fall back to known install if nvim's env is thinner
          command = (function()
            local from_path = vim.fn.exepath("grok")
            if from_path ~= "" then
              return from_path
            end
            return vim.fn.expand("~/.grok/bin/grok")
          end)(),
          args = {
            "agent",
            -- "--model", "grok-build",
            -- "--always-approve", -- powerful; enable only if you want full auto tools
            "stdio",
          },
          env = {},
        },
      },
      behaviour = {
        -- Use explicit `keys` above only (avoid double-binding with avante defaults)
        auto_set_keymaps = false,
        acp_follow_agent_locations = true,
        auto_set_highlight_group = true,
      },
      selection = {
        hint_display = "none",
      },
      -- Layout: make input band vs result band physically distinct
      windows = {
        position = "right",
        width = 38,
        wrap = true,
        sidebar_header = {
          enabled = true,
          align = "center",
          rounded = true,
          include_model = true,
        },
        input = {
          prefix = "❯ ",
          height = 8, -- composer strip; distinct bg, not a second "chat wall"
        },
        edit = {
          border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
          start_insert = true,
        },
        ask = {
          floating = false,
          border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
          start_insert = true,
        },
      },
      mappings = {
        -- auto_set_keymaps is false; we bind <leader>az via keys + :AvanteZen
        zen_mode = "<leader>az",
        sidebar = {
          -- result pane stock: x toggles code window
          toggle_code_window = "x",
          -- from input strip without leaving chat
          toggle_code_window_from_input = {
            normal = "z",
            insert = "<C-z>",
          },
          -- stock: d remove one, @ add; we add D = deselect all (see patches below)
          remove_file = "d",
          add_file = "@",
        },
      },
    },
    config = function(_, opts)
      require("avante").setup(opts)

      local api = vim.api

      ---------------------------------------------------------------------------
      -- File selection: deselect-all + hard gitignore filter
      --
      -- Stock: d deletes one line, @ opens picker, process_directory uses rg/fd
      -- which *usually* honor .gitignore — but explicit paths, parent dirs, and
      -- some providers still let ignored files in. There is no clear-all key.
      ---------------------------------------------------------------------------
      do
        local ok_u, Utils = pcall(require, "avante.utils")
        local ok_fs, FileSelector = pcall(require, "avante.file_selector")
        local ok_sb, Sidebar = pcall(require, "avante.sidebar")
        if ok_u and ok_fs and ok_sb then
          ---@type table<string, { ignore: string[], negate: string[] }>
          local gitignore_cache = {}

          local function project_root()
            return (Utils.get_project_root and Utils.get_project_root()) or (vim.uv.cwd() or ".")
          end

          ---@param root string
          ---@return { ignore: string[], negate: string[] }
          local function gitignore_patterns(root)
            local gi = root .. "/.gitignore"
            local cached = gitignore_cache[gi]
            if cached then
              return cached
            end
            local ignore, negate = {}, {}
            if Utils.parse_gitignore then
              ignore, negate = Utils.parse_gitignore(gi)
            end
            ignore = ignore or {}
            vim.list_extend(ignore, {
              "%.git",
              "node_modules",
              "target",
              "%.worktree",
              "__pycache__",
              "%.direnv",
            })
            cached = { ignore = ignore, negate = negate or {} }
            gitignore_cache[gi] = cached
            return cached
          end

          ---@param abs_path string
          ---@return string
          local function to_rel(abs_path)
            local root = project_root()
            if Utils.make_relative_path then
              return Utils.make_relative_path(abs_path, root)
            end
            return abs_path
          end

          --- Fallback single-path check (no git or batch miss)
          ---@param abs_path string
          ---@return boolean
          local function is_gitignored_fallback(abs_path)
            if not abs_path or abs_path == "" then
              return true
            end
            local root = project_root()
            local rel = to_rel(abs_path)
            local pat = gitignore_patterns(root)
            if Utils.is_ignored then
              return Utils.is_ignored(rel, pat.ignore, pat.negate)
            end
            return false
          end

          ---@param abs_path string
          ---@return boolean  true if path should be excluded from selection
          local function is_gitignored(abs_path)
            if not abs_path or abs_path == "" then
              return true
            end
            local root = project_root()
            local rel = to_rel(abs_path)
            if vim.fn.executable("git") == 1 then
              vim.fn.system({ "git", "-C", root, "check-ignore", "-q", "--", rel })
              if vim.v.shell_error == 0 then
                return true
              end
              if vim.fn.isdirectory(abs_path) == 1 then
                vim.fn.system({
                  "git",
                  "-C",
                  root,
                  "check-ignore",
                  "-q",
                  "--",
                  rel:gsub("/?$", "/"),
                })
                if vim.v.shell_error == 0 then
                  return true
                end
              end
              return false
            end
            return is_gitignored_fallback(abs_path)
          end

          --- Batch filter via `git check-ignore --stdin` (one process for N paths).
          ---@param paths string[]
          ---@return string[], integer
          local function filter_gitignored(paths)
            local root = project_root()
            local kept, dropped = {}, 0
            if not paths or #paths == 0 then
              return kept, 0
            end

            ---@type string[]
            local abs_list = {}
            ---@type string[]
            local rel_list = {}
            for _, p in ipairs(paths) do
              local abs = Utils.to_absolute_path and Utils.to_absolute_path(p) or p
              abs_list[#abs_list + 1] = abs
              rel_list[#rel_list + 1] = to_rel(abs)
            end

            if vim.fn.executable("git") == 1 and #rel_list > 0 then
              -- One process: stdin paths → stdout ignored paths (exit 0/1 both OK)
              local ignored_out = vim.fn.systemlist(
                { "git", "-C", root, "check-ignore", "--stdin" },
                table.concat(rel_list, "\n") .. "\n"
              )
              local ignored_set = {}
              for _, line in ipairs(ignored_out or {}) do
                if line ~= "" then
                  ignored_set[line] = true
                  ignored_set[line:gsub("/$", "")] = true
                end
              end
              for i, abs in ipairs(abs_list) do
                local rel = rel_list[i]
                if ignored_set[rel] or ignored_set[rel:gsub("/$", "")] or ignored_set[rel .. "/"] then
                  dropped = dropped + 1
                else
                  kept[#kept + 1] = abs
                end
              end
              return kept, dropped
            end

            for _, abs in ipairs(abs_list) do
              if is_gitignored_fallback(abs) then
                dropped = dropped + 1
              else
                kept[#kept + 1] = abs
              end
            end
            return kept, dropped
          end

          -- Clear all selected files (do not use :reset() — it wipes event handlers)
          ---@diagnostic disable-next-line: inject-field
          function FileSelector:clear_selected_files()
            local n = #self.selected_filepaths
            self.selected_filepaths = {}
            self:emit("update")
            if n > 0 then
              vim.notify(
                string.format("Avante: deselected all (%d file%s)", n, n == 1 and "" or "s"),
                vim.log.levels.INFO
              )
            end
          end

          -- Folder add: drop gitignored members (one `git check-ignore --stdin`)
          if type(FileSelector.process_directory) == "function" then
            local orig_proc = FileSelector.process_directory
            ---@diagnostic disable-next-line: duplicate-set-field
            function FileSelector:process_directory(absolute_path)
              orig_proc(self, absolute_path)
              local kept, dropped = filter_gitignored(self.selected_filepaths)
              if dropped > 0 then
                self.selected_filepaths = kept
                self:emit("update")
                vim.notify(
                  string.format(
                    "Avante: skipped %d gitignored file%s under folder",
                    dropped,
                    dropped == 1 and "" or "s"
                  ),
                  vim.log.levels.INFO
                )
              end
            end
          end

          -- Single file / path add
          if type(FileSelector.add_selected_file) == "function" then
            local orig_add = FileSelector.add_selected_file
            ---@diagnostic disable-next-line: duplicate-set-field
            function FileSelector:add_selected_file(filepath)
              if not filepath or filepath == "" then
                return
              end
              local abs = Utils.to_absolute_path and Utils.to_absolute_path(filepath) or filepath
              if is_gitignored(abs) then
                vim.notify("Avante: skipped gitignored path: " .. tostring(filepath), vim.log.levels.WARN)
                return
              end
              return orig_add(self, filepath)
            end
          end

          -- Multi-select from picker
          if type(FileSelector.handle_path_selection) == "function" then
            local orig_handle = FileSelector.handle_path_selection
            ---@diagnostic disable-next-line: duplicate-set-field
            function FileSelector:handle_path_selection(selected_paths)
              if not selected_paths then
                return
              end
              local kept, dropped = filter_gitignored(selected_paths)
              if dropped > 0 then
                vim.notify(
                  string.format("Avante: skipped %d gitignored path%s", dropped, dropped == 1 and "" or "s"),
                  vim.log.levels.INFO
                )
              end
              if #kept == 0 then
                return
              end
              return orig_handle(self, kept)
            end
          end

          -- Picker listing: never offer gitignored paths (batched)
          if type(FileSelector.get_filepaths) == "function" then
            local orig_list = FileSelector.get_filepaths
            ---@diagnostic disable-next-line: duplicate-set-field
            function FileSelector:get_filepaths()
              local list = orig_list(self) or {}
              if #list == 0 then
                return list
              end
              local root = project_root()
              ---@type string[]
              local abs_for_check = {}
              ---@type table<string, string>  abs -> original list entry (may keep trailing /)
              local abs_to_orig = {}
              for _, rel in ipairs(list) do
                local bare = rel:gsub("/$", "")
                local abs = Utils.to_absolute_path and Utils.to_absolute_path(bare) or (root .. "/" .. bare)
                abs_for_check[#abs_for_check + 1] = abs
                abs_to_orig[abs] = rel
              end
              local kept_abs = filter_gitignored(abs_for_check)
              local out = {}
              for _, abs in ipairs(kept_abs) do
                out[#out + 1] = abs_to_orig[abs] or abs
              end
              return out
            end
          end

          -- Keymap D = deselect all + richer hint
          if type(Sidebar.create_selected_files_container) == "function" then
            local orig_create = Sidebar.create_selected_files_container
            ---@diagnostic disable-next-line: duplicate-set-field
            function Sidebar:create_selected_files_container(...)
              orig_create(self, ...)
              local cont = self.containers and self.containers.selected_files
              if not cont or type(cont.map) ~= "function" then
                return
              end
              cont:map("n", "D", function()
                if self.file_selector and self.file_selector.clear_selected_files then
                  self.file_selector:clear_selected_files()
                else
                  self.file_selector.selected_filepaths = {}
                  self.file_selector:emit("update")
                end
              end, { noremap = true, silent = true, desc = "Deselect all files" })
              cont:map("n", "X", function()
                if self.file_selector and self.file_selector.clear_selected_files then
                  self.file_selector:clear_selected_files()
                end
              end, { noremap = true, silent = true, desc = "Deselect all files" })
            end
          end

          if type(Sidebar.show_selected_files_hint) == "function" then
            local orig_hint = Sidebar.show_selected_files_hint
            ---@diagnostic disable-next-line: duplicate-set-field
            function Sidebar:show_selected_files_hint(...)
              orig_hint(self, ...)
              -- Overlay a clearer right-align hint including deselect-all
              local cont = self.containers and self.containers.selected_files
              if not cont or not cont.bufnr or not api.nvim_buf_is_valid(cont.bufnr) then
                return
              end
              local n = self.file_selector and #self.file_selector.selected_filepaths or 0
              local hint
              if n == 0 then
                hint = " [@: add] "
              else
                hint = string.format(" [d: del  D: deselect all  @: add] (%d) ", n)
              end
              local ok_ns, ns = pcall(api.nvim_create_namespace, "avante_selected_files_hint_extra")
              if not ok_ns then
                return
              end
              local cursor = api.nvim_win_get_cursor(cont.winid)
              pcall(api.nvim_buf_clear_namespace, cont.bufnr, ns, 0, -1)
              pcall(api.nvim_buf_set_extmark, cont.bufnr, ns, cursor[1] - 1, 0, {
                virt_text = { { hint, "AvanteInlineHint" } },
                virt_text_pos = "right_align",
                priority = 200,
              })
            end
          end

          vim.api.nvim_create_user_command("AvanteDeselectFiles", function()
            local ok_av, avante = pcall(require, "avante")
            local sidebar = ok_av and avante.get and avante.get() or nil
            if sidebar and sidebar.file_selector and sidebar.file_selector.clear_selected_files then
              sidebar.file_selector:clear_selected_files()
            else
              vim.notify("Avante sidebar not open", vim.log.levels.WARN)
            end
          end, { desc = "Deselect all Avante selected files" })
        end -- ok_u and ok_fs and ok_sb
      end

      ---------------------------------------------------------------------------
      -- render-markdown race fix (Image: red Error / C: in function 'get')
      --
      -- Stock path: Updater:parse → Context.new → async view:parse →
      -- handlers → Context.get(buf). If Avante re-renders before context is
      -- cached (or cache was clobbered), get() asserts "missing request context"
      -- and vim.schedule surfaces a red Error toast.
      -- Re-create context on miss instead of crashing the UI.
      ---------------------------------------------------------------------------
      do
        local ok_ctx, Context = pcall(require, "render-markdown.request.context")
        if ok_ctx and type(Context) == "table" and type(Context.get) == "function" then
          local orig_get = Context.get
          local orig_new = Context.new
          ---@diagnostic disable-next-line: duplicate-set-field
          Context.get = function(buf)
            local ok, res = pcall(orig_get, buf)
            if ok and res ~= nil then
              return res
            end
            -- Miss: rebuild if buffer still valid
            if type(buf) ~= "number" or not api.nvim_buf_is_valid(buf) then
              error("render-markdown: invalid buf for Context.get")
            end
            local wins = vim.fn.win_findbuf(buf)
            local win = (wins and wins[1]) or 0
            if win == 0 or not api.nvim_win_is_valid(win) then
              -- No window: invent a noop-safe path by reusing cwd win
              win = api.nvim_get_current_win()
            end
            local ok_state, state = pcall(require, "render-markdown.state")
            local config = ok_state and state.get and state.get(buf) or nil
            if type(orig_new) == "function" and config then
              local rebuilt = orig_new(buf, win, config)
              if rebuilt then
                return rebuilt
              end
            end
            -- Last resort: rethrow original
            return orig_get(buf)
          end
        end
      end

      ---------------------------------------------------------------------------
      -- Zen / full-screen toggle
      -- Stock api.zen_mode() opens ask already full (not a true toggle).
      -- Ours: sidebar open → toggle full view; else open in full view.
      ---------------------------------------------------------------------------
      local function avante_zen_toggle(toggle_opts)
        toggle_opts = toggle_opts or {}
        local force_open = toggle_opts.force_open == true
        local ok_av, avante = pcall(require, "avante")
        if not ok_av then
          vim.notify("avante not loaded", vim.log.levels.WARN)
          return
        end
        local sidebar = avante.get and avante.get() or nil
        local open = sidebar and sidebar.is_open and sidebar:is_open()

        if open and not force_open then
          if type(sidebar.toggle_code_window) == "function" then
            sidebar:toggle_code_window()
            local full = sidebar.is_in_full_view and "zen (full)" or "split (code + chat)"
            vim.notify("Avante view: " .. full, vim.log.levels.INFO)
          end
          return
        end

        local ok_api, Api = pcall(require, "avante.api")
        if ok_api and type(Api.zen_mode) == "function" then
          Api.zen_mode()
          vim.notify("Avante zen: opened full view", vim.log.levels.INFO)
        elseif ok_api and type(Api.ask) == "function" then
          Api.ask({
            show_logo = true,
            sidebar_post_render = function(sb)
              if sb and type(sb.toggle_code_window) == "function" and not sb.is_in_full_view then
                sb:toggle_code_window()
              end
            end,
          })
        else
          vim.notify("avante.api.zen_mode unavailable", vim.log.levels.ERROR)
        end
      end

      vim.api.nvim_create_user_command("AvanteZen", function(cmd_opts)
        local force = false
        if cmd_opts.args and cmd_opts.args:match("force") then
          force = true
        end
        avante_zen_toggle({ force_open = force })
      end, {
        nargs = "?",
        desc = "Toggle Avante zen/full view (hide code). Args: force_open",
        complete = function()
          return { "force_open" }
        end,
      })

      _G.AvanteZenToggle = avante_zen_toggle

      ---------------------------------------------------------------------------
      -- Theme / layout contrast
      --
      -- Problem (Image: flat brown UI): transparency.lua clears Normal/NormalFloat
      -- backgrounds, and stock AvanteSidebarNormal links to NormalFloat — so the
      -- result pane and the input pane share one wash of color with no hierarchy.
      -- Fix: solid, distinct Avante* groups + FileType winhl (not cleared by
      -- transparency's group list). Re-apply on ColorScheme / theme hotreload.
      ---------------------------------------------------------------------------
      local function avante_palette()
        local light = vim.o.background == "light"
        if light then
          return {
            -- Panes (same warm family; input only slightly cooler)
            result_bg = "#E8DFD0",
            result_fg = "#3C3836",
            input_bg = "#DFD6C6",
            input_fg = "#1D2021",
            sep_fg = "#A89984",
            title_bg = "#7C6F64",
            title_fg = "#FBF1C7",
            subtitle_bg = "#928374",
            subtitle_fg = "#FBF1C7",
            border_fg = "#A89984",
            hint_fg = "#7C6F64",
            -- Tool chips: soft pill, not neon bar
            ok_fg = "#FBF1C7",
            ok_bg = "#689D6A",
            run_fg = "#FBF1C7",
            run_bg = "#458588",
            fail_fg = "#FBF1C7",
            fail_bg = "#CC241D",
            -- Diff in tool cards (muted)
            del_bg = "#E8C4C0",
            del_fg = "#9D0006",
            add_bg = "#D5E4C7",
            add_fg = "#276320",
            code_bg = "#DDD4C4",
            code_fg = "#3C3836",
          }
        end
        -- dark — eye-comfort gruvbox soft (dark0 #322922)
        -- Hierarchy: result slightly lifted, input a shade deeper (same hue family)
        return {
          result_bg = "#3A3129",
          result_fg = "#E8DED0",
          input_bg = "#2B241E",
          input_fg = "#E8DED0",
          sep_fg = "#7A6A5A", -- quiet separator, not neon green
          title_bg = "#5A4A3A",
          title_fg = "#E8DED0",
          subtitle_bg = "#4A3E34",
          subtitle_fg = "#D5C4A1",
          border_fg = "#7A6A5A",
          hint_fg = "#A89984",
          -- Tool state chips: compact accent, readable on dark
          ok_fg = "#1D2021",
          ok_bg = "#A9B665", -- soft olive, not #98c379 neon wash
          run_fg = "#1D2021",
          run_bg = "#7DAEA3",
          fail_fg = "#1D2021",
          fail_bg = "#E78A4E", -- warm fail, not pure red scream
          -- Diff inside tool cards (toned down)
          del_bg = "#4A3030",
          del_fg = "#D8A0A0",
          add_bg = "#2F3A2C",
          add_fg = "#B8C88A",
          code_bg = "#322A24",
          code_fg = "#D5C4A1",
        }
      end

      local function apply_avante_colors()
        local p = avante_palette()
        local function set(name, spec)
          api.nvim_set_hl(0, name, spec)
        end

        -- ── Panes ──────────────────────────────────────────────────────────
        set("AvanteSidebarNormal", { fg = p.result_fg, bg = p.result_bg })
        set("AvanteSidebarWinSeparator", { fg = p.sep_fg, bg = p.result_bg })
        set("AvanteSidebarWinHorizontalSeparator", { fg = p.sep_fg, bg = p.result_bg })
        set("AvantePromptInput", { fg = p.input_fg, bg = p.input_bg })
        set("AvantePromptInputBorder", { fg = p.border_fg, bg = p.input_bg })
        set("AvantePromptInputHL", { fg = p.ok_bg, bg = p.input_bg, bold = true })

        -- ── Header chips (top bar) ─────────────────────────────────────────
        set("AvanteTitle", { fg = p.title_fg, bg = p.title_bg, bold = true })
        set("AvanteReversedTitle", { fg = p.title_bg, bg = p.result_bg })
        set("AvanteSubtitle", { fg = p.subtitle_fg, bg = p.subtitle_bg, bold = true })
        set("AvanteReversedSubtitle", { fg = p.subtitle_bg, bg = p.result_bg })
        set("AvanteThirdTitle", { fg = p.hint_fg, bg = p.input_bg })
        set("AvanteReversedThirdTitle", { fg = p.input_bg, bg = p.result_bg })
        set("AvantePopupHint", { fg = p.hint_fg, bg = p.input_bg })
        set("AvanteInlineHint", { fg = p.hint_fg, bg = p.input_bg, italic = true })
        set("AvanteCommentFg", { fg = p.hint_fg, italic = true })
        set("AvanteInputPromptSign", { fg = p.ok_bg, bg = p.input_bg, bold = true })
        set("AvanteSelectedCode", { fg = p.code_fg, bg = p.code_bg })
        set("AvanteSelectedFiles", { fg = p.hint_fg, bg = p.result_bg })

        -- ── Tool-call state chips (the loud green bar in your screenshot) ──
        -- Used as: { " Execute(cmd) ", STATE_TO_HL[state] }
        set("AvanteStateSpinnerSucceeded", { fg = p.ok_fg, bg = p.ok_bg, bold = true })
        set("AvanteStateSpinnerGenerating", { fg = p.run_fg, bg = p.run_bg, bold = true })
        set("AvanteStateSpinnerToolCalling", { fg = p.run_fg, bg = p.run_bg, bold = true })
        set("AvanteStateSpinnerFailed", { fg = p.fail_fg, bg = p.fail_bg, bold = true })
        set("AvanteStateSpinnerSearching", { fg = p.run_fg, bg = p.run_bg, bold = true })
        set("AvanteStateSpinnerThinking", { fg = p.run_fg, bg = p.subtitle_bg, bold = true })
        set("AvanteStateSpinnerCompacting", { fg = p.hint_fg, bg = p.subtitle_bg })
        set("AvanteTaskRunning", { fg = p.run_bg, bg = p.result_bg })
        set("AvanteTaskCompleted", { fg = p.ok_bg, bg = p.result_bg })
        set("AvanteTaskFailed", { fg = p.fail_bg, bg = p.result_bg })
        set("AvanteThinking", { fg = p.hint_fg, bg = p.result_bg, italic = true })

        -- ── Diff inside tool cards (was harsh yellow/red wash) ─────────────
        set("AvanteToBeDeleted", { fg = p.del_fg, bg = p.del_bg, strikethrough = true })
        set("AvanteToBeDeletedWOStrikethrough", { fg = p.del_fg, bg = p.del_bg })
        set("AvanteConflictCurrent", { fg = p.del_fg, bg = p.del_bg, bold = true })
        set("AvanteConflictIncoming", { fg = p.add_fg, bg = p.add_bg, bold = true })
        set("AvanteConflictCurrentLabel", { fg = p.del_fg, bg = p.del_bg, bold = true })
        set("AvanteConflictIncomingLabel", { fg = p.add_fg, bg = p.add_bg, bold = true })

        -- ── Code / markdown in Avante buffer ───────────────────────────────
        set("AvanteCodeBlock", { fg = p.code_fg, bg = p.code_bg })
        set("AvanteCodeInline", { fg = p.code_fg, bg = p.code_bg })
        -- Keep RenderMarkdown groups from blasting neon on Avante panes
        set("RenderMarkdownCode", { fg = p.code_fg, bg = p.code_bg })
        set("RenderMarkdownCodeInline", { fg = p.code_fg, bg = p.code_bg })
      end

      local function apply_avante_winhl()
        local win = api.nvim_get_current_win()
        local ft = vim.bo.filetype
        if ft == "AvanteInput" or ft == "AvantePromptInput" then
          -- Input: cool green ground + green separator
          pcall(
            api.nvim_set_option_value,
            "winhighlight",
            table.concat({
              "Normal:AvantePromptInput",
              "NormalNC:AvantePromptInput",
              "SignColumn:AvantePromptInput",
              "EndOfBuffer:AvantePromptInput",
              "CursorLine:AvantePromptInput",
              "WinSeparator:AvantePromptInputBorder",
              "FloatBorder:AvantePromptInputBorder",
            }, ","),
            { win = win }
          )
          pcall(api.nvim_set_option_value, "signcolumn", "yes", { win = win })
        elseif ft == "Avante" or ft == "AvanteSelectedFiles" or ft == "AvanteSelectedCode" then
          -- Response / chrome: warm brown ground
          pcall(
            api.nvim_set_option_value,
            "winhighlight",
            table.concat({
              "Normal:AvanteSidebarNormal",
              "NormalNC:AvanteSidebarNormal",
              "SignColumn:AvanteSidebarNormal",
              "EndOfBuffer:AvanteSidebarNormal",
              "CursorLine:AvanteSidebarNormal",
              "WinSeparator:AvanteSidebarWinSeparator",
            }, ","),
            { win = win }
          )
        end
      end

      apply_avante_colors()

      -- Once: FileType hooks so new Avante panes get distinct winhl
      if not vim.g._avante_ui_autocmds then
        vim.g._avante_ui_autocmds = true
        api.nvim_create_autocmd("FileType", {
          pattern = { "Avante", "AvanteInput", "AvantePromptInput", "AvanteSelectedFiles", "AvanteSelectedCode" },
          callback = function()
            vim.schedule(apply_avante_winhl)
          end,
        })
        api.nvim_create_autocmd("ColorScheme", {
          callback = function()
            -- After theme + transparency.lua: re-assert solid Avante panes
            vim.defer_fn(function()
              apply_avante_colors()
              -- refresh open avante windows
              for _, win in ipairs(api.nvim_list_wins()) do
                local buf = api.nvim_win_get_buf(win)
                local ft = vim.bo[buf].filetype
                if ft:match("^Avante") then
                  api.nvim_win_call(win, apply_avante_winhl)
                end
              end
            end, 30)
          end,
        })
        api.nvim_create_autocmd("User", {
          pattern = { "LazyReload", "AvanteInputSubmitted" },
          callback = function()
            vim.defer_fn(apply_avante_colors, 20)
          end,
        })
      end

      ---@param buf integer|nil
      ---@return boolean
      local function buf_ok(buf)
        return type(buf) == "number" and buf > 0 and api.nvim_buf_is_valid(buf)
      end

      ---@param buf integer|nil
      ---@return string
      local function safe_buf_name(buf)
        if not buf_ok(buf) then
          return ""
        end
        local ok, name = pcall(api.nvim_buf_get_name, buf)
        if ok and type(name) == "string" then
          return name
        end
        return ""
      end

      -- Harden project-root detection (unprotected nvim_buf_get_name in stock Root.get).
      local ok_root, Root = pcall(require, "avante.utils.root")
      if ok_root and type(Root) == "table" and type(Root.get) == "function" then
        local orig_root_get = Root.get
        ---@diagnostic disable-next-line: duplicate-set-field
        Root.get = function(get_opts)
          get_opts = get_opts or {}
          local buf = get_opts.buf
          if buf == nil or buf == 0 then
            buf = api.nvim_get_current_buf()
          end
          if not buf_ok(buf) then
            return (vim.uv.cwd() or "")
          end
          -- Pre-touch name with pcall so stock path never raises on invalid id
          local _ = safe_buf_name(buf)
          get_opts.buf = buf
          local ok_call, ret = pcall(orig_root_get, get_opts)
          if ok_call and type(ret) == "string" and ret ~= "" then
            return ret
          end
          return (vim.uv.cwd() or "")
        end
      end

      -- Harden get_doc (nvim_buf_get_name(0) + changedtick on odd buffers).
      local ok_u, Utils = pcall(require, "avante.utils")
      if ok_u and type(Utils) == "table" and type(Utils.get_doc) == "function" then
        local orig_get_doc = Utils.get_doc
        ---@diagnostic disable-next-line: duplicate-set-field
        Utils.get_doc = function()
          local buf = api.nvim_get_current_buf()
          if not buf_ok(buf) then
            return {
              uri = "",
              version = 0,
              relativePath = "",
              insertSpaces = vim.o.expandtab,
              tabSize = vim.fn.shiftwidth(),
              indentSize = vim.fn.shiftwidth(),
              position = { row = 1, col = 0 },
            }
          end
          local ok_call, doc = pcall(orig_get_doc)
          if ok_call then
            return doc
          end
          return {
            uri = "",
            version = 0,
            relativePath = "",
            insertSpaces = vim.o.expandtab,
            tabSize = vim.fn.shiftwidth(),
            indentSize = vim.fn.shiftwidth(),
            position = { row = 1, col = 0 },
          }
        end
      end

      -- Sidebar prompt builder: code.bufnr can go stale after ACP follow / wipe.
      local ok_s, Sidebar = pcall(require, "avante.sidebar")
      if ok_s and type(Sidebar) == "table" and type(Sidebar.get_generate_prompts_options) == "function" then
        local orig_prompts = Sidebar.get_generate_prompts_options
        ---@diagnostic disable-next-line: duplicate-set-field
        function Sidebar:get_generate_prompts_options(request, cb)
          if self.code and not buf_ok(self.code.bufnr) then
            self.code.bufnr = api.nvim_get_current_buf()
          end
          local ok_call, a, b = pcall(orig_prompts, self, request, cb)
          if ok_call then
            return a, b
          end
          -- Fall through: empty prompts path rather than red Error toast
          if type(cb) == "function" then
            return
          end
          return nil
        end
      end

      -- Regression fix (API-key toast on ACP):
      -- Stock Providers.setup() always does `vim.g.avante_login = false` then
      -- early-returns for ACP providers (no API key env). Sidebar:submit_input
      -- gates on avante_login and shows the misleading
      -- "Sending message to fast!, API key is not yet set".
      local function ensure_acp_login()
        local Config = require("avante.config")
        if Config.acp_providers and Config.acp_providers[Config.provider] then
          vim.g.avante_login = true
        end
      end
      ensure_acp_login()

      local ok_p, Providers = pcall(require, "avante.providers")
      if ok_p and type(Providers.setup) == "function" then
        local orig_providers_setup = Providers.setup
        ---@diagnostic disable-next-line: duplicate-set-field
        Providers.setup = function(...)
          local ret = orig_providers_setup(...)
          ensure_acp_login()
          return ret
        end
      end

      if ok_s and type(Sidebar) == "table" and type(Sidebar.submit_input) == "function" then
        local orig_submit = Sidebar.submit_input
        ---@diagnostic disable-next-line: duplicate-set-field
        function Sidebar:submit_input(...)
          ensure_acp_login()
          return orig_submit(self, ...)
        end
      end

      -- Consume Grok proprietary ACP extensions (`_x.ai/*`) for operator UI.
      -- Stock avante: acp_client.lua whitelist = session/* + fs/* only → WARN spam.
      ---------------------------------------------------------------------------
      -- State (also usable by statusline / which-key): vim.g.grok_acp_mcp
      ---------------------------------------------------------------------------
      vim.g.grok_acp_mcp = vim.g.grok_acp_mcp
        or {
          servers = {}, -- name -> { status, detail, at }
          last_progress = nil, -- { message, progress, server, at }
          ready = false,
          last_method = nil,
          event_count = 0,
        }

      ---@param params table|nil
      ---@return string|nil
      local function xai_pick_name(params)
        if type(params) ~= "table" then
          return nil
        end
        return params.name or params.server or params.serverName or params.id or params.server_id
      end

      ---@param params table|nil
      ---@return string|nil
      local function xai_pick_message(params)
        if type(params) ~= "table" then
          return nil
        end
        return params.message
          or params.body
          or params.status_message
          or params.detail
          or params.title
      end

      ---@param params table|nil
      ---@return number|string|nil
      local function xai_pick_progress(params)
        if type(params) ~= "table" then
          return nil
        end
        local p = params.progress or params.percent or params.fraction or params.pct
        if type(p) == "number" and p > 0 and p <= 1 then
          return string.format("%d%%", math.floor(p * 100 + 0.5))
        end
        return p
      end

      --- Toast throttle: same signature within window → drop; coalesce latest
      local toast_last = {} ---@type table<string, number>
      local TOAST_THROTTLE_MS = 2500
      local last_echo_ms = 0
      local ECHO_THROTTLE_MS = 600
      local session_note_count = 0
      local session_note_flush = nil ---@type any

      local function now_ms()
        if vim.uv and vim.uv.now then
          return vim.uv.now()
        end
        if vim.loop and vim.loop.now then
          return vim.loop.now()
        end
        return os.time() * 1000
      end

      --- Method / kind names that are not operator-readable (Image #1 spam).
      local GENERIC_LABELS = {
        session_notification = true,
        notification = true,
        ["mcp/session_notification"] = true,
        ["mcp/init_progress"] = true,
        ["mcp/server_status"] = true,
        ["mcp/servers_updated"] = true,
        ["_x.ai/session_notification"] = true,
        ["Grok ACP"] = true, -- old title; never use as body
      }

      ---@param s string|nil
      ---@return boolean
      local function is_generic_label(s)
        if not s or s == "" then
          return true
        end
        local t = tostring(s):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if GENERIC_LABELS[t] then
          return true
        end
        -- bare method suffixes / snake_case event names with no human text
        if t:match("^[%w_./]+$") and (t:find("notification", 1, true) or t:find("progress", 1, true)) then
          return true
        end
        return false
      end

      ---@param title string
      ---@param body string
      ---@param lvl integer
      ---@param force boolean|nil
      local function notify_throttled(title, body, lvl, force)
        body = (body or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        title = (title or "Grok"):gsub("%s+", " ")
        -- Never toast empty / generic-only payloads
        if is_generic_label(body) then
          return
        end
        if is_generic_label(title) and body == title then
          return
        end
        -- Prefer human titles; rewrite legacy "Grok ACP" + method-name body
        if title == "Grok ACP" or title == "" then
          title = "Grok"
        end
        local sig = title .. "\0" .. body .. "\0" .. tostring(lvl)
        local t = now_ms()
        if not force and toast_last[sig] and (t - toast_last[sig]) < TOAST_THROTTLE_MS then
          return
        end
        toast_last[sig] = t
        -- Cap toast map growth
        local n = 0
        for _ in pairs(toast_last) do
          n = n + 1
        end
        if n > 64 then
          toast_last = { [sig] = t }
        end
        vim.schedule(function()
          vim.notify(body, lvl, { title = title })
        end)
      end

      ---@param line string
      local function echo_throttled(line)
        local t = now_ms()
        if t - last_echo_ms < ECHO_THROTTLE_MS then
          return
        end
        last_echo_ms = t
        vim.schedule(function()
          vim.api.nvim_echo({ { line, "Comment" } }, false, {})
        end)
      end

      ---@param method string
      ---@param params table|nil
      local function handle_xai_notification(method, params)
        params = type(params) == "table" and params or {}
        local suffix = method:match("^_x%.ai/(.+)$") or method
        if method:match("^_x%.ai/") then
          suffix = method:match("^_x%.ai/(.+)$")
        end
        if not suffix then
          return false
        end

        local state = vim.g.grok_acp_mcp
        state.event_count = (state.event_count or 0) + 1
        state.last_method = method
        local now = os.time()

        -- High-frequency session noise: coalesce, never N identical toasts
        if suffix == "session_notification" or suffix:find("session_notification", 1, true) then
          session_note_count = session_note_count + 1
          local msg = xai_pick_message(params)
            or params.text
            or params.content
            or params.summary
          if type(msg) == "table" then
            msg = msg.text or msg.message or vim.inspect(msg)
          end
          local kind = params.kind or params.type or params.category
          state.last_session_note = {
            kind = kind,
            message = msg,
            count = session_note_count,
            at = now,
          }
          -- Meaningful human text only → throttled toast; never method-name cards
          if msg and not is_generic_label(tostring(msg)) then
            local title = "Grok"
            if kind and not is_generic_label(tostring(kind)) then
              title = "Grok · " .. tostring(kind)
            end
            notify_throttled(title, tostring(msg), vim.log.levels.INFO, false)
          else
            -- Pure noise: delayed cmdline echo summary (no popup stack)
            if session_note_flush then
              pcall(vim.fn.timer_stop, session_note_flush)
            end
            session_note_flush = vim.fn.timer_start(2000, function()
              session_note_flush = nil
              local n = session_note_count
              session_note_count = 0
              if n > 3 then
                -- Only surface a quiet echo when there was real volume
                echo_throttled(string.format("Grok session: %d quiet update(s)", n))
              end
            end)
          end
          vim.g.grok_acp_mcp = state
          return true
        end

        -- MCP init progress: echo only (throttled)
        if suffix == "mcp/init_progress" or suffix:find("init_progress", 1, true) then
          local msg = xai_pick_message(params) or "starting"
          local pct = xai_pick_progress(params)
          local server = xai_pick_name(params)
          state.last_progress = {
            message = msg,
            progress = pct,
            server = server,
            at = now,
          }
          if server then
            state.servers[server] = state.servers[server] or { status = "starting", at = now }
            state.servers[server].status = "starting"
            state.servers[server].at = now
          end
          local line = "Grok MCP"
          if server then
            line = line .. " · " .. tostring(server)
          end
          line = line .. ": " .. tostring(msg)
          if pct then
            line = line .. " (" .. tostring(pct) .. ")"
          end
          echo_throttled(line)
          vim.g.grok_acp_mcp = state
          return true
        end

        -- Single server status: toast only on meaningful transitions
        if suffix == "mcp/server_status" or suffix:find("server_status", 1, true) then
          local name = xai_pick_name(params) or "server"
          local st = params.status or params.state or params.phase or "unknown"
          local prev = state.servers[name] and state.servers[name].status
          state.servers[name] = {
            status = st,
            detail = xai_pick_message(params),
            at = now,
          }
          local st_l = tostring(st):lower()
          local detail = xai_pick_message(params)
          local body = detail and string.format("%s → %s — %s", name, st, detail)
            or string.format("%s → %s", name, st)
          if st_l:find("err") or st_l:find("fail") or st_l:find("disconnect") then
            notify_throttled("Grok MCP", body, vim.log.levels.WARN, true)
          elseif prev ~= st and (st_l:find("ready") or st_l:find("ok") or st_l:find("connected") or st_l == "running") then
            notify_throttled("Grok MCP", body, vim.log.levels.INFO, false)
          else
            echo_throttled("Grok MCP · " .. body)
          end
          vim.g.grok_acp_mcp = state
          return true
        end

        -- Full server list refresh (one toast)
        if suffix == "mcp/servers_updated" or suffix:find("servers_updated", 1, true) then
          local list = params.servers or params.items or params.list or {}
          if type(list) == "table" then
            for _, s in ipairs(list) do
              if type(s) == "string" then
                state.servers[s] = state.servers[s] or { status = "ready", at = now }
                state.servers[s].at = now
              elseif type(s) == "table" then
                local name = s.name or s.id or s.server or "?"
                state.servers[name] = {
                  status = s.status or s.state or "ready",
                  detail = s.message or s.detail,
                  at = now,
                }
              end
            end
          end
          if type(params.by_name) == "table" then
            for name, st in pairs(params.by_name) do
              state.servers[tostring(name)] = {
                status = type(st) == "table" and (st.status or st.state) or st,
                at = now,
              }
            end
          end
          state.ready = true
          local n = 0
          for _ in pairs(state.servers) do
            n = n + 1
          end
          notify_throttled(
            "Grok MCP",
            n > 0 and string.format("%d server(s) connected", n) or "server list updated",
            vim.log.levels.INFO,
            false
          )
          vim.g.grok_acp_mcp = state
          return true
        end

        -- PR / system structured (kind/title/body)
        if suffix:find("^pr/", 1) or params.kind or params.title then
          local kind = params.kind or suffix
          local title = "Grok · " .. tostring(kind)
          local body = params.body or params.message or params.detail or params.title
          if body and tostring(body) ~= tostring(kind) then
            notify_throttled(title, tostring(body), vim.log.levels.INFO, false)
          else
            echo_throttled(title)
          end
          vim.g.grok_acp_mcp = state
          return true
        end

        -- Unknown _x.ai/* : quiet store
        state.last_unknown = { method = method, params = params, at = now }
        vim.g.grok_acp_mcp = state
        return true
      end

      vim.api.nvim_create_user_command("GrokMcpStatus", function()
        local state = vim.g.grok_acp_mcp or {}
        local lines = {
          "Grok ACP MCP state",
          "  events: " .. tostring(state.event_count or 0),
          "  ready: " .. tostring(state.ready),
          "  last_method: " .. tostring(state.last_method),
        }
        if state.last_progress then
          local p = state.last_progress
          lines[#lines + 1] = string.format(
            "  last_progress: %s %s %s",
            tostring(p.server or ""),
            tostring(p.message or ""),
            tostring(p.progress or "")
          )
        end
        lines[#lines + 1] = "  servers:"
        local servers = state.servers or {}
        local names = vim.tbl_keys(servers)
        table.sort(names)
        if #names == 0 then
          lines[#lines + 1] = "    (none yet — open an Avante chat to connect)"
        else
          for _, name in ipairs(names) do
            local s = servers[name]
            lines[#lines + 1] = string.format(
              "    - %s: %s%s",
              name,
              tostring(s.status or "?"),
              s.detail and (" — " .. tostring(s.detail)) or ""
            )
          end
        end
        if state.last_unknown then
          lines[#lines + 1] = "  last_unknown: " .. tostring(state.last_unknown.method)
        end
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Grok MCP" })
      end, { desc = "Show Grok ACP MCP server/progress state from _x.ai/* notifications" })

      local ok_acp, ACPClient = pcall(require, "avante.libs.acp_client")
      if ok_acp and type(ACPClient) == "table" and type(ACPClient._handle_notification) == "function" then
        local original = ACPClient._handle_notification
        ---@diagnostic disable-next-line: duplicate-set-field
        function ACPClient:_handle_notification(message_id, method, params)
          if type(method) == "string" and method:match("^_x%.ai/") then
            if type(self._debug_log) == "function" then
              self:_debug_log("grok _x.ai notification: " .. method .. "\n" .. vim.inspect(params) .. "\n")
            end
            local ok_h, err = pcall(handle_xai_notification, method, params)
            if not ok_h and type(self._debug_log) == "function" then
              self:_debug_log("grok _x.ai handler error: " .. tostring(err) .. "\n")
            end
            return -- never fall through to Unknown notification WARN
          end
          return original(self, message_id, method, params)
        end
      end
    end,
  },
}
