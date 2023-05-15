var shadowCss = {'-moz-box-shadow': '0px 2px 6px rgba(0,0,0,.3)',
'-webkit-box-shadow': '0px 2px 6px rgba(0,0,0,.3)',
'box-shadow': '0px 2px 6px rgba(0,0,0,.3)'};

var noShadowCss = {'-moz-box-shadow': '',
'-webkit-box-shadow': '',
'box-shadow': ''};
var j;

jQuery(document).ready(function(){
//  console.log("nav: ready");
  j = jQuery;
  j(".subnav").hide();

  j("#parentnav li").hover(function(){
    j(".subnav", this).show();
    j(".navitem", this).css({'background-color':'#464646', 'color':'#fff'});
    j(".navcurve", this).show();
  }, function(){
    j(".subnav", this).hide();
    j(".navitem", this).css({'background-color':'', 'color':'#00ccff'});
    j(".navcurve", this).hide();
  });

  /*
  j("#nav-act").parent().hover(function(){
    j("#subnav").show();
    j("#nav-act").css({'background-color':'#464646', 'color':'#fff'});
    j("#navcurve").show();
  }, function(){
    j("#subnav").hide();
    j("#nav-act").css({'background-color':'', 'color':'#00ccff'});
    j("#navcurve").hide();
  });*/

  loadEnormousBackgroundImage();

  //init signup form
  initForm();

  if(jQuery.browser.msie && jQuery.browser.version < 9){
    fixPNGs();
    fixIE8Buttons();
  //  setTimeout( fixIE8BoxPositions, 2000 );
  }
});

function fixIE8BoxPositions(){
  jQuery(window).resize();
}

function fixIE8Buttons(){

  j("a button").each(function(){
    var btn = j(this);
    var hrefValue = btn.parent().attr("href");

    if(hrefValue){
      //clog("button " + btn + " href = " + hrefValue);
      btn.click(function(){
        window.location = hrefValue;
      });
    }



  });
}



function loadEnormousBackgroundImage() {
        // TODO
        jQuery("html").addClass("complete");
        return;

  var el = jQuery('<div class="bg"></div>'), body = jQuery(document.body);
  el.css({
    opacity : 0,
    background: 'url(/wp-content/themes/customtheme/images/bg.jpg) top center no-repeat'
  });
  body.append(el);
  jQuery.ajax({
    method : "GET",
    url : '/wp-content/themes/customtheme/images/bg.jpg',
    complete : function() {
      callback.call(this);
    }
  });
  var callback = function(e) {
    el.animate({
      opacity: 1
    }, 1000, function() {
      jQuery("html").addClass("complete");
      el.remove();
      //jQuery(window).unbind("scroll"); // F this it breaks the lightbox centering.
    });
  };
}

function fixPNGs(){

  var i;
  //alert(document.images.length);
  for(i in document.images){
    if(document.images[i].src){
      var imgSrc = document.images[i].src;
      if(imgSrc.substr(imgSrc.length-4) === '.png' || imgSrc.substr(imgSrc.length-4) === '.PNG'){
        document.images[i].style.filter = "progid:DXImageTransform.Microsoft.AlphaImageLoader(enabled='true',sizingMethod='crop',src='" + imgSrc + "')";
      }
    }
  }

}

// HTML5 Placeholder support for older browsers
jQuery(function() {
  jQuery.support.placeholder = false;
  test = document.createElement('input');
  if('placeholder' in test) jQuery.support.placeholder = true;
});

 jQuery(function() {
  if(!jQuery.support.placeholder) {
    jQuery('[placeholder]').focus(function() {
      var input = jQuery(this);
      if (input.val() == input.attr('placeholder')) {
      input.val('');
      input.removeClass('placeholder');
      }
    }).blur(function() {
      var input = jQuery(this);
      if (input.val() == '' || input.val() == input.attr('placeholder')) {
      input.addClass('placeholder');
      input.val(input.attr('placeholder'));
      }
    }).blur();
    jQuery('[placeholder]').parents('form').submit(function() {
      jQuery(this).find('[placeholder]').each(function() {
      var input = jQuery(this);
      if (input.val() == input.attr('placeholder')) {
        input.val('');
      }
      })
    });
  }
});



//---------------------------------------------//
//     SIGNUP FORM
//---------------------------------------------//

jQuery.validator.addMethod("fullNameIsValid", function(value, element) {
  clog("custom validator fullNameIsValid - v: "+ value + " e: " + element);
    return this.optional(element) || (value != "FULL NAME");
}, "");


function initForm() {

//  clog("nav.js: initForm");

  j('#join-coalition-btn').click(function() {
    if( j(this).closest('#footer_container').length > 0 ) j('#formText').fadeOut();
      if(winWidth>1006){
            j('html,body').animate({scrollTop: j('#join_us_content').offset().top},2000);
      }else{
        jQuery.sidr('open', 'sidr-right');
        }
      j('#join_us_content ul').fadeOut(function() {
      j('#joinForm').fadeIn();
    });
    return false;
  });

  j('#join-individual a').click(function() {
    if( j(this).closest('#footer_container').length > 0 ) j('#formText').fadeOut();
    j(this).parent().parent().fadeOut(function() {
      j('#joinForm').fadeIn();
    });
    return false;
  });


  j("#submitbutton").removeAttr('disabled');
  j("#footer_errorContainer").text("");
  j.ajaxSetup({cache:false});
  j("#joinForm").validate({

    errorLabelContainer: "#footer_errorContainer",
    rules: {

      join_fullname: { fullNameIsValid:true },
      join_zipcode: { required:true, digits:true },
      join_email: { required:true, email:true },
      join_emailconfirm: { required:true, email:true, equalTo:"#join_email" },
      join_check:{ required:true }
    },
    messages:{
      join_zipcode: "",
      join_email: "",
      join_emailconfirm: "",
      join_check: ""
    },

    invalidHandler: function(form, validator) {
      j("#footer_errorContainer").text("valid name & email are required.");
      if( j("#join_check").attr('checked') != "checked") j("#footer_errorContainer").text("Checkbox is required.");
    },

    submitHandler: function(form) {
      //clog("nav.js: submitHandler");
      var data = {
        "fullname":j("#join_fullname").val(),
        "email":j("#join_email").val(),
        "zip":j("#join_zipcode").val()
      };

      j.post(templateDir+'/form/store-address.php', data, function(resultData){
        clog("post result: " + resultData);

        if(resultData.indexOf("success") != -1){
          j("#formText").hide();
          j("#formThankYou").show();
          j("#joinForm").hide();
          clog(" ... Success");

        }else if(resultData.indexOf("already subscribed") != -1 ){
          alert("We already have you in our database. If you're having problems, please email info@breatheproject.org.");
        }else{
          alert("There was a problem submitting your information. Please try again later.  If you're having problems, please email info@breatheproject.org.");
        }

      }).error(function(error){
        clog("---- post error ----");
        clog(error);
        alert("There was a problem submitting your information. Please try again later");
      });


    }
  })


  // Fullname -------------------------------------------
  j("#join_fullname").focus(function(){
    if ( j("#join_fullname").attr("value") == "FULL NAME" ) j("#join_fullname").attr("value","");
  });

  j("#join_fullname").blur(function(){
    if ( j("#join_fullname").attr("value") == "" ) j("#join_fullname").attr("value","FULL NAME");
  });

  // Email ----------------------------------------------
  j("#join_email").focus(function(){
    if ( j("#join_email").attr("value") == "YOUR EMAIL" ) j("#join_email").attr("value","");
  });

  j("#join_email").blur(function(){
    if ( j("#join_email").attr("value") == "" ) j("#join_email").attr("value","YOUR EMAIL");
  });

  // Email Confirm ----------------------------------------------
  j("#join_emailconfirm").focus(function(){
    if ( j("#join_emailconfirm").attr("value") == "CONFIRM EMAIL" ) j("#join_emailconfirm").attr("value","");
  });

  j("#join_emailconfirm").blur(function(){
    if ( j("#join_emailconfirm").attr("value") == "" ) j("#join_emailconfirm").attr("value","CONFIRM EMAIL");
  });

  // Zip Code ----------------------------------------------
  j("#join_zipcode").focus(function(){
    if ( j("#join_zipcode").attr("value") == "ZIP CODE" ) j("#join_zipcode").attr("value","");
  });

  j("#join_zipcode").blur(function(){
    if ( j("#join_zipcode").attr("value") == "" ) j("#join_zipcode").attr("value","ZIP CODE");
  });
}


function loadLatestPostsData(_type, _targetElement) {
//  clog("loadLatestPostsData...");
  var data = {"type":_type};

  j.post('/news/wp-content/themes/customtheme/ajax-feeds.php', data, function(resultData){
    //clog(resultData);
    _targetElement.html( resultData );
    //return resultData;
    if(_type == "events"){
      //Cufon.replace("#event_icon");
      //Cufon.replace("#event_boxtitle");

      //if(j("#upcoming_event").length > 0) j("#upcoming_event").addClass("roundedsquare");
    }
  }).error(function(error){
    //clog("---- post error ----");
    //alert("There was a problem submitting your information. Please try again later");
    _targetElement.html( "Problem loading news data. Please try again later." );
  });



}


