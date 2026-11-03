{{flutter_js}}
{{flutter_build_config}}

_flutter.buildConfig.builds.forEach((build) => {
  if (build.mainJsPath) {
    build.mainJsPath += '?v=2.1.41-244';
  }
});

_flutter.loader.load();
