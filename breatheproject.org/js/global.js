var lineheight = jQuery('#meter-lines').height();
var heightconversion = lineheight / 100;
var dirtNumber = jQuery("#select-city option:nth-child(2)").val();
var percentage = lineheight - (dirtNumber*heightconversion);
var pghDirtNumber = 12.9;
var pghPercentage = lineheight - (pghDirtNumber*heightconversion);
var cityName = 'New York, NY';
var dirtNumber = 47.3;
var id = ['',1];
var ua = navigator.userAgent;
var clevent = (ua.match(/iPad/i)) ? "touchstart" : "click";
var winWidth = jQuery(window).width();
var toggles = [];
var ssArchive = false;
toggles['currentmenu'] = false;
toggles['currentmenu_interval'] = '';
toggles['currentmenu_attempt'] = 0;
var resize;

jQuery(window).resize(function(){
  clearTimeout(resize);
    resize = setTimeout(doneResizing, 250);
});
jQuery(document).ready(function(){
  aboutScrollBar();
  alignNavHash();
  moveJoinForm();
  initMobileNav();
  hpBoxMobileMove();
  bottomAlignBars();
  initGraphBars();
  matchBoxHeight();
  bottomAlignButtons();

  /*var intervalID = setInterval(function () {

     matchBoxHeight();

     if (++matchInterval === 5) {
       window.clearInterval(intervalID);
     }
  }, 1000);

  var intervalID = setInterval(function () {

     bottomAlignButtons();

     if (++buttonInterval === 5) {
       window.clearInterval(intervalID);
     }
  }, 1000);*/

  jQuery.ajax({
    'async': false,
    'global': false,
    'url': '../../wp-content/themes/breathe2014responsive/airdata.json',
    'dataType': 'json',
    'success': function (data) {
     processEverything(data);
    }
     });
  jQuery('#meter-right .city-name').text(cityName);
  jQuery('#pgh-number').text(pghDirtNumber+"%");
  jQuery('#city-number').text(dirtNumber+"%");
  animateMeter();
  jQuery('#home-news-feed .gray-area:even').css('background','url("images/transparent-bg.png")');
  jQuery('#events-list .gray-area:even').css('background','url("images/transparent-bg.png")');
  jQuery('#industry-story .gray-area:even').css('background','url("images/transparent-bg.png")');
  jQuery('#testimonialPages .testimonial:even').css('background','#4F5457');
  jQuery('.cff-item:even').css('background','url("images/transparent-bg.png")');
  jQuery('#businessActions-1').fadeIn(500);
  jQuery('#govActionsBottom-1').fadeIn(500);
  if(winWidth<1007){
    jQuery('#howYouCanHelp .gray-area').css('height','auto');
    jQuery('#howYouCanHelp .content-block').css('height','auto');
    }else{}
  if(winWidth<1006){
    jQuery('#navhash').hide();
  }else{
    jQuery('#navhash').fadeIn(500);
    }
})
.on("mouseenter", ".top-level-nav", function() {
  var submenuWidth = jQuery(this).width();
  jQuery(this).children('.submenu').css('min-width',submenuWidth+'px');
  jQuery(this).addClass('active-nav');
  jQuery(this).children('.submenu').stop().slideDown(200);
})
.on("mouseleave", ".top-level-nav", function() {
  jQuery(this).children('.submenu').stop().slideUp(200, function(){
  jQuery(this).parent('.top-level-nav').removeClass('active-nav');
  });
})
.on("change", "#select-city", function() {
  cityName = jQuery("#select-city option:selected").text();
  dirtNumber = jQuery("#select-city option:selected").val();
  jQuery('#meter-right .city-name').text(cityName);
  jQuery('#city-number').text(dirtNumber+"%");
  animateMeter();
})
.on("click", "#business-act-icons .act-icons", function() {
  id = jQuery(this).attr('id').split('-');
  jQuery('.act-center-content').hide();
  jQuery('.gov_bottom').hide();
  jQuery('#govActionsBottom-'+id[1]).fadeIn(500);
  jQuery('#businessActions-'+id[1]).fadeIn(500);
  jQuery(".act-icons").each(function(){
    jQuery(this).find("img").attr("src", jQuery(this).find("img").attr("src").replace("orange", "gray"));
  });
  jQuery(this).children('img').attr('src', jQuery(this).children('img').attr('src').replace('gray','orange'));
  return false;
})
.on("click", "#gov-act-icons .act-icons", function() {
  id = jQuery(this).attr('id').split('-');
  jQuery('.act-center-content').hide();
  jQuery('.gov_bottom').hide();
  jQuery('#govActionsBottom-'+id[1]).fadeIn(500);
  jQuery('#businessActions-'+id[1]).fadeIn(500);
  jQuery(".act-icons").each(function(){
    jQuery(this).find("img").attr("src", jQuery(this).find("img").attr("src").replace("purple", "gray"));
  });
  jQuery(this).children('img').attr('src', jQuery(this).children('img').attr('src').replace('gray','purple'));
  return false;
})
.on("click", "#business-section #act-nav-right", function() {
  id[1]++;
  actArrowNav();
})
.on("click", "#business-section #act-nav-left", function() {
  id[1] --;
  actArrowNav();
})
.on("click", "#gov-section #act-nav-right", function() {
  id[1]++;
  govArrowNav();
})
.on("click", "#gov-section #act-nav-left", function() {
  id[1] --;
  govArrowNav();
})
.on("change", "#archive-month", function(){
  if(jQuery(this).val() != '' && jQuery(this).val() != 0){
    window.open(jQuery(this).val(), "_top");
  }
})
.on("mouseover", ".bar-col", function(){
  simple_tooltip(".bar-col","tooltip");
})
.on("click", "#sidr-right .mobileNavDD", function(){
  jQuery(this).parent('.navitem').siblings().find('.sub-menu').slideUp();
  jQuery(this).parent('.navitem').find('.sub-menu').slideToggle();
})
.on("click", ".closeInfo", function(){
  return false;
  my_tooltip.stop().fadeOut(400);
})
.on("click", "#ssArchiveLink", function(){
  ssArchive = true;
  jQuery('#ssVisible').slideUp(400, function(){
    jQuery('#ssArchive').slideDown(400);
    jQuery('#ssTitle').html('Success Story Archives');
  });
  jQuery('html,body').animate({scrollTop: jQuery('#ssTitle').offset().top},1000);
})
.on("click", "#ssArchiveBackLink", function(){
  ssArchive = false;
  jQuery('#ssArchive').slideUp(400, function(){
    jQuery('#ssVisible').slideDown(400);
    jQuery('#ssTitle').html('Success Stories');
  });
  jQuery('html,body').animate({scrollTop: jQuery('#ssTitle').offset().top},1000);

})
.on("click", ".ssLatest", function(){
  ssArchive = false;
  jQuery(this).parent('div').slideUp(400, function(){
    jQuery('#ssVisible').slideDown(400);
    jQuery('#ssTitle').html('Success Stories');
  });
  jQuery('html,body').animate({scrollTop: jQuery('#ssTitle').offset().top},1000);

})
.on("click", "#right-menu", function(){
  return false;
})
.on("click", ".ssReadMore", function(){
  jQuery(this).parent('span').slideUp(400, function(){
  jQuery(this).parent('.gray-area').find('.ss-content').slideDown(400);
  });
  event.preventDefault();
})
.on("click", ".ssClose", function(){
  jQuery(this).parent('.ss-content').slideUp(400, function(){
  jQuery(this).parent('.gray-area').find('.ss-excerpt').slideDown(400);
  });
  event.preventDefault();
})
.on(clevent, "#container", function(){
  jQuery.sidr('close', 'sidr-right');
})
;

function filterSuccess(){
  var successCat = "#"+jQuery('option:selected').attr('value');
  if(ssArchive){
    jQuery('#ssArchive').slideUp(400, function(){
      jQuery(successCat).siblings('div').slideUp(500);
      jQuery(successCat).slideDown(500);
    });
    }else{
      jQuery('#ssVisible').slideUp(400, function(){
        jQuery(successCat).siblings('div').slideUp(500);
        jQuery(successCat).slideDown(500);
      });
    }
}

function doneResizing(){
  winWidth = jQuery(window).width();
  animateMeter();
  moveJoinForm();
  alignNavHash();
  hpBoxMobileMove();
  matchBoxHeight();
  moveJoinForm();
  bottomAlignButtons();
  if(winWidth<1006){
    jQuery('#navhash').hide();
    }else{
    jQuery('#navhash').fadeIn(500);
    }
}
function aboutScrollBar(){
if(winWidth>1006){
  jQuery('#coalition_scrollbar').tinyscrollbar({ size:780, sizethumb:88 });
  }else{
    jQuery('#coalition_scrollbar').tinyscrollbar({ size:300, sizethumb:88 });
    }

}
function alignNavHash(){
  toggles['currentmenu_interval'] = setInterval(function(){
    if(toggles['currentmenu'] === false){
      if(jQuery('#parentnav > li > a.current_page_item').length > 0 || jQuery('#parentnav > li > a.current_page_parent').length > 0 || jQuery('#parentnav > li > a.current-menu-parent').length > 0){
        var hashWidth = jQuery('#navhash').width()/2;
        var menuPosition;
        var menuWidth;
        var hit = false;
        if(jQuery('#parentnav > li > a.current_page_item').length > 0){
          menuPosition = jQuery('#parentnav > li > a.current_page_item').parent('li').position().left;
          menuWidth = jQuery('#parentnav > li > a.current_page_item').parent('li').width()/2;
          hit = true;
        } else if(jQuery('#parentnav > li > a.current_page_parent').length > 0){
          menuPosition = jQuery('#parentnav > li > a.current_page_parent').parent('li').position().left;
          menuWidth = jQuery('#parentnav > li > a.current_page_parent').parent('li').width()/2;
          hit = true;
        } else if(jQuery('#parentnav > li > a.current-menu-parent').length > 0){
          menuPosition = jQuery('#parentnav > li > a.current-menu-parent').parent('li').position().left;
          menuWidth = jQuery('#parentnav > li > a.current-menu-parent').parent('li').width()/2;
          hit = true;
        }
        if(hit&&winWidth>1007){
          jQuery('#navhash').css('left',menuPosition+menuWidth-hashWidth);
          jQuery('#navhash').fadeIn(500);
          toggles['currentmenu'] = true;
        }
      }
    } else {
      clearInterval(toggles['currentmenu_interval']);
    }
    toggles['currentmenu_attempt']++;
    if(toggles['currentmenu_attempt'] > 10){
      clearInterval(toggles['currentmenu_interval']);
    }
  }, 1000);
}

function initGraphBars(){
  var ton=0;
  var tonNumber=0;
  var totalNumber=0;
  jQuery(".bar-col").each(function(){
     ton = jQuery(this).find('.em-tons').html();
     tonNumber = parseFloat(ton);
     if(tonNumber==0){

     }else if(tonNumber>290){
       jQuery(this).find('.blue-bar').animate({'height':290+'px'}, 1000)
       }else{
         jQuery(this).find('.blue-bar').animate({'height':tonNumber*2+'px'}, 1000)
         }
     totalNumber += tonNumber;
  }
  );
  jQuery('#tot-em-number strong span').html(totalNumber);
  jQuery('#tot-em-number strong').show(2000);
}


function initMobileNav(){
   jQuery("#sidr-right .navitem").each(function(){
   if(jQuery(this).find('.sub-menu').length){
    jQuery(this).prepend('<a href="#" class="mobileNavDD"></a>');
     }else{
       }
    });
}

function moveJoinForm(){
  winWidth = jQuery(window).width();
  if(winWidth<1006){
    jQuery("#joinForm").appendTo("#mobileIndividualForm");
    }else{
    jQuery("#joinForm").appendTo("#individualForm");
    }
}

function hpBoxMobileMove(){
  winWidth = jQuery(window).width();
  if(winWidth<1006&&winWidth>750){
    jQuery('#breath-meter').addClass('row-2');
    jQuery('#breath-meter').addClass('homepage-col-1');
    matchBoxHeight();
    bottomAlignButtons();
    }else{
      jQuery('#breath-meter').removeClass('row-2');
      jQuery('#breath-meter').removeClass('homepage-col-1');
      jQuery('#breath-meter').css('height','auto');
      jQuery('#breath-meter a').css('top',0+"px");
      jQuery('#breath-meter a').css('position','relative');
      }
}
function simple_tooltip(target_items, name){
 jQuery(target_items).each(function(i){
    jQuery("body").append("<div class='"+name+"' id='"+name+i+"'><p>"+jQuery(this).find('.tooltip-html').html()+"</p></div>");
    var my_tooltip = jQuery("#"+name+i);
    if(jQuery(this).attr("title") != ""){ // checks if there is a title
    jQuery(this).removeAttr("title").mouseover(function(){
        my_tooltip.stop().css({opacity:1, display:"none"}).fadeIn(400);
    }).mousemove(function(kmouse){
      if(winWidth>1007){

        my_tooltip.css({left:kmouse.pageX-370, top:kmouse.pageY-50});
      }else{
        my_tooltip.css({left:winWidth/2-125+'px', top:kmouse.pageY-50});
        }
    }).mouseout(function(){
        my_tooltip.stop().fadeOut(400);
    });
    }
  });
}

function bottomAlignBars(){
var windowHeight = jQuery("#industry-bars").height();
jQuery('#industry-bars').show()
jQuery(".bar-col").each(function(){
  jQuery(this).css({
    /*"position": "absolute",
    "top": windowHeight-jQuery(this).height()*/
  });
});

}

function bottomAlignButtons(){
  if(winWidth<750){
    jQuery(".homepage-col-1 .blue-btn").each(function(){
      jQuery(this).css({
        "position": "relative",
        "top": "0px"
      });
    });
    }else{
      //alert('Not mobile. Window width is '+winWidth);
      var parentHeight = jQuery(".homepage-col-1").height();
      var parentWidth = jQuery(".homepage-col-1").width()/2;
      jQuery(".homepage-col-1 .blue-btn").each(function(){
      jQuery(this).css({
        "position": "absolute",
        "top": parentHeight-jQuery(this).height()-5+"px"
        });
      });
      //clearInterval();
      }
}
function actArrowNav(){
  var countIcons = jQuery('#act-icon-container a').length;
  if(id[1]>countIcons){
    id[1]=1;
  }else if(id[1]<1){
    id[1]=countIcons;
    }
  jQuery('.act-center-content').hide();
  jQuery('.gov_bottom').hide();
  jQuery('#businessActions-'+id[1]).fadeIn(500);
  jQuery('#govActionsBottom-'+id[1]).fadeIn(500);
  jQuery(".act-icons").each(function(){
    jQuery(this).find("img").attr("src", jQuery(this).find("img").attr("src").replace("orange", "gray"));
  });
  jQuery('#actIcon-'+id[1]).children('img').attr('src', jQuery('#actIcon-'+id[1]).children('img').attr('src').replace('gray','orange'));

  return false;
}


function govArrowNav(){
  var countIcons = jQuery('#act-icon-container a').length;
  if(id[1]>countIcons){
    id[1]=1;
  }else if(id[1]<1){
    id[1]=countIcons;
    }
  jQuery('.act-center-content').hide();
  jQuery('.gov_bottom').hide();
  jQuery('#businessActions-'+id[1]).fadeIn(500);
  jQuery('#govActionsBottom-'+id[1]).fadeIn(500);
  jQuery(".act-icons").each(function(){
    jQuery(this).find("img").attr("src", jQuery(this).find("img").attr("src").replace("purple", "gray"));
  });
  jQuery('#actIcon-'+id[1]).children('img').attr('src', jQuery('#actIcon-'+id[1]).children('img').attr('src').replace('gray','purple'));

  return false;
}

function matchBoxHeight(){
  winWidth = jQuery(window).width();

  if(winWidth<750){
    jQuery('.gray-area').css('height','auto');
    jQuery('.row-2').css('height','auto');
    }else{
       //Set height for boxes in row 1
       var row1maxHeight = 0;
       jQuery('.row-1').find('.gray-area').each(function() {
       row1maxHeight = row1maxHeight > jQuery(this).height() ? row1maxHeight : jQuery(this).height();
       });
       jQuery('.row-1').find('.gray-area').each(function() {
       jQuery(this).height(row1maxHeight);
       });
       //Set height for boxes in row 2
       var row2maxHeight = 0;
       jQuery('.row-2').each(function() {
       row2maxHeight = row2maxHeight > jQuery(this).height() ? row2maxHeight : jQuery(this).height();
       });
       jQuery('.row-2').each(function() {
       jQuery(this).height(row2maxHeight);
       });
      //Set height for boxes in row 3
       var row3maxHeight = 0;
       jQuery('.home-footer-col').each(function() {
       row3maxHeight = row3maxHeight > jQuery(this).height() ? row3maxHeight : jQuery(this).height();
       });
       jQuery('.home-footer-col').each(function() {
       jQuery(this).height(row3maxHeight);
       });
       //clearInterval();
      }



}

function animateMeter(){


  var percentage = lineheight - (dirtNumber*heightconversion);
  var pghPercentage = lineheight - (pghDirtNumber*heightconversion);
  var cloudSize;

  if(winWidth>1007){
    cloudSize = "cloud";
    }else{
      cloudSize = "smallcloud";
      }
//Set Pittsburgh cloud graphic according to air quality number
  if(pghDirtNumber<=20){
    jQuery("#pgh-cloud").css('background','url("/wp-content/themes/breathe2014responsive/images/'+cloudSize+'-100.png") no-repeat');
  }else if(pghDirtNumber <=40 && pghDirtNumber >20){
    jQuery("#pgh-cloud").css('background','url("/wp-content/themes/breathe2014responsive/images/'+cloudSize+'-80.png"  no-repeat)');
  }else if(pghDirtNumber <=60 && pghDirtNumber >40){
    jQuery("#pgh-cloud").css('background','url("/wp-content/themes/breathe2014responsive/images/'+cloudSize+'-60.png")  no-repeat');
  }else if(pghDirtNumber <=80 && pghDirtNumber >60){
    jQuery("#pgh-cloud").css('background','url("/wp-content/themes/breathe2014responsive/images/'+cloudSize+'-40.png")  no-repeat');
  }else{
    jQuery("#pgh-cloud").css('background','url("/wp-content/themes/breathe2014responsive/images/'+cloudSize+'-20.png")  no-repeat');
  }

  //Set city cloud graphic according to air quality number
  if(dirtNumber<=20){
    jQuery("#city-cloud").css('background','url("/wp-content/themes/breathe2014responsive/images/'+cloudSize+'-100.png")  no-repeat');
  }else if(dirtNumber <=40 && dirtNumber >20){
    jQuery("#city-cloud").css('background','url("/wp-content/themes/breathe2014responsive/images/'+cloudSize+'-80.png")  no-repeat');
  }else if(dirtNumber <=60 && dirtNumber >40){
    jQuery("#city-cloud").css('background','url("/wp-content/themes/breathe2014responsive/images/'+cloudSize+'-60.png")  no-repeat');
  }else if(dirtNumber <=80 && dirtNumber >60){
    jQuery("#city-cloud").css('background','url("/wp-content/themes/breathe2014responsive/images/'+cloudSize+'-40.png")  no-repeat');
  }else{
    jQuery("#city-cloud").css('background','url("/wp-content/themes/breathe2014responsive/images/'+cloudSize+'-20.png")  no-repeat');
  }
  //Animate the breathe meter to correct percentage mark.
  jQuery('#blue-meter').animate({'margin-top':percentage+'px'}, 1000, 'easeInOutBack')
  jQuery('#orange-meter').animate({'margin-top':pghPercentage+'px'}, 1000, 'easeInOutBack')

}


