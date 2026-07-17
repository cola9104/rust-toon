UPDATE system_menu
SET name = 'PostgreSQL 监控',
    path = 'postgresql',
    icon = 'lucide:database',
    component_name = 'InfraPostgreSql',
    updater = 'system',
    update_time = now()
WHERE id = 111;

UPDATE system_menu
SET name = 'Rust 服务监控',
    path = 'rust',
    icon = 'lucide:server-cog',
    component_name = 'InfraRustServer',
    updater = 'system',
    update_time = now()
WHERE id = 112;

UPDATE system_menu
SET icon = 'lucide:database-zap', updater = 'system', update_time = now()
WHERE id = 113;

UPDATE system_menu
SET name = '请求链路',
    path = 'traces',
    icon = 'lucide:route',
    component_name = 'InfraRequestTraces',
    updater = 'system',
    update_time = now()
WHERE id = 1077;
