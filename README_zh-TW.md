# Gemini Delegate Skill

> **狀態(2026-07):legacy 通道,gemini 後端已 fail-closed。** 舊版
> Gemini CLI 路徑自 2026-06-18 起棄用——Google 移除了消費者/個人層級的
> CLI 認證,此後非互動式 CLI 會**靜默輸出偽代碼**而非真正執行;wrapper
> 現在會直接拒絕執行它(覆寫:`GEMINI_DEPRECATED_OVERRIDE=1`)。`agy`
> (Antigravity CLI)後端在此仍可用,但持續維護、有實證背書的
> Antigravity 通道是
> [**antigravity-delegate**](https://github.com/WenyuChiou/antigravity-delegate)
> (2026-07-11 通過預註冊 k=5 可靠性閘門後晉升)。本 repo 保留作為課程
> 教材與 agy-via-gemini-delegate 的歷史紀錄。
>
> [English](README.md)

`gemini-delegate` 是面向 Claude 的 skill，用來把大量脈絡整理、長文草稿、英文或中英文 / CJK 寫作，以及第二意見審閱，委派給 Google Antigravity CLI (`agy`) 或舊版 Gemini CLI。

> 本專案屬於 [**agentic AI learning roadmap**](https://github.com/WenyuChiou/awesome-agentic-ai-zh)，一套 7 階段的 agentic AI 學習路線，涵蓋 zh-TW、zh-CN、English。本 skill 對應 Lesson 13 (Multi-LLM Delegation)。

## 為什麼需要這個 Skill

Claude 的工作脈絡有限，有些任務即使 Claude 能做，也不是最有效率的選擇。常見狀況有兩種：

- **長篇輸入不容易完整放入脈絡。** 當你需要摘要、比較、改寫多個大型來源檔案時，Gemini 系列模型的大脈絡可以一次讀完整體，不必讓 Claude 分段拼接。
- **CJK / 雙語長文需要更自然的語感。** 對長篇繁體中文或中英文改寫，Gemini 常能產生較自然的節奏。這是社群使用觀察，不是官方 benchmark，但足以讓工作流程值得被結構化。

把這些任務交給 `agy` 或舊版 Gemini，可以讓 Claude 專注在判斷、術語審核、事實查核，以及最後是否發布。

**適合使用本 skill 的情境：**

- 來源材料超過 Claude 舒適的工作脈絡
- 需要長篇繁體中文或雙語寫作
- 需要對長文件做 reviewer-style 第二意見
- 需要對齊翻譯內容中的術語
- 需要從多個來源整理 release notes、FAQ 或摘要

**不適合使用本 skill 的情境：**

- 大量程式碼產生或重構，請改用 `codex-delegate`
- 架構或安全審查，應留在 Claude
- 輸入本來就能放進 Claude 脈絡，而且品質比吞吐量更重要
- 事實準確性比草稿流暢度更重要，因為發布前仍需 Claude 審核

## 定位

這個 skill **不是** `codex-delegate` 的 Gemini 版本。它的工作不同：

- 將大型來源材料摘要成英文或繁體中文
- 跨多檔案整合重點
- 草擬英文、雙語或 CJK 面向的內容
- 對長文件做 reviewer-style 第二意見審閱
- 對齊翻譯內容中的術語

它不適合用於大量程式碼產生或架構工作。

## 核心流程

1. Claude 準備 context file，列出來源路徑、輸出路徑、語言與限制。
2. Claude 啟動 wrapper，wrapper 會自動偵測 `agy` 或舊版 `gemini`。
3. Wrapper 可在執行後驗證必要輸出檔案是否存在。
4. Claude 在發布前進行事實、術語與語氣審核。

委派模型可以產生有用草稿，但是否可發布仍由 Claude 決定。

## 專案結構

```text
gemini-delegate-skill/
├── README.md
├── README_zh-TW.md
├── scripts/
│   ├── run_gemini.sh
│   └── run_gemini.ps1
├── skills/
│   └── gemini-delegate/
│       ├── SKILL.md
│       └── references/
│           ├── wrapper.md
│           ├── delegation-targets.md
│           ├── output-contract.md
│           ├── review-checklist.md
│           ├── task-template.md
│           └── examples.md
└── tests/
    └── test_wrappers.py
```

## 測試

```bash
python -m pytest tests/ -q
```

目前 wrapper 測試涵蓋：

- success path 的 `result.json` 產生
- 驗證失敗回報 (`verify_failed`)
- `AGY_PATH` 與 `GEMINI_PATH` 的後端選擇

## 安裝

**1. 透過 [`ai-research-skills` Claude Code marketplace](https://github.com/WenyuChiou/ai-research-skills) 安裝 skill：**

```bash
claude plugin marketplace add WenyuChiou/ai-research-skills
claude plugin install gemini-delegate@ai-research-skills
```

預設 scope 是 `user`，也就是此 OS 帳號的所有專案。若只要安裝到目前專案，加入 `--scope project`。

**2. 安裝支援的後端。建議優先使用 Antigravity CLI (`agy`)：**

```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
agy --version
```

舊版 Gemini CLI fallback 自 **2026-06-18 起 fail-closed**：wrapper 會拒絕
呼叫 `gemini` 後端並以 exit 1 結束，因為被停用的消費者層級會讓非互動式
CLI 靜默輸出偽代碼。已確認自身層級仍可用的企業 / Cloud 使用者，必須明確
opt-in：

```bash
npm install -g @google/gemini-cli
gemini --version
GEMINI_DEPRECATED_OVERRIDE=1 bash scripts/run_gemini.sh --prompt "..."
```

也可以指定 wrapper 使用的二進位檔：

```bash
export AGY_PATH=/path/to/agy
export GEMINI_PATH=/path/to/gemini
```

偵測順序是 `AGY_PATH`、`GEMINI_PATH`、PATH 上的 `agy`，最後是 PATH 上的 `gemini`。

## 從 Gemini CLI 遷移

Gemini CLI 自 2026-06-18 起已不再支援 free/Pro/Ultra 個人使用者。Wrapper 會先自動偵測 `agy`;舊版 Gemini CLI 路徑已 fail-closed(FATAL + exit 1),已確認層級仍可用的企業使用者需明確設定 `GEMINI_DEPRECATED_OVERRIDE=1` 才能使用。既有 wrapper 指令、檔名，以及 `.ai/gemini_task_*.md` 任務 brief 慣例都不需要更改。若要強制使用特定 Antigravity CLI，請設定 `AGY_PATH`。

## License

MIT
