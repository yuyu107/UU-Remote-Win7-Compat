# UU Remote Windows 7 Compatibility Patch (Unofficial)

Community research utility to test the **client-side OS-version checks** that prevent Windows 7 SP1 x64 from initiating remote sessions in certain UU Remote `GameViewer.exe` builds.

**Not affiliated with or endorsed by NetEase or UU Remote.** This repository contains scripts and documentation only; it never distributes any proprietary UU Remote binary.

## Windows 7 compatibility — please check your system architecture

| Operating system | Status | Reason |
| --- | --- | --- |
| **Windows 7 SP1 x64 (64-bit)** | ✅ Tested core remote-control features | The patch targets recognized 64-bit client builds |
| **Windows 7 SP1 x86 (32-bit)** | ❌ **Unsupported** | The tested installation contains 64-bit main and service executables; no complete x86 remote-control build was found |

**The 32-bit issue is not just an OS-version block.** On Windows 7 SP1 x86, the installer failed to start its service with Windows error **216** (executable machine-type mismatch). Windows Service Control Manager event **7000** confirmed that the installed `GameViewerService.exe` was an AMD64 executable. The desktop shortcut's `GameViewer.exe` also could not launch. An inventory of the installed files found x64 main, service, server, streaming and supporting binaries; the few x86 utilities are not a usable 32-bit client.

Unlike the Windows 7 x64 local version check bypass, patching a few bytes cannot make a 64-bit executable run on 32-bit Windows. **This project supports x64 client builds only and does not provide or plan an x86 port.** This conclusion applies to the tested installation package; it does not establish whether unrelated or historic x86 builds ever existed.

## Observed results

A Windows 7 SP1 x64 user successfully used the normal remote session's video, keyboard, mouse, audio, fullscreen and quality controls after applying the patch. The cloud-PC entry point proceeded to its queue instead of showing the Windows 7 block. **The full cloud-PC session has not been independently verified.** Two known executable builds passed offline patch-and-restore tests. Future builds are not guaranteed.

## Windows 7: an OS-version block is not proof of an incompatible API

**In the tested UU Remote builds, the Windows 7 warning was triggered by an explicit client-side OS-version check before starting a remote session, not by a failure after calling an unsupported Windows API.** Using x64dbg to change that check's result allowed a real Windows 7 SP1 x64 remote session: video, keyboard, mouse, scroll wheel, audio, fullscreen, and quality controls worked. The standalone compatibility patch was also tested successfully on another Windows 7 machine.

This demonstrates that **the tested core remote-control features are not inherently impossible on Windows 7**. However, this is **not** evidence that the entire product has no newer Windows API dependencies. The separate uuyc-mux.exe component directly imports Windows 8+ functions such as WaitOnAddress, WakeByAddressSingle, WakeByAddressAll, and GetSystemTimePreciseAsFileTime. Their feature-path impact has not been fully determined. The main executable and streamer library had no such direct imports in the limited list checked, but dynamic or indirect dependencies remain possible. Windows 7 supports Direct3D 11 and DXGI 1.1; later graphics interfaces and optional drivers may still require newer Windows versions.

Cloud PC was only verified to reach the queue after bypassing the local block, **not** to complete a session. Other features, GPUs, long-term stability, and future builds remain unverified. This project documents **observed compatibility of particular functions in particular builds**, not complete or official Windows 7 support.

Microsoft references: [Direct3D 11](https://learn.microsoft.com/en-us/windows/win32/direct3d11), [WaitOnAddress](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitonaddress), [GetSystemTimePreciseAsFileTime](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getsystemtimepreciseasfiletime).

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
