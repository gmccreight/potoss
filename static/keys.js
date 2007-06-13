if (window.Event){
  document.captureEvents(Event.KEYDOWN);
}

document.onkeydown = myKeyDown;

function myKeyDown(e){

  var tag = '';

  if (window.Event){
    tag = e.target.tagName;
    mykey = e.which;
  }
  else{
    tag = event.srcElement.tagName;
    mykey = event.keyCode;
  }

  //disable shortcuts if in input or textarea
  if ( tag == 'INPUT' || tag == 'TEXTAREA' ){
    return 0;
  }

  var mykey = String.fromCharCode(mykey).toLowerCase();

  switch(mykey) {
    case 'f':
      // f is easy to reach, and most people are right handed, so they can
      // use it with their finger on the mouse.
      var key_palette = document.getElementById('myel_keys_palette');
      if (key_palette.style.left == "-1000px") {
        var v_sPageName = get_pagename();
        var v_sInnerHTML = '<iframe id="myel_keys_palette_iframe" src="./?PH_compact_page_opts&nm_page=' + v_sPageName + '" style="width:400px;height:240px;"/>';
        key_palette.innerHTML = v_sInnerHTML;
        key_palette.style.left = "40px";
      }
      else {
        key_palette.style.left = "-1000px";
      }
      
      break;
    case 's':
      // just another example... these will be filled in later.
      break;
  }
}