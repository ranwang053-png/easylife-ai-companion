{{flutter_js}}
{{flutter_build_config}}

const easylifeFlutterConfig = {
  canvasKitBaseUrl: 'canvaskit/',
  canvasKitVariant: 'full',
  useLocalCanvasKit: true,
};

_flutter.loader.load({
  config: easylifeFlutterConfig,
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
