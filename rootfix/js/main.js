(function(){
  var d=document,root=d.documentElement;
  var reduce=matchMedia("(prefers-reduced-motion: reduce)").matches;
  var fine=matchMedia("(hover:hover) and (pointer:fine)").matches;
  var $=function(s,c){return (c||d).querySelector(s)},$$=function(s,c){return Array.prototype.slice.call((c||d).querySelectorAll(s))};
  var hasG=!!(window.gsap&&window.ScrollTrigger)&&!reduce;

  $$("[data-split]").forEach(function(h){
    var words=h.textContent.trim().split(/\s+/);
    h.setAttribute("aria-label",h.textContent.trim());
    h.innerHTML=words.map(function(w){return '<span class="w" aria-hidden="true"><span>'+w.replace(/&/g,"&amp;").replace(/</g,"&lt;")+'</span></span>'}).join(" ");
  });

  var nav=$(".nav"),prog=$(".prog"),lastY=scrollY;
  var menu=$("#menu"),mbtn=$(".menu-btn");
  var onScroll=function(){
    var y=scrollY;
    if(nav){
      nav.classList.toggle("stuck",y>24);
      var open=menu&&menu.classList.contains("open");
      if(!reduce&&!open)nav.classList.toggle("up",y>lastY&&y>320);
      if(y<lastY)nav.classList.remove("up");
    }
    if(prog){var h=root.scrollHeight-innerHeight;prog.style.transform="scaleX("+(h>0?Math.min(1,y/h):0)+")"}
    lastY=y;
  };
  addEventListener("scroll",onScroll,{passive:true});onScroll();

  var lenis=null;
  if(window.Lenis&&!reduce){
    lenis=new Lenis({duration:1.05,smoothWheel:true});
    if(hasG){
      lenis.on("scroll",ScrollTrigger.update);
      gsap.ticker.add(function(t){lenis.raf(t*1000)});
      gsap.ticker.lagSmoothing(0);
    }else{var raf=function(t){lenis.raf(t);requestAnimationFrame(raf)};requestAnimationFrame(raf)}
  }

  if(menu&&mbtn){
    var setMenu=function(o){
      menu.classList.toggle("open",o);menu.setAttribute("aria-hidden",String(!o));
      mbtn.setAttribute("aria-expanded",String(o));
      root.style.overflow=o?"hidden":"";
      if(lenis){o?lenis.stop():lenis.start()}
      if(o){var f=$(".menu-close",menu);f&&f.focus()}else mbtn.focus();
    };
    mbtn.addEventListener("click",function(){setMenu(true)});
    $(".menu-close",menu).addEventListener("click",function(){setMenu(false)});
    $$("a",menu).forEach(function(a){a.addEventListener("click",function(){setMenu(false)})});
    d.addEventListener("keydown",function(e){if(e.key==="Escape"&&menu.classList.contains("open"))setMenu(false)});
  }

  $$('a[href^="#"]').forEach(function(a){
    a.addEventListener("click",function(e){
      var id=a.getAttribute("href");if(id.length<2)return;
      var t=$(id);if(!t)return;e.preventDefault();
      if(lenis)lenis.scrollTo(t,{offset:-40});else t.scrollIntoView({behavior:reduce?"auto":"smooth"});
      history.replaceState(null,"",id);
    });
  });

  if(hasG){
    gsap.registerPlugin(ScrollTrigger);
    root.classList.add("anim");
    $$("[data-split]").forEach(function(h){
      gsap.from($$(".w>span",h),{yPercent:110,duration:1,ease:"power4.out",stagger:.045,delay:.1});
    });
    ScrollTrigger.batch("[data-r]",{start:"top 88%",once:true,onEnter:function(els){
      gsap.to(els,{opacity:1,y:0,duration:.7,ease:"power3.out",stagger:.08,overwrite:true});
    }});
    $$(".ch-fill").forEach(function(f){
      gsap.to(f,{scaleY:1,ease:"none",scrollTrigger:{trigger:f.parentNode,start:"top 70%",end:"bottom 55%",scrub:.4}});
    });
    var hp=$(".hero-photo img");
    if(hp)gsap.to(hp,{yPercent:-12,ease:"none",scrollTrigger:{trigger:".hero",start:"top top",end:"bottom top",scrub:true}});
    var track=$(".method-track"),method=$(".method");
    if(track&&method&&innerWidth>900){
      var dist=function(){return Math.max(0,track.scrollWidth-innerWidth)};
      gsap.to(track,{x:function(){return -dist()},ease:"none",scrollTrigger:{trigger:method,start:"top top",end:function(){return "+="+dist()},pin:true,scrub:.6,invalidateOnRefresh:true,anticipatePin:1}});
      $$(".method img").forEach(function(i){i.addEventListener("load",function(){ScrollTrigger.refresh()})});
    }
    addEventListener("load",function(){ScrollTrigger.refresh()});
  }

  var vio=("IntersectionObserver" in window)?new IntersectionObserver(function(es){
    es.forEach(function(e){
      var v=e.target;
      if(e.isIntersecting){
        if(!v.dataset.ready){
          $$("source",v).forEach(function(s){s.src=s.dataset.src});
          v.load();v.dataset.ready="1";
          v.addEventListener("playing",function(){v.classList.add("on")},{once:true});
        }
        if(!reduce){var p=v.play();if(p&&p.catch)p.catch(function(){})}
      }else if(v.dataset.ready){v.pause()}
    });
  },{rootMargin:"120px 0px",threshold:.15}):null;
  $$("video[data-lazy]").forEach(function(v){vio&&vio.observe(v)});

  $$("[data-magnetic]").forEach(function(mag){
    if(!fine||reduce)return;
    mag.addEventListener("mousemove",function(e){
      var r=mag.getBoundingClientRect();
      mag.style.transform="translate("+((e.clientX-r.left-r.width/2)*.18)+"px,"+((e.clientY-r.top-r.height/2)*.28)+"px)";
    });
    mag.addEventListener("mouseleave",function(){mag.style.transition="transform 500ms cubic-bezier(.22,.8,.2,1)";mag.style.transform="";setTimeout(function(){mag.style.transition=""},500)});
  });

  var dg=$("#diagnoser"),wrapP=$("#dpanels");
  if(dg&&wrapP){
    var chips=$$(".chip",dg),panels=$$(".dpanel",wrapP),cur=0;
    var show=function(i){panels.forEach(function(p,j){p.hidden=j!==i})};
    chips.forEach(function(c,i){
      c.addEventListener("click",function(){
        if(i===cur)return;cur=i;
        chips.forEach(function(k,j){k.setAttribute("aria-pressed",String(j===i))});
        if(reduce){show(i);return}
        wrapP.classList.add("out");
        setTimeout(function(){show(i);wrapP.classList.remove("out")},260);
      });
    });
  }

  var grid=$(".work-grid");
  if(grid){
    var tabs=$$(".tab"),cases=$$(".case",grid);
    var apply=function(f){
      cases.forEach(function(c){c.hidden=!(f==="all"||c.dataset.cat===f)});
      tabs.forEach(function(t){t.setAttribute("aria-selected",String(t.dataset.f===f))});
      if(hasG){ScrollTrigger.refresh();gsap.set(cases.filter(function(c){return !c.hidden}),{opacity:1,y:0})}
    };
    tabs.forEach(function(t){t.addEventListener("click",function(){apply(t.dataset.f);history.replaceState(null,"",t.dataset.f==="all"?location.pathname:"#"+t.dataset.f)})});
    var q=location.hash.slice(1);
    if(q&&tabs.some(function(t){return t.dataset.f===q}))apply(q);
    var cur2=$(".cursor");
    if(cur2&&fine){
      var x=0,y=0,tx=0,ty=0;
      grid.addEventListener("mousemove",function(e){tx=e.clientX;ty=e.clientY;cur2.classList.toggle("on",!!e.target.closest(".case-media"))});
      grid.addEventListener("mouseleave",function(){cur2.classList.remove("on")});
      if(reduce){grid.addEventListener("mousemove",function(e){cur2.style.left=e.clientX+"px";cur2.style.top=e.clientY+"px"})}
      else{var loop=function(){x+=(tx-x)*.2;y+=(ty-y)*.2;cur2.style.left=x+"px";cur2.style.top=y+"px";requestAnimationFrame(loop)};loop()}
    }
  }

  var form=$("#diag-form");
  if(form){
    var pchips=$$(".chip",form),prob="";
    pchips.forEach(function(c){c.addEventListener("click",function(){
      var was=c.getAttribute("aria-pressed")==="true";
      pchips.forEach(function(k){k.setAttribute("aria-pressed","false")});
      c.setAttribute("aria-pressed",String(!was));prob=was?"":c.textContent.trim();
    })});
    form.addEventListener("submit",function(e){
      e.preventDefault();
      var f=new FormData(form);
      var lines=["ROOT - Free Shop Diagnosis","","Name: "+(f.get("name")||"-"),"Business: "+(f.get("business")||"-"),"City: "+(f.get("city")||"-"),"Website / Instagram: "+(f.get("link")||"-"),"Biggest problem: "+(prob||"Not sure yet")];
      var url="https://wa.me/916301521358?text="+encodeURIComponent(lines.join("\n"));
      var a=$("#wa-open");if(a){a.href=url;a.hidden=false}
      try{window.open(url,"_blank","noopener")}catch(err){}
    });
  }
})();
