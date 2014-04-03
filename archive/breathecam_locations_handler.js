// Node.js server for handling breathecam locations

var http = require('http');
var port = 40893;
var fs = require('fs');
var locationsOutputFile = "locations.json";
var logOutputFile = ""
var locations = {};
var logList = ["temp"];

var server = http.createServer( function(req, res) {
  var body = "";
  if (req.method == 'POST') {
    req.on('data', function (data) {
      body += data;
    });
    req.on('end', function () {
      var paramsArray = body.split("&");
      var locationName = "";
      var logMsg = "";
      logMsg += new Date().getTime();
      for (var i = 0; i < paramsArray.length; i++) {
        var tmpParamArray = paramsArray[i].split("=");
        if (tmpParamArray.length < 2) continue;
        // Assumes the id (i.e. the location name) is the first param
        if (i == 0) {
          locationName = tmpParamArray[1];
          locations[locationName] = {};
          logOutputFile = locationName + ".log";
        } else {
          key = tmpParamArray[0];
          value = tmpParamArray[1];
          // Check that the request is valid. Of course someone
          // could have just snooped what a valid request looks like...
          if (key == "uuid") {
            decodedId = hexToStr(value);
            if (decodedId !== locationName) {
              console.log(key + " did not match " + locationName);
              return;
            }
          }
          if (logList.indexOf(key) >= 0) {
	    logMsg += "\t" + value;
          } else {
            locations[locationName][key] = value;
          }
        }
      }
      logMsg += "\n";
      locations[locationName]["ip"] =  req.connection.remoteAddress;
      fs.writeFile(locationsOutputFile, JSON.stringify(locations), null);
      fs.appendFile(logOutputFile, logMsg, null);
      res.writeHeader(200, {"Content-Type": "text/plain"});
      res.write("Hello Josh\n");
      res.end();
    });
  }
});

function strTohex(str) {
  var hex = '';
  for(var i = 0; i < str.length; i++)
    hex += '' + str.charCodeAt(i).toString(16);
  return hex;
}

function hexToStr(hex) {
  var hex = hex.toString(); // force conversion
  var str = '';
  for (var i = 0; i < hex.length; i += 2)
    str += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
  return str;
}


// Main

fs.readFile(locationsOutputFile, function(error, data) {
  if (!error) locations = JSON.parse(data);
});

server.listen(port);
console.log('Listening at port ' + port);
