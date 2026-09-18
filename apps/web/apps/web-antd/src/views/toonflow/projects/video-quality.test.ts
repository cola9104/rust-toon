import { describe, expect, it } from 'vitest';
import { isUsableVideo, videoQualityPresentation } from './video-quality';

describe('video quality acceptance', () => {
  it('keeps a downloaded clip unavailable until the worker accepts it', () => {
    const video = { state: '生成中', src: '/clip.mp4', generationContext: { quality: { state: 'pending' } } };
    expect(isUsableVideo(video)).toBe(false);
    expect(videoQualityPresentation(video).label).toBe('等待基础质检');
    expect(isUsableVideo({ ...video, state: '生成成功', generationContext: { quality: { state: 'passed' } } })).toBe(true);
    expect(isUsableVideo({ ...video, state: '生成成功' })).toBe(false);
  });
  it('preserves legacy playback while distinguishing uninspected and rejected clips', () => {
    expect(isUsableVideo({ state: '生成成功', src: '/legacy.mp4' })).toBe(true);
    expect(videoQualityPresentation({ state: '生成成功' }).label).toBe('尚未质检');
    expect(isUsableVideo({ state: '生成失败', src: '/bad.mp4' })).toBe(false);
    expect(videoQualityPresentation({ state: '已取消', generationContext: { quality: { state: 'pending' } } }).label).toBe('已取消');
    const display = videoQualityPresentation({ generationContext: { quality: { state: 'passed', warnings: ['black_start: 0'] } } });
    expect(display.color).toBe('orange');
    expect(display.detail).toContain('仍需审片');
  });
});
