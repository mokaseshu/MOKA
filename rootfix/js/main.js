(function(){
  var d=document,root=d.documentElement;
  var reduce=matchMedia("(prefers-reduced-motion: reduce)").matches;
  var fine=matchMedia("(hover:hover) and (pointer:fine)").matches;
  var $=function(s,c){return (c||d).querySelector(s)},$$=function(s,c){return Array.prototype.slice.call((c||d).querySelectorAll(s))};

  var nav=$(".nav");
  var onScroll=function(){nav&&nav.classList.toggle("stuck",scrollY>24)};
  addEventListener("scroll",onScroll,{passive:true});onScroll();

  var lenis=null;
  if(window.Lenis&&!reduce){
    lenis=new Lenis({duration:1.05,smoothWheel:true});
    if(window.gsap&&window.ScrollTrigger){
      lenis.on("scroll",ScrollTrigger.update);
      gsap.ticker.add(function(t){lenis.raf(t*1000)});
      gsap.ticker.lagSmoothing(0);
    }else{
      var raf=function(t){lenis.raf(t);requestAnimationFrame(raf)};requestAnimationFrame(raf);
    }
  }
  $$('a[href^="#"]').forEach(function(a){
    a.addEventListener("click",function(e){
      var id=a.getAttribute("href");if(id.length<2)return;
      var t=$(id);if(!t)return;e.preventDefault();
      if(lenis)lenis.scrollTo(t,{offset:-56});else t.scrollIntoView({behavior:reduce?"auto":"smooth"});
      history.replaceState(null,"",id);
    });
  });

  if(window.gsap&&window.ScrollTrigger&&!reduce){
    gsap.registerPlugin(ScrollTrigger);
    root.classList.add("anim");
    ScrollTrigger.batch("[data-r]",{start:"top 88%",once:true,onEnter:function(els){
      gsap.to(els,{opacity:1,y:0,duration:.65,ease:"power3.out",stagger:.08,overwrite:true});
    }});
    var track=$(".method-track"),method=$(".method");
    if(track&&method&&innerWidth>900){
      var dist=function(){return Math.max(0,track.scrollWidth-innerWidth)};
      gsap.to(track,{x:function(){return -dist()},ease:"none",scrollTrigger:{trigger:method,start:"top top",end:function(){return "+="+dist()},pin:true,scrub:.6,invalidateOnRefresh:true,anticipatePin:1}});
    }
    addEventListener("load",function(){ScrollTrigger.refresh()});
    $$(".method img").forEach(function(i){i.addEventListener("load",function(){ScrollTrigger.refresh()})});
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
        if(!reduce||v.hasAttribute("data-always")){var p=v.play();if(p&&p.catch)p.catch(function(){})}
      }else if(v.dataset.ready){v.pause()}
    });
  },{rootMargin:"120px 0px",threshold:.15}):null;
  var watch=function(c){$$("video[data-lazy]",c).forEach(function(v){vio?vio.observe(v):0})};
  watch(d);

  var mag=$("[data-magnetic]");
  if(mag&&fine&&!reduce){
    mag.addEventListener("mousemove",function(e){
      var r=mag.getBoundingClientRect();
      mag.style.transform="translate("+((e.clientX-r.left-r.width/2)*.18)+"px,"+((e.clientY-r.top-r.height/2)*.28)+"px)";
    });
    mag.addEventListener("mouseleave",function(){mag.style.transition="transform 500ms cubic-bezier(.22,.8,.2,1)";mag.style.transform="";setTimeout(function(){mag.style.transition=""},500)});
  }

  var dg=$("#diagnoser");
  if(dg){
    var data=JSON.parse($("#diag-data").textContent);
    var chips=$$(".chip",dg),rootEl=$("#d-root"),fixEl=$("#d-fix"),linkEl=$("#d-link"),media=$("#d-media"),bar=$("#d-bar"),swaps=$$(".swap",dg.parentNode);
    var cur=0;
    var render=function(i){
      var x=data[i];
      rootEl.textContent=x.root;fixEl.textContent=x.fix;
      linkEl.href="work/"+x.slug+".html";linkEl.firstChild.textContent="Case file: "+x.title+" ";
      bar.textContent=x.title.toLowerCase();
      media.innerHTML=x.video?'<video data-lazy muted loop playsinline preload="none" poster="assets/work/'+x.slug+'.jpg" aria-label="Screen recording of '+x.title+'"><source data-src="assets/work/'+x.slug+'.mp4" type="video/mp4"><source data-src="assets/work/'+x.slug+'.webm" type="video/webm"></video>':'<img src="assets/img/'+x.img+'" alt="'+x.title+'" loading="lazy">';
      var v=$("video",media);if(v){v.classList.add("on");watch(media)}
    };
    chips.forEach(function(c,i){
      c.addEventListener("click",function(){
        if(i===cur)return;cur=i;
        chips.forEach(function(k,j){k.setAttribute("aria-pressed",j===i)});
        if(reduce){render(i);return}
        swaps.forEach(function(s){s.classList.add("out")});
        setTimeout(function(){render(i);swaps.forEach(function(s){s.classList.remove("out")})},260);
      });
    });
  }

  var grid=$(".work-grid");
  if(grid){
    var tabs=$$(".tab"),cases=$$(".case",grid);
    var apply=function(f){
      grid.classList.toggle("feat",f==="featured");
      cases.forEach(function(c){
        var show=f==="all"||(f==="featured"?c.dataset.feat==="1":c.dataset.cat===f);
        c.hidden=!show;
      });
      tabs.forEach(function(t){t.setAttribute("aria-selected",t.dataset.f===f)});
      if(window.ScrollTrigger)ScrollTrigger.refresh();
    };
    tabs.forEach(function(t){t.addEventListener("click",function(){apply(t.dataset.f)})});
    var q=new URLSearchParams(location.search).get("c");
    if(q&&tabs.some(function(t){return t.dataset.f===q}))apply(q);
    var cur2=$(".cursor");
    if(cur2&&fine){
      var x=0,y=0,tx=0,ty=0,on=false;
      grid.addEventListener("mousemove",function(e){tx=e.clientX;ty=e.clientY;var hit=e.target.closest(".case-media");cur2.classList.toggle("on",!!hit)});
      grid.addEventListener("mouseleave",function(){cur2.classList.remove("on")});
      var loop=function(){x+=(tx-x)*.2;y+=(ty-y)*.2;cur2.style.left=x+"px";cur2.style.top=y+"px";requestAnimationFrame(loop)};
      if(reduce){grid.addEventListener("mousemove",function(e){cur2.style.left=e.clientX+"px";cur2.style.top=e.clientY+"px"})}else loop();
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
