// Ads for the browser build (alchemons.com/play). The iOS and Android apps
// never show ads; this file only exists on the web.
//
// Leave `client` empty and the page runs with no ads at all. Ad unit ids and
// the H5 switch below can change with a redeploy of the site alone — the game
// itself does not need rebuilding.
//
// Preview the layout: /play/?adpreview=1 (placeholder boxes, no real ads).
// Google's test ads once the id is in: /play/?adtest=1
window.ALCHEMONS_ADS = {
  // AdSense → Account → Settings → Publisher ID.
  client: 'ca-pub-8875246042491117',

  // H5 Games Ads (between-screens, start and rewarded ads) is a separate
  // application to Google (developers.google.com/ad-placement/docs/signup).
  // Leave false until it is approved: until then those ads never fill, and
  // the game skips asking. Display units beside/under the game don't need it.
  h5Games: false,

  // AdSense → Ads → By ad unit → Display ads. Each value is the unit's
  // data-ad-slot number. Any left empty is simply not shown.
  slots: {
    railLeft: '8617703029',   // "Alchemons rail left" (vertical), wide screens
    railRight: '5061687113',  // "Alchemons rail right" (vertical)
    bottom: '4814275109',     // "Alchemons bottom" (horizontal), under the game on phones
  },

  // Between-screens ads (H5 Games Ads): at most one per this many seconds.
  // Google paces them on top of this.
  interstitialGapSec: 90,

  // A between-screens ad once this many fusions or extractions have added up
  // (FUSE ALL and EXTRACT ALL count each one). The count survives a reload,
  // and starts over only once an ad has actually played. Leave one out, or
  // 0, and that action never brings an ad.
  every: {
    fusion: 5,
    extraction: 5,
  },

  // An ad right after PLAY, before the game starts.
  startAd: true,
};
