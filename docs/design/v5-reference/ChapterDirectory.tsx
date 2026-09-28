import { useLayoutEffect, useMemo, useRef, useState } from 'react';
import { ArrowRight, ChevronDown, ChevronLeft, ChevronRight, Search, X } from 'lucide-react';
import './chapter-directory.css';

export type DirectoryChapter = {
  id: string;
  title: string;
  place: string;
  durationLabel?: string;
  visited: boolean;
};

interface ChapterDirectoryProps {
  open: boolean;
  chapters: DirectoryChapter[];
  currentId: string;
  routeName: string;
  preserveStateOnOpen?: boolean;
  onClose: () => void;
  onSelect: (id: string) => void;
}

type ProgressFilter = 'all' | 'new' | 'visited';
const PAGE_SIZE = 12;
const folio = (value: number) => String(value).padStart(2, '0');

export default function ChapterDirectory({ open, chapters, currentId, routeName, preserveStateOnOpen = false, onClose, onSelect }: ChapterDirectoryProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const returnFocusRef = useRef<HTMLElement | null>(null);
  const onCloseRef = useRef(onClose);
  const [query, setQuery] = useState('');
  const [progress, setProgress] = useState<ProgressFilter>('all');
  const [page, setPage] = useState(0);
  const [compact, setCompact] = useState(false);
  const savedPositionRef = useRef({ top: 0, compact: false });
  const pendingPositionRef = useRef<{ current: boolean; top: number } | null>(null);
  const previousViewRef = useRef({ open: false, routeName, page: 0, query: '', progress: 'all' as ProgressFilter });
  onCloseRef.current = onClose;

  const indexedChapters = useMemo(() => chapters.map((chapter, index) => ({ ...chapter, sequence: index + 1 })), [chapters]);
  const matches = useMemo(() => {
    const needle = query.trim().toLocaleLowerCase();
    return indexedChapters.filter(chapter => {
      const matchesText = !needle || `${chapter.title} ${chapter.place} ${chapter.sequence}`.toLocaleLowerCase().includes(needle);
      const matchesProgress = progress === 'all' || (progress === 'visited' ? chapter.visited : !chapter.visited);
      return matchesText && matchesProgress;
    });
  }, [indexedChapters, query, progress]);
  const pageCount = Math.max(1, Math.ceil(matches.length / PAGE_SIZE));
  const activePage = Math.min(page, pageCount - 1);
  const start = activePage * PAGE_SIZE;
  const visibleChapters = matches.slice(start, start + PAGE_SIZE);
  const longDirectory = chapters.length > PAGE_SIZE;

  useLayoutEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;
    if (!open) {
      if (dialog.open) dialog.close();
      return;
    }
    returnFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    if (!dialog.open) dialog.showModal();
    closeButtonRef.current?.focus({ preventScroll: true });
    dialog.scrollTop = 0;
    return () => {
      document.body.style.overflow = previousOverflow;
      if (dialog.open) dialog.close();
      const previousFocus = returnFocusRef.current;
      if (previousFocus?.isConnected) previousFocus.focus({ preventScroll: true });
    };
  }, [open]);

  useLayoutEffect(() => {
    const previous = previousViewRef.current;
    const routeChanged = previous.routeName !== routeName;
    const opening = open && !previous.open;
    const browsingChanged = previous.page !== activePage || previous.query !== query || previous.progress !== progress;
    previousViewRef.current = { open, routeName, page: activePage, query, progress };

    if (routeChanged || (opening && !preserveStateOnOpen)) {
      setQuery('');
      setProgress('all');
      setPage(Math.floor(Math.max(0, chapters.findIndex(chapter => chapter.id === currentId)) / PAGE_SIZE));
      setCompact(false);
      savedPositionRef.current = { top: 0, compact: false };
      pendingPositionRef.current = { current: true, top: 0 };
    } else if (opening) {
      setCompact(savedPositionRef.current.compact);
      pendingPositionRef.current = { current: false, top: savedPositionRef.current.top };
    } else if (open && browsingChanged && !pendingPositionRef.current) {
      pendingPositionRef.current = { current: false, top: 0 };
    }

    if (!open) return;
    const position = pendingPositionRef.current;
    if (!position) return;
    const frame = requestAnimationFrame(() => {
      const list = listRef.current;
      if (!list) return;
      list.scrollTop = position.top;
      if (position.current) {
        const chapter = list.querySelector<HTMLElement>('[aria-current]');
        if (chapter) {
          const rowBounds = chapter.getBoundingClientRect();
          const listBounds = list.getBoundingClientRect();
          list.scrollTop += rowBounds.top - listBounds.top - (list.clientHeight - rowBounds.height) / 2;
        }
      }
      if (dialogRef.current) dialogRef.current.scrollTop = 0;
      const shouldCompact = longDirectory && (savedPositionRef.current.compact || list.scrollTop > 72);
      savedPositionRef.current = { top: list.scrollTop, compact: shouldCompact };
      setCompact(shouldCompact);
      pendingPositionRef.current = null;
    });
    return () => cancelAnimationFrame(frame);
  }, [activePage, query, progress, open, routeName, preserveStateOnOpen]);

  function rememberPosition() {
    savedPositionRef.current = { top: listRef.current?.scrollTop ?? 0, compact };
  }

  function closeDirectory() {
    rememberPosition();
    onCloseRef.current();
  }

  function resetFilters() {
    setQuery('');
    setProgress('all');
    setPage(0);
  }

  return <dialog
    ref={dialogRef}
    className={`chapter-directory${compact && longDirectory ? ' is-compact' : ''}`}
    aria-labelledby="chapter-directory-title"
    aria-describedby="chapter-directory-description"
    onCancel={event => { event.preventDefault(); closeDirectory(); }}
    onKeyDown={event => {
      if (event.key !== 'Tab') return;
      const dialog = event.currentTarget;
      const controls = Array.from(dialog.querySelectorAll<HTMLElement>('button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex="0"]'))
        .filter(control => control.tabIndex >= 0 && control.getClientRects().length > 0 && getComputedStyle(control).visibility !== 'hidden' && !control.closest('[hidden], [inert]'));
      const first = controls[0];
      const last = controls[controls.length - 1];
      const focused = document.activeElement;
      if (!first || !last) { event.preventDefault(); dialog.focus(); return; }
      if (event.shiftKey && (focused === first || !dialog.contains(focused))) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && (focused === last || !dialog.contains(focused))) {
        event.preventDefault();
        first.focus();
      }
    }}
    onClick={event => {
      if (event.target !== event.currentTarget) return;
      const bounds = event.currentTarget.getBoundingClientRect();
      if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) closeDirectory();
    }}
  >
    <header className="chapter-directory-header">
      <div className="chapter-directory-topline">
        <span>本刊目录 <i>INDEX</i></span>
        <button ref={closeButtonRef} type="button" className="chapter-directory-close" aria-label="关闭章节目录" onClick={closeDirectory}><X size={21} strokeWidth={1.5} /></button>
      </div>
      <div className="chapter-directory-title-row">
        <h2 id="chapter-directory-title"><span>翻到</span>哪一页<span className="chapter-directory-period">。</span></h2>
        <div className="chapter-directory-route"><span>{routeName}</span><b>{folio(chapters.length)}</b><small>篇城市故事</small></div>
      </div>
      <p id="chapter-directory-description" className="chapter-directory-description">挑一页，从你感兴趣的地方开始。</p>
      <label className="chapter-directory-search">
        <Search size={17} strokeWidth={1.5} aria-hidden="true" />
        <input type="search" aria-label="搜索章节或地点" placeholder="找一个地点，或一段故事" value={query} onChange={event => { setQuery(event.target.value); setPage(0); }} />
      </label>
      <div className="chapter-directory-filterline">
        <div className="chapter-directory-filters" role="group" aria-label="章节阅读进度">
          {([['all', '全部'], ['new', '未翻阅'], ['visited', '翻过']] as const).map(([value, label]) => <button key={value} type="button" aria-pressed={progress === value} onClick={() => { setProgress(value); setPage(0); }}>{label}</button>)}
        </div>
        <span aria-live="polite">{matches.length} 篇</span>
      </div>
    </header>

    <div ref={listRef} className="chapter-directory-scroll" onScroll={event => {
      if (!open || pendingPositionRef.current) return;
      const top = event.currentTarget.scrollTop;
      // Keep the compact heading for this browse, so changing its height cannot toggle it back and forth.
      const shouldCompact = compact || (longDirectory && top > 72);
      savedPositionRef.current = { top, compact: shouldCompact };
      if (shouldCompact !== compact) setCompact(shouldCompact);
    }}>
      {visibleChapters.length > 0 ? <ol className="chapter-directory-list" start={start + 1}>
        {visibleChapters.map(chapter => <li key={chapter.id}>
          <button type="button" className={chapter.id === currentId ? 'chapter-directory-row is-current' : 'chapter-directory-row'} aria-current={chapter.id === currentId ? 'true' : undefined} onClick={() => { rememberPosition(); onSelect(chapter.id); }}>
            <span className="chapter-directory-number">{folio(chapter.sequence)}</span>
            <span className="chapter-directory-copy"><strong>{chapter.title}</strong><span>{chapter.place}{chapter.durationLabel && <i>{chapter.durationLabel}</i>}</span></span>
            <ArrowRight size={17} strokeWidth={1.4} aria-hidden="true" />
            {chapter.id === currentId && <span className="chapter-directory-sr-only">当前章节</span>}
          </button>
        </li>)}
      </ol> : <div className="chapter-directory-empty"><span>这一页，<br />暂时留白。</span><p>{chapters.length ? '换一个词，或看看其他章节。' : '故事还在准备，稍后再来翻阅。'}</p>{chapters.length > 0 && <button type="button" onClick={resetFilters}>查看全部故事 <ArrowRight size={16} /></button>}</div>}
    </div>

    <footer className={`chapter-directory-footer${pageCount === 1 ? ' is-single-page' : ''}`}>
      {pageCount > 1 && <div className="chapter-directory-pagination">
        <button type="button" aria-label="上一页章节" disabled={activePage === 0 || !matches.length} onClick={() => setPage(activePage - 1)}><ChevronLeft size={20} strokeWidth={1.5} /></button>
        <label className="chapter-directory-jump"><span className="chapter-directory-sr-only">跳转章节范围</span><select aria-label="跳转章节范围" value={activePage} disabled={!matches.length} onChange={event => setPage(Number(event.target.value))}>{Array.from({ length: pageCount }, (_, index) => <option value={index} key={index}>{matches.length ? `第 ${index * PAGE_SIZE + 1}–${Math.min((index + 1) * PAGE_SIZE, matches.length)} 项 / ${matches.length}` : '第 0 项 / 0'}</option>)}</select><ChevronDown size={13} aria-hidden="true" /></label>
        <button type="button" aria-label="下一页章节" disabled={activePage >= pageCount - 1 || !matches.length} onClick={() => setPage(activePage + 1)}><ChevronRight size={20} strokeWidth={1.5} /></button>
      </div>}
      <p>按自己的节奏，一页一页走。</p>
    </footer>
  </dialog>;
}
