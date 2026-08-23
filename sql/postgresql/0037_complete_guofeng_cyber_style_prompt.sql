-- Complete the legacy Guofeng Cyber 3D style entry so the style library can
-- show and reuse an actual visual description instead of a formatting note.
UPDATE toonflow.art_styles
SET prompt = '国风赛博3D：以中国传统美学为骨架，融合未来城市与数字科技视觉。采用高精度3D建模、PBR材质、细腻纹理和电影级光影；结合青瓷青、朱砂红、鎏金、墨黑等东方色彩，加入传统纹样、飞檐、玉石、丝绸和书法结构元素。赛博霓虹仅作为局部光源与交互点缀，整体保持东方含蓄、秩序感和空间层次，画面精致、统一、具有史诗感。避免西式奇幻、现代写实摄影、低模塑料质感、杂乱文字和无意义的霓虹堆叠。'
WHERE id = 560107
  AND name = '国风赛博3D';
