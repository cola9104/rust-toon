import { beforeEach, describe, expect, it } from 'vitest';
import { createProjectLocationStore, resolveProjectScript } from './project-location';
beforeEach(() => localStorage.clear());
describe('project position memory', () => {
  it('restores stage, episode and nodes independently for each user and project', () => {
    const store = createProjectLocationStore('alice', localStorage);
    store.write(1, { stage: 'production', scriptId: 10, nodes: { 10: 'storyboard', 11: 'video' } });
    store.write(2, { stage: 'archive', scriptId: 20, nodes: {} });
    expect(store.read(1)).toEqual({ stage: 'production', scriptId: 10, nodes: { 10: 'storyboard', 11: 'video' } });
    expect(store.read(2).stage).toBe('archive');
    expect(createProjectLocationStore('bob', localStorage).read(1).stage).toBe('novel');
  });
  it('prioritizes a valid deep link and falls back when an episode was deleted', () => {
    expect(resolveProjectScript([10, 11], 10, '11')).toBe(11);
    expect(resolveProjectScript([10, 11], 11, '999')).toBe(11);
    expect(resolveProjectScript([10, 11], 999)).toBe(10);
    expect(resolveProjectScript([], 999)).toBeUndefined();
  });
  it('ignores corrupt or unavailable browser storage', () => {
    localStorage.setItem('toonflow:location:v1:alice:1', '{oops');
    expect(createProjectLocationStore('alice', localStorage).read(1)).toEqual({ stage: 'novel', nodes: {} });
    const store = createProjectLocationStore('alice', { getItem: () => { throw Error('blocked'); }, setItem: () => { throw Error('full'); } });
    expect(store.read(1).stage).toBe('novel'); expect(() => store.write(1, { stage: 'archive', nodes: {} })).not.toThrow();
  });
});
