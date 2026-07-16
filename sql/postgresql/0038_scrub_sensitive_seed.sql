UPDATE system_mail_account
SET password = 'enc:v1:' || encode(convert_to('not-configured', 'UTF8'), 'base64'),
    update_time = now()
WHERE password IS NOT NULL
  AND password <> ''
  AND password NOT LIKE 'enc:v1:%';

UPDATE system_sms_channel
SET api_key = 'enc:v1:' || encode(convert_to('not-configured', 'UTF8'), 'base64'),
    api_secret = CASE
        WHEN api_secret IS NULL OR api_secret = '' THEN api_secret
        ELSE 'enc:v1:' || encode(convert_to('not-configured', 'UTF8'), 'base64')
    END,
    update_time = now()
WHERE api_key NOT LIKE 'enc:v1:%'
   OR (api_secret IS NOT NULL AND api_secret <> '' AND api_secret NOT LIKE 'enc:v1:%');

UPDATE infra_data_source_config
SET password = 'enc:v1:' || encode(convert_to('not-configured', 'UTF8'), 'base64'),
    update_time = now()
WHERE password IS NOT NULL
  AND password <> ''
  AND password NOT LIKE 'enc:v1:%';

UPDATE system_users
SET login_ip = '',
    login_date = NULL
WHERE login_ip <> ''
   OR login_date IS NOT NULL;

DELETE FROM system_user_role WHERE user_id IN (
    SELECT id FROM system_users WHERE username IN ('codex_excel_user')
);

DELETE FROM system_user_post WHERE user_id IN (
    SELECT id FROM system_users WHERE username IN ('codex_excel_user')
);

DELETE FROM system_users WHERE username IN ('codex_excel_user');
