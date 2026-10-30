# GitHub 与 CurseForge 自动发布

仓库：<https://github.com/zhufei1000/QFXAddonManager>。CurseForge 项目 ID 固定为 **1773703**，主包 TOC 同步记录此 ID。

## 首次配置

在仓库 Settings → Secrets and variables → Actions 中新增 repository secret：

- Name：`CF_API_KEY`
- Secret：你在 CurseForge Authors → API Tokens 创建的上传密钥。

直达设置：<https://github.com/zhufei1000/QFXAddonManager/settings/secrets/actions/new>。密钥只保存在 GitHub Secrets，不写进代码、发布包或日志。GitHub Release 使用工作流自带的 `GITHUB_TOKEN`，无需额外 GitHub 密钥。

## 日常提交与正式发布

普通 `main` 提交、PR 和手动运行工作流只检查与打包，不自动改版本，也不上传 CurseForge。Actions 的 addon-package artifact 可用于本地验证。

正式发布前：

1. 统一修改主包及五个子包的 TOC Version，并同步主包 README.txt 首行。
2. 新增 `docs/RELEASE_版本号.md`，记录本次正式版本说明；文档不进入运行 ZIP。
3. 提交代码，等 Build and release 的 build 检查通过。
4. 在同一个已提交版本创建并推送 `vX.Y.Z` 标签。例如将来正式发布 1.1.12 时：

```powershell
git tag -a v1.1.12 -m "QFXAddonManager 1.1.12"
git push origin v1.1.12
```

本次建仓保留现有 1.1.11，不推送正式版本标签，不重复上传已经人工提交过的版本。

## 发布流程

工作流先检查六包版本、标签、CurseForge 项目 ID、词典、所有 Lua 语法及三语 UI 行为；再调用唯一构建器 `tools/build_addon.py`。ZIP 根层包含主包、五子包与 QFX_SharedMedia，素材根同名 TOC 仅在 ZIP 中生成。校验每个顶层同名 TOC、CRC、完整清单和逐文件字节，生成 SHA256。

仅版本标签触发 publish：先确认 `CF_API_KEY` 已配置，建立含 ZIP 与校验文件的 GitHub 草稿 Release，调用 CurseForge 官方上传 API 上传到项目 1773703，最后保存上传文件 ID 回执并将 GitHub Release 公开。游戏版本名称由主包 Interface 列表换算，不把 Interface 数字误当成 CurseForge 游戏版本 ID。

如果缺少密钥，publish 明确失败，既不上传也不假报成功。CurseForge 接收文件后仍按平台流程审核；API 返回文件 ID 不等于已通过审核。

成功回执 `curseforge-upload.json` 随 GitHub Release 保存，重复运行会校验回执并跳过重复上传。失败留下草稿时，需要先在 CurseForge 检查文件是否已被接收；不要直接反复上传同一版本。

## 本地验证

```powershell
python tools/release.py check
python -m unittest discover -s tests -v
python tools/release.py prepare --output-dir dist/local
```

本地工具需要 Python 3 与 Lua 5.4；不需要 CurseForge 密钥即可验证和打包。`prepare` 拒绝覆盖已有 ZIP。开发备份、日志、客户端文件、历史包、API 源码快照和个人配置不进入 Git 仓库。

依据：GitHub Actions 工作流与 Secrets 官方文档；CurseForge Upload API：<https://support.curseforge.com/support/solutions/articles/9000197321>。
