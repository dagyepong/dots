# Privacy Policy: Web Crawlers

**Effective date: 2026-10-02**

[English](#english) · [简体中文](#简体中文)

---

## English

Web Crawlers is a Chrome extension that lets an animated spider walk across the web page you are viewing. This policy describes what the extension does and does not do with your information.

**In short: Web Crawlers collects nothing.** It has no accounts, no servers, no analytics and no advertising.

### Information we collect

None. Web Crawlers does not collect, transmit, store remotely, sell or share any personal information or browsing data. The developer receives no data from the extension.

### What the extension reads on the page

When you click the toolbar button (or press its keyboard shortcut), Chrome gives the extension temporary access to the current tab (the `activeTab` permission). Opening the popup only checks whether a spider is already on that page. When you press "Release the spider" (or use the shortcut), the extension reads where the words sit on that page, so the spider's feet can land on real text and the words it touches can be animated.

- This happens **locally, in your browser, in memory**, and only while the spider is on the page.
- The page content is never saved, logged or sent anywhere. It does not leave your browser.
- The extension does not record which pages you visit or keep any browsing history.
- The page itself is not modified. All effects are drawn in a separate, isolated overlay that disappears when you recall the spider or reload the page.

### What is stored

Only your own settings:

- auto-read (on/off)
- spider size (S/M/L)
- effect density (calm/normal/wild)

These are saved with `chrome.storage.sync`. If you are signed in to Chrome with sync turned on, Chrome may sync these settings across your own signed-in browsers. That sync is handled by Chrome under your Google Account settings, and the developer has no access to it. Removing the extension removes its settings from that browser; a copy synced by Chrome stays under your Google Account's sync data, which you can clear in Chrome's sync settings.

### Network requests, analytics and remote code

- **No network requests.** The extension does not contact any server.
- **No analytics or telemetry.** Nothing about how you use it is measured or reported.
- **No remote code.** Everything the extension runs is included in its package. It does not download or run code from anywhere else.

### Permissions

| Permission | Why it's needed |
|---|---|
| `activeTab` | Access the current tab, only after you click the toolbar button or press the shortcut, to place the spider on that page. |
| `scripting` | Insert the extension's own bundled spider script into that tab. |
| `storage` | Remember your three settings. |

Web Crawlers requests no host permissions and cannot access any site until you click its button on that tab.

### Third parties

No data is shared with, sold to or transferred to anyone, because none is collected.

### Changes to this policy

If this policy changes, the updated version will be published at this same address with a new effective date.

### Contact

Questions or concerns? Please open an issue on GitHub:
https://github.com/cyohei9907/web-crawlers/issues

---

## 简体中文

Web Crawlers 是一个 Chrome 扩展程序，它会让一只动画蜘蛛在你正在浏览的网页上爬行。本政策说明该扩展程序会如何对待你的信息，以及不会做什么。

**简而言之：Web Crawlers 不收集任何信息。** 没有账号，没有服务器，没有统计分析，也没有广告。

### 我们收集的信息

无。Web Crawlers 不会收集、传输、远程存储、出售或分享任何个人信息或浏览数据。开发者不会从扩展程序接收任何数据。

### 扩展程序在页面上读取的内容

当你点击工具栏按钮（或按下它的快捷键）时，Chrome 会授予扩展程序对当前标签页的临时访问权限（`activeTab` 权限）。打开弹出窗口时，它只会检查该页面上是否已经有蜘蛛。当你按下“放出蜘蛛”（或使用快捷键）后，扩展程序才会读取页面上文字的位置，让蜘蛛的脚落在真实的文字上，并为它碰到的文字绘制动画效果。

- 这一切都只在**你的浏览器本地、内存中**进行，并且仅在蜘蛛停留在页面上时进行。
- 页面内容不会被保存、记录或发送到任何地方，不会离开你的浏览器。
- 扩展程序不会记录你访问了哪些页面，也不保留任何浏览记录。
- 页面本身不会被修改。所有效果都绘制在一个独立、隔离的覆盖层中，召回蜘蛛或刷新页面后即消失。

### 存储的内容

仅保存你自己的设置：

- 自动阅读（开 / 关）
- 蜘蛛大小（S / M / L）
- 效果密度（平静 / 普通 / 狂野）

这些设置通过 `chrome.storage.sync` 保存。如果你已登录 Chrome 并开启了同步，Chrome 可能会在你自己登录的多个浏览器之间同步这些设置。该同步由 Chrome 根据你的 Google 账号设置完成，开发者无法访问。移除扩展程序会删除它在该浏览器中的设置；Chrome 已同步的副本保存在你 Google 账号的同步数据中，可在 Chrome 的同步设置里清除。

### 网络请求、统计分析与远程代码

- **没有网络请求。** 扩展程序不会连接任何服务器。
- **没有统计分析或遥测。** 不会测量或上报你的任何使用情况。
- **没有远程代码。** 扩展程序运行的所有代码都包含在安装包中，不会从其他任何地方下载或运行代码。

### 权限

| 权限 | 用途 |
|---|---|
| `activeTab` | 仅在你点击工具栏按钮或按下快捷键后访问当前标签页，以便把蜘蛛放到该页面上。 |
| `scripting` | 将扩展程序自带的蜘蛛脚本注入该标签页。 |
| `storage` | 记住你的三项设置。 |

Web Crawlers 不申请任何网站访问权限（host permissions）。在你于某个标签页点击它的按钮之前，它无法访问任何网站。

### 第三方

由于不收集任何数据，因此不会与任何人分享、出售或转让数据。

### 政策变更

如本政策有更新，新版本将发布在同一地址，并注明新的生效日期。

### 联系方式

如有疑问或意见，请在 GitHub 上提交 issue：
https://github.com/cyohei9907/web-crawlers/issues

**生效日期：2026-10-02**
