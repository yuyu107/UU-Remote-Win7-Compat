# UU Remote Win7 Compat v3.0.0 — 首个公开发布版本

这是**非官方社区兼容性补丁**。面向 Windows 7 SP1 x64，通过本地系统版本检查适配，使部分 UU 远程客户端能够发起远控；同时探索云电脑入口的兼容性。

**本版亮点**
- 按 `.text` 内的两处唯一特征自动定位，不再依赖单一固定偏移。
- Windows 7 自带 CMD + VBScript 即可使用，无需 Python 或 PowerShell。
- `Check / Apply / Restore`、自动备份、SHA-256 验证、旧版 v1/v2 升级识别。
- 两份已知 EXE 构建离线回归测试通过；用户实测普通远控画面、输入、声音、全屏和画质调整可用；云电脑已可进入排队（尚未完整验证云电脑会话）。

**安装方法**：退出 UU 远程和调试器；把安装目录里的 `GameViewer.exe` 依次拖到 `Check_Win7.cmd`、`Apply_Win7.cmd`；重启测试。若需要恢复，使用 `Restore_Win7.cmd`。请保留 `.Win7Original.bak`。

**已知限制**：仅 64 位目标程序；未知版本不保证兼容；修改 EXE 会导致数字签名失效，且可能被官方更新覆盖。仓库和发布包不含任何官方二进制文件。
