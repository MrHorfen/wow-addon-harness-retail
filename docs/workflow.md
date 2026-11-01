# Workflow / 工作流

> **EN TL;DR** — Read the API map, change one layer, add a behavior test, run
> the suite, run the gate, package, verify in game.
>
> **中文摘要** — 先查 API 映射，一次只改一层，补一条行为测试，跑测试与门禁，
> 打包，再进游戏验证。

## English

### Setup

```bash
python -m pip install lupa
```

Python 3.11+ is recommended. The harness uses `lupa` to embed Lua 5.5.

### The loop

```bash
# 1. Behavior tests
python -m unittest discover -s tests -t . -v

# 2. Repository gate
python tools/gate.py

# 3. Build an installable folder
python tools/package.py --out dist
```

### Continuous integration

`docs/ci.yml` contains a ready-to-use GitHub Actions workflow. Copy it to
`.github/workflows/ci.yml` and push with a token that has the `workflow` scope.

### Adding a feature

1. Find the API in `docs/api-map.md`. If it is not there, verify it on the real
   client before writing code.
2. Decide the layer with the three questions in `docs/architecture.md`.
3. If the API shape is surprising, add one normalized function to
   `Core/Env.lua` first. Do not put raw API calls in the business layer.
4. Change the data layer, then the UI. Keep UI free of purchase/list primitives.
5. Add a behavior test: call the function, fire the event, read the result.
6. Run the suite, the gate, and the package.

### Adding a file

- Add it to `AHProbe.toc` in dependency order.
- Add it to the expected list in `tests/test_retail.py`.
- The package script follows the toc automatically.

### Adding a capability

When you need an API that may not exist in every build:

1. Add its dotted path to `Env.CAPS`.
2. Check it with `Env.Has(path)` before calling.
3. Return an explicit failure from the adapter when it is missing.
4. Add a test that removes the API from the mock and asserts the failure.

Do not silently pretend the call succeeded.

### Classic Era support

This repository is Retail-only. If you need Classic Era 1.15.x or a dual-client
adapter, use the companion repository `wow-addon-harness-classic` instead of
adding legacy branches here. Keeping the two trees separate is deliberate.

### Release checklist

- [ ] The test suite passes.
- [ ] Gate passes.
- [ ] The package builds.
- [ ] The package loads in Retail.
- [ ] `/ahprobe` opens the panel and `Scan` updates the count.
- [ ] No new absolute paths, account names, tokens, logs, or SavedVariables.

## 中文

### 环境

```bash
python -m pip install lupa
```

建议 Python 3.11+。Harness 用 `lupa` 内嵌 Lua 5.5。

### 日常闭环

```bash
# 1. 行为测试
python -m unittest discover -s tests -t . -v

# 2. 仓库门禁
python tools/gate.py

# 3. 打安装包
python tools/package.py --out dist
```

### 持续集成

`docs/ci.yml` 是一份可直接使用的 GitHub Actions 工作流。复制到
`.github/workflows/ci.yml`，用带 `workflow` 权限的 token 推送即可启用。

### 加一个功能

1. 在 `docs/api-map.md` 找到 API；表里没有，就先去真机核实，再写代码。
2. 用 `docs/architecture.md` 的三问判断落层。
3. 如果 API 形状出乎意料，先在 `Core/Env.lua` 加一个归一化函数，不要把原始调用
   写进业务层。
4. 先改数据层，再改 UI；UI 不持有买入/上架原语。
5. 补一条行为测试：调用函数、触发事件、读回结果。
6. 跑测试、门禁和打包。

### 新增文件

- 按依赖顺序加入 `AHProbe.toc`。
- 同步 `tests/test_retail.py` 的期望清单。
- 打包脚本自动跟随 toc，不需要另改。

### 新增能力

当你需要一个“不一定每个版本都有”的 API：

1. 把它的点分路径加进 `Env.CAPS`。
2. 调用前用 `Env.Has(path)` 判断。
3. 缺失时由适配层返回显式失败。
4. 加一条测试：从 mock 里删掉该 API，断言失败路径。

不要假装调用成功了。

### 经典怀旧支持

本仓只做正式服。如果需要 Classic Era 1.15.x 或双客户端适配，请使用配套仓库
`wow-addon-harness-classic`，不要在这里加老 API 分支。两个仓库分开是刻意的。

### 发布前检查

- [ ] 测试通过。
- [ ] 门禁通过。
- [ ] 包能打出来。
- [ ] 包能在正式服加载。
- [ ] `/ahprobe` 能打开面板，`Scan` 能更新数量。
- [ ] 没有新增绝对路径、账号名、token、日志或存档。
