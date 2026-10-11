{{flutter_js}}
{{flutter_build_config}}

// The game runs inside the page's column (web/shell.js), and only after the
// player presses PLAY: the engine loads behind the start gate meanwhile.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const shell = window.alchemonsShell;
    try {
      const appRunner = await engineInitializer.initializeEngine({
        hostElement: document.getElementById('game'),
      });
      shell.engineReady();
      await shell.waitForPlay();
      await appRunner.runApp();
      shell.started();
    } catch (e) {
      shell.failed(e);
    }
  },
});
