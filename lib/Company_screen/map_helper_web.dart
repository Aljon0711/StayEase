// Web-only implementation
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

String createLeafletMapHtml(double latitude, double longitude) {
  // Create HTML content for Leaflet map
  final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
     integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
     crossorigin=""/>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; }
    #map { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
     integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
     crossorigin=""></script>
  <script>
    try {
      var map = L.map('map', { zoomControl: true }).setView([$latitude, $longitude], 15);
      
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        maxZoom: 19
      }).addTo(map);
      
      var marker = L.marker([$latitude, $longitude], { draggable: true }).addTo(map);
      marker.bindPopup('Hotel Location').openPopup();
      
      map.on('click', function(e) {
        marker.setLatLng(e.latlng);
        if (window.parent) {
          window.parent.postMessage({
            type: 'mapClick',
            lat: e.latlng.lat,
            lng: e.latlng.lng
          }, '*');
        }
      });
      
      marker.on('dragend', function(e) {
        var pos = marker.getLatLng();
        if (window.parent) {
          window.parent.postMessage({
            type: 'mapClick',
            lat: pos.lat,
            lng: pos.lng
          }, '*');
        }
      });
    } catch (e) {
      console.error('Map error:', e);
    }
  </script>
</body>
</html>
''';
  
  // Create a Blob URL from the HTML content
  final blob = html.Blob([htmlContent], 'text/html');
  return html.Url.createObjectUrlFromBlob(blob);
}

void registerMapView(String mapId, String htmlContent, Function(double, double)? onLocationUpdate) {
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(mapId, (int viewId) {
    final html.IFrameElement iframe = html.IFrameElement()
      ..src = htmlContent
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    
    // Listen for messages from the iframe
    if (onLocationUpdate != null) {
      html.window.addEventListener('message', (html.Event e) {
        final event = e as html.MessageEvent;
        if (event.data is Map && event.data['type'] == 'mapClick') {
          final lat = event.data['lat'] as double;
          final lng = event.data['lng'] as double;
          onLocationUpdate(lat, lng);
        }
      });
    }
    
    return iframe;
  });
}
