import { describe, expect, it } from 'vitest';

import {
  extractScriptItems,
  extractXmlContent,
  formatEventDisplay,
  renderMarkdown,
} from './production-content';

describe('production content helpers', () => {
  it('extracts agent XML sections and script items', () => {
    expect(extractXmlContent('<plan>  outline  </plan>', 'plan')).toBe('outline');
    expect(
      extractScriptItems('<scriptItem name="第一集">场景一</scriptItem>'),
    ).toBe('### 第一集\n\n场景一');
  });

  it('keeps invalid event payloads and formats valid arrays', () => {
    expect(formatEventDisplay('not-json')).toBe('not-json');
    expect(formatEventDisplay('[{"name":"相遇","detail":"车站"}]')).toBe(
      '1.相遇：车站',
    );
  });

  it('escapes HTML before rendering the supported markdown subset', () => {
    expect(renderMarkdown('# 标题\n\n**内容** <script>')).toContain(
      '<h2>标题</h2>',
    );
    expect(renderMarkdown('<script>')).toBe('&lt;script&gt;');
  });
});
