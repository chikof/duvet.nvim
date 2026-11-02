# 🔧 Troubleshooting

## 🛠️ General Steps

1. Update duvet.nvim, make sure `:Duvet update` is also executed.
2. Make sure the Duvet app is running.
3. Enable logging. See [FAQ](./FAQ.md#q-logging-for-debugging).
4. Run `:checkhealth duvet` for a config check.
5. Make sure Duvet's IPC socket exists:

   - **Windows:** 
     ```pwsh
     Test-Path \\.\pipe\duvet-ipc
     ```

   - **Linux/macOS:**
     ```sh
     find /tmp ${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR} ${TMPDIR:+$TMPDIR} ${TMP:+$TMP} ${TEMP:+$TEMP} -type s -name 'duvet-ipc.sock' 2>/dev/null
     ```

   If you get nothing or "False", the pipe does not exist in the expected location.

## 🔁 Plugin Not Loaded (lazy.nvim)

Add `event = 'VeryLazy'` to the plugin spec.

## ⏱️ Presence Timer Stuck at 00:00

Your system clock might be off. Sync your clock with NTP.

## 🔒 EACCES: Permission Denied

```sh
chmod +x ~/.local/share/nvim/duvet/bin/duvet
```

## ❓ Still Having Trouble?

If nothing above works:

1. Check the [FAQ](./FAQ.md) for other common questions.
2. Look through [existing GitHub issues](https://github.com/chikof/duvet.nvim/issues).
3. [Open a new issue](https://github.com/chikof/duvet.nvim/issues/new/choose).
   Be clear and include as much detail as possible.

