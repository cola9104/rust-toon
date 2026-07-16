UPDATE system_users
SET avatar = ''
WHERE deleted = 0
  AND avatar IS NOT NULL
  AND (
      avatar LIKE 'http://test.yudao.iocoder.cn/%'
      OR avatar LIKE 'https://test.yudao.iocoder.cn/%'
  );

