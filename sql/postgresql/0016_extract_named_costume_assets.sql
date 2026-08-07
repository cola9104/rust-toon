UPDATE toonflow.prompts
SET data = replace(
    replace(
        data,
        'costume=确实需要跨不同角色复用的统一服装方案。',
        'costume=需要独立保持造型一致的穿戴物或服装方案；跨角色复用、被剧本明确命名、被剧情强调、需要特写或需要单独生成图片的帽子、制服及其他穿戴物，即使只由一个角色穿戴，也必须创建 costume。'
    ),
    '普通人物服装只保存在 appearances，不创建独立 costume 图片资产。',
    '未被明确命名、未被剧情强调且无需单独生成的普通人物服装只保存在 appearances；被明确命名、被剧情强调、需要特写或需要单独生成的穿戴物必须同时创建独立 costume 资产。比如“黑色鸭舌帽”“深紫技师装”必须进入 newAssets 或 existingAssetRefs，type 固定为 costume，并继续在对应人物 appearance.costumePrompt 中描述其穿戴效果。'
)
WHERE source_key = 'script_asset_extraction'
  AND data NOT LIKE '%比如“黑色鸭舌帽”“深紫技师装”必须进入%';
