import { useEffect, useRef } from 'react';
import { ArrowLeft, ArrowRight, BookOpen, List, Play, X } from 'lucide-react';

interface PreludeProps {
  open: boolean;
  routeName: string;
  chapter: { title: string; story: string; image: string };
  number: string;
  count: number;
  hasAudio: boolean;
  time: string;
  resumeAt: string | null;
  fromDirectory?: boolean;
  onClose: () => void;
  onDirectory: () => void;
  onStart: (mode: 'audio' | 'text') => void;
}

export default function JourneyPrelude({ open, routeName, chapter, number, count, hasAudio, time, resumeAt, fromDirectory = false, onClose, onDirectory, onStart }: PreludeProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const dialog = dialogRef.current;
    if (!open || !dialog) return;
    const previous = document.activeElement as HTMLElement | null;
    const overflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    if (!dialog.open) dialog.showModal();
    return () => {
      dialog.close();
      document.body.style.overflow = overflow;
      if (previous?.isConnected) previous.focus({ preventScroll: true });
    };
  }, [open]);

  return <dialog ref={dialogRef} className="journey-prelude" aria-labelledby="journey-prelude-title" onKeyDown={event => {
    if (event.key !== 'Tab') return;
    const controls = [...event.currentTarget.querySelectorAll<HTMLElement>('button:not(:disabled), input, select, [tabindex="0"]')].filter(element => element.getClientRects().length);
    const first = controls[0], last = controls.at(-1);
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
  }} onCancel={event => { event.preventDefault(); onClose(); }} onClick={event => {
    const rect = event.currentTarget.getBoundingClientRect();
    if (event.target === event.currentTarget && (event.clientY < rect.top || event.clientY > rect.bottom || event.clientX < rect.left || event.clientX > rect.right)) onClose();
  }}>
    <div className="prelude-handle" aria-hidden="true" />
    <header className={`prelude-top ${fromDirectory ? 'has-back' : ''}`}>{fromDirectory ? <><button className="prelude-back" onClick={onClose}><ArrowLeft size={19} strokeWidth={1.4} /><span>返回目录</span></button><span>见地 <i>/</i> 一页序言</span></> : <><span>见地 <i>/</i> 一页序言</span><button aria-label="合上序页" onClick={onClose}><X size={22} strokeWidth={1.3} /></button></>}</header>
    <div className="prelude-scroll">
      <span className="prelude-eyebrow">{routeName} · 共 {count} 篇</span>
      <h2 id="journey-prelude-title">先翻一页，<br /><em>再{hasAudio ? '听' : '读'}一座城。</em></h2>
      <div className="prelude-leaf" key={number}>
        <div className="prelude-image">{chapter.image && <img src={chapter.image} alt="" />}<span aria-hidden="true">{number}</span></div>
        <div className="prelude-copy"><span>第 {number} 篇 <i>·</i> {hasAudio ? time : '文字手册'}</span><h3>{chapter.story}</h3><p>{chapter.title}</p></div>
      </div>
      <p className="prelude-note">{resumeAt ? `上次听到 ${resumeAt}，这一页替你留着。` : '停在这一页，让故事慢慢展开。'}</p>
      {!fromDirectory && <button className="prelude-directory" onClick={onDirectory}><span><List size={16} />从目录挑一篇</span><ArrowRight size={18} /></button>}
    </div>
    <footer className="prelude-actions">
      {hasAudio && <button className="prelude-listen" onClick={() => onStart('audio')}><span><i aria-hidden="true">{number}</i>{resumeAt ? '继续听这一篇' : '播放这一篇'}</span><span className="prelude-play-mark"><Play size={18} fill="currentColor" /></span></button>}
      <button className={`prelude-read ${!hasAudio ? 'is-primary' : ''}`} onClick={() => onStart('text')}><span><BookOpen size={18} strokeWidth={1.4} />阅读这一篇</span><ArrowRight size={19} strokeWidth={1.4} /></button>
    </footer>
  </dialog>;
}
