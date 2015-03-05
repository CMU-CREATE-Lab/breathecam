// ThumbnailServiceAPI.js

var ThumbnailServiceAPI = function (config, args) {
  this.host = (config && config.host) ? config.host : "http://timemachine-api.bodytrack.org/thumbnail";
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
