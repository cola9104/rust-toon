UPDATE toonflow.skill_list
SET content = replace(
  replace(
    replace(
      content,
      '角色父资产默认即为该角色对应身份的基础着装（由 `art_character.md` 根据角色描述生成）。变身/换装类衍生按对应风格的 `art_character_derivative.md` 落地。',
      '角色父资产统一为中性基础底模：男性仅穿无图案白色安全短裤，女性仅穿无图案白色抹胸和白色安全短裤。剧本中的所有服装搭配均作为角色衍生资产，按对应风格的 `art_character_derivative.md` 落地。'
    ),
    '角色只提取「变身状态」类衍生，三个方向——①**服装**',
    '角色提取「服装与变身状态」衍生，三个方向——①**服装**'
  ),
  '仅当剧本中角色出现明确的换装/变身/形态改变时才补充对应衍生；若全程维持基础着装且无变身、无形变，则不衍生',
  '剧本中角色实际穿着的每套服装均须作为衍生资产；同一套服装跨镜头复用，不重复创建。无剧情服装、无变身、无形变时才无需衍生'
), update_time = EXTRACT(EPOCH FROM NOW()) * 1000
WHERE path = 'production_execution_derive_assets.md';
