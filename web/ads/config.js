// Ads for the browser build (alchemons.com/play). The iOS and Android apps
// never show ads; this file only exists on the web.
//
// Leave `client` empty and the page runs with no ads at all. Once AdSense has
// approved alchemons.com, paste the publisher id and the ad unit ids here and
// redeploy — the game itself does not need rebuilding.
//
// Preview the layout before approval: /play/?adpreview=1 (placeholder boxes).
// Google's test ads once the id is in: /play/?adtest=1
window.ALCHEMONS_ADS = {
  // AdSense → Account → Settings → Publisher ID, e.g. 'ca-pub-1234567890123456'.
  client: '',

  // AdSense → Ads → By ad unit → Display ads. Each value is the unit's
  // data-ad-slot number. Any left empty is simply not shown.
  slots: {
    railLeft: '',   // beside the game on wide screens (vertical unit)
    railRight: '',  // the other side (may reuse railLeft's id)
    bottom: '',     // under the game on phones (horizontal 320×50 unit)
  },

  // Between-screens ads (H5 Games Ads): at most one per this many seconds.
  // Google paces them on top of this.
  interstitialGapSec: 90,

  // An ad right after PLAY, before the game starts.
  startAd: true,
};
