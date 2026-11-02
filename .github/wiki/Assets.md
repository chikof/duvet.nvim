# 📂 Custom Assets

Duvet allows you to go beyond the default icons and fully customize the assets used in your presence. This guide will walk you through how to override and define custom assets.

## 🛠️ Structure

Custom assets are configured within the `assets` table in your `duvet.setup()` call. The basic structure is as follows:

```lua
require('duvet').setup {
  assets = {
    -- "key" = "icon" or { asset_options }
  },
}
```

Here, `"key"` is the identifier for the asset, and `"value"` can be either a simple string for the asset icon or a table for more detailed asset options.

## 🔑 Asset Keys

The `key` in your asset configuration determines what type of file or context the custom asset will apply to. You can use the following key types:

- **Filetype**: Use a Vim filetype string (e.g., `"lua"`, `"python"`) to set assets for specific languages.
- **Filename**: Use a specific filename (e.g., `"Cargo.toml"`, `"README.md"`) to customize assets for particular files.
- **File Extension**: Use a file extension (e.g., `".rs"`, `".js"`) to apply assets to all files with that extension.
- **Special Keys**: Duvet provides special keys for generic scenarios (see [Overriding Defaults](#-overriding-defaults)).

## ⚙️ Asset Options

When you use a table as the `value` in your asset configuration, you can specify these options to fine-tune your custom asset:

| Option    | Type                  | Description                                                                                                  |
| --------- | --------------------- | ------------------------------------------------------------------------------------------------------------ |
| `icon`    | `string \| function ` | A direct URL to the icon image. |
| `tooltip` | `string \| function`  | Text that appears when you hover over the icon in Duvet.                                                   |
| `name`    | `string \| function`  | An optional override for the icon's name. Generally used for types other than `language`.                    |
| `text`    | `string \| function`  | An optional override for the icon's text. **Completely replaces** the default text.                          |
| `type`    | `string`              | Specifies the context of the asset.  See [Asset Types](#asset-types) for available options.                  |

### Asset Types

The `type` option categorizes your asset, influencing how Duvet displays it. Available types include:
- `language` (default)
- `docs`
- `plugin_manager`
- `lsp_manager`
- `file_browser`
- `vcs`
- `workspace`
- `dashboard`
- `notes`
- `debug`
- `test`
- `diagnostics`
- `games`
- `terminal`

## 🚀 Examples

**1. Simple Icon Replacement by Extension:**

```lua
assets = {
  ['.rs'] = 'https://...', -- Use this icon URL for all Rust files
}
```

This will use the given icon URL for any file with the `.rs` extension.

**2. Custom Icon and Tooltip for a Filetype:**

```lua
assets = {
  lua = {
    icon = 'lua_custom_icon',
    tooltip = 'Lua Script', -- Custom tooltip for Lua files
  },
}
```

This example sets a custom icon and tooltip specifically for Lua files (the `lua` filetype).

**3. Using Duvet's Built-in Icons:**

```lua
assets = {
  ['.settings'] = require('duvet.api.icon').get('settings'),
}
```

This makes use of Duvet's default icon library, using the "settings" icon for files with the `.settings` extension.

**4. Plugin Manager Asset with Custom Text:**

```lua
assets = {
  lazy = {
    name = 'Lazy',
    icon = 'https://...',
    tooltip = 'lazy.nvim Plugin Manager',
    type = 'plugin_manager',
    text = function(opts) -- Dynamic text
      return 'Managing plugins in ' .. opts.name
    end,
  },
}
```

Here, we define a custom asset for the `lazy.nvim` plugin manager, setting its name, icon, tooltip, type, and dynamic text.

**5. Overriding Tooltip and Text, Keeping Default Icon:**

```lua
assets = {
  lua = {
    tooltip = '.lua file',     -- Just change the tooltip
    text = 'Writing Lua Code', -- Override the text
  },
}
```

This example only modifies the tooltip and text for Lua files, keeping Duvet's default icon.

## 🧰 Overriding Defaults

Duvet provides special keys to define assets for generic situations:

- `['Duvet.new']`: Asset for a new, empty buffer when Neovim starts without file arguments, when both filetype and filename are empty.
- `['Duvet.unknown']`: Asset when the filetype is not detected/defined in Duvet.
- `['Duvet.override']`: This key overrides *all* existing icons, applying the specified asset everywhere.

**Example of Default Overrides:**

```lua
assets = {
  ['Duvet.new'] = 'default_file_icon',
  ['Duvet.unknown'] = 'question_mark_icon',
  ['Duvet.override'] = 'my_brand_icon',
}
```

## 💡 Tip

Sometimes, filetypes aren't automatically recognized by Neovim based on filename or extension alone. Use `vim.filetype.add` to help the editor identify them:

```lua
vim.filetype.add {
  pattern = {
    ['.*/waybar/config'] = 'jsonc',    -- Recognize waybar config files as jsonc
    ['.*/hypr/.*%.conf'] = 'hyprlang', -- Hyprland configs as hyprlang
    -- ... add more custom patterns
  },
}
```
