function scale(val, omin, omax, nmin, nmax) {
  return ( ((val - omin) * (nmax - nmin))/(omax - omin) + nmin)
}

var ThumbnailTool = function(timelapse, ltrb) {
  this.timelapse_ = timelapse;

  this.canvasLayer_ = new TimeMachineCanvasLayer({
    timelapse: timelapse,
    resizeHandler: resize,
    animate: false,
    updateHandler: update,
    id: "thumbnailTool"
  });

  this.ctx_ = this.canvasLayer_.canvas.getContext('2d');

  this.bounds_ = {};

  this.handles_ = [];

  this.display = false;

  this.selected = false;

  this.resizing = false;

  this.selectedHandle = null;

  this.xhr = null;
  this.requestMade = false;

  var that = this;
  var el = document.getElementById('thumbnail-tool');

  this.$videoDiv = $("#" + timelapse.getVideoDivId());

  if (ltrb) {
    this.display = true;
    var a = ltrb.split(",");
    this.offset_ = {
      x: 0,
      y: 0
    }
    this.setBounds({
      xmin: parseFloat(a[0]),
      xmax: parseFloat(a[2]),
      ymin: parseFloat(a[1]),
      ymax: parseFloat(a[3])
    });
    this.draw();
    this.filter(function(r) { var o = JSON.parse(r); drawResults(o.values)})
  }

  el.addEventListener("mousedown", function(event) {
    if (that.display) {
      that.display = false;
      that.bounds_ = {};
      that.erase();
      if (typeof chart != "undefined") {
        chart.clearChart();
      }
      var el = document.getElementById('chart');
      el.style['background'] = "#ffffff";

    } else {
      that.display = true;
      var view = timelapse.getView();
      var scaleOffset = 100/view.scale;
      that.offset = {
        x: 0,
        y: 0
      }
      that.bounds_ = {
        xmin: view.x - scaleOffset,
        xmax: view.x + scaleOffset,
        ymin: view.y - scaleOffset,
        ymax: view.y + scaleOffset
      };

      /*
       * 0 1 2
       * 7   3
       * 6 5 4
      */
      that.handles_[0] = {
        x: that.bounds_.xmin,
        y: that.bounds_.ymin
      };
      that.handles_[1] = {
        x: that.bounds_.xmin + (that.bounds_.xmax - that.bounds_.xmin)/2.,
        y: that.bounds_.ymin
      };
      that.handles_[2] = {
        x: that.bounds_.xmax,
        y: that.bounds_.ymin
      };
      that.handles_[3] = {
        x: that.bounds_.xmax,
        y: that.bounds_.ymin + (that.bounds_.ymax - that.bounds_.ymin)/2.
      };
      that.handles_[4] = {
        x: that.bounds_.xmax,
        y: that.bounds_.ymax
      };
      that.handles_[5] = {
        x: that.bounds_.xmin + (that.bounds_.xmax - that.bounds_.xmin)/2.,
        y: that.bounds_.ymax
      };
      that.handles_[6] = {
        x: that.bounds_.xmin,
        y: that.bounds_.ymax
      };
      that.handles_[7] = {
        x: that.bounds_.xmin,
        y: that.bounds_.ymin + (that.bounds_.ymax - that.bounds_.ymin)/2.
      };

      that.draw();
      that.filter(function(r) { var o = JSON.parse(r); drawResults(o.values)})

    }
  });

  var el = this.timelapse_.getDiv();

  el.addEventListener("dblclick", function(event) {
    that.dispatchEvent(event);
  });

  el.addEventListener("mousedown", function(event) {
    var coords = that.getMouse(event);
    var bounds = that.timelapse_.getBoundingBoxForCurrentView();
    var timelapseCoords = {
      x: scale(coords.x, 0, that.canvasLayer_.canvas.width, bounds.xmin, bounds.xmax),
      y: scale(coords.y, 0, that.canvasLayer_.canvas.height, bounds.ymin, bounds.ymax)
    }
    if (that.contains(timelapseCoords, that.bounds_)) {
      that.selected = true;
      that.offset_.x = timelapseCoords.x - (that.bounds_.xmin + (that.bounds_.xmax - that.bounds_.xmin) / 2.);
      that.offset_.y = timelapseCoords.y - (that.bounds_.ymin + (that.bounds_.ymax - that.bounds_.ymin) / 2.);
    } else {
      for (var i = 0; i < that.handles_.length; i++) {
        var box = that.getHandleBox(i);
        var handleBounds = {
          xmin: box.x,
          xmax: box.x + box.width,
          ymin: box.y,
          ymax: box.y + box.height
        }
        if (that.contains(coords, handleBounds)) {
          that.resizing = true;
          that.selectedHandle = i;
          break;
        }
      }
      that.dispatchEvent(event);
    }
  });

  el.addEventListener("mouseup", function(event) {
    if (that.selected || that.resizing) {
      that.filter(function(r) {
        var o = JSON.parse(r);
        drawResults(o.values);
      });

    }
    that.selected = false;
    that.resizing = false;
  });

  el.addEventListener("mousemove", function(event) {
    var coords = that.getMouse(event);
    var bounds = that.timelapse_.getBoundingBoxForCurrentView();
    var timelapseCoords = {
      x: scale(coords.x, 0, that.canvasLayer_.canvas.width, bounds.xmin, bounds.xmax),
      y: scale(coords.y, 0, that.canvasLayer_.canvas.height, bounds.ymin, bounds.ymax)
    }
    if (that.contains(timelapseCoords, that.bounds_)) {
      that.setCursor(-1);
    } else {
      for (var i = 0; i < that.handles_.length; i++) {
        var box = that.getHandleBox(i);
        var handleBounds = {
          xmin: box.x,
          xmax: box.x + box.width,
          ymin: box.y,
          ymax: box.y + box.height
        }
        if (that.contains(coords, handleBounds)) {
          that.setCursor(i);
          break;
        } else {
          that.$videoDiv.removeClass("selectTopLeft selectUp selectTopRight selectRight selectBottomRight selectDown selectBottomLeft selectLeft selectMove");
        }
      }
    }

    if (that.selected) {
      var x = timelapseCoords.x - that.offset_.x;
      var y = timelapseCoords.y - that.offset_.y;

      that.setBounds( {
        xmin: x - (that.bounds_.xmax - that.bounds_.xmin)/2.,
        xmax: x + (that.bounds_.xmax - that.bounds_.xmin)/2.,
        ymin: y - (that.bounds_.ymax - that.bounds_.ymin)/2.,
        ymax: y + (that.bounds_.ymax - that.bounds_.ymin)/2.
      });
      that.draw();
      event.stopPropagation();
    } else if (that.resizing) {
      var x = timelapseCoords.x; //- that.offset_.x;
      var y = timelapseCoords.y; //- that.offset_.y;

      var newBounds = that.bounds_;
      that.setCursor(that.selectedHandle);
      switch (that.selectedHandle) {
        case 0:
          newBounds.xmin = x;
          newBounds.ymin = y;
          break;
        case 1:
          newBounds.ymin = y;
          break;
        case 2:
          newBounds.ymin = y;
          newBounds.xmax = x;
          break;
        case 3:
          newBounds.xmax = x;
          break;
        case 4:
          newBounds.xmax = x;
          newBounds.ymax = y;
          break;
        case 5:
          newBounds.ymax = y;
          break;
        case 6:
          newBounds.xmin = x;
          newBounds.ymax = y;
          break;
        case 7:
          newBounds.xmin = x;
          break;
      }
      that.setBounds(newBounds);
      that.draw();
      event.stopPropagation();
    }
  });

}

ThumbnailTool.prototype.toggleLayer = function() {
  var thumbnailToolPane = document.getElementById(this.canvasLayer_.getPaneName());
  var thumbnailToolPaneLeftPos = parseInt(thumbnailToolPane.style.left);
  if (thumbnailToolPaneLeftPos < 0) {
    thumbnailToolPane.style.left = thumbnailToolPaneLeftPos + 10000 + "px"
  } else {
    thumbnailToolPane.style.left = thumbnailToolPaneLeftPos - 10000 + "px"
  }
}

ThumbnailTool.prototype.setCursor = function(index) {
  if (index == -1)
    this.$videoDiv.removeClass('closedHand').addClass('selectMove');
  else if (index == 0)
    this.$videoDiv.removeClass('closedHand').addClass('selectTopLeft');
  else if (index == 1)
    this.$videoDiv.removeClass('closedHand').addClass('selectUp');
  else if (index == 2)
    this.$videoDiv.removeClass('closedHand').addClass('selectTopRight');
  else if (index == 3)
    this.$videoDiv.removeClass('closedHand').addClass('selectRight');
  else if (index == 4)
    this.$videoDiv.removeClass('closedHand').addClass('selectBottomRight');
  else if (index == 5)
    this.$videoDiv.removeClass('closedHand').addClass('selectDown');
  else if (index == 6)
    this.$videoDiv.removeClass('closedHand').addClass('selectBottomLeft');
  else if (index == 7)
    this.$videoDiv.removeClass('closedHand').addClass('selectLeft');
}

ThumbnailTool.prototype.dispatchEvent = function(event) {
  if (!this.resizing && !supportsPointerEventsNone) {
    //var hitTargets = document.msElementsFromPoint(event.clientX, event.clientY);
    var timeMachineCanvas = document.getElementById(this.timelapse_.getVideoDivId());
    var thumbnailToolPane = document.getElementById(this.canvasLayer_.getPaneName());
    if (!timeMachineCanvas || parseInt(thumbnailToolPane.style.left) < 0) return;
    event.target = timeMachineCanvas;
    var theMouse = document.createEvent("MouseEvent");
    theMouse.initMouseEvent(event.type, false, true, window, 1, event.screenX, event.screenY, event.clientX, event.clientY, false, false, false, false, 0, null);
    timeMachineCanvas.dispatchEvent(theMouse);
  }
}

ThumbnailTool.prototype.getHandleBox = function(index) {
  var cv = this.timelapse_.getBoundingBoxForCurrentView();
  var box = {};
  if (index == 0) {
    box = {
      x: scale(this.handles_[0].x,cv.xmin, cv.xmax, 0, this.canvasLayer_.canvas.width) - 8,
      y: scale(this.handles_[0].y,cv.ymin, cv.ymax, 0, this.canvasLayer_.canvas.height) - 8,
      width: 7,
      height: 7
    }
  } else if (index == 1) {
    box = {
      x: scale(this.handles_[1].x,cv.xmin, cv.xmax, 0, this.canvasLayer_.canvas.width) - 4,
      y: scale(this.handles_[1].y,cv.ymin, cv.ymax, 0, this.canvasLayer_.canvas.height) - 8,
      width: 7,
      height: 7
    }
   } else if (index== 2) {
     box = {
       x: scale(this.handles_[2].x,cv.xmin, cv.xmax, 0, this.canvasLayer_.canvas.width) + 1,
       y: scale(this.handles_[2].y,cv.ymin, cv.ymax, 0, this.canvasLayer_.canvas.height) - 8,
       width: 7,
       height: 7
     }
   } else if (index == 3) {
     box = {
       x: scale(this.handles_[3].x,cv.xmin, cv.xmax, 0, this.canvasLayer_.canvas.width) + 1,
       y: scale(this.handles_[3].y,cv.ymin, cv.ymax, 0, this.canvasLayer_.canvas.height) - 4,
       width: 7,
       height: 7
     }
   } else if (index == 4) {
     box = {
       x: scale(this.handles_[4].x,cv.xmin, cv.xmax, 0, this.canvasLayer_.canvas.width) + 1,
       y: scale(this.handles_[4].y,cv.ymin, cv.ymax, 0, this.canvasLayer_.canvas.height) + 1,
       width: 7,
       height: 7
     }
   } else if (index == 5) {
     box = {
       x: scale(this.handles_[5].x,cv.xmin, cv.xmax, 0, this.canvasLayer_.canvas.width) - 4,
       y: scale(this.handles_[5].y,cv.ymin, cv.ymax, 0, this.canvasLayer_.canvas.height) + 1,
       width: 7,
       height: 7
     }
   } else if (index == 6) {
     box = {
       x: scale(this.handles_[6].x,cv.xmin, cv.xmax, 0, this.canvasLayer_.canvas.width) - 8,
       y: scale(this.handles_[6].y,cv.ymin, cv.ymax, 0, this.canvasLayer_.canvas.height) + 1,
       width: 7,
       height: 7
     }
   } else {
     box = {
       x: scale(this.handles_[7].x,cv.xmin, cv.xmax, 0, this.canvasLayer_.canvas.width) - 8,
       y: scale(this.handles_[7].y,cv.ymin, cv.ymax, 0, this.canvasLayer_.canvas.height) - 4,
       width: 7,
       height: 7
     }
   }
   return box;
}

ThumbnailTool.prototype.getMouse = function(event) {
  var el = this.canvasLayer_.canvas;
  var offsetX = 0;
  var offsetY = 0;
  var mx;
  var my;

  // Compute the total offset
  if (el.offsetParent !== undefined) {
    do {
      offsetX += el.offsetLeft;
      offsetY += el.offsetTop;
    } while ((el = el.offsetParent));
  }

  mx = event.pageX - offsetX;
  my = event.pageY - offsetY;

  return {x: mx, y: my};
}

ThumbnailTool.prototype.contains = function(point, bounds) {
  return ((point.x >= bounds.xmin && point.x <= bounds.xmax) && (point.y >= bounds.ymin && point.y <= bounds.ymax));
}

ThumbnailTool.prototype.draw = function() {
  var cv = this.timelapse_.getBoundingBoxForCurrentView();
  var v = this.timelapse_.getView();
  this.ctx_.clearRect(0,0,this.canvasLayer_.canvas.width, this.canvasLayer_.canvas.height)
  this.ctx_.strokeStyle = 'rgb(0,255,0)';
  this.ctx_.beginPath();
  this.ctx_.strokeRect(scale(this.bounds_.xmin,cv.xmin, cv.xmax, 0, this.canvasLayer_.canvas.width),scale(this.bounds_.ymin,cv.ymin, cv.ymax, 0, this.canvasLayer_.canvas.height),(this.bounds_.xmax-this.bounds_.xmin)*v.scale,(this.bounds_.ymax - this.bounds_.ymin)*v.scale);
  this.ctx_.fillStyle = 'rgb(0,255,0)';

  for (var i = 0; i < this.handles_.length; i++) {
    var box = this.getHandleBox(i);
    this.ctx_.fillRect(box.x, box.y, box.width, box.height);
  }
}

ThumbnailTool.prototype.erase = function() {
  this.ctx_.clearRect(0,0,this.canvasLayer_.canvas.width, this.canvasLayer_.canvas.height)
}


ThumbnailTool.prototype.update = function() {
  if (this.bounds_.xmin != undefined) {
    this.draw();
  }
}

ThumbnailTool.prototype.resize = function() {
}

ThumbnailTool.prototype.setBounds = function(bounds) {
  this.bounds_ = bounds;
  this.handles_[0] = {
    x: this.bounds_.xmin,
    y: this.bounds_.ymin
  };
  this.handles_[1] = {
    x: this.bounds_.xmin + (this.bounds_.xmax - this.bounds_.xmin)/2.,
    y: this.bounds_.ymin
  };
  this.handles_[2] = {
    x: this.bounds_.xmax,
    y: this.bounds_.ymin
  };
  this.handles_[3] = {
    x: this.bounds_.xmax,
    y: this.bounds_.ymin + (this.bounds_.ymax - this.bounds_.ymin)/2.
  };
  this.handles_[4] = {
    x: this.bounds_.xmax,
    y: this.bounds_.ymax
  };
  this.handles_[5] = {
    x: this.bounds_.xmin + (this.bounds_.xmax - this.bounds_.xmin)/2.,
    y: this.bounds_.ymax
  };
  this.handles_[6] = {
    x: this.bounds_.xmin,
    y: this.bounds_.ymax
  };
  this.handles_[7] = {
    x: this.bounds_.xmin,
    y: this.bounds_.ymin + (this.bounds_.ymax - this.bounds_.ymin)/2.
  };

}

ThumbnailTool.prototype.filter = function(callback) {
  var el = document.getElementById('chart');
  el.style['background'] = "url('assets/ajax-loader.gif') #fff center no-repeat";
    if (typeof chart != "undefined") {
      chart.clearChart();
    }
  var config = {
    'host': 'http://timemachine-api.bodytrack.org/thumbnail'
  };
  var args = {
    'root': this.timelapse_.getSettings().url,
    'boundsLTRB': this.bounds_.xmin + "," + this.bounds_.ymin + "," + this.bounds_.xmax + "," + this.bounds_.ymax,
    'width': this.bounds_.xmax - this.bounds_.xmin,
    'height': this.bounds_.ymax - this.bounds_.ymin,
    'nframes': this.timelapse_.getDatasetJSON().frames,
    'filter': 'difference-filter',
    'format': 'rgb24',
    'tileFormat': this.timelapse_.getSettings().mediaType.slice(1)
  }

  var t = new ThumbnailServiceAPI(config, args);
  if (this.requestMade) {
    this.xhr.abort();
  }
  this.requestMade = true;

  var that = this;

  if (window.XDomainRequest) {
    this.xhr = new XDomainRequest();
    this.xhr.onload = function() {
      if (that.xhr.responseText != "") {
        requestMade = false;
        callback(that.xhr.responseText);
      }
    }
  } else if (window.XMLHttpRequest) {
    this.xhr = new XMLHttpRequest();
    this.xhr.onreadystatechange = function() {
      if (that.xhr.readyState == 4) {
        requestMade = false;
        if (that.xhr.response != "") {
          callback(that.xhr.response);
        }
      }
    }
  }
  this.xhr.open('GET', t.serialize(), true);
  this.xhr.send();
}

ThumbnailTool.prototype.getCurrentThumbnail = function() {
  var v = this.timelapse_.getView();
  var config = {
    'host': 'http://timemachine-api.bodytrack.org/thumbnail'
  };
  var args = {
    'root': this.timelapse_.getSettings().url,
    'boundsLTRB': this.bounds_.xmin + "," + this.bounds_.ymin + "," + this.bounds_.xmax + "," + this.bounds_.ymax,
    'width': (this.bounds_.xmax-this.bounds_.xmin)*v.scale,
    'height': (this.bounds_.ymax-this.bounds_.ymin)*v.scale,
    'frameTime': this.timelapse_.getCurrentFrameNumber()/this.timelapse_.getFps(),
    'format': 'png',
    'tileFormat': this.timelapse_.getSettings().mediaType.slice(1)
  }
  var t = new ThumbnailServiceAPI(config, args);
  return(t.serialize());
}

ThumbnailTool.prototype.getCurrentGif = function() {
  var v = this.timelapse_.getView();
  var config = {
    'host': 'http://timemachine-api.bodytrack.org/thumbnail'
  };
  var args = {
    'root': this.timelapse_.getSettings().url,
    'boundsLTRB': this.bounds_.xmin + "," + this.bounds_.ymin + "," + this.bounds_.xmax + "," + this.bounds_.ymax,
    'width': (this.bounds_.xmax-this.bounds_.xmin)*v.scale,
    'height': (this.bounds_.ymax-this.bounds_.ymin)*v.scale,
    'frameTime': this.timelapse_.getCurrentFrameNumber()/this.timelapse_.getFps(),
    'nframes': 10,
    'format': 'gif',
    'tileFormat': this.timelapse_.getSettings().mediaType.slice(1)
  }
  var t = new ThumbnailServiceAPI(config, args);
  return(t.serialize());
}

var data = [];
var chart;
function drawResults(response) {
  data = [];
  data.push(['x','results']);
  for (var i = 0; i < response.length; i++) {
    var date = new Date(timelapse.getCaptureTimes()[i]);
    data.push([date, response[i]]);
  }
  chart = new google.visualization.LineChart(document.getElementById('chart'));
  var options = {
    hAxis: {
      gridlines: {
        count:12
      }
    },
    vAxis : {
      textPosition: 'none',
      title: 'Amount of Change',
      minValue: 0,
      viewWindow: {
        min: 0
      }
    },
    chartArea: { left: 40, top: 0, width: "100%", height: "80%"},
    legend: 'none',
    curveType: 'function',
    'tooltip' : {
      trigger: 'none'
    }
  }
  data = google.visualization.arrayToDataTable(data);
  chart.draw(data, options);
  chart.setSelection([{column: 1, row: thumbnailTool.timelapse_.getCurrentFrameNumber()}]);

  google.visualization.events.addListener(chart, 'select', function() {
    var selection = chart.getSelection()[0];
    if (typeof selection != "undefined") {
      var frame = selection.row;
      thumbnailTool.timelapse_.seekToFrame(frame);
      timelapse.setPlaybackRate(0.50, true, false);
    }
  });

  thumbnailTool.timelapse_.addTimeChangeListener(function() {
    chart.setSelection([{column: 1, row: thumbnailTool.timelapse_.getCurrentFrameNumber()}]);
  });
}
