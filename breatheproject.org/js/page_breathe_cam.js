var $iframe = jQuery("#breathe-cam");
var $window = jQuery(window);
var iframeRootUrl = $iframe.attr("src");
var iframeOrigin = iframeRootUrl.substring(0, iframeRootUrl.lastIndexOf('/'));
var hashVar = window.location.hash;
var iframeUrl = hashVar ? iframeRootUrl + hashVar : iframeRootUrl;
$iframe.attr("src", iframeUrl);
var originalIframeHeight = $iframe.height();
var wideScreen = true;
var preFillScreenIframeCSS = {};
var fillScreen = false;

function receiveMessage(event) {
  event = event.originalEvent ? event.originalEvent : event;
  if (event.origin === iframeOrigin) {
    if (!event.type) return;
    if (event.data)
      data = JSON.parse(event.data);
    if (data.type == "resize_iframe") {
      if (data.data.fillScreen) {
        var $body = jQuery("body");
        $window.scrollTop(0);
        if ($body.css("overflow") == "hidden") {
          $body.css("overflow", "auto");
          $iframe.css({
            width: "100%",
            height: preFillScreenIframeCSS.height,
            top: preFillScreenIframeCSS.top,
            left: preFillScreenIframeCSS.left,
            position: preFillScreenIframeCSS.position,
            zIndex: preFillScreenIframeCSS.zIndex
          });
          resizeBreathecamContainer();
        } else {
          $body.css("overflow", "hidden");
          preFillScreenIframeCSS = {
            width: $iframe.css("width"),
            height: $iframe.css("height"),
            top: $iframe.css("top"),
            left: $iframe.css("left"),
            position: $iframe.css("position"),
            zIndex: $iframe.css("zIndex")
          };
          $iframe.css({
            width: $window.width() + 6,
            height: $window.height() + 3,
            top: "0px",
            left: "0px",
            position: "fixed",
            zIndex: "9001"
          });
        }
        fillScreen = !fillScreen;
      } else if (data.data.height) {
        var newHeight = $iframe.height() + data.data.height;
        $iframe.height(newHeight);
        if (data.data.persist)
          originalIframeHeight = newHeight;
      }
    } else if (data.type == "clear_hash") {
      if (window.location.hash)
        window.location.hash = "";
      $iframe.height(originalIframeHeight + data.data.changeDetectHeight);
    } else if (data.type == "set_share_links") {
      jQuery('[data-breathe-cam-view]').each(function() {
        var $shareContainer = jQuery(this);
        var shareView = $shareContainer.data('breathe-cam-view');
        $shareContainer.wrap("<a href='#breathe-cam' class='breathe-cam-view-link' title='Click to explore this view'></a>");
      });
    }
  }
}

function resizeBreathecamContainer() {
  //var viewerContainer = document.querySelector(".col-3");
  //var referenceContainer = document.querySelector(".col-1");
  var viewerContainer = jQuery(".col-3")[0];
  var referenceContainer = jQuery(".col-1")[0];
  viewerContainer.style.width = document.body.offsetWidth + "px";
  viewerContainer.style.marginLeft = (-1 * referenceContainer.getBoundingClientRect().left) + "px";
}

function isMobile() {
  var navAgent = navigator.userAgent;
    return (navAgent.match(/Android/i) || navAgent.match(/webOS/i) || navAgent.match(/iPhone/i) || navAgent.match(/iPad/i) || navAgent.match(/iPod/i) || navAgent.match(/BlackBerry/i) || navAgent.match(/Windows Phone/i) || navAgent.match(/Opera Mini/i) || navAgent.match(/IEMobile/i));
}

function setViewOnBreatheCam(newView) {
  $iframe.attr("src", iframeRootUrl + newView);
}

$window.resize(function() {
  if (fillScreen) {
    $iframe.css({
      width: $window.width() + 6,
      height: $window.height() + 3
    });
  }
  resizeBreathecamContainer();
});

jQuery(function() {
  if (isMobile()) {
    $iframe.css("min-width", "100px !important");
    jQuery("#breathe-cam-container").css("min-width", "100px !important");
    jQuery("#navbar").css("top", "-8px");
    jQuery("#breathe-meter-top").css("padding-top", "50px");
    jQuery("#share").css({"position" : "relative", "top" : "66px", "right" : "0px"});
  } else {
    jQuery("#breathe-cam").css("min-width", "580px");
    jQuery("#breathe-cam-container").css("min-width", "592px");
    jQuery("#share").hide();
    jQuery("#navbar").css("top", "-8px");
  }
  resizeBreathecamContainer();
  jQuery(".content_toggle").click(function() {
      jQuery(this).parent().find(".collapsible").slideToggle();
      jQuery(this).toggleClass("toggle-collapse");
      if (jQuery(this).hasClass("toggle-collapse")) {
        jQuery(this).find(".collapse-expand").text("-");
      } else {
        jQuery(this).find(".collapse-expand").text("+");
      }
      return false;
  });
  jQuery("body").on("click", ".breathe-cam-view-link", function() {
    var shareView = jQuery(this).children().data('breathe-cam-view');
    shareView = "#v=" + shareView;
    setViewOnBreatheCam(shareView);
  });
});

jQuery(window).on("message onmessage", receiveMessage);