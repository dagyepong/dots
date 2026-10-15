# Web Crawlers: Chrome Web Store listing

Ready-to-paste copy for the Chrome Web Store Developer Dashboard.

How the fields map:

- **Name** and **summary** are read from the package: `name` and `description` in `manifest.json`. To show the Chinese and Japanese summaries in the store, the package needs `_locales/en`, `_locales/zh_CN` and `_locales/ja` with `default_locale: "en"`. Without them, the English summary appears in every language.
- **Detailed description** is pasted into the **Store listing** tab, once per language. The store shows it as plain text, so copy only what is inside each `text` block.

| Field | Value |
|---|---|
| Name | `Web Crawlers` |
| Category | **Just for Fun** (Lifestyle group) |
| Languages | English (default, `en`) · Chinese (Simplified), `zh_CN` · Japanese, `ja` |
| Price | Free |
| Homepage URL | https://github.com/cyohei9907/web-crawlers |
| Support URL | https://github.com/cyohei9907/web-crawlers/issues |
| Privacy policy URL | https://github.com/cyohei9907/web-crawlers/blob/main/PRIVACY.md |
| Mature content | No |

---

## English (primary)

### Name

```text
Web Crawlers
```

12 / 45 characters. The name stays the same in every language so it's recognizable everywhere.

### Summary (127 / 132 characters)

```text
Let a neon spider loose on the page you're reading: it walks on the real words, and each word it touches glitches for a moment.
```

### Detailed description

```text
Web Crawlers lets a small neon spider loose on the page you're reading.

Click the toolbar icon, press "Release the spider", and it drops onto the page. Its cyan legs feel for the page's actual words (headlines, paragraphs, link text) and plant their feet on them. Every word it steps on glitches for a moment: a coloured outline, a highlight, a monospace blow-up, a sudden tilt, a stretched bar of "silk", a ghostly echo, a thin thread trailing behind. Then the word settles back exactly as it was.

The spider is procedural. Every leg, joint and step is drawn by code in real time, so each walk turns out a little different. It started as a small generative art piece about how we read the web. Now it can wander across the pages you read.

HOW TO USE
1. Open an ordinary web page: an article, a blog post, a wiki page, anything with text on it.
2. Click the Web Crawlers icon in the toolbar. (If you don't see it, open the puzzle-piece Extensions menu and pin it.)
3. Press "Release the spider".
4. To send it home, open the popup again and press "Recall the spider", or just reload the page.

Shortcut: Alt+Shift+S releases or recalls the spider on the current tab. Chrome only assigns it if no other extension uses it already; if the popup shows "not set", pick your own at chrome://extensions/shortcuts.

SETTINGS
• Auto-read: the spider slowly scrolls the page down as it reads, so you can sit back and watch.
• Size: small, medium or large.
• Effects: calm, normal or wild (how busy the glitches are).
Your settings are saved with Chrome's built-in storage. If Chrome sync is on, they follow you to your other signed-in Chrome browsers.

YOUR PAGE AND YOUR DATA
• The page is never modified. Everything is drawn on a separate, isolated layer above the page, and clicks pass straight through it, so links, forms and text selection keep working.
• Web Crawlers runs on a tab only when you click its button. It doesn't ask for access to any website in advance.
• No data is collected. The page's text is read locally only to work out where the spider's feet should land, and it never leaves your browser. There are no network requests, no analytics and no remote code.

GOOD TO KNOW
Chrome doesn't let any extension run on its own internal pages (addresses that start with chrome://, such as chrome://settings or chrome://extensions) or on the Chrome Web Store itself, so the spider can't visit those. Pages that are mostly images or video give it fewer words to walk on.

OPEN SOURCE
Web Crawlers is free and open source. The code, the original art piece and the issue tracker are here:
https://github.com/cyohei9907/web-crawlers
```

---

## 简体中文

### 名称

```text
Web Crawlers
```

12 / 45 个字符，各语言保持同一名称。

### 简短说明（62 / 132 个字符）

```text
在你正在浏览的网页上放出一只霓虹蜘蛛：它踩着页面上真实的文字爬行，被踩到的字会短暂“故障”变形。不改动页面，不收集任何数据。
```

### 详细说明

```text
Web Crawlers 会把一只小小的霓虹蜘蛛放到你正在浏览的网页上。

点击工具栏图标，按下“放出蜘蛛”，它就会落到页面上。青色的长腿会去摸索页面上真实的文字，比如标题、段落和链接，然后把脚稳稳踩在上面。被踩到的字会短暂地“故障”一下：彩色描边、高亮、等宽字体放大、突然倾斜、被拉成一条“蛛丝”色带、留下残影，还有拖在身后的细细蛛丝。之后，文字会恢复原样。

这只蜘蛛完全由程序生成。每条腿、每个关节、每一步都由代码实时绘制，所以每次爬行都会有些不同。它最初是一件关于“我们如何阅读网页”的生成艺术小作品，现在可以在任何你喜欢的网页上漫步。

使用方法
1. 打开一个普通网页：文章、博客、百科页面，只要有文字就行。
2. 点击工具栏中的 Web Crawlers 图标。（找不到的话，打开拼图形状的“扩展程序”菜单，把它固定到工具栏。）
3. 按下“放出蜘蛛”。
4. 想让它回家时，再次打开弹出窗口按“收回蜘蛛”，或者直接刷新页面。

快捷键：Alt+Shift+S 可以在当前标签页放出或收回蜘蛛。只有在没有其他扩展占用时 Chrome 才会分配它；如果弹出窗口显示“未设置”，请在 chrome://extensions/shortcuts 中自行设置。

设置
• 自动阅读：蜘蛛一边读，一边慢慢向下滚动页面，你只需要坐着看。
• 大小：小、中、大。
• 特效：平静、普通、狂野（特效的多少）。
设置保存在 Chrome 自带的存储中。如果开启了 Chrome 同步，设置会同步到你用同一账号登录的其他 Chrome 浏览器。

你的页面与你的数据
• 页面本身从不被修改。所有效果都绘制在页面上方一个独立、隔离的图层里，鼠标点击会直接穿过它，链接、表单和文字选择都照常可用。
• 只有在你点击按钮时，Web Crawlers 才会在当前标签页运行，它不会预先申请任何网站的访问权限。
• 不收集任何数据。页面文字只在本地读取，仅用来计算蜘蛛的脚该落在哪里，不会离开你的浏览器。没有网络请求，没有统计分析，没有远程代码。

须知
Chrome 不允许任何扩展程序在它的内部页面（以 chrome:// 开头的地址，例如 chrome://settings、chrome://extensions）和 Chrome 网上应用店本身运行，所以蜘蛛进不了这些页面。以图片或视频为主的页面，能让它踩的文字也会少一些。

开源
Web Crawlers 免费且开源。代码、原始艺术作品和问题反馈都在这里：
https://github.com/cyohei9907/web-crawlers
```

---

## 日本語

### 名前

```text
Web Crawlers
```

12 / 45 文字。どの言語でも同じ名前です。

### 概要（72 / 132 文字）

```text
閲覧中のページにネオンの蜘蛛を放ちます。蜘蛛は本物の文字の上を歩き、触れた言葉は一瞬だけグリッチします。ページは変更せず、データも収集しません。
```

### 詳細な説明

```text
Web Crawlers は、いま読んでいるページに小さなネオンの蜘蛛を放つ拡張機能です。

ツールバーのアイコンをクリックして「蜘蛛を放つ」を押すと、蜘蛛がページに降りてきます。シアンに光る脚が、見出しや段落、リンクなど、ページ上の本物の文字を探り、その上に足を下ろします。踏まれた言葉は一瞬だけグリッチします。色つきの輪郭、ハイライト、等幅フォントでの拡大、ふいの傾き、引き伸ばされた「糸」のバー、残像、そして背後にたなびく細い糸。そのあと、言葉は元どおりに戻ります。

蜘蛛はプロシージャルに生成されます。脚も関節も一歩一歩も、コードがリアルタイムで描いているので、歩き方は毎回少しずつ変わります。もとは「ウェブを読む」ことをテーマにした小さなジェネレーティブアート作品でしたが、いまでは好きなページを歩き回れるようになりました。

使い方
1. 記事、ブログ、Wiki など、文字のある普通のウェブページを開きます。
2. ツールバーの Web Crawlers アイコンをクリックします。（見当たらない場合は、パズルピース型の「拡張機能」メニューから固定してください。）
3. 「蜘蛛を放つ」を押します。
4. 帰らせたいときは、もう一度ポップアップを開いて「蜘蛛を呼び戻す」を押すか、ページを再読み込みしてください。

ショートカット：Alt+Shift+S で、いまのタブに蜘蛛を放つ / 呼び戻すことができます。ほかの拡張機能が使っていない場合にのみ Chrome が割り当てます。ポップアップに「未設定」と表示されたら、chrome://extensions/shortcuts で設定してください。

設定
• 自動読み進め：蜘蛛が読みながらページをゆっくり下へスクロールします。のんびり眺めていてください。
• サイズ：小・中・大
• エフェクトの量：控えめ・ふつう・ワイルド
設定は Chrome 標準のストレージに保存されます。Chrome の同期がオンなら、同じアカウントでログインしている他の Chrome にも引き継がれます。

ページとデータについて
• ページそのものは変更しません。すべての効果はページの上に重ねた独立したレイヤーに描かれ、クリックはそのまま下のページに届くので、リンクやフォーム、テキスト選択もいつもどおり使えます。
• Web Crawlers が動くのは、ボタンをクリックしたタブだけです。あらかじめウェブサイトへのアクセス権を求めることはありません。
• データは収集しません。ページの文字は、蜘蛛の足を置く場所を決めるためにブラウザ内で読み取るだけで、外部に送られることはありません。ネットワーク通信、アクセス解析、リモートコードは一切ありません。

ご注意
Chrome は、内部ページ（chrome://settings や chrome://extensions など、chrome:// で始まるアドレス）と Chrome ウェブストア自体では、どの拡張機能も動かせないようにしています。そのため蜘蛛はこれらのページには入れません。画像や動画が中心のページでは、歩ける文字が少なくなります。

オープンソース
Web Crawlers は無料のオープンソースです。コード、元になったアート作品、Issue はこちら：
https://github.com/cyohei9907/web-crawlers
```

---

## Category and languages

- **Category:** **Just for Fun** (in the Lifestyle group). The store describes it as extensions designed for entertainment, which fits a generative art toy better than the alternatives. If you need a second choice, use **Entertainment**. *Art & Design* is meant for image viewing and editing tools, so it's a weaker fit.
- **Languages:** English (`en`, default), Chinese (Simplified), `zh_CN`, Japanese, `ja`. In the Store listing tab, add each language and paste its detailed description. The name and summary come from `_locales/*/messages.json`.

---

## Privacy practices (Privacy tab)

### Single purpose description

```text
Web Crawlers is a piece of interactive visual art for the current web page. When the user clicks the toolbar button and presses "Release the spider", an animated spider is drawn over that tab. It walks on the page's words and briefly animates the words it touches. Everything is drawn in an isolated overlay: the page is not modified, nothing is sent anywhere, and the spider disappears when it is recalled or the page reloads.
```

### Permission justification

**activeTab**

```text
Grants temporary access to the tab the user is looking at, only after they click the Web Crawlers toolbar button (which opens the popup) or press the extension's keyboard shortcut, so the spider can be placed on that page. This lets the extension work on the site the user chooses without requesting any host permissions.
```

**scripting**

```text
Used with activeTab to run the extension's own packaged code in the current tab, only after the user clicks the toolbar button or presses the keyboard shortcut. When the popup opens, a one-line function checks whether the spider is already on the page. "Release the spider" (or the shortcut) injects the bundled spider.js, which draws everything, styles included, inside its own closed shadow root. "Recall the spider" and the popup's settings call functions of that same script. Only files bundled inside the extension are injected; no code is downloaded.
```

**storage**

```text
Saves the user's three popup preferences with chrome.storage.sync so they are remembered next time: auto-read on/off, spider size (S/M/L) and effect density (calm/normal/wild). No page content, URLs or browsing data is stored.
```

**Host permissions:** none are requested, so no host permission justification is needed. If the dashboard asks for one, check that the uploaded `manifest.json` has no `host_permissions` and no `content_scripts` `matches`.

### Remote code

Select: **No, I am not using remote code**

```text
All JavaScript and CSS ships inside the extension package. The extension does not load external scripts, modules, stylesheets, fonts or WebAssembly, and it makes no network requests. Text is rendered with fonts already installed on the user's system.
```

### Data usage

**What user data do you plan to collect from users now or in the future?** Leave every box unchecked. Web Crawlers collects **none** of these categories:

| Category | Collected? |
|---|---|
| Personally identifiable information | No |
| Health information | No |
| Financial and payment information | No |
| Authentication information | No |
| Personal communications | No |
| Location | No |
| Web history | No |
| User activity | No |
| Website content | No* |

\* The page's text and word positions are read **locally, in memory**, only to place the spider's feet and draw the effects. They are never stored, logged or transmitted, so nothing is collected. The privacy policy says the same thing so reviewers and users see one consistent statement.

**Certifications.** Tick all three. Since no user data is collected, each one holds trivially:

- [x] I do not sell or transfer user data to third parties, outside of the approved use cases. *(No user data is collected.)*
- [x] I do not use or transfer user data for purposes that are unrelated to my item's single purpose. *(No user data is collected.)*
- [x] I do not use or transfer user data to determine creditworthiness or for lending purposes. *(No user data is collected.)*

**Privacy policy URL:** https://github.com/cyohei9907/web-crawlers/blob/main/PRIVACY.md (source: `PRIVACY.md` at the repo root. The link only works after it is pushed to `main`.)

---

## Test instructions (optional, Test instructions tab)

```text
No account or login is needed. Open any ordinary web page with text (for example a news article or a blog post), click the Web Crawlers toolbar icon, and press "Release the spider" (or press Alt+Shift+S). A spider appears and walks over the page's words. Open the popup again to recall it, or reload the page. Settings (auto-read, size, density) are in the same popup. The extension cannot run on chrome:// pages or on the Chrome Web Store, because Chrome blocks all extensions there.
```

---

## Submission checklist

Store assets live in `extension/store/` (screenshots, promo tiles) and `extension/src/icons/` (icons).

1. [ ] **Developer account.** Register at https://chrome.google.com/webstore/devconsole (one-time **US$5** registration fee). Turn on 2-Step Verification for the Google account, verify the contact email, and complete the trader / non-trader declaration on the Account tab.
2. [ ] **Pre-flight check of the package.** Confirm that `manifest.json` lists only `activeTab`, `scripting` and `storage`, with no `host_permissions`. Confirm that the code has no `fetch`, `XMLHttpRequest`, `WebSocket`, `eval`, `new Function` or external `http(s)://` script, style or font URLs. Load it unpacked in `chrome://extensions` and test on a few sites.
3. [ ] **Upload the zip.** Run `python extension/tools/pack.py`. It validates the package (permissions, icon sizes, referenced files, locale keys, description length) and writes `extension/dist/web-crawlers-<version>.zip` with `manifest.json` at the zip root. Then go to **Add new item → upload**.
4. [ ] **Store listing tab.** Paste the detailed description for English, then add Chinese (Simplified) and Japanese and paste theirs. Set category **Just for Fun**, homepage URL and support URL (see the table at the top).
5. [ ] **Store icon (128×128).** Upload `extension/src/icons/icon128.png`. Use the same artwork as the 128 px icon inside the package: about 96×96 of artwork with transparent padding, legible on light and dark backgrounds.
6. [ ] **Screenshots (at least 1, up to 5, 1280×800).** Upload `extension/store/screenshot-1.jpg` … `screenshot-4.jpg`. They were captured by `extension/tools/shots.mjs` on a neutral, original sample article (`extension/tools/store-sample.html`, light and dark theme), so no third-party site, layout, logo or trademark appears.
7. [ ] **Small promo tile (440×280).** Upload `extension/store/promo-small-440x280.png`.
8. [ ] **Marquee promo tile (1400×560, optional).** Upload `extension/store/promo-marquee-1400x560.png` if it exists.
9. [ ] **Privacy tab.** Paste the single purpose description, the three permission justifications, the remote-code answer and the data-usage answers above. Tick the three certifications.
10. [ ] **Privacy policy URL.** Push `PRIVACY.md` to `main`, check that https://github.com/cyohei9907/web-crawlers/blob/main/PRIVACY.md opens, then paste it.
11. [ ] **Distribution tab.** Choose **Free**, visibility **Public** (or **Unlisted** for a soft launch), and **All regions**.
12. [ ] **Submit for review.** Optionally choose to publish manually after approval (deferred publishing). Most reviews take a few days. Narrow permissions and no remote code tend to help.
