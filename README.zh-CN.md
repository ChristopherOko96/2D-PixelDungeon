# Basement Run：Codex Studio 集成

这是现有的 Godot 地牢游戏项目，而不是未配置的空白模板。
当前使用 Godot 4.7.2、GDScript、最多四名玩家和 32×32 像素素材。

Codex 适配基于
[chuanglibs/Claude-Code-Game-Studios-Codex](https://github.com/chuanglibs/Claude-Code-Game-Studios-Codex)
的 `d202f58a3977a1ffaddd660ad782724a4392e012`，共享工作流最初来自
[Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)。
保留原有 MIT 许可证和版权声明。

适配器从本项目较新的源文件生成 **74 个工作流入口和 49 个角色**，保留全部
14 份规则的原始路径模式。没有用较旧模板覆盖现有游戏代码、配置或设计文档。

在 Windows 双击 `Codex-Studio.cmd`，或在项目目录运行：

```powershell
./scripts/Studio.ps1 Doctor
./scripts/Studio.ps1 Open
./scripts/Studio.ps1 Check
```

在 Codex 对话框输入 `$studio-help`。无需重新运行新游戏入门流程或安装 Claude Code。
模型、权限和全局配置保留原有设置。共享配置以 project.yaml 及其本地覆盖规则为准。
Claude hooks 不会自动成为 Codex hooks；手动检查不执行 Git 提交或推送。

详细说明：[Codex guide](docs/codex/README.md)、[运行规则](docs/codex/runtime.md)、
[验证报告](docs/codex/SETUP-REPORT.de.md)。
