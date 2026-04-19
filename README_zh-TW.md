# Gemini CLI 委派技能

> [English Version](README.md)

一個讓 Claude 將高 token 消耗任務委派給 Google Gemini CLI 的技能。Claude 負責規劃與審核，Gemini 負責執行。

## 功能特色

**任務委派** — 透過 stdin 管道與 `--approval-mode yolo` 進行非互動式 headless 執行

**中日韓內容** — 原生支援中文/日文/韓文文本生成、財務報告、社群媒體貼文

**多檔案操作** — 跨多個檔案的批次重構、程式碼生成與文件撰寫

**上下文管道** — 撰寫詳細的任務檔案並傳送給 Gemini 處理複雜的多步驟工作

**跨平台** — 內含 Windows 專用解決方案（cmd shell 路由、UTF-8 處理）

## 安裝

Gemini CLI 需全域安裝：

```bash
npm install -g @google/gemini-cli
```

驗證：`gemini --version`（已測試 v0.37.1）

## 專案結構

```
gemini-delegate/
├── SKILL.md              # 主要技能指令
├── README.md             # 英文文件
├── README_zh-TW.md       # 繁體中文文件
├── scripts/
│   ├── run_gemini.sh     # Bash 輔助腳本（pushd、--approval-mode yolo、stdin 管道、驗證）
│   └── run_gemini.ps1    # PowerShell 輔助腳本（同 .sh 邏輯）
└── references/
    └── examples.md       # 完整委派範例
```

## 使用方式

此技能設計給 Claude（或任何 AI 協調器）讀取並遵循。當 Claude 遇到符合委派條件的任務時：

1. 撰寫描述任務的上下文檔案
2. 以上下文啟動 Gemini CLI
3. 審核並驗證輸出結果
4. 向使用者報告結果

## 授權

MIT
