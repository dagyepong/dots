// In the Capsule dock style the media cover is a circle (it was a square with its corners sticking
// out of the round key). The QML can't be run here, so the wiring is read from source.
// Run: node media_capsule_test.js
const fs = require('fs'), assert = require('assert')
const D = fs.readFileSync(__dirname + '/../../modules/sekai/dock/Dock.qml', 'utf8')
const block = (id) => { const i = D.indexOf('id: ' + id + '\n'); assert.ok(i > 0, id); return D.slice(i, i + 16000) }

// the small key: the cover is cut with a mask, not just `clip` (which only clips to the box)
const small = block('mediaFace').split('// The media key')[0].slice(0, 9000)
assert.ok(/id: coverLayer[\s\S]*?layer\.enabled: true[\s\S]*?maskSource: coverMask/.test(small), 'the cover is masked')
assert.ok(/id: coverMask[\s\S]*?radius: coverBox\.radius/.test(small), 'by the key\'s own radius, a circle in Capsule')
assert.ok(!/color: Theme\.surfaceDivider\s*\n\s*clip: true/.test(small), 'no more box clip standing in for a round one')
assert.ok(/capKeys \? parent\.width \/ 2 \+ \(parent\.width \/ 2 - 5\) \* 0\.7071/.test(small), 'the play mark sits on the circle, not in the empty corner')

// the long pill (top / bottom dock): a capsule with a circular cover in Capsule style
const wide = block('mediaWideFace')
assert.ok(/id: widePill\s*\n[\s\S]*?cornerRadius: dockWindow\.capKeys \? Math\.min\(widePill\.capWidth, widePill\.capHeight\) \/ 2 : Theme\.radiusBadge/.test(wide), 'fully rounded in Capsule')
assert.ok(/width: dockWindow\.capKeys \? height : widePill\.innerH/.test(wide), 'the cover is as wide as the pill is tall: a circle')
assert.ok(/maskEnabled: dockWindow\.capKeys\s*\n\s*maskSource: wideArtMask/.test(wide) && /maskSource: wideBlurMask/.test(wide), 'cover and blur are masked in Capsule')
assert.ok(/visible: !dockWindow\.capKeys\s*\n\s*edge: "left"/.test(wide) && /visible: !dockWindow\.capKeys\s*\n\s*edge: "right"/.test(wide), 'the square-corner patches are only for the other styles')
// the other styles are as they were
assert.ok(/: Theme\.radiusBadge/.test(wide) && /clip: !dockWindow\.capKeys/.test(wide))
// the ring the pill's content and the buttons' hit zones are measured from follows the style
assert.ok(/mediaRing: dockWindow\.capKeys \? Theme\.capDotRing : 6/.test(D))
console.log('media capsule: ok')
