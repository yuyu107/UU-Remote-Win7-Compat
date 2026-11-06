# 技术与兼容性记录

## 检查对象

本项目只修改 `GameViewer.exe` **64 位**程序中的两处本地操作系统版本判断，不修改客户端与服务器的认证、远控协议、云电脑排队或计费行为。

```text
入口检查：84 C0 (test al, al) → 0C 01 (or al, 1)
公共检查：32 C0 (xor al, al) → B0 01 (mov al, 1)
```

总计 4 字节。多个版本的固定文件偏移不同，因此 v3 只在 `.text` 节内搜索独立上下文锚点并要求唯一匹配，之后对原始/已补丁字节做状态校验。非登记构建需要显式人工确认。

## 32 位 Windows 7 的单独验证结论（不支持）

本项目不能用于 Windows 7 SP1 x86。研究过程中在 32 位 Win7 上运行当前测试的 UU 远程安装包，安装器报告 **“启动服务失败，错误码 216”**，桌面已生成的 `GameViewer.exe` 快捷方式也无法启动，并提示需要匹配 x86/x64 的程序版本。

只读诊断证据：

- `PROCESSOR_ARCHITECTURE=x86`，系统为 Windows 7 SP1 32 位。
- 安装器注册 `GameViewerService`，路径指向 `GameViewerService.exe`，PE 机器类型为 **AMD64 (0x8664)**；服务控制管理器记录 **Event ID 7000**，明确说明服务程序架构与系统不兼容。
- 对实际安装目录的 PE 文件盘点发现 `GameViewer.exe`、`GameViewerService.exe`、`GameViewerLauncher.exe`、`GameViewerServer.exe`、`streamer.dll` 等关键组件均是 x64。存在部分 x86 辅助文件（如卸载器、下载器），但并非完整的 32 位远控程序。

**与 64 位 Win7 的区别：** 在 Win7 x64 上，程序可执行而发起远控被版本检查拦截；在 Win7 x86 上，当前客户端主程序和服务的机器架构本身就与操作系统不匹配。既有的字节补丁不可能将 AMD64 二进制转换成 x86；也不应在 x86 系统上强制套用本项目补丁。

结论限定于所测试的安装包，不推断所有历史版本是否曾有 x86 构建。**项目范围明确为 Win7 x64，不提供或继续开发 x86 兼容补丁。**

## 为什么“Win7 不支持”不能直接归因于新版 API

### 动态验证

1. Windows 7 SP1 x64 上点击发起远控，连接开始之前立即出现“不支持”提示。
2. 用 x64dbg 命中发出 Win7 拦截信号的函数，追踪其调用者，并在版本检查返回后的条件判断处观察到 AL=0（不通过）。
3. 临时将检查结果改为通过后，连接流程继续，实际画面、键盘、鼠标、滚轮、音频、全屏及画质设置均正常。
4. 独立补丁在 Win7 实体机也取得成功；云电脑只证明能够跨过排队前拦截并进入队列。

因此，针对已测版本，**入口处存在明确的本地版本限制，而且普通远控已验证的功能并非由于 Win7 缺少 API 而无法使用**。这不代表其他路径都兼容。

### 静态依赖的边界

| 检查对象 | 已知检查结果 | 限制 |
| --- | --- | --- |
| GameViewer.exe | 指定的 Win8+ API 检查清单内未发现直接导入 | 无法排除动态获取函数及更高版本接口 |
| streamer.dll | 同一清单内未发现相应直接导入；涉及 D3D11、DXGI | Win7 支持 D3D11 和 DXGI 1.1，但不保证全部图形路径 |
| uuyc-mux.exe | 直接导入 WaitOnAddress、WakeByAddressSingle、WakeByAddressAll、GetSystemTimePreciseAsFileTime | 这些函数最低要求 Win8，仍未确定其是否属于基础远控必经路径 |
| 可选驱动及其他功能 | 有些组件可能有更高系统要求 | 未测试功能不能因基础远控可用就宣布兼容 |

**必须同时保留这两条结论：主动 OS 版本门槛已经动态验证；部分安装组件确实依赖新版 API。** 静态导入表不是所有运行时依赖的完整清单，不能据此断言“全客户端没有 Win8+ API”。

微软参考：[Direct3D 11](https://learn.microsoft.com/en-us/windows/win32/direct3d11)、[Windows 7 图形 API](https://learn.microsoft.com/en-us/windows/win32/direct3darticles/graphics-apis-in-windows-vista)、[WaitOnAddress](https://learn.microsoft.com/en-us/windows/win32/api/synchapi/nf-synchapi-waitonaddress)、[GetSystemTimePreciseAsFileTime](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getsystemtimepreciseasfiletime)。

## 已知构建（仅供校验，绝不提供这些 EXE）

| 构建 | 原版 SHA-256 | 字节大小 | 入口检查文件偏移 | 公共检查文件偏移 |
| --- | --- | ---: | --- | --- |
| A（较早包） | `ef7112e173cdc6d74735c50292cf9750082ce351cdea60dc068fc2b60f3aa92e` | 73,768,952 | `0x9B606E` | `0x19C4A35` |
| B（Win7 实测） | `8f1390b33bf003c543eab575aea2299d84e25a753ceb92faba751953844ef10a` | 73,772,024 | `0x9B617E` | `0x19C4E75` |

**表中是文件偏移而非 RVA。** 不可将其直接作为 x64dbg 断点地址。

## 验证层级

1. **离线**：A、B 两个构建都通过原版 → 完整补丁 → 完整恢复的逐字节校验，以及带有效备份的 V1 → V2 升级检查。
2. **实机**：构建 B 的 Win7 SP1 x64 用户实测普通远控画面、键鼠、远程音频、画质和全屏可用；V2 可进入云电脑排队。
3. **多版本**：用户随后确认 v3 在另一台 Windows 7 机器上能够解除限制，相关功能可用；尚未收集该机 EXE 的 SHA-256 及完整测试矩阵，因此不把该机计入“已登记构建”。
4. **未验证**：云电脑会话从排队结束到进入桌面的完整过程、其他 Win7 显卡驱动、所有更新版本及长时间稳定性。

## 校验与备份约束

- 校验可执行文件名、x64 PE32+ 结构和 `.text` 节范围。
- 两个独立代码锚点必须分别唯一出现；模糊/缺失则拒绝修改。
- SHA-256 已登记的文件状态需与对应代码字节一致，否则拒绝。
- 对未知构建即使匹配，也要求输入 `APPLY <哈希前 8 位>`；这仅是实验性适配。
- 修改前验证或生成 `.Win7Original.bak`，更新时验证其与当前文件为同一构建。
- 在暂存副本上操作，做状态与哈希复核，再替换原文件；失败时尝试自动恢复。
- 修改后的数字签名会失效，安装或自动更新可能恢复原始 EXE。

## 技术限制

静态特征匹配无法证明完整调用链或所有动态 API 兼容；反汇编可能因编译版本变化而失效。此项目是特定版本的社区兼容性实验，不构成对任意二进制或任意系统的兼容承诺。
