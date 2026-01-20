 // ==UserScript== // @match https://bc.instructue.com/* // @match https://letterboxd.com/* // ==/UserScript==

const meta = document.createElement('meta'); meta.name = "color-scheme"; meta.content = "dark light"; document.head.appendChild(meta);
