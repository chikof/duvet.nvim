# 💻 Special Environments

## 🔌 Duvet's socket

Duvet publishes your activity to the Duvet app over a local socket. The plugin looks for it at:

- **Linux/macOS/FreeBSD:** `duvet-ipc.sock` inside the first of `XDG_RUNTIME_DIR`, `TMPDIR`, `TMP`, `TEMP` that is set, falling back to `/tmp`.
- **Windows:** the named pipe `\\.\pipe\duvet-ipc`.

To use a different location, set `advanced.duvet.pipe_paths` to a list of absolute paths.

## 🐧 Running inside WSL

WSL doesn't expose Windows named pipes, which is what the Duvet app listens on when it runs on Windows. To work around that, use `socat` and `npiperelay`.
This method is based on [this gist](https://gist.github.com/mousebyte/af45cbecaf0028ea78d0c882c477644a#aliasing-nvim).

1. **Install `socat`** in WSL: `sudo apt install socat`
2. **Get `npiperelay.exe`** from [here](https://github.com/jstarks/npiperelay/releases) and place it in a path accessible from WSL, preferably add it to PATH.
3. **Add this `nvim` alias** in your `.bashrc`, `.zshrc`, etc.:

   ```sh
   nvim() {
        if ! pidof socat > /dev/null 2>&1; then
            [ -e /tmp/duvet-ipc.sock ] && rm -f /tmp/duvet-ipc.sock
            socat UNIX-LISTEN:/tmp/duvet-ipc.sock,fork \
                EXEC:"npiperelay.exe //./pipe/duvet-ipc" 2>/dev/null &
        fi

        command nvim "$@"
   }
   ```

   > Do note that you must either add the path to npiperelay to your Windows PATH, or specify an absolute path to it inside `EXEC` (e.g. `/mnt/c/.../npiperelay.exe`).
   > Always launch Neovim using this alias in WSL.
   > If `XDG_RUNTIME_DIR` or `TMPDIR` is set in WSL, either put the socket there or point `advanced.duvet.pipe_paths` at `/tmp/duvet-ipc.sock`.
