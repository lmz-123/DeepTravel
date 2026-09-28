import { useEffect, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, ArrowUpRight, Bookmark, Check, ChevronDown, BookOpen, Headphones, List, MapPin, Pause, Play, SkipBack, SkipForward, Volume2 } from 'lucide-react';
import type { Place } from './catalog';
import content from './content.json';
import JourneyPrelude from './JourneyPrelude';
import ChapterDirectory from './ChapterDirectory';
import './journey.css';

interface JourneyProps {
  place: Place | null;
  visible: boolean;
  saved: boolean;
  onSave: () => void;
  onBack: () => void;
}

type JourneySession = { index: number; positions: Record<number, number>; focus: boolean; visited: boolean; mode: 'audio' | 'text'; opened: number[] };
const emptySession: JourneySession = { index: 0, positions: {}, focus: false, visited: false, mode: 'audio', opened: [] };
const audioLengths = [48.32, 48.15, 48.73, 57.99, 55.87];
const chapterImages = ['/assets/wukang.png', '/assets/lane.png', '/assets/wukang.png', '/assets/lane.png', '/assets/wukang.png'];
const timeLabel = (seconds: number) => `${Math.floor(Math.max(0, seconds) / 60).toString().padStart(2, '0')}:${Math.floor(Math.max(0, seconds) % 60).toString().padStart(2, '0')}`;
const numberLabel = (number: number) => String(number).padStart(2, '0');

export default function Journey({ place, visible, saved, onSave, onBack }: JourneyProps) {
  const [sessions, setSessions] = useState<Record<string, JourneySession>>({});
  const [playing, setPlaying] = useState(false);
  const [duration, setDuration] = useState(0);
  const [audioError, setAudioError] = useState('');
  const [preludeOpen, setPreludeOpen] = useState(false);
  const [draftIndex, setDraftIndex] = useState(0);
  const [directoryOpen, setDirectoryOpen] = useState(false);
  const [bookmarksLit, setBookmarksLit] = useState(false);
  const [preserveDirectory, setPreserveDirectory] = useState(false);
  const [directoryIndex, setDirectoryIndex] = useState(0);
  const [detailDock, setDetailDock] = useState(false);
  const [playerDock, setPlayerDock] = useState(false);
  const directoryOrigin = useRef<'detail' | 'focus' | 'prelude'>('detail');
  const preludeOrigin = useRef<'detail' | 'focus' | 'directory'>('detail');
  const bookmarksRef = useRef<HTMLElement>(null);
  const coverActionRef = useRef<HTMLButtonElement>(null);
  const allChaptersRef = useRef<HTMLButtonElement>(null);
  const playerControlsRef = useRef<HTMLDivElement>(null);
  const detailOffset = useRef(0);
  const playbackRequest = useRef(0);
  const playbackAllowed = useRef(false);
  const audioRef = useRef<HTMLAudioElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const pendingPlayback = useRef(false);
  const visibleRef = useRef(visible);
  const routeId = place?.id ?? '';
  const session = sessions[routeId] ?? emptySession;
  const hasAudio = routeId === 'wukang' && !place?.demo && !place?.pending;
  const canStart = Boolean(place && !place.demo && !place.pending && place.stops.length);
  const index = Math.min(session.index, Math.max(0, (hasAudio ? content.fragments.length : place?.stops.length ?? 0) - 1));
  const chapters = hasAudio
    ? content.fragments.map((fragment, chapterIndex) => ({ title: fragment.stop.title, story: fragment.title, body: fragment.transcript, image: chapterImages[chapterIndex] }))
    : (place?.stops ?? []).map(stop => ({ ...stop, image: place?.image ?? '' }));
  const chapter = chapters[index];
  const draftChapter = chapters[draftIndex] ?? chapter;
  const isListening = hasAudio && session.mode === 'audio';
  const position = session.positions[index] ?? 0;
  const totalDuration = duration || audioLengths[index] || 0;
  const audioSrc = hasAudio ? `/assets/narration-${index + 1}.m4a` : undefined;
  const coverDeck = !place?.demo && !place?.pending && routeId === 'nantou'
    ? '沿着城门与老街，读懂一座不断换身份的城。'
    : !place?.demo && !place?.pending && routeId === 'dameisha'
      ? '从旧村走到浪边，读一读这片海岸怎样一步步来到今天。'
      : place?.subtitle;

  function updateSession(update: (previous: JourneySession) => JourneySession) {
    if (!routeId) return;
    setSessions(previous => ({ ...previous, [routeId]: update(previous[routeId] ?? emptySession) }));
  }

  function pauseAudio() {
    playbackRequest.current += 1;
    playbackAllowed.current = false;
    pendingPlayback.current = false;
    audioRef.current?.pause();
    setPlaying(false);
  }

  async function playAudio() {
    const audio = audioRef.current;
    if (!audio || !visibleRef.current || !hasAudio) return;
    const request = ++playbackRequest.current;
    playbackAllowed.current = true;
    setAudioError('');
    try {
      if (audio.ended) {
        audio.currentTime = 0;
        updateSession(previous => ({ ...previous, positions: { ...previous.positions, [index]: 0 } }));
      }
      await audio.play();
      if (audio !== audioRef.current || !visibleRef.current || !playbackAllowed.current) audio.pause();
    } catch (error) {
      if (request !== playbackRequest.current || audio !== audioRef.current) return;
      if (error instanceof DOMException && error.name === 'AbortError') return;
      setPlaying(false);
      setAudioError('这一段暂时没能播放。可以再次点播放，或打开下方全文。');
    }
  }

  function enterFocus(nextIndex = index, autoplay = false, mode: 'audio' | 'text' = session.mode) {
    if (!canStart) return;
    pauseAudio();
    setAudioError('');
    pendingPlayback.current = autoplay && hasAudio && nextIndex !== index;
    updateSession(previous => ({ ...previous, index: nextIndex, focus: true, visited: true, mode, opened: [...new Set([...previous.opened, nextIndex])] }));
    if (nextIndex !== index) setDuration(0);
    if (autoplay && hasAudio && nextIndex === index) void playAudio();
    window.scrollTo({ top: 0, behavior: 'instant' });
  }

  function leaveFocus() {
    pauseAudio();
    updateSession(previous => ({ ...previous, focus: false }));
    requestAnimationFrame(() => window.scrollTo({ top: detailOffset.current, behavior: 'instant' }));
  }

  function leaveJourney() {
    pauseAudio();
    onBack();
  }

  function openPrelude(nextIndex = index, origin: 'detail' | 'focus' | 'directory' = session.focus ? 'focus' : 'detail') {
    if (!canStart || nextIndex < 0 || nextIndex >= chapters.length) return;
    if (!session.focus) detailOffset.current = window.scrollY;
    pauseAudio();
    preludeOrigin.current = origin;
    setDraftIndex(nextIndex);
    setPreludeOpen(true);
  }

  function returnToDirectory() {
    setPreludeOpen(false);
    setPreserveDirectory(true);
    setDirectoryOpen(true);
  }

  function closePrelude() {
    if (preludeOrigin.current === 'directory') returnToDirectory();
    else setPreludeOpen(false);
  }

  function selectChapter(nextIndex: number) { openPrelude(nextIndex); }

  function openDirectory(origin: 'detail' | 'focus' | 'prelude') {
    pauseAudio();
    directoryOrigin.current = origin;
    setDirectoryIndex(origin === 'prelude' ? draftIndex : index);
    setPreserveDirectory(false);
    setPreludeOpen(false);
    setDirectoryOpen(true);
  }

  function closeDirectory() {
    setDirectoryOpen(false);
    if (directoryOrigin.current === 'prelude') setPreludeOpen(true);
  }

  function revealBookmarks() {
    const target = bookmarksRef.current;
    if (!target) return;
    target.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth', block: 'start' });
    target.querySelector<HTMLElement>('h2')?.focus({ preventScroll: true });
    setBookmarksLit(true);
  }

  useEffect(() => {
    visibleRef.current = visible;
    if (!visible) {
      pauseAudio();
      setPreludeOpen(false);
      setDirectoryOpen(false);
    }
  }, [visible]);

  useEffect(() => {
    const routeAudio = audioRef.current;
    pauseAudio();
    setPreludeOpen(false);
    setDirectoryOpen(false);
    setBookmarksLit(false);
    setDetailDock(false);
    setPlayerDock(false);
    detailOffset.current = 0;
    setDuration(0);
    setAudioError('');
    return () => routeAudio?.pause();
  }, [routeId]);

  useEffect(() => {
    if (!visible || !canStart) return;
    let frame = 0;
    const measure = () => {
      const opening = coverActionRef.current?.getBoundingClientRect();
      const ending = allChaptersRef.current?.getBoundingClientRect();
      const controls = playerControlsRef.current?.getBoundingClientRect();
      const endingVisible = ending && ending.top < window.innerHeight && ending.bottom > 0;
      setDetailDock(!session.focus && Boolean(opening && opening.bottom < 0 && !endingVisible));
      setPlayerDock(session.focus && isListening && Boolean(controls && (controls.top < 0 || controls.bottom > window.innerHeight)));
    };
    const schedule = () => { cancelAnimationFrame(frame); frame = requestAnimationFrame(measure); };
    schedule();
    const resize = new ResizeObserver(schedule);
    [coverActionRef.current, allChaptersRef.current, playerControlsRef.current].forEach(element => { if (element) resize.observe(element); });
    window.addEventListener('scroll', schedule, { passive: true });
    window.addEventListener('resize', schedule);
    return () => { cancelAnimationFrame(frame); resize.disconnect(); window.removeEventListener('scroll', schedule); window.removeEventListener('resize', schedule); };
  }, [visible, canStart, routeId, session.focus, isListening, index]);

  useEffect(() => {
    if (visible && session.focus) titleRef.current?.focus({ preventScroll: true });
  }, [visible, session.focus, session.mode, routeId, index]);

  useEffect(() => {
    const pauseOnPageHide = () => pauseAudio();
    window.addEventListener('pagehide', pauseOnPageHide);
    return () => { window.removeEventListener('pagehide', pauseOnPageHide); audioRef.current?.pause(); };
  }, []);

  useEffect(() => {
    if (!bookmarksLit) return;
    const timer = window.setTimeout(() => setBookmarksLit(false), 1500);
    return () => window.clearTimeout(timer);
  }, [bookmarksLit]);

  if (!place) return null;

  return <section className={`journey-root ${session.focus && canStart ? 'journey-is-focused' : ''}`} hidden={!visible} aria-label={`${place.name}城市手册`}>
    {hasAudio && <audio
      key={`${routeId}-${index}`}
      ref={audioRef}
      src={audioSrc}
      preload="metadata"
      onLoadedMetadata={event => {
        const audio = event.currentTarget;
        setDuration(Number.isFinite(audio.duration) ? audio.duration : audioLengths[index]);
        audio.currentTime = Math.min(session.positions[index] ?? 0, Number.isFinite(audio.duration) ? audio.duration : 0);
        if (pendingPlayback.current && visibleRef.current) { pendingPlayback.current = false; void playAudio(); }
      }}
      onTimeUpdate={event => {
        const currentTime = event.currentTarget.currentTime;
        updateSession(previous => ({ ...previous, positions: { ...previous.positions, [index]: currentTime } }));
      }}
      onPlay={() => { if (!visibleRef.current || !playbackAllowed.current) audioRef.current?.pause(); else setPlaying(true); }}
      onPause={() => setPlaying(false)}
      onEnded={() => setPlaying(false)}
      onError={() => { setPlaying(false); setAudioError('音频暂时不可用，仍可阅读完整文字。'); }}
    />}

    {session.focus && canStart && chapter ? <div className={`journey-focus ${isListening ? 'is-listening' : 'is-reading'}`} key={`${routeId}-${index}-${session.mode}`}>
      <header className="journey-focus-header">
        <button className="journey-back" onClick={leaveFocus}><ArrowLeft size={19} />路线介绍</button>
        <span className="journey-focus-wordmark">见地 <i>JIAN DI</i></span><button className="journey-top-directory" onClick={() => openDirectory('focus')} aria-label="打开章节目录"><List size={18} /><span>目录</span></button>
        <button className={`journey-save ${saved ? 'journey-saved' : ''}`} onClick={onSave} aria-label={saved ? '取消收藏这条路线' : '收藏这条路线'} aria-pressed={saved}>{saved ? <Check size={20} /> : <Bookmark size={20} />}</button>
      </header>
      <div className="journey-focus-meta"><span>{place.city} / {place.name}</span><span>{isListening ? 'A WALK TO LISTEN' : 'A WALK TO READ'}</span></div>
      <div className="journey-listening-stage">
        <div className="journey-record-scene">
          <span className="journey-giant-number" aria-hidden="true">{numberLabel(index + 1)}</span>
          <div className={`journey-record ${playing ? 'journey-record-playing' : ''}`}>
            <div className="journey-record-grooves" />
            {chapter.image && <img src={chapter.image} alt="" />}
            <span className="journey-record-center" />
          </div>
          <span className="journey-record-caption">{isListening ? '给眼前的城市，一段耳朵的时间。' : '一页文字，读懂眼前的城市。'}</span>
        </div>
        <div className="journey-listening-copy">
          <div className="journey-chapter-label"><span>第 {numberLabel(index + 1)} 段 / 共 {numberLabel(chapters.length)} 段</span><span className="journey-mode-badge">{isListening ? <Headphones size={14} /> : <BookOpen size={14} />}{isListening ? '音频故事' : '文字手册'}</span></div>
          <h1 className="journey-focus-title" ref={titleRef} tabIndex={-1}>{chapter.story}</h1>
          <p className="journey-stop-address"><MapPin size={16} /><span>{chapter.title}</span></p>
          {isListening ? <>
            <p className="journey-audio-excerpt">{chapter.body.split('。').slice(0, 2).join('。')}。</p>
            <div className="journey-player">
              <div className="journey-progress-label"><span>{timeLabel(position)}</span><span>{timeLabel(totalDuration)}</span></div>
              <input className="journey-progress" type="range" min="0" max={totalDuration || 1} step="0.1" value={Math.min(position, totalDuration || 1)} aria-label="音频播放进度" aria-valuetext={`${timeLabel(position)}，共${timeLabel(totalDuration)}`} onChange={event => {
                const nextPosition = Number(event.target.value);
                if (audioRef.current) audioRef.current.currentTime = nextPosition;
                updateSession(previous => ({ ...previous, positions: { ...previous.positions, [index]: nextPosition } }));
              }} />
              <div className="journey-playback-controls" ref={playerControlsRef}>
                <button className="journey-skip" aria-label="上一段" disabled={index === 0} onClick={() => selectChapter(index - 1)}><SkipBack size={23} /><span>上一段</span></button>
                <button className="journey-play" aria-label={playing ? '暂停音频' : '播放音频'} onClick={() => { if (playing) pauseAudio(); else void playAudio(); }}>{playing ? <Pause size={29} fill="currentColor" /> : <Play size={29} fill="currentColor" />}</button>
                <button className="journey-skip" aria-label="下一段" disabled={index === chapters.length - 1} onClick={() => selectChapter(index + 1)}><SkipForward size={23} /><span>下一段</span></button>
              </div>
              <p className="journey-play-status" aria-live="polite">{playing ? <><Volume2 size={14} />正在播放，慢慢听。</> : position >= totalDuration - 0.3 && position > 0 ? '这一段听完了，下一段随时开始。' : position > 0 ? '已暂停，回来时从这里继续。' : '准备好了，就按下播放。'}</p>
              {audioError && <p className="journey-audio-error" role="status">{audioError}</p>}
            </div>
          </> : <div className="journey-text-reading"><p>{chapter.body}</p><div className="journey-reading-controls"><button disabled={index === 0} onClick={() => selectChapter(index - 1)}><ArrowLeft size={17} />上一段</button><button disabled={index === chapters.length - 1} onClick={() => selectChapter(index + 1)}>下一段<ArrowRight size={17} /></button></div></div>}
        </div>
      </div>
      <div className="journey-focus-bottom">
        {isListening && <details className="journey-disclosure" key={`transcript-${index}`}><summary><span>边听边读<span>这一段的完整文字</span></span><ChevronDown size={20} /></summary><div className="journey-transcript"><p>{chapter.body}</p></div></details>}
        <button className="journey-directory-link" onClick={() => openDirectory('focus')}><span><List size={19} />翻开章节目录<small>第 {numberLabel(index + 1)} 篇 / 共 {chapters.length} 篇</small></span><ArrowUpRight size={21} /></button>
        {hasAudio && <button className="journey-format-switch" onClick={() => { if (isListening) enterFocus(index, false, 'text'); else openPrelude(index); }}>{isListening ? <BookOpen size={17} /> : <Headphones size={17} />}{isListening ? '安静地读这一篇' : '听听这一篇'}<ArrowRight size={16} /></button>}
        <p className="journey-field-note">停在宽阔的公共步行区域。拥挤时，先照顾脚下和身边的人。</p>
      </div>
    </div> : <div className="journey-detail">
      <header className="journey-detail-header"><button className="journey-back" onClick={leaveJourney}><ArrowLeft size={19} />回到{place.city}</button><span className="journey-issue">见地城市手册 / {place.city}</span><button className={`journey-save ${saved ? 'journey-saved' : ''}`} onClick={onSave} aria-label={saved ? '取消收藏这条路线' : '收藏这条路线'} aria-pressed={saved}>{saved ? <Check size={20} /> : <Bookmark size={20} />}</button></header>
      <div className="journey-cover">
        <div className="journey-cover-copy">
          <div className="journey-overline"><span>{place.city} / {place.area}</span><span>{place.theme}</span></div>
          <h1 className="journey-cover-title">{place.name.split(' · ').map((part, partIndex) => <span key={partIndex}>{part}</span>)}</h1>
          <p className="journey-cover-subtitle">{place.title}</p>
          <div className="journey-cover-facts" aria-label="路线信息"><span>{place.minutes} 分钟</span><span>{place.distance} km</span><span>{place.demo ? '布局样例' : `${chapters.length} 段${hasAudio ? '声音' : '文字'}`}</span></div>
          <p className="journey-cover-deck">{coverDeck}</p>
          <div className="journey-cover-actions">{canStart ? <button ref={coverActionRef} className="journey-start" onClick={() => openDirectory('detail')}><span className="journey-start-folio" aria-hidden="true">{numberLabel(chapters.length)}<small>INDEX</small></span><span className="journey-start-copy"><strong>{session.visited ? '继续翻阅这段旅程' : '翻开这段旅程'}</strong><small>{hasAudio ? '先选一篇，再听或读' : '先选一篇，慢慢读'}</small></span><span className="journey-start-arrow"><ArrowRight size={22} strokeWidth={1.4} /></span></button> : <span className="journey-unavailable">{place.demo ? '布局演示 · 示例路线' : place.pending ? '这份手册，正在写给你。' : '手册内容准备中'}</span>}<span className="journey-cover-format">{place.demo ? '用于探索目录设计' : place.pending ? '可以先收藏，留给下次' : hasAudio ? `${chapters.length} 篇声音 · 可听，也可读` : `${chapters.length} 段文字 · 按自己的节奏`}</span></div>
        </div>
        <figure className="journey-cover-media">{place.image ? <img src={place.image} alt={`${place.name}路线封面`} onError={event => { event.currentTarget.style.visibility = 'hidden'; }} /> : <div className="journey-cover-placeholder"><span>{place.city}</span><small>EVERY PLACE HAS A STORY</small></div>}<figcaption><span>{place.demo ? '示例封面 / 布局演示' : '一份写给行走者的城市手册'}</span><span>{place.city}</span></figcaption>{canStart && <button className="journey-cover-stamp" aria-label="慢慢走，才看得见：看看沿途书签" onClick={revealBookmarks}><span>慢慢走</span><span>才看得见</span><small>看看沿途</small><ArrowDownStamp /></button>}</figure>
      </div>
      <div className="journey-facts"><div><strong>{place.minutes}</strong><span>分钟 / 留一点时间</span></div><div><strong>{place.distance}<i>km</i></strong><span>路线长度 / 从容慢行</span></div>{place.demo ? <div className="journey-facts-example"><strong>样例</strong><span>用于布局演示</span></div> : <div><strong>{numberLabel(chapters.length)}</strong><span>{hasAudio ? '段声音 / 关于眼前' : '段文字 / 认识这里'}</span></div>}<p>{place.demo ? '此处时长与距离为布局演示数据。' : '不用集齐什么。\n走过的一小段，也算数。'}</p></div>
      <div className="journey-story-intro"><div><span className="journey-section-label">01 / WHY THIS WALK</span><h2>把脚步放慢，<br />让城市展开。</h2></div><div><p>{place.description}</p><span className="journey-intro-note">{place.demo ? '示例内容没有音频、定位或可开始的导览。' : place.pending ? '内容仍在准备中，当前可预览路线介绍。' : hasAudio ? '到现场听，也可以先在这里认识它。' : '这条路线当前提供文字手册，暂不提供音频。'}</span></div></div>
      {canStart && chapters.length > 0 && <section ref={bookmarksRef} className={`journey-chapter-section journey-bookmarks ${bookmarksLit ? 'is-revealed' : ''}`} aria-labelledby="journey-bookmarks-title"><div className="journey-chapters-heading"><div><span className="journey-section-label">02 / BOOKMARKS ALONG THE WAY</span><h2 id="journey-bookmarks-title" tabIndex={-1}>沿途书签<span>，</span><br />先翻几页。</h2></div><span>预览 {Math.min(3, chapters.length)} 篇 · 共 {chapters.length} 篇</span></div><ol className="journey-chapter-list">{chapters.slice(0, 3).map((item, itemIndex) => <li key={itemIndex}><button onClick={() => openPrelude(itemIndex)} aria-label={`翻开第${itemIndex + 1}篇：${item.story}`}><span className="journey-chapter-number">{numberLabel(itemIndex + 1)}</span><div><span>{item.title}</span><h3>{item.story}</h3></div><span className="journey-chapter-end">{hasAudio ? timeLabel(audioLengths[itemIndex]) : '阅读'}<ArrowUpRight size={21} /></span></button></li>)}</ol><button ref={allChaptersRef} className="journey-all-chapters" onClick={() => openDirectory('detail')}><span>翻开全部目录 <small>{chapters.length} 篇</small></span><List size={20} /></button><p className="journey-preview-footnote">不必按顺序，停在你感兴趣的那一页。</p></section>}
      <footer className="journey-detail-footer"><span>见地 <i>JIAN DI</i></span><p>不急着抵达。<br />在途中，看见更多。</p><button className="journey-back" onClick={leaveJourney}>回到城市<ArrowRight size={18} /></button></footer>
    </div>}
    {visible && canStart && !session.focus && detailDock && !preludeOpen && !directoryOpen && <div className="journey-directory-dock"><span className="journey-dock-folio" aria-hidden="true">{numberLabel(chapters.length)}<small>篇</small></span><button onClick={() => openDirectory('detail')}><BookOpen size={19} strokeWidth={1.4} /><span>翻开目录</span><ArrowRight size={20} strokeWidth={1.4} /></button></div>}
    {visible && session.focus && isListening && playerDock && !preludeOpen && !directoryOpen && <div className="journey-listen-dock" aria-label="随身播放控制"><div className="journey-dock-caption"><i>{numberLabel(index + 1)}</i><span>{chapter.story}</span></div><div className="journey-dock-controls"><button className="journey-dock-secondary" onClick={() => openDirectory('focus')}><List size={20} /><span>目录</span></button><button className="journey-play" aria-label={playing ? '暂停音频' : '播放音频'} onClick={() => { if (playing) pauseAudio(); else void playAudio(); }}>{playing ? <Pause size={26} fill="currentColor" /> : <Play size={26} fill="currentColor" />}</button><button className="journey-dock-secondary" disabled={index === chapters.length - 1} onClick={() => selectChapter(index + 1)}><SkipForward size={20} /><span>下一篇</span></button></div></div>}
    {draftChapter && <JourneyPrelude open={preludeOpen && visible} routeName={place.name} chapter={draftChapter} number={numberLabel(draftIndex + 1)} count={chapters.length} hasAudio={hasAudio} time={timeLabel(audioLengths[draftIndex] || 0)} resumeAt={hasAudio && (session.positions[draftIndex] || 0) > 0.5 && (session.positions[draftIndex] || 0) < (audioLengths[draftIndex] || 0) - 0.5 ? timeLabel(session.positions[draftIndex]) : null} fromDirectory={preludeOrigin.current === 'directory'} onClose={closePrelude} onDirectory={() => preludeOrigin.current === 'directory' ? returnToDirectory() : openDirectory('prelude')} onStart={mode => { setPreludeOpen(false); enterFocus(draftIndex, mode === 'audio', mode); }} />}
    <ChapterDirectory open={directoryOpen && visible} chapters={chapters.map((item, i) => ({ id: String(i), title: item.story, place: item.title, durationLabel: hasAudio ? timeLabel(audioLengths[i] || 0) : '文字', visited: session.opened.includes(i) }))} preserveStateOnOpen={preserveDirectory} currentId={String(directoryIndex)} routeName={place.name} onClose={closeDirectory} onSelect={id => { directoryOrigin.current = session.focus ? 'focus' : 'detail'; setDirectoryIndex(Number(id)); setDirectoryOpen(false); openPrelude(Number(id), 'directory'); }} />
  </section>;
}

function ArrowDownStamp() {
  return <svg width="32" height="20" viewBox="0 0 32 20" fill="none"><path d="M16 1v16M8 10l8 8 8-8" stroke="currentColor" strokeWidth="1.7" /></svg>;
}
