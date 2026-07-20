export interface ImportedNovelChapter {
  chapter: string;
  chapterData: string;
  index: number;
  reel: string;
}

const CHAPTER_HEADING = /^\s*(?:正文\s*)?(?:第\s*[0-9零〇一二三四五六七八九十百千万两]+\s*[章节回卷部集]|Chapter\s+\d+)(?:\s*[:：.．、—-]?\s*.*)?$/i;

export function parseNovelText(
  content: string,
  fallbackTitle = '第1章',
): ImportedNovelChapter[] {
  const normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replace(/^\uFEFF/, '').trim();
  if (!normalized) return [];
  const chapters: ImportedNovelChapter[] = [];
  let title: null | string = null;
  let body: string[] = [];
  const append = () => {
    if (!title) return;
    chapters.push({ chapter: title, chapterData: body.join('\n').trim(), index: 0, reel: '' });
  };
  for (const line of normalized.split('\n')) {
    if (CHAPTER_HEADING.test(line)) {
      append();
      title = line.trim();
      body = [];
    } else if (title) {
      body.push(line);
    }
  }
  append();
  const populated = chapters.filter((chapter) => chapter.chapterData.trim());
  return populated.length > 0
    ? populated
    : [{ chapter: fallbackTitle, chapterData: normalized, index: 0, reel: '' }];
}
