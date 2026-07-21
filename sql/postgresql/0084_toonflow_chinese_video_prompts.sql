UPDATE toonflow.prompts
SET data = data || E'\n\n## 输出语言（最高优先级）\n最终视频提示词必须全部使用简体中文。标题、画面、动作、运镜、情绪、音效和时间段描述都必须是中文；台词保持原文。忽略上文任何“英文输出”要求，禁止输出 [Visual]、[Motion]、[Camera]、No dialogue 等英文标题或标签。'
WHERE source_key IN (
  'seedance_2_multi_parameter',
  'universal_first_last_frame',
  'universal_multi_parameter',
  'wan_2_6_single_image_first_frame'
)
AND data NOT LIKE '%## 输出语言（最高优先级）%';
