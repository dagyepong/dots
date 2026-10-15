// Procedural encyclopedia: an endless stack of arachnid "articles" with long
// reference lists — the terrain the crawler walks on. All text is generated.
(() => {
  const R = Math.random;
  const pick = a => a[(R() * a.length) | 0];
  const ri = (a, b) => a + ((R() * (b - a + 1)) | 0);
  const digits = n => Array.from({ length: n }, () => ri(0, 9)).join('');
  const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

  // every word becomes a span so legs can grab individual words
  const W = s => esc(s).split(/(\s+)/).map(p => (!p || /^\s+$/.test(p)) ? p : `<span class="w">${p}</span>`).join('');
  const A = (s, cls = '') => `<a class="${cls}${R() < .12 ? ' v' : ''}">${W(s)}</a>`;
  const X = s => A(s, 'ext');

  const SUR = ['Haldane', 'Okafor', 'Lindqvist', 'Moreau', 'Tanaka', 'Ferreira', 'Novak', 'Brennan', 'Kowalski',
    'Ishikawa', 'Delgado', 'Whitcombe', 'Varga', 'Achterberg', 'Sorensen', 'Petrov', 'Castellanos', 'Imai',
    'Rahman', 'Oyelaran', 'Bellweather', 'Quist', 'Marchetti', 'Holloway', 'Szabo', 'Nakagawa', 'Dunmore',
    'Eriksen', 'Valcourt', 'Mbeki', 'Ostrander', 'Lachance', 'Fairweather', 'Grummet', 'Abernathy', 'Kerrigan',
    'Ulloa', 'Zhou', 'Pradhan', 'Ivers', 'Teague', 'Renwick', 'Alcott', 'Bramley', 'Cutler', 'Desrosiers'];
  const GIVEN = ['Anna', 'Paul', 'Marisol', 'Kenji', 'Edith', 'Tomasz', 'Ruth', 'Olu', 'Greta', 'Hector', 'Lena',
    'Ivo', 'Saskia', 'Bernard', 'Yuki', 'Farah', 'Desmond', 'Ilse', 'Rafael', 'Wren', 'Mateo', 'Clara', 'Ansel'];
  const INIT = 'ABCDEFGHJKLMNPRSTVW'.split('');

  const ADJ = ['cryptic', 'nocturnal', 'segmented', 'arboreal', 'fossil', 'tropical', 'cavernicolous', 'venomous',
    'social', 'ballooning', 'trapdoor', 'iridescent', 'myrmecomorphic', 'subterranean', 'Cretaceous', 'insular',
    'aquatic', 'desert', 'ancient', 'miniature', 'web-building', 'free-living', 'Jurassic', 'montane'];
  const NOUN = ['silk', 'spinnerets', 'chelicerae', 'courtship', 'egg sacs', 'book lungs', 'venom glands',
    'moulting', 'web geometry', 'prey capture', 'eyes', 'trichobothria', 'dispersal', 'mimicry', 'burrows',
    'pedipalps', 'mating plugs', 'maternal care', 'vibration signals', 'cuticle', 'retreats', 'kleptoparasitism'];
  const TAXA = ['Araneae', 'Mesothelae', 'Mygalomorphae', 'Araneomorphae', 'Liphistiidae', 'Salticidae',
    'Theridiidae', 'Araneidae', 'Lycosidae', 'Theraphosidae', 'Pholcidae', 'Thomisidae', 'Linyphiidae',
    'Tetragnathidae', 'Uloboridae', 'Atypidae', 'Ctenizidae', 'Dictynidae', 'Oonopidae', 'Zodariidae'];
  const PLACE = ['Southeast Asia', 'the Western Cape', 'Patagonia', 'Madagascar', 'the Andes', 'New Caledonia',
    'the Arid Southwest', 'Borneo', 'Tasmania', 'the Canary Islands', 'Sri Lanka', 'the Appalachians',
    'Hokkaido', 'the Atacama', 'Myanmar amber', 'the Baltic coast'];
  const VENUE = ['Annals of Silk Biology', 'Bulletin of Chelicerate Studies', 'Acta Arachnologica Nova',
    'Journal of Comparative Webcraft', 'Invertebrate Systematics Letters', 'Proceedings of the Spinneret Society',
    'Zoological Review of the Southern Hemisphere', 'Archives of Venom Research', 'Fossil Arthropod Quarterly',
    'Cladistic Notes', 'Behavioural Ecology of Small Things', 'Transactions in Eight Legs'];
  const PUB = ['Greywater Press', 'Lantern & Loom', 'Harrow University Press', 'Meridian Books', 'Sable Hill',
    'Northgate Academic', 'Quillon & Sons', 'Field Notes Publishing', 'Corvid House'];
  const CITY = ['Santa Barbara, California', 'Cambridge', 'Princeton, NJ', 'New York', 'Dubuque, Iowa',
    'Melbourne', 'Leiden', 'Edinburgh', 'Kyoto', 'Toronto', 'Cape Town', 'Oxford'];
  const MONTH = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September',
    'October', 'November', 'December'];

  const date = () => `${ri(1, 28)} ${pick(MONTH)} ${ri(1998, 2024)}`;
  const year = () => ri(1871, 2024);
  const cap = s => s[0].toUpperCase() + s.slice(1);

  const title = () => cap(pick([
    () => `The ${pick(ADJ)} ${pick(NOUN)} of ${pick(TAXA)}`,
    () => `${cap(pick(NOUN))} and ${pick(NOUN)} in ${pick(ADJ)} spiders`,
    () => `A ${pick(ADJ)} analysis of ${pick(NOUN)} in ${pick(TAXA)}`,
    () => `New records of ${pick(TAXA)} from ${pick(PLACE)}`,
    () => `On the ${pick(NOUN)} of ${pick(ADJ)} ${pick(TAXA)}`,
    () => `${cap(pick(ADJ))} spiders of ${pick(PLACE)}`,
    () => `How to know the spiders: ${pick(NOUN)}, ${pick(NOUN)} and ${pick(NOUN)}`,
    () => `Phylogeny of ${pick(TAXA)} inferred from ${pick(NOUN)}`,
    () => `The ${pick(ADJ)} world of ${pick(NOUN)}`,
  ])());

  const authors = () => {
    const n = R() < .55 ? 1 : ri(2, 5);
    const list = Array.from({ length: n }, () =>
      R() < .5 ? `${pick(SUR)}, ${pick(GIVEN)}` : `${pick(SUR)}, ${pick(INIT)}.${R() < .4 ? ' ' + pick(INIT) + '.' : ''}`);
    return n > 4 ? list.slice(0, 3).join('; ') + '; et al.' : list.join('; ');
  };

  const isbn = () => `ISBN ${A(`978-${ri(0, 1)}-${digits(3)}-${digits(5)}-${ri(0, 9)}`)}`;
  const doi = () => `${A('doi')}:${A(`10.${ri(1000, 1999)}/${pick(['j.', 'zse.', 'arac.', 'fgene.', ''])}${digits(4)}-${digits(4)}.${year()}.${digits(5)}`)}`;
  const pmid = () => `${A('PMID')} ${A(digits(8))}`;
  const pmc = () => `${A('PMC')} ${A(digits(7))}<span class="lock">🔒</span>`;
  const bib = () => `${A('Bibcode')}:${A(`${year()}${pick(['PBioJ', 'NatSR', 'ArthS', 'Palgy', 'SilkB'])}..${ri(1, 99)}..${ri(10, 999)}${pick(INIT)}`)}`;
  const s2 = () => `${A('S2CID')} ${A(digits(ri(6, 9)))}`;
  const oclc = () => `${A('OCLC')} ${A(digits(ri(7, 9)))}`;
  const jstor = () => `${A('JSTOR')} ${A(digits(7))}`;
  const ids = () => {
    const pool = [doi, pmid, pmc, bib, s2, oclc, jstor];
    const out = [];
    for (let i = 0, n = ri(0, 4); i < n; i++) out.push(pick(pool)());
    return out.length ? ' ' + out.join('. ') + '.' : '';
  };

  const backlink = () => {
    if (R() < .82) return `<a class="back">^</a>`;
    const n = ri(2, 4);
    return `<span class="back">^</span> ` + 'abcd'.slice(0, n).split('').map(c => `<a class="back"><b>${c}</b></a>`).join('');
  };

  const citation = () => {
    const kind = R();
    if (kind < .32) { // book
      const t = R() < .5 ? `<i>${A(title(), R() < .4 ? 'ext' : '')}</i>` : `<i>${W(title())}</i>`;
      return `${W(authors())} (${year()}). ${t}${R() < .3 ? ` (${ri(1, 4)}${pick(['st', 'nd', 'rd', 'th'])} ed.)` : ''}. ${W(pick(CITY))}: ${W(pick(PUB))}.${R() < .5 ? ` p.&nbsp;${ri(3, 480)}.` : ''} ${isbn()}.${R() < .4 ? ' ' + oclc() + '.' : ''}`;
    }
    if (kind < .78) { // journal
      return `${W(authors())} (${year()}). "${X(title())}"${R() < .15 ? '<span class="pdf"> (PDF)</span>' : ''}. <i>${A(pick(VENUE))}</i>. <b>${ri(1, 220)}</b> (${ri(1, 12)}): ${ri(1, 900)}–${ri(901, 999)}.${ids()}`;
    }
    if (kind < .92) { // web / archived
      return `"${X(title())}". ${W(pick(['eightlegs.example', 'arachnid-notes.example', 'Fieldbook Quarterly Online', 'silkwire.example', 'Spider Survey Digest']))}. ${A('Archived', 'ext')} from ${A('the original', 'ext')} on ${date()}. Retrieved ${date()}.`;
    }
    return `${W(authors())} (${date()}). "${X(title())}". <i>${A(pick(['The Evening Lantern', 'Harbor Gazette', 'The Weekly Orb', 'Northern Courier']))}</i>. pp.&nbsp;${ri(10, 90)}–${ri(91, 120)}.`;
  };

  // ---- prose ----
  const SUBJ = ['Spiders in this group', 'Members of the family', 'Adult females', 'Juveniles', 'Most species',
    'Several lineages', 'Orb-weaving species', 'Ground-dwelling forms', 'Males', 'Many populations',
    'The earliest known fossils', 'Cave-dwelling relatives'];
  const PRED = ['construct silk retreats beneath bark', 'rely on vibration rather than vision to locate prey',
    'produce several distinct kinds of silk', 'ambush prey from concealed burrows', 'moult up to a dozen times before maturity',
    'disperse over long distances by ballooning', 'inject digestive enzymes into captured prey',
    'guard their egg sacs for weeks', 'retain traces of abdominal segmentation', 'signal to rivals by plucking web lines',
    'hunt actively at night', 'mimic ants in shape and gait', 'line their burrows with a hinged silk door',
    'recycle old webs by eating them', 'tolerate long periods without food', 'live communally in shared nests'];
  const TAIL = ['although this varies between populations', 'particularly in humid regions',
    'as noted in early descriptions', 'a trait shared with related families', 'unlike most other arachnids',
    'which remains poorly studied', 'especially during the breeding season', `as recorded in ${pick(PLACE)}`];

  const sup = () => `<sup>${A(`[${ri(1, 180)}]`)}</sup>`;
  const sentence = () => {
    const s = `${pick(SUBJ)} ${pick(PRED)}${R() < .5 ? ', ' + pick(TAIL) : ''}.`;
    // occasionally turn a keyword into an inline link
    return W(s).replace(/<span class="w">(silk|burrows|prey|ballooning|webs?|spiders|arachnids|fossils)<\/span>/g,
      (m, w) => R() < .6 ? `<a>${m}</a>` : m) + (R() < .45 ? sup() : '');
  };
  const para = () => `<p>${Array.from({ length: ri(3, 6) }, sentence).join(' ')}</p>`;

  const SECTIONS = ['Description', 'Behaviour', 'Taxonomy', 'Distribution', 'Evolution', 'Silk and webs',
    'Reproduction', 'Ecology', 'Relationship with humans', 'Fossil record'];

  const listOf = (n, f) => Array.from({ length: n }, () => `<li>${f()}</li>`).join('');

  const navbox = () => {
    const fam = (names) => names.map(n => A(n)).join(' <span class="dot">·</span> ');
    return `<table class="navbox">
      <tr><th colspan="2" class="nb-title"><span class="nb-vte">${A('V')}·${A('T')}·${A('E')}</span>${W('Extant Araneae families')}</th></tr>
      <tr><td colspan="2" class="nb-tax">${W('Kingdom:')} ${A('Animalia')} · ${W('Phylum:')} ${A('Arthropoda')} · ${W('Subphylum:')} ${A('Chelicerata')} · ${W('Class:')} ${A('Arachnida')}</td></tr>
      <tr><td colspan="2" class="nb-sub">${W('Suborder')} ${A('Mesothelae')}</td></tr>
      <tr><th class="nb-group">${W('Liphistiomorphae')}</th><td>${A('Liphistiidae')} ${W('(segmented spiders)')} <span class="dot">·</span> ${A('Heptathelidae')}</td></tr>
      <tr><td colspan="2" class="nb-sub">${W('Suborder')} ${A('Opisthothelae')}</td></tr>
      <tr><th class="nb-group">${A('Mygalomorphae')}</th><td>${fam(['Actinopodidae', 'Antrodiaetidae', 'Atracidae', 'Atypidae', 'Barychelidae', 'Ctenizidae', 'Dipluridae', 'Euctenizidae', 'Halonoproctidae', 'Idiopidae', 'Nemesiidae', 'Theraphosidae'])}</td></tr>
      <tr><th class="nb-group">${A('Araneomorphae')}</th><td>${fam(['Agelenidae', 'Araneidae', 'Clubionidae', 'Ctenidae', 'Dictynidae', 'Gnaphosidae', 'Linyphiidae', 'Lycosidae', 'Oxyopidae', 'Pholcidae', 'Pisauridae', 'Salticidae', 'Sparassidae', 'Tetragnathidae', 'Theridiidae', 'Thomisidae', 'Uloboridae', 'Zodariidae'])}</td></tr>
    </table>`;
  };

  const NAMES = ['Spider', 'Liphistiidae', 'Salticidae', 'Araneidae', 'Theraphosidae', 'Lycosidae', 'Pholcidae',
    'Theridiidae', 'Thomisidae', 'Uloboridae', 'Atypidae', 'Linyphiidae'];
  let articleN = 0;

  function article(nRefs) {
    const name = NAMES[articleN++ % NAMES.length];
    const secs = SECTIONS.slice().sort(() => R() - .5).slice(0, ri(3, 5));
    // content is grouped into .cv chunks so the browser can skip layout of
    // chunks far off screen (content-visibility) — the page grows forever
    const cv = s => `<div class="cv">${s}</div>`;
    // .cont (not `.article + .article`): the crawler removes read articles from the top,
    // and the separator of the new first article must not vanish with them
    let h = `<article class="article${articleN > 1 ? ' cont' : ''}">
      <h1>${W(name)}</h1>
      <div class="tagline">${W('From Arachnopedia, the crawlable encyclopedia')}</div>
      ${cv(para() + para())}`;
    for (const s of secs) {
      let sec = `<h2>${W(s)}</h2>`;
      for (let i = 0, n = ri(1, 3); i < n; i++) sec += para();
      h += cv(sec);
    }
    h += `<h2>${W('References')}</h2>`;
    for (let i = 0; i < nRefs; i += 12) {
      h += cv(`<ol class="refs" start="${i + 1}">${listOf(Math.min(12, nRefs - i), () => `${backlink()} ${citation()}`)}</ol>`);
    }
    h += cv(`<h2>${W('General and cited references')}</h2><ul class="refs">${listOf(ri(5, 9), citation)}</ul>`);
    h += cv(`<h2>${W('Further reading')}</h2><ul class="refs">${listOf(ri(5, 9), citation)}</ul>`);
    h += cv(`<h2 class="ext-links">${W('External links')}</h2><ul class="refs">${listOf(ri(3, 6), () =>
      `${X(title())} (${A('Archived', 'ext')} ${date()} at the ${A('Page Archive')})`)}</ul>`);
    h += cv(navbox()) + `</article>`;
    return h;
  }

  const root = document.getElementById('content');
  window.Arachno = {
    append(nRefs = ri(90, 150)) { root.insertAdjacentHTML('beforeend', article(nRefs)); },
  };

  window.Arachno.append(160);
  window.Arachno.append();
})();
