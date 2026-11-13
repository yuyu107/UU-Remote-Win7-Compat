# UU Remote Windows 7 Compatibility Patch

**非官方的网易 UU 远程 Windows 7 发起端兼容性实验工具。** 通过定位并调整客户端本地的系统版本检查，使 Windows 7 SP1 x64 能尝试使用原本被入口限制的远控功能。

> [!IMPORTANT]
> 这是社区兼容性项目，**不是网易 UU 官方补丁**。项目不附带 UU 远程安装包、`GameViewer.exe` 或其他官方二进制文件；请自行合法获取客户端。补丁会使被修改 EXE 的数字签名失效，使用前务必备份。

## Windows 7 兼容性（请先确认系统位数）

| 系统 | 当前补丁支持情况 | 原因 |
| --- | --- | --- |
| **Windows 7 SP1 64 位（x64）** | ✅ 已实机验证普通远控功能 | 可对已识别的 x64 客户端解除本地版本检查 |
| **Windows 7 SP1 32 位（x86）** | ❌ **不支持，且本项目不提供 x86 移植** | 当前测试安装包的主程序和服务本身就是 64 位，32 位系统无法执行 |

**特别提醒：Windows 7 32 位不是“打完补丁就能用”。** 在 Win7 SP1 x86 实测中，安装器弹出“启动服务失败，错误码：216”；Windows 事件日志（Service Control Manager，事件 7000）证实安装的 `GameViewerService.exe` 为 AMD64 架构，无法在 x86 系统启动。桌面快捷方式指向的 `GameViewer.exe` 也报“需要 x86 (32 位) 或 x64 (64 位)版本”的不兼容提示。扫描实际安装目录后，`GameViewer.exe`、`GameViewerService.exe`、`GameViewerServer.exe` 和 `streamer.dll` 等核心组件均为 x64；虽然有少数 x86 辅助组件，但并没有发现能组成完整远控客户端的 x86 核心。

**这与 Windows 7 x64 的主动版本限制完全不同：** x64 是程序能够运行却被本地版本检测挡住；x86 是当前安装包实际提供的二进制架构不兼容。修改版本判断、使用 VXKex 或强行跳过安装报错，都不能将 x64 程序转换成 x86 程序。**本项目只针对 x64 客户端，不计划继续研究 32 位适配。**

## 为什么 Win7 会被拦截？版本限制与 API 兼容性是两回事

**已实测确认：在本项目测试的 UU 远程客户端版本中，“Windows 7 设备暂不支持发起远控”是由客户端主动执行的本地系统版本判断触发的，并不是远控引擎调用某个 Win7 不存在的 API 后才出现的错误。**

研究过程：在 Windows 7 SP1 x64 上点击发起远控，程序在开始连接前立即弹出限制提示。通过 x64dbg 追踪到发起端版本检查，Win7 上检查结果为不通过；临时修改判断结果后，成功建立真实远控连接，并实测画面、键盘、鼠标、滚轮、远程声音、全屏和画质调节均正常。后续 v3 兼容补丁也已在 Windows 7 实体机上验证相关功能可用。

**这证明：至少对已测试的客户端构建，上述基础远控功能并非技术上无法在 Win7 使用，原先的入口限制是实际存在的。**

但是，**不能据此声称 UU 远程全部组件都不依赖新版 Windows API**：

- 主程序 GameViewer.exe 和 streamer.dll 的静态检查未在指定的 Win8+ API 清单中发现相应直接导入；这不等于排除了动态加载或间接调用。
- 安装目录中的其他组件，例如 uuyc-mux.exe，确实直接导入 WaitOnAddress、WakeByAddressSingle、WakeByAddressAll 和 GetSystemTimePreciseAsFileTime。这些函数最低支持 Windows 8。尚未确认这些依赖在具体功能中何时加载，不能凭它们推断普通远控必定不能运行。
- Windows 7 本身支持 Direct3D 11 和 DXGI 1.1，因此“采用 D3D11 / DXGI”也不能直接证明必须使用 Windows 8/10；但较新的图形接口、驱动及其他功能仍可能不受支持。
- 云电脑目前只验证成功解除排队前的拦截、进入队列；完整云电脑会话、未测试功能、其他显卡和后续客户端版本仍不能保证。

**准确结论是：被主动版本检查阻止的部分功能，经实测可以在 Win7 上正常运行；并非“整个客户端完全兼容 Win7”，也不代表网易官方继续支持 Win7。**

参考微软文档：[Direct3D 11 最低支持 Windows 7](https://learn.microsoft.com/en-us/windows/win32/direct3d11)、[WaitOnAddress 最低支持 Windows 8](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitonaddress)、[GetSystemTimePreciseAsFileTime 最低支持 Windows 8](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getsystemtimepreciseasfiletime)。详见 [技术说明](docs/TECHNICAL.md)。

## 已验证的进展

| 项目 | 结果 | 说明 |
| --- | --- | --- |
| Windows 7 SP1 x64 启动 UU 远程 | ✅ 实测 | 用户环境为 Windows 7 SP1 x64 |
| 普通远控：显示画面 | ✅ 实测 | 被控端画面正常 |
| 键盘、鼠标、滚轮 | ✅ 实测 | 各项输入正常 |
| 远程声音 | ✅ 实测 | 音频正常 |
| 全屏及画质调整 | ✅ 实测 | 可用 |
| 云电脑入口的 Win7 拦截 | ✅ 实测解除 | 已能进入排队；**不等于已验证云电脑会话完整可用** |
| 不同 EXE 构建定位 | ✅ 已验证 | 三份已登记构建；最新构建已核对原版和修补版的精确差异 |
| 所有未来版本均支持 | ❌ 不保证 | 新版可能改变代码与兼容条件 |

这些结论来自指定客户端版本的实际反馈，**不代表官方支持 Windows 7，也不保证所有 GPU、驱动或网络环境能工作**。

## 下载与运行

下载并解压 `UU-Remote-Win7-Compat_v3.1.0.zip`（**v3.1.0 正式包已制作完成，待上传至 GitHub Releases**；GitHub Releases 当前仍提供 v3.0.0）。无需安装 Python 或 PowerShell；在 Windows 7 上使用内置 `cscript.exe`、`certutil.exe`、MSXML6 和 ADODB。

1. 完全退出 UU 远程（包括托盘进程），并关闭 x64dbg 等可能占用 EXE 的程序。
2. 找到安装目录内**真正的** `GameViewer.exe`（64 位），**拖到 `Check_Win7.cmd` 上**，先看 `State`、`SHA256` 和两项 `Signature`。
3. 如果显示 `ORIGINAL` 或 `V1`，再将同一 EXE 拖到 `Apply_Win7.cmd`；如果已经是 `V2`，无需重复修改。
4. 看到 `SUCCESS` 后重新启动 UU 远程，测试连接。原文件的备份位于 `GameViewer.exe.Win7Original.bak`。
5. 如需恢复，退出客户端后将同一 EXE 拖到 `Restore_Win7.cmd`，使用经验证的备份还原。

**注意：** 工具的检测、修补、恢复及报错提示已采用简体中文（同时保留 `State`、`SHA256` 等便于反馈的字段名）。对于 SHA-256 尚未登记但代码结构唯一匹配的构建，修补时会弹出中文「是 / 否」确认框，**默认选择否，无需输入随机哈希字符串**。此时仅说明**局部代码结构匹配**，不代表已经验证真实兼容性；无法唯一定位时仍拒绝修改。安装位置无写入权限时可能需要管理员权限。

### 状态说明

- `ORIGINAL`：对应检查点尚未修改。
- `V1`：仅普通远控入口的检查点已修改。
- `V2`：两个检查点均已修改（v3 工具输出的完整补丁状态）。
- `UNSUPPORTED`：未识别到安全的唯一修改位置；**不要强行套用旧偏移**。

## 技术原理

通过对 `GameViewer.exe` 的 `.text` 代码节进行特征搜索与状态校验，定位两处本地版本检查指令，而不是盲目写入固定文件偏移。

```diff
- 84 C0      ; test al, al
+ 0C 01      ; or al, 1

- 32 C0      ; xor al, al
+ B0 01      ; mov al, 1
```

合计修改 **4 字节**，用于本地操作系统版本分支。不修改服务器端系统、账户认证、网络协议或云电脑排队/计费逻辑。已知构建按 SHA-256 和字节结构校验；未知构建只有在特征唯一、上下文匹配且用户在确认框中明确选择「是」时才进入实验流程。安装前后会进行备份与可逆性检查。

更详细的原理与已知构建哈希见 [技术与版本说明](docs/TECHNICAL.md)。

## 文件结构

| 文件 | 用途 |
| --- | --- |
| `Check_Win7.cmd` | 只读检查兼容性特征和补丁状态 |
| `Apply_Win7.cmd` | 安装补丁，自动备份和核验 |
| `Restore_Win7.cmd` | 从已校验的原版备份恢复 |
| `UU_Win7_MultiVersion.vbs` | Windows 7 默认执行核心，无第三方运行时依赖 |
| `UU_Win7_MultiVersion.py` | 可选的跨平台参考与离线测试实现（Python 3） |
| `tests/` | 采用合成 PE 样本的识别单元测试；**不包含官方 EXE** |

## 注意事项与责任范围

- 修改厂商签名过的 EXE 会使**原数字签名失效**，可能触发自动更新覆盖、完整性校验或安全软件告警。
- 退出客户端再操作；不要在运行中替换文件。保留独立原版备份，**不要误删** `.Win7Original.bak`。
- 只在您有权修改、使用的程序副本上实验，遵守适用法律与服务条款；后续的联网和付费功能仍须遵守服务规则。
- **不提供** UU 原版 EXE、DLL、安装包、账号、付费权限绕过或服务器功能修改。
- 请勿把含登录信息、设备 ID、远控码或个人资料的完整日志和截图直接发到公开 Issue。
- 本工具为兼容性研究性质，作者与贡献者不保证适用于任何特定环境，详见 `LICENSE`。

## 反馈与贡献

出现问题时先运行 `Check_Win7.cmd`，在 Issue 中提供系统架构、**EXE 的 SHA-256**、`State`、两项匹配数量、报错原文以及是否使用过旧补丁。**不要将网易 UU 官方二进制文件直接附加在公开 Issue 中。**

参考 [反馈指南](CONTRIBUTING.md)、[更新记录](CHANGELOG.md) 和 [英文说明](README_EN.md)。

## 许可与声明

此仓库中的自编写补丁脚本与文档采用 [MIT License](LICENSE)。网易、UU 远程及相关商标和官方软件归各自权利人所有；本项目与网易 UU 无关联或官方背书。
