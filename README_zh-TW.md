# Gemini Delegate Skill

> [English](README.md)

`gemini-delegate` 是一個給 Claude 使用的 skill，目的是把 Gemini 當成「large-context synthesis / 長文撰寫 / 英文與 CJK 輸出 / 第二意見 review」的專門工具，而不是拿來做大量程式實作。

## 定位

這個 skill 不是 `codex-delegate` 的 Gemini 版本。

它比較適合這些工作：

- 把大量材料整理成英文或 zh-TW 摘要
- 綜合多份文件後輸出一份整理稿
- 起草英文、雙語或 CJK 導向的更新內容
- 對長篇文件做 reviewer-style 第二意見審查
- 對翻譯稿做術語一致性整理

它不適合用來做大量 code generation、架構決策或程式除錯。

## 這版更新重點

- 範圍收斂為 synthesis 與 CJK 寫作
- 明確區分 Gemini、Codex、Claude 的邊界
- wrapper 會輸出機器可讀的 `<log>.result.json`
- 新增驗證導向的 wrapper tests

## 核心工作流

1. Claude 先準備 context file，寫清楚來源、輸出、語言與限制。
2. Claude 透過 wrapper 啟動 Gemini。
3. Wrapper 可在執行後驗證預期輸出檔案是否真的存在。
4. Claude 再做事實、術語、語氣的最終審核。

Gemini 可以提供有價值的初稿，但最後是否能發布，仍然由 Claude 判斷。

## 專案結構

```text
gemini-delegate-skill/
├── SKILL.md
├── README.md
├── README_zh-TW.md
├── scripts/
│   ├── run_gemini.sh
│   └── run_gemini.ps1
├── tests/
│   └── test_wrappers.py
└── references/
```

## 測試

```bash
python -m pytest -q
```

目前測試涵蓋：

- success path 的 `result.json` 輸出
- verification failure 的回報行為

## 安裝

**1. 從 [`ai-research-skills` Claude Code marketplace](https://github.com/WenyuChiou/ai-research-skills) 裝 skill：**

```bash
claude plugin marketplace add WenyuChiou/ai-research-skills
claude plugin install gemini-delegate@ai-research-skills
```

Default scope 是 `user`（這個 OS 使用者帳號全域）。要只裝在當下 project
加 `--scope project`。

**2. 確認環境裡有 Gemini CLI：**

```bash
npm install -g @google/gemini-cli
gemini --version
```

## License

MIT
