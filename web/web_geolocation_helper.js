// web/web_geolocation_helper.js

window.getUserLocation = function(successCallbackName, errorCallbackName) {
  if (!navigator.geolocation) {
    window[errorCallbackName]("Geolocation is not supported by your browser");
    return;
  }

  navigator.geolocation.getCurrentPosition(
    function (position) {
      window[successCallbackName](position.coords.latitude, position.coords.longitude);
    },
    function (error) {
//      window[errorCallbackName]("Unable to retrieve your location: " + error.message);
        window[errorCallbackName]("Browser tidak mendukung geolocation, gunakan browser lain seperti Chrome");
    }
  );
};
