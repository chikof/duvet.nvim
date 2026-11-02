## ❓ FAQ

Some common questions about duvet.nvim that nobody asked, yet we answered anyway.

<details>
<summary><h4>What is the minimum required version of Neovim?</h4></summary>

Duvet is compatible with Neovim **0.6.0** or newer.

</details>

<details>
<summary><h4>Do I need to install Rust to use Duvet?</h4></summary>

No, you don't need Rust anymore.
Duvet will download the server binary for you.
If you'd rather build it yourself, check the [Build guide](./Build.md).

</details>

<details>
<summary><h4>How to see the logs?</h4></summary>

Duvet's notifications/messages/logs are controlled by the `DUVET_LOG_LEVEL` env var OR `log_level` configuration option. Usually, you want this value to be set to one of `off`, `error`, `warn`, `info`.

```lua
require('duvet').setup {
    log_level = '...' -- one of 'trace', 'debug', 'info', 'warn', 'error'
}
```

Where logs go depends on the presence of the `DUVET_LOG_FILE` environment variable.

</details>

<details>
<summary><h4>Logging for debugging</h4></summary>

```sh
DUVET_LOG_LEVEL="trace" DUVET_LOG_FILE="duvet.log" nvim
```

</details>

<details>
<summary><h4>Can I change the name shown in my presence?</h4></summary>

No. The displayed name is always *"Neovim"*.

</details>

<details>
<summary><h4>Why do I still see Duvet's server running in background, even after I've closed Neovim?</h4></summary>

That's intentional.
Duvet's server keeps running to maintain a single continuous connection to Duvet and avoid reconnecting too often.
This is especially useful if you restart Neovim a lot.
If you'd rather shut it down sooner, there's the `advanced.server.timeout` option.

</details>

<details>
<summary><h4>Is X plugin or X language supported?</h4></summary>

Duvet detects buffers mostly by filetype (and sometimes by filename).
Check the list of supported filetypes [here](https://github.com/vyfor/cord.nvim/blob/master/lua/cord/plugin/activity/mappings.lua).

If the language or plugin you use isn't found on the list, please [open an issue](https://github.com/vyfor/cord.nvim/issues/new/choose).

Just keep in mind:
- **Languages** that don't expose a clear filetype or filename need extra setup (see [this page](https://github.com/vyfor/cord.nvim/wiki/Assets#-tip)).
- **Plugins** need to override the buffer's `filetype`, otherwise Duvet won't be able to recognize them.

</details>
