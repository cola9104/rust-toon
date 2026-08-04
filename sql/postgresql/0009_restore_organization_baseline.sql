-- The consolidated baseline retained users that reference department 103 and
-- legacy post IDs, but omitted the department and post rows themselves.  This
-- left the department tree empty and made the user-management page appear to
-- contain incomplete data.  Restore a small, coherent organization baseline
-- without replacing records created by an upgraded installation.

INSERT INTO system_dept
    (id, name, parent_id, sort, leader_user_id, phone, email, status)
VALUES
    (100, 'Rust Toon', 0,   0, 1,    '15888888888', 'admin@rust-toon.local', 0),
    (101, '深圳总公司', 100, 1, 1,    NULL, NULL, 0),
    (102, '长沙分公司', 100, 2, NULL,                          NULL, NULL, 0),
    (103, '研发部门',   101, 1, 1,    NULL, NULL, 0),
    (104, '市场部门',   101, 2, NULL,                          NULL, NULL, 0),
    (105, '测试部门',   101, 3, NULL,                          NULL, NULL, 0),
    (106, '财务部门',   101, 4, NULL,                          NULL, NULL, 0),
    (107, '运维部门',   101, 5, NULL,                          NULL, NULL, 0),
    (108, '市场部门',   102, 1, NULL,                          NULL, NULL, 0),
    (109, '财务部门',   102, 2, NULL,                          NULL, NULL, 0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO system_post (id, code, name, sort, status, remark)
VALUES
    (1, 'chairman', '董事长',   1, 0, ''),
    (2, 'se',       '项目经理', 2, 0, ''),
    (3, 'hr',       '人力资源', 3, 0, ''),
    (4, 'user',     '普通员工', 4, 0, '')
ON CONFLICT (id) DO NOTHING;

INSERT INTO system_user_post (id, user_id, post_id, creator, updater, deleted, tenant_id)
SELECT nextval('system_user_post_seq'), 1, post.id, 'migration-0009', 'migration-0009', 0, 1
FROM (VALUES (1::bigint), (2::bigint)) AS post(id)
WHERE EXISTS (SELECT 1 FROM system_users WHERE id = 1 AND deleted = 0)
  AND EXISTS (SELECT 1 FROM system_post WHERE id = post.id AND deleted = 0)
  AND NOT EXISTS (
      SELECT 1 FROM system_user_post relation
      WHERE relation.user_id = 1 AND relation.post_id = post.id AND relation.deleted = 0
  );

SELECT setval('system_dept_seq', GREATEST((SELECT max(id) FROM system_dept), 1), true);
SELECT setval('system_post_seq', GREATEST((SELECT max(id) FROM system_post), 1), true);
