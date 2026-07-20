import { describe, expect, it } from 'vitest';
import { parseNovelText } from './novel-import';

describe('parseNovelText', () => {
  it('parses more than nine hundred Chinese chapters', () => {
    const content = Array.from({ length: 950 }, (_, index) =>
      `第${index + 1}章 标题${index + 1}\n这是第${index + 1}章正文。`,
    ).join('\n');
    const chapters = parseNovelText(content, '小说');
    expect(chapters).toHaveLength(950);
    expect(chapters[899]?.chapter).toBe('第900章 标题900');
  });

  it('supports spaced Chinese and English headings', () => {
    const chapters = parseNovelText('第 一 章：开始\n正文一\nChapter 2 - Continue\n正文二');
    expect(chapters.map((item) => item.chapter)).toEqual(['第 一 章：开始', 'Chapter 2 - Continue']);
  });

  it('imports content without headings as one chapter', () => {
    expect(parseNovelText('整篇正文', '作品名')).toEqual([
      { chapter: '作品名', chapterData: '整篇正文', index: 0, reel: '' },
    ]);
  });
});
