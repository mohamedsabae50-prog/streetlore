{{flutter_js}}
{{flutter_build_config}}

_flutter.buildConfig.builds.forEach((build) => {
  if (build.mainJsPath) {
    build.mainJsPath += '?v=2.1.36-237-clean-splash';
  }
});

_flutter.loader.load();
