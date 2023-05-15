<?php
//-------------------------------------------------------

//Template Name: About: page_breathe_cam.php
update_option('current_page_template','page_breathe_cam');

//-------------------------------------------------------
get_header();

$pods = new Pod('breathe_cam_page_content');
$pods->findRecords('name ASC');

while ($pods->fetchRecord()) {
	$pod_video_id = $pods->get_field('video_vimeo_url');
	$pod_video_imageArray = $pods->get_field('video_image');
	$pod_video_image = $pod_video_imageArray[0]['guid'];

	$pod_video_label = $pods->get_field('video_label');
	$pod_video_link_label = strtoupper($pods->get_field('video_link_label'));

	$pod_hero_title = strtoupper($pods->get_field('hero_title'));
	$pod_hero_body = $pods->get_field('hero_body');

	$pod_coalition_title = strtoupper($pods->get_field('coalition_title'));
	$pod_coalition_body = $pods->get_field('coalition_body');
}
unset($pods)
?>

<script type='text/javascript'>
	var imagesDir  = "<?php bloginfo( 'template_url' ); ?>/images/";
</script>
<img id='navhash' style="top: 59px !important" src="<?php bloginfo( 'template_url' ); ?>/images/navhash.png" />
<div id='breathe-meter-top' style="padding-top: 32px !important">
    <div class="spacer15" style="height: 44px; line-height: 44px"></div>
    <section class="row">
        <div class="col-3" id="breathe-cam-container">
        	<div class="content-block content-block-breathe-cam">
        		
                <div class="gray-area gray-area-breathe-cam">
                	<iframe id="breathe-cam" frameborder="0" allowfullscreen src="http://staging.breathecam.bodytrack.org/achd"></iframe>
            	</div>
              
        	</div>
        </div>
        <div class="clear"></div>
    </section> 
    <div class="spacer15"></div>
    <section class="row">
        <div class="col-1" style="width: 198px">
        	<div class="content-block" id="airRealTime" style="height: 188px">
                <div class="block-title">LEARN MORE</div>
                <div class="gray-area" style="padding-top: 2px; padding-bottom: 4px">
                <u style="font-size: 15px; line-height: 30px">
		  <li><a style="text-decoration: underline" href="#gallery">Gallery</a></li>
		  <li><a style="text-decoration: underline" href="#overview">Overview</a></li>
		  <li><a style="text-decoration: underline" href="#tutorial">Understanding Visibility</a></li>
                  <li><a style="text-decoration: underline" href="#data_disclaimer">Data Disclaimer</a></li>
                  <li><a style="text-decoration: underline" href="#credits">Credits</a></li>
                </u>
            	</div> 
                <div class="spacer15"></div>
            </div>
        	<div class="clear"></div>
    	</div>    
        <div class="clear showMobile"></div>
        <div class="spacer15 showMobile"></div>
        <div class="col-2 col-2-breathe-cam">
        	<div class="content-block">
            	<div class="block-title">OUR AIR IN REAL TIME</div>
                <div class="gray-area">
			<p class="breathe-cam-text">Did you know that you can estimate pollution levels by simply looking at the horizon?</p><br>
			<p class="breathe-cam-text">Breathe Cam provides high-resolution panoramas of Pittsburgh's skyline and other views in the region to help you discover more about the air you breathe using the power of your own vision. The zoomable live camera feed and historical time-lapses enable you to view our horizon in amazing detail from sky-high vantage points.</p><br>
			<p class="breathe-cam-text">Through this exploration, you can learn more about how pollution affects visibility and your health, as well as actions you can take to protect our most precious natural resource—air!</p>					
              	<div class='clear'></div>
                </div>
            </div>
        	<div class="clear"></div>
    	</div>     
    </section>
    <div class="spacer15"></div> 
    <div class="clear"></div>
    <div class="spacer15" id="gallery"></div>
    <section class="row">
        <div class="col-3">
        	<div class="content-block">
            	<div class="block-title">GALLERY</div>
                <div class="gray-area">

<p style="font-size:18px; font-family: 'quicksandregular' !important;">Notable Views</p><br>
<table>
<tr>
<td style="vertical-align: top; padding-right: 13px;" width="33%">
      <a href="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/clear-to-haze.gif" target="_blank" title="Click to see a larger version">
        <img class="breathe-cam-tutorial-gif" width="310" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/clear-to-haze.gif"></a>
</td>
<td style="vertical-align: top; padding-right: 13px;" width="33%">
      <a href="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/clear-to-brown-cloud.gif" target="_blank" title="Click to see a larger version">
        <img class="breathe-cam-tutorial-gif" width="310" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/clear-to-brown-cloud.gif"></a>
</td>
<td style="vertical-align: top; padding-right: 13px;" width="33%">
      <a href="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/clear-to-fog.gif" target="_blank" title="Click to see a larger version">
        <img class="breathe-cam-tutorial-gif" width="310" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/clear-to-fog.gif"></a>
</td>

</tr>
<tr>
<td style="vertical-align: top; padding-right: 13px;"><div class="breathe-cam-gallery-text" width="33%">Images of exact same location taken at 11:29AM on two separate dates – on a <span data-breathe-cam-view="2987.03513,829.50875,3.714,pts&t=57.19&d=2014-07-04&s=heinz">clear day (7/4)</span> details on the horizon are clearly visible; on a <span data-breathe-cam-view="2987.03513,829.50875,3.714,pts&t=49.11&d=2014-08-05&s=heinz">hazy day (8/5)</span> fine particle (PM<sub>2.5</sub>) concentration is high and white haze covers the hillside. Click to see a larger view.</div></td>

<td style="vertical-align: top; padding-right: 13px;"><div class="breathe-cam-gallery-text" width="33%">Images of exact same location taken at 9:11AM on two separate dates – on a <span data-breathe-cam-view="1975.06957,800.19148,3.572,pts&t=45.94&d=2014-03-26&s=heinz">clear day (3/26)</span> details on the horizon are clearly visible; on a <span data-breathe-cam-view="1975.06957,800.19148,3.385,pts&t=45.94&d=2014-04-06&s=heinz">"brown cloud" day (4/6)</span> a layer of pollution occludes visibility on the horizon. Click to see a larger view.</div></td>

<td style="vertical-align: top; padding-right: 13px;"><div class="breathe-cam-gallery-text" width="33%">Images of the exact same location taken at 9:11AM on two separate dates – on a <span data-breathe-cam-view="1975.06957,800.19148,3.572,pts&t=45.94&d=2014-03-26&s=heinz">clear day (3/26)</span> details on the horizon are clearly visible; on a <span data-breathe-cam-view="1975.06957,800.19148,3.385,pts&t=45.94&d=2014-04-15&s=heinz">foggy day (4/15)</span> visibility is poor due to high humidity, although air quality is good. Click to see a larger view.</div></td>
</tr>
</table>

<br><br><br>
<p style="font-size:18px; font-family: 'quicksandregular' !important">Notable Events</p><br>

<table>
<tr>

<td style="vertical-align: bottom; padding-right: 13px;" width="33%">
      <a href="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/smog.gif" target="_blank" title="Click to see a larger version">
        <img class="breathe-cam-tutorial-gif" width="310" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/smog-reduced.gif"></a>
</td>

<td style="vertical-align: bottom; padding-right: 13px;" width="33%">
      <a href="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/sunset.gif" target="_blank" title="Click to see a larger version">
        <img class="breathe-cam-tutorial-gif" width="310" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/sunset-reduced.gif"></a>
</td>

<td style="vertical-align: bottom; padding-right: 13px;" width="33%">
      <a href="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/moonrise.gif" target="_blank" title="Click to see a larger version">
        <img class="breathe-cam-tutorial-gif" width="310" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/moonrise-reduced.gif"></a>
</td>

</tr>
<tr>
<td style="vertical-align: top; padding-right: 13px;" width="33%"><div class="breathe-cam-gallery-text" data-breathe-cam-view="3170.07353,846.47187,4.018,pts&t=60.77&d=2014-10-03&s=heinz">Smog - 10/03/2014 North Shore</div></td>

<td style="vertical-align: top; padding-right: 13px;" width="33%"><div class="breathe-cam-gallery-text" data-breathe-cam-view="2609.97505,891.41399,2.066,pts&t=101.77&d=2014-07-04&s=heinz">Sunset - 07/04/2014 North Shore</div></td>

<td style="vertical-align: top; padding-right: 13px;" width="33%"><div class="breathe-cam-gallery-text" data-breathe-cam-view="3374.07824,1004.17121,1.209,pts&t=102.52&d=2014-11-10&s=trimont1">Moonrise - 11/10/2014 Downtown</div></td>
</tr>

<tr><td><div style="height:30px"></div></td><td></td><td></td></tr>
<tr>

<td style="vertical-align: top; padding-right: 13px;" width="33%">
      <a href="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/rainbow.gif" target="_blank" title="Click to see a larger version">
        <img class="breathe-cam-tutorial-gif" width="310" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/rainbow-reduced.gif"></a>
</td>

<td style="vertical-align: top; padding-right: 13px;" width="33%">
      <a href="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/rain-cloud.gif" target="_blank" title="Click to see a larger version">
        <img class="breathe-cam-tutorial-gif" width="310" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/rain-cloud-reduced.gif"></a>
</td>

<td style="vertical-align: top; padding-right: 13px;" width="33%">
      <a href="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/fireworks.gif" target="_blank" title="Click to see a larger version">
        <img class="breathe-cam-tutorial-gif" width="310" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/fireworks-reduced.gif"></a>
</td>

</tr>
<tr>
<td style="vertical-align: top; padding-right: 13px;" width="33%"><div class="breathe-cam-gallery-text" data-breathe-cam-view="3728.12236,942.29103,1.529,pts&t=86.36&d=2014-07-27&s=trimont1">Rainbow – 07/27/2014 Downtown</div></td>

<td style="vertical-align: top; padding-right: 13px;" width="33%"><div class="breathe-cam-gallery-text" data-breathe-cam-view="2736.5631,790.05884,1.05,pts&t=63.69&d=2014-05-27&s=heinz">Rain Cloud - 05/27/2014 North Shore</div></td>

<td style="vertical-align: top; padding-right: 13px;" width="33%"><div class="breathe-cam-gallery-text" data-breathe-cam-view="1514.15484,1017.98975,1.104,pts&t=107.86&d=2014-07-04&s=heinz">Fireworks - 07/04/2014 North Shore</div></td>

</tr>

</table>
		
              	<div class='clear'></div>
                </div>
            </div>
        	<div class="clear"></div>
    	</div>     
    </section>
<div class="spacer15"></div>
<div class="clear"></div>
<div class="spacer15" id="overview"></div>
    <section class="row">
        <div class="col-3">
        	<div class="content-block">
            	<div class="block-title content_toggle"><span class="collapse-expand">+</span> OVERVIEW</div>
                <div class="gray-area collapsible">
	          <p style="font-size:18px; font-family: 'quicksandregular' !important">What is Breathe Cam?</p><br>
                  <p class="breathe-cam-text">Breathe Cam is a project of the <a href="http://cmucreatelab.org" target="_blank">CREATE Lab</a> at <a href="http://cmu.edu" target="_blank">Carnegie Mellon University</a>, in collaboration with the Breathe Project of <a href="http://www.heinz.org/" target="_blank">The Heinz Endowments</a>.</p><br>
	<p class="breathe-cam-text">Images are captured using an off-the-shelf, <a href="http://www.arecontvision.com/product/SurroundVideo%C2%AE+Series/AV40185DN-HB" targ="_blank">Arecont</a> 40 megapixel 180&deg; panoramic IP camera. This model houses four high-resolution cameras inside a glass dome and is designed for outdoor mounting. The base of the camera housing contains a built-in heater/blower, which helps regulate the air temperature throughout the year. Data is transferred via an Internet connection and the entire system can be powered with a single 120v power outlet.</p><br>
	<p class="breathe-cam-text">At the back end, Breathe Cam is powered by the CREATE Lab's <a href="http://timemachine.cmucreatelab.org" target="_blank">Time Machine</a> software, which accumulates individual images taken over time and stitches them together to create panoramic video timelapses. The true power of this software lies in its ability to provide zoomable, terapixel-scale animations that allow you to delve into intricate details and explore how the panorama changes over space and time.</p>

<br><br>
<p style="font-size:18px; font-family: 'quicksandregular' !important">Air Quality and Meteorological Data</p><br>

<p class="breathe-cam-text">To help you interpret Breathe Cam images, air quality and meteorological data from the <a href="http://www.achd.net/mainstart.html" target="_blank">Allegheny County Health Department</a> are displayed below the panorama. You can see how the following data gathered at nearby ACHD monitoring stations change over time:</p>
<ul class="breathe-cam-list">
  <li class="breathe-cam-list-item">Fine particles (PM<sub>2.5</sub>)</li>
  <li class="breathe-cam-list-item">Respirable Suspended (RS) or Coarse particles (PM<sub>10</sub>)</li>
  <li class="breathe-cam-list-item">Sulfur dioxide (in ppb)</li>
  <li class="breathe-cam-list-item">Temperature (in Fahrenheit)</li>
  <li class="breathe-cam-list-item">Percentage of relative humidity</li>
  <li class="breathe-cam-list-item">Wind speed and direction</li>
</ul>
<br>
<p class="breathe-cam-text">By clicking on any of the numbers in the ACHD data table, you can activate a graphical display of this information, showing how these metrics vary over time with the panoramic video timelapse.</p>

<br><br>				
<p style="font-size:18px; font-family: 'quicksandregular' !important">Change-Detect Tool</p><br>
<p class="breathe-cam-text">The Change-Detect tool enables you to monitor specific landmarks or types of activities within the Breathe Cam panoramas. Simply move and size the green rectangle to cover the area of interest, and the software will graph changes detected in that region. You can then follow the data pattern to see how notable variations in the graph correspond to real-world changes in the panoramic video timelapse. For example, you could track train activity, emissions from a specific smoke stack, traffic levels, etc. Once a detection area is selected, you can click a button to create animated gifs that highlight particularly interesting events related to the type of change you monitored.</p>

              	  <div class='clear'></div>
                </div>
            </div>
        	<div class="clear"></div>
    	</div>     
    </section>
<div class="spacer15"></div>
<div class="clear"></div>
<div class="spacer15" id="tutorial"></div>
    <section class="row">
        <div class="col-3">
        	<div class="content-block">
            	<div class="block-title content_toggle"><span class="collapse-expand">+</span> UNDERSTANDING VISIBILITY</div>
                <div class="gray-area collapsible">
			

<p class="breathe-cam-text">Pittsburgh is known for its gorgeous skyline that can take your breath away the moment you exit the Fort Pitt Tunnels. It's part of what makes our city an attractive place to live, work and play—and why it has been named by National Geographic Traveler among the best places in the world to visit.<p><br>
	<p class="breathe-cam-text">Unfortunately, our skyline has the power to take your breath away for different reasons as well. When you look at Downtown or other scenic views throughout southwestern Pennsylvania, you often don’t enjoy a clear view due to a veil of white or brown haze hanging in the air.</p><br>
	<p class="breathe-cam-text">Haze is created when sunlight is absorbed and scattered by tiny pollution particles, reducing the clarity and color of what you see. These haze-causing particles come from power plants, factories, wood burning and motor vehicles, as well as windblown dust and soot from wildfires. Some pollution particles are emitted directly into the air. Others form as gases emitted into the air and are carried many miles from their source. Exposure to very small particles in the air has been linked to respiratory illness, heart disease, cancer, adverse birth outcomes and other serious health problems—even premature death.</p><br>
	<p class="breathe-cam-text">Breathe Cam brings you real-time pictures of four views in the Pittsburgh area so you can literally see what you are breathing. In addition, air quality data and meteorological data are provided to help you distinguish between natural causes of poor visibility and those produced by human activity.</p><br>

<p class="breathe-cam-text">Here are some tips to help you interpret what you are seeing:</p><br>

<ol class="breathe-cam-list">
<li class="breathe-cam-list-item-num">Look carefully. Does the picture really seem clear? On <span class="breathe-cam-bold-text">clear days</span>, features on the horizon look crisp and pollution and relative humidity levels are low. If today’s images are not as clear as in this photo, then there may be haze or fog obscuring the view.<br>
<img class="breathe-cam-tutorial" width="931" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/tutorial_clear.png"></li>
<br>
<li class="breathe-cam-list-item-num">Is it a <span class="breathe-cam-bold-text">hazy day</span>? Haze is relatively uniform across the horizon, but tends to diminish slightly at higher elevations. Look at pollution levels. Also, note the relative humidity. Haze often occurs with medium or high levels of fine particles or ozone. Relative humidity also tends to be medium to high.<br>
<img class="breathe-cam-tutorial" width="931" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/tutorial_haze.png"></li>
<br>
<li class="breathe-cam-list-item-num">Is it a <span class="breathe-cam-bold-text">"brown cloud" day</span>? A brown cloud appears to envelop the scene, but quickly thins out at higher elevations. Brown clouds tend to occur when a layer of warm air higher in the atmosphere traps pollutants at the surface. Particle levels are usually high, and relative humidity may vary.<br>
<img class="breathe-cam-tutorial" width="931" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/tutorial_brown_cloud.png">
</li>
<br>
<li class="breathe-cam-list-item-num">Is it a <span class="breathe-cam-bold-text">foggy day</span>? Look at the relative humidity and precipitation levels. If the relative humidity nears 100 percent and there has been precipitation in the past 24 hours, then you are probably looking at fog. Fog tends to be gray, while haze is generally white. It is most common in the fall and spring and doesn't thin out at the top of the image.<br>
<img class="breathe-cam-tutorial" width="931" src="<?php bloginfo( 'template_url' ); ?>/images/breathe-cam-gallery/tutorial_fog.png">
</li>
<br>
<li class="breathe-cam-list-item-num">Is there a <span class="breathe-cam-bold-text">temperature inversion</span>? Normally, air near the surface of the Earth is warmer than the air above it. But under certain conditions, that normal gradient is inverted, and the air near the surface becomes colder than the air above it. The temperature inversion acts like a lid on the sky, trapping air pollutants beneath it. There’s little to no atmospheric mixing to disperse the pollutants, and the build-up can be especially unhealthy in river valleys. In the Pittsburgh area, inversions periodically happen overnight and break up by mid-morning. Brown clouds are often a result of temperature inversions, as depicted in example 3 above.</li>
</ol>
<br>

<p class="breathe-cam-test">Source: U.S. Environmental Protection Agency, U.S. Forest Service</p>
				
              	<div class='clear'></div>
                </div>
            </div>
        	<div class="clear"></div>
    	</div>     
    </section>
<div class="spacer15"></div>
<div class="clear"></div>
<div class="spacer15" id="data_disclaimer"></div>
    <section class="row">
        <div class="col-3">
        	<div class="content-block">
            	<div class="block-title content_toggle"><span class="collapse-expand">+</span> DATA DISCLAIMER</div>
                <div class="gray-area collapsible">
<p class="breathe-cam-text">Raw visual data on this website are collected and reported on a real-time and automated basis by the Breathe Cam system. Although measures are in place to ensure the integrity of the captured images, the data have not gone through the rigorous quality control procedures that government agencies usually perform before releasing such data for regulatory and scientific purposes.</p><br>
<p class="breathe-cam-text">Note that there may be dates when our cameras are down due to inclement weather conditions or technical issues. On such occasions there will be interruptions to the time-lapse panorama at certain time periods. Also note that during the night images appear black and white because cameras switch to IR mode, which allows you to see greater detail including smoke emissions, and cloud and fog movement.</p>
				
              	<div class='clear'></div>
                </div>
            </div>
        	<div class="clear"></div>
    	</div>     
    </section>
<div class="spacer15"></div>
<div class="clear"></div>

<div class="spacer15" id="credits"></div>
    <section class="row">
        <div class="col-3">
        	<div class="content-block">
            	<div class="block-title content_toggle"><span class="collapse-expand">+</span> CREDITS</div>
                <div class="gray-area collapsible">
<p class="breathe-cam-text">Breathe Cam was developed by the CREATE Lab at Carnegie Mellon University with support from The Heinz Endowments. The amazing views of Pittsburgh's skyline could not have been captured without wonderful partnerships with The Heinz Endowments, Jim and Julia Albright, Walnut Capital, and the University of Pittsburgh. Meteorological and pollutant data is furnished by the Allegheny County Health Department, which also partnered with us on this project.</p>
              	<div class='clear'></div>
                </div>
            </div>
        	<div class="clear"></div>
    	</div>     
    </section>
<div class="spacer15"></div>
<div class="clear"></div>
</div><!-- end of top -->

<?php get_footer(); ?>