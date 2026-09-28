import React, { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { ArrowUpRight, ArrowLeft, ArrowRight, Bookmark, Check, ChevronDown, Search, X, Headphones, BookOpen, SlidersHorizontal } from 'lucide-react';
import { getCatalog, type Place } from './catalog';
import Atlas from './Atlas';
import Journey from './Journey';
import './next.css';

type Tab = 'journal'|'atlas'|'shelf';
const cityNames=['深圳','上海','商丘'];
const editions:Record<string,{id:string;first:string;second:string;note:string;tone:string;image:string;caption:string}[]>={
 深圳:[
  {id:'dameisha',first:'不赶路，',second:'去听海。',note:'把一点时间，交给潮汐。',tone:'sea',image:'/assets/coast.png',caption:'一座城市，也有呼吸的另一面。'},
  {id:'nantou',first:'旧街里，',second:'有新意。',note:'拐进日常，遇见一座城的来处。',tone:'town',image:'/assets/nantou.png',caption:'不是所有故事，都在博物馆里。'},
 ],
 上海:[{id:'wukang',first:'走慢点，',second:'听上海。',note:'梧桐深处，日常正在发生。',tone:'city',image:'/assets/wukang.png',caption:'五段声音，重新读一条街。'}],
 商丘:[{id:'peoples-park',first:'树荫下，',second:'等故事。',note:'下一本城市随刊，正在慢慢生长。',tone:'park',image:'/assets/park.png',caption:'一座老公园，一段共同的记忆。'}],
};
function Mark(){return <svg viewBox="0 0 40 40" fill="none" aria-hidden="true"><path d="M7 29C-1 18 21 0 32 11C43 22 15 38 8 28C1 18 27 10 29 23C31 32 21 38 17 35" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"/></svg>}
function readSaved():string[]{try{const v=JSON.parse(localStorage.getItem('jiandi-v5-saved')||'[]');return Array.isArray(v)?v.filter(x=>typeof x==='string'):[];}catch{return [];}}
function CitySheet({current,onChoose,onClose}:{current:string;onChoose:(city:string)=>void;onClose:()=>void}){
 const panel=useRef<HTMLDivElement>(null);
 useEffect(()=>{
  const prev=document.activeElement as HTMLElement;const old=document.body.style.overflow;document.body.style.overflow='hidden';panel.current?.querySelector<HTMLButtonElement>('button')?.focus();
  function key(e:KeyboardEvent){if(e.key==='Escape')onClose();if(e.key==='Tab'){const els=Array.from(panel.current?.querySelectorAll<HTMLButtonElement>('button')||[]);if(e.shiftKey&&document.activeElement===els[0]){e.preventDefault();els.at(-1)?.focus();}else if(!e.shiftKey&&document.activeElement===els.at(-1)){e.preventDefault();els[0]?.focus();}}}
  document.addEventListener('keydown',key);return()=>{document.body.style.overflow=old;document.removeEventListener('keydown',key);prev?.focus();};
 },[]);
 return <div className="next-scrim" onClick={onClose}><div className="next-city-sheet" ref={panel} role="dialog" aria-modal="true" aria-labelledby="city-sheet-title" onClick={e=>e.stopPropagation()}><button className="next-close" aria-label="关闭城市选择" onClick={onClose}><X size={21}/></button><span className="next-kicker">下一站，不必很远</span><h2 id="city-sheet-title">去哪里<br/><em>看一看？</em></h2>{cityNames.map((city,i)=><button className="next-city-choice" aria-pressed={city===current} key={city} onClick={()=>onChoose(city)}><span className="next-city-index">0{i+1}</span><strong>{city}</strong><small>{['向海，也向老街','在梧桐下听故事','公园手册 · 筹备中'][i]}</small>{current===city?<Check size={22}/>:<ArrowUpRight size={22}/>}</button>)}</div></div>
}
function NovelApp({scale=false}:{scale?:boolean}){
 const [page,setPage]=useState<Tab>('journal');
 const [city,setCity]=useState('深圳');
 const [edition,setEdition]=useState(0);
 const [cityOpen,setCityOpen]=useState(false);
 const [saved,setSaved]=useState(readSaved);
 const [route,setRoute]=useState<Place|null>(null);
 const [journeyVisible,setJourneyVisible]=useState(false);
 const [toast,setToast]=useState('');
 const places=getCatalog(scale);
 const pageOffset=useRef(0);const previousJourney=useRef(false);const touchStart=useRef<number|null>(null);const swiped=useRef(false);
 const cityEditions=editions[city]||editions['深圳'];
 const issue=cityEditions[edition%cityEditions.length];
 const featured=places.find(p=>p.id===issue.id)||places.find(p=>p.city===city&&!p.demo);
 useEffect(()=>{localStorage.setItem('jiandi-v5-saved',JSON.stringify(saved));},[saved]);
 useEffect(()=>{if(!toast)return;const t=setTimeout(()=>setToast(''),2200);return()=>clearTimeout(t);},[toast]);
 useLayoutEffect(()=>{if(!journeyVisible&&previousJourney.current&&page!=='atlas')window.scrollTo({top:pageOffset.current,behavior:'instant'});previousJourney.current=journeyVisible;},[journeyVisible,page]);
 function selectCity(next:string){setCity(next);setEdition(0);setCityOpen(false);window.scrollTo({top:0,behavior:'instant'});}
 function save(id:string){setSaved(s=>s.includes(id)?s.filter(x=>x!==id):[...s,id]);setToast(saved.includes(id)?'已从书架移出':'已放进书架，留给下一次出发');}
 function open(place:Place){pageOffset.current=window.scrollY;setRoute(place);setJourneyVisible(true);window.scrollTo({top:0,behavior:'instant'});}
 function changePage(next:Tab){setPage(next);window.scrollTo({top:0,behavior:'instant'});}
 function changeIssue(delta:number){setEdition(e=>(e+delta+cityEditions.length)%cityEditions.length);}
 const shelf=places.filter(p=>saved.includes(p.id));
 return <div className="novel-app">
  <div hidden={journeyVisible}>
   <header className="next-header"><button className="next-brand" onClick={()=>changePage('journal')} aria-label="返回随刊"><Mark/><span>见地<small>THE CITY, UNFOLDED</small></span></button>{page!=='atlas'&&<button className="next-city" onClick={()=>setCityOpen(true)} aria-label={`选择城市，当前${city}`}>{city}<ChevronDown size={14}/></button>}</header>
   <div hidden={page!=='journal'}><main className={`journal-page journal-${issue.tone}`}>
    <div className="journal-folio"><span>城市随刊 <i>·</i> <b>{String(edition+1).padStart(2,'0')}</b><small> / {String(cityEditions.length).padStart(2,'0')}</small></span><div><button aria-label="上一期随刊" onClick={()=>changeIssue(-1)} disabled={cityEditions.length<2}><ArrowLeft size={16}/></button><button aria-label="下一期随刊" onClick={()=>changeIssue(1)} disabled={cityEditions.length<2}><ArrowRight size={16}/></button></div></div>
    <section className="journal-cover" aria-label={`${city}：${issue.first}${issue.second}`}>
     <h1 key={issue.id}><span>{issue.first}</span><em>{issue.second}</em></h1>
     <div className="journal-side-note" aria-hidden="true">{issue.note}</div>
     <button className="journal-photo" aria-label={featured?`打开${featured.name}`:'路线正在准备'} disabled={!featured} onPointerDown={e=>{touchStart.current=e.clientX;swiped.current=false;}} onPointerUp={e=>{if(touchStart.current!==null&&Math.abs(e.clientX-touchStart.current)>55&&cityEditions.length>1){swiped.current=true;changeIssue(e.clientX<touchStart.current?1:-1);}touchStart.current=null;}} onPointerCancel={()=>{touchStart.current=null;}} onClick={()=>{if(swiped.current){swiped.current=false;return;}if(featured)open(featured);}}>
      <img src={issue.image} alt={`${city}的街区与自然景观`} draggable={false}/><span className="journal-photo-caption">{issue.caption}</span><span className="journal-open"><ArrowUpRight size={31}/></span>
     </button>
     <div className="journal-print" aria-hidden="true">{issue.tone==='sea'?'海':issue.tone==='town'?'街':issue.tone==='city'?'城':'树'}</div>
    </section>
    {featured&&<div className="journal-route"><button className="journal-route-main" onClick={()=>open(featured)}><span>{city} <i>/</i> {featured.theme}</span><strong>{featured.name}<ArrowUpRight size={19}/></strong><small>{featured.pending?'筹备中 · 可看构想':`${featured.minutes} 分钟 · ${featured.distance} km · ${featured.id==='wukang'?'声音导览':'文字漫游'}`}</small></button><button className={`journal-bookmark ${saved.includes(featured.id)?'saved':''}`} aria-label={`${saved.includes(featured.id)?'取消收藏':'收藏'}${featured.name}`} aria-pressed={saved.includes(featured.id)} onClick={()=>save(featured.id)}><Bookmark size={23}/></button></div>}
    <button className="journal-atlas-link" onClick={()=>changePage('atlas')}><span>有目的地，也有自己的节奏。</span><b>打开城市索引 <ArrowUpRight size={15}/></b></button>
   </main></div>
   <div hidden={page!=='atlas'}><Atlas places={places} city={city} onCity={selectCity} saved={saved} onSave={save} onOpen={open} visible={page==='atlas'&&!journeyVisible}/></div>
   <div hidden={page!=='shelf'}><main className="next-shelf"><div className="shelf-heading"><span className="next-kicker">把想去的，留给以后</span><h1>私人<em>书架</em><sup>{shelf.length.toString().padStart(2,'0')}</sup></h1><p>无需打卡，也值得留下一页。</p></div>{shelf.length?<div className="shelf-books">{shelf.map((p,i)=><article className={`shelf-book shelf-book-${i%3}`} key={p.id}><button onClick={()=>open(p)}><div className="shelf-book-cover">{p.image&&<img src={p.image} alt=""/>}<span>{p.city}</span><b>{p.name.split(/\s*·\s*/).map((part,j)=><React.Fragment key={j}>{j>0&&<br/>}{part}</React.Fragment>)}</b></div><small>{p.minutes} 分钟 · {p.demo?'布局样例':p.pending?'筹备中':p.id==='wukang'?'声音导览':'文字漫游'}</small></button><button className="shelf-remove" aria-label={`取消收藏${p.name}`} onClick={()=>save(p.id)}><Bookmark size={17} fill="currentColor"/></button></article>)}</div>:<div className="shelf-empty"><div className="shelf-empty-art" aria-hidden="true"><span>留</span><i/></div><h2>你的下一页，<br/>还没有写下。</h2><p>在随刊或路线里轻点收藏，<br/>想去的地方就会出现在这里。</p><button className="next-action" onClick={()=>changePage('journal')}>去翻一翻<ArrowUpRight size={19}/></button></div>}</main></div>
   {route&&<button className="next-resume" onClick={()=>setJourneyVisible(true)}><span>{route.id==='wukang'?<Headphones size={17}/>:<BookOpen size={17}/>}<b>{route.name}</b></span><small>继续查看<ArrowUpRight size={14}/></small></button>}
   <nav className="next-nav" aria-label="主要导航">{([['journal','随刊'],['atlas','路线'],['shelf','书架']] as const).map(([id,label],i)=><button key={id} aria-current={page===id?'page':undefined} onClick={()=>changePage(id)}>{i===0?<BookOpen size={19}/>:i===1?<Search size={19}/>:<Bookmark size={19}/>}<span>{label}</span>{page===id&&<i/>}</button>)}</nav>
  </div>
  <div hidden={!journeyVisible}><Journey place={route} visible={journeyVisible} saved={!!route&&saved.includes(route.id)} onSave={()=>route&&save(route.id)} onBack={()=>setJourneyVisible(false)}/></div>
  {cityOpen&&<CitySheet current={city} onClose={()=>setCityOpen(false)} onChoose={selectCity}/>}
  {toast&&<div className="next-toast" role="status"><Check size={15}/>{toast}</div>}
 </div>
}
function Preview(){
 const [scale,setScale]=useState(new URLSearchParams(location.search).get('catalog')==='scale');
 return <div className="lab-preview"><header className="lab-toolbar"><div><b>见地</b><span>V5 / 城市随刊</span></div><a href="http://127.0.0.1:3211/?catalog=scale" target="_blank" rel="noreferrer">打开已保存 V4 <ArrowUpRight size={14}/></a><label><input type="checkbox" checked={scale} onChange={e=>setScale(e.target.checked)}/>120 条规模样例</label></header><div className="lab-stage"><aside className="lab-description"><span>EXPERIMENT 05</span><h1>把城市，<br/>翻成一本<br/><em>随身的刊物。</em></h1><p>从一幅画面出发，找到一条路线。<br/>进入街巷后，让声音与文字接管。</p><div><b>01 / 随刊</b><small>先被打动，再决定去哪里</small><b>02 / 路线</b><small>按时间、地点和兴趣找到合适的一条</small><b>03 / 专注听读</b><small>把屏幕退到身后，把城市留在眼前</small></div><span className="lab-boundary">独立交互原型 · 手机画布 390 × 844<br/>{scale?'规模模式包含 118 条布局样例':'使用已有 4 条路线与武康路示例音频'}</span></aside><div className="lab-device"><iframe title="见地 V5 手机 App" key={String(scale)} src={`/?surface=app${scale?'&catalog=scale':''}`}/></div></div></div>
}
const params=new URLSearchParams(location.search);
createRoot(document.getElementById('root')!).render(<React.StrictMode>{params.get('surface')==='app'?<NovelApp scale={params.get('catalog')==='scale'}/>:<Preview/>}</React.StrictMode>);
