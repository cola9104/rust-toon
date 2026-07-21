type ProductionDocumentKind = 'scriptPlan' | 'storyboardTable';

function unwrapValue(value: unknown): string {
  if (!value) return '';
  if (typeof value === 'string') {
    const text = value.trim();
    if (text.startsWith('{')) {
      try {
        return unwrapValue(JSON.parse(text));
      } catch {
        return text;
      }
    }
    return text;
  }
  if (typeof value === 'object') {
    const record = value as Record<string, unknown>;
    for (const key of ['content', 'markdown', 'text', 'value']) {
      if (typeof record[key] === 'string') return unwrapValue(record[key]);
    }
  }
  return JSON.stringify(value, null, 2);
}

function escapeCell(value: string | null) {
  return (value ?? '').replaceAll('|', '\\|').replaceAll('\n', ' ');
}

function scriptPlanXmlToMarkdown(xml: string) {
  const document = new DOMParser().parseFromString(xml, 'application/xml');
  if (document.querySelector('parsererror')) return '';

  const scenes = [...document.querySelectorAll('sceneSummaryTable > scene')];
  const lines = [
    '## 分场汇总表',
    '',
    '| 场次 | 场景名 | 台词条数 | 台词字数 | 情绪浓度 | 情绪基调 |',
    '|---|---|---:|---:|---:|---|',
    ...scenes.map((scene) =>
      `| ${escapeCell(scene.getAttribute('id'))} | ${escapeCell(scene.getAttribute('name'))} | ${escapeCell(scene.getAttribute('dialogueCount'))} | ${escapeCell(scene.getAttribute('dialogueChars'))} | ${escapeCell(scene.getAttribute('emotionIntensity'))} | ${escapeCell(scene.getAttribute('emotionTone'))} |`,
    ),
    '',
    '## 逐场注意事项',
    '',
  ];

  const fieldLabels: Record<string, string> = {
    ambientSound: '环境音',
    consistency: '一致性锚点',
    emotionalBeat: '情感砸点',
    pitfall: '易错提示',
    spatial: '空间距离',
  };
  for (const note of document.querySelectorAll('sceneNotes > note')) {
    lines.push(`### ${note.getAttribute('scene') ?? ''}`, '');
    for (const [tag, label] of Object.entries(fieldLabels)) {
      const content = note.querySelector(tag)?.textContent?.trim();
      if (content) lines.push(`- **${label}**：${content}`);
    }
    lines.push('');
  }

  lines.push('## 场间过渡', '');
  const transitions = document.querySelector('transitions')?.textContent?.trim();
  lines.push(transitions || '无');
  return lines.join('\n').trim();
}

export function normalizeProductionDocument(
  value: unknown,
  kind: ProductionDocumentKind,
) {
  let text = unwrapValue(value);
  const tagMatch = text.match(new RegExp(`<${kind}>([\\s\\S]*?)<\\/${kind}>`, 'i'));
  if (tagMatch?.[1]) text = tagMatch[1].trim();

  text = text
    .replace(/^```(?:markdown|md|xml)?\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();

  if (kind === 'scriptPlan' && /<sceneSummaryTable[\s>]/i.test(text)) {
    const converted = scriptPlanXmlToMarkdown(`<scriptPlan>${text}</scriptPlan>`);
    if (converted) return converted;
  }
  return text;
}
