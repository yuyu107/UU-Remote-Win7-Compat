# UU Remote Windows 7 Compatibility Patch (Unofficial)

Community research utility to test the **client-side OS-version checks** that prevent Windows 7 SP1 x64 from initiating remote sessions in certain UU Remote `GameViewer.exe` builds.

**Not affiliated with or endorsed by NetEase or UU Remote.** This repository contains scripts and documentation only; it never distributes any proprietary UU Remote binary.

## Observed results

A Windows 7 SP1 x64 user successfully used the normal remote session's video, keyboard, mouse, audio, fullscreen and quality controls after applying the patch. The cloud-PC entry point proceeded to its queue instead of showing the Windows 7 block. **The full cloud-PC session has not been independently verified.** Two known executable builds passed offline patch-and-restore tests. Future builds are not guaranteed.

## Usage

1. Fully quit UU Remote and any attached debugger.
2. Drag the installed **64-bit** `GameViewer.exe` onto `Check_Win7.cmd`.
3. If appropriate, drag it onto `Apply_Win7.cmd`; keep the generated `GameViewer.exe.Win7Original.bak`.
4. Restart UU Remote and verify the functionality you need.
5. Quit the client and use `Restore_Win7.cmd` to revert from the verified original backup.

These Windows 7 launchers use Windows Script Host, `certutil.exe`, MSXML6 and ADODB; no Python or PowerShell installation is necessary. The Python script is an optional reference/test implementation.

The tool searches unique code signatures inside the `.text` section and checks file state rather than applying hard-coded offsets. Unknown matching builds require explicit confirmation; ambiguous builds are rejected.

**Warning:** Patching invalidates the original binary's digital signature, and updates/integrity checks may undo or reject the change. Use only on software copies you are legally entitled to modify. This project does not alter accounts, authentication, queueing or billing.

For details, see the [Chinese README](README.md) and [technical notes](docs/TECHNICAL.md). The project's code is MIT-licensed; UU Remote binaries and trademarks are not covered.
