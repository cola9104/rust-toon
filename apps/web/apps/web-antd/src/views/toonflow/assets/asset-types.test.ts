import { describe, expect, it } from 'vitest';

import {
  assetCategory,
  assetFileUrl,
  assetTypeLabel,
  isAssetInCategory,
} from './asset-types';

describe('asset type categories', () => {
  it.each([
    ['role', 'role', '角色'],
    ['scene', 'scene', '场景'],
    ['tool', 'tool', '道具'],
    ['costume', 'costume', '服装'],
    ['audio', 'material', '素材'],
    ['clip', 'material', '素材'],
  ])('maps %s into its display category', (type, category, label) => {
    expect(assetCategory(type)).toBe(category);
    expect(assetTypeLabel(type)).toBe(label);
  });

  it('groups unknown media types into material', () => {
    expect(isAssetInCategory('clip', 'material')).toBe(true);
    expect(isAssetInCategory('clip', 'role')).toBe(false);
  });

  it('routes backend-relative asset files through the API proxy', () => {
    expect(assetFileUrl('/toonflow/assets/files/role.jpg')).toBe(
      '/api/toonflow/assets/files/role.jpg',
    );
    expect(assetFileUrl('https://cdn.example.com/role.jpg')).toBe(
      'https://cdn.example.com/role.jpg',
    );
  });
});
