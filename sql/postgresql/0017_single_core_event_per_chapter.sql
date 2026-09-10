-- Keep JSON transport while summarizing each chapter as one core event.
UPDATE toonflow.prompts
SET data = replace(
    replace(data,
        '即使章节信息较少，也至少输出 1 个事件，不得返回空内容',
        '每章只概括一条核心事件，JSON 数组必须恰好包含一个对象，不得返回空内容'),
    '每3000字提取3-5个事件，短章节至少提取1个事件',
    '每章只概括一条核心事件，以整章为单位保留主要行动、结果和转折，不按字数或场景拆分'),
    use_data = '每章一条核心事件，使用 JSON 数组输出。'
WHERE source_key = 'eventExtraction'
  AND (data LIKE '%每3000字提取3-5个事件，短章节至少提取1个事件%'
    OR data LIKE '%即使章节信息较少，也至少输出 1 个事件，不得返回空内容%');
