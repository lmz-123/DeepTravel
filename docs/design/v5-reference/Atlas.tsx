import { useEffect, useId, useMemo, useRef, useState } from 'react';
import { ArrowDown, ArrowUpRight, Bookmark, Check, ChevronDown, MapPin, Search, SlidersHorizontal, X } from 'lucide-react';
import type { Place } from './catalog';
import './atlas.css';

type AtlasProps = {
  places: Place[];
  city: string;
  onCity: (city: string) => void;
  saved: string[];
  onSave: (id: string) => void;
  onOpen: (place: Place) => void;
  visible: boolean;
};
type Duration = 'any' | 'short' | 'medium' | 'long';
type Sort = 'editorial' | 'duration' | 'distance';
type Filters = { areas: string[]; duration: Duration };
type ScrollRoot = Window | HTMLElement;
const EMPTY_FILTERS: Filters = { areas: [], duration: 'any' };
const DURATIONS: { key: Duration; title: string; detail: string }[] = [
  { key: 'any', title: '时间不限', detail: '按你的节奏来' },
  { key: 'short', title: '45 分钟内', detail: '留一个小空隙' },
  { key: 'medium', title: '45–90 分钟', detail: '刚好一个下午' },
  { key: 'long', title: '90 分钟以上', detail: '再走远一点' },
];
const SORT_LABELS: Record<Sort, string> = { editorial: '编辑精选', duration: '用时最短', distance: '路程最短' };
const normalize = (value: string) => value.trim().toLocaleLowerCase().replace(/\s+/g, '');
function withinDuration(place: Place, duration: Duration) {
  return duration === 'any' || (duration === 'short' && place.minutes <= 45) || (duration === 'medium' && place.minutes > 45 && place.minutes <= 90) || (duration === 'long' && place.minutes > 90);
}
function getScrollRoot(element: HTMLElement | null): ScrollRoot {
  for (let parent = element?.parentElement; parent; parent = parent.parentElement) {
    if (/(auto|scroll|overlay)/.test(getComputedStyle(parent).overflowY) && parent.scrollHeight > parent.clientHeight) return parent;
  }
  return window;
}
function scrollTop(root: ScrollRoot) { return root === window ? window.scrollY : (root as HTMLElement).scrollTop; }
function scrollToTop(root: ScrollRoot, top: number) { root.scrollTo({ top: Math.max(0, top), behavior: 'instant' }); }
function viewportTop(root: ScrollRoot) { return root === window ? 0 : (root as HTMLElement).getBoundingClientRect().top; }

export default function Atlas({ places, city, onCity, saved, onSave, onOpen, visible }: AtlasProps) {
  const [query, setQuery] = useState('');
  const [theme, setTheme] = useState('全部');
  const [filters, setFilters] = useState<Filters>(EMPTY_FILTERS);
  const [draft, setDraft] = useState<Filters>(EMPTY_FILTERS);
  const [sort, setSort] = useState<Sort>('editorial');
  const [onlySaved, setOnlySaved] = useState(false);
  const [limit, setLimit] = useState(20);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [announcement, setAnnouncement] = useState('');
  const pageRef = useRef<HTMLElement>(null);
  const resultsRef = useRef<HTMLDivElement>(null);
  const sheetRef = useRef<HTMLDivElement>(null);
  const filterTriggerRef = useRef<HTMLButtonElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const savedScroll = useRef({ top: 0, id: '', offset: 0 });
  const previousCity = useRef(city);
  const visibleRef = useRef(visible);
  visibleRef.current = visible;
  const returnFocusRef = useRef(false);
  const frozenRef = useRef(false);
  const rowRefs = useRef(new Map<string, HTMLLIElement>());
  const headingId = useId();
  const savedSet = useMemo(() => new Set(saved), [saved]);
  const cityPlaces = useMemo(() => places.filter(place => place.city === city), [places, city]);
  const areas = useMemo(() => [...new Set(cityPlaces.map(place => place.area))].filter(Boolean), [cityPlaces]);
  const themes = useMemo(() => ['全部', ...new Set(cityPlaces.map(place => place.theme))], [cityPlaces]);
  const demoCount = cityPlaces.filter(place => place.demo).length;
  const savedCount = cityPlaces.filter(place => savedSet.has(place.id)).length;
  const searchTerm = normalize(query);
  const matches = (place: Place, applied: Filters) =>
    (!searchTerm || normalize(`${place.name} ${place.title} ${place.subtitle} ${place.area} ${place.theme}`).includes(searchTerm)) &&
    (theme === '全部' || place.theme === theme) &&
    (!applied.areas.length || applied.areas.includes(place.area)) &&
    withinDuration(place, applied.duration) &&
    (!onlySaved || savedSet.has(place.id));
  const filtered = cityPlaces.filter(place => matches(place, filters));
  const results = sort === 'editorial' ? filtered : [...filtered].sort((a, b) => sort === 'duration' ? a.minutes - b.minutes : a.distance - b.distance);
  const draftCount = cityPlaces.filter(place => matches(place, draft)).length;
  const displayed = results.slice(0, limit);
  const filterCount = filters.areas.length + Number(filters.duration !== 'any');
  const hasConditions = Boolean(query || theme !== '全部' || filterCount || onlySaved);

  function rememberPosition(preferredId?: string) {
    if(!visibleRef.current || !pageRef.current?.getClientRects().length) return;
    const root = getScrollRoot(pageRef.current);
    const top = viewportTop(root);
    const anchor = preferredId ? rowRefs.current.get(preferredId) : [...rowRefs.current.values()].find(row => row.getBoundingClientRect().bottom > top + 8);
    savedScroll.current = { top: scrollTop(root), id: anchor?.dataset.placeId || '', offset: anchor ? anchor.getBoundingClientRect().top - top : 0 };
  }
  function resetPosition() {
    savedScroll.current = { top: 0, id: '', offset: 0 };
    setLimit(20);
    if(visibleRef.current) scrollToTop(getScrollRoot(pageRef.current), 0);
  }
  function resetAll() {
    setQuery(''); setTheme('全部'); setFilters(EMPTY_FILTERS); setDraft(EMPTY_FILTERS); setOnlySaved(false); setSort('editorial'); resetPosition();
  }
  function showFilters() { setDraft({ areas: [...filters.areas], duration: filters.duration }); setSheetOpen(true); }
  function closeFilters() { setSheetOpen(false); requestAnimationFrame(() => filterTriggerRef.current?.focus({ preventScroll: true })); }
  function openPlace(place: Place) { rememberPosition(place.id); frozenRef.current = true; returnFocusRef.current = true; onOpen(place); }
  function savePlace(place: Place) {
    onSave(place.id);
    setAnnouncement(savedSet.has(place.id) ? `已从收藏中移除「${place.name}」` : `已收藏「${place.name}」`);
  }
  function applyFilters() { setFilters({ areas: [...draft.areas], duration: draft.duration }); resetPosition(); closeFilters(); }
  function changeCity(next: string) { if(next !== city) { resetAll(); onCity(next); } }

  useEffect(() => {
    if (previousCity.current !== city) { previousCity.current = city; resetAll(); }
  }, [city]);
  useEffect(() => {
    if(!announcement) return;
    const timer = window.setTimeout(() => setAnnouncement(''), 2400);
    return () => window.clearTimeout(timer);
  }, [announcement]);
  useEffect(() => {
    if(!visible) { frozenRef.current = true; setSheetOpen(false); return; }
    frozenRef.current = true;
    let secondFrame = 0;
    let thawFrame = 0;
    const frame = requestAnimationFrame(() => {
      secondFrame = requestAnimationFrame(() => {
        const root = getScrollRoot(pageRef.current);
        const snapshot = savedScroll.current;
        const anchor = snapshot.id ? rowRefs.current.get(snapshot.id) : null;
        scrollToTop(root, anchor ? scrollTop(root) + anchor.getBoundingClientRect().top - viewportTop(root) - snapshot.offset : snapshot.top);
        if(returnFocusRef.current) { anchor?.querySelector<HTMLButtonElement>('.atlas-route-open')?.focus({preventScroll:true}); returnFocusRef.current = false; }
        thawFrame = requestAnimationFrame(() => { frozenRef.current = false; });
      });
    });
    const root = getScrollRoot(pageRef.current);
    const track = () => { if(!frozenRef.current && visibleRef.current) rememberPosition(); };
    root.addEventListener('scroll', track, { passive: true });
    return () => { cancelAnimationFrame(frame); cancelAnimationFrame(secondFrame); cancelAnimationFrame(thawFrame); root.removeEventListener('scroll', track); };
  }, [visible]);
  useEffect(() => {
    if(!sheetOpen || !visible) return;
    const panel = sheetRef.current;
    const root = getScrollRoot(pageRef.current);
    const scrollElement = root === window ? document.body : root as HTMLElement;
    const previousOverflow = scrollElement.style.overflow;
    scrollElement.style.overflow = 'hidden';
    const frame = requestAnimationFrame(() => panel?.querySelector<HTMLElement>('[data-sheet-heading]')?.focus());
    function keydown(event: KeyboardEvent) {
      if(event.key === 'Escape') { event.preventDefault(); closeFilters(); return; }
      if(event.key !== 'Tab' || !panel) return;
      const controls = [...panel.querySelectorAll<HTMLElement>('button:not(:disabled), select, input, [tabindex="0"]')].filter(node => node.offsetParent !== null);
      if(!controls.length) return;
      const first = controls[0], last = controls[controls.length - 1];
      if(event.shiftKey && (document.activeElement === first || !controls.includes(document.activeElement as HTMLElement))) {event.preventDefault();last.focus();}
      else if(!event.shiftKey && (document.activeElement === last || !controls.includes(document.activeElement as HTMLElement))) {event.preventDefault();first.focus();}
    }
    document.addEventListener('keydown', keydown);
    return () => { cancelAnimationFrame(frame); scrollElement.style.overflow = previousOverflow; document.removeEventListener('keydown', keydown); };
  }, [sheetOpen, visible]);

  return <section ref={pageRef} className="atlas-page" hidden={!visible} aria-label="城市路线索引">
    <header className="atlas-header">
      <div className="atlas-running-head"><span>THE CITY, ON FOOT.</span><span>索引 / 02</span></div>
      <div className="atlas-title-line"><h1>城市索引<span className="atlas-title-dot">.</span></h1><span className="atlas-total" aria-label={`${city}共${cityPlaces.length}条路线`}>{String(cityPlaces.length).padStart(2, '0')}<sup>条</sup></span></div>
      <div className="atlas-city-line"><div className="atlas-city-control"><MapPin size={15} strokeWidth={1.5}/><span className="atlas-city-name">{city}</span><ChevronDown size={17} strokeWidth={1.4}/><select aria-label="选择城市" value={city} onChange={event => changeCity(event.target.value)}><option value="深圳">深圳</option><option value="上海">上海</option><option value="商丘">商丘</option></select></div><p>不赶路，去读一座城。</p></div>
    </header>

    <div className="atlas-discovery-controls">
      <div className="atlas-search"><Search size={20} strokeWidth={1.5}/><input ref={searchRef} value={query} onChange={event => {setQuery(event.target.value);resetPosition();}} placeholder="搜索街区、地点或故事" aria-label="搜索路线" type="search" autoComplete="off"/>{query && <button type="button" aria-label="清除搜索" onClick={() => {setQuery('');resetPosition();searchRef.current?.focus();}}><X size={18} strokeWidth={1.5}/></button>}<span className="atlas-search-slash" aria-hidden="true">↵</span></div>
      <div className="atlas-themes" aria-label="按主题筛选">{themes.map((item, index) => <button type="button" key={item} aria-pressed={theme === item} className={theme === item ? 'is-active' : ''} onClick={() => {setTheme(item);resetPosition();}}><span className="atlas-theme-number" aria-hidden="true">{String(index).padStart(2, '0')}</span><span className="atlas-theme-name">{item}</span></button>)}</div>
      <div className="atlas-filter-toolbar"><button type="button" className={`atlas-filter-trigger ${filterCount ? 'is-active' : ''}`} ref={filterTriggerRef} onClick={showFilters} aria-haspopup="dialog"><SlidersHorizontal size={16} strokeWidth={1.5}/><span>区域 / 时长</span>{filterCount > 0 && <em>{filterCount}</em>}<ChevronDown size={14} strokeWidth={1.5}/></button><span className="atlas-filter-divider"/><button type="button" className={`atlas-saved-filter ${onlySaved ? 'is-active' : ''}`} aria-pressed={onlySaved} onClick={() => {setOnlySaved(value => !value);resetPosition();}}><Bookmark size={15} strokeWidth={1.5} fill={onlySaved ? 'currentColor' : 'none'}/><span>已收藏</span>{savedCount > 0 && <em>{savedCount}</em>}</button><label className="atlas-sort"><span>{SORT_LABELS[sort]}</span><ChevronDown size={13} strokeWidth={1.5}/><select aria-label="路线排序" value={sort} onChange={event => {setSort(event.target.value as Sort);resetPosition();}}><option value="editorial">编辑精选</option><option value="duration">用时最短</option><option value="distance">路程最短</option></select></label></div>
      {filterCount > 0 && <div className="atlas-applied-filters">{filters.areas.map(area => <button type="button" key={area} aria-label={`移除${area}筛选`} onClick={() => {setFilters({...filters, areas:filters.areas.filter(item => item !== area)});resetPosition();}}>{area}<X size={12} strokeWidth={1.5}/></button>)}{filters.duration !== 'any' && <button type="button" aria-label="移除时长筛选" onClick={() => {setFilters({...filters,duration:'any'});resetPosition();}}>{DURATIONS.find(item=>item.key===filters.duration)?.title}<X size={12} strokeWidth={1.5}/></button>}</div>}
    </div>

    <div className="atlas-results" ref={resultsRef}>
      <div className="atlas-results-heading"><span>{hasConditions ? '找到' : '收录'} <strong>{results.length}</strong> 条路线</span><span>{String(Math.min(limit, results.length)).padStart(2,'0')} / {String(results.length).padStart(2,'0')}</span></div>
      {demoCount > 0 && <p className="atlas-demo-note"><span className="atlas-demo-asterisk" aria-hidden="true">✳</span><span>含 {demoCount} 条布局示例，图片、时长与距离为演示数据。</span></p>}
      {displayed.length > 0 ? <ol className="atlas-route-list">{displayed.map((place, index) => <li key={place.id} className="atlas-route" data-place-id={place.id} ref={element => {if(element) rowRefs.current.set(place.id,element);else rowRefs.current.delete(place.id);}}>
        <button type="button" className="atlas-route-open" onClick={() => openPlace(place)} aria-label={`查看${place.name}${place.demo ? '，布局示例' : ''}`}><span className={`atlas-route-image ${!place.image ? 'is-placeholder' : ''}`}>{place.image ? <img src={place.image} alt="" loading={index < 4 ? 'eager' : 'lazy'} onError={event => {event.currentTarget.style.display='none';event.currentTarget.parentElement?.classList.add('is-placeholder');}}/> : <MapPin size={24} strokeWidth={1}/>}<span className="atlas-route-image-mark" aria-hidden="true">↗</span></span><span className="atlas-route-copy"><span className="atlas-route-eyebrow"><span className="atlas-route-number">{String(index + 1).padStart(3,'0')}</span><span>{place.area}</span><span className="atlas-route-dot">·</span><span>{place.theme}</span></span><span className="atlas-route-title">{place.name}</span><span className="atlas-route-subtitle">{place.title}</span><span className="atlas-route-meta"><span>{place.minutes}<small> 分钟</small></span><span className="atlas-meta-divider"/><span>{place.distance.toFixed(1)}<small> km</small></span>{place.demo ? <span className="atlas-demo-tag">示例</span> : place.pending ? <span className="atlas-pending-tag">筹备中</span> : <span className="atlas-ready-tag">{place.id === 'wukang' ? '声音导览' : '图文导览'}</span>}</span></span></button>
        <button type="button" className={`atlas-route-save ${savedSet.has(place.id) ? 'is-saved' : ''}`} onClick={() => savePlace(place)} aria-label={`${savedSet.has(place.id) ? '取消收藏' : '收藏'}${place.name}`} aria-pressed={savedSet.has(place.id)}><Bookmark size={19} strokeWidth={1.35} fill={savedSet.has(place.id) ? 'currentColor' : 'none'}/></button>
      </li>)}</ol> : <div className="atlas-empty"><span className="atlas-empty-mark" aria-hidden="true">∅</span><h2>{onlySaved && savedCount === 0 ? '把想走的路，先留下。' : '换个方向，继续找。'}</h2><p>{onlySaved && savedCount === 0 ? `你还没有收藏${city}的路线。点一下书签，把下一次出发留在这里。` : query ? `没有找到与「${query}」匹配的路线，试试地点简称，或放宽筛选条件。` : '暂时没有符合这些条件的路线，试试其他主题、区域或时长。'}</p><button type="button" onClick={resetAll}>{onlySaved && savedCount === 0 ? '浏览全部路线' : '重置全部筛选'}<ArrowUpRight size={17} strokeWidth={1.5}/></button></div>}
      {results.length > 0 && <div className="atlas-list-footer">{limit < results.length ? <button type="button" className="atlas-load-more" onClick={() => setLimit(value => value + 20)}><span>再看 {Math.min(20, results.length - limit)} 条路线</span><ArrowDown size={18} strokeWidth={1.5}/></button> : <p className="atlas-end-note"><span/>城市的故事，未完待续。<span/></p>}<span className="atlas-list-footnote">步行的尺度，刚好认识一座城。</span></div>}
    </div>
    <div className="atlas-announcement" role="status" aria-live="polite">{announcement && <span><Check size={15} strokeWidth={1.5}/>{announcement}</span>}</div>

    {sheetOpen && <div className="atlas-sheet-backdrop" onClick={closeFilters}><div ref={sheetRef} className="atlas-filter-sheet" role="dialog" aria-modal="true" aria-labelledby={headingId} onClick={event=>event.stopPropagation()}><div className="atlas-sheet-handle" aria-hidden="true"/><header className="atlas-sheet-heading"><div><span className="atlas-sheet-kicker">MAKE ROOM FOR A WALK</span><h2 id={headingId} tabIndex={-1} data-sheet-heading>想怎么逛<span>？</span></h2></div><button type="button" aria-label="关闭筛选，不应用修改" onClick={closeFilters}><X size={23} strokeWidth={1.3}/></button></header><div className="atlas-sheet-scroll"><section className="atlas-sheet-section"><div className="atlas-sheet-section-title"><h3>从哪个区域开始</h3><span>可多选</span></div><div className="atlas-area-grid" aria-label="选择区域"><button type="button" className={!draft.areas.length ? 'is-selected' : ''} aria-pressed={!draft.areas.length} onClick={() => setDraft({...draft,areas:[]})}>全城{!draft.areas.length && <Check size={13} strokeWidth={1.8}/>}</button>{areas.map(area => <button type="button" key={area} className={draft.areas.includes(area) ? 'is-selected' : ''} aria-pressed={draft.areas.includes(area)} onClick={() => setDraft({...draft,areas:draft.areas.includes(area) ? draft.areas.filter(item=>item!==area) : [...draft.areas,area]})}>{area}{draft.areas.includes(area) && <Check size={13} strokeWidth={1.8}/>}</button>)}</div></section><section className="atlas-sheet-section"><div className="atlas-sheet-section-title"><h3>留多少时间给自己</h3><span>单选</span></div><div className="atlas-duration-list" aria-label="选择步行时长">{DURATIONS.map(item => <button type="button" key={item.key} className={draft.duration === item.key ? 'is-selected' : ''} aria-pressed={draft.duration === item.key} onClick={() => setDraft({...draft,duration:item.key})}><span className="atlas-duration-radio" aria-hidden="true"/><strong>{item.title}</strong><span>{item.detail}</span></button>)}</div></section></div><footer className="atlas-sheet-footer"><button type="button" className="atlas-reset-draft" onClick={() => setDraft({areas:[],duration:'any'})}>重置</button><button type="button" className="atlas-apply" onClick={applyFilters}>查看 {draftCount} 条路线<ArrowUpRight size={18} strokeWidth={1.5}/></button></footer></div></div>}
  </section>;
}
