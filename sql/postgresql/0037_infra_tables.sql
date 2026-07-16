CREATE SEQUENCE IF NOT EXISTS infra_config_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS infra_config (
    id bigint PRIMARY KEY DEFAULT nextval('infra_config_seq'),
    category varchar(64) NOT NULL DEFAULT '',
    type smallint NOT NULL DEFAULT 2,
    name varchar(100) NOT NULL DEFAULT '',
    config_key varchar(100) NOT NULL DEFAULT '',
    value varchar(500) NOT NULL DEFAULT '',
    visible boolean NOT NULL DEFAULT true,
    remark varchar(500),
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS infra_data_source_config_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS infra_data_source_config (
    id bigint PRIMARY KEY DEFAULT nextval('infra_data_source_config_seq'),
    name varchar(100) NOT NULL DEFAULT '',
    url varchar(500) NOT NULL DEFAULT '',
    username varchar(100) NOT NULL DEFAULT '',
    password varchar(500) NOT NULL DEFAULT '',
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS infra_file_config_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS infra_file_config (
    id bigint PRIMARY KEY DEFAULT nextval('infra_file_config_seq'),
    name varchar(100) NOT NULL DEFAULT '',
    storage smallint NOT NULL DEFAULT 10,
    master boolean NOT NULL DEFAULT false,
    config text NOT NULL DEFAULT '{}',
    remark varchar(500),
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS infra_file_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS infra_file (
    id bigint PRIMARY KEY DEFAULT nextval('infra_file_seq'),
    config_id bigint,
    name varchar(255),
    path varchar(512) NOT NULL DEFAULT '',
    url varchar(1024) NOT NULL DEFAULT '',
    type varchar(128),
    size integer NOT NULL DEFAULT 0,
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS infra_job_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS infra_job (
    id bigint PRIMARY KEY DEFAULT nextval('infra_job_seq'),
    name varchar(100) NOT NULL DEFAULT '',
    status smallint NOT NULL DEFAULT 0,
    handler_name varchar(100) NOT NULL DEFAULT '',
    handler_param varchar(255),
    cron_expression varchar(100) NOT NULL DEFAULT '',
    retry_count integer NOT NULL DEFAULT 0,
    retry_interval integer NOT NULL DEFAULT 0,
    monitor_timeout integer NOT NULL DEFAULT 0,
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS infra_job_log_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS infra_job_log (
    id bigint PRIMARY KEY DEFAULT nextval('infra_job_log_seq'),
    job_id bigint NOT NULL DEFAULT 0,
    handler_name varchar(100) NOT NULL DEFAULT '',
    handler_param varchar(255),
    execute_index integer NOT NULL DEFAULT 1,
    begin_time timestamp without time zone,
    end_time timestamp without time zone,
    duration integer NOT NULL DEFAULT 0,
    status smallint NOT NULL DEFAULT 0,
    result text,
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS infra_api_access_log_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS infra_api_access_log (
    id bigint PRIMARY KEY DEFAULT nextval('infra_api_access_log_seq'),
    trace_id varchar(64),
    user_id bigint,
    user_type smallint,
    application_name varchar(100),
    request_method varchar(16),
    request_url varchar(1024),
    request_params text,
    response_body text,
    user_ip varchar(64),
    user_agent varchar(512),
    operate_module varchar(100),
    operate_name varchar(100),
    operate_type smallint,
    begin_time timestamp without time zone,
    end_time timestamp without time zone,
    duration integer NOT NULL DEFAULT 0,
    result_code integer,
    result_msg varchar(512),
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS infra_api_error_log_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS infra_api_error_log (
    id bigint PRIMARY KEY DEFAULT nextval('infra_api_error_log_seq'),
    trace_id varchar(64),
    user_id bigint,
    user_type smallint,
    application_name varchar(100),
    request_method varchar(16),
    request_url varchar(1024),
    request_params text,
    user_ip varchar(64),
    user_agent varchar(512),
    exception_time timestamp without time zone,
    exception_name varchar(255),
    exception_message text,
    exception_root_cause_message text,
    exception_stack_trace text,
    exception_class_name varchar(255),
    exception_file_name varchar(255),
    exception_method_name varchar(255),
    exception_line_number integer,
    process_status smallint NOT NULL DEFAULT 0,
    process_time timestamp without time zone,
    process_user_id bigint,
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS infra_codegen_table_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS infra_codegen_table (
    id bigint PRIMARY KEY DEFAULT nextval('infra_codegen_table_seq'),
    data_source_config_id bigint NOT NULL DEFAULT 0,
    scene smallint NOT NULL DEFAULT 1,
    table_name varchar(200) NOT NULL DEFAULT '',
    table_comment varchar(500) NOT NULL DEFAULT '',
    module_name varchar(100) NOT NULL DEFAULT '',
    business_name varchar(100) NOT NULL DEFAULT '',
    class_name varchar(100) NOT NULL DEFAULT '',
    class_comment varchar(500) NOT NULL DEFAULT '',
    author varchar(100) NOT NULL DEFAULT '',
    template_type smallint NOT NULL DEFAULT 1,
    front_type smallint NOT NULL DEFAULT 20,
    parent_menu_id bigint,
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS infra_codegen_column_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS infra_codegen_column (
    id bigint PRIMARY KEY DEFAULT nextval('infra_codegen_column_seq'),
    table_id bigint NOT NULL DEFAULT 0,
    column_name varchar(200) NOT NULL DEFAULT '',
    data_type varchar(100) NOT NULL DEFAULT '',
    column_comment varchar(500) NOT NULL DEFAULT '',
    nullable boolean NOT NULL DEFAULT true,
    primary_key boolean NOT NULL DEFAULT false,
    ordinal_position integer NOT NULL DEFAULT 0,
    java_type varchar(100) NOT NULL DEFAULT '',
    java_field varchar(100) NOT NULL DEFAULT '',
    create_operation boolean NOT NULL DEFAULT true,
    update_operation boolean NOT NULL DEFAULT true,
    list_operation boolean NOT NULL DEFAULT true,
    list_operation_result boolean NOT NULL DEFAULT true,
    html_type varchar(100) NOT NULL DEFAULT 'input',
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS yudao_demo01_contact_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS yudao_demo01_contact (
    id bigint PRIMARY KEY DEFAULT nextval('yudao_demo01_contact_seq'),
    name varchar(100),
    sex smallint,
    birthday date,
    description text,
    avatar varchar(1024),
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS yudao_demo02_category_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS yudao_demo02_category (
    id bigint PRIMARY KEY DEFAULT nextval('yudao_demo02_category_seq'),
    name varchar(100),
    parent_id bigint,
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS yudao_demo03_student_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS yudao_demo03_student (
    id bigint PRIMARY KEY DEFAULT nextval('yudao_demo03_student_seq'),
    name varchar(100),
    sex smallint,
    birthday date,
    description text,
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS yudao_demo03_course_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS yudao_demo03_course (
    id bigint PRIMARY KEY DEFAULT nextval('yudao_demo03_course_seq'),
    student_id bigint NOT NULL DEFAULT 0,
    name varchar(100),
    score integer,
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);

CREATE SEQUENCE IF NOT EXISTS yudao_demo03_grade_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS yudao_demo03_grade (
    id bigint PRIMARY KEY DEFAULT nextval('yudao_demo03_grade_seq'),
    student_id bigint NOT NULL DEFAULT 0,
    name varchar(100),
    teacher varchar(100),
    creator varchar(64) NOT NULL DEFAULT '',
    create_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updater varchar(64) NOT NULL DEFAULT '',
    update_time timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted smallint NOT NULL DEFAULT 0
);
