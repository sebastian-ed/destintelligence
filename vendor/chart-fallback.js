
(function(){
 if(typeof window.Chart==='function') return;
 class LocalChart{
   constructor(canvas,config){this.canvas=canvas;this.config=config||{};this.data=this.config.data||{labels:[],datasets:[]};this.draw();}
   update(){this.data=this.config.data||this.data;this.draw()}
   destroy(){const c=this.canvas;if(c&&c.getContext){const x=c.getContext('2d');x.clearRect(0,0,c.width,c.height)}}
   draw(){
     const c=this.canvas, cfg=this.config||{}, data=cfg.data||{}, labels=data.labels||[], vals=(data.datasets&&data.datasets[0]&&data.datasets[0].data)||[];
     if(!c||!c.getContext)return;const parent=c.parentElement;const w=Math.max(320,parent?.clientWidth||640),h=Math.max(220,parent?.clientHeight||300);c.width=w;c.height=h;
     const x=c.getContext('2d');x.clearRect(0,0,w,h);x.font='12px system-ui, sans-serif';x.fillStyle='#4c5c54';x.strokeStyle='#dfe5e1';
     if(cfg.type==='doughnut'){
       const total=vals.reduce((a,b)=>a+(Number(b)||0),0)||1,cx=Math.min(w*.34,190),cy=h/2,r=Math.min(85,h*.34),inner=r*.58;
       const colors=['#315d4d','#638574','#91aa9c','#b4c4bb','#d3ddd7','#7a6b52','#9b8b70','#546f8a','#7f91a5','#9d6f73'];let start=-Math.PI/2;
       vals.forEach((v,i)=>{const a=(Number(v)||0)/total*Math.PI*2;x.beginPath();x.moveTo(cx,cy);x.arc(cx,cy,r,start,start+a);x.closePath();x.fillStyle=colors[i%colors.length];x.fill();start+=a});x.globalCompositeOperation='destination-out';x.beginPath();x.arc(cx,cy,inner,0,Math.PI*2);x.fill();x.globalCompositeOperation='source-over';
       let yy=28;labels.slice(0,8).forEach((lab,i)=>{x.fillStyle=colors[i%colors.length];x.fillRect(w*.55,yy-9,10,10);x.fillStyle='#36443d';const p=Math.round((Number(vals[i])||0)/total*100);x.fillText(String(lab).slice(0,28)+' · '+p+'%',w*.55+16,yy);yy+=24});return;
     }
     const horizontal=cfg.options?.indexAxis==='y',max=Math.max(1,...vals.map(v=>Number(v)||0)),padL=horizontal?150:45,padR=25,padT=18,padB=horizontal?20:70,plotW=w-padL-padR,plotH=h-padT-padB;
     x.strokeStyle='#e4e9e6';x.beginPath();x.moveTo(padL,padT);x.lineTo(padL,padT+plotH);x.lineTo(padL+plotW,padT+plotH);x.stroke();
     x.fillStyle='#315d4d';
     if(horizontal){const n=Math.max(1,labels.length),slot=plotH/n,bh=Math.max(8,slot*.56);labels.forEach((lab,i)=>{const v=Number(vals[i])||0,y=padT+i*slot+(slot-bh)/2,bw=plotW*(v/max);x.fillStyle='#315d4d';x.fillRect(padL,y,bw,bh);x.fillStyle='#4c5c54';x.textAlign='right';x.fillText(String(lab).slice(0,23),padL-8,y+bh*.72);x.textAlign='left';x.fillText(String(v),Math.min(padL+bw+6,w-28),y+bh*.72)});
     }else{const n=Math.max(1,labels.length),slot=plotW/n,bw=Math.max(10,slot*.55);labels.forEach((lab,i)=>{const v=Number(vals[i])||0,bh=plotH*(v/max),xx=padL+i*slot+(slot-bw)/2,yy=padT+plotH-bh;x.fillStyle='#315d4d';x.fillRect(xx,yy,bw,bh);x.save();x.translate(xx+bw/2,padT+plotH+10);x.rotate(-Math.PI/4);x.fillStyle='#4c5c54';x.textAlign='right';x.fillText(String(lab).slice(0,18),0,0);x.restore()});}
   }
 }
 window.Chart=LocalChart;
})();
