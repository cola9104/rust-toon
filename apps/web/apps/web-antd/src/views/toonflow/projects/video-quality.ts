export function videoQualityPresentation(video: any) {
  const quality = (video?.generationContext ?? video?.generation_context)?.quality;
  const errors: string[] = Array.isArray(quality?.errors) ? quality.errors.filter((v: unknown) => typeof v === 'string') : [];
  const warnings: string[] = Array.isArray(quality?.warnings) ? quality.warnings.filter((v: unknown) => typeof v === 'string') : [];
  if (video?.state === '已取消') return { color: 'default', label: '已取消', detail: '本次视频任务已取消。' };
  if (quality?.state === 'passed') return {
    color: warnings.length ? 'orange' : 'green',
    label: warnings.length ? '基础检查通过 · 有提醒' : '基础检查通过',
    detail: ['已检查文件、完整解码、时长、比例和所需音轨；人物、动作与口型仍需审片。', ...warnings.map((v) => `黑场或静止片段提醒：${v}`)].join('\n'),
  };
  if (quality?.state === 'rejected' || quality?.state === 'error') return {
    color: 'red', label: quality.state === 'error' ? '质检执行失败' : '基础检查不通过',
    detail: errors.join('；') || video?.errorReason || '请检查视频或重新执行质检。',
  };
  if (quality?.state === 'pending') return { color: 'processing', label: '等待基础质检', detail: '视频已归档，正在等待 Worker 检查；通过后才能选用。' };
  if (quality?.state === 'running') return { color: 'processing', label: '基础质检中', detail: '正在检查视频完整性、时长、比例和音轨；通过后才能选用。' };
  return { color: 'default', label: '尚未质检', detail: '可对已归档的视频执行基础质量检查。' };
}

export function isUsableVideo(video: any): boolean {
  const quality = (video?.generationContext ?? video?.generation_context)?.quality;
  return ['生成成功', '已完成'].includes(video?.state)
    && Boolean(video?.src || video?.filePath || video?.file_path)
    && (!quality || quality.state === 'passed');
}
