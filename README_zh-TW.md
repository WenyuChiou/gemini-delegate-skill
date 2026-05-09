# Gemini Delegate Skill

> [English](README.md)

`gemini-delegate` 是一個給 Claude 使用的 skill,把 Google Gemini 當作「大 context 合成 / 長文撰寫 / 雙語與 CJK 寫作 / 第二意見審查」的專家。

> 📚 這是 [**agentic AI 學習路徑**](https://github.com/WenyuChiou/awesome-agentic-ai-zh) 的一部分 — 一個 7 階段的 agentic AI 學習路徑,支援多語言(zh-TW · zh-CN · English)。這個 skill 在 §13(Multi-LLM Delegation)被引用。

## 為什麼存在這個 Skill

Claude 的工作 context 有上限,有些任務即使 Claude 技術上做得到,結果也不理想。常見兩種失敗模式:

- **長文輸入塞不下。** 當需要摘要、比對、改寫橫跨多個大檔案的內容時,Gemini 較大的 context window 可以一次吃下整個全貌,而不需要 Claude 切片再拼回去。
- **CJK / 雙語寫作品質不穩。** 長篇繁中或中英互譯,Gemini 的語感通常比 Claude 自然。這是社群觀察,不是官方 benchmark,但出現得夠頻繁,值得結構化地處理。

把這類任務交給 Gemini,可以讓 Claude 留在自己的強項(判斷、術語審查、事實核對),而 Gemini 做它真正擅長的事(大 context 合成與 CJK 撰寫)。

**這個 skill 划算的情境:**

- 來源材料超過 Claude 舒服的 context 範圍
- 需要長篇繁中或雙語寫作
- 想對長文件做 reviewer-style 第二意見
- 需要在翻譯內容裡對齊術語
- 從多個來源草擬 release note、FAQ、摘要

**這個 skill 不划算的情境:**

- 任務是大量產生程式碼(改用 `codex-delegate`)
- 任務是架構或安全審查(留在 Claude)
- 輸入塞得進 Claude 的 context,而且品質比吞吐量重要
- 事實準確度比草稿流暢度更重要(Claude 反正會在出貨前審一遍)

## 定位

這個 skill **不是** `codex-delegate` 的 Gemini 版。它的工作不同:

- 把大型原始材料摘要成英文或 zh-TW
- 跨多檔合成
- 草擬英文、雙語、或對 CJK 讀者的更新
- 對長文件做 reviewer-style 第二意見
- 在翻譯內容裡對齊術語

不是用來做大量程式碼生成或架構工作。

## 核心流程

1. Claude 準備 context file,寫明 source paths、output paths、語言與限制
2. Claude 透過 wrapper 啟動 Gemini
3. Wrapper 可在執行後驗證指定輸出檔是否存在且非空
4. Claude 出貨前做事實、術語、語氣審查

Gemini 可以產生不錯的草稿,但出不出得了門仍由 Claude 決定。

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
python -m pytest -q
```

目前的 wrapper 測試覆蓋:

- success path 的 `result.json` 輸出
- 驗證失敗(`verify_failed`)的處理路徑

## 安裝

**1. 從 [`ai-research-skills` Claude Code marketplace](https://github.com/WenyuChiou/ai-research-skills) 安裝這個 skill:**

```bash
claude plugin marketplace add WenyuChiou/ai-research-skills
claude plugin install gemini-delegate@ai-research-skills
```

預設 scope 是 `user`(這個 OS 帳號、所有專案)。若只想安裝在目前專案,加 `--scope project`。

**2. 確認 Gemini CLI 在 `$PATH`:**

```bash
npm install -g @google/gemini-cli
gemini --version
```

## License

MIT
