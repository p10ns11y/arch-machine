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
-- Image/WARN note: Grok agent emits proprietary JSON-RPC notifications
-- (`_x.ai/mcp/init_progress`, `_x.ai/mcp/server_status`, `_x.ai/mcp/servers_updated`, …).
-- stock avante ACPClient only handles session/* and fs/* and otherwise
-- `vim.notify("Unknown notification method: …", WARN)`. That is protocol-
-- extension noise, not a broken provider/PATH. We ignore `_x.ai/*` below.
--
-- Invalid-buffer toast (nvim_buf_get_name in vim.schedule):
-- Stock avante often calls nvim_buf_get_name on a stale code.bufnr after ACP
-- location-follow / buffer wipe. On Neovim 0.12 that raises a red Error popup
-- (stack: vim/_core/editor → avante.utils.*). We harden hot paths below.
return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
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

          ---@param abs_path string
          ---@return boolean  true if path should be excluded from selection
          local function is_gitignored(abs_path)
            if not abs_path or abs_path == "" then
              return true
            end
            local root = project_root()
            local rel = abs_path
            if Utils.make_relative_path then
              rel = Utils.make_relative_path(abs_path, root)
            end
            -- Prefer git (handles nested rules, negation, dir patterns correctly)
            if vim.fn.executable("git") == 1 then
              vim.fn.system({
                "git",
                "-C",
                root,
                "check-ignore",
                "-q",
                "--",
                rel,
              })
              if vim.v.shell_error == 0 then
                return true
              end
              -- Also try with trailing slash for directories
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
            end
            -- Fallback: parse root .gitignore + always-skip noise
            local gi = root .. "/.gitignore"
            local cached = gitignore_cache[gi]
            if not cached then
              local ignore, negate = {}, {}
              if Utils.parse_gitignore then
                ignore, negate = Utils.parse_gitignore(gi)
              end
              ignore = ignore or {}
              -- Always skip common junk even if not listed
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
            end
            if Utils.is_ignored then
              return Utils.is_ignored(rel, cached.ignore, cached.negate)
            end
            return false
          end

          ---@param paths string[]
          ---@return string[], integer
          local function filter_gitignored(paths)
            local kept, dropped = {}, 0
            for _, p in ipairs(paths or {}) do
              local abs = Utils.to_absolute_path and Utils.to_absolute_path(p) or p
              if is_gitignored(abs) then
                dropped = dropped + 1
              else
                table.insert(kept, abs)
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

          -- Folder add: drop gitignored members
          if type(FileSelector.process_directory) == "function" then
            local orig_proc = FileSelector.process_directory
            ---@diagnostic disable-next-line: duplicate-set-field
            function FileSelector:process_directory(absolute_path)
              local before = #self.selected_filepaths
              orig_proc(self, absolute_path)
              local kept = {}
              local dropped = 0
              for _, p in ipairs(self.selected_filepaths) do
                if is_gitignored(p) then
                  dropped = dropped + 1
                else
                  table.insert(kept, p)
                end
              end
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
              local _ = before
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

          -- Picker listing: never offer gitignored paths
          if type(FileSelector.get_filepaths) == "function" then
            local orig_list = FileSelector.get_filepaths
            ---@diagnostic disable-next-line: duplicate-set-field
            function FileSelector:get_filepaths()
              local list = orig_list(self) or {}
              local root = project_root()
              local out = {}
              for _, rel in ipairs(list) do
                local path = rel
                -- dirs end with /
                local bare = rel:gsub("/$", "")
                local abs = Utils.to_absolute_path and Utils.to_absolute_path(bare) or (root .. "/" .. bare)
                if not is_gitignored(abs) then
                  table.insert(out, path)
                end
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

      -- Ignore Grok proprietary ACP extensions (WARN spam).
      -- Stock avante: acp_client.lua _handle_notification whitelist = session/* + fs/*.
      local ok_acp, ACPClient = pcall(require, "avante.libs.acp_client")
      if ok_acp and type(ACPClient) == "table" and type(ACPClient._handle_notification) == "function" then
        local original = ACPClient._handle_notification
        ---@diagnostic disable-next-line: duplicate-set-field
        function ACPClient:_handle_notification(message_id, method, params)
          if type(method) == "string" and method:match("^_x%.ai/") then
            if type(self._debug_log) == "function" then
              self:_debug_log("ignored proprietary Grok ACP notification: " .. method .. "\n")
            end
            return
          end
          return original(self, message_id, method, params)
        end
      end
    end,
  },
}
