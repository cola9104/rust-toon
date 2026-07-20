export type AssetCategory = 'costume' | 'material' | 'role' | 'scene' | 'tool';

export const ASSET_CATEGORY_OPTIONS: Array<{
  label: string;
  value: AssetCategory;
}> = [
  { label: '角色', value: 'role' },
  { label: '场景', value: 'scene' },
  { label: '道具', value: 'tool' },
  { label: '服装', value: 'costume' },
  { label: '素材', value: 'material' },
];

const DOMAIN_ASSET_TYPES = new Set(['costume', 'role', 'scene', 'tool']);

export function assetCategory(type: string): AssetCategory {
  return DOMAIN_ASSET_TYPES.has(type)
    ? (type as 'costume' | 'role' | 'scene' | 'tool')
    : 'material';
}

export function assetTypeLabel(type: string) {
  return {
    role: '角色',
    scene: '场景',
    tool: '道具',
    costume: '服装',
  }[type] ?? '素材';
}

export function isAssetInCategory(type: string, category: AssetCategory) {
  return assetCategory(type) === category;
}

export function assetFileUrl(path?: string) {
  if (!path || /^(?:data:|https?:\/\/)/i.test(path) || path.startsWith('/api/')) {
    return path ?? '';
  }
  return path.startsWith('/toonflow/') ? `/api${path}` : path;
}
