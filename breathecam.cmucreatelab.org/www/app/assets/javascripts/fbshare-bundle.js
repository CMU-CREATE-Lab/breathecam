window.fbAsyncInit = function() {
  FB.init({
    appId      : '342963495886660',
    xfbml      : true,
    version    : 'v2.1'
  });
};

(function(d, s, id){
   var js, fjs = d.getElementsByTagName(s)[0];
   if (d.getElementById(id)) {return;}
   js = d.createElement(s); js.id = id;
   js.src = "//connect.facebook.net/en_US/sdk.js";
   fjs.parentNode.insertBefore(js, fjs);
 }(document, 'script', 'facebook-jssdk'));

var ThumbnailServiceAPI = function (config, args) {
  this.host = (config && config.host) ? config.host : "http://timemachine-api.cmucreatelab.org/thumbnail";
  this.args = (args) ? args : {};
}

ThumbnailServiceAPI.prototype.serializeArgs = function() {
  var str = [];
  for(var key in this.args){
    if (this.args.hasOwnProperty(key)) {
      var val = encodeURIComponent(key);
      if (this.args[key] != "") {
        val += "=" + this.args[key];
      }
      str.push(val);
    }
  }
  return str.join("&");
}
ThumbnailServiceAPI.prototype.serialize = function() {
  return this.host + "?" + this.serializeArgs();
}

function getPicture() {
  var v = timelapse.getView();
  var config = {
    'host': 'http://timemachine-api.cmucreatelab.org/thumbnail'
  };
  var bounds = timelapse.getBoundingBoxForCurrentView();
  var args = {
    'root': timelapse.getSettings().url,
    'boundsLTRB': bounds.xmin + "," + bounds.ymin + "," + bounds.xmax + "," + bounds.ymax,
    'width': 1528,
    'height': 800,
    'frameTime': timelapse.getCurrentFrameNumber()/timelapse.getFps(),
    'format': 'png',
    'tileFormat': timelapse.getSettings().mediaType.slice(1)
  }
  var t = new ThumbnailServiceAPI(config, args);
  return t.serialize();
}

// defaults to window.location.href
function getLink(url) {
  if (!url) {
    url = window.location.href;
  }
  var shareView = timelapse.getShareView();
  return url + shareView;
}

function getDescription() {
  return "Breathe Cam provides high-resolution timelapse panoramas of Pittsburgh’s skyline to help you discover more about the air you breathe using the power of your own vision.";
}

function getCaption() {
  var location = '<%= @location_id %>';
  var caption = 'Timelapse captured from ';
  if (location == 'heinz') {
    caption += 'downtown Pittsburgh';
  } else if (location == 'trimont1') {
    caption += 'Mount Washington';
  } else if (location == 'walnuttowers1') {
    caption += 'Squirrel Hill';
  } else if (location == 'pitt1') {
    caption += 'Oakland';
  } else {
    caption += 'Pittsburgh';
  }
  caption += " at " + timelapse.getCurrentCaptureTime();
  return caption;
}

var fbShareUrl;
function fbShare() {
  FB.ui({
    method: 'feed',
    name: 'Breathe Cam',
    link: getLink(fbShareUrl),
    picture: getPicture(),
    caption: getCaption(),
    description: getDescription(),
  }, function(response){});
}
