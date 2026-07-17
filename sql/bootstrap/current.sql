--
-- PostgreSQL database dump
--


-- Dumped from database version 18.4 (Debian 18.4-1.pgdg13+1)
-- Dumped by pg_dump version 18.4 (Debian 18.4-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: ai; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ai;


--
-- Name: infra; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA infra;


--
-- Name: media; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA media;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS '';


--
-- Name: toon; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA toon;


--
-- Name: toonflow; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA toonflow;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: chat_conversations; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.chat_conversations (
    id bigint NOT NULL,
    user_id text NOT NULL,
    title text NOT NULL,
    pinned boolean DEFAULT false NOT NULL,
    role_id bigint,
    model_id bigint NOT NULL,
    temperature double precision DEFAULT 0.7 NOT NULL,
    max_tokens integer DEFAULT 4096 NOT NULL,
    max_contexts integer DEFAULT 20 NOT NULL,
    system_message text,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL,
    tool_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    knowledge_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL
);


--
-- Name: chat_messages; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.chat_messages (
    id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    user_id text NOT NULL,
    type text NOT NULL,
    model_id bigint,
    content text DEFAULT ''::text NOT NULL,
    reasoning_content text,
    tokens integer DEFAULT 0 NOT NULL,
    segment_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    attachment_urls text[] DEFAULT '{}'::text[] NOT NULL,
    tool_calls jsonb DEFAULT '[]'::jsonb NOT NULL,
    create_time bigint NOT NULL,
    CONSTRAINT chat_messages_type_check CHECK ((type = ANY (ARRAY['system'::text, 'user'::text, 'assistant'::text, 'tool'::text])))
);


--
-- Name: chat_roles; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.chat_roles (
    id bigint NOT NULL,
    user_id text,
    model_id bigint NOT NULL,
    name text NOT NULL,
    avatar text DEFAULT ''::text NOT NULL,
    category text DEFAULT '通用'::text NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    system_message text DEFAULT ''::text NOT NULL,
    welcome_message text DEFAULT ''::text NOT NULL,
    public_status boolean DEFAULT false NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    knowledge_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    tool_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL
);


--
-- Name: images; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.images (
    id bigint NOT NULL,
    user_id text NOT NULL,
    model_id bigint NOT NULL,
    platform text NOT NULL,
    model text NOT NULL,
    prompt text NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    status integer DEFAULT 10 NOT NULL,
    public_status boolean DEFAULT false NOT NULL,
    pic_url text,
    error_message text,
    options jsonb DEFAULT '{}'::jsonb NOT NULL,
    task_id text,
    buttons jsonb DEFAULT '[]'::jsonb NOT NULL,
    create_time bigint NOT NULL,
    finish_time bigint,
    parent_id bigint,
    action_custom_id text,
    poll_count integer DEFAULT 0 NOT NULL,
    last_poll_time bigint
);


--
-- Name: knowledge_bases; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.knowledge_bases (
    id bigint NOT NULL,
    name text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    embedding_model_id bigint NOT NULL,
    top_k integer DEFAULT 5 NOT NULL,
    similarity_threshold double precision DEFAULT 0.5 NOT NULL,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL
);


--
-- Name: knowledge_documents; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.knowledge_documents (
    id bigint NOT NULL,
    knowledge_id bigint NOT NULL,
    name text NOT NULL,
    url text DEFAULT ''::text NOT NULL,
    content text DEFAULT ''::text NOT NULL,
    content_length integer DEFAULT 0 NOT NULL,
    tokens integer DEFAULT 0 NOT NULL,
    segment_max_tokens integer DEFAULT 500 NOT NULL,
    retrieval_count integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL
);


--
-- Name: knowledge_segments; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.knowledge_segments (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    knowledge_id bigint NOT NULL,
    vector_id text NOT NULL,
    content text NOT NULL,
    content_length integer NOT NULL,
    tokens integer NOT NULL,
    retrieval_count integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    embedding real[],
    create_time bigint NOT NULL,
    update_time bigint NOT NULL
);


--
-- Name: model_catalog; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.model_catalog (
    platform text NOT NULL,
    model text NOT NULL,
    type text NOT NULL,
    source text DEFAULT 'preset'::text NOT NULL,
    source_url text DEFAULT ''::text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    synced_at bigint NOT NULL,
    missing_count integer DEFAULT 0 NOT NULL,
    verified_at bigint
);


--
-- Name: COLUMN model_catalog.missing_count; Type: COMMENT; Schema: ai; Owner: -
--

COMMENT ON COLUMN ai.model_catalog.missing_count IS '连续未在供应商模型目录中出现的次数；仅作为验证依据，不自动删除';


--
-- Name: COLUMN model_catalog.verified_at; Type: COMMENT; Schema: ai; Owner: -
--

COMMENT ON COLUMN ai.model_catalog.verified_at IS '最后一次通过真实模型调用验证可用的时间';


--
-- Name: model_configs; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.model_configs (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    key character varying(255) NOT NULL,
    platform character varying(64) NOT NULL,
    type character varying(32) NOT NULL,
    model character varying(255) NOT NULL,
    api_key text DEFAULT ''::text NOT NULL,
    url text DEFAULT ''::text NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL
);


--
-- Name: model_platforms; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.model_platforms (
    platform text NOT NULL,
    label text NOT NULL,
    default_url text DEFAULT ''::text NOT NULL,
    supported_types text[] DEFAULT '{}'::text[] NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    update_time bigint NOT NULL
);


--
-- Name: music; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.music (
    id bigint NOT NULL,
    user_id text NOT NULL,
    model_id bigint NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    lyric text DEFAULT ''::text NOT NULL,
    image_url text,
    audio_url text,
    video_url text,
    status integer DEFAULT 10 NOT NULL,
    gpt_description_prompt text,
    prompt text DEFAULT ''::text NOT NULL,
    platform text NOT NULL,
    model text NOT NULL,
    generate_mode integer DEFAULT 1 NOT NULL,
    tags text DEFAULT ''::text NOT NULL,
    duration double precision DEFAULT 0 NOT NULL,
    public_status boolean DEFAULT false NOT NULL,
    task_id text,
    error_message text,
    create_time bigint NOT NULL,
    finish_time bigint,
    poll_count integer DEFAULT 0 NOT NULL,
    last_poll_time bigint
);


--
-- Name: tools; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.tools (
    id bigint NOT NULL,
    name text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    input_schema jsonb DEFAULT '{"type": "object", "properties": {}}'::jsonb NOT NULL,
    executor jsonb DEFAULT '{}'::jsonb NOT NULL,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL
);


--
-- Name: writes; Type: TABLE; Schema: ai; Owner: -
--

CREATE TABLE ai.writes (
    id bigint NOT NULL,
    user_id text NOT NULL,
    model_id bigint NOT NULL,
    type integer NOT NULL,
    prompt text NOT NULL,
    original_content text DEFAULT ''::text NOT NULL,
    length integer DEFAULT 0 NOT NULL,
    format integer DEFAULT 1 NOT NULL,
    tone integer DEFAULT 1 NOT NULL,
    language integer DEFAULT 1 NOT NULL,
    platform text NOT NULL,
    model text NOT NULL,
    generated_content text DEFAULT ''::text NOT NULL,
    error_message text,
    create_time bigint NOT NULL,
    finish_time bigint
);


--
-- Name: assets; Type: TABLE; Schema: media; Owner: -
--

CREATE TABLE media.assets (
    id uuid NOT NULL,
    object_key character varying(512) NOT NULL,
    content_type character varying(128) NOT NULL,
    size_bytes bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    filename character varying(255),
    status character varying(32) DEFAULT 'ready'::character varying NOT NULL,
    checksum character varying(128),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    owner_user_id uuid
);


--
-- Name: _sqlx_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public._sqlx_migrations (
    version bigint NOT NULL,
    description text NOT NULL,
    installed_on timestamp with time zone DEFAULT now() NOT NULL,
    success boolean NOT NULL,
    checksum bytea NOT NULL,
    execution_time bigint NOT NULL
);


--
-- Name: infra_api_access_log_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.infra_api_access_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: infra_api_access_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.infra_api_access_log (
    id bigint DEFAULT nextval('public.infra_api_access_log_seq'::regclass) NOT NULL,
    trace_id character varying(64),
    user_id bigint,
    user_type smallint,
    application_name character varying(100),
    request_method character varying(16),
    request_url character varying(1024),
    request_params text,
    response_body text,
    user_ip character varying(64),
    user_agent character varying(512),
    operate_module character varying(100),
    operate_name character varying(100),
    operate_type smallint,
    begin_time timestamp without time zone,
    end_time timestamp without time zone,
    duration integer DEFAULT 0 NOT NULL,
    result_code integer,
    result_msg character varying(512),
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: infra_api_error_log_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.infra_api_error_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: infra_api_error_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.infra_api_error_log (
    id bigint DEFAULT nextval('public.infra_api_error_log_seq'::regclass) NOT NULL,
    trace_id character varying(64),
    user_id bigint,
    user_type smallint,
    application_name character varying(100),
    request_method character varying(16),
    request_url character varying(1024),
    request_params text,
    user_ip character varying(64),
    user_agent character varying(512),
    exception_time timestamp without time zone,
    exception_name character varying(255),
    exception_message text,
    exception_root_cause_message text,
    exception_stack_trace text,
    exception_class_name character varying(255),
    exception_file_name character varying(255),
    exception_method_name character varying(255),
    exception_line_number integer,
    process_status smallint DEFAULT 0 NOT NULL,
    process_time timestamp without time zone,
    process_user_id bigint,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: infra_codegen_column_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.infra_codegen_column_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: infra_codegen_column; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.infra_codegen_column (
    id bigint DEFAULT nextval('public.infra_codegen_column_seq'::regclass) NOT NULL,
    table_id bigint DEFAULT 0 NOT NULL,
    column_name character varying(200) DEFAULT ''::character varying NOT NULL,
    data_type character varying(100) DEFAULT ''::character varying NOT NULL,
    column_comment character varying(500) DEFAULT ''::character varying NOT NULL,
    nullable boolean DEFAULT true NOT NULL,
    primary_key boolean DEFAULT false NOT NULL,
    ordinal_position integer DEFAULT 0 NOT NULL,
    java_type character varying(100) DEFAULT ''::character varying NOT NULL,
    java_field character varying(100) DEFAULT ''::character varying NOT NULL,
    create_operation boolean DEFAULT true NOT NULL,
    update_operation boolean DEFAULT true NOT NULL,
    list_operation boolean DEFAULT true NOT NULL,
    list_operation_result boolean DEFAULT true NOT NULL,
    html_type character varying(100) DEFAULT 'input'::character varying NOT NULL,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: infra_codegen_table_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.infra_codegen_table_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: infra_codegen_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.infra_codegen_table (
    id bigint DEFAULT nextval('public.infra_codegen_table_seq'::regclass) NOT NULL,
    data_source_config_id bigint DEFAULT 0 NOT NULL,
    scene smallint DEFAULT 1 NOT NULL,
    table_name character varying(200) DEFAULT ''::character varying NOT NULL,
    table_comment character varying(500) DEFAULT ''::character varying NOT NULL,
    module_name character varying(100) DEFAULT ''::character varying NOT NULL,
    business_name character varying(100) DEFAULT ''::character varying NOT NULL,
    class_name character varying(100) DEFAULT ''::character varying NOT NULL,
    class_comment character varying(500) DEFAULT ''::character varying NOT NULL,
    author character varying(100) DEFAULT ''::character varying NOT NULL,
    template_type smallint DEFAULT 1 NOT NULL,
    front_type smallint DEFAULT 20 NOT NULL,
    parent_menu_id bigint,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: infra_config_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.infra_config_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: infra_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.infra_config (
    id bigint DEFAULT nextval('public.infra_config_seq'::regclass) NOT NULL,
    category character varying(64) DEFAULT ''::character varying NOT NULL,
    type smallint DEFAULT 2 NOT NULL,
    name character varying(100) DEFAULT ''::character varying NOT NULL,
    config_key character varying(100) DEFAULT ''::character varying NOT NULL,
    value character varying(500) DEFAULT ''::character varying NOT NULL,
    visible boolean DEFAULT true NOT NULL,
    remark character varying(500),
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: infra_data_source_config_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.infra_data_source_config_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: infra_data_source_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.infra_data_source_config (
    id bigint DEFAULT nextval('public.infra_data_source_config_seq'::regclass) NOT NULL,
    name character varying(100) DEFAULT ''::character varying NOT NULL,
    url character varying(500) DEFAULT ''::character varying NOT NULL,
    username character varying(100) DEFAULT ''::character varying NOT NULL,
    password character varying(500) DEFAULT ''::character varying NOT NULL,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: infra_file_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.infra_file_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: infra_file; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.infra_file (
    id bigint DEFAULT nextval('public.infra_file_seq'::regclass) NOT NULL,
    config_id bigint,
    name character varying(255),
    path character varying(512) DEFAULT ''::character varying NOT NULL,
    url character varying(1024) DEFAULT ''::character varying NOT NULL,
    type character varying(128),
    size integer DEFAULT 0 NOT NULL,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: infra_file_config_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.infra_file_config_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: infra_file_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.infra_file_config (
    id bigint DEFAULT nextval('public.infra_file_config_seq'::regclass) NOT NULL,
    name character varying(100) DEFAULT ''::character varying NOT NULL,
    storage smallint DEFAULT 10 NOT NULL,
    master boolean DEFAULT false NOT NULL,
    config text DEFAULT '{}'::text NOT NULL,
    remark character varying(500),
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: infra_job_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.infra_job_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: infra_job; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.infra_job (
    id bigint DEFAULT nextval('public.infra_job_seq'::regclass) NOT NULL,
    name character varying(100) DEFAULT ''::character varying NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    handler_name character varying(100) DEFAULT ''::character varying NOT NULL,
    handler_param character varying(255),
    cron_expression character varying(100) DEFAULT ''::character varying NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    retry_interval integer DEFAULT 0 NOT NULL,
    monitor_timeout integer DEFAULT 0 NOT NULL,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: infra_job_log_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.infra_job_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: infra_job_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.infra_job_log (
    id bigint DEFAULT nextval('public.infra_job_log_seq'::regclass) NOT NULL,
    job_id bigint DEFAULT 0 NOT NULL,
    handler_name character varying(100) DEFAULT ''::character varying NOT NULL,
    handler_param character varying(255),
    execute_index integer DEFAULT 1 NOT NULL,
    begin_time timestamp without time zone,
    end_time timestamp without time zone,
    duration integer DEFAULT 0 NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    result text,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: system_dept; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_dept (
    id bigint NOT NULL,
    name character varying(30) DEFAULT ''::character varying NOT NULL,
    parent_id bigint DEFAULT 0 NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    leader_user_id bigint,
    phone character varying(11) DEFAULT NULL::character varying,
    email character varying(50) DEFAULT NULL::character varying,
    status smallint NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_dept; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_dept IS '部门表';


--
-- Name: COLUMN system_dept.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.id IS '部门id';


--
-- Name: COLUMN system_dept.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.name IS '部门名称';


--
-- Name: COLUMN system_dept.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.parent_id IS '父部门id';


--
-- Name: COLUMN system_dept.sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.sort IS '显示顺序';


--
-- Name: COLUMN system_dept.leader_user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.leader_user_id IS '负责人';


--
-- Name: COLUMN system_dept.phone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.phone IS '联系电话';


--
-- Name: COLUMN system_dept.email; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.email IS '邮箱';


--
-- Name: COLUMN system_dept.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.status IS '部门状态（0正常 1停用）';


--
-- Name: COLUMN system_dept.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.creator IS '创建者';


--
-- Name: COLUMN system_dept.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.create_time IS '创建时间';


--
-- Name: COLUMN system_dept.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.updater IS '更新者';


--
-- Name: COLUMN system_dept.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.update_time IS '更新时间';


--
-- Name: COLUMN system_dept.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.deleted IS '是否删除';


--
-- Name: COLUMN system_dept.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dept.tenant_id IS '租户编号';


--
-- Name: system_dept_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_dept_seq
    START WITH 118
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_dict_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_dict_data (
    id bigint NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    label character varying(100) DEFAULT ''::character varying NOT NULL,
    value character varying(100) DEFAULT ''::character varying NOT NULL,
    dict_type character varying(100) DEFAULT ''::character varying NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    color_type character varying(100) DEFAULT ''::character varying,
    css_class character varying(100) DEFAULT ''::character varying,
    remark character varying(500) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_dict_data; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_dict_data IS '字典数据表';


--
-- Name: COLUMN system_dict_data.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.id IS '字典编码';


--
-- Name: COLUMN system_dict_data.sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.sort IS '字典排序';


--
-- Name: COLUMN system_dict_data.label; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.label IS '字典标签';


--
-- Name: COLUMN system_dict_data.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.value IS '字典键值';


--
-- Name: COLUMN system_dict_data.dict_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.dict_type IS '字典类型';


--
-- Name: COLUMN system_dict_data.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.status IS '状态（0正常 1停用）';


--
-- Name: COLUMN system_dict_data.color_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.color_type IS '颜色类型';


--
-- Name: COLUMN system_dict_data.css_class; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.css_class IS 'css 样式';


--
-- Name: COLUMN system_dict_data.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.remark IS '备注';


--
-- Name: COLUMN system_dict_data.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.creator IS '创建者';


--
-- Name: COLUMN system_dict_data.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.create_time IS '创建时间';


--
-- Name: COLUMN system_dict_data.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.updater IS '更新者';


--
-- Name: COLUMN system_dict_data.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.update_time IS '更新时间';


--
-- Name: COLUMN system_dict_data.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_data.deleted IS '是否删除';


--
-- Name: system_dict_data_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_dict_data_seq
    START WITH 3449
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_dict_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_dict_type (
    id bigint NOT NULL,
    name character varying(100) DEFAULT ''::character varying NOT NULL,
    type character varying(100) DEFAULT ''::character varying NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    remark character varying(500) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    deleted_time timestamp without time zone
);


--
-- Name: TABLE system_dict_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_dict_type IS '字典类型表';


--
-- Name: COLUMN system_dict_type.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.id IS '字典主键';


--
-- Name: COLUMN system_dict_type.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.name IS '字典名称';


--
-- Name: COLUMN system_dict_type.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.type IS '字典类型';


--
-- Name: COLUMN system_dict_type.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.status IS '状态（0正常 1停用）';


--
-- Name: COLUMN system_dict_type.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.remark IS '备注';


--
-- Name: COLUMN system_dict_type.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.creator IS '创建者';


--
-- Name: COLUMN system_dict_type.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.create_time IS '创建时间';


--
-- Name: COLUMN system_dict_type.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.updater IS '更新者';


--
-- Name: COLUMN system_dict_type.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.update_time IS '更新时间';


--
-- Name: COLUMN system_dict_type.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.deleted IS '是否删除';


--
-- Name: COLUMN system_dict_type.deleted_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_dict_type.deleted_time IS '删除时间';


--
-- Name: system_dict_type_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_dict_type_seq
    START WITH 2139
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_login_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_login_log (
    id bigint NOT NULL,
    log_type bigint NOT NULL,
    trace_id character varying(64) DEFAULT ''::character varying NOT NULL,
    user_id bigint DEFAULT 0 NOT NULL,
    user_type smallint DEFAULT 0 NOT NULL,
    username character varying(50) DEFAULT ''::character varying NOT NULL,
    result smallint NOT NULL,
    user_ip character varying(50) NOT NULL,
    user_agent character varying(512) NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_login_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_login_log IS '系统访问记录';


--
-- Name: COLUMN system_login_log.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.id IS '访问ID';


--
-- Name: COLUMN system_login_log.log_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.log_type IS '日志类型';


--
-- Name: COLUMN system_login_log.trace_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.trace_id IS '链路追踪编号';


--
-- Name: COLUMN system_login_log.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.user_id IS '用户编号';


--
-- Name: COLUMN system_login_log.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.user_type IS '用户类型';


--
-- Name: COLUMN system_login_log.username; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.username IS '用户账号';


--
-- Name: COLUMN system_login_log.result; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.result IS '登陆结果';


--
-- Name: COLUMN system_login_log.user_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.user_ip IS '用户 IP';


--
-- Name: COLUMN system_login_log.user_agent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.user_agent IS '浏览器 UA';


--
-- Name: COLUMN system_login_log.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.creator IS '创建者';


--
-- Name: COLUMN system_login_log.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.create_time IS '创建时间';


--
-- Name: COLUMN system_login_log.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.updater IS '更新者';


--
-- Name: COLUMN system_login_log.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.update_time IS '更新时间';


--
-- Name: COLUMN system_login_log.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.deleted IS '是否删除';


--
-- Name: COLUMN system_login_log.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_login_log.tenant_id IS '租户编号';


--
-- Name: system_login_log_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_login_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_mail_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_mail_account (
    id bigint NOT NULL,
    mail character varying(255) NOT NULL,
    username character varying(255) NOT NULL,
    password character varying(255) NOT NULL,
    host character varying(255) NOT NULL,
    port integer NOT NULL,
    ssl_enable boolean DEFAULT false NOT NULL,
    starttls_enable boolean DEFAULT false NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_mail_account; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_mail_account IS '邮箱账号表';


--
-- Name: COLUMN system_mail_account.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.id IS '主键';


--
-- Name: COLUMN system_mail_account.mail; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.mail IS '邮箱';


--
-- Name: COLUMN system_mail_account.username; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.username IS '用户名';


--
-- Name: COLUMN system_mail_account.password; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.password IS '密码';


--
-- Name: COLUMN system_mail_account.host; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.host IS 'SMTP 服务器域名';


--
-- Name: COLUMN system_mail_account.port; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.port IS 'SMTP 服务器端口';


--
-- Name: COLUMN system_mail_account.ssl_enable; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.ssl_enable IS '是否开启 SSL';


--
-- Name: COLUMN system_mail_account.starttls_enable; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.starttls_enable IS '是否开启 STARTTLS';


--
-- Name: COLUMN system_mail_account.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.creator IS '创建者';


--
-- Name: COLUMN system_mail_account.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.create_time IS '创建时间';


--
-- Name: COLUMN system_mail_account.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.updater IS '更新者';


--
-- Name: COLUMN system_mail_account.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.update_time IS '更新时间';


--
-- Name: COLUMN system_mail_account.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_account.deleted IS '是否删除';


--
-- Name: system_mail_account_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_mail_account_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_mail_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_mail_log (
    id bigint NOT NULL,
    user_id bigint,
    user_type smallint,
    to_mails character varying(1024) NOT NULL,
    cc_mails character varying(1024) DEFAULT NULL::character varying,
    bcc_mails character varying(1024) DEFAULT NULL::character varying,
    account_id bigint NOT NULL,
    from_mail character varying(255) NOT NULL,
    template_id bigint NOT NULL,
    template_code character varying(63) NOT NULL,
    template_nickname character varying(255) DEFAULT NULL::character varying,
    template_title character varying(255) NOT NULL,
    template_content text NOT NULL,
    template_params character varying(255) NOT NULL,
    send_status smallint DEFAULT 0 NOT NULL,
    send_time timestamp without time zone,
    send_message_id character varying(255) DEFAULT NULL::character varying,
    send_exception character varying(4096) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_mail_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_mail_log IS '邮件日志表';


--
-- Name: COLUMN system_mail_log.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.id IS '编号';


--
-- Name: COLUMN system_mail_log.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.user_id IS '用户编号';


--
-- Name: COLUMN system_mail_log.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.user_type IS '用户类型';


--
-- Name: COLUMN system_mail_log.to_mails; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.to_mails IS '接收邮箱地址';


--
-- Name: COLUMN system_mail_log.cc_mails; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.cc_mails IS '抄送邮箱地址';


--
-- Name: COLUMN system_mail_log.bcc_mails; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.bcc_mails IS '密送邮箱地址';


--
-- Name: COLUMN system_mail_log.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.account_id IS '邮箱账号编号';


--
-- Name: COLUMN system_mail_log.from_mail; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.from_mail IS '发送邮箱地址';


--
-- Name: COLUMN system_mail_log.template_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.template_id IS '模板编号';


--
-- Name: COLUMN system_mail_log.template_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.template_code IS '模板编码';


--
-- Name: COLUMN system_mail_log.template_nickname; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.template_nickname IS '模版发送人名称';


--
-- Name: COLUMN system_mail_log.template_title; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.template_title IS '邮件标题';


--
-- Name: COLUMN system_mail_log.template_content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.template_content IS '邮件内容';


--
-- Name: COLUMN system_mail_log.template_params; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.template_params IS '邮件参数';


--
-- Name: COLUMN system_mail_log.send_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.send_status IS '发送状态';


--
-- Name: COLUMN system_mail_log.send_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.send_time IS '发送时间';


--
-- Name: COLUMN system_mail_log.send_message_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.send_message_id IS '发送返回的消息 ID';


--
-- Name: COLUMN system_mail_log.send_exception; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.send_exception IS '发送异常';


--
-- Name: COLUMN system_mail_log.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.creator IS '创建者';


--
-- Name: COLUMN system_mail_log.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.create_time IS '创建时间';


--
-- Name: COLUMN system_mail_log.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.updater IS '更新者';


--
-- Name: COLUMN system_mail_log.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.update_time IS '更新时间';


--
-- Name: COLUMN system_mail_log.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_log.deleted IS '是否删除';


--
-- Name: system_mail_log_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_mail_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_mail_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_mail_template (
    id bigint NOT NULL,
    name character varying(63) NOT NULL,
    code character varying(63) NOT NULL,
    account_id bigint NOT NULL,
    nickname character varying(255) DEFAULT NULL::character varying,
    title character varying(255) NOT NULL,
    content character varying(10240) NOT NULL,
    params character varying(255) NOT NULL,
    status smallint NOT NULL,
    remark character varying(255) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_mail_template; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_mail_template IS '邮件模版表';


--
-- Name: COLUMN system_mail_template.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.id IS '编号';


--
-- Name: COLUMN system_mail_template.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.name IS '模板名称';


--
-- Name: COLUMN system_mail_template.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.code IS '模板编码';


--
-- Name: COLUMN system_mail_template.account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.account_id IS '发送的邮箱账号编号';


--
-- Name: COLUMN system_mail_template.nickname; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.nickname IS '发送人名称';


--
-- Name: COLUMN system_mail_template.title; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.title IS '模板标题';


--
-- Name: COLUMN system_mail_template.content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.content IS '模板内容';


--
-- Name: COLUMN system_mail_template.params; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.params IS '参数数组';


--
-- Name: COLUMN system_mail_template.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.status IS '开启状态';


--
-- Name: COLUMN system_mail_template.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.remark IS '备注';


--
-- Name: COLUMN system_mail_template.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.creator IS '创建者';


--
-- Name: COLUMN system_mail_template.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.create_time IS '创建时间';


--
-- Name: COLUMN system_mail_template.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.updater IS '更新者';


--
-- Name: COLUMN system_mail_template.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.update_time IS '更新时间';


--
-- Name: COLUMN system_mail_template.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_mail_template.deleted IS '是否删除';


--
-- Name: system_mail_template_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_mail_template_seq
    START WITH 16
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_menu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_menu (
    id bigint NOT NULL,
    name character varying(50) NOT NULL,
    permission character varying(100) DEFAULT ''::character varying NOT NULL,
    type smallint NOT NULL,
    sort integer DEFAULT 0 NOT NULL,
    parent_id bigint DEFAULT 0 NOT NULL,
    path character varying(200) DEFAULT ''::character varying,
    icon character varying(100) DEFAULT '#'::character varying,
    component character varying(255) DEFAULT NULL::character varying,
    component_name character varying(255) DEFAULT NULL::character varying,
    status smallint DEFAULT 0 NOT NULL,
    visible boolean DEFAULT true NOT NULL,
    keep_alive boolean DEFAULT true NOT NULL,
    always_show boolean DEFAULT true NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_menu; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_menu IS '菜单权限表';


--
-- Name: COLUMN system_menu.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.id IS '菜单ID';


--
-- Name: COLUMN system_menu.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.name IS '菜单名称';


--
-- Name: COLUMN system_menu.permission; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.permission IS '权限标识';


--
-- Name: COLUMN system_menu.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.type IS '菜单类型';


--
-- Name: COLUMN system_menu.sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.sort IS '显示顺序';


--
-- Name: COLUMN system_menu.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.parent_id IS '父菜单ID';


--
-- Name: COLUMN system_menu.path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.path IS '路由地址';


--
-- Name: COLUMN system_menu.icon; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.icon IS '菜单图标';


--
-- Name: COLUMN system_menu.component; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.component IS '组件路径';


--
-- Name: COLUMN system_menu.component_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.component_name IS '组件名';


--
-- Name: COLUMN system_menu.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.status IS '菜单状态';


--
-- Name: COLUMN system_menu.visible; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.visible IS '是否可见';


--
-- Name: COLUMN system_menu.keep_alive; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.keep_alive IS '是否缓存';


--
-- Name: COLUMN system_menu.always_show; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.always_show IS '是否总是显示';


--
-- Name: COLUMN system_menu.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.creator IS '创建者';


--
-- Name: COLUMN system_menu.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.create_time IS '创建时间';


--
-- Name: COLUMN system_menu.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.updater IS '更新者';


--
-- Name: COLUMN system_menu.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.update_time IS '更新时间';


--
-- Name: COLUMN system_menu.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_menu.deleted IS '是否删除';


--
-- Name: system_menu_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_menu_seq
    START WITH 5986
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_notice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_notice (
    id bigint NOT NULL,
    title character varying(50) NOT NULL,
    content text NOT NULL,
    type smallint NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_notice; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_notice IS '通知公告表';


--
-- Name: COLUMN system_notice.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.id IS '公告ID';


--
-- Name: COLUMN system_notice.title; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.title IS '公告标题';


--
-- Name: COLUMN system_notice.content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.content IS '公告内容';


--
-- Name: COLUMN system_notice.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.type IS '公告类型（1通知 2公告）';


--
-- Name: COLUMN system_notice.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.status IS '公告状态（0正常 1关闭）';


--
-- Name: COLUMN system_notice.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.creator IS '创建者';


--
-- Name: COLUMN system_notice.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.create_time IS '创建时间';


--
-- Name: COLUMN system_notice.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.updater IS '更新者';


--
-- Name: COLUMN system_notice.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.update_time IS '更新时间';


--
-- Name: COLUMN system_notice.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.deleted IS '是否删除';


--
-- Name: COLUMN system_notice.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notice.tenant_id IS '租户编号';


--
-- Name: system_notice_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_notice_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_notify_message; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_notify_message (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    user_type smallint NOT NULL,
    template_id bigint NOT NULL,
    template_code character varying(64) NOT NULL,
    template_nickname character varying(63) NOT NULL,
    template_content character varying(1024) NOT NULL,
    template_type integer NOT NULL,
    template_params character varying(255) NOT NULL,
    read_status boolean NOT NULL,
    read_time timestamp without time zone,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_notify_message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_notify_message IS '站内信消息表';


--
-- Name: COLUMN system_notify_message.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.id IS '用户ID';


--
-- Name: COLUMN system_notify_message.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.user_id IS '用户id';


--
-- Name: COLUMN system_notify_message.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.user_type IS '用户类型';


--
-- Name: COLUMN system_notify_message.template_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.template_id IS '模版编号';


--
-- Name: COLUMN system_notify_message.template_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.template_code IS '模板编码';


--
-- Name: COLUMN system_notify_message.template_nickname; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.template_nickname IS '模版发送人名称';


--
-- Name: COLUMN system_notify_message.template_content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.template_content IS '模版内容';


--
-- Name: COLUMN system_notify_message.template_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.template_type IS '模版类型';


--
-- Name: COLUMN system_notify_message.template_params; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.template_params IS '模版参数';


--
-- Name: COLUMN system_notify_message.read_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.read_status IS '是否已读';


--
-- Name: COLUMN system_notify_message.read_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.read_time IS '阅读时间';


--
-- Name: COLUMN system_notify_message.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.creator IS '创建者';


--
-- Name: COLUMN system_notify_message.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.create_time IS '创建时间';


--
-- Name: COLUMN system_notify_message.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.updater IS '更新者';


--
-- Name: COLUMN system_notify_message.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.update_time IS '更新时间';


--
-- Name: COLUMN system_notify_message.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.deleted IS '是否删除';


--
-- Name: COLUMN system_notify_message.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_message.tenant_id IS '租户编号';


--
-- Name: system_notify_message_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_notify_message_seq
    START WITH 11
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_notify_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_notify_template (
    id bigint NOT NULL,
    name character varying(63) NOT NULL,
    code character varying(64) NOT NULL,
    nickname character varying(255) NOT NULL,
    content character varying(1024) NOT NULL,
    type smallint NOT NULL,
    params character varying(255) DEFAULT NULL::character varying,
    status smallint NOT NULL,
    remark character varying(255) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_notify_template; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_notify_template IS '站内信模板表';


--
-- Name: COLUMN system_notify_template.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.id IS '主键';


--
-- Name: COLUMN system_notify_template.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.name IS '模板名称';


--
-- Name: COLUMN system_notify_template.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.code IS '模版编码';


--
-- Name: COLUMN system_notify_template.nickname; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.nickname IS '发送人名称';


--
-- Name: COLUMN system_notify_template.content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.content IS '模版内容';


--
-- Name: COLUMN system_notify_template.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.type IS '类型';


--
-- Name: COLUMN system_notify_template.params; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.params IS '参数数组';


--
-- Name: COLUMN system_notify_template.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.status IS '状态';


--
-- Name: COLUMN system_notify_template.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.remark IS '备注';


--
-- Name: COLUMN system_notify_template.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.creator IS '创建者';


--
-- Name: COLUMN system_notify_template.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.create_time IS '创建时间';


--
-- Name: COLUMN system_notify_template.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.updater IS '更新者';


--
-- Name: COLUMN system_notify_template.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.update_time IS '更新时间';


--
-- Name: COLUMN system_notify_template.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_notify_template.deleted IS '是否删除';


--
-- Name: system_notify_template_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_notify_template_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_oauth2_access_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_oauth2_access_token (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    user_type smallint NOT NULL,
    user_info character varying(512) NOT NULL,
    access_token text NOT NULL,
    refresh_token character varying(32) NOT NULL,
    client_id character varying(255) NOT NULL,
    scopes character varying(255) DEFAULT NULL::character varying,
    expires_time timestamp without time zone NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_oauth2_access_token; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_oauth2_access_token IS 'OAuth2 访问令牌';


--
-- Name: COLUMN system_oauth2_access_token.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.id IS '编号';


--
-- Name: COLUMN system_oauth2_access_token.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.user_id IS '用户编号';


--
-- Name: COLUMN system_oauth2_access_token.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.user_type IS '用户类型';


--
-- Name: COLUMN system_oauth2_access_token.user_info; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.user_info IS '用户信息';


--
-- Name: COLUMN system_oauth2_access_token.access_token; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.access_token IS '访问令牌';


--
-- Name: COLUMN system_oauth2_access_token.refresh_token; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.refresh_token IS '刷新令牌';


--
-- Name: COLUMN system_oauth2_access_token.client_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.client_id IS '客户端编号';


--
-- Name: COLUMN system_oauth2_access_token.scopes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.scopes IS '授权范围';


--
-- Name: COLUMN system_oauth2_access_token.expires_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.expires_time IS '过期时间';


--
-- Name: COLUMN system_oauth2_access_token.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.creator IS '创建者';


--
-- Name: COLUMN system_oauth2_access_token.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.create_time IS '创建时间';


--
-- Name: COLUMN system_oauth2_access_token.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.updater IS '更新者';


--
-- Name: COLUMN system_oauth2_access_token.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.update_time IS '更新时间';


--
-- Name: COLUMN system_oauth2_access_token.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.deleted IS '是否删除';


--
-- Name: COLUMN system_oauth2_access_token.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_access_token.tenant_id IS '租户编号';


--
-- Name: system_oauth2_access_token_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_oauth2_access_token_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_oauth2_approve; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_oauth2_approve (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    user_type smallint NOT NULL,
    client_id character varying(255) NOT NULL,
    scope character varying(255) DEFAULT ''::character varying NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    expires_time timestamp without time zone NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_oauth2_approve; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_oauth2_approve IS 'OAuth2 批准表';


--
-- Name: COLUMN system_oauth2_approve.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.id IS '编号';


--
-- Name: COLUMN system_oauth2_approve.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.user_id IS '用户编号';


--
-- Name: COLUMN system_oauth2_approve.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.user_type IS '用户类型';


--
-- Name: COLUMN system_oauth2_approve.client_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.client_id IS '客户端编号';


--
-- Name: COLUMN system_oauth2_approve.scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.scope IS '授权范围';


--
-- Name: COLUMN system_oauth2_approve.approved; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.approved IS '是否接受';


--
-- Name: COLUMN system_oauth2_approve.expires_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.expires_time IS '过期时间';


--
-- Name: COLUMN system_oauth2_approve.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.creator IS '创建者';


--
-- Name: COLUMN system_oauth2_approve.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.create_time IS '创建时间';


--
-- Name: COLUMN system_oauth2_approve.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.updater IS '更新者';


--
-- Name: COLUMN system_oauth2_approve.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.update_time IS '更新时间';


--
-- Name: COLUMN system_oauth2_approve.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.deleted IS '是否删除';


--
-- Name: COLUMN system_oauth2_approve.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_approve.tenant_id IS '租户编号';


--
-- Name: system_oauth2_approve_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_oauth2_approve_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_oauth2_client; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_oauth2_client (
    id bigint NOT NULL,
    client_id character varying(255) NOT NULL,
    secret character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    logo character varying(255) NOT NULL,
    description character varying(255) DEFAULT NULL::character varying,
    status smallint NOT NULL,
    access_token_validity_seconds integer NOT NULL,
    refresh_token_validity_seconds integer NOT NULL,
    redirect_uris character varying(255) NOT NULL,
    authorized_grant_types character varying(255) NOT NULL,
    scopes character varying(255) DEFAULT NULL::character varying,
    auto_approve_scopes character varying(255) DEFAULT NULL::character varying,
    authorities character varying(255) DEFAULT NULL::character varying,
    resource_ids character varying(255) DEFAULT NULL::character varying,
    additional_information character varying(4096) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_oauth2_client; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_oauth2_client IS 'OAuth2 客户端表';


--
-- Name: COLUMN system_oauth2_client.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.id IS '编号';


--
-- Name: COLUMN system_oauth2_client.client_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.client_id IS '客户端编号';


--
-- Name: COLUMN system_oauth2_client.secret; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.secret IS '客户端密钥';


--
-- Name: COLUMN system_oauth2_client.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.name IS '应用名';


--
-- Name: COLUMN system_oauth2_client.logo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.logo IS '应用图标';


--
-- Name: COLUMN system_oauth2_client.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.description IS '应用描述';


--
-- Name: COLUMN system_oauth2_client.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.status IS '状态';


--
-- Name: COLUMN system_oauth2_client.access_token_validity_seconds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.access_token_validity_seconds IS '访问令牌的有效期';


--
-- Name: COLUMN system_oauth2_client.refresh_token_validity_seconds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.refresh_token_validity_seconds IS '刷新令牌的有效期';


--
-- Name: COLUMN system_oauth2_client.redirect_uris; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.redirect_uris IS '可重定向的 URI 地址';


--
-- Name: COLUMN system_oauth2_client.authorized_grant_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.authorized_grant_types IS '授权类型';


--
-- Name: COLUMN system_oauth2_client.scopes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.scopes IS '授权范围';


--
-- Name: COLUMN system_oauth2_client.auto_approve_scopes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.auto_approve_scopes IS '自动通过的授权范围';


--
-- Name: COLUMN system_oauth2_client.authorities; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.authorities IS '权限';


--
-- Name: COLUMN system_oauth2_client.resource_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.resource_ids IS '资源';


--
-- Name: COLUMN system_oauth2_client.additional_information; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.additional_information IS '附加信息';


--
-- Name: COLUMN system_oauth2_client.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.creator IS '创建者';


--
-- Name: COLUMN system_oauth2_client.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.create_time IS '创建时间';


--
-- Name: COLUMN system_oauth2_client.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.updater IS '更新者';


--
-- Name: COLUMN system_oauth2_client.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.update_time IS '更新时间';


--
-- Name: COLUMN system_oauth2_client.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_client.deleted IS '是否删除';


--
-- Name: system_oauth2_client_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_oauth2_client_seq
    START WITH 43
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_oauth2_code; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_oauth2_code (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    user_type smallint NOT NULL,
    code character varying(32) NOT NULL,
    client_id character varying(255) NOT NULL,
    scopes character varying(255) DEFAULT ''::character varying,
    expires_time timestamp without time zone NOT NULL,
    redirect_uri character varying(255) DEFAULT NULL::character varying,
    state character varying(255) DEFAULT ''::character varying NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_oauth2_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_oauth2_code IS 'OAuth2 授权码表';


--
-- Name: COLUMN system_oauth2_code.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.id IS '编号';


--
-- Name: COLUMN system_oauth2_code.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.user_id IS '用户编号';


--
-- Name: COLUMN system_oauth2_code.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.user_type IS '用户类型';


--
-- Name: COLUMN system_oauth2_code.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.code IS '授权码';


--
-- Name: COLUMN system_oauth2_code.client_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.client_id IS '客户端编号';


--
-- Name: COLUMN system_oauth2_code.scopes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.scopes IS '授权范围';


--
-- Name: COLUMN system_oauth2_code.expires_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.expires_time IS '过期时间';


--
-- Name: COLUMN system_oauth2_code.redirect_uri; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.redirect_uri IS '可重定向的 URI 地址';


--
-- Name: COLUMN system_oauth2_code.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.state IS '状态';


--
-- Name: COLUMN system_oauth2_code.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.creator IS '创建者';


--
-- Name: COLUMN system_oauth2_code.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.create_time IS '创建时间';


--
-- Name: COLUMN system_oauth2_code.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.updater IS '更新者';


--
-- Name: COLUMN system_oauth2_code.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.update_time IS '更新时间';


--
-- Name: COLUMN system_oauth2_code.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.deleted IS '是否删除';


--
-- Name: COLUMN system_oauth2_code.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_code.tenant_id IS '租户编号';


--
-- Name: system_oauth2_code_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_oauth2_code_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_oauth2_refresh_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_oauth2_refresh_token (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    refresh_token character varying(32) NOT NULL,
    user_type smallint NOT NULL,
    client_id character varying(255) NOT NULL,
    scopes character varying(255) DEFAULT NULL::character varying,
    expires_time timestamp without time zone NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_oauth2_refresh_token; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_oauth2_refresh_token IS 'OAuth2 刷新令牌';


--
-- Name: COLUMN system_oauth2_refresh_token.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.id IS '编号';


--
-- Name: COLUMN system_oauth2_refresh_token.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.user_id IS '用户编号';


--
-- Name: COLUMN system_oauth2_refresh_token.refresh_token; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.refresh_token IS '刷新令牌';


--
-- Name: COLUMN system_oauth2_refresh_token.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.user_type IS '用户类型';


--
-- Name: COLUMN system_oauth2_refresh_token.client_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.client_id IS '客户端编号';


--
-- Name: COLUMN system_oauth2_refresh_token.scopes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.scopes IS '授权范围';


--
-- Name: COLUMN system_oauth2_refresh_token.expires_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.expires_time IS '过期时间';


--
-- Name: COLUMN system_oauth2_refresh_token.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.creator IS '创建者';


--
-- Name: COLUMN system_oauth2_refresh_token.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.create_time IS '创建时间';


--
-- Name: COLUMN system_oauth2_refresh_token.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.updater IS '更新者';


--
-- Name: COLUMN system_oauth2_refresh_token.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.update_time IS '更新时间';


--
-- Name: COLUMN system_oauth2_refresh_token.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.deleted IS '是否删除';


--
-- Name: COLUMN system_oauth2_refresh_token.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_oauth2_refresh_token.tenant_id IS '租户编号';


--
-- Name: system_oauth2_refresh_token_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_oauth2_refresh_token_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_operate_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_operate_log (
    id bigint NOT NULL,
    trace_id character varying(64) DEFAULT ''::character varying NOT NULL,
    user_id bigint NOT NULL,
    user_type smallint DEFAULT 0 NOT NULL,
    type character varying(50) NOT NULL,
    sub_type character varying(50) NOT NULL,
    biz_id bigint NOT NULL,
    action character varying(2000) DEFAULT ''::character varying NOT NULL,
    success boolean DEFAULT true NOT NULL,
    extra character varying(2000) DEFAULT ''::character varying NOT NULL,
    request_method character varying(16) DEFAULT ''::character varying,
    request_url character varying(255) DEFAULT ''::character varying,
    user_ip character varying(50) DEFAULT NULL::character varying,
    user_agent character varying(512) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_operate_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_operate_log IS '操作日志记录 V2 版本';


--
-- Name: COLUMN system_operate_log.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.id IS '日志主键';


--
-- Name: COLUMN system_operate_log.trace_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.trace_id IS '链路追踪编号';


--
-- Name: COLUMN system_operate_log.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.user_id IS '用户编号';


--
-- Name: COLUMN system_operate_log.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.user_type IS '用户类型';


--
-- Name: COLUMN system_operate_log.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.type IS '操作模块类型';


--
-- Name: COLUMN system_operate_log.sub_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.sub_type IS '操作名';


--
-- Name: COLUMN system_operate_log.biz_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.biz_id IS '操作数据模块编号';


--
-- Name: COLUMN system_operate_log.action; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.action IS '操作内容';


--
-- Name: COLUMN system_operate_log.success; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.success IS '操作结果';


--
-- Name: COLUMN system_operate_log.extra; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.extra IS '拓展字段';


--
-- Name: COLUMN system_operate_log.request_method; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.request_method IS '请求方法名';


--
-- Name: COLUMN system_operate_log.request_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.request_url IS '请求地址';


--
-- Name: COLUMN system_operate_log.user_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.user_ip IS '用户 IP';


--
-- Name: COLUMN system_operate_log.user_agent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.user_agent IS '浏览器 UA';


--
-- Name: COLUMN system_operate_log.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.creator IS '创建者';


--
-- Name: COLUMN system_operate_log.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.create_time IS '创建时间';


--
-- Name: COLUMN system_operate_log.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.updater IS '更新者';


--
-- Name: COLUMN system_operate_log.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.update_time IS '更新时间';


--
-- Name: COLUMN system_operate_log.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.deleted IS '是否删除';


--
-- Name: COLUMN system_operate_log.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_operate_log.tenant_id IS '租户编号';


--
-- Name: system_operate_log_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_operate_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_post; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_post (
    id bigint NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(50) NOT NULL,
    sort integer NOT NULL,
    status smallint NOT NULL,
    remark character varying(500) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_post; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_post IS '岗位信息表';


--
-- Name: COLUMN system_post.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.id IS '岗位ID';


--
-- Name: COLUMN system_post.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.code IS '岗位编码';


--
-- Name: COLUMN system_post.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.name IS '岗位名称';


--
-- Name: COLUMN system_post.sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.sort IS '显示顺序';


--
-- Name: COLUMN system_post.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.status IS '状态（0正常 1停用）';


--
-- Name: COLUMN system_post.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.remark IS '备注';


--
-- Name: COLUMN system_post.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.creator IS '创建者';


--
-- Name: COLUMN system_post.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.create_time IS '创建时间';


--
-- Name: COLUMN system_post.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.updater IS '更新者';


--
-- Name: COLUMN system_post.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.update_time IS '更新时间';


--
-- Name: COLUMN system_post.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.deleted IS '是否删除';


--
-- Name: COLUMN system_post.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_post.tenant_id IS '租户编号';


--
-- Name: system_post_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_post_seq
    START WITH 8
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_role; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_role (
    id bigint NOT NULL,
    name character varying(30) NOT NULL,
    code character varying(100) NOT NULL,
    sort integer NOT NULL,
    data_scope smallint DEFAULT 1 NOT NULL,
    data_scope_dept_ids character varying(500) DEFAULT ''::character varying NOT NULL,
    status smallint NOT NULL,
    type smallint NOT NULL,
    remark character varying(500) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_role IS '角色信息表';


--
-- Name: COLUMN system_role.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.id IS '角色ID';


--
-- Name: COLUMN system_role.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.name IS '角色名称';


--
-- Name: COLUMN system_role.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.code IS '角色权限字符串';


--
-- Name: COLUMN system_role.sort; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.sort IS '显示顺序';


--
-- Name: COLUMN system_role.data_scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.data_scope IS '数据范围（1：全部数据权限 2：自定数据权限 3：本部门数据权限 4：本部门及以下数据权限）';


--
-- Name: COLUMN system_role.data_scope_dept_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.data_scope_dept_ids IS '数据范围(指定部门数组)';


--
-- Name: COLUMN system_role.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.status IS '角色状态（0正常 1停用）';


--
-- Name: COLUMN system_role.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.type IS '角色类型';


--
-- Name: COLUMN system_role.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.remark IS '备注';


--
-- Name: COLUMN system_role.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.creator IS '创建者';


--
-- Name: COLUMN system_role.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.create_time IS '创建时间';


--
-- Name: COLUMN system_role.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.updater IS '更新者';


--
-- Name: COLUMN system_role.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.update_time IS '更新时间';


--
-- Name: COLUMN system_role.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.deleted IS '是否删除';


--
-- Name: COLUMN system_role.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role.tenant_id IS '租户编号';


--
-- Name: system_role_menu; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_role_menu (
    id bigint NOT NULL,
    role_id bigint NOT NULL,
    menu_id bigint NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_role_menu; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_role_menu IS '角色和菜单关联表';


--
-- Name: COLUMN system_role_menu.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role_menu.id IS '自增编号';


--
-- Name: COLUMN system_role_menu.role_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role_menu.role_id IS '角色ID';


--
-- Name: COLUMN system_role_menu.menu_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role_menu.menu_id IS '菜单ID';


--
-- Name: COLUMN system_role_menu.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role_menu.creator IS '创建者';


--
-- Name: COLUMN system_role_menu.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role_menu.create_time IS '创建时间';


--
-- Name: COLUMN system_role_menu.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role_menu.updater IS '更新者';


--
-- Name: COLUMN system_role_menu.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role_menu.update_time IS '更新时间';


--
-- Name: COLUMN system_role_menu.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role_menu.deleted IS '是否删除';


--
-- Name: COLUMN system_role_menu.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_role_menu.tenant_id IS '租户编号';


--
-- Name: system_role_menu_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_role_menu_seq
    START WITH 6365
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_role_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_role_seq
    START WITH 156
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_sms_channel; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_sms_channel (
    id bigint NOT NULL,
    signature character varying(12) NOT NULL,
    code character varying(63) NOT NULL,
    status smallint NOT NULL,
    remark character varying(255) DEFAULT NULL::character varying,
    api_key character varying(128) NOT NULL,
    api_secret character varying(128) DEFAULT NULL::character varying,
    callback_url character varying(255) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_sms_channel; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_sms_channel IS '短信渠道';


--
-- Name: COLUMN system_sms_channel.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.id IS '编号';


--
-- Name: COLUMN system_sms_channel.signature; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.signature IS '短信签名';


--
-- Name: COLUMN system_sms_channel.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.code IS '渠道编码';


--
-- Name: COLUMN system_sms_channel.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.status IS '开启状态';


--
-- Name: COLUMN system_sms_channel.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.remark IS '备注';


--
-- Name: COLUMN system_sms_channel.api_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.api_key IS '短信 API 的账号';


--
-- Name: COLUMN system_sms_channel.api_secret; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.api_secret IS '短信 API 的秘钥';


--
-- Name: COLUMN system_sms_channel.callback_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.callback_url IS '短信发送回调 URL';


--
-- Name: COLUMN system_sms_channel.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.creator IS '创建者';


--
-- Name: COLUMN system_sms_channel.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.create_time IS '创建时间';


--
-- Name: COLUMN system_sms_channel.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.updater IS '更新者';


--
-- Name: COLUMN system_sms_channel.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.update_time IS '更新时间';


--
-- Name: COLUMN system_sms_channel.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_channel.deleted IS '是否删除';


--
-- Name: system_sms_channel_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_sms_channel_seq
    START WITH 8
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_sms_code; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_sms_code (
    id bigint NOT NULL,
    mobile character varying(11) NOT NULL,
    code character varying(6) NOT NULL,
    create_ip character varying(15) NOT NULL,
    scene smallint NOT NULL,
    today_index smallint NOT NULL,
    used smallint NOT NULL,
    used_time timestamp without time zone,
    used_ip character varying(255) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_sms_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_sms_code IS '手机验证码';


--
-- Name: COLUMN system_sms_code.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.id IS '编号';


--
-- Name: COLUMN system_sms_code.mobile; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.mobile IS '手机号';


--
-- Name: COLUMN system_sms_code.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.code IS '验证码';


--
-- Name: COLUMN system_sms_code.create_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.create_ip IS '创建 IP';


--
-- Name: COLUMN system_sms_code.scene; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.scene IS '发送场景';


--
-- Name: COLUMN system_sms_code.today_index; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.today_index IS '今日发送的第几条';


--
-- Name: COLUMN system_sms_code.used; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.used IS '是否使用';


--
-- Name: COLUMN system_sms_code.used_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.used_time IS '使用时间';


--
-- Name: COLUMN system_sms_code.used_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.used_ip IS '使用 IP';


--
-- Name: COLUMN system_sms_code.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.creator IS '创建者';


--
-- Name: COLUMN system_sms_code.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.create_time IS '创建时间';


--
-- Name: COLUMN system_sms_code.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.updater IS '更新者';


--
-- Name: COLUMN system_sms_code.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.update_time IS '更新时间';


--
-- Name: COLUMN system_sms_code.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.deleted IS '是否删除';


--
-- Name: COLUMN system_sms_code.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_code.tenant_id IS '租户编号';


--
-- Name: system_sms_code_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_sms_code_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_sms_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_sms_log (
    id bigint NOT NULL,
    channel_id bigint NOT NULL,
    channel_code character varying(63) NOT NULL,
    template_id bigint NOT NULL,
    template_code character varying(63) NOT NULL,
    template_type smallint NOT NULL,
    template_content character varying(255) NOT NULL,
    template_params character varying(255) NOT NULL,
    api_template_id character varying(63) NOT NULL,
    mobile character varying(11) NOT NULL,
    user_id bigint,
    user_type smallint,
    send_status smallint DEFAULT 0 NOT NULL,
    send_time timestamp without time zone,
    api_send_code character varying(63) DEFAULT NULL::character varying,
    api_send_msg character varying(255) DEFAULT NULL::character varying,
    api_request_id character varying(255) DEFAULT NULL::character varying,
    api_serial_no character varying(255) DEFAULT NULL::character varying,
    receive_status smallint DEFAULT 0 NOT NULL,
    receive_time timestamp without time zone,
    api_receive_code character varying(63) DEFAULT NULL::character varying,
    api_receive_msg character varying(255) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_sms_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_sms_log IS '短信日志';


--
-- Name: COLUMN system_sms_log.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.id IS '编号';


--
-- Name: COLUMN system_sms_log.channel_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.channel_id IS '短信渠道编号';


--
-- Name: COLUMN system_sms_log.channel_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.channel_code IS '短信渠道编码';


--
-- Name: COLUMN system_sms_log.template_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.template_id IS '模板编号';


--
-- Name: COLUMN system_sms_log.template_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.template_code IS '模板编码';


--
-- Name: COLUMN system_sms_log.template_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.template_type IS '短信类型';


--
-- Name: COLUMN system_sms_log.template_content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.template_content IS '短信内容';


--
-- Name: COLUMN system_sms_log.template_params; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.template_params IS '短信参数';


--
-- Name: COLUMN system_sms_log.api_template_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.api_template_id IS '短信 API 的模板编号';


--
-- Name: COLUMN system_sms_log.mobile; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.mobile IS '手机号';


--
-- Name: COLUMN system_sms_log.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.user_id IS '用户编号';


--
-- Name: COLUMN system_sms_log.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.user_type IS '用户类型';


--
-- Name: COLUMN system_sms_log.send_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.send_status IS '发送状态';


--
-- Name: COLUMN system_sms_log.send_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.send_time IS '发送时间';


--
-- Name: COLUMN system_sms_log.api_send_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.api_send_code IS '短信 API 发送结果的编码';


--
-- Name: COLUMN system_sms_log.api_send_msg; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.api_send_msg IS '短信 API 发送失败的提示';


--
-- Name: COLUMN system_sms_log.api_request_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.api_request_id IS '短信 API 发送返回的唯一请求 ID';


--
-- Name: COLUMN system_sms_log.api_serial_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.api_serial_no IS '短信 API 发送返回的序号';


--
-- Name: COLUMN system_sms_log.receive_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.receive_status IS '接收状态';


--
-- Name: COLUMN system_sms_log.receive_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.receive_time IS '接收时间';


--
-- Name: COLUMN system_sms_log.api_receive_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.api_receive_code IS 'API 接收结果的编码';


--
-- Name: COLUMN system_sms_log.api_receive_msg; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.api_receive_msg IS 'API 接收结果的说明';


--
-- Name: COLUMN system_sms_log.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.creator IS '创建者';


--
-- Name: COLUMN system_sms_log.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.create_time IS '创建时间';


--
-- Name: COLUMN system_sms_log.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.updater IS '更新者';


--
-- Name: COLUMN system_sms_log.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.update_time IS '更新时间';


--
-- Name: COLUMN system_sms_log.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_log.deleted IS '是否删除';


--
-- Name: system_sms_log_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_sms_log_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_sms_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_sms_template (
    id bigint NOT NULL,
    type smallint NOT NULL,
    status smallint NOT NULL,
    code character varying(63) NOT NULL,
    name character varying(63) NOT NULL,
    content character varying(255) NOT NULL,
    params character varying(255) NOT NULL,
    remark character varying(255) DEFAULT NULL::character varying,
    api_template_id character varying(63) NOT NULL,
    channel_id bigint NOT NULL,
    channel_code character varying(63) NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_sms_template; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_sms_template IS '短信模板';


--
-- Name: COLUMN system_sms_template.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.id IS '编号';


--
-- Name: COLUMN system_sms_template.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.type IS '模板类型';


--
-- Name: COLUMN system_sms_template.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.status IS '开启状态';


--
-- Name: COLUMN system_sms_template.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.code IS '模板编码';


--
-- Name: COLUMN system_sms_template.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.name IS '模板名称';


--
-- Name: COLUMN system_sms_template.content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.content IS '模板内容';


--
-- Name: COLUMN system_sms_template.params; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.params IS '参数数组';


--
-- Name: COLUMN system_sms_template.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.remark IS '备注';


--
-- Name: COLUMN system_sms_template.api_template_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.api_template_id IS '短信 API 的模板编号';


--
-- Name: COLUMN system_sms_template.channel_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.channel_id IS '短信渠道编号';


--
-- Name: COLUMN system_sms_template.channel_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.channel_code IS '短信渠道编码';


--
-- Name: COLUMN system_sms_template.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.creator IS '创建者';


--
-- Name: COLUMN system_sms_template.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.create_time IS '创建时间';


--
-- Name: COLUMN system_sms_template.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.updater IS '更新者';


--
-- Name: COLUMN system_sms_template.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.update_time IS '更新时间';


--
-- Name: COLUMN system_sms_template.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_sms_template.deleted IS '是否删除';


--
-- Name: system_sms_template_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_sms_template_seq
    START WITH 20
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_social_client; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_social_client (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    social_type smallint NOT NULL,
    user_type smallint NOT NULL,
    client_id character varying(255) NOT NULL,
    client_secret character varying(255) NOT NULL,
    agent_id character varying(255) DEFAULT NULL::character varying,
    public_key character varying(2048) DEFAULT NULL::character varying,
    status smallint NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_social_client; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_social_client IS '社交客户端表';


--
-- Name: COLUMN system_social_client.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.id IS '编号';


--
-- Name: COLUMN system_social_client.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.name IS '应用名';


--
-- Name: COLUMN system_social_client.social_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.social_type IS '社交平台的类型';


--
-- Name: COLUMN system_social_client.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.user_type IS '用户类型';


--
-- Name: COLUMN system_social_client.client_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.client_id IS '客户端编号';


--
-- Name: COLUMN system_social_client.client_secret; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.client_secret IS '客户端密钥';


--
-- Name: COLUMN system_social_client.agent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.agent_id IS '代理编号';


--
-- Name: COLUMN system_social_client.public_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.public_key IS 'publicKey 公钥';


--
-- Name: COLUMN system_social_client.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.status IS '状态';


--
-- Name: COLUMN system_social_client.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.creator IS '创建者';


--
-- Name: COLUMN system_social_client.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.create_time IS '创建时间';


--
-- Name: COLUMN system_social_client.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.updater IS '更新者';


--
-- Name: COLUMN system_social_client.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.update_time IS '更新时间';


--
-- Name: COLUMN system_social_client.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.deleted IS '是否删除';


--
-- Name: COLUMN system_social_client.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_client.tenant_id IS '租户编号';


--
-- Name: system_social_client_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_social_client_seq
    START WITH 48
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_social_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_social_user (
    id bigint NOT NULL,
    type smallint NOT NULL,
    openid character varying(32) NOT NULL,
    token character varying(256) DEFAULT NULL::character varying,
    raw_token_info character varying(1024) NOT NULL,
    nickname character varying(32) NOT NULL,
    avatar character varying(255) DEFAULT NULL::character varying,
    raw_user_info character varying(1024) NOT NULL,
    code character varying(256) NOT NULL,
    state character varying(256) DEFAULT NULL::character varying,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_social_user; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_social_user IS '社交用户表';


--
-- Name: COLUMN system_social_user.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.id IS '主键(自增策略)';


--
-- Name: COLUMN system_social_user.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.type IS '社交平台的类型';


--
-- Name: COLUMN system_social_user.openid; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.openid IS '社交 openid';


--
-- Name: COLUMN system_social_user.token; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.token IS '社交 token';


--
-- Name: COLUMN system_social_user.raw_token_info; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.raw_token_info IS '原始 Token 数据，一般是 JSON 格式';


--
-- Name: COLUMN system_social_user.nickname; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.nickname IS '用户昵称';


--
-- Name: COLUMN system_social_user.avatar; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.avatar IS '用户头像';


--
-- Name: COLUMN system_social_user.raw_user_info; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.raw_user_info IS '原始用户数据，一般是 JSON 格式';


--
-- Name: COLUMN system_social_user.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.code IS '最后一次的认证 code';


--
-- Name: COLUMN system_social_user.state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.state IS '最后一次的认证 state';


--
-- Name: COLUMN system_social_user.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.creator IS '创建者';


--
-- Name: COLUMN system_social_user.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.create_time IS '创建时间';


--
-- Name: COLUMN system_social_user.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.updater IS '更新者';


--
-- Name: COLUMN system_social_user.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.update_time IS '更新时间';


--
-- Name: COLUMN system_social_user.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.deleted IS '是否删除';


--
-- Name: COLUMN system_social_user.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user.tenant_id IS '租户编号';


--
-- Name: system_social_user_bind; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_social_user_bind (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    user_type smallint NOT NULL,
    social_type smallint NOT NULL,
    social_user_id bigint NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_social_user_bind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_social_user_bind IS '社交绑定表';


--
-- Name: COLUMN system_social_user_bind.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.id IS '主键(自增策略)';


--
-- Name: COLUMN system_social_user_bind.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.user_id IS '用户编号';


--
-- Name: COLUMN system_social_user_bind.user_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.user_type IS '用户类型';


--
-- Name: COLUMN system_social_user_bind.social_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.social_type IS '社交平台的类型';


--
-- Name: COLUMN system_social_user_bind.social_user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.social_user_id IS '社交用户的编号';


--
-- Name: COLUMN system_social_user_bind.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.creator IS '创建者';


--
-- Name: COLUMN system_social_user_bind.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.create_time IS '创建时间';


--
-- Name: COLUMN system_social_user_bind.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.updater IS '更新者';


--
-- Name: COLUMN system_social_user_bind.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.update_time IS '更新时间';


--
-- Name: COLUMN system_social_user_bind.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.deleted IS '是否删除';


--
-- Name: COLUMN system_social_user_bind.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_social_user_bind.tenant_id IS '租户编号';


--
-- Name: system_social_user_bind_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_social_user_bind_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_social_user_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_social_user_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_tenant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_tenant (
    id bigint NOT NULL,
    name character varying(30) NOT NULL,
    contact_user_id bigint,
    contact_name character varying(30) NOT NULL,
    contact_mobile character varying(500) DEFAULT NULL::character varying,
    status smallint DEFAULT 0 NOT NULL,
    websites character varying(1024) DEFAULT ''::character varying,
    package_id bigint NOT NULL,
    expire_time timestamp without time zone NOT NULL,
    account_count integer NOT NULL,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_tenant; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_tenant IS '租户表';


--
-- Name: COLUMN system_tenant.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.id IS '租户编号';


--
-- Name: COLUMN system_tenant.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.name IS '租户名';


--
-- Name: COLUMN system_tenant.contact_user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.contact_user_id IS '联系人的用户编号';


--
-- Name: COLUMN system_tenant.contact_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.contact_name IS '联系人';


--
-- Name: COLUMN system_tenant.contact_mobile; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.contact_mobile IS '联系手机';


--
-- Name: COLUMN system_tenant.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.status IS '租户状态';


--
-- Name: COLUMN system_tenant.websites; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.websites IS '绑定域名数组';


--
-- Name: COLUMN system_tenant.package_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.package_id IS '租户套餐编号';


--
-- Name: COLUMN system_tenant.expire_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.expire_time IS '过期时间';


--
-- Name: COLUMN system_tenant.account_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.account_count IS '账号数量';


--
-- Name: COLUMN system_tenant.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.creator IS '创建者';


--
-- Name: COLUMN system_tenant.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.create_time IS '创建时间';


--
-- Name: COLUMN system_tenant.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.updater IS '更新者';


--
-- Name: COLUMN system_tenant.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.update_time IS '更新时间';


--
-- Name: COLUMN system_tenant.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant.deleted IS '是否删除';


--
-- Name: system_tenant_package; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_tenant_package (
    id bigint CONSTRAINT system_tenant_package_id_not_null1 NOT NULL,
    name character varying(30) NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    remark character varying(256) DEFAULT ''::character varying,
    menu_ids character varying(4096) NOT NULL,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_tenant_package; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_tenant_package IS '租户套餐表';


--
-- Name: COLUMN system_tenant_package.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant_package.id IS '套餐编号';


--
-- Name: COLUMN system_tenant_package.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant_package.name IS '套餐名';


--
-- Name: COLUMN system_tenant_package.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant_package.status IS '租户状态（0正常 1停用）';


--
-- Name: COLUMN system_tenant_package.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant_package.remark IS '备注';


--
-- Name: COLUMN system_tenant_package.menu_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant_package.menu_ids IS '关联的菜单编号';


--
-- Name: COLUMN system_tenant_package.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant_package.creator IS '创建者';


--
-- Name: COLUMN system_tenant_package.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant_package.create_time IS '创建时间';


--
-- Name: COLUMN system_tenant_package.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant_package.updater IS '更新者';


--
-- Name: COLUMN system_tenant_package.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant_package.update_time IS '更新时间';


--
-- Name: COLUMN system_tenant_package.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_tenant_package.deleted IS '是否删除';


--
-- Name: system_tenant_package_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_tenant_package_seq
    START WITH 112
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_tenant_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_tenant_seq
    START WITH 123
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_user_post; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_user_post (
    id bigint NOT NULL,
    user_id bigint DEFAULT 0 NOT NULL,
    post_id bigint DEFAULT 0 NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_user_post; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_user_post IS '用户岗位表';


--
-- Name: COLUMN system_user_post.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_post.id IS 'id';


--
-- Name: COLUMN system_user_post.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_post.user_id IS '用户ID';


--
-- Name: COLUMN system_user_post.post_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_post.post_id IS '岗位ID';


--
-- Name: COLUMN system_user_post.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_post.creator IS '创建者';


--
-- Name: COLUMN system_user_post.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_post.create_time IS '创建时间';


--
-- Name: COLUMN system_user_post.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_post.updater IS '更新者';


--
-- Name: COLUMN system_user_post.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_post.update_time IS '更新时间';


--
-- Name: COLUMN system_user_post.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_post.deleted IS '是否删除';


--
-- Name: COLUMN system_user_post.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_post.tenant_id IS '租户编号';


--
-- Name: system_user_post_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_user_post_seq
    START WITH 130
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_user_role; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_user_role (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    role_id bigint NOT NULL,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_user_role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_user_role IS '用户和角色关联表';


--
-- Name: COLUMN system_user_role.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_role.id IS '自增编号';


--
-- Name: COLUMN system_user_role.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_role.user_id IS '用户ID';


--
-- Name: COLUMN system_user_role.role_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_role.role_id IS '角色ID';


--
-- Name: COLUMN system_user_role.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_role.creator IS '创建者';


--
-- Name: COLUMN system_user_role.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_role.create_time IS '创建时间';


--
-- Name: COLUMN system_user_role.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_role.updater IS '更新者';


--
-- Name: COLUMN system_user_role.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_role.update_time IS '更新时间';


--
-- Name: COLUMN system_user_role.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_role.deleted IS '是否删除';


--
-- Name: COLUMN system_user_role.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_user_role.tenant_id IS '租户编号';


--
-- Name: system_user_role_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_user_role_seq
    START WITH 55
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: system_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_users (
    id bigint NOT NULL,
    username character varying(30) NOT NULL,
    password character varying(100) DEFAULT ''::character varying NOT NULL,
    nickname character varying(30) NOT NULL,
    remark character varying(500) DEFAULT NULL::character varying,
    dept_id bigint,
    post_ids character varying(255) DEFAULT NULL::character varying,
    email character varying(50) DEFAULT ''::character varying,
    mobile character varying(11) DEFAULT ''::character varying,
    sex smallint DEFAULT 0,
    avatar character varying(512) DEFAULT ''::character varying,
    status smallint DEFAULT 0 NOT NULL,
    login_ip character varying(50) DEFAULT ''::character varying,
    login_date timestamp without time zone,
    creator character varying(64) DEFAULT ''::character varying,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL,
    tenant_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: TABLE system_users; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_users IS '用户信息表';


--
-- Name: COLUMN system_users.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.id IS '用户ID';


--
-- Name: COLUMN system_users.username; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.username IS '用户账号';


--
-- Name: COLUMN system_users.password; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.password IS '密码';


--
-- Name: COLUMN system_users.nickname; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.nickname IS '用户昵称';


--
-- Name: COLUMN system_users.remark; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.remark IS '备注';


--
-- Name: COLUMN system_users.dept_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.dept_id IS '部门ID';


--
-- Name: COLUMN system_users.post_ids; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.post_ids IS '岗位编号数组';


--
-- Name: COLUMN system_users.email; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.email IS '用户邮箱';


--
-- Name: COLUMN system_users.mobile; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.mobile IS '手机号码';


--
-- Name: COLUMN system_users.sex; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.sex IS '用户性别';


--
-- Name: COLUMN system_users.avatar; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.avatar IS '头像地址';


--
-- Name: COLUMN system_users.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.status IS '帐号状态（0正常 1停用）';


--
-- Name: COLUMN system_users.login_ip; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.login_ip IS '最后登录IP';


--
-- Name: COLUMN system_users.login_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.login_date IS '最后登录时间';


--
-- Name: COLUMN system_users.creator; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.creator IS '创建者';


--
-- Name: COLUMN system_users.create_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.create_time IS '创建时间';


--
-- Name: COLUMN system_users.updater; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.updater IS '更新者';


--
-- Name: COLUMN system_users.update_time; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.update_time IS '更新时间';


--
-- Name: COLUMN system_users.deleted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.deleted IS '是否删除';


--
-- Name: COLUMN system_users.tenant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_users.tenant_id IS '租户编号';


--
-- Name: system_users_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.system_users_seq
    START WITH 145
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: yudao_demo01_contact_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.yudao_demo01_contact_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: yudao_demo01_contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.yudao_demo01_contact (
    id bigint DEFAULT nextval('public.yudao_demo01_contact_seq'::regclass) NOT NULL,
    name character varying(100),
    sex smallint,
    birthday date,
    description text,
    avatar character varying(1024),
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: yudao_demo02_category_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.yudao_demo02_category_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: yudao_demo02_category; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.yudao_demo02_category (
    id bigint DEFAULT nextval('public.yudao_demo02_category_seq'::regclass) NOT NULL,
    name character varying(100),
    parent_id bigint,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: yudao_demo03_course_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.yudao_demo03_course_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: yudao_demo03_course; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.yudao_demo03_course (
    id bigint DEFAULT nextval('public.yudao_demo03_course_seq'::regclass) NOT NULL,
    student_id bigint DEFAULT 0 NOT NULL,
    name character varying(100),
    score integer,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: yudao_demo03_grade_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.yudao_demo03_grade_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: yudao_demo03_grade; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.yudao_demo03_grade (
    id bigint DEFAULT nextval('public.yudao_demo03_grade_seq'::regclass) NOT NULL,
    student_id bigint DEFAULT 0 NOT NULL,
    name character varying(100),
    teacher character varying(100),
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: yudao_demo03_student_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.yudao_demo03_student_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: yudao_demo03_student; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.yudao_demo03_student (
    id bigint DEFAULT nextval('public.yudao_demo03_student_seq'::regclass) NOT NULL,
    name character varying(100),
    sex smallint,
    birthday date,
    description text,
    creator character varying(64) DEFAULT ''::character varying NOT NULL,
    create_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updater character varying(64) DEFAULT ''::character varying NOT NULL,
    update_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deleted smallint DEFAULT 0 NOT NULL
);


--
-- Name: episodes; Type: TABLE; Schema: toon; Owner: -
--

CREATE TABLE toon.episodes (
    id uuid NOT NULL,
    project_id uuid NOT NULL,
    title character varying(128) NOT NULL,
    episode_no integer NOT NULL,
    summary text,
    status character varying(32) DEFAULT 'draft'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: toon; Owner: -
--

CREATE TABLE toon.projects (
    id uuid NOT NULL,
    name character varying(128) NOT NULL,
    owner_user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    description text,
    status character varying(32) DEFAULT 'draft'::character varying NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: publications; Type: TABLE; Schema: toon; Owner: -
--

CREATE TABLE toon.publications (
    id uuid NOT NULL,
    project_id uuid NOT NULL,
    channel character varying(64) NOT NULL,
    status character varying(32) DEFAULT 'published'::character varying NOT NULL,
    published_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: scenes; Type: TABLE; Schema: toon; Owner: -
--

CREATE TABLE toon.scenes (
    id uuid NOT NULL,
    episode_id uuid NOT NULL,
    title character varying(128) NOT NULL,
    scene_no integer NOT NULL,
    content text,
    status character varying(32) DEFAULT 'draft'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: agent_deployments; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.agent_deployments (
    id bigint NOT NULL,
    key character varying(128) NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    name character varying(128) NOT NULL,
    temperature integer DEFAULT 1 NOT NULL,
    max_output_tokens integer DEFAULT 0 NOT NULL,
    disabled boolean DEFAULT false NOT NULL,
    model_config_id bigint
);


--
-- Name: agent_deployments_id_seq; Type: SEQUENCE; Schema: toonflow; Owner: -
--

ALTER TABLE toonflow.agent_deployments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME toonflow.agent_deployments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: agent_memories; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.agent_memories (
    id bigint NOT NULL,
    agent_type character varying(64) NOT NULL,
    isolation_key character varying(255) NOT NULL,
    role character varying(64) NOT NULL,
    content text NOT NULL,
    memory_type character varying(32) DEFAULT 'message'::character varying NOT NULL,
    summarized boolean DEFAULT false NOT NULL,
    related_message_ids jsonb DEFAULT '[]'::jsonb NOT NULL,
    create_time bigint NOT NULL
);


--
-- Name: agent_run_events; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.agent_run_events (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    event_type character varying(32) NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    create_time bigint NOT NULL
);


--
-- Name: agent_run_events_id_seq; Type: SEQUENCE; Schema: toonflow; Owner: -
--

ALTER TABLE toonflow.agent_run_events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME toonflow.agent_run_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: agent_runs; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.agent_runs (
    id bigint NOT NULL,
    agent_type character varying(64) NOT NULL,
    isolation_key character varying(255) NOT NULL,
    project_id bigint NOT NULL,
    script_id bigint,
    input text NOT NULL,
    output text,
    state character varying(32) NOT NULL,
    error_reason text,
    think boolean DEFAULT false NOT NULL,
    think_level integer DEFAULT 0 NOT NULL,
    start_time bigint NOT NULL,
    finish_time bigint
);


--
-- Name: agent_tool_calls; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.agent_tool_calls (
    id bigint NOT NULL,
    run_id bigint,
    agent_type character varying(64) NOT NULL,
    tool_name character varying(128) NOT NULL,
    arguments jsonb DEFAULT '{}'::jsonb NOT NULL,
    result jsonb,
    state character varying(32) NOT NULL,
    error_reason text,
    create_time bigint NOT NULL,
    finish_time bigint
);


--
-- Name: agent_work_data; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.agent_work_data (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    episodes_id bigint,
    key character varying(128) NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL
);


--
-- Name: agent_work_data_id_seq; Type: SEQUENCE; Schema: toonflow; Owner: -
--

ALTER TABLE toonflow.agent_work_data ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME toonflow.agent_work_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: art_styles; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.art_styles (
    id bigint NOT NULL,
    name character varying(128) NOT NULL,
    file_url text DEFAULT ''::text NOT NULL,
    label text DEFAULT ''::text NOT NULL,
    prompt text DEFAULT ''::text NOT NULL,
    create_time bigint DEFAULT (floor((EXTRACT(epoch FROM clock_timestamp()) * (1000)::numeric)))::bigint NOT NULL
);


--
-- Name: asset_audio_bindings; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.asset_audio_bindings (
    asset_role_id bigint NOT NULL,
    asset_audio_id bigint NOT NULL,
    create_time bigint NOT NULL
);


--
-- Name: assets; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.assets (
    id bigint NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    prompt text DEFAULT ''::text NOT NULL,
    remark text,
    type text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    script_id bigint,
    image_id bigint,
    parent_asset_id bigint,
    project_id bigint NOT NULL,
    flow_id bigint,
    start_time bigint,
    prompt_state character varying(64),
    audio_bind_state integer,
    prompt_error_reason text
);


--
-- Name: assets_storyboards; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.assets_storyboards (
    storyboard_id bigint NOT NULL,
    asset_id bigint NOT NULL
);


--
-- Name: creative_manuals; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.creative_manuals (
    id bigint NOT NULL,
    kind character varying(32) NOT NULL,
    name character varying(255) NOT NULL,
    path character varying(255) NOT NULL,
    images jsonb DEFAULT '[]'::jsonb NOT NULL,
    data jsonb DEFAULT '[]'::jsonb NOT NULL,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL,
    CONSTRAINT creative_manuals_kind_check CHECK (((kind)::text = ANY (ARRAY[('visual'::character varying)::text, ('director'::character varying)::text])))
);


--
-- Name: creative_manuals_id_seq; Type: SEQUENCE; Schema: toonflow; Owner: -
--

ALTER TABLE toonflow.creative_manuals ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME toonflow.creative_manuals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: event_chapters; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.event_chapters (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    novel_id bigint NOT NULL
);


--
-- Name: event_chapters_id_seq; Type: SEQUENCE; Schema: toonflow; Owner: -
--

ALTER TABLE toonflow.event_chapters ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME toonflow.event_chapters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: events; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.events (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    detail text DEFAULT ''::text NOT NULL,
    create_time bigint NOT NULL
);


--
-- Name: image_flows; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.image_flows (
    id bigint NOT NULL,
    flow_data jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: images; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.images (
    id bigint NOT NULL,
    file_path text,
    type text,
    assets_id bigint,
    model text,
    resolution text,
    state text,
    error_reason text
);


--
-- Name: novels; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.novels (
    id bigint NOT NULL,
    chapter_index integer NOT NULL,
    reel text DEFAULT ''::text NOT NULL,
    chapter text DEFAULT ''::text NOT NULL,
    chapter_data text DEFAULT ''::text NOT NULL,
    project_id bigint NOT NULL,
    event_state integer DEFAULT 0 NOT NULL,
    event text,
    error_reason text,
    create_time bigint NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.projects (
    id bigint NOT NULL,
    project_type character varying(64) DEFAULT ''::character varying NOT NULL,
    image_model bigint,
    image_quality character varying(64) DEFAULT ''::character varying NOT NULL,
    video_model bigint,
    name text NOT NULL,
    intro text DEFAULT ''::text NOT NULL,
    type text DEFAULT ''::text NOT NULL,
    art_style text DEFAULT ''::text NOT NULL,
    director_manual text DEFAULT ''::text NOT NULL,
    mode text DEFAULT ''::text NOT NULL,
    video_ratio text DEFAULT ''::text NOT NULL,
    user_id uuid,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL
);


--
-- Name: prompts; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.prompts (
    id bigint NOT NULL,
    name character varying(128) NOT NULL,
    type character varying(128) NOT NULL,
    data text DEFAULT ''::text NOT NULL,
    use_data text
);


--
-- Name: prompts_id_seq; Type: SEQUENCE; Schema: toonflow; Owner: -
--

ALTER TABLE toonflow.prompts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME toonflow.prompts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: script_assets; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.script_assets (
    script_id bigint NOT NULL,
    asset_id bigint NOT NULL
);


--
-- Name: scripts; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.scripts (
    id bigint NOT NULL,
    name text NOT NULL,
    content text DEFAULT ''::text NOT NULL,
    project_id bigint NOT NULL,
    extract_state integer,
    create_time bigint NOT NULL,
    error_reason text
);


--
-- Name: settings; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.settings (
    key text NOT NULL,
    value text NOT NULL
);


--
-- Name: skill_list; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.skill_list (
    id text NOT NULL,
    md5 text NOT NULL,
    path text NOT NULL,
    name text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    embedding text,
    type text NOT NULL,
    create_time bigint NOT NULL,
    update_time bigint NOT NULL,
    state integer NOT NULL,
    content text DEFAULT ''::text NOT NULL
);


--
-- Name: storyboards; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.storyboards (
    id bigint NOT NULL,
    script_id bigint NOT NULL,
    prompt text DEFAULT ''::text NOT NULL,
    file_path text,
    duration text,
    state text,
    track_id bigint,
    reason text,
    track text,
    video_desc text,
    should_generate_image integer DEFAULT 1 NOT NULL,
    project_id bigint NOT NULL,
    flow_id bigint,
    index integer,
    create_time bigint NOT NULL
);


--
-- Name: tasks; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.tasks (
    id bigint NOT NULL,
    project_id bigint,
    task_class character varying(128) DEFAULT ''::character varying NOT NULL,
    related_objects character varying(255) DEFAULT ''::character varying NOT NULL,
    model character varying(128) DEFAULT ''::character varying NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    state character varying(64) DEFAULT ''::character varying NOT NULL,
    start_time bigint,
    reason text
);


--
-- Name: video_tracks; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.video_tracks (
    id bigint NOT NULL,
    video_id bigint,
    project_id bigint NOT NULL,
    script_id bigint,
    state text,
    reason text,
    prompt text,
    select_video_id bigint,
    duration integer,
    sort_order integer DEFAULT 0 NOT NULL
);


--
-- Name: videos; Type: TABLE; Schema: toonflow; Owner: -
--

CREATE TABLE toonflow.videos (
    id bigint NOT NULL,
    file_path text,
    error_reason text,
    "time" bigint,
    state text,
    script_id bigint,
    project_id bigint NOT NULL,
    video_track_id bigint
);


--
-- Data for Name: chat_conversations; Type: TABLE DATA; Schema: ai; Owner: -
--



--
-- Data for Name: chat_messages; Type: TABLE DATA; Schema: ai; Owner: -
--



--
-- Data for Name: chat_roles; Type: TABLE DATA; Schema: ai; Owner: -
--



--
-- Data for Name: images; Type: TABLE DATA; Schema: ai; Owner: -
--



--
-- Data for Name: knowledge_bases; Type: TABLE DATA; Schema: ai; Owner: -
--



--
-- Data for Name: knowledge_documents; Type: TABLE DATA; Schema: ai; Owner: -
--



--
-- Data for Name: knowledge_segments; Type: TABLE DATA; Schema: ai; Owner: -
--



--
-- Data for Name: model_catalog; Type: TABLE DATA; Schema: ai; Owner: -
--

INSERT INTO ai.model_catalog VALUES ('DeepSeek', 'deepseek-v4-pro', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DeepSeek', 'deepseek-v4-flash', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Moonshot', 'kimi-k2.5', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Moonshot', 'kimi-k2-0711-preview', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Anthropic', 'claude-fable-5', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Anthropic', 'claude-opus-4-8', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Anthropic', 'claude-sonnet-5', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Anthropic', 'claude-haiku-4-5', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('OpenAI', 'gpt-5.6-sol', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('OpenAI', 'gpt-5.6-terra', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('OpenAI', 'gpt-5.6-luna', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('OpenAI', 'gpt-image-2', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('OpenAI', 'gpt-audio-1.5', 'speech', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('OpenAI', 'gpt-4o-transcribe', 'transcription', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('OpenAI', 'text-embedding-3-small', 'embedding', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('OpenAI', 'text-embedding-3-large', 'embedding', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('TongYi', 'qwen-max', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('TongYi', 'qwen-plus', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('TongYi', 'qwen-turbo', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('TongYi', 'text-embedding-v4', 'embedding', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('TongYi', 'qwen3-vl-embedding', 'embedding', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('TongYi', 'qwen3-rerank', 'rerank', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('TongYi', 'qwen3-vl-rerank', 'rerank', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('TongYi', 'gte-rerank-v2', 'rerank', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('ZhiPu', 'glm-5.1', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('ZhiPu', 'glm-5v-turbo', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('ZhiPu', 'glm-image', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('ZhiPu', 'cogvideox-3', 'video', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('ZhiPu', 'glm-tts', 'speech', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('ZhiPu', 'glm-asr-2512', 'transcription', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('ZhiPu', 'embedding-3', 'embedding', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Gemini', 'gemini-3.5-flash', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Gemini', 'gemini-3.1-pro-preview', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Gemini', 'gemini-3.1-flash-image', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Gemini', 'veo-3.1-preview', 'video', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Gemini', 'gemini-3.1-flash-tts-preview', 'speech', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Gemini', 'lyria-3-pro-preview', 'music', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Gemini', 'gemini-embedding-2', 'embedding', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('MiniMax', 'MiniMax-M2.7', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('MiniMax', 'image-01', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('MiniMax', 'MiniMax-Hailuo-2.3', 'video', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('MiniMax', 'speech-2.8-hd', 'speech', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('MiniMax', 'music-2.6', 'music', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Suno', 'V4', 'music', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Suno', 'V4_5', 'music', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Suno', 'V5', 'music', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Grok', 'grok-4.5', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Grok', 'grok-4.3', 'chat', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Grok', 'grok-imagine-image-quality', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Grok', 'grok-imagine-video', 'video', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('StableDiffusion', 'stable-image-ultra', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('StableDiffusion', 'stable-image-core', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('StableDiffusion', 'sd3.5-large', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Midjourney', 'midjourney-v8.1', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Midjourney', 'midjourney-v7', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('Midjourney', 'niji-7', 'image', 'preset', '', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedream-5-0-lite-260128', 'image', 'preset', 'https://www.volcengine.com/docs/82379/1541523', true, 0, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-128k-240428', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-128k-240515', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-4k-240328', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-32k-240428', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-4k-240515', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-4k-character-240515', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-embedding-text-240515', 'embedding', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'mistral-7b-instruct-v0.2', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-4k-character-240515', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-4k-functioncall-240515', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-4k-pretrain-character-240516', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-character-240528', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-4k-browsing-240524', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-functioncall-240515', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-4k-functioncall-240615', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-browsing-240615', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-240615', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-32k-240628', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-128k-240628', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-embedding-text-240715', 'embedding', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-4k-character-240728', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-functioncall-240815', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-240828', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-4k-character-240828', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-character-240828', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-32k-240828', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-128k-240828', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-browsing-240828', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-functioncall-preview', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-embedding-large-text-240915', 'embedding', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-32k-character-241015', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-functioncall-241028', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-browsing-241115', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-vision-pro-32k-241028', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-vision-lite-32k-241015', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seaweed-241128', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-256k-241115', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-character-241215', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-pro-32k-241215', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-lite-32k-250115', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-pro-32k-250115', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-vision-pro-32k-250115', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-embedding-vision-241215', 'embedding', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-pro-256k-250115', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-v3-241226', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-r1-distill-qwen-7b-250120', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-r1-distill-qwen-32b-250120', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-r1-250120', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-pro-32k-character-250228', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1.5-vision-lite-250315', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-v3-250324', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1.5-vision-pro-250328', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-lite-32k-character-250228', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1.5-ui-tars-250328', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-embedding-vision-250328', 'embedding', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-thinking-pro-250415', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'wan2-1-14b-i2v-250225', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'wan2-1-14b-t2v-250225', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-thinking-pro-m-250415', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedance-1-0-lite-i2v-250428', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedance-1-0-lite-t2v-250428', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedream-3-0-t2i-250415', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'wan2-1-14b-flf2v-250417', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-thinking-vision-pro-250428', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-thinking-pro-m-250428', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-embedding-large-text-250515', 'embedding', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-ui-tars-250428', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-r1-250528', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-1-6-flash-250615', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-1-6-250615', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-1-6-thinking-250615', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedance-1-0-pro-250528', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-embedding-vision-250615', 'embedding', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-1-6-thinking-250715', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-1-5-pro-32k-character-250715', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seededit-3-0-i2i-250628', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-1-6-flash-250715', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'kimi-k2-250711', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-1-6-vision-250815', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-v3-1-250821', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-1-6-flash-250828', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'glm-4-5-air-20250728', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'qwen3-8b-20250429', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'qwen3-32b-20250429', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'qwen2-5-72b-20240919', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedream-4-0-250828', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'kimi-k2-250905', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-translation-250915', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-v3-1-terminus', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-smart-router-250928', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-1-6-251015', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedance-1-0-pro-fast-251015', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-1-6-lite-251015', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed3d-1-0-250928', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'kimi-k2-thinking-251104', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-code-preview-251028', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'qwen3-0-6b-20250429', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'qwen3-14b-20250429', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedream-4-5-251128', 'image', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-embedding-vision-251215', 'embedding', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-v3-2-251201', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedance-1-5-pro-251215', 'video', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'glm-4-7-251222', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-1-8-251228', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-character-251128', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-2-0-lite-260215', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedance-2-0-260128', 'video', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedream-5-0-260128', 'image', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-2-0-mini-260215', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-2-0-pro-260215', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedance-2-0-fast-260128', 'video', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-2-0-code-preview-260215', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'hyper3d-gen2-260112', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'hitem3d-2-0-251223', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed3d-2-0-260328', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-2-0-mini-260428', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-2-0-lite-260428', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-v4-pro-260425', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'deepseek-v4-flash-260425', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedance-2-0-mini-260615', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-2-1-pro-260628', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-2-1-turbo-260628', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-character-260628', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seed-evolving', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'glm-5-2-260617', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);
INSERT INTO ai.model_catalog VALUES ('DouBao', 'doubao-seedream-5-0-pro-260628', 'chat', 'discover', 'https://ark.cn-beijing.volces.com/api/v3/models', true, 1784249634400, 0, NULL);


--
-- Data for Name: model_configs; Type: TABLE DATA; Schema: ai; Owner: -
--

INSERT INTO ai.model_configs VALUES (1784249635985, '豆包 · doubao-seedance-2-0-260128', 'doubao-doubao-seedance-2-0-260128', 'DouBao', 'video', 'doubao-seedance-2-0-260128', '', 'https://ark.cn-beijing.volces.com/api/v3', 0, 'null', 1784249635985, 1784249635985);


--
-- Data for Name: model_platforms; Type: TABLE DATA; Schema: ai; Owner: -
--

INSERT INTO ai.model_platforms VALUES ('TongYi', '通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1', '{chat,image,video,speech,embedding,rerank}', true, 0);
INSERT INTO ai.model_platforms VALUES ('YiYan', '文心一言', 'https://qianfan.baidubce.com/v2', '{chat}', true, 0);
INSERT INTO ai.model_platforms VALUES ('DeepSeek', 'DeepSeek', 'https://api.deepseek.com', '{chat}', true, 0);
INSERT INTO ai.model_platforms VALUES ('ZhiPu', '智谱清言', 'https://open.bigmodel.cn/api/paas/v4', '{chat,image,video,speech,transcription,embedding}', true, 0);
INSERT INTO ai.model_platforms VALUES ('XingHuo', '讯飞星火', 'https://spark-api-open.xf-yun.com/v1', '{chat}', true, 0);
INSERT INTO ai.model_platforms VALUES ('DouBao', '豆包', 'https://ark.cn-beijing.volces.com/api/v3', '{chat,image,video,speech,transcription,embedding}', true, 0);
INSERT INTO ai.model_platforms VALUES ('HunYuan', '腾讯混元', 'https://api.hunyuan.cloud.tencent.com/v1', '{chat}', true, 0);
INSERT INTO ai.model_platforms VALUES ('SiliconFlow', '硅基流动', 'https://api.siliconflow.cn/v1', '{chat,image,video,speech,embedding,rerank}', true, 0);
INSERT INTO ai.model_platforms VALUES ('MiniMax', 'MiniMax', 'https://api.minimax.chat/v1', '{chat,image,video,speech,music}', true, 0);
INSERT INTO ai.model_platforms VALUES ('Moonshot', 'Kimi', 'https://api.moonshot.cn/v1', '{chat}', true, 0);
INSERT INTO ai.model_platforms VALUES ('BaiChuan', '百川智能', 'https://api.baichuan-ai.com/v1', '{chat}', true, 0);
INSERT INTO ai.model_platforms VALUES ('StepFun', '阶跃星辰', 'https://api.stepfun.com/v1', '{chat,image,speech,transcription}', true, 0);
INSERT INTO ai.model_platforms VALUES ('OpenAI', 'OpenAI 官方', 'https://api.openai.com/v1', '{chat,image,video,speech,transcription,embedding}', true, 0);
INSERT INTO ai.model_platforms VALUES ('AzureOpenAI', '微软 Azure（OpenAI）', '', '{chat}', true, 0);
INSERT INTO ai.model_platforms VALUES ('Anthropic', 'Claude', 'https://api.anthropic.com/v1', '{chat}', true, 0);
INSERT INTO ai.model_platforms VALUES ('Gemini', 'Gemini', 'https://generativelanguage.googleapis.com/v1beta', '{chat,image,video,speech,music,embedding}', true, 0);
INSERT INTO ai.model_platforms VALUES ('Ollama', 'Ollama 本地模型', 'http://127.0.0.1:11434/v1', '{chat,embedding}', true, 0);
INSERT INTO ai.model_platforms VALUES ('StableDiffusion', 'Stable Diffusion', 'https://api.stability.ai', '{image}', true, 0);
INSERT INTO ai.model_platforms VALUES ('Midjourney', 'Midjourney', '', '{image}', true, 0);
INSERT INTO ai.model_platforms VALUES ('Suno', 'Suno 音乐', '', '{music}', true, 0);
INSERT INTO ai.model_platforms VALUES ('Grok', 'Grok', 'https://api.x.ai/v1', '{chat,image,video,speech,transcription}', true, 0);
INSERT INTO ai.model_platforms VALUES ('OpenAICompatible', 'OpenAI 兼容平台', '', '{chat,image,video,speech,transcription,music,embedding,rerank}', true, 0);


--
-- Data for Name: music; Type: TABLE DATA; Schema: ai; Owner: -
--



--
-- Data for Name: tools; Type: TABLE DATA; Schema: ai; Owner: -
--

INSERT INTO ai.tools VALUES (1, 'current_time', '获取指定时区的当前时间', 1, '{"type": "object", "required": ["utcOffset"], "properties": {"utcOffset": {"type": "string"}}}', '{"kind": "builtin"}', 0, 0);
INSERT INTO ai.tools VALUES (2, 'weather_query', '查询指定地点的天气', 1, '{"type": "object", "required": ["location"], "properties": {"location": {"type": "string"}}}', '{"kind": "builtin"}', 0, 0);


--
-- Data for Name: writes; Type: TABLE DATA; Schema: ai; Owner: -
--



--
-- Data for Name: assets; Type: TABLE DATA; Schema: media; Owner: -
--



--
-- Data for Name: _sqlx_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public._sqlx_migrations VALUES (1, 'init', '2026-07-16 04:33:02.723511+00', true, '\x75a4d51396dd4f58758170d3e3489cc7bf0fcfad5155cc7802b93289945440dbdf9a40f49cb9fc2b05c0178175804ba3', 39073838);
INSERT INTO public._sqlx_migrations VALUES (2, 'auth sessions', '2026-07-16 04:33:02.771597+00', true, '\x66d2973ac856bd77dc7a8544474833a903d5a8ce8cd3e3067f69f406832d7456fdbf50dae1a010eda8462203fa255d65', 11089527);
INSERT INTO public._sqlx_migrations VALUES (3, 'audit logs', '2026-07-16 04:33:02.790859+00', true, '\xdb648a931ed7b280d89b53ad665d58f52cbc77758d771c390b54aa2ac3a34ffd04647d4afa88ff1b846815bfabac5c32', 12039671);
INSERT INTO public._sqlx_migrations VALUES (4, 'toon media business', '2026-07-16 04:33:02.811578+00', true, '\x50ae0194f8d342d132bd479478c0df00ee18fb17695d78e499defed324bdb7c02585f6fbf7a60164abe22c37b9baebe9', 10811085);
INSERT INTO public._sqlx_migrations VALUES (5, 'system management items', '2026-07-16 04:33:02.832078+00', true, '\x19c97154c5e840b259c188fd9f5d6e7261f099b52bba39d41ab57915f5e8033423db56e5035e1f795e4936f594284b3e', 13528709);
INSERT INTO public._sqlx_migrations VALUES (6, 'system saas permissions', '2026-07-16 04:33:02.852032+00', true, '\x66239603dde39a3cef1e8675038bfd28cc6de69ea394addc7d7d6b6dc243dab1e01a8b56ece6c63576c4eaf74c07ebb4', 9912789);
INSERT INTO public._sqlx_migrations VALUES (7, 'system core tables', '2026-07-16 04:33:02.870134+00', true, '\xe5f93dac8c3beb9708a4576afcf068b2091c4451e3be5b7ef38fc9cbbb18cb78884abfede7eed6a85648365ae47974cf', 37301616);
INSERT INTO public._sqlx_migrations VALUES (8, 'system user profiles', '2026-07-16 04:33:02.915456+00', true, '\xb161ab147e16996687aae2c251c0ce26597fe29394dfe3b05396a3471dd4d5f9b1340e7cb3e4e399946798db13228cf6', 11189187);
INSERT INTO public._sqlx_migrations VALUES (9, 'prune yudao menus', '2026-07-16 04:33:02.934882+00', true, '\xb9bb7e69cf0d0cbde2b0c75cdb7ed38a3cce2958bde6f2d38172d39c9c89a8296dc9823b0ca0cd5e2c17cb1e6914dd90', 14060466);
INSERT INTO public._sqlx_migrations VALUES (10, 'toonflow core', '2026-07-16 04:33:02.958964+00', true, '\x6a9b2355dc12075613d4458d7252ed15be45f8478ca15845185c6110d35c7d8af1a255e377b3efda27561aa5e45fd059', 161250740);
INSERT INTO public._sqlx_migrations VALUES (11, 'toonflow menus', '2026-07-16 04:33:03.129083+00', true, '\xe0fa944e3e6133311cd244ef7cc549b666a84febd26f508f0b3edad1069c6c55630f894850053a48f7ab852a0d7b5cb7', 13369846);
INSERT INTO public._sqlx_migrations VALUES (12, 'toonflow resource menus', '2026-07-16 04:33:03.197882+00', true, '\xf1b8345566494a437fbe80376d68337d6bef9a6cfbf20e80617ccb5bd2635c5fec55bc89158a87e8c504619b8f0d6008', 12194220);
INSERT INTO public._sqlx_migrations VALUES (13, 'toonflow creative manuals', '2026-07-16 04:33:03.258577+00', true, '\xd7b3ea170c92270fd0d7c861de89228271f040899bad01ccc87321f18c6eaad47681cf1fb8f5cae6d5820b4d2095af14', 24233430);
INSERT INTO public._sqlx_migrations VALUES (14, 'toonflow vendor model map', '2026-07-16 04:33:03.291578+00', true, '\x1d609a9c9fdcf465bdb2f7ae2990e370fc1d13796f72247680f035ea8622121cf9a69bfc49a301b4303f0a152a7b28a8', 10815349);
INSERT INTO public._sqlx_migrations VALUES (15, 'toonflow audio', '2026-07-16 04:33:03.31158+00', true, '\x94b95dbb224857a706c6deceefa047a6ea098a03a3a5e78ba7273211299662632a534f5cf9416ef43792cb3f5ceb48db', 12900430);
INSERT INTO public._sqlx_migrations VALUES (16, 'toonflow agents', '2026-07-16 04:33:03.333295+00', true, '\x6c6a45de4473d43ddd55889b0465cbe35f5210cd9f2105a10a5877b6aef018dbe007e8ecb4507ecde0de8c2275bba55c', 23040722);
INSERT INTO public._sqlx_migrations VALUES (17, 'toonflow agent tools', '2026-07-16 04:33:03.364322+00', true, '\x845e7e91d234a0ca63472f71ada9436600924ceb040434e3d543b530909c01651d0b42aad139221c6fc79287a3c0a633', 12009843);
INSERT INTO public._sqlx_migrations VALUES (18, 'toonflow agent events', '2026-07-16 04:33:03.383372+00', true, '\x31254b7089dab492b921ae0d1b823973c7bd6be045462618ad052dccb99b91ead9f758047c5bade44320420689d7a74f', 22295577);
INSERT INTO public._sqlx_migrations VALUES (19, 'ai model', '2026-07-16 04:33:03.414195+00', true, '\xf68513fecc8a0ddd1a65af4eb85484dc1806805b0cf7fe4747d7fba76e573cc3a5935ebc34a2c3da573990592fa4827e', 22956383);
INSERT INTO public._sqlx_migrations VALUES (20, 'toonflow unified ai', '2026-07-16 04:33:03.44507+00', true, '\x8467644271b9242f376416d3a4558b510ab09836eaecb89e7904355292303be1dffe2adaf47be8ec943d23d03099856c', 14876761);
INSERT INTO public._sqlx_migrations VALUES (21, 'ai chat', '2026-07-16 04:33:03.468971+00', true, '\x4d5c55146282f165078863cbd5fc7148a426552cb05179122af01ae027ac246ceca20f2f104ae4293f6a0ded60063d27', 22534423);
INSERT INTO public._sqlx_migrations VALUES (22, 'ai tools', '2026-07-16 04:33:03.500566+00', true, '\xf9e5b5ed4b4a2fe42ba970e25dcbba242305737f7a67f77b073c517a344e6219ca178f68b7a9e9968cb235b3159685d9', 19945211);
INSERT INTO public._sqlx_migrations VALUES (23, 'ai media write', '2026-07-16 04:33:03.527573+00', true, '\x19d958dcf15451a680964f0d3bc35e2ed76fa9f2c04774c45029e6432f3a3965173cebce55cbcb81fe3f0d909cca75c3', 23910967);
INSERT INTO public._sqlx_migrations VALUES (24, 'ai knowledge', '2026-07-16 04:33:03.560747+00', true, '\xe6717726ce5aa42baf1362b17eda136daaf34f014c382b94cafbac24f54e9bc1912054aeb988f9218e797a1ce116932d', 29157214);
INSERT INTO public._sqlx_migrations VALUES (25, 'remove toonflow legacy ai', '2026-07-16 04:33:03.599469+00', true, '\x975dbb66a335ca135af8e31ce7e16d7a54a44ab8db1bfd03154847d916d41717689c34e6b67b4693e2cb578516f125af', 18983950);
INSERT INTO public._sqlx_migrations VALUES (26, 'ai music polling', '2026-07-16 04:33:03.628111+00', true, '\xc58f1dcfdf64c6b0d5c246cd25274caab6fd17af06a52f456a69d40f530678d7db55162d49cf5f83f99758c09bd90218', 14942281);
INSERT INTO public._sqlx_migrations VALUES (27, 'ai midjourney', '2026-07-16 04:33:03.650255+00', true, '\x6242d8dba593ea3f94b1094534400f21759b84a8c872c3ec264d79ab4ea005d778744d461cb9a98e4f78e04e042922ab', 9921732);
INSERT INTO public._sqlx_migrations VALUES (28, 'ai chat knowledge', '2026-07-16 04:33:03.667724+00', true, '\xbe4f17b9b2b7aa5a017a1d442b4f9c48349635bbff74f4914eec14d3c8b843f1a47a746bd9f642217a96008c4f64e9d0', 10668161);
INSERT INTO public._sqlx_migrations VALUES (29, 'ai chat roles', '2026-07-16 04:33:03.685228+00', true, '\xfcc2a7b8512ef6d03116c5edfab20bd24e695668cabbba4e9fa191d8ad9a5e2633f0c028d15063d4cad837ea68a9f3c8', 16022166);
INSERT INTO public._sqlx_migrations VALUES (30, 'ai permissions menus', '2026-07-16 04:33:03.71024+00', true, '\x42d02bbb7557cf01c58c9a3cb4621ca9cff3bfb4e87c6dd2d6488bb78d532b75008b736a054133f97972d23e719082ca', 9920304);
INSERT INTO public._sqlx_migrations VALUES (31, 'remove legacy system storage', '2026-07-16 05:29:59.591886+00', true, '\x833e237dd88aea8051e714886ba7b8434fdb0f1573a5bcdbc33649411a0ef1c903c1870998b05ca6c11b52ae71febd78', 30634679);
INSERT INTO public._sqlx_migrations VALUES (32, 'use yudao tokens and logs', '2026-07-16 05:41:34.124219+00', true, '\x69af11882ba8a4f88a9f239fe2867f60a8d869add68b5d5854d0c3f15dd2a7ac0489d51820ac081dddb108c3914ed73a', 11902261);
INSERT INTO public._sqlx_migrations VALUES (33, 'allow jwt oauth2 access tokens', '2026-07-16 05:44:38.29753+00', true, '\x89f76f4e36e742eb4c48bb8faa682c04926953bae609d180d453047599cf7db453c8b17c0eae81df9b9a64a4e4bda069', 18968770);
INSERT INTO public._sqlx_migrations VALUES (34, 'index jwt access token hash', '2026-07-16 05:47:36.030159+00', true, '\xea9517663df81d09532757fceb535a4cc319c475599770a356be3f8faab99a603642777882b01d3993ff11ba8cfdeb57', 8384204);
INSERT INTO public._sqlx_migrations VALUES (35, 'sync yudao user posts', '2026-07-16 06:02:21.121236+00', true, '\x4ab5135c0fc56e99476aca4599b90ee9cfbd3f8232884a34bd01db8180f30aacc64532947df0fa74026ede72cf10fbdf', 9460432);
INSERT INTO public._sqlx_migrations VALUES (36, 'align yudao system sequences', '2026-07-16 06:11:02.990461+00', true, '\x5a08484d7d9c185c4e406284c61fd556ab336da73ae52ae5f5ac5442f0c60ab41c35fb7d080380e39b847c03ee8116bc', 29565336);
INSERT INTO public._sqlx_migrations VALUES (37, 'infra tables', '2026-07-16 07:19:26.62877+00', true, '\xbfde070d2327b8bee71f0938ba4cb6ae0990a5d1fc1bf869059aa652bd57e460d3f93dde667e13eca24ef50e59e19cdb', 49145149);
INSERT INTO public._sqlx_migrations VALUES (38, 'scrub sensitive seed', '2026-07-16 07:29:32.31865+00', true, '\x33445a702b9d287ccac21ceef68a17f017e6298bd3f62eb2a20126ddca1fc07b0ac1b106ed615556b862d3ad6155e972', 28085219);
INSERT INTO public._sqlx_migrations VALUES (39, 'performance indexes', '2026-07-16 07:38:11.921865+00', true, '\x6febc2510b0dd7282527465a9b6af30332d5c609acc2c396cc721e3c3755a517e5af8e61133e34325b2bcb0b4792bfbf', 13518621);
INSERT INTO public._sqlx_migrations VALUES (40, 'scrub remote yudao media urls', '2026-07-16 08:09:08.864335+00', true, '\xda93bdb5309faae5272dbe6251a0e68205f3298d27c52b25b6f5c46bad35b1f93a8cb89e4cd436a1e338b47a9135527d', 9586715);
INSERT INTO public._sqlx_migrations VALUES (41, 'disable duplicate ai route menus', '2026-07-16 08:12:35.316268+00', true, '\x51b20a8a2eb6e59ecbb1dc10ebe87c92d1be1c9d288e8347e4de0cc073371363d8e0d8a0d7fed40b1c13ba5dec699dab', 7386480);
INSERT INTO public._sqlx_migrations VALUES (42, 'toonflow video track order', '2026-07-16 09:12:40.005436+00', true, '\xe8759abdbba8df9642971d7cc759b4afa5af70e144acadab30ed9239345854c015cc36da50a01ffa853ad63f9e4428b3', 34449382);
INSERT INTO public._sqlx_migrations VALUES (43, 'toonflow video time bigint', '2026-07-16 09:17:03.430162+00', true, '\xf755db3e0f6001318ea062f9ca090c9d2aff005c99c8fba5c50f7fca71b76fd38feb9f72b70d4fa76427ba64b8f91c67', 21847726);
INSERT INTO public._sqlx_migrations VALUES (44, 'ai model catalog', '2026-07-16 10:52:52.33751+00', true, '\x242255685a8815dfeb018047f471796cdd1170cf798dbd4825e16831bd5c2af3bc8151e0ac84f6de206426a46db4c983', 49064433);
INSERT INTO public._sqlx_migrations VALUES (45, 'ai model catalog validation', '2026-07-16 10:52:52.39164+00', true, '\xbd56dcc72ea5a50d5241555ef6a39d7d156eb6bf88cde14a54ed75e97b9e17bdb175d2171894d742cd5faec05c4bae4c', 8980738);
INSERT INTO public._sqlx_migrations VALUES (46, 'doubao seedance seedream', '2026-07-17 00:51:31.239115+00', true, '\x44cec0d9d1c8b68470349676483a682248cf98e34e985a9a5295e9b1e8219734dfbaab575fe20c9f730e35ee24d9920d', 10337681);


--
-- Data for Name: infra_api_access_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: infra_api_error_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: infra_codegen_column; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.infra_codegen_column VALUES (1, 1, 'id', 'bigint', 'id', false, true, 1, 'Long', 'id', true, true, true, true, 'input', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (2, 1, 'category', 'character varying', 'category', false, false, 2, 'String', 'category', true, true, true, true, 'input', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (3, 1, 'type', 'smallint', 'type', false, false, 3, 'Integer', 'type', true, true, true, true, 'input', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (4, 1, 'name', 'character varying', 'name', false, false, 4, 'String', 'name', true, true, true, true, 'input', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (5, 1, 'config_key', 'character varying', 'config_key', false, false, 5, 'String', 'configKey', true, true, true, true, 'input', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (6, 1, 'value', 'character varying', 'value', false, false, 6, 'String', 'value', true, true, true, true, 'input', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (7, 1, 'visible', 'boolean', 'visible', false, false, 7, 'Boolean', 'visible', true, true, true, true, 'radio', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (8, 1, 'remark', 'character varying', 'remark', true, false, 8, 'String', 'remark', true, true, true, true, 'input', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (9, 1, 'creator', 'character varying', 'creator', false, false, 9, 'String', 'creator', true, true, true, true, 'input', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (10, 1, 'create_time', 'timestamp without time zone', 'create_time', false, false, 10, 'LocalDateTime', 'createTime', true, true, true, true, 'datetime', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (11, 1, 'updater', 'character varying', 'updater', false, false, 11, 'String', 'updater', true, true, true, true, 'input', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (12, 1, 'update_time', 'timestamp without time zone', 'update_time', false, false, 12, 'LocalDateTime', 'updateTime', true, true, true, true, 'datetime', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (13, 1, 'deleted', 'smallint', 'deleted', false, false, 13, 'Integer', 'deleted', true, true, true, true, 'input', '', '2026-07-16 07:30:13.363579', '', '2026-07-16 07:30:13.521669', 1);
INSERT INTO public.infra_codegen_column VALUES (14, 1, 'id', 'bigint', 'id', false, true, 1, 'Long', 'id', true, true, true, true, 'input', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (15, 1, 'category', 'character varying', 'category', false, false, 2, 'String', 'category', true, true, true, true, 'input', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (16, 1, 'type', 'smallint', 'type', false, false, 3, 'Integer', 'type', true, true, true, true, 'input', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (17, 1, 'name', 'character varying', 'name', false, false, 4, 'String', 'name', true, true, true, true, 'input', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (18, 1, 'config_key', 'character varying', 'config_key', false, false, 5, 'String', 'configKey', true, true, true, true, 'input', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (19, 1, 'value', 'character varying', 'value', false, false, 6, 'String', 'value', true, true, true, true, 'input', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (20, 1, 'visible', 'boolean', 'visible', false, false, 7, 'Boolean', 'visible', true, true, true, true, 'radio', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (21, 1, 'remark', 'character varying', 'remark', true, false, 8, 'String', 'remark', true, true, true, true, 'input', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (22, 1, 'creator', 'character varying', 'creator', false, false, 9, 'String', 'creator', true, true, true, true, 'input', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (23, 1, 'create_time', 'timestamp without time zone', 'create_time', false, false, 10, 'LocalDateTime', 'createTime', true, true, true, true, 'datetime', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (24, 1, 'updater', 'character varying', 'updater', false, false, 11, 'String', 'updater', true, true, true, true, 'input', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (25, 1, 'update_time', 'timestamp without time zone', 'update_time', false, false, 12, 'LocalDateTime', 'updateTime', true, true, true, true, 'datetime', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);
INSERT INTO public.infra_codegen_column VALUES (26, 1, 'deleted', 'smallint', 'deleted', false, false, 13, 'Integer', 'deleted', true, true, true, true, 'input', '', '2026-07-16 07:30:13.521669', '', '2026-07-16 07:30:13.521669', 0);


--
-- Data for Name: infra_codegen_table; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.infra_codegen_table VALUES (1, 0, 1, 'infra_config', 'infra_config', 'infra', 'config', 'InfraConfig', 'infra_config', 'admin', 1, 20, NULL, '', '2026-07-16 07:30:13.35742', '', '2026-07-16 07:30:13.35742', 0);


--
-- Data for Name: infra_config; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.infra_config VALUES (1, 'test', 1, 'Codex Test2', 'codex.test.updated.1784190150145', '2', true, 'smoke', '', '2026-07-16 08:22:29.993205', '', '2026-07-16 08:22:30.328864', 1);
INSERT INTO public.infra_config VALUES (2, 'test', 1, 'Codex Test2', 'codex.test.updated.1784190297896', '2', true, 'smoke', '', '2026-07-16 08:24:57.790394', '', '2026-07-16 08:24:58.074263', 1);


--
-- Data for Name: infra_data_source_config; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.infra_data_source_config VALUES (1, 'Codex DS2', 'jdbc:postgresql://localhost/test2', 'u2', 'enc:v1:QA==', '', '2026-07-16 08:22:30.56435', '', '2026-07-16 08:22:30.951151', 1);
INSERT INTO public.infra_data_source_config VALUES (2, 'Codex DS2', 'jdbc:postgresql://localhost/test2', 'u2', 'enc:v1:QA==', '', '2026-07-16 08:24:58.257105', '', '2026-07-16 08:24:58.52636', 1);


--
-- Data for Name: infra_file; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.infra_file VALUES (1, NULL, 'upload-1784190151596', '/upload/upload-1784190151596', '/upload/upload-1784190151596', 'application/octet-stream', 0, '', '2026-07-16 08:22:31.598394', '', '2026-07-16 08:22:31.811991', 1);
INSERT INTO public.infra_file VALUES (2, NULL, 'hello.txt', '/upload/20260716/1784190299062_hello.txt', '/upload/20260716/1784190299062_hello.txt', 'text/plain', 11, '', '2026-07-16 08:24:59.066129', '', '2026-07-16 08:24:59.323691', 1);
INSERT INTO public.infra_file VALUES (3, NULL, 'hello.txt', '/upload/20260716/1784190421868_hello.txt', '/upload/20260716/1784190421868_hello.txt', 'text/plain', 11, '', '2026-07-16 08:27:01.871695', '', '2026-07-16 08:27:02.075376', 1);


--
-- Data for Name: infra_file_config; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.infra_file_config VALUES (1, 'Codex Local', 10, true, '{"basePath":"/tmp/rust-toon-upload"}', 'smoke', '', '2026-07-16 08:22:31.17725', '', '2026-07-16 08:22:31.911776', 1);
INSERT INTO public.infra_file_config VALUES (2, 'Codex Local', 10, true, '{"basePath":"storage/uploads"}', 'smoke', '', '2026-07-16 08:24:58.710186', '', '2026-07-16 08:24:59.430503', 1);
INSERT INTO public.infra_file_config VALUES (3, 'Codex Local Final', 10, false, '{"basePath":"storage/uploads"}', 'smoke', '', '2026-07-16 08:27:01.760067', '', '2026-07-16 08:27:02.170941', 1);


--
-- Data for Name: infra_job; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.infra_job VALUES (1, 'Codex Job2', 0, 'codexHandler', '{}', '0 0/10 * * * ?', 1, 1, 10, '', '2026-07-16 08:22:32.197157', '', '2026-07-16 08:22:32.899056', 1);
INSERT INTO public.infra_job VALUES (2, 'Codex Job2', 1, 'codexHandler', '{}', '0 0/10 * * * ?', 1, 1, 10, '', '2026-07-16 08:24:59.610099', '', '2026-07-16 08:25:00.250999', 1);
INSERT INTO public.infra_job VALUES (3, 'Codex Job Final', 1, 'codexHandler', '{}', '0 0/10 * * * ?', 0, 0, 0, '', '2026-07-16 08:27:02.268192', '', '2026-07-16 08:27:02.541902', 1);


--
-- Data for Name: infra_job_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_dept; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_dept VALUES (100, '芋道源码', 0, 0, 1, '15888888888', 'ry@qq.com', 0, 'admin', '2021-01-05 17:03:47', '1', '2026-01-04 18:01:12', 0, 1);
INSERT INTO public.system_dept VALUES (101, '深圳总公司', 100, 1, 104, '15888888888', 'ry@qq.com', 0, 'admin', '2021-01-05 17:03:47', '1', '2025-03-29 15:49:55', 0, 1);
INSERT INTO public.system_dept VALUES (102, '长沙分公司', 100, 2, NULL, '15888888888', 'ry@qq.com', 0, 'admin', '2021-01-05 17:03:47', '', '2021-12-15 05:01:40', 0, 1);
INSERT INTO public.system_dept VALUES (103, '研发部门', 101, 1, 104, '15888888888', 'ry@qq.com', 0, 'admin', '2021-01-05 17:03:47', '1', '2026-01-04 18:01:24', 0, 1);
INSERT INTO public.system_dept VALUES (104, '市场部门', 101, 2, NULL, '15888888888', 'ry@qq.com', 0, 'admin', '2021-01-05 17:03:47', '', '2021-12-15 05:01:38', 0, 1);
INSERT INTO public.system_dept VALUES (105, '测试部门', 101, 3, NULL, '15888888888', 'ry@qq.com', 0, 'admin', '2021-01-05 17:03:47', '1', '2022-05-16 20:25:15', 0, 1);
INSERT INTO public.system_dept VALUES (106, '财务部门', 101, 4, 103, '15888888888', 'ry@qq.com', 0, 'admin', '2021-01-05 17:03:47', '103', '2022-01-15 21:32:22', 0, 1);
INSERT INTO public.system_dept VALUES (107, '运维部门', 101, 5, 1, '15888888888', 'ry@qq.com', 0, 'admin', '2021-01-05 17:03:47', '1', '2023-12-02 09:28:22', 0, 1);
INSERT INTO public.system_dept VALUES (108, '市场部门', 102, 1, NULL, '15888888888', 'ry@qq.com', 0, 'admin', '2021-01-05 17:03:47', '1', '2022-02-16 08:35:45', 0, 1);
INSERT INTO public.system_dept VALUES (109, '财务部门', 102, 2, NULL, '15888888888', 'ry@qq.com', 0, 'admin', '2021-01-05 17:03:47', '', '2021-12-15 05:01:29', 0, 1);
INSERT INTO public.system_dept VALUES (110, '新部门', 0, 1, NULL, NULL, NULL, 0, '110', '2022-02-23 20:46:30', '110', '2022-02-23 20:46:30', 0, 121);
INSERT INTO public.system_dept VALUES (111, '顶级部门', 0, 1, NULL, NULL, NULL, 0, '113', '2022-03-07 21:44:50', '113', '2022-03-07 21:44:50', 0, 122);
INSERT INTO public.system_dept VALUES (112, '产品部门', 101, 100, 1, NULL, NULL, 1, '1', '2023-12-02 09:45:13', '1', '2023-12-02 09:45:31', 0, 1);
INSERT INTO public.system_dept VALUES (113, '支持部门', 102, 3, 104, NULL, NULL, 1, '1', '2023-12-02 09:47:38', '1', '2025-03-29 15:00:56', 0, 1);
INSERT INTO public.system_dept VALUES (116, '某个子部门', 0, 1, NULL, NULL, NULL, 0, '1', '2025-12-08 14:51:12', '1', '2025-12-08 14:51:12', 0, 1);
INSERT INTO public.system_dept VALUES (117, '某个子部门 2', 0, 2, NULL, NULL, NULL, 0, '1', '2025-12-08 14:51:25', '1', '2025-12-08 14:51:25', 0, 1);


--
-- Data for Name: system_dict_data; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_dict_data VALUES (1, 1, '男', '1', 'system_user_sex', 0, 'primary', 'A', '性别男', 'admin', '2021-01-05 17:03:48', '1', '2025-12-10 13:19:26', 0);
INSERT INTO public.system_dict_data VALUES (2, 2, '女', '2', 'system_user_sex', 0, 'success', '', '性别女', 'admin', '2021-01-05 17:03:48', '1', '2023-11-15 23:30:37', 0);
INSERT INTO public.system_dict_data VALUES (8, 1, '正常', '1', 'infra_job_status', 0, 'success', '', '正常状态', 'admin', '2021-01-05 17:03:48', '1', '2022-02-16 19:33:38', 0);
INSERT INTO public.system_dict_data VALUES (9, 2, '暂停', '2', 'infra_job_status', 0, 'danger', '', '停用状态', 'admin', '2021-01-05 17:03:48', '1', '2022-02-16 19:33:45', 0);
INSERT INTO public.system_dict_data VALUES (12, 1, '系统内置', '1', 'infra_config_type', 0, 'danger', '', '参数类型 - 系统内置', 'admin', '2021-01-05 17:03:48', '1', '2022-02-16 19:06:02', 0);
INSERT INTO public.system_dict_data VALUES (13, 2, '自定义', '2', 'infra_config_type', 0, 'primary', '', '参数类型 - 自定义', 'admin', '2021-01-05 17:03:48', '1', '2022-02-16 19:06:07', 0);
INSERT INTO public.system_dict_data VALUES (14, 1, '通知', '1', 'system_notice_type', 0, 'success', '', '通知', 'admin', '2021-01-05 17:03:48', '1', '2022-02-16 13:05:57', 0);
INSERT INTO public.system_dict_data VALUES (15, 2, '公告', '2', 'system_notice_type', 0, 'info', '', '公告', 'admin', '2021-01-05 17:03:48', '1', '2022-02-16 13:06:01', 0);
INSERT INTO public.system_dict_data VALUES (16, 0, '其它', '0', 'infra_operate_type', 0, 'default', '', '其它操作', 'admin', '2021-01-05 17:03:48', '1', '2024-03-14 12:44:19', 0);
INSERT INTO public.system_dict_data VALUES (17, 1, '查询', '1', 'infra_operate_type', 0, 'info', '', '查询操作', 'admin', '2021-01-05 17:03:48', '1', '2024-03-14 12:44:20', 0);
INSERT INTO public.system_dict_data VALUES (18, 2, '新增', '2', 'infra_operate_type', 0, 'primary', '', '新增操作', 'admin', '2021-01-05 17:03:48', '1', '2024-03-14 12:44:21', 0);
INSERT INTO public.system_dict_data VALUES (19, 3, '修改', '3', 'infra_operate_type', 0, 'warning', '', '修改操作', 'admin', '2021-01-05 17:03:48', '1', '2024-03-14 12:44:22', 0);
INSERT INTO public.system_dict_data VALUES (20, 4, '删除', '4', 'infra_operate_type', 0, 'danger', '', '删除操作', 'admin', '2021-01-05 17:03:48', '1', '2024-03-14 12:44:23', 0);
INSERT INTO public.system_dict_data VALUES (22, 5, '导出', '5', 'infra_operate_type', 0, 'default', '', '导出操作', 'admin', '2021-01-05 17:03:48', '1', '2024-03-14 12:44:24', 0);
INSERT INTO public.system_dict_data VALUES (23, 6, '导入', '6', 'infra_operate_type', 0, 'default', '', '导入操作', 'admin', '2021-01-05 17:03:48', '1', '2024-03-14 12:44:25', 0);
INSERT INTO public.system_dict_data VALUES (27, 1, '开启', '0', 'common_status', 0, 'primary', '', '开启状态', 'admin', '2021-01-05 17:03:48', '1', '2022-02-16 08:00:39', 0);
INSERT INTO public.system_dict_data VALUES (28, 2, '关闭', '1', 'common_status', 0, 'info', '', '关闭状态', 'admin', '2021-01-05 17:03:48', '1', '2022-02-16 08:00:44', 0);
INSERT INTO public.system_dict_data VALUES (29, 1, '目录', '1', 'system_menu_type', 0, '', '', '目录', 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:43:45', 0);
INSERT INTO public.system_dict_data VALUES (30, 2, '菜单', '2', 'system_menu_type', 0, '', '', '菜单', 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:43:41', 0);
INSERT INTO public.system_dict_data VALUES (31, 3, '按钮', '3', 'system_menu_type', 0, '', '', '按钮', 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:43:39', 0);
INSERT INTO public.system_dict_data VALUES (32, 1, '内置', '1', 'system_role_type', 0, 'danger', '', '内置角色', 'admin', '2021-01-05 17:03:48', '1', '2022-02-16 13:02:08', 0);
INSERT INTO public.system_dict_data VALUES (33, 2, '自定义', '2', 'system_role_type', 0, 'primary', '', '自定义角色', 'admin', '2021-01-05 17:03:48', '1', '2022-02-16 13:02:12', 0);
INSERT INTO public.system_dict_data VALUES (34, 1, '全部数据权限', '1', 'system_data_scope', 0, '', '', '全部数据权限', 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:47:17', 0);
INSERT INTO public.system_dict_data VALUES (35, 2, '指定部门数据权限', '2', 'system_data_scope', 0, '', '', '指定部门数据权限', 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:47:18', 0);
INSERT INTO public.system_dict_data VALUES (36, 3, '本部门数据权限', '3', 'system_data_scope', 0, '', '', '本部门数据权限', 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:47:16', 0);
INSERT INTO public.system_dict_data VALUES (37, 4, '本部门及以下数据权限', '4', 'system_data_scope', 0, '', '', '本部门及以下数据权限', 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:47:21', 0);
INSERT INTO public.system_dict_data VALUES (38, 5, '仅本人数据权限', '5', 'system_data_scope', 0, '', '', '仅本人数据权限', 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:47:23', 0);
INSERT INTO public.system_dict_data VALUES (39, 0, '成功', '0', 'system_login_result', 0, 'success', '', '登陆结果 - 成功', '', '2021-01-18 06:17:36', '1', '2022-02-16 13:23:49', 0);
INSERT INTO public.system_dict_data VALUES (40, 10, '账号或密码不正确', '10', 'system_login_result', 0, 'primary', '', '登陆结果 - 账号或密码不正确', '', '2021-01-18 06:17:54', '1', '2022-02-16 13:24:27', 0);
INSERT INTO public.system_dict_data VALUES (41, 20, '用户被禁用', '20', 'system_login_result', 0, 'warning', '', '登陆结果 - 用户被禁用', '', '2021-01-18 06:17:54', '1', '2022-02-16 13:23:57', 0);
INSERT INTO public.system_dict_data VALUES (42, 30, '验证码不存在', '30', 'system_login_result', 0, 'info', '', '登陆结果 - 验证码不存在', '', '2021-01-18 06:17:54', '1', '2022-02-16 13:24:07', 0);
INSERT INTO public.system_dict_data VALUES (43, 31, '验证码不正确', '31', 'system_login_result', 0, 'info', '', '登陆结果 - 验证码不正确', '', '2021-01-18 06:17:54', '1', '2022-02-16 13:24:11', 0);
INSERT INTO public.system_dict_data VALUES (44, 100, '未知异常', '100', 'system_login_result', 0, 'danger', '', '登陆结果 - 未知异常', '', '2021-01-18 06:17:54', '1', '2022-02-16 13:24:23', 0);
INSERT INTO public.system_dict_data VALUES (45, 1, '是', 'true', 'infra_boolean_string', 0, 'danger', '', 'Boolean 是否类型 - 是', '', '2021-01-19 03:20:55', '1', '2022-03-15 23:01:45', 0);
INSERT INTO public.system_dict_data VALUES (46, 1, '否', 'false', 'infra_boolean_string', 0, 'info', '', 'Boolean 是否类型 - 否', '', '2021-01-19 03:20:55', '1', '2022-03-15 23:09:45', 0);
INSERT INTO public.system_dict_data VALUES (50, 1, '单表（增删改查）', '1', 'infra_codegen_template_type', 0, '', '', NULL, '', '2021-02-05 07:09:06', '', '2022-03-10 16:33:15', 0);
INSERT INTO public.system_dict_data VALUES (51, 2, '树表（增删改查）', '2', 'infra_codegen_template_type', 0, '', '', NULL, '', '2021-02-05 07:14:46', '', '2022-03-10 16:33:19', 0);
INSERT INTO public.system_dict_data VALUES (53, 0, '初始化中', '0', 'infra_job_status', 0, 'primary', '', NULL, '', '2021-02-07 07:46:49', '1', '2022-02-16 19:33:29', 0);
INSERT INTO public.system_dict_data VALUES (57, 0, '运行中', '0', 'infra_job_log_status', 0, 'primary', '', 'RUNNING', '', '2021-02-08 10:04:24', '1', '2022-02-16 19:07:48', 0);
INSERT INTO public.system_dict_data VALUES (58, 1, '成功', '1', 'infra_job_log_status', 0, 'success', '', NULL, '', '2021-02-08 10:06:57', '1', '2022-02-16 19:07:52', 0);
INSERT INTO public.system_dict_data VALUES (59, 2, '失败', '2', 'infra_job_log_status', 0, 'warning', '', '失败', '', '2021-02-08 10:07:38', '1', '2022-02-16 19:07:56', 0);
INSERT INTO public.system_dict_data VALUES (60, 1, '会员', '1', 'user_type', 0, 'primary', '', NULL, '', '2021-02-26 00:16:27', '1', '2022-02-16 10:22:19', 0);
INSERT INTO public.system_dict_data VALUES (61, 2, '管理员', '2', 'user_type', 0, 'success', '', NULL, '', '2021-02-26 00:16:34', '1', '2025-04-06 18:37:43', 0);
INSERT INTO public.system_dict_data VALUES (62, 0, '未处理', '0', 'infra_api_error_log_process_status', 0, 'primary', '', NULL, '', '2021-02-26 07:07:19', '1', '2022-02-16 20:14:17', 0);
INSERT INTO public.system_dict_data VALUES (63, 1, '已处理', '1', 'infra_api_error_log_process_status', 0, 'success', '', NULL, '', '2021-02-26 07:07:26', '1', '2022-02-16 20:14:08', 0);
INSERT INTO public.system_dict_data VALUES (64, 2, '已忽略', '2', 'infra_api_error_log_process_status', 0, 'danger', '', NULL, '', '2021-02-26 07:07:34', '1', '2022-02-16 20:14:14', 0);
INSERT INTO public.system_dict_data VALUES (66, 1, '阿里云', 'ALIYUN', 'system_sms_channel_code', 0, 'primary', '', NULL, '1', '2021-04-05 01:05:26', '1', '2024-07-22 22:23:25', 0);
INSERT INTO public.system_dict_data VALUES (67, 1, '验证码', '1', 'system_sms_template_type', 0, 'warning', '', NULL, '1', '2021-04-05 21:50:57', '1', '2022-02-16 12:48:30', 0);
INSERT INTO public.system_dict_data VALUES (68, 2, '通知', '2', 'system_sms_template_type', 0, 'primary', '', NULL, '1', '2021-04-05 21:51:08', '1', '2022-02-16 12:48:27', 0);
INSERT INTO public.system_dict_data VALUES (69, 0, '营销', '3', 'system_sms_template_type', 0, 'danger', '', NULL, '1', '2021-04-05 21:51:15', '1', '2022-02-16 12:48:22', 0);
INSERT INTO public.system_dict_data VALUES (70, 0, '初始化', '0', 'system_sms_send_status', 0, 'primary', '', NULL, '1', '2021-04-11 20:18:33', '1', '2022-02-16 10:26:07', 0);
INSERT INTO public.system_dict_data VALUES (71, 1, '发送成功', '10', 'system_sms_send_status', 0, 'success', '', NULL, '1', '2021-04-11 20:18:43', '1', '2022-02-16 10:25:56', 0);
INSERT INTO public.system_dict_data VALUES (72, 2, '发送失败', '20', 'system_sms_send_status', 0, 'danger', '', NULL, '1', '2021-04-11 20:18:49', '1', '2022-02-16 10:26:03', 0);
INSERT INTO public.system_dict_data VALUES (73, 3, '不发送', '30', 'system_sms_send_status', 0, 'info', '', NULL, '1', '2021-04-11 20:19:44', '1', '2022-02-16 10:26:10', 0);
INSERT INTO public.system_dict_data VALUES (74, 0, '等待结果', '0', 'system_sms_receive_status', 0, 'primary', '', NULL, '1', '2021-04-11 20:27:43', '1', '2022-02-16 10:28:24', 0);
INSERT INTO public.system_dict_data VALUES (75, 1, '接收成功', '10', 'system_sms_receive_status', 0, 'success', '', NULL, '1', '2021-04-11 20:29:25', '1', '2022-02-16 10:28:28', 0);
INSERT INTO public.system_dict_data VALUES (76, 2, '接收失败', '20', 'system_sms_receive_status', 0, 'danger', '', NULL, '1', '2021-04-11 20:29:31', '1', '2022-02-16 10:28:32', 0);
INSERT INTO public.system_dict_data VALUES (77, 0, '调试(钉钉)', 'DEBUG_DING_TALK', 'system_sms_channel_code', 0, 'info', '', NULL, '1', '2021-04-13 00:20:37', '1', '2022-02-16 10:10:00', 0);
INSERT INTO public.system_dict_data VALUES (80, 100, '账号登录', '100', 'system_login_type', 0, 'primary', '', '账号登录', '1', '2021-10-06 00:52:02', '1', '2022-02-16 13:11:34', 0);
INSERT INTO public.system_dict_data VALUES (81, 101, '社交登录', '101', 'system_login_type', 0, 'info', '', '社交登录', '1', '2021-10-06 00:52:17', '1', '2022-02-16 13:11:40', 0);
INSERT INTO public.system_dict_data VALUES (83, 200, '主动登出', '200', 'system_login_type', 0, 'primary', '', '主动登出', '1', '2021-10-06 00:52:58', '1', '2022-02-16 13:11:49', 0);
INSERT INTO public.system_dict_data VALUES (85, 202, '强制登出', '202', 'system_login_type', 0, 'danger', '', '强制退出', '1', '2021-10-06 00:53:41', '1', '2022-02-16 13:11:57', 0);
INSERT INTO public.system_dict_data VALUES (86, 0, '病假', '1', 'bpm_oa_leave_type', 0, 'primary', '', NULL, '1', '2021-09-21 22:35:28', '1', '2022-02-16 10:00:41', 0);
INSERT INTO public.system_dict_data VALUES (87, 1, '事假', '2', 'bpm_oa_leave_type', 0, 'info', '', NULL, '1', '2021-09-21 22:36:11', '1', '2022-02-16 10:00:49', 0);
INSERT INTO public.system_dict_data VALUES (88, 2, '婚假', '3', 'bpm_oa_leave_type', 0, 'warning', '', NULL, '1', '2021-09-21 22:36:38', '1', '2022-02-16 10:00:53', 0);
INSERT INTO public.system_dict_data VALUES (112, 0, '微信 Wap 网站支付', 'wx_wap', 'pay_channel_code', 0, 'success', '', '微信 Wap 网站支付', '1', '2023-07-19 20:08:06', '1', '2023-07-19 20:09:08', 0);
INSERT INTO public.system_dict_data VALUES (113, 1, '微信公众号支付', 'wx_pub', 'pay_channel_code', 0, 'success', '', '微信公众号支付', '1', '2021-12-03 10:40:24', '1', '2023-07-19 20:08:47', 0);
INSERT INTO public.system_dict_data VALUES (114, 2, '微信小程序支付', 'wx_lite', 'pay_channel_code', 0, 'success', '', '微信小程序支付', '1', '2021-12-03 10:41:06', '1', '2023-07-19 20:08:50', 0);
INSERT INTO public.system_dict_data VALUES (115, 3, '微信 App 支付', 'wx_app', 'pay_channel_code', 0, 'success', '', '微信 App 支付', '1', '2021-12-03 10:41:20', '1', '2023-07-19 20:08:56', 0);
INSERT INTO public.system_dict_data VALUES (116, 10, '支付宝 PC 网站支付', 'alipay_pc', 'pay_channel_code', 0, 'primary', '', '支付宝 PC 网站支付', '1', '2021-12-03 10:42:09', '1', '2023-07-19 20:09:12', 0);
INSERT INTO public.system_dict_data VALUES (117, 11, '支付宝 Wap 网站支付', 'alipay_wap', 'pay_channel_code', 0, 'primary', '', '支付宝 Wap 网站支付', '1', '2021-12-03 10:42:26', '1', '2023-07-19 20:09:16', 0);
INSERT INTO public.system_dict_data VALUES (118, 12, '支付宝 App 支付', 'alipay_app', 'pay_channel_code', 0, 'primary', '', '支付宝 App 支付', '1', '2021-12-03 10:42:55', '1', '2023-07-19 20:09:20', 0);
INSERT INTO public.system_dict_data VALUES (119, 14, '支付宝扫码支付', 'alipay_qr', 'pay_channel_code', 0, 'primary', '', '支付宝扫码支付', '1', '2021-12-03 10:43:10', '1', '2023-07-19 20:09:28', 0);
INSERT INTO public.system_dict_data VALUES (120, 10, '通知成功', '10', 'pay_notify_status', 0, 'success', '', '通知成功', '1', '2021-12-03 11:02:41', '1', '2023-07-19 10:08:19', 0);
INSERT INTO public.system_dict_data VALUES (121, 20, '通知失败', '20', 'pay_notify_status', 0, 'danger', '', '通知失败', '1', '2021-12-03 11:02:59', '1', '2023-07-19 10:08:21', 0);
INSERT INTO public.system_dict_data VALUES (122, 0, '等待通知', '0', 'pay_notify_status', 0, 'info', '', '未通知', '1', '2021-12-03 11:03:10', '1', '2023-07-19 10:08:24', 0);
INSERT INTO public.system_dict_data VALUES (123, 10, '支付成功', '10', 'pay_order_status', 0, 'success', '', '支付成功', '1', '2021-12-03 11:18:29', '1', '2023-07-19 18:04:28', 0);
INSERT INTO public.system_dict_data VALUES (124, 30, '支付关闭', '30', 'pay_order_status', 0, 'info', '', '支付关闭', '1', '2021-12-03 11:18:42', '1', '2023-07-19 18:05:07', 0);
INSERT INTO public.system_dict_data VALUES (125, 0, '等待支付', '0', 'pay_order_status', 0, 'info', '', '未支付', '1', '2021-12-03 11:18:18', '1', '2023-07-19 18:04:15', 0);
INSERT INTO public.system_dict_data VALUES (600, 5, '首页', '1', 'promotion_banner_position', 0, 'warning', '', '', '1', '2023-10-11 07:45:24', '1', '2023-10-11 07:45:38', 0);
INSERT INTO public.system_dict_data VALUES (601, 4, '秒杀活动页', '2', 'promotion_banner_position', 0, 'warning', '', '', '1', '2023-10-11 07:45:24', '1', '2023-10-11 07:45:38', 0);
INSERT INTO public.system_dict_data VALUES (602, 3, '砍价活动页', '3', 'promotion_banner_position', 0, 'warning', '', '', '1', '2023-10-11 07:45:24', '1', '2023-10-11 07:45:38', 0);
INSERT INTO public.system_dict_data VALUES (603, 2, '限时折扣页', '4', 'promotion_banner_position', 0, 'warning', '', '', '1', '2023-10-11 07:45:24', '1', '2023-10-11 07:45:38', 0);
INSERT INTO public.system_dict_data VALUES (604, 1, '满减送页', '5', 'promotion_banner_position', 0, 'warning', '', '', '1', '2023-10-11 07:45:24', '1', '2023-10-11 07:45:38', 0);
INSERT INTO public.system_dict_data VALUES (1118, 0, '等待退款', '0', 'pay_refund_status', 0, 'info', '', '等待退款', '1', '2021-12-10 16:44:59', '1', '2023-07-19 10:14:39', 0);
INSERT INTO public.system_dict_data VALUES (1119, 20, '退款失败', '20', 'pay_refund_status', 0, 'danger', '', '退款失败', '1', '2021-12-10 16:45:10', '1', '2023-07-19 10:15:10', 0);
INSERT INTO public.system_dict_data VALUES (1124, 10, '退款成功', '10', 'pay_refund_status', 0, 'success', '', '退款成功', '1', '2021-12-10 16:46:26', '1', '2023-07-19 10:15:00', 0);
INSERT INTO public.system_dict_data VALUES (1127, 1, '审批中', '1', 'bpm_process_instance_status', 0, 'default', '', '流程实例的状态 - 进行中', '1', '2022-01-07 23:47:22', '1', '2024-03-16 16:11:45', 0);
INSERT INTO public.system_dict_data VALUES (1128, 2, '审批通过', '2', 'bpm_process_instance_status', 0, 'success', '', '流程实例的状态 - 已完成', '1', '2022-01-07 23:47:49', '1', '2024-03-16 16:11:54', 0);
INSERT INTO public.system_dict_data VALUES (1129, 1, '审批中', '1', 'bpm_task_status', 0, 'primary', '', '流程实例的结果 - 处理中', '1', '2022-01-07 23:48:32', '1', '2024-03-08 22:41:37', 0);
INSERT INTO public.system_dict_data VALUES (1130, 2, '审批通过', '2', 'bpm_task_status', 0, 'success', '', '流程实例的结果 - 通过', '1', '2022-01-07 23:48:45', '1', '2024-03-08 22:41:38', 0);
INSERT INTO public.system_dict_data VALUES (1131, 3, '审批不通过', '3', 'bpm_task_status', 0, 'danger', '', '流程实例的结果 - 不通过', '1', '2022-01-07 23:48:55', '1', '2024-03-08 22:41:38', 0);
INSERT INTO public.system_dict_data VALUES (1132, 4, '已取消', '4', 'bpm_task_status', 0, 'info', '', '流程实例的结果 - 撤销', '1', '2022-01-07 23:49:06', '1', '2024-03-08 22:41:39', 0);
INSERT INTO public.system_dict_data VALUES (1133, 10, '流程表单', '10', 'bpm_model_form_type', 0, '', '', '流程的表单类型 - 流程表单', '103', '2022-01-11 23:51:30', '103', '2022-01-11 23:51:30', 0);
INSERT INTO public.system_dict_data VALUES (1134, 20, '业务表单', '20', 'bpm_model_form_type', 0, '', '', '流程的表单类型 - 业务表单', '103', '2022-01-11 23:51:47', '103', '2022-01-11 23:51:47', 0);
INSERT INTO public.system_dict_data VALUES (1135, 10, '角色', '10', 'bpm_task_candidate_strategy', 0, 'info', '', '任务分配规则的类型 - 角色', '103', '2022-01-12 23:21:22', '1', '2024-03-06 02:53:16', 0);
INSERT INTO public.system_dict_data VALUES (1136, 20, '部门的成员', '20', 'bpm_task_candidate_strategy', 0, 'primary', '', '任务分配规则的类型 - 部门的成员', '103', '2022-01-12 23:21:47', '1', '2024-03-06 02:53:17', 0);
INSERT INTO public.system_dict_data VALUES (1137, 21, '部门的负责人', '21', 'bpm_task_candidate_strategy', 0, 'primary', '', '任务分配规则的类型 - 部门的负责人', '103', '2022-01-12 23:33:36', '1', '2024-03-06 02:53:18', 0);
INSERT INTO public.system_dict_data VALUES (1138, 30, '用户', '30', 'bpm_task_candidate_strategy', 0, 'info', '', '任务分配规则的类型 - 用户', '103', '2022-01-12 23:34:02', '1', '2024-03-06 02:53:19', 0);
INSERT INTO public.system_dict_data VALUES (1139, 40, '用户组', '40', 'bpm_task_candidate_strategy', 0, 'warning', '', '任务分配规则的类型 - 用户组', '103', '2022-01-12 23:34:21', '1', '2024-03-06 02:53:20', 0);
INSERT INTO public.system_dict_data VALUES (1140, 60, '流程表达式', '60', 'bpm_task_candidate_strategy', 0, 'danger', '', '任务分配规则的类型 - 流程表达式', '103', '2022-01-12 23:34:43', '1', '2024-03-06 02:53:20', 0);
INSERT INTO public.system_dict_data VALUES (1141, 22, '岗位', '22', 'bpm_task_candidate_strategy', 0, 'success', '', '任务分配规则的类型 - 岗位', '103', '2022-01-14 18:41:55', '1', '2024-03-06 02:53:21', 0);
INSERT INTO public.system_dict_data VALUES (1145, 1, '管理后台', '1', 'infra_codegen_scene', 0, '', '', '代码生成的场景枚举 - 管理后台', '1', '2022-02-02 13:15:06', '1', '2022-03-10 16:32:59', 0);
INSERT INTO public.system_dict_data VALUES (1146, 2, '用户 APP', '2', 'infra_codegen_scene', 0, '', '', '代码生成的场景枚举 - 用户 APP', '1', '2022-02-02 13:15:19', '1', '2022-03-10 16:33:03', 0);
INSERT INTO public.system_dict_data VALUES (1150, 1, '数据库', '1', 'infra_file_storage', 0, 'default', '', NULL, '1', '2022-03-15 00:25:28', '1', '2022-03-15 00:25:28', 0);
INSERT INTO public.system_dict_data VALUES (1151, 10, '本地磁盘', '10', 'infra_file_storage', 0, 'default', '', NULL, '1', '2022-03-15 00:25:41', '1', '2022-03-15 00:25:56', 0);
INSERT INTO public.system_dict_data VALUES (1152, 11, 'FTP 服务器', '11', 'infra_file_storage', 0, 'default', '', NULL, '1', '2022-03-15 00:26:06', '1', '2022-03-15 00:26:10', 0);
INSERT INTO public.system_dict_data VALUES (1153, 12, 'SFTP 服务器', '12', 'infra_file_storage', 0, 'default', '', NULL, '1', '2022-03-15 00:26:22', '1', '2022-03-15 00:26:22', 0);
INSERT INTO public.system_dict_data VALUES (1154, 20, 'S3 对象存储', '20', 'infra_file_storage', 0, 'default', '', NULL, '1', '2022-03-15 00:26:31', '1', '2022-03-15 00:26:45', 0);
INSERT INTO public.system_dict_data VALUES (1155, 103, '短信登录', '103', 'system_login_type', 0, 'default', '', NULL, '1', '2022-05-09 23:57:58', '1', '2022-05-09 23:58:09', 0);
INSERT INTO public.system_dict_data VALUES (1156, 1, 'password', 'password', 'system_oauth2_grant_type', 0, 'default', '', '密码模式', '1', '2022-05-12 00:22:05', '1', '2022-05-11 16:26:01', 0);
INSERT INTO public.system_dict_data VALUES (1157, 2, 'authorization_code', 'authorization_code', 'system_oauth2_grant_type', 0, 'primary', '', '授权码模式', '1', '2022-05-12 00:22:59', '1', '2022-05-11 16:26:02', 0);
INSERT INTO public.system_dict_data VALUES (1158, 3, 'implicit', 'implicit', 'system_oauth2_grant_type', 0, 'success', '', '简化模式', '1', '2022-05-12 00:23:40', '1', '2022-05-11 16:26:05', 0);
INSERT INTO public.system_dict_data VALUES (1159, 4, 'client_credentials', 'client_credentials', 'system_oauth2_grant_type', 0, 'default', '', '客户端模式', '1', '2022-05-12 00:23:51', '1', '2022-05-11 16:26:08', 0);
INSERT INTO public.system_dict_data VALUES (1160, 5, 'refresh_token', 'refresh_token', 'system_oauth2_grant_type', 0, 'info', '', '刷新模式', '1', '2022-05-12 00:24:02', '1', '2022-05-11 16:26:11', 0);
INSERT INTO public.system_dict_data VALUES (1162, 1, '销售中', '1', 'product_spu_status', 0, 'success', '', '商品 SPU 状态 - 销售中', '1', '2022-10-24 21:19:47', '1', '2022-10-24 21:20:38', 0);
INSERT INTO public.system_dict_data VALUES (1163, 0, '仓库中', '0', 'product_spu_status', 0, 'info', '', '商品 SPU 状态 - 仓库中', '1', '2022-10-24 21:20:54', '1', '2022-10-24 21:21:22', 0);
INSERT INTO public.system_dict_data VALUES (1164, 0, '回收站', '-1', 'product_spu_status', 0, 'default', '', '商品 SPU 状态 - 回收站', '1', '2022-10-24 21:21:11', '1', '2022-10-24 21:21:11', 0);
INSERT INTO public.system_dict_data VALUES (1165, 1, '满减', '1', 'promotion_discount_type', 0, 'success', '', '优惠类型 - 满减', '1', '2022-11-01 12:46:41', '1', '2022-11-01 12:50:11', 0);
INSERT INTO public.system_dict_data VALUES (1166, 2, '折扣', '2', 'promotion_discount_type', 0, 'primary', '', '优惠类型 - 折扣', '1', '2022-11-01 12:46:51', '1', '2022-11-01 12:50:08', 0);
INSERT INTO public.system_dict_data VALUES (1167, 1, '固定日期', '1', 'promotion_coupon_template_validity_type', 0, 'default', '', '优惠劵模板的有限期类型 - 固定日期', '1', '2022-11-02 00:07:34', '1', '2022-11-04 00:07:49', 0);
INSERT INTO public.system_dict_data VALUES (1168, 2, '领取之后', '2', 'promotion_coupon_template_validity_type', 0, 'default', '', '优惠劵模板的有限期类型 - 领取之后', '1', '2022-11-02 00:07:54', '1', '2022-11-04 00:07:52', 0);
INSERT INTO public.system_dict_data VALUES (1169, 1, '通用劵', '1', 'promotion_product_scope', 0, 'default', '', '营销的商品范围 - 全部商品参与', '1', '2022-11-02 00:28:22', '1', '2023-09-28 00:27:42', 0);
INSERT INTO public.system_dict_data VALUES (1170, 2, '商品劵', '2', 'promotion_product_scope', 0, 'default', '', '营销的商品范围 - 指定商品参与', '1', '2022-11-02 00:28:34', '1', '2023-09-28 00:27:44', 0);
INSERT INTO public.system_dict_data VALUES (1171, 1, '未使用', '1', 'promotion_coupon_status', 0, 'primary', '', '优惠劵的状态 - 已领取', '1', '2022-11-04 00:15:08', '1', '2023-10-03 12:54:38', 0);
INSERT INTO public.system_dict_data VALUES (1172, 2, '已使用', '2', 'promotion_coupon_status', 0, 'success', '', '优惠劵的状态 - 已使用', '1', '2022-11-04 00:15:21', '1', '2022-11-04 19:16:08', 0);
INSERT INTO public.system_dict_data VALUES (1173, 3, '已过期', '3', 'promotion_coupon_status', 0, 'info', '', '优惠劵的状态 - 已过期', '1', '2022-11-04 00:15:43', '1', '2022-11-04 19:16:12', 0);
INSERT INTO public.system_dict_data VALUES (1174, 1, '直接领取', '1', 'promotion_coupon_take_type', 0, 'primary', '', '优惠劵的领取方式 - 直接领取', '1', '2022-11-04 19:13:00', '1', '2022-11-04 19:13:25', 0);
INSERT INTO public.system_dict_data VALUES (1175, 2, '指定发放', '2', 'promotion_coupon_take_type', 0, 'success', '', '优惠劵的领取方式 - 指定发放', '1', '2022-11-04 19:13:13', '1', '2022-11-04 19:14:48', 0);
INSERT INTO public.system_dict_data VALUES (1176, 10, '未开始', '10', 'promotion_activity_status', 0, 'primary', '', '促销活动的状态枚举 - 未开始', '1', '2022-11-04 22:54:49', '1', '2022-11-04 22:55:53', 0);
INSERT INTO public.system_dict_data VALUES (1177, 20, '进行中', '20', 'promotion_activity_status', 0, 'success', '', '促销活动的状态枚举 - 进行中', '1', '2022-11-04 22:55:06', '1', '2022-11-04 22:55:20', 0);
INSERT INTO public.system_dict_data VALUES (1178, 30, '已结束', '30', 'promotion_activity_status', 0, 'info', '', '促销活动的状态枚举 - 已结束', '1', '2022-11-04 22:55:41', '1', '2022-11-04 22:55:41', 0);
INSERT INTO public.system_dict_data VALUES (1179, 40, '已关闭', '40', 'promotion_activity_status', 0, 'warning', '', '促销活动的状态枚举 - 已关闭', '1', '2022-11-04 22:56:10', '1', '2022-11-04 22:56:18', 0);
INSERT INTO public.system_dict_data VALUES (1180, 10, '满 N 元', '10', 'promotion_condition_type', 0, 'primary', '', '营销的条件类型 - 满 N 元', '1', '2022-11-04 22:59:45', '1', '2022-11-04 22:59:45', 0);
INSERT INTO public.system_dict_data VALUES (1181, 20, '满 N 件', '20', 'promotion_condition_type', 0, 'success', '', '营销的条件类型 - 满 N 件', '1', '2022-11-04 23:00:02', '1', '2022-11-04 23:00:02', 0);
INSERT INTO public.system_dict_data VALUES (1182, 10, '申请售后', '10', 'trade_after_sale_status', 0, 'primary', '', '交易售后状态 - 申请售后', '1', '2022-11-19 20:53:33', '1', '2022-11-19 20:54:42', 0);
INSERT INTO public.system_dict_data VALUES (1183, 20, '商品待退货', '20', 'trade_after_sale_status', 0, 'primary', '', '交易售后状态 - 商品待退货', '1', '2022-11-19 20:54:36', '1', '2022-11-19 20:58:58', 0);
INSERT INTO public.system_dict_data VALUES (1184, 30, '商家待收货', '30', 'trade_after_sale_status', 0, 'primary', '', '交易售后状态 - 商家待收货', '1', '2022-11-19 20:56:56', '1', '2022-11-19 20:59:20', 0);
INSERT INTO public.system_dict_data VALUES (1185, 40, '等待退款', '40', 'trade_after_sale_status', 0, 'primary', '', '交易售后状态 - 等待退款', '1', '2022-11-19 20:59:54', '1', '2022-11-19 21:00:01', 0);
INSERT INTO public.system_dict_data VALUES (1186, 50, '退款成功', '50', 'trade_after_sale_status', 0, 'default', '', '交易售后状态 - 退款成功', '1', '2022-11-19 21:00:33', '1', '2022-11-19 21:00:33', 0);
INSERT INTO public.system_dict_data VALUES (1187, 61, '买家取消', '61', 'trade_after_sale_status', 0, 'info', '', '交易售后状态 - 买家取消', '1', '2022-11-19 21:01:29', '1', '2022-11-19 21:01:29', 0);
INSERT INTO public.system_dict_data VALUES (1188, 62, '商家拒绝', '62', 'trade_after_sale_status', 0, 'info', '', '交易售后状态 - 商家拒绝', '1', '2022-11-19 21:02:17', '1', '2022-11-19 21:02:17', 0);
INSERT INTO public.system_dict_data VALUES (1189, 63, '商家拒收货', '63', 'trade_after_sale_status', 0, 'info', '', '交易售后状态 - 商家拒收货', '1', '2022-11-19 21:02:37', '1', '2022-11-19 21:03:07', 0);
INSERT INTO public.system_dict_data VALUES (1190, 10, '售中退款', '10', 'trade_after_sale_type', 0, 'success', '', '交易售后的类型 - 售中退款', '1', '2022-11-19 21:05:05', '1', '2022-11-19 21:38:23', 0);
INSERT INTO public.system_dict_data VALUES (1191, 20, '售后退款', '20', 'trade_after_sale_type', 0, 'primary', '', '交易售后的类型 - 售后退款', '1', '2022-11-19 21:05:32', '1', '2022-11-19 21:38:32', 0);
INSERT INTO public.system_dict_data VALUES (1192, 10, '仅退款', '10', 'trade_after_sale_way', 0, 'primary', '', '交易售后的方式 - 仅退款', '1', '2022-11-19 21:39:19', '1', '2022-11-19 21:39:19', 0);
INSERT INTO public.system_dict_data VALUES (1193, 20, '退货退款', '20', 'trade_after_sale_way', 0, 'success', '', '交易售后的方式 - 退货退款', '1', '2022-11-19 21:39:38', '1', '2022-11-19 21:39:49', 0);
INSERT INTO public.system_dict_data VALUES (1194, 10, '微信小程序', '10', 'terminal', 0, 'default', '', '终端 - 微信小程序', '1', '2022-12-10 10:51:11', '1', '2022-12-10 10:51:57', 0);
INSERT INTO public.system_dict_data VALUES (1195, 20, 'H5 网页', '20', 'terminal', 0, 'default', '', '终端 - H5 网页', '1', '2022-12-10 10:51:30', '1', '2022-12-10 10:51:59', 0);
INSERT INTO public.system_dict_data VALUES (1196, 11, '微信公众号', '11', 'terminal', 0, 'default', '', '终端 - 微信公众号', '1', '2022-12-10 10:54:16', '1', '2022-12-10 10:52:01', 0);
INSERT INTO public.system_dict_data VALUES (1197, 31, '苹果 App', '31', 'terminal', 0, 'default', '', '终端 - 苹果 App', '1', '2022-12-10 10:54:42', '1', '2022-12-10 10:52:18', 0);
INSERT INTO public.system_dict_data VALUES (1198, 32, '安卓 App', '32', 'terminal', 0, 'default', '', '终端 - 安卓 App', '1', '2022-12-10 10:55:02', '1', '2022-12-10 10:59:17', 0);
INSERT INTO public.system_dict_data VALUES (1199, 0, '普通订单', '0', 'trade_order_type', 0, 'default', '', '交易订单的类型 - 普通订单', '1', '2022-12-10 16:34:14', '1', '2022-12-10 16:34:14', 0);
INSERT INTO public.system_dict_data VALUES (1200, 1, '秒杀订单', '1', 'trade_order_type', 0, 'default', '', '交易订单的类型 - 秒杀订单', '1', '2022-12-10 16:34:26', '1', '2022-12-10 16:34:26', 0);
INSERT INTO public.system_dict_data VALUES (1201, 2, '砍价订单', '2', 'trade_order_type', 0, 'default', '', '交易订单的类型 - 拼团订单', '1', '2022-12-10 16:34:36', '1', '2024-09-07 14:18:39', 0);
INSERT INTO public.system_dict_data VALUES (1202, 3, '拼团订单', '3', 'trade_order_type', 0, 'default', '', '交易订单的类型 - 砍价订单', '1', '2022-12-10 16:34:48', '1', '2024-09-07 14:18:32', 0);
INSERT INTO public.system_dict_data VALUES (1203, 0, '待支付', '0', 'trade_order_status', 0, 'default', '', '交易订单状态 - 待支付', '1', '2022-12-10 16:49:29', '1', '2022-12-10 16:49:29', 0);
INSERT INTO public.system_dict_data VALUES (1204, 10, '待发货', '10', 'trade_order_status', 0, 'primary', '', '交易订单状态 - 待发货', '1', '2022-12-10 16:49:53', '1', '2022-12-10 16:51:17', 0);
INSERT INTO public.system_dict_data VALUES (1205, 20, '已发货', '20', 'trade_order_status', 0, 'primary', '', '交易订单状态 - 已发货', '1', '2022-12-10 16:50:13', '1', '2022-12-10 16:51:31', 0);
INSERT INTO public.system_dict_data VALUES (1206, 30, '已完成', '30', 'trade_order_status', 0, 'success', '', '交易订单状态 - 已完成', '1', '2022-12-10 16:50:30', '1', '2022-12-10 16:51:06', 0);
INSERT INTO public.system_dict_data VALUES (1207, 40, '已取消', '40', 'trade_order_status', 0, 'danger', '', '交易订单状态 - 已取消', '1', '2022-12-10 16:50:50', '1', '2022-12-10 16:51:00', 0);
INSERT INTO public.system_dict_data VALUES (1208, 0, '未售后', '0', 'trade_order_item_after_sale_status', 0, 'info', '', '交易订单项的售后状态 - 未售后', '1', '2022-12-10 20:58:42', '1', '2022-12-10 20:59:29', 0);
INSERT INTO public.system_dict_data VALUES (1209, 10, '售后中', '10', 'trade_order_item_after_sale_status', 0, 'primary', '', '交易订单项的售后状态 - 售后中', '1', '2022-12-10 20:59:21', '1', '2024-07-21 17:01:24', 0);
INSERT INTO public.system_dict_data VALUES (1210, 20, '已退款', '20', 'trade_order_item_after_sale_status', 0, 'success', '', '交易订单项的售后状态 - 已退款', '1', '2022-12-10 20:59:46', '1', '2024-07-21 17:01:35', 0);
INSERT INTO public.system_dict_data VALUES (1369, 2, '申请提现', '2', 'brokerage_record_biz_type', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1211, 1, '完全匹配', '1', 'mp_auto_reply_request_match', 0, 'primary', '', '公众号自动回复的请求关键字匹配模式 - 完全匹配', '1', '2023-01-16 23:30:39', '1', '2023-01-16 23:31:00', 0);
INSERT INTO public.system_dict_data VALUES (1212, 2, '半匹配', '2', 'mp_auto_reply_request_match', 0, 'success', '', '公众号自动回复的请求关键字匹配模式 - 半匹配', '1', '2023-01-16 23:30:55', '1', '2023-01-16 23:31:10', 0);
INSERT INTO public.system_dict_data VALUES (1213, 1, '文本', 'text', 'mp_message_type', 0, 'default', '', '公众号的消息类型 - 文本', '1', '2023-01-17 22:17:32', '1', '2023-01-17 22:17:39', 0);
INSERT INTO public.system_dict_data VALUES (1214, 2, '图片', 'image', 'mp_message_type', 0, 'default', '', '公众号的消息类型 - 图片', '1', '2023-01-17 22:17:32', '1', '2023-01-17 14:19:47', 0);
INSERT INTO public.system_dict_data VALUES (1215, 3, '语音', 'voice', 'mp_message_type', 0, 'default', '', '公众号的消息类型 - 语音', '1', '2023-01-17 22:17:32', '1', '2023-01-17 14:20:08', 0);
INSERT INTO public.system_dict_data VALUES (1216, 4, '视频', 'video', 'mp_message_type', 0, 'default', '', '公众号的消息类型 - 视频', '1', '2023-01-17 22:17:32', '1', '2023-01-17 14:21:08', 0);
INSERT INTO public.system_dict_data VALUES (1217, 5, '小视频', 'shortvideo', 'mp_message_type', 0, 'default', '', '公众号的消息类型 - 小视频', '1', '2023-01-17 22:17:32', '1', '2023-01-17 14:19:59', 0);
INSERT INTO public.system_dict_data VALUES (1218, 6, '图文', 'news', 'mp_message_type', 0, 'default', '', '公众号的消息类型 - 图文', '1', '2023-01-17 22:17:32', '1', '2023-01-17 14:22:54', 0);
INSERT INTO public.system_dict_data VALUES (1219, 7, '音乐', 'music', 'mp_message_type', 0, 'default', '', '公众号的消息类型 - 音乐', '1', '2023-01-17 22:17:32', '1', '2023-01-17 14:22:54', 0);
INSERT INTO public.system_dict_data VALUES (1220, 8, '地理位置', 'location', 'mp_message_type', 0, 'default', '', '公众号的消息类型 - 地理位置', '1', '2023-01-17 22:17:32', '1', '2023-01-17 14:23:51', 0);
INSERT INTO public.system_dict_data VALUES (1221, 9, '链接', 'link', 'mp_message_type', 0, 'default', '', '公众号的消息类型 - 链接', '1', '2023-01-17 22:17:32', '1', '2023-01-17 14:24:49', 0);
INSERT INTO public.system_dict_data VALUES (1222, 10, '事件', 'event', 'mp_message_type', 0, 'default', '', '公众号的消息类型 - 事件', '1', '2023-01-17 22:17:32', '1', '2023-01-17 14:24:49', 0);
INSERT INTO public.system_dict_data VALUES (1223, 0, '初始化', '0', 'system_mail_send_status', 0, 'primary', '', '邮件发送状态 - 初始化\n', '1', '2023-01-26 09:53:49', '1', '2023-01-26 16:36:14', 0);
INSERT INTO public.system_dict_data VALUES (1224, 10, '发送成功', '10', 'system_mail_send_status', 0, 'success', '', '邮件发送状态 - 发送成功', '1', '2023-01-26 09:54:28', '1', '2023-01-26 16:36:22', 0);
INSERT INTO public.system_dict_data VALUES (1225, 20, '发送失败', '20', 'system_mail_send_status', 0, 'danger', '', '邮件发送状态 - 发送失败', '1', '2023-01-26 09:54:50', '1', '2023-01-26 16:36:26', 0);
INSERT INTO public.system_dict_data VALUES (1226, 30, '不发送', '30', 'system_mail_send_status', 0, 'info', '', '邮件发送状态 -  不发送', '1', '2023-01-26 09:55:06', '1', '2023-01-26 16:36:36', 0);
INSERT INTO public.system_dict_data VALUES (1227, 1, '通知公告', '1', 'system_notify_template_type', 0, 'primary', '', '站内信模版的类型 - 通知公告', '1', '2023-01-28 10:35:59', '1', '2023-01-28 10:35:59', 0);
INSERT INTO public.system_dict_data VALUES (1228, 2, '系统消息', '2', 'system_notify_template_type', 0, 'success', '', '站内信模版的类型 - 系统消息', '1', '2023-01-28 10:36:20', '1', '2023-01-28 10:36:25', 0);
INSERT INTO public.system_dict_data VALUES (1230, 13, '支付宝条码支付', 'alipay_bar', 'pay_channel_code', 0, 'primary', '', '支付宝条码支付', '1', '2023-02-18 23:32:24', '1', '2023-07-19 20:09:23', 0);
INSERT INTO public.system_dict_data VALUES (1231, 10, 'Vue2 Element UI 标准模版', '10', 'infra_codegen_front_type', 0, '', '', '', '1', '2023-04-13 00:03:55', '1', '2023-04-13 00:03:55', 0);
INSERT INTO public.system_dict_data VALUES (1232, 20, 'Vue3 Element Plus 标准模版', '20', 'infra_codegen_front_type', 0, '', '', '', '1', '2023-04-13 00:04:08', '1', '2023-04-13 00:04:08', 0);
INSERT INTO public.system_dict_data VALUES (1234, 30, 'Vben2.0 Ant Design Schema 模版', '30', 'infra_codegen_front_type', 1, '', '', '', '1', '2023-04-13 00:04:26', '1', '2025-07-27 10:55:14', 0);
INSERT INTO public.system_dict_data VALUES (1244, 0, '按件', '1', 'trade_delivery_express_charge_mode', 0, '', '', '', '1', '2023-05-21 22:46:40', '1', '2023-05-21 22:46:40', 0);
INSERT INTO public.system_dict_data VALUES (1245, 1, '按重量', '2', 'trade_delivery_express_charge_mode', 0, '', '', '', '1', '2023-05-21 22:46:58', '1', '2023-05-21 22:46:58', 0);
INSERT INTO public.system_dict_data VALUES (1246, 2, '按体积', '3', 'trade_delivery_express_charge_mode', 0, '', '', '', '1', '2023-05-21 22:47:18', '1', '2023-05-21 22:47:18', 0);
INSERT INTO public.system_dict_data VALUES (1335, 11, '订单积分抵扣', '11', 'member_point_biz_type', 0, '', '', '', '1', '2023-06-10 12:15:27', '1', '2023-10-11 07:41:43', 0);
INSERT INTO public.system_dict_data VALUES (1336, 1, '签到', '1', 'member_point_biz_type', 0, '', '', '', '1', '2023-06-10 12:15:48', '1', '2023-08-20 11:59:53', 0);
INSERT INTO public.system_dict_data VALUES (1341, 20, '已退款', '20', 'pay_order_status', 0, 'danger', '', '已退款', '1', '2023-07-19 18:05:37', '1', '2023-07-19 18:05:37', 0);
INSERT INTO public.system_dict_data VALUES (1342, 21, '请求成功，但是结果失败', '21', 'pay_notify_status', 0, 'warning', '', '请求成功，但是结果失败', '1', '2023-07-19 18:10:47', '1', '2023-07-19 18:11:38', 0);
INSERT INTO public.system_dict_data VALUES (1343, 22, '请求失败', '22', 'pay_notify_status', 0, 'warning', '', NULL, '1', '2023-07-19 18:11:05', '1', '2023-07-19 18:11:27', 0);
INSERT INTO public.system_dict_data VALUES (1344, 4, '微信扫码支付', 'wx_native', 'pay_channel_code', 0, 'success', '', '微信扫码支付', '1', '2023-07-19 20:07:47', '1', '2023-07-19 20:09:03', 0);
INSERT INTO public.system_dict_data VALUES (1345, 5, '微信条码支付', 'wx_bar', 'pay_channel_code', 0, 'success', '', '微信条码支付\n', '1', '2023-07-19 20:08:06', '1', '2023-07-19 20:09:08', 0);
INSERT INTO public.system_dict_data VALUES (1346, 1, '支付单', '1', 'pay_notify_type', 0, 'primary', '', '支付单', '1', '2023-07-20 12:23:17', '1', '2023-07-20 12:23:17', 0);
INSERT INTO public.system_dict_data VALUES (1347, 2, '退款单', '2', 'pay_notify_type', 0, 'danger', '', NULL, '1', '2023-07-20 12:23:26', '1', '2023-07-20 12:23:26', 0);
INSERT INTO public.system_dict_data VALUES (1348, 20, '模拟支付', 'mock', 'pay_channel_code', 0, 'default', '', '模拟支付', '1', '2023-07-29 11:10:51', '1', '2023-07-29 03:14:10', 0);
INSERT INTO public.system_dict_data VALUES (1349, 12, '订单积分抵扣（整单取消）', '12', 'member_point_biz_type', 0, '', '', '', '1', '2023-08-20 12:00:03', '1', '2023-10-11 07:42:01', 0);
INSERT INTO public.system_dict_data VALUES (1350, 0, '管理员调整', '0', 'member_experience_biz_type', 0, '', '', NULL, '', '2023-08-22 12:41:01', '', '2023-08-22 12:41:01', 0);
INSERT INTO public.system_dict_data VALUES (1351, 1, '邀新奖励', '1', 'member_experience_biz_type', 0, '', '', NULL, '', '2023-08-22 12:41:01', '', '2023-08-22 12:41:01', 0);
INSERT INTO public.system_dict_data VALUES (1352, 11, '下单奖励', '11', 'member_experience_biz_type', 0, 'success', '', NULL, '', '2023-08-22 12:41:01', '1', '2023-10-11 07:45:09', 0);
INSERT INTO public.system_dict_data VALUES (1353, 12, '下单奖励（整单取消）', '12', 'member_experience_biz_type', 0, 'warning', '', NULL, '', '2023-08-22 12:41:01', '1', '2023-10-11 07:45:01', 0);
INSERT INTO public.system_dict_data VALUES (1354, 4, '签到奖励', '4', 'member_experience_biz_type', 0, '', '', NULL, '', '2023-08-22 12:41:01', '', '2023-08-22 12:41:01', 0);
INSERT INTO public.system_dict_data VALUES (1355, 5, '抽奖奖励', '5', 'member_experience_biz_type', 0, '', '', NULL, '', '2023-08-22 12:41:01', '', '2023-08-22 12:41:01', 0);
INSERT INTO public.system_dict_data VALUES (1356, 1, '快递发货', '1', 'trade_delivery_type', 0, '', '', '', '1', '2023-08-23 00:04:55', '1', '2023-08-23 00:04:55', 0);
INSERT INTO public.system_dict_data VALUES (1357, 2, '用户自提', '2', 'trade_delivery_type', 0, '', '', '', '1', '2023-08-23 00:05:05', '1', '2023-08-23 00:05:05', 0);
INSERT INTO public.system_dict_data VALUES (1358, 3, '品类劵', '3', 'promotion_product_scope', 0, 'default', '', '', '1', '2023-09-01 23:43:07', '1', '2023-09-28 00:27:47', 0);
INSERT INTO public.system_dict_data VALUES (1359, 1, '人人分销', '1', 'brokerage_enabled_condition', 0, '', '', '所有用户都可以分销', '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1360, 2, '指定分销', '2', 'brokerage_enabled_condition', 0, '', '', '仅可后台手动设置推广员', '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1361, 1, '首次绑定', '1', 'brokerage_bind_mode', 0, '', '', '只要用户没有推广人，随时都可以绑定推广关系', '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1362, 2, '注册绑定', '2', 'brokerage_bind_mode', 0, '', '', '仅新用户注册时才能绑定推广关系', '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1363, 3, '覆盖绑定', '3', 'brokerage_bind_mode', 0, '', '', '如果用户已经有推广人，推广人会被变更', '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1364, 1, '钱包', '1', 'brokerage_withdraw_type', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1365, 2, '银行卡', '2', 'brokerage_withdraw_type', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1366, 3, '微信收款码', '3', 'brokerage_withdraw_type', 0, '', '', '手动打款', '', '2023-09-28 02:46:05', '1', '2025-05-10 08:24:25', 0);
INSERT INTO public.system_dict_data VALUES (1367, 4, '支付宝收款码', '4', 'brokerage_withdraw_type', 0, '', '', '手动打款', '', '2023-09-28 02:46:05', '1', '2025-05-10 08:24:37', 0);
INSERT INTO public.system_dict_data VALUES (1368, 1, '订单返佣', '1', 'brokerage_record_biz_type', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1370, 3, '申请提现驳回', '3', 'brokerage_record_biz_type', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1371, 0, '待结算', '0', 'brokerage_record_status', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1372, 1, '已结算', '1', 'brokerage_record_status', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1373, 2, '已取消', '2', 'brokerage_record_status', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1374, 0, '审核中', '0', 'brokerage_withdraw_status', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1375, 10, '审核通过', '10', 'brokerage_withdraw_status', 0, 'success', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1376, 11, '提现成功', '11', 'brokerage_withdraw_status', 0, 'success', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1377, 20, '审核不通过', '20', 'brokerage_withdraw_status', 0, 'danger', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1378, 21, '提现失败', '21', 'brokerage_withdraw_status', 0, 'danger', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1379, 0, '工商银行', '0', 'brokerage_bank_name', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1380, 1, '建设银行', '1', 'brokerage_bank_name', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1381, 2, '农业银行', '2', 'brokerage_bank_name', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1382, 3, '中国银行', '3', 'brokerage_bank_name', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1383, 4, '交通银行', '4', 'brokerage_bank_name', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1384, 5, '招商银行', '5', 'brokerage_bank_name', 0, '', '', NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0);
INSERT INTO public.system_dict_data VALUES (1385, 21, '钱包', 'wallet', 'pay_channel_code', 0, 'primary', '', '', '1', '2023-10-01 21:46:19', '1', '2023-10-01 21:48:01', 0);
INSERT INTO public.system_dict_data VALUES (1386, 1, '砍价中', '1', 'promotion_bargain_record_status', 0, 'default', '', '', '1', '2023-10-05 10:41:26', '1', '2023-10-05 10:41:26', 0);
INSERT INTO public.system_dict_data VALUES (1387, 2, '砍价成功', '2', 'promotion_bargain_record_status', 0, 'success', '', '', '1', '2023-10-05 10:41:39', '1', '2023-10-05 10:41:39', 0);
INSERT INTO public.system_dict_data VALUES (1388, 3, '砍价失败', '3', 'promotion_bargain_record_status', 0, 'warning', '', '', '1', '2023-10-05 10:41:57', '1', '2023-10-05 10:41:57', 0);
INSERT INTO public.system_dict_data VALUES (1389, 0, '拼团中', '0', 'promotion_combination_record_status', 0, '', '', '', '1', '2023-10-08 07:24:44', '1', '2024-10-13 10:08:17', 0);
INSERT INTO public.system_dict_data VALUES (1390, 1, '拼团成功', '1', 'promotion_combination_record_status', 0, 'success', '', '', '1', '2023-10-08 07:24:56', '1', '2024-10-13 10:08:20', 0);
INSERT INTO public.system_dict_data VALUES (1391, 2, '拼团失败', '2', 'promotion_combination_record_status', 0, 'warning', '', '', '1', '2023-10-08 07:25:11', '1', '2024-10-13 10:08:24', 0);
INSERT INTO public.system_dict_data VALUES (1392, 2, '管理员修改', '2', 'member_point_biz_type', 0, 'default', '', '', '1', '2023-10-11 07:41:34', '1', '2023-10-11 07:41:34', 0);
INSERT INTO public.system_dict_data VALUES (1393, 13, '订单积分抵扣（单个退款）', '13', 'member_point_biz_type', 0, '', '', '', '1', '2023-10-11 07:42:29', '1', '2023-10-11 07:42:29', 0);
INSERT INTO public.system_dict_data VALUES (1394, 21, '订单积分奖励', '21', 'member_point_biz_type', 0, 'default', '', '', '1', '2023-10-11 07:42:44', '1', '2023-10-11 07:42:44', 0);
INSERT INTO public.system_dict_data VALUES (1395, 22, '订单积分奖励（整单取消）', '22', 'member_point_biz_type', 0, 'default', '', '', '1', '2023-10-11 07:42:55', '1', '2023-10-11 07:43:01', 0);
INSERT INTO public.system_dict_data VALUES (1396, 23, '订单积分奖励（单个退款）', '23', 'member_point_biz_type', 0, 'default', '', '', '1', '2023-10-11 07:43:16', '1', '2023-10-11 07:43:16', 0);
INSERT INTO public.system_dict_data VALUES (1397, 13, '下单奖励（单个退款）', '13', 'member_experience_biz_type', 0, 'warning', '', '', '1', '2023-10-11 07:45:24', '1', '2023-10-11 07:45:38', 0);
INSERT INTO public.system_dict_data VALUES (1398, 5, '网上转账', '5', 'crm_receivable_return_type', 0, 'default', '', '', '1', '2023-10-18 21:55:24', '1', '2023-10-18 21:55:24', 0);
INSERT INTO public.system_dict_data VALUES (1399, 6, '支付宝', '6', 'crm_receivable_return_type', 0, 'default', '', '', '1', '2023-10-18 21:55:38', '1', '2023-10-18 21:55:38', 0);
INSERT INTO public.system_dict_data VALUES (1400, 7, '微信支付', '7', 'crm_receivable_return_type', 0, 'default', '', '', '1', '2023-10-18 21:55:53', '1', '2023-10-18 21:55:53', 0);
INSERT INTO public.system_dict_data VALUES (1401, 8, '其他', '8', 'crm_receivable_return_type', 0, 'default', '', '', '1', '2023-10-18 21:56:06', '1', '2023-10-18 21:56:06', 0);
INSERT INTO public.system_dict_data VALUES (1402, 1, 'IT', '1', 'crm_customer_industry', 0, 'default', '', '', '1', '2023-10-28 23:02:15', '1', '2024-02-18 23:30:38', 0);
INSERT INTO public.system_dict_data VALUES (1403, 2, '金融业', '2', 'crm_customer_industry', 0, 'default', '', '', '1', '2023-10-28 23:02:29', '1', '2024-02-18 23:30:43', 0);
INSERT INTO public.system_dict_data VALUES (1404, 3, '房地产', '3', 'crm_customer_industry', 0, 'default', '', '', '1', '2023-10-28 23:02:41', '1', '2024-02-18 23:30:48', 0);
INSERT INTO public.system_dict_data VALUES (1405, 4, '商业服务', '4', 'crm_customer_industry', 0, 'default', '', '', '1', '2023-10-28 23:02:54', '1', '2024-02-18 23:30:54', 0);
INSERT INTO public.system_dict_data VALUES (1406, 5, '运输/物流', '5', 'crm_customer_industry', 0, 'default', '', '', '1', '2023-10-28 23:03:03', '1', '2024-02-18 23:31:00', 0);
INSERT INTO public.system_dict_data VALUES (1407, 6, '生产', '6', 'crm_customer_industry', 0, 'default', '', '', '1', '2023-10-28 23:03:13', '1', '2024-02-18 23:31:08', 0);
INSERT INTO public.system_dict_data VALUES (1408, 7, '政府', '7', 'crm_customer_industry', 0, 'default', '', '', '1', '2023-10-28 23:03:27', '1', '2024-02-18 23:31:13', 0);
INSERT INTO public.system_dict_data VALUES (1409, 8, '文化传媒', '8', 'crm_customer_industry', 0, 'default', '', '', '1', '2023-10-28 23:03:37', '1', '2024-02-18 23:31:20', 0);
INSERT INTO public.system_dict_data VALUES (1422, 1, 'A （重点客户）', '1', 'crm_customer_level', 0, 'primary', '', '', '1', '2023-10-28 23:07:13', '1', '2023-10-28 23:07:13', 0);
INSERT INTO public.system_dict_data VALUES (1423, 2, 'B （普通客户）', '2', 'crm_customer_level', 0, 'info', '', '', '1', '2023-10-28 23:07:35', '1', '2023-10-28 23:07:35', 0);
INSERT INTO public.system_dict_data VALUES (1424, 3, 'C （非优先客户）', '3', 'crm_customer_level', 0, 'default', '', '', '1', '2023-10-28 23:07:53', '1', '2023-10-28 23:07:53', 0);
INSERT INTO public.system_dict_data VALUES (1425, 1, '促销', '1', 'crm_customer_source', 0, 'default', '', '', '1', '2023-10-28 23:08:29', '1', '2023-10-28 23:08:29', 0);
INSERT INTO public.system_dict_data VALUES (1426, 2, '搜索引擎', '2', 'crm_customer_source', 0, 'default', '', '', '1', '2023-10-28 23:08:39', '1', '2023-10-28 23:08:39', 0);
INSERT INTO public.system_dict_data VALUES (1427, 3, '广告', '3', 'crm_customer_source', 0, 'default', '', '', '1', '2023-10-28 23:08:47', '1', '2023-10-28 23:08:47', 0);
INSERT INTO public.system_dict_data VALUES (1428, 4, '转介绍', '4', 'crm_customer_source', 0, 'default', '', '', '1', '2023-10-28 23:08:58', '1', '2023-10-28 23:08:58', 0);
INSERT INTO public.system_dict_data VALUES (1429, 5, '线上注册', '5', 'crm_customer_source', 0, 'default', '', '', '1', '2023-10-28 23:09:12', '1', '2023-10-28 23:09:12', 0);
INSERT INTO public.system_dict_data VALUES (1430, 6, '线上咨询', '6', 'crm_customer_source', 0, 'default', '', '', '1', '2023-10-28 23:09:22', '1', '2023-10-28 23:09:22', 0);
INSERT INTO public.system_dict_data VALUES (1431, 7, '预约上门', '7', 'crm_customer_source', 0, 'default', '', '', '1', '2023-10-28 23:09:39', '1', '2023-10-28 23:09:39', 0);
INSERT INTO public.system_dict_data VALUES (1432, 8, '陌拜', '8', 'crm_customer_source', 0, 'default', '', '', '1', '2023-10-28 23:10:04', '1', '2023-10-28 23:10:04', 0);
INSERT INTO public.system_dict_data VALUES (1433, 9, '电话咨询', '9', 'crm_customer_source', 0, 'default', '', '', '1', '2023-10-28 23:10:18', '1', '2023-10-28 23:10:18', 0);
INSERT INTO public.system_dict_data VALUES (1434, 10, '邮件咨询', '10', 'crm_customer_source', 0, 'default', '', '', '1', '2023-10-28 23:10:33', '1', '2023-10-28 23:10:33', 0);
INSERT INTO public.system_dict_data VALUES (1435, 10, 'Gitee', '10', 'system_social_type', 0, '', '', '', '1', '2023-11-04 13:04:42', '1', '2023-11-04 13:04:42', 0);
INSERT INTO public.system_dict_data VALUES (1436, 20, '钉钉', '20', 'system_social_type', 0, '', '', '', '1', '2023-11-04 13:04:54', '1', '2023-11-04 13:04:54', 0);
INSERT INTO public.system_dict_data VALUES (1437, 30, '企业微信', '30', 'system_social_type', 0, '', '', '', '1', '2023-11-04 13:05:09', '1', '2023-11-04 13:05:09', 0);
INSERT INTO public.system_dict_data VALUES (1438, 31, '微信公众平台', '31', 'system_social_type', 0, '', '', '', '1', '2023-11-04 13:05:18', '1', '2023-11-04 13:05:18', 0);
INSERT INTO public.system_dict_data VALUES (1439, 32, '微信开放平台', '32', 'system_social_type', 0, '', '', '', '1', '2023-11-04 13:05:30', '1', '2023-11-04 13:05:30', 0);
INSERT INTO public.system_dict_data VALUES (1440, 34, '微信小程序', '34', 'system_social_type', 0, '', '', '', '1', '2023-11-04 13:05:38', '1', '2023-11-04 13:07:16', 0);
INSERT INTO public.system_dict_data VALUES (1441, 1, '上架', '1', 'crm_product_status', 0, 'success', '', '', '1', '2023-10-30 21:49:34', '1', '2023-10-30 21:49:34', 0);
INSERT INTO public.system_dict_data VALUES (1442, 0, '下架', '0', 'crm_product_status', 0, 'success', '', '', '1', '2023-10-30 21:49:13', '1', '2023-10-30 21:49:13', 0);
INSERT INTO public.system_dict_data VALUES (1443, 15, '子表', '15', 'infra_codegen_template_type', 0, 'default', '', '', '1', '2023-11-13 23:06:16', '1', '2023-11-13 23:06:16', 0);
INSERT INTO public.system_dict_data VALUES (1444, 10, '主表（标准模式）', '10', 'infra_codegen_template_type', 0, 'default', '', '', '1', '2023-11-14 12:32:49', '1', '2023-11-14 12:32:49', 0);
INSERT INTO public.system_dict_data VALUES (1445, 11, '主表（ERP 模式）', '11', 'infra_codegen_template_type', 0, 'default', '', '', '1', '2023-11-14 12:33:05', '1', '2023-11-14 12:33:05', 0);
INSERT INTO public.system_dict_data VALUES (1446, 12, '主表（内嵌模式）', '12', 'infra_codegen_template_type', 0, '', '', '', '1', '2023-11-14 12:33:31', '1', '2023-11-14 12:33:31', 0);
INSERT INTO public.system_dict_data VALUES (1447, 1, '负责人', '1', 'crm_permission_level', 0, 'default', '', '', '1', '2023-11-30 09:53:12', '1', '2023-11-30 09:53:12', 0);
INSERT INTO public.system_dict_data VALUES (1448, 2, '只读', '2', 'crm_permission_level', 0, '', '', '', '1', '2023-11-30 09:53:29', '1', '2023-11-30 09:53:29', 0);
INSERT INTO public.system_dict_data VALUES (1449, 3, '读写', '3', 'crm_permission_level', 0, '', '', '', '1', '2023-11-30 09:53:36', '1', '2023-11-30 09:53:36', 0);
INSERT INTO public.system_dict_data VALUES (1450, 0, '未提交', '0', 'crm_audit_status', 0, '', '', '', '1', '2023-11-30 18:56:59', '1', '2023-11-30 18:56:59', 0);
INSERT INTO public.system_dict_data VALUES (1451, 10, '审批中', '10', 'crm_audit_status', 0, '', '', '', '1', '2023-11-30 18:57:10', '1', '2023-11-30 18:57:10', 0);
INSERT INTO public.system_dict_data VALUES (1452, 20, '审核通过', '20', 'crm_audit_status', 0, '', '', '', '1', '2023-11-30 18:57:24', '1', '2023-11-30 18:57:24', 0);
INSERT INTO public.system_dict_data VALUES (1453, 30, '审核不通过', '30', 'crm_audit_status', 0, '', '', '', '1', '2023-11-30 18:57:32', '1', '2023-11-30 18:57:32', 0);
INSERT INTO public.system_dict_data VALUES (1454, 40, '已取消', '40', 'crm_audit_status', 0, '', '', '', '1', '2023-11-30 18:57:42', '1', '2023-11-30 18:57:42', 0);
INSERT INTO public.system_dict_data VALUES (1456, 1, '支票', '1', 'crm_receivable_return_type', 0, 'default', '', '', '1', '2023-10-18 21:54:29', '1', '2023-10-18 21:54:29', 0);
INSERT INTO public.system_dict_data VALUES (1457, 2, '现金', '2', 'crm_receivable_return_type', 0, 'default', '', '', '1', '2023-10-18 21:54:41', '1', '2023-10-18 21:54:41', 0);
INSERT INTO public.system_dict_data VALUES (1458, 3, '邮政汇款', '3', 'crm_receivable_return_type', 0, 'default', '', '', '1', '2023-10-18 21:54:53', '1', '2023-10-18 21:54:53', 0);
INSERT INTO public.system_dict_data VALUES (1459, 4, '电汇', '4', 'crm_receivable_return_type', 0, 'default', '', '', '1', '2023-10-18 21:55:07', '1', '2023-10-18 21:55:07', 0);
INSERT INTO public.system_dict_data VALUES (1461, 1, '个', '1', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:02:26', '1', '2023-12-05 23:02:26', 0);
INSERT INTO public.system_dict_data VALUES (1462, 2, '块', '2', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:02:34', '1', '2023-12-05 23:02:34', 0);
INSERT INTO public.system_dict_data VALUES (1463, 3, '只', '3', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:02:57', '1', '2023-12-05 23:02:57', 0);
INSERT INTO public.system_dict_data VALUES (1464, 4, '把', '4', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:03:05', '1', '2023-12-05 23:03:05', 0);
INSERT INTO public.system_dict_data VALUES (1465, 5, '枚', '5', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:03:14', '1', '2023-12-05 23:03:14', 0);
INSERT INTO public.system_dict_data VALUES (1466, 6, '瓶', '6', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:03:20', '1', '2023-12-05 23:03:20', 0);
INSERT INTO public.system_dict_data VALUES (1467, 7, '盒', '7', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:03:30', '1', '2023-12-05 23:03:30', 0);
INSERT INTO public.system_dict_data VALUES (1468, 8, '台', '8', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:03:41', '1', '2023-12-05 23:03:41', 0);
INSERT INTO public.system_dict_data VALUES (1469, 9, '吨', '9', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:03:48', '1', '2023-12-05 23:03:48', 0);
INSERT INTO public.system_dict_data VALUES (1470, 10, '千克', '10', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:04:03', '1', '2023-12-05 23:04:03', 0);
INSERT INTO public.system_dict_data VALUES (1471, 11, '米', '11', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:04:12', '1', '2023-12-05 23:04:12', 0);
INSERT INTO public.system_dict_data VALUES (1472, 12, '箱', '12', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:04:25', '1', '2023-12-05 23:04:25', 0);
INSERT INTO public.system_dict_data VALUES (1473, 13, '套', '13', 'crm_product_unit', 0, '', '', '', '1', '2023-12-05 23:04:34', '1', '2023-12-05 23:04:34', 0);
INSERT INTO public.system_dict_data VALUES (1474, 1, '打电话', '1', 'crm_follow_up_type', 0, '', '', '', '1', '2024-01-15 20:48:20', '1', '2024-01-15 20:48:20', 0);
INSERT INTO public.system_dict_data VALUES (1475, 2, '发短信', '2', 'crm_follow_up_type', 0, '', '', '', '1', '2024-01-15 20:48:31', '1', '2024-01-15 20:48:31', 0);
INSERT INTO public.system_dict_data VALUES (1476, 3, '上门拜访', '3', 'crm_follow_up_type', 0, '', '', '', '1', '2024-01-15 20:49:07', '1', '2024-01-15 20:49:07', 0);
INSERT INTO public.system_dict_data VALUES (1477, 4, '微信沟通', '4', 'crm_follow_up_type', 0, '', '', '', '1', '2024-01-15 20:49:15', '1', '2024-01-15 20:49:15', 0);
INSERT INTO public.system_dict_data VALUES (1482, 4, '转账失败', '20', 'pay_transfer_status', 0, 'warning', '', '', '1', '2023-10-28 16:24:16', '1', '2025-05-08 12:59:01', 0);
INSERT INTO public.system_dict_data VALUES (1483, 3, '转账成功', '10', 'pay_transfer_status', 0, 'success', '', '', '1', '2023-10-28 16:23:50', '1', '2025-05-08 12:58:58', 0);
INSERT INTO public.system_dict_data VALUES (1484, 2, '转账进行中', '5', 'pay_transfer_status', 0, 'info', '', '', '1', '2023-10-28 16:23:12', '1', '2025-05-08 12:58:54', 0);
INSERT INTO public.system_dict_data VALUES (1485, 1, '等待转账', '0', 'pay_transfer_status', 0, 'default', '', '', '1', '2023-10-28 16:21:43', '1', '2023-10-28 16:23:22', 0);
INSERT INTO public.system_dict_data VALUES (1486, 10, '其它入库', '10', 'erp_stock_record_biz_type', 0, '', '', '', '1', '2024-02-05 18:07:25', '1', '2024-02-05 18:07:43', 0);
INSERT INTO public.system_dict_data VALUES (1487, 11, '其它入库（作废）', '11', 'erp_stock_record_biz_type', 0, 'danger', '', '', '1', '2024-02-05 18:08:07', '1', '2024-02-05 19:20:16', 0);
INSERT INTO public.system_dict_data VALUES (1488, 20, '其它出库', '20', 'erp_stock_record_biz_type', 0, '', '', '', '1', '2024-02-05 18:08:51', '1', '2024-02-05 18:08:51', 0);
INSERT INTO public.system_dict_data VALUES (1489, 21, '其它出库（作废）', '21', 'erp_stock_record_biz_type', 0, 'danger', '', '', '1', '2024-02-05 18:09:00', '1', '2024-02-05 19:20:10', 0);
INSERT INTO public.system_dict_data VALUES (1490, 10, '未审核', '10', 'erp_audit_status', 0, 'default', '', '', '1', '2024-02-06 00:00:21', '1', '2024-02-06 00:00:21', 0);
INSERT INTO public.system_dict_data VALUES (1491, 20, '已审核', '20', 'erp_audit_status', 0, 'success', '', '', '1', '2024-02-06 00:00:35', '1', '2024-02-06 00:00:35', 0);
INSERT INTO public.system_dict_data VALUES (1492, 30, '调拨入库', '30', 'erp_stock_record_biz_type', 0, '', '', '', '1', '2024-02-07 20:34:19', '1', '2024-02-07 12:36:31', 0);
INSERT INTO public.system_dict_data VALUES (1493, 31, '调拨入库（作废）', '31', 'erp_stock_record_biz_type', 0, 'danger', '', '', '1', '2024-02-07 20:34:29', '1', '2024-02-07 20:37:11', 0);
INSERT INTO public.system_dict_data VALUES (1494, 32, '调拨出库', '32', 'erp_stock_record_biz_type', 0, '', '', '', '1', '2024-02-07 20:34:38', '1', '2024-02-07 12:36:33', 0);
INSERT INTO public.system_dict_data VALUES (1495, 33, '调拨出库（作废）', '33', 'erp_stock_record_biz_type', 0, 'danger', '', '', '1', '2024-02-07 20:34:49', '1', '2024-02-07 20:37:06', 0);
INSERT INTO public.system_dict_data VALUES (1496, 40, '盘盈入库', '40', 'erp_stock_record_biz_type', 0, '', '', '', '1', '2024-02-08 08:53:00', '1', '2024-02-08 08:53:09', 0);
INSERT INTO public.system_dict_data VALUES (1497, 41, '盘盈入库（作废）', '41', 'erp_stock_record_biz_type', 0, 'danger', '', '', '1', '2024-02-08 08:53:39', '1', '2024-02-16 19:40:54', 0);
INSERT INTO public.system_dict_data VALUES (1498, 42, '盘亏出库', '42', 'erp_stock_record_biz_type', 0, '', '', '', '1', '2024-02-08 08:54:16', '1', '2024-02-08 08:54:16', 0);
INSERT INTO public.system_dict_data VALUES (1499, 43, '盘亏出库（作废）', '43', 'erp_stock_record_biz_type', 0, 'danger', '', '', '1', '2024-02-08 08:54:31', '1', '2024-02-16 19:40:46', 0);
INSERT INTO public.system_dict_data VALUES (1500, 50, '销售出库', '50', 'erp_stock_record_biz_type', 0, '', '', '', '1', '2024-02-11 21:47:25', '1', '2024-02-11 21:50:40', 0);
INSERT INTO public.system_dict_data VALUES (1501, 51, '销售出库（作废）', '51', 'erp_stock_record_biz_type', 0, 'danger', '', '', '1', '2024-02-11 21:47:37', '1', '2024-02-11 21:51:12', 0);
INSERT INTO public.system_dict_data VALUES (1502, 60, '销售退货入库', '60', 'erp_stock_record_biz_type', 0, '', '', '', '1', '2024-02-12 06:51:05', '1', '2024-02-12 06:51:05', 0);
INSERT INTO public.system_dict_data VALUES (1503, 61, '销售退货入库（作废）', '61', 'erp_stock_record_biz_type', 0, 'danger', '', '', '1', '2024-02-12 06:51:18', '1', '2024-02-12 06:51:18', 0);
INSERT INTO public.system_dict_data VALUES (1504, 70, '采购入库', '70', 'erp_stock_record_biz_type', 0, '', '', '', '1', '2024-02-16 13:10:02', '1', '2024-02-16 13:10:02', 0);
INSERT INTO public.system_dict_data VALUES (1505, 71, '采购入库（作废）', '71', 'erp_stock_record_biz_type', 0, 'danger', '', '', '1', '2024-02-16 13:10:10', '1', '2024-02-16 19:40:40', 0);
INSERT INTO public.system_dict_data VALUES (1506, 80, '采购退货出库', '80', 'erp_stock_record_biz_type', 0, '', '', '', '1', '2024-02-16 13:10:17', '1', '2024-02-16 13:10:17', 0);
INSERT INTO public.system_dict_data VALUES (1507, 81, '采购退货出库（作废）', '81', 'erp_stock_record_biz_type', 0, 'danger', '', '', '1', '2024-02-16 13:10:26', '1', '2024-02-16 19:40:33', 0);
INSERT INTO public.system_dict_data VALUES (1509, 3, '审批不通过', '3', 'bpm_process_instance_status', 0, 'danger', '', '', '1', '2024-03-16 16:12:06', '1', '2024-03-16 16:12:06', 0);
INSERT INTO public.system_dict_data VALUES (1510, 4, '已取消', '4', 'bpm_process_instance_status', 0, 'warning', '', '', '1', '2024-03-16 16:12:22', '1', '2024-03-16 16:12:22', 0);
INSERT INTO public.system_dict_data VALUES (1511, 5, '已退回', '5', 'bpm_task_status', 0, 'warning', '', '', '1', '2024-03-16 19:10:46', '1', '2024-03-08 22:41:40', 0);
INSERT INTO public.system_dict_data VALUES (1512, 6, '委派中', '6', 'bpm_task_status', 0, 'primary', '', '', '1', '2024-03-17 10:06:22', '1', '2024-03-08 22:41:40', 0);
INSERT INTO public.system_dict_data VALUES (1513, 7, '审批通过中', '7', 'bpm_task_status', 0, 'success', '', '', '1', '2024-03-17 10:06:47', '1', '2024-03-08 22:41:41', 0);
INSERT INTO public.system_dict_data VALUES (1514, 0, '待审批', '0', 'bpm_task_status', 0, 'info', '', '', '1', '2024-03-17 10:07:11', '1', '2024-03-08 22:41:42', 0);
INSERT INTO public.system_dict_data VALUES (1515, 35, '发起人自选', '35', 'bpm_task_candidate_strategy', 0, '', '', '', '1', '2024-03-22 19:45:16', '1', '2024-03-22 19:45:16', 0);
INSERT INTO public.system_dict_data VALUES (1516, 1, '执行监听器', 'execution', 'bpm_process_listener_type', 0, 'primary', '', '', '1', '2024-03-23 12:54:03', '1', '2024-03-23 19:14:19', 0);
INSERT INTO public.system_dict_data VALUES (1517, 1, '任务监听器', 'task', 'bpm_process_listener_type', 0, 'success', '', '', '1', '2024-03-23 12:54:13', '1', '2024-03-23 19:14:24', 0);
INSERT INTO public.system_dict_data VALUES (1526, 1, 'Java 类', 'class', 'bpm_process_listener_value_type', 0, 'primary', '', '', '1', '2024-03-23 15:08:45', '1', '2024-03-23 19:14:32', 0);
INSERT INTO public.system_dict_data VALUES (1527, 2, '表达式', 'expression', 'bpm_process_listener_value_type', 0, 'success', '', '', '1', '2024-03-23 15:09:06', '1', '2024-03-23 19:14:38', 0);
INSERT INTO public.system_dict_data VALUES (1528, 3, '代理表达式', 'delegateExpression', 'bpm_process_listener_value_type', 0, 'info', '', '', '1', '2024-03-23 15:11:23', '1', '2024-03-23 19:14:41', 0);
INSERT INTO public.system_dict_data VALUES (1529, 1, '天', '1', 'date_interval', 0, '', '', '', '1', '2024-03-29 22:50:26', '1', '2024-03-29 22:50:26', 0);
INSERT INTO public.system_dict_data VALUES (1530, 2, '周', '2', 'date_interval', 0, '', '', '', '1', '2024-03-29 22:50:36', '1', '2024-03-29 22:50:36', 0);
INSERT INTO public.system_dict_data VALUES (1531, 3, '月', '3', 'date_interval', 0, '', '', '', '1', '2024-03-29 22:50:46', '1', '2024-03-29 22:50:54', 0);
INSERT INTO public.system_dict_data VALUES (1532, 4, '季度', '4', 'date_interval', 0, '', '', '', '1', '2024-03-29 22:51:01', '1', '2024-03-29 22:51:01', 0);
INSERT INTO public.system_dict_data VALUES (1533, 5, '年', '5', 'date_interval', 0, '', '', '', '1', '2024-03-29 22:51:07', '1', '2024-03-29 22:51:07', 0);
INSERT INTO public.system_dict_data VALUES (1534, 1, '赢单', '1', 'crm_business_end_status_type', 0, 'success', '', '', '1', '2024-04-13 23:26:57', '1', '2024-04-13 23:26:57', 0);
INSERT INTO public.system_dict_data VALUES (1535, 2, '输单', '2', 'crm_business_end_status_type', 0, 'primary', '', '', '1', '2024-04-13 23:27:31', '1', '2024-04-13 23:27:31', 0);
INSERT INTO public.system_dict_data VALUES (1536, 3, '无效', '3', 'crm_business_end_status_type', 0, 'info', '', '', '1', '2024-04-13 23:27:59', '1', '2024-04-13 23:27:59', 0);
INSERT INTO public.system_dict_data VALUES (1537, 1, 'OpenAI', 'OpenAI', 'ai_platform', 0, '', '', '', '1', '2024-05-09 22:33:47', '1', '2024-05-09 22:58:46', 0);
INSERT INTO public.system_dict_data VALUES (1538, 2, 'Ollama', 'Ollama', 'ai_platform', 0, '', '', '', '1', '2024-05-17 23:02:55', '1', '2024-05-17 23:02:55', 0);
INSERT INTO public.system_dict_data VALUES (1539, 3, '文心一言', 'YiYan', 'ai_platform', 0, '', '', '', '1', '2024-05-18 09:24:20', '1', '2024-05-18 09:29:01', 0);
INSERT INTO public.system_dict_data VALUES (1540, 4, '讯飞星火', 'XingHuo', 'ai_platform', 0, '', '', '', '1', '2024-05-18 10:08:56', '1', '2024-05-18 10:08:56', 0);
INSERT INTO public.system_dict_data VALUES (1541, 5, '通义千问', 'TongYi', 'ai_platform', 0, '', '', '', '1', '2024-05-18 10:32:29', '1', '2024-07-06 15:42:29', 0);
INSERT INTO public.system_dict_data VALUES (1542, 6, 'StableDiffusion', 'StableDiffusion', 'ai_platform', 0, '', '', '', '1', '2024-06-01 15:09:31', '1', '2024-06-01 15:10:25', 0);
INSERT INTO public.system_dict_data VALUES (1543, 10, '进行中', '10', 'ai_image_status', 0, 'primary', '', '', '1', '2024-06-26 20:51:41', '1', '2024-06-26 20:52:48', 0);
INSERT INTO public.system_dict_data VALUES (1544, 20, '已完成', '20', 'ai_image_status', 0, 'success', '', '', '1', '2024-06-26 20:52:07', '1', '2024-06-26 20:52:41', 0);
INSERT INTO public.system_dict_data VALUES (1545, 30, '已失败', '30', 'ai_image_status', 0, 'warning', '', '', '1', '2024-06-26 20:52:25', '1', '2024-06-26 20:52:35', 0);
INSERT INTO public.system_dict_data VALUES (1546, 7, 'Midjourney', 'Midjourney', 'ai_platform', 0, '', '', '', '1', '2024-06-26 22:14:46', '1', '2024-06-26 22:14:46', 0);
INSERT INTO public.system_dict_data VALUES (1547, 10, '进行中', '10', 'ai_music_status', 0, 'primary', '', '', '1', '2024-06-27 22:45:22', '1', '2024-06-28 00:56:17', 0);
INSERT INTO public.system_dict_data VALUES (1548, 20, '已完成', '20', 'ai_music_status', 0, 'success', '', '', '1', '2024-06-27 22:45:33', '1', '2024-06-28 00:56:18', 0);
INSERT INTO public.system_dict_data VALUES (1549, 30, '已失败', '30', 'ai_music_status', 0, 'danger', '', '', '1', '2024-06-27 22:45:44', '1', '2024-06-28 00:56:19', 0);
INSERT INTO public.system_dict_data VALUES (1550, 1, '歌词模式', '1', 'ai_generate_mode', 0, '', '', '', '1', '2024-06-27 22:46:31', '1', '2024-06-28 01:22:25', 0);
INSERT INTO public.system_dict_data VALUES (1551, 2, '描述模式', '2', 'ai_generate_mode', 0, '', '', '', '1', '2024-06-27 22:46:37', '1', '2024-06-28 01:22:24', 0);
INSERT INTO public.system_dict_data VALUES (1552, 8, 'Suno', 'Suno', 'ai_platform', 0, '', '', '', '1', '2024-06-29 09:13:36', '1', '2024-06-29 09:13:41', 0);
INSERT INTO public.system_dict_data VALUES (1553, 9, 'DeepSeek', 'DeepSeek', 'ai_platform', 0, '', '', '', '1', '2024-07-06 12:04:30', '1', '2024-07-06 12:05:20', 0);
INSERT INTO public.system_dict_data VALUES (1554, 13, '智谱', 'ZhiPu', 'ai_platform', 0, '', '', '', '1', '2024-07-06 18:00:35', '1', '2025-02-24 20:18:41', 0);
INSERT INTO public.system_dict_data VALUES (1555, 4, '长', '4', 'ai_write_length', 0, '', '', '', '1', '2024-07-07 15:49:03', '1', '2024-07-07 15:49:03', 0);
INSERT INTO public.system_dict_data VALUES (1556, 5, '段落', '5', 'ai_write_format', 0, '', '', '', '1', '2024-07-07 15:49:54', '1', '2024-07-07 15:49:54', 0);
INSERT INTO public.system_dict_data VALUES (1557, 6, '文章', '6', 'ai_write_format', 0, '', '', '', '1', '2024-07-07 15:50:05', '1', '2024-07-07 15:50:05', 0);
INSERT INTO public.system_dict_data VALUES (1558, 7, '博客文章', '7', 'ai_write_format', 0, '', '', '', '1', '2024-07-07 15:50:23', '1', '2024-07-07 15:50:23', 0);
INSERT INTO public.system_dict_data VALUES (1559, 8, '想法', '8', 'ai_write_format', 0, '', '', '', '1', '2024-07-07 15:50:31', '1', '2024-07-07 15:50:31', 0);
INSERT INTO public.system_dict_data VALUES (1560, 9, '大纲', '9', 'ai_write_format', 0, '', '', '', '1', '2024-07-07 15:50:37', '1', '2024-07-07 15:50:37', 0);
INSERT INTO public.system_dict_data VALUES (1561, 1, '自动', '1', 'ai_write_tone', 0, '', '', '', '1', '2024-07-07 15:51:06', '1', '2024-07-07 15:51:06', 0);
INSERT INTO public.system_dict_data VALUES (1562, 2, '友善', '2', 'ai_write_tone', 0, '', '', '', '1', '2024-07-07 15:51:19', '1', '2024-07-07 15:51:19', 0);
INSERT INTO public.system_dict_data VALUES (1563, 3, '随意', '3', 'ai_write_tone', 0, '', '', '', '1', '2024-07-07 15:51:27', '1', '2024-07-07 15:51:27', 0);
INSERT INTO public.system_dict_data VALUES (1564, 4, '友好', '4', 'ai_write_tone', 0, '', '', '', '1', '2024-07-07 15:51:37', '1', '2024-07-07 15:51:37', 0);
INSERT INTO public.system_dict_data VALUES (1565, 5, '专业', '5', 'ai_write_tone', 0, '', '', '', '1', '2024-07-07 15:51:49', '1', '2024-07-07 15:52:02', 0);
INSERT INTO public.system_dict_data VALUES (1566, 6, '诙谐', '6', 'ai_write_tone', 0, '', '', '', '1', '2024-07-07 15:52:15', '1', '2024-07-07 15:52:15', 0);
INSERT INTO public.system_dict_data VALUES (1567, 7, '有趣', '7', 'ai_write_tone', 0, '', '', '', '1', '2024-07-07 15:52:24', '1', '2024-07-07 15:52:24', 0);
INSERT INTO public.system_dict_data VALUES (1568, 8, '正式', '8', 'ai_write_tone', 0, '', '', '', '1', '2024-07-07 15:54:33', '1', '2024-07-07 15:54:33', 0);
INSERT INTO public.system_dict_data VALUES (1570, 1, '自动', '1', 'ai_write_format', 0, '', '', '', '1', '2024-07-07 15:19:34', '1', '2024-07-07 15:19:34', 0);
INSERT INTO public.system_dict_data VALUES (1571, 2, '电子邮件', '2', 'ai_write_format', 0, '', '', '', '1', '2024-07-07 15:19:50', '1', '2024-07-07 15:49:30', 0);
INSERT INTO public.system_dict_data VALUES (1572, 3, '消息', '3', 'ai_write_format', 0, '', '', '', '1', '2024-07-07 15:20:01', '1', '2024-07-07 15:49:38', 0);
INSERT INTO public.system_dict_data VALUES (1573, 4, '评论', '4', 'ai_write_format', 0, '', '', '', '1', '2024-07-07 15:20:13', '1', '2024-07-07 15:49:45', 0);
INSERT INTO public.system_dict_data VALUES (1574, 1, '自动', '1', 'ai_write_language', 0, '', '', '', '1', '2024-07-07 15:44:18', '1', '2024-07-07 15:44:18', 0);
INSERT INTO public.system_dict_data VALUES (1575, 2, '中文', '2', 'ai_write_language', 0, '', '', '', '1', '2024-07-07 15:44:28', '1', '2024-07-07 15:44:28', 0);
INSERT INTO public.system_dict_data VALUES (1576, 3, '英文', '3', 'ai_write_language', 0, '', '', '', '1', '2024-07-07 15:44:37', '1', '2024-07-07 15:44:37', 0);
INSERT INTO public.system_dict_data VALUES (1577, 4, '韩语', '4', 'ai_write_language', 0, '', '', '', '1', '2024-07-07 15:46:28', '1', '2024-07-07 15:46:28', 0);
INSERT INTO public.system_dict_data VALUES (1578, 5, '日语', '5', 'ai_write_language', 0, '', '', '', '1', '2024-07-07 15:46:44', '1', '2024-07-07 15:46:44', 0);
INSERT INTO public.system_dict_data VALUES (1579, 1, '自动', '1', 'ai_write_length', 0, '', '', '', '1', '2024-07-07 15:48:34', '1', '2024-07-07 15:48:34', 0);
INSERT INTO public.system_dict_data VALUES (1580, 2, '短', '2', 'ai_write_length', 0, '', '', '', '1', '2024-07-07 15:48:44', '1', '2024-07-07 15:48:44', 0);
INSERT INTO public.system_dict_data VALUES (1581, 3, '中等', '3', 'ai_write_length', 0, '', '', '', '1', '2024-07-07 15:48:52', '1', '2024-07-07 15:48:52', 0);
INSERT INTO public.system_dict_data VALUES (1584, 1, '撰写', '1', 'ai_write_type', 0, '', '', '', '1', '2024-07-10 21:26:00', '1', '2024-07-10 21:26:00', 0);
INSERT INTO public.system_dict_data VALUES (1585, 2, '回复', '2', 'ai_write_type', 0, '', '', '', '1', '2024-07-10 21:26:06', '1', '2024-07-10 21:26:06', 0);
INSERT INTO public.system_dict_data VALUES (1586, 2, '腾讯云', 'TENCENT', 'system_sms_channel_code', 0, '', '', '', '1', '2024-07-22 22:23:16', '1', '2024-07-22 22:23:16', 0);
INSERT INTO public.system_dict_data VALUES (1587, 3, '华为云', 'HUAWEI', 'system_sms_channel_code', 0, '', '', '', '1', '2024-07-22 22:23:46', '1', '2024-07-22 22:23:53', 0);
INSERT INTO public.system_dict_data VALUES (1588, 1, 'OpenAI 微软', 'AzureOpenAI', 'ai_platform', 0, '', '', '', '1', '2024-08-10 14:07:41', '1', '2024-08-10 14:07:41', 0);
INSERT INTO public.system_dict_data VALUES (1589, 10, 'BPMN 设计器', '10', 'bpm_model_type', 0, 'primary', '', '', '1', '2024-08-26 15:22:17', '1', '2024-08-26 16:46:02', 0);
INSERT INTO public.system_dict_data VALUES (1590, 20, 'SIMPLE 设计器', '20', 'bpm_model_type', 0, 'success', '', '', '1', '2024-08-26 15:22:27', '1', '2024-08-26 16:45:58', 0);
INSERT INTO public.system_dict_data VALUES (1591, 4, '七牛云', 'QINIU', 'system_sms_channel_code', 0, '', '', '', '1', '2024-08-31 08:45:03', '1', '2024-08-31 08:45:24', 0);
INSERT INTO public.system_dict_data VALUES (1592, 3, '新人券', '3', 'promotion_coupon_take_type', 0, 'info', '', '新人注册后，自动发放', '1', '2024-09-03 11:57:16', '1', '2024-09-03 11:57:28', 0);
INSERT INTO public.system_dict_data VALUES (1593, 5, '微信零钱', '5', 'brokerage_withdraw_type', 0, '', '', 'API 打款', '1', '2024-10-13 11:06:48', '1', '2025-05-10 08:24:55', 0);
INSERT INTO public.system_dict_data VALUES (1683, 10, '字节豆包', 'DouBao', 'ai_platform', 0, '', '', '', '1', '2025-02-23 19:51:40', '1', '2025-02-23 19:52:02', 0);
INSERT INTO public.system_dict_data VALUES (1684, 11, '腾讯混元', 'HunYuan', 'ai_platform', 0, '', '', '', '1', '2025-02-23 20:58:04', '1', '2025-02-23 20:58:04', 0);
INSERT INTO public.system_dict_data VALUES (1685, 12, '硅基流动', 'SiliconFlow', 'ai_platform', 0, '', '', '', '1', '2025-02-24 20:19:09', '1', '2025-02-24 20:19:09', 0);
INSERT INTO public.system_dict_data VALUES (1686, 1, '聊天', '1', 'ai_model_type', 0, '', '', '', '1', '2025-03-03 12:26:34', '1', '2025-03-03 12:26:34', 0);
INSERT INTO public.system_dict_data VALUES (1687, 2, '图像', '2', 'ai_model_type', 0, '', '', '', '1', '2025-03-03 12:27:23', '1', '2025-03-03 12:27:23', 0);
INSERT INTO public.system_dict_data VALUES (1688, 3, '音频', '3', 'ai_model_type', 0, '', '', '', '1', '2025-03-03 12:27:51', '1', '2025-03-03 12:27:51', 0);
INSERT INTO public.system_dict_data VALUES (1689, 4, '视频', '4', 'ai_model_type', 0, '', '', '', '1', '2025-03-03 12:28:03', '1', '2025-03-03 12:28:03', 0);
INSERT INTO public.system_dict_data VALUES (1690, 5, '向量', '5', 'ai_model_type', 0, '', '', '', '1', '2025-03-03 12:28:15', '1', '2025-03-03 12:28:15', 0);
INSERT INTO public.system_dict_data VALUES (1691, 6, '重排', '6', 'ai_model_type', 0, '', '', '', '1', '2025-03-03 12:28:26', '1', '2025-03-03 12:28:26', 0);
INSERT INTO public.system_dict_data VALUES (1692, 14, 'MiniMax', 'MiniMax', 'ai_platform', 0, '', '', '', '1', '2025-03-11 20:04:51', '1', '2025-03-11 20:04:51', 0);
INSERT INTO public.system_dict_data VALUES (1693, 15, '月之暗面', 'Moonshot', 'ai_platform', 0, '', '', '', '1', '2025-03-11 20:05:08', '1', '2025-11-24 07:17:39', 0);
INSERT INTO public.system_dict_data VALUES (2002, 0, '直连设备', '0', 'iot_product_device_type', 0, 'default', '', '', '1', '2024-08-10 11:54:58', '1', '2025-03-17 09:28:22', 0);
INSERT INTO public.system_dict_data VALUES (2003, 2, '网关设备', '2', 'iot_product_device_type', 0, 'default', '', '', '1', '2024-08-10 11:55:08', '1', '2025-03-17 09:28:28', 0);
INSERT INTO public.system_dict_data VALUES (2004, 1, '网关子设备', '1', 'iot_product_device_type', 0, 'default', '', '', '1', '2024-08-10 11:55:20', '1', '2025-03-17 09:28:31', 0);
INSERT INTO public.system_dict_data VALUES (2005, 1, '已发布', '1', 'iot_product_status', 0, 'success', '', '', '1', '2024-08-10 12:10:33', '1', '2025-03-17 09:28:34', 0);
INSERT INTO public.system_dict_data VALUES (2006, 0, '开发中', '0', 'iot_product_status', 0, 'default', '', '', '1', '2024-08-10 14:19:18', '1', '2025-03-17 09:28:39', 0);
INSERT INTO public.system_dict_data VALUES (2009, 0, 'Wi-Fi', '0', 'iot_net_type', 0, '', '', '', '1', '2024-09-06 22:04:47', '1', '2025-03-17 09:28:47', 0);
INSERT INTO public.system_dict_data VALUES (2010, 1, '移动网络', '1', 'iot_net_type', 0, '', '', '', '1', '2024-09-06 22:05:14', '1', '2025-06-12 23:27:19', 0);
INSERT INTO public.system_dict_data VALUES (2011, 2, '以太网', '2', 'iot_net_type', 0, '', '', '', '1', '2024-09-06 22:05:35', '1', '2025-03-17 09:28:51', 0);
INSERT INTO public.system_dict_data VALUES (2012, 3, '其他', '3', 'iot_net_type', 0, '', '', '', '1', '2024-09-06 22:05:52', '1', '2025-03-17 09:28:54', 0);
INSERT INTO public.system_dict_data VALUES (2018, 0, '未激活', '0', 'iot_device_state', 0, '', '', '', '1', '2024-09-21 08:13:34', '1', '2025-03-17 09:29:09', 0);
INSERT INTO public.system_dict_data VALUES (2019, 1, '在线', '1', 'iot_device_state', 0, '', '', '', '1', '2024-09-21 08:13:48', '1', '2025-03-17 09:29:12', 0);
INSERT INTO public.system_dict_data VALUES (2020, 2, '离线', '2', 'iot_device_state', 0, '', '', '', '1', '2024-09-21 08:13:59', '1', '2025-03-17 09:29:14', 0);
INSERT INTO public.system_dict_data VALUES (2021, 1, '属性', '1', 'iot_thing_model_type', 0, '', '', '', '1', '2024-09-29 20:03:01', '1', '2025-03-17 09:29:24', 0);
INSERT INTO public.system_dict_data VALUES (2022, 2, '服务', '2', 'iot_thing_model_type', 0, '', '', '', '1', '2024-09-29 20:03:11', '1', '2025-03-17 09:29:27', 0);
INSERT INTO public.system_dict_data VALUES (2023, 3, '事件', '3', 'iot_thing_model_type', 0, '', '', '', '1', '2024-09-29 20:03:20', '1', '2025-03-17 09:29:29', 0);
INSERT INTO public.system_dict_data VALUES (2030, 1, '升每分钟', 'L/min', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:34:24', 0);
INSERT INTO public.system_dict_data VALUES (2031, 2, '毫克每千克', 'mg/kg', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:34:27', 0);
INSERT INTO public.system_dict_data VALUES (2032, 3, '浊度', 'NTU', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:34:31', 0);
INSERT INTO public.system_dict_data VALUES (2033, 4, 'PH值', 'pH', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:34:36', 0);
INSERT INTO public.system_dict_data VALUES (2034, 5, '土壤EC值', 'dS/m', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:34:43', 0);
INSERT INTO public.system_dict_data VALUES (2035, 6, '太阳总辐射', 'W/㎡', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:36:20', 0);
INSERT INTO public.system_dict_data VALUES (2036, 7, '降雨量', 'mm/hour', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:36:24', 0);
INSERT INTO public.system_dict_data VALUES (2037, 8, '乏', 'var', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:36:27', 0);
INSERT INTO public.system_dict_data VALUES (2038, 9, '厘泊', 'cP', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:36:33', 0);
INSERT INTO public.system_dict_data VALUES (2039, 10, '饱和度', 'aw', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:11', 0);
INSERT INTO public.system_dict_data VALUES (2040, 11, '个', 'pcs', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:19', 0);
INSERT INTO public.system_dict_data VALUES (2041, 12, '厘斯', 'cst', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:22', 0);
INSERT INTO public.system_dict_data VALUES (2042, 13, '巴', 'bar', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:24', 0);
INSERT INTO public.system_dict_data VALUES (2043, 14, '纳克每升', 'ppt', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:27', 0);
INSERT INTO public.system_dict_data VALUES (2044, 15, '十亿分之一', 'ppb', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2026-04-05 15:53:29', 0);
INSERT INTO public.system_dict_data VALUES (2045, 16, '微西每厘米', 'uS/cm', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:34', 0);
INSERT INTO public.system_dict_data VALUES (2046, 17, '牛顿每库仑', 'N/C', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:38', 0);
INSERT INTO public.system_dict_data VALUES (2047, 18, '伏特每米', 'V/m', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:43', 0);
INSERT INTO public.system_dict_data VALUES (2048, 19, '滴速', 'ml/min', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:46', 0);
INSERT INTO public.system_dict_data VALUES (2049, 20, '毫米汞柱', 'mmHg', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:48', 0);
INSERT INTO public.system_dict_data VALUES (2050, 21, '血糖', 'mmol/L', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:37:54', 0);
INSERT INTO public.system_dict_data VALUES (2051, 22, '毫米每秒', 'mm/s', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:38:02', 0);
INSERT INTO public.system_dict_data VALUES (2052, 23, '转每米', 'turn/m', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2026-04-05 15:53:29', 0);
INSERT INTO public.system_dict_data VALUES (2053, 24, '次', 'count', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:38:09', 0);
INSERT INTO public.system_dict_data VALUES (2054, 25, '档', 'gear', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:38:11', 0);
INSERT INTO public.system_dict_data VALUES (2055, 26, '步', 'stepCount', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:38:13', 0);
INSERT INTO public.system_dict_data VALUES (2056, 27, '标准立方米每小时', 'Nm3/h', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:38:15', 0);
INSERT INTO public.system_dict_data VALUES (2057, 28, '千伏', 'kV', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:38:20', 0);
INSERT INTO public.system_dict_data VALUES (2058, 29, '千伏安', 'kVA', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:38:24', 0);
INSERT INTO public.system_dict_data VALUES (2060, 30, '千乏', 'kVar', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2061, 31, '微瓦每平方厘米', 'uw/cm2', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2062, 32, '只', '只', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2063, 33, '相对湿度', '%RH', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2064, 34, '立方米每秒', 'm³/s', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2065, 35, '公斤每秒', 'kg/s', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2066, 36, '转每分钟', 'r/min', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2067, 37, '吨每小时', 't/h', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2068, 38, '千卡每小时', 'KCL/h', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2069, 39, '升每秒', 'L/s', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2070, 40, '兆帕', 'MPa', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2026-04-05 15:53:29', 0);
INSERT INTO public.system_dict_data VALUES (2071, 41, '立方米每小时', 'm³/h', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2072, 42, '千乏时', 'kvarh', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2073, 43, '微克每升', 'μg/L', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2074, 44, '千卡路里', 'kcal', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2075, 45, '吉字节', 'GB', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2076, 46, '兆字节', 'MB', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2077, 47, '千字节', 'KB', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2078, 48, '字节', 'B', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2079, 49, '微克每平方分米每天', 'μg/(d㎡·d)', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2080, 50, '无', '', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2081, 51, '百万分率', 'ppm', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2082, 52, '像素', 'pixel', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2083, 53, '照度', 'Lux', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2084, 54, '重力加速度', 'grav', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2085, 55, '分贝', 'dB', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2086, 56, '百分比', '%', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2087, 57, '流明', 'lm', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2088, 58, '比特', 'bit', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2089, 59, '克每毫升', 'g/mL', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2090, 60, '克每升', 'g/L', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2091, 61, '毫克每升', 'mg/L', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2092, 62, '微克每立方米', 'μg/m³', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2093, 63, '毫克每立方米', 'mg/m³', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2094, 64, '克每立方米', 'g/m³', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2095, 65, '千克每立方米', 'kg/m³', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2096, 66, '纳法', 'nF', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2097, 67, '皮法', 'pF', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2098, 68, '微法', 'μF', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2099, 69, '法拉', 'F', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2100, 70, '欧姆', 'Ω', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2101, 71, '微安', 'μA', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2102, 72, '毫安', 'mA', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2103, 73, '千安', 'kA', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2104, 74, '安培', 'A', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2105, 75, '毫伏', 'mV', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2106, 76, '伏特', 'V', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2107, 77, '毫秒', 'ms', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2108, 78, '秒', 's', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2109, 79, '分钟', 'min', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2110, 80, '小时', 'h', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2111, 81, '日', 'day', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2112, 82, '周', 'week', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2113, 83, '月', 'month', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2114, 84, '年', 'year', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2115, 85, '节', 'kn', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2116, 86, '千米每小时', 'km/h', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2117, 87, '米每秒', 'm/s', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2118, 88, '角秒', '″', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2026-04-05 15:53:29', 0);
INSERT INTO public.system_dict_data VALUES (2119, 89, '分', '′', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2120, 90, '度', '°', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2121, 91, '弧度', 'rad', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2122, 92, '赫兹', 'Hz', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2123, 93, '微瓦', 'μW', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2124, 94, '毫瓦', 'mW', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2125, 95, '千瓦特', 'kW', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2126, 96, '瓦特', 'W', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2127, 97, '卡路里', 'cal', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2128, 98, '千瓦时', 'kW·h', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2129, 99, '瓦时', 'Wh', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2130, 100, '电子伏', 'eV', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2131, 101, '千焦', 'kJ', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2132, 102, '焦耳', 'J', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2133, 103, '华氏度', '℉', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2134, 104, '开尔文', 'K', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2135, 105, '吨', 't', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2136, 106, '摄氏度', '°C', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2137, 107, '毫帕', '1e-3Pa', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2026-04-05 15:53:29', 0);
INSERT INTO public.system_dict_data VALUES (2138, 108, '百帕', 'hPa', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2139, 109, '千帕', 'kPa', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2140, 110, '帕斯卡', 'Pa', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2141, 111, '毫克', 'mg', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2142, 112, '克', 'g', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2143, 113, '千克', 'kg', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2144, 114, '牛', 'N', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2145, 115, '毫升', 'mL', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2146, 116, '升', 'L', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2147, 117, '立方毫米', 'mm³', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2148, 118, '立方厘米', 'cm³', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2149, 119, '立方千米', 'km³', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2150, 120, '立方米', 'm³', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2151, 121, '公顷', 'h㎡', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2152, 122, '平方厘米', 'c㎡', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2153, 123, '平方毫米', 'm㎡', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2154, 124, '平方千米', 'k㎡', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2155, 125, '平方米', '㎡', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2156, 126, '纳米', 'nm', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2157, 127, '微米', 'μm', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2158, 128, '毫米', 'mm', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2159, 129, '厘米', 'cm', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2160, 130, '分米', 'dm', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2161, 131, '千米', 'km', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2162, 132, '米', 'm', 'iot_thing_model_unit', 0, '', '', '', '1', '2024-12-13 11:08:41', '1', '2025-03-17 09:40:46', 0);
INSERT INTO public.system_dict_data VALUES (2165, 1, 'HTTP', '1', 'iot_data_sink_type_enum', 0, 'default', '', '', '1', '2025-03-09 12:39:54', '1', '2025-06-24 12:44:47', 0);
INSERT INTO public.system_dict_data VALUES (2166, 2, 'TCP', '2', 'iot_data_sink_type_enum', 0, 'default', '', '', '1', '2025-03-09 12:40:06', '1', '2025-06-24 12:44:46', 0);
INSERT INTO public.system_dict_data VALUES (2167, 3, 'WebSocket', '3', 'iot_data_sink_type_enum', 0, 'default', '', '', '1', '2025-03-09 12:40:24', '1', '2025-06-24 12:44:45', 0);
INSERT INTO public.system_dict_data VALUES (2168, 10, 'MQTT', '10', 'iot_data_sink_type_enum', 0, 'default', '', '', '1', '2025-03-09 12:40:37', '1', '2025-06-24 12:44:44', 0);
INSERT INTO public.system_dict_data VALUES (2169, 20, 'Database', '20', 'iot_data_sink_type_enum', 0, 'default', '', '', '1', '2025-03-09 12:41:05', '1', '2025-06-24 12:44:44', 0);
INSERT INTO public.system_dict_data VALUES (2170, 21, 'Redis Stream', '21', 'iot_data_sink_type_enum', 0, 'default', '', '', '1', '2025-03-09 12:41:18', '1', '2025-06-24 12:44:43', 0);
INSERT INTO public.system_dict_data VALUES (2171, 30, 'RocketMQ', '30', 'iot_data_sink_type_enum', 0, 'default', '', '', '1', '2025-03-09 12:41:30', '1', '2025-06-24 12:44:42', 0);
INSERT INTO public.system_dict_data VALUES (2172, 31, 'RabbitMQ', '31', 'iot_data_sink_type_enum', 0, 'default', '', '', '1', '2025-03-09 12:41:47', '1', '2025-06-24 12:44:41', 0);
INSERT INTO public.system_dict_data VALUES (2173, 32, 'Kafka', '32', 'iot_data_sink_type_enum', 0, 'default', '', '', '1', '2025-03-09 12:41:59', '1', '2025-06-24 12:44:39', 0);
INSERT INTO public.system_dict_data VALUES (2174, 1, '设备上下线变更', '1', 'iot_rule_scene_trigger_type_enum', 0, 'primary', '', '', '1', '2025-03-20 15:00:01', '"1"', '2025-07-06 10:28:16', 0);
INSERT INTO public.system_dict_data VALUES (2175, 2, '物模型属性上报', '2', 'iot_rule_scene_trigger_type_enum', 0, 'primary', '', '', '1', '2025-03-20 15:00:09', '"1"', '2025-07-06 10:28:22', 0);
INSERT INTO public.system_dict_data VALUES (2176, 1, '设备状态', 'state', 'iot_device_message_type_enum', 0, 'primary', '', '', '1', '2025-03-20 15:24:58', '1', '2025-03-20 15:24:58', 0);
INSERT INTO public.system_dict_data VALUES (2177, 2, '设备属性', 'property', 'iot_device_message_type_enum', 0, 'primary', '', '', '1', '2025-03-20 15:25:09', '1', '2025-03-20 15:25:09', 0);
INSERT INTO public.system_dict_data VALUES (2178, 3, '设备事件', 'event', 'iot_device_message_type_enum', 0, 'primary', '', '', '1', '2025-03-20 15:25:23', '1', '2025-03-20 15:25:23', 0);
INSERT INTO public.system_dict_data VALUES (2179, 4, '设备服务', 'service', 'iot_device_message_type_enum', 0, 'primary', '', '', '1', '2025-03-20 15:25:39', '1', '2025-03-20 15:25:39', 0);
INSERT INTO public.system_dict_data VALUES (2180, 5, '设备配置', 'config', 'iot_device_message_type_enum', 0, 'primary', '', '', '1', '2025-03-20 15:25:51', '1', '2025-03-20 15:25:57', 0);
INSERT INTO public.system_dict_data VALUES (2181, 6, '设备 OTA', 'ota', 'iot_device_message_type_enum', 0, 'primary', '', '', '1', '2025-03-20 15:26:17', '1', '2025-03-20 15:26:17', 0);
INSERT INTO public.system_dict_data VALUES (2182, 7, '设备注册', 'register', 'iot_device_message_type_enum', 0, 'primary', '', '', '1', '2025-03-20 15:26:35', '1', '2025-03-20 15:26:35', 0);
INSERT INTO public.system_dict_data VALUES (2183, 8, '设备拓扑', 'topology', 'iot_device_message_type_enum', 0, 'primary', '', '', '1', '2025-03-20 15:26:46', '1', '2025-03-20 15:26:46', 0);
INSERT INTO public.system_dict_data VALUES (2184, 1, '设备属性设置', '1', 'iot_rule_scene_action_type_enum', 0, 'primary', '', '', '1', '2025-03-28 15:27:12', '"1"', '2025-07-06 10:37:33', 0);
INSERT INTO public.system_dict_data VALUES (2185, 2, '设备服务调用', '2', 'iot_rule_scene_action_type_enum', 0, 'primary', '', '', '1', '2025-03-28 15:27:25', '"1"', '2025-07-06 10:37:41', 0);
INSERT INTO public.system_dict_data VALUES (2186, 100, '告警触发', '100', 'iot_rule_scene_action_type_enum', 0, 'primary', '', '', '1', '2025-03-28 15:27:35', '"1"', '2025-07-06 10:37:50', 0);
INSERT INTO public.system_dict_data VALUES (3000, 16, '百川智能', 'BaiChuan', 'ai_platform', 0, '', '', '', '1', '2025-03-23 12:15:46', '1', '2025-03-23 12:15:46', 0);
INSERT INTO public.system_dict_data VALUES (3001, 40, 'Vben5.0 Ant Design Schema 模版', '40', 'infra_codegen_front_type', 0, '', '', NULL, '1', '2025-04-23 21:47:47', '1', '2025-09-04 23:25:12', 0);
INSERT INTO public.system_dict_data VALUES (3002, 6, '支付宝余额', '6', 'brokerage_withdraw_type', 0, '', '', 'API 打款', '1', '2025-05-10 08:24:49', '1', '2025-05-10 08:24:49', 0);
INSERT INTO public.system_dict_data VALUES (3004, 3, 'WARN', '3', 'iot_alert_level', 0, 'warning', '', '', '1', '2025-06-27 20:32:22', '1', '2025-06-27 20:34:31', 0);
INSERT INTO public.system_dict_data VALUES (3005, 1, 'INFO', '1', 'iot_alert_level', 0, 'primary', '', '', '1', '2025-06-27 20:33:28', '1', '2025-06-27 20:34:35', 0);
INSERT INTO public.system_dict_data VALUES (3006, 5, 'ERROR', '5', 'iot_alert_level', 0, 'danger', '', '', '1', '2025-06-27 20:33:50', '1', '2025-06-27 20:33:50', 0);
INSERT INTO public.system_dict_data VALUES (3007, 1, '短信', '1', 'iot_alert_receive_type', 0, '', '', '', '1', '2025-06-27 22:49:30', '1', '2025-06-27 22:49:30', 0);
INSERT INTO public.system_dict_data VALUES (3008, 2, '邮箱', '2', 'iot_alert_receive_type', 0, '', '', '', '1', '2025-06-27 22:49:39', '1', '2025-06-27 22:50:07', 0);
INSERT INTO public.system_dict_data VALUES (3009, 3, '站内信', '3', 'iot_alert_receive_type', 0, '', '', '', '1', '2025-06-27 22:50:20', '1', '2025-06-27 22:50:20', 0);
INSERT INTO public.system_dict_data VALUES (3010, 1, '全部设备', '1', 'iot_ota_task_device_scope', 0, '', '', '', '1', '2025-07-02 09:43:09', '1', '2025-07-02 09:43:09', 0);
INSERT INTO public.system_dict_data VALUES (3011, 2, '指定设备', '2', 'iot_ota_task_device_scope', 0, '', '', '', '1', '2025-07-02 09:43:15', '1', '2025-07-02 09:43:15', 0);
INSERT INTO public.system_dict_data VALUES (3012, 10, '进行中', '10', 'iot_ota_task_status', 0, 'primary', '', '', '1', '2025-07-02 09:44:01', '"1"', '2025-07-02 09:44:21', 0);
INSERT INTO public.system_dict_data VALUES (3013, 20, '已结束', '20', 'iot_ota_task_status', 0, 'success', '', '', '1', '2025-07-02 09:44:14', '"1"', '2025-07-02 23:56:12', 0);
INSERT INTO public.system_dict_data VALUES (3014, 30, '已取消', '30', 'iot_ota_task_status', 0, 'danger', '', '', '1', '2025-07-02 09:44:36', '1', '2025-07-02 09:44:36', 0);
INSERT INTO public.system_dict_data VALUES (3015, 0, '待推送', '0', 'iot_ota_task_record_status', 0, '', '', '', '1', '2025-07-02 09:45:16', '1', '2025-07-02 09:45:16', 0);
INSERT INTO public.system_dict_data VALUES (3016, 10, '已推送', '10', 'iot_ota_task_record_status', 0, '', '', '', '1', '2025-07-02 09:45:25', '1', '2025-07-02 09:45:25', 0);
INSERT INTO public.system_dict_data VALUES (3017, 20, '升级中', '20', 'iot_ota_task_record_status', 0, 'primary', '', '', '1', '2025-07-02 09:45:37', '1', '2025-07-02 09:45:37', 0);
INSERT INTO public.system_dict_data VALUES (3018, 30, '升级成功', '30', 'iot_ota_task_record_status', 0, 'success', '', '', '1', '2025-07-02 09:45:47', '1', '2025-07-02 09:45:47', 0);
INSERT INTO public.system_dict_data VALUES (3019, 40, '升级失败', '40', 'iot_ota_task_record_status', 0, 'danger', '', '', '1', '2025-07-02 09:46:02', '1', '2025-07-02 09:46:02', 0);
INSERT INTO public.system_dict_data VALUES (3020, 50, '升级取消', '50', 'iot_ota_task_record_status', 0, 'warning', '', '', '1', '2025-07-02 09:46:09', '"1"', '2025-07-02 09:46:27', 0);
INSERT INTO public.system_dict_data VALUES (3024, 3, '设备事件上报', '3', 'iot_rule_scene_trigger_type_enum', 0, '', '', '', '1', '2025-07-06 10:28:29', '1', '2025-07-06 10:28:29', 0);
INSERT INTO public.system_dict_data VALUES (3025, 4, '设备服务调用', '4', 'iot_rule_scene_trigger_type_enum', 0, '', '', '', '1', '2025-07-06 10:28:35', '1', '2025-07-06 10:28:35', 0);
INSERT INTO public.system_dict_data VALUES (3026, 100, '定时触发', '100', 'iot_rule_scene_trigger_type_enum', 0, '', '', '', '1', '2025-07-06 10:28:48', '1', '2025-07-06 10:28:48', 0);
INSERT INTO public.system_dict_data VALUES (3027, 101, '告警恢复', '101', 'iot_rule_scene_action_type_enum', 0, '', '', '', '1', '2025-07-06 10:37:57', '1', '2025-07-06 10:37:57', 0);
INSERT INTO public.system_dict_data VALUES (3028, 2, 'Anthropic', 'Anthropic', 'ai_platform', 0, '', '', '', '1', '2025-08-21 22:54:24', '1', '2025-08-21 22:57:58', 0);
INSERT INTO public.system_dict_data VALUES (3029, 2, '谷歌 Gemini', 'Gemini', 'ai_platform', 0, '', '', '', '1', '2025-08-22 22:39:35', '1', '2025-08-22 22:44:49', 0);
INSERT INTO public.system_dict_data VALUES (3030, 1, '文件系统', 'filesystem', 'ai_mcp_client_name', 0, '', '', '', '1', '2025-08-28 13:58:43', '1', '2025-08-28 21:19:42', 0);
INSERT INTO public.system_dict_data VALUES (3031, 41, 'Vben5.0 Ant Design 标准模版', '41', 'infra_codegen_front_type', 0, '', '', '', '1', '2025-09-04 23:26:07', '1', '2025-09-04 23:26:07', 0);
INSERT INTO public.system_dict_data VALUES (3032, 50, 'Vben5.0 Element Plus Schema 模版', '50', 'infra_codegen_front_type', 0, '', '', '', '1', '2025-09-04 23:26:38', '1', '2025-09-04 23:26:38', 0);
INSERT INTO public.system_dict_data VALUES (3033, 51, 'Vben5.0 Element Plus 标准模版', '51', 'infra_codegen_front_type', 0, '', '', '', '1', '2025-09-04 23:26:49', '1', '2025-09-04 23:26:49', 0);
INSERT INTO public.system_dict_data VALUES (3034, 1, 'ttt', 'tt', 'iot_ota_task_record_status', 0, 'success', '', NULL, '1', '2025-09-06 00:02:21', '1', '2025-09-06 00:02:31', 0);
INSERT INTO public.system_dict_data VALUES (3035, 40, '支付宝小程序', '40', 'system_social_type', 0, '', '', '', '1', '2023-11-04 13:05:38', '1', '2023-11-04 13:07:16', 0);
INSERT INTO public.system_dict_data VALUES (3036, 60, 'Admin Uniapp 移动端', '60', 'infra_codegen_front_type', 0, '', '', NULL, '1', '2025-12-16 19:25:51', '1', '2025-12-17 09:46:15', 0);
INSERT INTO public.system_dict_data VALUES (3037, 42, 'Vben5.0 Antdv Next Schema 模版', '42', 'infra_codegen_front_type', 0, '', '', '', '1', '2026-07-14 04:45:56.4759', '1', '2026-07-14 04:45:56.4759', 0);
INSERT INTO public.system_dict_data VALUES (3038, 43, 'Vben5.0 Antdv Next 标准模版', '43', 'infra_codegen_front_type', 0, '', '', '', '1', '2026-07-14 04:45:56.4759', '1', '2026-07-14 04:45:56.4759', 0);
INSERT INTO public.system_dict_data VALUES (3040, 1, 'UDP', 'udp', 'iot_protocol_type', 0, '', '', 'UDP 协议', '1', '2026-02-04 00:32:47', '1', '2026-02-04 00:32:47', 0);
INSERT INTO public.system_dict_data VALUES (3041, 2, 'WebSocket', 'websocket', 'iot_protocol_type', 0, '', '', 'WebSocket 协议', '1', '2026-02-04 00:32:55', '1', '2026-02-04 00:32:55', 0);
INSERT INTO public.system_dict_data VALUES (3042, 3, 'HTTP', 'http', 'iot_protocol_type', 0, '', '', 'HTTP 协议', '1', '2026-02-04 00:32:55', '1', '2026-02-04 00:32:55', 0);
INSERT INTO public.system_dict_data VALUES (3043, 4, 'MQTT', 'mqtt', 'iot_protocol_type', 0, 'success', '', 'MQTT 协议', '1', '2026-02-04 00:32:55', '1', '2026-02-04 00:32:55', 0);
INSERT INTO public.system_dict_data VALUES (3044, 5, 'EMQX', 'emqx', 'iot_protocol_type', 0, 'success', '', 'EMQX 协议', '1', '2026-02-04 00:32:55', '1', '2026-02-04 00:32:55', 0);
INSERT INTO public.system_dict_data VALUES (3045, 6, 'CoAP', 'coap', 'iot_protocol_type', 0, '', '', 'CoAP 协议', '1', '2026-02-04 00:32:55', '1', '2026-02-04 00:32:55', 0);
INSERT INTO public.system_dict_data VALUES (3046, 7, 'Modbus TCP Server', 'modbus_tcp_server', 'iot_protocol_type', 0, '', '', 'Modbus TCP Server 协议', '1', '2026-02-04 00:32:55', '1', '2026-02-12 15:16:45', 0);
INSERT INTO public.system_dict_data VALUES (3047, 0, 'JSON', 'json', 'iot_serialize_type', 0, 'success', '', 'JSON 格式', '1', '2026-02-04 00:33:19', '1', '2026-02-04 00:33:19', 0);
INSERT INTO public.system_dict_data VALUES (3048, 1, '二进制', 'binary', 'iot_serialize_type', 0, 'warning', '', '二进制格式', '1', '2026-02-04 00:33:19', '1', '2026-02-04 00:33:19', 0);
INSERT INTO public.system_dict_data VALUES (3049, 8, 'Modbus TCP Client', 'modbus_tcp_client', 'iot_protocol_type', 0, '', '', 'Modbus TCP Client 协议', '1', '2026-02-08 18:29:46', '1', '2026-02-12 15:16:32', 0);
INSERT INTO public.system_dict_data VALUES (3050, 2, '边缘采集', '2', 'iot_modbus_mode', 0, 'success', '', '设备主动上报数据，无需轮询', '1', '2025-06-12 22:56:06', '1', '2026-02-09 13:03:23', 0);
INSERT INTO public.system_dict_data VALUES (3051, 1, 'Modbus TCP', '1', 'iot_modbus_frame_format', 0, 'default', '', 'MBAP 头部格式', '1', '2025-06-12 22:56:06', '1', '2025-06-12 22:56:06', 0);
INSERT INTO public.system_dict_data VALUES (3052, 2, 'Modbus RTU', '2', 'iot_modbus_frame_format', 0, 'warning', '', 'CRC16 校验格式', '1', '2025-06-12 22:56:06', '1', '2025-06-12 22:56:06', 0);
INSERT INTO public.system_dict_data VALUES (3053, 1, '云端轮询', '1', 'iot_modbus_mode', 0, 'primary', '', '网关主动轮询读取设备寄存器', '1', '2025-06-12 22:56:06', '1', '2025-06-12 22:56:06', 0);
INSERT INTO public.system_dict_data VALUES (3054, 1, '企业客户', '1', 'mes_client_type', 0, 'primary', '', '', '1', '2026-02-15 14:38:25', '1', '2026-02-15 14:38:25', 0);
INSERT INTO public.system_dict_data VALUES (3055, 2, '个人', '2', 'mes_client_type', 0, 'success', '', '', '1', '2026-02-15 14:38:25', '1', '2026-02-15 14:38:25', 0);
INSERT INTO public.system_dict_data VALUES (3056, 1, '优质供应商', 'A', 'mes_vendor_level', 0, 'success', '', '', '1', '2026-02-15 15:59:15', '1', '2026-02-15 15:59:15', 0);
INSERT INTO public.system_dict_data VALUES (3057, 2, '正常', 'B', 'mes_vendor_level', 0, 'primary', '', '', '1', '2026-02-15 15:59:15', '1', '2026-02-15 15:59:15', 0);
INSERT INTO public.system_dict_data VALUES (3058, 3, '重点关注', 'C', 'mes_vendor_level', 0, 'warning', '', '', '1', '2026-02-15 15:59:15', '1', '2026-02-15 15:59:15', 0);
INSERT INTO public.system_dict_data VALUES (3059, 4, '劣质供应商', 'D', 'mes_vendor_level', 0, 'danger', '', '', '1', '2026-02-15 15:59:15', '1', '2026-02-15 15:59:15', 0);
INSERT INTO public.system_dict_data VALUES (3060, 5, '黑名单', 'E', 'mes_vendor_level', 0, 'info', '', '', '1', '2026-02-15 15:59:15', '1', '2026-02-15 15:59:15', 0);
INSERT INTO public.system_dict_data VALUES (3061, 1, '假期', '2', 'mes_cal_holiday_type', 0, 'success', '', '', '1', '2026-02-16 07:35:58', '1', '2026-02-16 11:20:42', 0);
INSERT INTO public.system_dict_data VALUES (3062, 2, '工作日', '1', 'mes_cal_holiday_type', 0, 'primary', '', '', '1', '2026-02-16 07:35:58', '1', '2026-02-16 11:20:40', 0);
INSERT INTO public.system_dict_data VALUES (3063, 1, '在库', '1', 'mes_tm_tool_status', 0, 'success', '', '', '1', '2026-02-16 11:10:55', '1', '2026-02-16 11:10:55', 0);
INSERT INTO public.system_dict_data VALUES (3064, 2, '领用中', '2', 'mes_tm_tool_status', 0, 'primary', '', '', '1', '2026-02-16 11:10:55', '1', '2026-02-16 11:10:55', 0);
INSERT INTO public.system_dict_data VALUES (3065, 3, '维修中', '3', 'mes_tm_tool_status', 0, 'warning', '', '', '1', '2026-02-16 11:10:55', '1', '2026-02-16 11:10:55', 0);
INSERT INTO public.system_dict_data VALUES (3066, 4, '报废', '4', 'mes_tm_tool_status', 0, 'danger', '', '', '1', '2026-02-16 11:10:55', '1', '2026-02-16 11:10:55', 0);
INSERT INTO public.system_dict_data VALUES (3067, 1, '定期维护', '1', 'mes_tm_mainten_type', 0, 'primary', '', '', '1', '2026-02-16 11:10:55', '1', '2026-02-16 11:10:55', 0);
INSERT INTO public.system_dict_data VALUES (3068, 2, '按使用次数维护', '2', 'mes_tm_mainten_type', 0, 'success', '', '', '1', '2026-02-16 11:10:55', '1', '2026-02-16 11:10:55', 0);
INSERT INTO public.system_dict_data VALUES (3069, 1, '停机', '1', 'mes_dv_machinery_status', 0, 'success', '', '', '1', '2026-02-17 01:00:06', '1', '2026-02-17 03:28:27', 0);
INSERT INTO public.system_dict_data VALUES (3070, 2, '生产中', '2', 'mes_dv_machinery_status', 0, 'info', '', '', '1', '2026-02-17 01:00:06', '1', '2026-02-17 03:28:33', 0);
INSERT INTO public.system_dict_data VALUES (3071, 3, '维护中', '3', 'mes_dv_machinery_status', 0, 'danger', '', '', '1', '2026-02-17 01:00:06', '1', '2026-02-17 03:28:41', 0);
INSERT INTO public.system_dict_data VALUES (3072, 1, '尺寸', '1', 'mes_indicator_type', 0, '', '', '', '1', '2026-02-17 02:18:18', '1', '2026-04-09 14:38:53', 0);
INSERT INTO public.system_dict_data VALUES (3073, 2, '外观', '2', 'mes_indicator_type', 0, '', '', '', '1', '2026-02-17 02:18:18', '1', '2026-04-09 14:38:53', 0);
INSERT INTO public.system_dict_data VALUES (3074, 3, '重量', '3', 'mes_indicator_type', 0, '', '', '', '1', '2026-02-17 02:18:18', '1', '2026-04-09 14:38:53', 0);
INSERT INTO public.system_dict_data VALUES (3075, 4, '性能', '4', 'mes_indicator_type', 0, '', '', '', '1', '2026-02-17 02:18:18', '1', '2026-04-09 14:38:53', 0);
INSERT INTO public.system_dict_data VALUES (3076, 5, '成分', '5', 'mes_indicator_type', 0, '', '', '', '1', '2026-02-17 02:18:18', '1', '2026-04-09 14:38:53', 0);
INSERT INTO public.system_dict_data VALUES (3077, 1, '致命缺陷', '1', 'mes_defect_level', 0, 'danger', '', '', '1', '2026-02-17 02:18:18', '1', '2026-02-21 12:21:12', 0);
INSERT INTO public.system_dict_data VALUES (3078, 2, '严重缺陷', '2', 'mes_defect_level', 0, 'warning', '', '', '1', '2026-02-17 02:18:18', '1', '2026-02-21 12:21:15', 0);
INSERT INTO public.system_dict_data VALUES (3079, 3, '轻微缺陷', '3', 'mes_defect_level', 0, 'info', '', '', '1', '2026-02-17 02:18:18', '1', '2026-02-21 12:21:19', 0);
INSERT INTO public.system_dict_data VALUES (3080, 1, '单白班', '1', 'mes_cal_shift_type', 0, 'primary', '', '', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0);
INSERT INTO public.system_dict_data VALUES (3081, 2, '两班倒', '2', 'mes_cal_shift_type', 0, 'success', '', '', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0);
INSERT INTO public.system_dict_data VALUES (3082, 3, '三班倒', '3', 'mes_cal_shift_type', 0, 'warning', '', '', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0);
INSERT INTO public.system_dict_data VALUES (3083, 1, '按季度', '1', 'mes_cal_shift_method', 0, '', '', '', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0);
INSERT INTO public.system_dict_data VALUES (3084, 2, '按月', '2', 'mes_cal_shift_method', 0, '', '', '', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0);
INSERT INTO public.system_dict_data VALUES (3085, 3, '按周', '3', 'mes_cal_shift_method', 0, '', '', '', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0);
INSERT INTO public.system_dict_data VALUES (3086, 4, '按天', '4', 'mes_cal_shift_method', 0, '', '', '', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0);
INSERT INTO public.system_dict_data VALUES (3089, 0, '草稿', '0', 'mes_cal_plan_status', 0, 'info', '', '', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0);
INSERT INTO public.system_dict_data VALUES (3090, 1, '已确认', '1', 'mes_cal_plan_status', 0, 'success', '', '', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0);
INSERT INTO public.system_dict_data VALUES (3100, 0, '草稿', '0', 'mes_pro_work_order_status', 0, 'info', '', '', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0);
INSERT INTO public.system_dict_data VALUES (3101, 1, '已确认', '1', 'mes_pro_work_order_status', 0, 'primary', '', '', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0);
INSERT INTO public.system_dict_data VALUES (3102, 2, '已完成', '2', 'mes_pro_work_order_status', 0, 'success', '', '', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0);
INSERT INTO public.system_dict_data VALUES (3103, 3, '已取消', '3', 'mes_pro_work_order_status', 0, 'warning', '', '', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0);
INSERT INTO public.system_dict_data VALUES (3104, 1, '客户订单', '1', 'mes_pro_work_order_source_type', 0, 'primary', '', '', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0);
INSERT INTO public.system_dict_data VALUES (3105, 2, '库存备货', '2', 'mes_pro_work_order_source_type', 0, 'success', '', '', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0);
INSERT INTO public.system_dict_data VALUES (3106, 1, '自行生产', '1', 'mes_pro_work_order_type', 0, 'primary', '', '', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0);
INSERT INTO public.system_dict_data VALUES (3107, 2, '代工', '2', 'mes_pro_work_order_type', 0, 'warning', '', '', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0);
INSERT INTO public.system_dict_data VALUES (3108, 3, '采购', '3', 'mes_pro_work_order_type', 0, 'info', '', '', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0);
INSERT INTO public.system_dict_data VALUES (3121, 1, 'IQC（来料检验）', '1', 'mes_qc_type', 0, 'primary', '', '来料质量检验', '1', '2026-02-18 14:12:05', '1', '2026-02-18 14:12:05', 0);
INSERT INTO public.system_dict_data VALUES (3122, 2, 'IPQC（过程检验）', '2', 'mes_qc_type', 0, 'warning', '', '生产制程质量检验', '1', '2026-02-18 14:12:05', '1', '2026-03-24 15:21:34', 0);
INSERT INTO public.system_dict_data VALUES (3123, 3, 'OQC（出货检验）', '3', 'mes_qc_type', 0, 'success', '', '出货质量检验', '1', '2026-02-18 14:12:05', '1', '2026-02-18 14:12:05', 0);
INSERT INTO public.system_dict_data VALUES (3124, 4, 'RQC（退料检验）', '4', 'mes_qc_type', 0, 'danger', '', '退货质量检验', '1', '2026-02-18 14:12:05', '1', '2026-03-24 15:22:00', 0);
INSERT INTO public.system_dict_data VALUES (3125, 0, '开始-开始(SS)', '0', 'mes_pro_link_type', 0, 'default', '', '前序开始后，后序可以开始', '1', '2026-02-19 04:24:53', '1', '2026-02-19 04:24:53', 0);
INSERT INTO public.system_dict_data VALUES (3126, 1, '结束-结束(FF)', '1', 'mes_pro_link_type', 0, 'default', '', '前序结束后，后序才能结束', '1', '2026-02-19 04:24:53', '1', '2026-02-19 04:24:53', 0);
INSERT INTO public.system_dict_data VALUES (3127, 2, '开始-结束(SF)', '2', 'mes_pro_link_type', 0, 'default', '', '前序开始后，后序才能结束', '1', '2026-02-19 04:24:53', '1', '2026-02-19 04:24:53', 0);
INSERT INTO public.system_dict_data VALUES (3128, 3, '结束-开始(FS)', '3', 'mes_pro_link_type', 0, 'default', '', '前序结束后，后序才能开始', '1', '2026-02-19 04:24:53', '1', '2026-02-19 04:24:53', 0);
INSERT INTO public.system_dict_data VALUES (3129, 1, '分钟', 'MINUTE', 'mes_time_unit_type', 0, 'default', '', '', '1', '2026-02-19 04:24:53', '1', '2026-02-19 04:24:53', 0);
INSERT INTO public.system_dict_data VALUES (3130, 2, '小时', 'HOUR', 'mes_time_unit_type', 0, 'default', '', '', '1', '2026-02-19 04:24:53', '1', '2026-02-19 04:24:53', 0);
INSERT INTO public.system_dict_data VALUES (3131, 3, '天', 'DAY', 'mes_time_unit_type', 0, 'default', '', '', '1', '2026-02-19 04:24:53', '1', '2026-02-19 04:24:53', 0);
INSERT INTO public.system_dict_data VALUES (3137, 1, '设备点检', '1', 'mes_dv_subject_type', 0, 'info', '', '', '1', '2026-02-20 01:42:58', '1', '2026-02-20 01:42:58', 0);
INSERT INTO public.system_dict_data VALUES (3138, 2, '设备保养', '2', 'mes_dv_subject_type', 0, 'success', '', '', '1', '2026-02-20 01:42:58', '1', '2026-02-20 01:42:58', 0);
INSERT INTO public.system_dict_data VALUES (3139, 1, '待保养', '0', 'mes_mainten_record_status', 0, 'info', '', NULL, 'admin', '2026-02-20 02:59:55', '1', '2026-04-16 05:32:37', 0);
INSERT INTO public.system_dict_data VALUES (3140, 2, '已完成', '4', 'mes_mainten_record_status', 0, 'success', '', NULL, 'admin', '2026-02-20 02:59:55', '1', '2026-04-16 05:32:37', 0);
INSERT INTO public.system_dict_data VALUES (3141, 1, '正常', '1', 'mes_mainten_status', 0, 'success', '', NULL, 'admin', '2026-02-20 02:59:55', 'admin', '2026-02-20 02:59:55', 0);
INSERT INTO public.system_dict_data VALUES (3142, 2, '异常', '0', 'mes_mainten_status', 0, 'danger', '', NULL, 'admin', '2026-02-20 02:59:55', 'admin', '2026-02-20 02:59:55', 0);
INSERT INTO public.system_dict_data VALUES (3143, 1, '天', '1', 'mes_dv_cycle_type', 0, 'default', '', '', '1', '2026-02-20 07:11:43', '1', '2026-02-20 07:11:43', 0);
INSERT INTO public.system_dict_data VALUES (3144, 2, '周', '2', 'mes_dv_cycle_type', 0, 'default', '', '', '1', '2026-02-20 07:11:43', '1', '2026-02-20 07:11:43', 0);
INSERT INTO public.system_dict_data VALUES (3145, 3, '月', '3', 'mes_dv_cycle_type', 0, 'default', '', '', '1', '2026-02-20 07:11:43', '1', '2026-02-20 07:11:43', 0);
INSERT INTO public.system_dict_data VALUES (3146, 4, '年', '4', 'mes_dv_cycle_type', 0, 'default', '', '', '1', '2026-02-20 07:11:43', '1', '2026-02-20 07:11:43', 0);
INSERT INTO public.system_dict_data VALUES (3147, 0, '草稿', '0', 'mes_dv_check_plan_status', 0, 'info', '', '', '1', '2026-02-20 07:11:43', '1', '2026-02-20 07:11:43', 0);
INSERT INTO public.system_dict_data VALUES (3148, 1, '已启用', '1', 'mes_dv_check_plan_status', 0, 'success', '', '', '1', '2026-02-20 07:11:43', '1', '2026-02-20 07:11:43', 0);
INSERT INTO public.system_dict_data VALUES (3149, 1, '待点检', '10', 'mes_dv_check_record_status', 0, 'info', '', NULL, 'admin', '2026-02-20 09:46:19', 'admin', '2026-02-20 09:46:19', 0);
INSERT INTO public.system_dict_data VALUES (3150, 2, '已完成', '20', 'mes_dv_check_record_status', 0, 'success', '', NULL, 'admin', '2026-02-20 09:46:19', 'admin', '2026-02-20 09:46:19', 0);
INSERT INTO public.system_dict_data VALUES (3151, 1, '正常', '1', 'mes_dv_check_result', 0, 'success', '', NULL, 'admin', '2026-02-20 09:46:19', 'admin', '2026-02-20 09:46:19', 0);
INSERT INTO public.system_dict_data VALUES (3152, 2, '异常', '2', 'mes_dv_check_result', 0, 'danger', '', NULL, 'admin', '2026-02-20 09:46:19', 'admin', '2026-02-20 09:46:19', 0);
INSERT INTO public.system_dict_data VALUES (3157, 1, '修复成功', '1', 'mes_dv_repair_result', 0, 'success', '', '', '1', '2026-02-20 10:56:24', '1', '2026-02-20 10:56:24', 0);
INSERT INTO public.system_dict_data VALUES (3158, 2, '报废', '2', 'mes_dv_repair_result', 0, 'danger', '', '', '1', '2026-02-20 10:56:24', '1', '2026-02-20 10:56:24', 0);
INSERT INTO public.system_dict_data VALUES (3161, 1, '校验通过', '1', 'mes_qc_check_result', 0, 'success', '', '', '1', '2026-02-20 11:23:35', '1', '2026-02-20 16:15:54', 0);
INSERT INTO public.system_dict_data VALUES (3162, 2, '校验不通过', '2', 'mes_qc_check_result', 0, 'danger', '', '', '1', '2026-02-20 11:23:35', '1', '2026-02-20 16:15:52', 0);
INSERT INTO public.system_dict_data VALUES (3166, 0, '未处置', '0', 'mes_pro_andon_status', 0, 'danger', '', '', '1', '2026-02-21 00:08:38', '1', '2026-02-21 00:08:38', 0);
INSERT INTO public.system_dict_data VALUES (3167, 1, '已处置', '1', 'mes_pro_andon_status', 0, 'success', '', '', '1', '2026-02-21 00:08:38', '1', '2026-02-21 00:08:38', 0);
INSERT INTO public.system_dict_data VALUES (3168, 1, '一级', '1', 'mes_pro_andon_level', 0, 'danger', '', '', '1', '2026-02-21 00:08:38', '1', '2026-02-21 00:08:38', 0);
INSERT INTO public.system_dict_data VALUES (3169, 2, '二级', '2', 'mes_pro_andon_level', 0, 'warning', '', '', '1', '2026-02-21 00:08:38', '1', '2026-02-21 00:08:38', 0);
INSERT INTO public.system_dict_data VALUES (3170, 3, '三级', '3', 'mes_pro_andon_level', 0, 'info', '', '', '1', '2026-02-21 00:08:38', '1', '2026-02-21 00:08:38', 0);
INSERT INTO public.system_dict_data VALUES (3171, 0, '草稿', '0', 'mes_pro_feedback_status', 0, 'info', '', '', '1', '2026-02-21 00:50:32', '1', '2026-02-21 00:50:32', 0);
INSERT INTO public.system_dict_data VALUES (3172, 2, '审批中', '2', 'mes_pro_feedback_status', 0, 'primary', '', '', '1', '2026-02-21 00:50:32', '1', '2026-03-19 00:51:54', 0);
INSERT INTO public.system_dict_data VALUES (3173, 3, '待检验', '3', 'mes_pro_feedback_status', 0, 'warning', '', '', '1', '2026-02-21 00:50:32', '1', '2026-03-19 00:51:54', 0);
INSERT INTO public.system_dict_data VALUES (3174, 4, '已完成', '4', 'mes_pro_feedback_status', 0, 'success', '', '', '1', '2026-02-21 00:50:32', '1', '2026-03-19 00:51:54', 0);
INSERT INTO public.system_dict_data VALUES (3176, 1, '自行报工', '1', 'mes_pro_feedback_type', 0, 'primary', '', '', '1', '2026-02-21 00:50:32', '1', '2026-02-21 00:50:32', 0);
INSERT INTO public.system_dict_data VALUES (3177, 2, '统一报工', '2', 'mes_pro_feedback_type', 0, 'success', '', '', '1', '2026-02-21 00:50:32', '1', '2026-02-21 00:50:32', 0);
INSERT INTO public.system_dict_data VALUES (3178, 1, 'PC', 'PC', 'mes_pro_feedback_channel', 0, 'primary', '', '', '1', '2026-02-21 00:50:32', '1', '2026-02-21 00:50:32', 0);
INSERT INTO public.system_dict_data VALUES (3179, 2, 'APP', 'APP', 'mes_pro_feedback_channel', 0, 'success', '', '', '1', '2026-02-21 00:50:32', '1', '2026-02-21 00:50:32', 0);
INSERT INTO public.system_dict_data VALUES (3180, 3, 'PDA', 'PDA', 'mes_pro_feedback_channel', 0, 'info', '', '', '1', '2026-02-21 00:50:32', '1', '2026-02-21 00:50:32', 0);
INSERT INTO public.system_dict_data VALUES (3181, 1, '浮点', '1', 'mes_qc_result_type', 0, 'primary', '', '', '1', '2026-02-21 13:37:17', '1', '2026-02-21 13:37:17', 0);
INSERT INTO public.system_dict_data VALUES (3182, 2, '整数', '2', 'mes_qc_result_type', 0, 'success', '', '', '1', '2026-02-21 13:37:17', '1', '2026-02-21 13:37:17', 0);
INSERT INTO public.system_dict_data VALUES (3183, 3, '文本', '3', 'mes_qc_result_type', 0, 'info', '', '', '1', '2026-02-21 13:37:17', '1', '2026-02-21 13:37:17', 0);
INSERT INTO public.system_dict_data VALUES (3184, 4, '字典', '4', 'mes_qc_result_type', 0, 'warning', '', '', '1', '2026-02-21 13:37:17', '1', '2026-02-21 13:37:17', 0);
INSERT INTO public.system_dict_data VALUES (3185, 5, '文件', '5', 'mes_qc_result_type', 0, 'danger', '', '', '1', '2026-02-21 13:37:17', '1', '2026-02-21 13:37:17', 0);
INSERT INTO public.system_dict_data VALUES (3186, 1, '生产退料', '1', 'mes_rqc_type', 0, 'default', '', '生产退料检验', '1', '2026-02-22 06:44:09', '1', '2026-02-22 06:44:09', 0);
INSERT INTO public.system_dict_data VALUES (3187, 2, '销售退货', '2', 'mes_rqc_type', 0, 'default', '', '销售退货检验', '1', '2026-02-22 06:44:09', '1', '2026-02-22 06:44:09', 0);
INSERT INTO public.system_dict_data VALUES (3188, 1, '自制工序检验', '1', 'mes_ipqc_type', 0, 'primary', '', '', '1', '2026-02-22 07:01:04', '1', '2026-02-22 07:01:04', 0);
INSERT INTO public.system_dict_data VALUES (3189, 2, '首检', '2', 'mes_ipqc_type', 0, 'success', '', '', '1', '2026-02-22 07:01:04', '1', '2026-02-22 07:01:04', 0);
INSERT INTO public.system_dict_data VALUES (3190, 3, '巡检', '3', 'mes_ipqc_type', 0, 'warning', '', '', '1', '2026-02-22 07:01:04', '1', '2026-02-22 07:01:04', 0);
INSERT INTO public.system_dict_data VALUES (3191, 4, '自检', '4', 'mes_ipqc_type', 0, 'info', '', '', '1', '2026-02-22 07:01:04', '1', '2026-02-22 07:01:04', 0);
INSERT INTO public.system_dict_data VALUES (3192, 5, '成品检验', '5', 'mes_ipqc_type', 0, 'danger', '', '', '1', '2026-02-22 07:01:04', '1', '2026-02-22 07:01:04', 0);
INSERT INTO public.system_dict_data VALUES (3205, 0, '草稿', '0', 'mes_wm_arrival_notice_status', 0, 'info', '', '', '1', '2026-02-22 14:53:18', '1', '2026-02-22 14:53:18', 0);
INSERT INTO public.system_dict_data VALUES (3206, 2, '待质检', '2', 'mes_wm_arrival_notice_status', 0, 'warning', '', '', '1', '2026-02-22 14:53:18', '1', '2026-02-26 05:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3207, 3, '待入库', '3', 'mes_wm_arrival_notice_status', 0, 'success', '', '', '1', '2026-02-22 14:53:18', '1', '2026-02-26 05:24:47', 0);
INSERT INTO public.system_dict_data VALUES (3208, 4, '已完成', '4', 'mes_wm_arrival_notice_status', 0, 'primary', '', '', '1', '2026-02-22 14:53:18', '1', '2026-02-26 05:24:52', 0);
INSERT INTO public.system_dict_data VALUES (3209, 0, '草稿', '0', 'mes_wm_item_receipt_status', 0, 'info', '', '', '1', '2026-02-22 14:54:05', '1', '2026-02-22 14:54:05', 0);
INSERT INTO public.system_dict_data VALUES (3210, 1, '待上架', '2', 'mes_wm_item_receipt_status', 0, 'warning', '', '', '1', '2026-02-22 14:54:05', '1', '2026-02-26 08:03:35', 0);
INSERT INTO public.system_dict_data VALUES (3211, 2, '待执行入库', '3', 'mes_wm_item_receipt_status', 0, 'success', '', '', '1', '2026-02-22 14:54:05', '1', '2026-02-26 08:03:31', 0);
INSERT INTO public.system_dict_data VALUES (3212, 3, '已完成', '4', 'mes_wm_item_receipt_status', 0, 'primary', '', '', '1', '2026-02-22 14:54:05', '1', '2026-02-26 08:03:20', 0);
INSERT INTO public.system_dict_data VALUES (3213, 4, '已取消', '5', 'mes_wm_item_receipt_status', 0, 'danger', '', '', '1', '2026-02-22 14:54:05', '1', '2026-02-26 08:03:24', 0);
INSERT INTO public.system_dict_data VALUES (3214, 1, '草稿', '0', 'mes_order_status', 0, 'info', '', '', '1', '2026-02-23 21:16:03', '1', '2026-02-23 21:16:03', 0);
INSERT INTO public.system_dict_data VALUES (3215, 2, '已确认', '1', 'mes_order_status', 0, 'primary', '', '', '1', '2026-02-23 21:16:03', '1', '2026-02-23 21:16:03', 0);
INSERT INTO public.system_dict_data VALUES (3216, 3, '审批中', '2', 'mes_order_status', 0, 'warning', '', '', '1', '2026-02-23 21:16:03', '1', '2026-02-23 21:16:03', 0);
INSERT INTO public.system_dict_data VALUES (3217, 4, '已审批', '3', 'mes_order_status', 0, 'success', '', '', '1', '2026-02-23 21:16:03', '1', '2026-02-23 21:16:03', 0);
INSERT INTO public.system_dict_data VALUES (3218, 5, '已完成', '4', 'mes_order_status', 0, 'success', '', '', '1', '2026-02-23 21:16:03', '1', '2026-02-23 21:16:03', 0);
INSERT INTO public.system_dict_data VALUES (3219, 6, '已取消', '5', 'mes_order_status', 0, 'danger', '', '', '1', '2026-02-23 21:16:03', '1', '2026-02-23 21:16:03', 0);
INSERT INTO public.system_dict_data VALUES (3220, 1, '草稿', '0', 'mes_wm_issue_status', 0, 'info', '', '草稿状态，未完成', '1', '2026-02-26 15:54:25', '1', '2026-02-26 15:54:25', 0);
INSERT INTO public.system_dict_data VALUES (3221, 2, '已完成', '4', 'mes_wm_issue_status', 0, 'success', '', '已完成出库', '1', '2026-02-26 15:54:25', '1', '2026-02-26 15:54:25', 0);
INSERT INTO public.system_dict_data VALUES (3222, 1, '草稿', '0', 'mes_wm_product_issue_status', 0, 'info', '', '草稿状态，可编辑', '1', '2026-02-26 16:39:12', '1', '2026-03-23 13:18:02', 0);
INSERT INTO public.system_dict_data VALUES (3223, 2, '待拣货', '2', 'mes_wm_product_issue_status', 0, 'warning', '', '审批中，可执行拣货', '1', '2026-02-26 16:39:12', '1', '2026-03-23 13:18:02', 0);
INSERT INTO public.system_dict_data VALUES (3224, 3, '待执行领出', '3', 'mes_wm_product_issue_status', 0, 'primary', '', '已审批，拣货完成', '1', '2026-02-26 16:39:12', '1', '2026-03-23 13:18:02', 0);
INSERT INTO public.system_dict_data VALUES (3225, 4, '已完成', '4', 'mes_wm_product_issue_status', 0, 'success', '', '已完成出库', '1', '2026-02-26 16:39:12', '1', '2026-03-23 13:18:02', 0);
INSERT INTO public.system_dict_data VALUES (3226, 5, '已取消', '5', 'mes_wm_product_issue_status', 0, 'success', '', '已完成出库', '1', '2026-02-26 16:39:12', '1', '2026-03-23 13:18:02', 0);
INSERT INTO public.system_dict_data VALUES (3232, 1, '草稿', '0', 'mes_wm_return_issue_status', 0, 'info', '', '草稿状态，可编辑', '1', '2026-02-28 14:11:12', '1', '2026-02-28 14:28:24', 0);
INSERT INTO public.system_dict_data VALUES (3233, 2, '待检验', '1', 'mes_wm_return_issue_status', 0, 'default', '', '已确认，等待质检', '1', '2026-02-28 14:11:12', '1', '2026-02-28 14:28:28', 0);
INSERT INTO public.system_dict_data VALUES (3234, 3, '待上架', '2', 'mes_wm_return_issue_status', 0, 'warning', '', '检验完成，等待仓库上架', '1', '2026-02-28 14:11:12', '1', '2026-02-28 14:28:31', 0);
INSERT INTO public.system_dict_data VALUES (3235, 4, '待执行退料', '3', 'mes_wm_return_issue_status', 0, 'primary', '', '上架完成，等待执行退料操作', '1', '2026-02-28 14:11:12', '1', '2026-02-28 14:28:34', 0);
INSERT INTO public.system_dict_data VALUES (3236, 5, '已完成', '4', 'mes_wm_return_issue_status', 0, 'success', '', '退料执行完成，库存已更新', '1', '2026-02-28 14:11:12', '1', '2026-02-28 14:28:37', 0);
INSERT INTO public.system_dict_data VALUES (3237, 6, '已取消', '5', 'mes_wm_return_issue_status', 0, 'danger', '', '已取消', '1', '2026-02-28 14:11:12', '1', '2026-02-28 14:28:40', 0);
INSERT INTO public.system_dict_data VALUES (3238, 1, '余料退料', '1', 'mes_wm_return_issue_type', 0, 'success', '', '余料退回，直接合格', '1', '2026-02-28 14:11:12', '1', '2026-02-28 14:27:47', 0);
INSERT INTO public.system_dict_data VALUES (3239, 2, '不良退料', '2', 'mes_wm_return_issue_type', 0, 'danger', '', '不良品退回', '1', '2026-02-28 14:11:12', '1', '2026-02-28 14:27:49', 0);
INSERT INTO public.system_dict_data VALUES (3240, 3, '其他退料', '3', 'mes_wm_return_issue_type', 0, 'info', '', '其他原因退料', '1', '2026-02-28 14:11:12', '1', '2026-02-28 14:27:55', 0);
INSERT INTO public.system_dict_data VALUES (3241, 1, '待检', '0', 'mes_wm_quality_status', 0, 'warning', '', '待检状态', '1', '2026-02-28 15:00:53', '1', '2026-02-28 15:00:53', 0);
INSERT INTO public.system_dict_data VALUES (3242, 2, '合格', '1', 'mes_wm_quality_status', 0, 'success', '', '合格状态', '1', '2026-02-28 15:00:53', '1', '2026-02-28 15:00:53', 0);
INSERT INTO public.system_dict_data VALUES (3243, 3, '不合格', '2', 'mes_wm_quality_status', 0, 'danger', '', '不合格状态', '1', '2026-02-28 15:00:53', '1', '2026-02-28 15:00:53', 0);
INSERT INTO public.system_dict_data VALUES (3244, 1, '草稿', '0', 'mes_wm_product_receipt_status', 0, 'info', '', '草稿状态', '1', '2026-03-01 06:03:07', '1', '2026-03-01 06:03:07', 0);
INSERT INTO public.system_dict_data VALUES (3245, 2, '待上架', '2', 'mes_wm_product_receipt_status', 0, 'primary', '', '待上架', '1', '2026-03-01 06:03:07', '1', '2026-03-01 06:03:07', 0);
INSERT INTO public.system_dict_data VALUES (3246, 3, '待执行入库', '3', 'mes_wm_product_receipt_status', 0, 'warning', '', '待执行入库', '1', '2026-03-01 06:03:07', '1', '2026-03-01 06:03:07', 0);
INSERT INTO public.system_dict_data VALUES (3247, 4, '已完成', '4', 'mes_wm_product_receipt_status', 0, 'success', '', '已完成', '1', '2026-03-01 06:03:07', '1', '2026-03-01 06:03:07', 0);
INSERT INTO public.system_dict_data VALUES (3248, 5, '已取消', '5', 'mes_wm_product_receipt_status', 0, 'danger', '', '已取消', '1', '2026-03-01 06:03:07', '1', '2026-03-01 06:03:07', 0);
INSERT INTO public.system_dict_data VALUES (3252, 1, '草稿', '0', 'mes_wm_product_sales_status', 0, 'info', '', '草稿状态', '1', '2026-03-02 08:55:11', '1', '2026-03-02 08:55:11', 0);
INSERT INTO public.system_dict_data VALUES (3253, 3, '待拣货', '2', 'mes_wm_product_sales_status', 0, 'warning', '', '待拣货状态', '1', '2026-03-02 08:55:11', '1', '2026-03-27 11:44:48', 0);
INSERT INTO public.system_dict_data VALUES (3254, 4, '待出库', '3', 'mes_wm_product_sales_status', 0, 'primary', '', '待出库状态', '1', '2026-03-02 08:55:11', '1', '2026-03-27 11:44:48', 0);
INSERT INTO public.system_dict_data VALUES (3255, 5, '已完成', '4', 'mes_wm_product_sales_status', 0, 'success', '', '已完成状态', '1', '2026-03-02 08:55:11', '1', '2026-03-27 11:44:48', 0);
INSERT INTO public.system_dict_data VALUES (3256, 6, '已取消', '5', 'mes_wm_product_sales_status', 0, 'danger', '', '已取消状态', '1', '2026-03-02 08:55:11', '1', '2026-03-27 11:44:48', 0);
INSERT INTO public.system_dict_data VALUES (3272, 1, '草稿', '0', 'mes_wm_misc_receipt_status', 0, 'info', '', '草稿状态', '1', '2026-03-03 07:33:41', '1', '2026-03-03 07:33:41', 0);
INSERT INTO public.system_dict_data VALUES (3273, 2, '待执行入库', '3', 'mes_wm_misc_receipt_status', 0, 'primary', '', '待执行入库状态', '1', '2026-03-03 07:33:41', '1', '2026-03-03 07:37:34', 0);
INSERT INTO public.system_dict_data VALUES (3274, 3, '已完成', '4', 'mes_wm_misc_receipt_status', 0, 'success', '', '已完成状态', '1', '2026-03-03 07:33:41', '1', '2026-03-03 07:33:41', 0);
INSERT INTO public.system_dict_data VALUES (3275, 4, '已取消', '5', 'mes_wm_misc_receipt_status', 0, 'danger', '', '已取消状态', '1', '2026-03-03 07:33:41', '1', '2026-03-03 07:33:41', 0);
INSERT INTO public.system_dict_data VALUES (3277, 1, '库存调整', '1', 'mes_wm_misc_receipt_type', 0, 'primary', '', '库存调整入库', '1', '2026-03-03 07:34:33', '1', '2026-03-03 07:34:33', 0);
INSERT INTO public.system_dict_data VALUES (3278, 1, '库存调整', '1', 'mes_wm_misc_issue_type', 0, 'primary', '', '库存调整出库', '1', '2026-03-03 07:34:33', '1', '2026-03-03 07:34:33', 0);
INSERT INTO public.system_dict_data VALUES (3279, 2, '报废出库', '2', 'mes_wm_misc_issue_type', 0, 'danger', '', '报废出库', '1', '2026-03-03 07:36:13', '1', '2026-03-03 07:36:13', 0);
INSERT INTO public.system_dict_data VALUES (3280, 1, '草稿', '0', 'mes_wm_outsource_receipt_status', 0, 'info', '', '草稿状态', '1', '2026-03-03 14:03:57', '1', '2026-03-03 14:03:57', 0);
INSERT INTO public.system_dict_data VALUES (3281, 2, '待检验', '1', 'mes_wm_outsource_receipt_status', 0, 'warning', '', '已确认，等待质检', '1', '2026-03-03 14:03:57', '1', '2026-03-03 14:03:57', 0);
INSERT INTO public.system_dict_data VALUES (3282, 3, '待上架', '2', 'mes_wm_outsource_receipt_status', 0, 'primary', '', '检验完成，等待仓库上架', '1', '2026-03-03 14:03:57', '1', '2026-03-03 14:03:57', 0);
INSERT INTO public.system_dict_data VALUES (3283, 4, '待执行入库', '3', 'mes_wm_outsource_receipt_status', 0, 'warning', '', '上架完成，等待执行入库操作', '1', '2026-03-03 14:03:57', '1', '2026-03-03 14:03:57', 0);
INSERT INTO public.system_dict_data VALUES (3284, 5, '已完成', '4', 'mes_wm_outsource_receipt_status', 0, 'success', '', '入库执行完成，库存已更新', '1', '2026-03-03 14:03:57', '1', '2026-03-03 14:03:57', 0);
INSERT INTO public.system_dict_data VALUES (3285, 6, '已取消', '5', 'mes_wm_outsource_receipt_status', 0, 'danger', '', '已取消', '1', '2026-03-03 14:03:57', '1', '2026-03-03 14:03:57', 0);
INSERT INTO public.system_dict_data VALUES (3286, 1, '草稿', '0', 'mes_wm_outsource_issue_status', 0, 'info', '', '草稿状态，可编辑、删除、执行出库', '1', '2026-03-03 16:31:00', '1', '2026-03-03 16:31:00', 0);
INSERT INTO public.system_dict_data VALUES (3287, 2, '待拣货', '2', 'mes_wm_outsource_issue_status', 0, 'warning', '', '待拣货状态', '1', '2026-03-03 16:31:00', '1', '2026-03-03 16:31:00', 0);
INSERT INTO public.system_dict_data VALUES (3288, 3, '待执行出库', '3', 'mes_wm_outsource_issue_status', 0, 'primary', '', '待执行出库状态', '1', '2026-03-03 16:31:00', '1', '2026-03-03 16:31:00', 0);
INSERT INTO public.system_dict_data VALUES (3289, 4, '已完成', '4', 'mes_wm_outsource_issue_status', 0, 'success', '', '已完成，库存已扣减', '1', '2026-03-03 16:31:00', '1', '2026-03-03 16:31:00', 0);
INSERT INTO public.system_dict_data VALUES (3290, 5, '已取消', '5', 'mes_wm_outsource_issue_status', 0, 'danger', '', '已取消状态', '1', '2026-03-03 16:31:00', '1', '2026-03-03 16:31:00', 0);
INSERT INTO public.system_dict_data VALUES (3301, 1, '输入字符', '1', 'mes_md_auto_code_part_type', 0, 'default', '', '输入字符', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3302, 2, '当前日期', '2', 'mes_md_auto_code_part_type', 0, 'primary', '', '当前日期时间', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3303, 3, '固定字符', '3', 'mes_md_auto_code_part_type', 0, 'success', '', '固定字符', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3304, 4, '流水号', '4', 'mes_md_auto_code_part_type', 0, 'warning', '', '流水号', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3305, 1, '左补齐', '1', 'mes_md_auto_code_padded_method', 0, 'primary', '', '左补齐', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3306, 2, '右补齐', '2', 'mes_md_auto_code_padded_method', 0, 'success', '', '右补齐', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3307, 1, '按年', '1', 'mes_md_auto_code_cycle_method', 0, 'default', '', '按年循环', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3308, 2, '按月', '2', 'mes_md_auto_code_cycle_method', 0, 'primary', '', '按月循环', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3309, 3, '按天', '3', 'mes_md_auto_code_cycle_method', 0, 'success', '', '按天循环', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3310, 4, '按小时', '4', 'mes_md_auto_code_cycle_method', 0, 'warning', '', '按小时循环', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3311, 5, '按分钟', '5', 'mes_md_auto_code_cycle_method', 0, 'danger', '', '按分钟循环', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3312, 10, '按传入字符', '10', 'mes_md_auto_code_cycle_method', 0, 'info', '', '按传入字符循环', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0);
INSERT INTO public.system_dict_data VALUES (3313, 1, '二维码', '1', 'mes_wm_barcode_format', 0, 'primary', '', 'QR_CODE', '1', '2026-03-05 14:37:20', '1', '2026-03-06 13:18:21', 0);
INSERT INTO public.system_dict_data VALUES (3314, 2, 'EAN13 商品条码', '2', 'mes_wm_barcode_format', 0, 'success', '', 'EAN13', '1', '2026-03-05 14:37:20', '1', '2026-03-06 13:18:23', 0);
INSERT INTO public.system_dict_data VALUES (3315, 3, 'CODE39 工业条码', '3', 'mes_wm_barcode_format', 0, 'info', '', 'CODE39', '1', '2026-03-05 14:37:20', '1', '2026-03-06 13:18:25', 0);
INSERT INTO public.system_dict_data VALUES (3316, 4, 'UPC-A 美国商品码', '4', 'mes_wm_barcode_format', 0, 'warning', '', 'UPC_A', '1', '2026-03-05 14:37:20', '1', '2026-03-06 13:18:28', 0);
INSERT INTO public.system_dict_data VALUES (3318, 3, '库位', '104', 'mes_wm_barcode_biz_type', 0, 'default', '', 'AREA', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3319, 4, '装箱单', '105', 'mes_wm_barcode_biz_type', 0, 'default', '', 'PACKAGE', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3320, 5, '库存', '106', 'mes_wm_barcode_biz_type', 0, 'default', '', 'STOCK', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3321, 6, '批次', '107', 'mes_wm_barcode_biz_type', 0, 'default', '', 'BATCH', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3322, 7, '流转卡', '300', 'mes_wm_barcode_biz_type', 0, 'primary', '', 'PROCARD', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3323, 8, '工单', '301', 'mes_wm_barcode_biz_type', 0, 'primary', '', 'WORKORDER', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3324, 9, '流转单', '302', 'mes_wm_barcode_biz_type', 0, 'primary', '', 'TRANSORDER', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3325, 10, '设备', '400', 'mes_wm_barcode_biz_type', 0, 'success', '', 'MACHINERY', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3327, 12, '产品物料', '600', 'mes_wm_barcode_biz_type', 0, 'info', '', 'ITEM', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3328, 13, '供应商', '601', 'mes_wm_barcode_biz_type', 0, 'info', '', 'VENDOR', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3329, 14, '工作站', '602', 'mes_wm_barcode_biz_type', 0, 'info', '', 'WORKSTATION', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3330, 15, '车间', '603', 'mes_wm_barcode_biz_type', 0, 'info', '', 'WORKSHOP', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3331, 16, '人员', '604', 'mes_wm_barcode_biz_type', 0, 'info', '', 'USER', '1', '2026-03-05 14:37:20', '1', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3351, 1, '仓库', '102', 'mes_wm_barcode_biz_type', 0, '', '', NULL, '', '2026-03-07 06:22:27', '', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3352, 2, '库区', '103', 'mes_wm_barcode_biz_type', 0, '', '', NULL, '', '2026-03-07 06:22:27', '', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3353, 11, '工具', '500', 'mes_wm_barcode_biz_type', 0, '', '', NULL, '', '2026-03-07 06:22:27', '', '2026-03-07 06:22:27', 0);
INSERT INTO public.system_dict_data VALUES (3354, 17, '客户', '605', 'mes_wm_barcode_biz_type', 0, '', '', NULL, '', '2026-03-07 06:22:27', '', '2026-03-07 06:25:19', 0);
INSERT INTO public.system_dict_data VALUES (3355, 1, '草稿', '0', 'mes_wm_package_status', 0, 'info', '', '草稿状态，可编辑', '1', '2026-03-08 02:05:46', '1', '2026-03-08 02:05:46', 0);
INSERT INTO public.system_dict_data VALUES (3356, 2, '已完成', '4', 'mes_wm_package_status', 0, 'success', '', '装箱已完成', '1', '2026-03-08 02:05:46', '1', '2026-03-08 02:05:46', 0);
INSERT INTO public.system_dict_data VALUES (3357, 1, '草稿', '0', 'mes_wm_transfer_status', 0, 'info', '', '草稿状态，可编辑', '1', '2026-03-08 11:55:25', '1', '2026-03-08 11:55:25', 0);
INSERT INTO public.system_dict_data VALUES (3358, 2, '待确认', '1', 'mes_wm_transfer_status', 0, 'warning', '', '外部调拨待确认到货', '1', '2026-03-08 11:55:25', '1', '2026-03-08 11:55:25', 0);
INSERT INTO public.system_dict_data VALUES (3359, 3, '待上架', '2', 'mes_wm_transfer_status', 0, 'primary', '', '待维护目标库位明细', '1', '2026-03-08 11:55:25', '1', '2026-03-08 11:55:25', 0);
INSERT INTO public.system_dict_data VALUES (3360, 4, '待执行', '3', 'mes_wm_transfer_status', 0, 'success', '', '目标库位已分配，待执行调拨', '1', '2026-03-08 11:55:25', '1', '2026-03-08 11:55:25', 0);
INSERT INTO public.system_dict_data VALUES (3361, 5, '已完成', '4', 'mes_wm_transfer_status', 0, 'success', '', '调拨已完成', '1', '2026-03-08 11:55:25', '1', '2026-03-08 11:55:25', 0);
INSERT INTO public.system_dict_data VALUES (3362, 6, '已取消', '5', 'mes_wm_transfer_status', 0, 'danger', '', '调拨已取消', '1', '2026-03-08 11:55:25', '1', '2026-03-08 11:55:25', 0);
INSERT INTO public.system_dict_data VALUES (3363, 1, '内部调拨', '1', 'mes_wm_transfer_type', 0, 'success', '', '内部仓储调拨', '1', '2026-03-08 11:55:25', '1', '2026-03-08 11:55:25', 0);
INSERT INTO public.system_dict_data VALUES (3364, 2, '外部调拨', '2', 'mes_wm_transfer_type', 0, 'warning', '', '外部配送/外部收货调拨', '1', '2026-03-08 11:55:25', '1', '2026-03-08 11:55:25', 0);
INSERT INTO public.system_dict_data VALUES (3365, 1, '静态盘点', '1', 'mes_wm_stock_taking_type', 0, 'primary', '', '静态盘点', '1', '2026-03-09 00:00:00', '1', '2026-04-05 15:02:18', 0);
INSERT INTO public.system_dict_data VALUES (3366, 2, '动态盘点', '2', 'mes_wm_stock_taking_type', 0, 'success', '', '动态盘点', '1', '2026-03-09 00:00:00', '1', '2026-04-05 15:02:18', 0);
INSERT INTO public.system_dict_data VALUES (3367, 1, '仓库', '102', 'mes_wm_stock_taking_plan_param_type', 0, 'primary', '', '按仓库盘点', '1', '2026-03-09 00:00:00', '1', '2026-03-09 00:00:00', 0);
INSERT INTO public.system_dict_data VALUES (3368, 2, '库区', '103', 'mes_wm_stock_taking_plan_param_type', 0, 'success', '', '按库区盘点', '1', '2026-03-09 00:00:00', '1', '2026-03-09 00:00:00', 0);
INSERT INTO public.system_dict_data VALUES (3369, 3, '库位', '104', 'mes_wm_stock_taking_plan_param_type', 0, 'info', '', '按库位盘点', '1', '2026-03-09 00:00:00', '1', '2026-03-09 00:00:00', 0);
INSERT INTO public.system_dict_data VALUES (3370, 4, '物料', '600', 'mes_wm_stock_taking_plan_param_type', 0, 'warning', '', '按物料盘点', '1', '2026-03-09 00:00:00', '1', '2026-03-09 00:00:00', 0);
INSERT INTO public.system_dict_data VALUES (3371, 5, '批次', '107', 'mes_wm_stock_taking_plan_param_type', 0, 'danger', '', '按批次盘点', '1', '2026-03-09 00:00:00', '1', '2026-03-09 00:00:00', 0);
INSERT INTO public.system_dict_data VALUES (3372, 1, '草稿', '0', 'mes_wm_stock_taking_task_status', 0, 'info', '', '草稿', '1', '2026-03-09 00:00:00', '1', '2026-04-05 15:02:18', 0);
INSERT INTO public.system_dict_data VALUES (3373, 2, '审批中', '2', 'mes_wm_stock_taking_task_status', 0, 'primary', '', '盘点任务审批中', '1', '2026-03-09 00:00:00', '1', '2026-03-09 00:00:00', 0);
INSERT INTO public.system_dict_data VALUES (3374, 3, '已完成', '4', 'mes_wm_stock_taking_task_status', 0, 'success', '', '已完成', '1', '2026-03-09 00:00:00', '1', '2026-04-05 15:02:18', 0);
INSERT INTO public.system_dict_data VALUES (3375, 4, '已取消', '5', 'mes_wm_stock_taking_task_status', 0, 'danger', '', '已取消', '1', '2026-03-09 00:00:00', '1', '2026-04-05 15:02:18', 0);
INSERT INTO public.system_dict_data VALUES (3377, 1, '正常', '1', 'mes_wm_stock_taking_task_line_status', 0, 'success', '', '正常', '1', '2026-03-09 00:00:00', '1', '2026-04-05 15:02:18', 0);
INSERT INTO public.system_dict_data VALUES (3378, 2, '盘盈', '2', 'mes_wm_stock_taking_task_line_status', 0, 'primary', '', '盘盈', '1', '2026-03-09 00:00:00', '1', '2026-04-05 15:02:18', 0);
INSERT INTO public.system_dict_data VALUES (3379, 3, '盘亏', '3', 'mes_wm_stock_taking_task_line_status', 0, 'danger', '', '盘亏', '1', '2026-03-09 00:00:00', '1', '2026-04-05 15:02:18', 0);
INSERT INTO public.system_dict_data VALUES (3380, 6, '质量状态', '900', 'mes_wm_stock_taking_plan_param_type', 0, 'default', '', '按质量状态盘点', '1', '2026-03-09 00:00:00', '1', '2026-03-09 00:00:00', 0);
INSERT INTO public.system_dict_data VALUES (3381, 1, '物料', 'ITEM', 'mes_md_item_or_product', 0, 'info', '', '', '1', '2026-03-15 01:55:06', '1', '2026-03-15 01:55:06', 0);
INSERT INTO public.system_dict_data VALUES (3382, 2, '产品', 'PRODUCT', 'mes_md_item_or_product', 0, 'success', '', '', '1', '2026-03-15 01:55:06', '1', '2026-03-15 01:55:06', 0);
INSERT INTO public.system_dict_data VALUES (3383, 1, '草稿', '0', 'mes_wm_item_consume_status', 0, 'info', '', '草稿状态', '1', '2026-03-19 15:06:23', '1', '2026-03-19 15:06:23', 0);
INSERT INTO public.system_dict_data VALUES (3384, 2, '已完成', '4', 'mes_wm_item_consume_status', 0, 'success', '', '已完成', '1', '2026-03-19 15:06:23', '1', '2026-03-19 15:06:23', 0);
INSERT INTO public.system_dict_data VALUES (3385, 1, '到货通知单', '100', 'mes_qc_source_doc_type', 0, 'primary', '', 'IQC', '1', '2026-03-26 13:01:09', '1', '2026-03-26 13:01:09', 0);
INSERT INTO public.system_dict_data VALUES (3386, 2, '外协入库单', '121', 'mes_qc_source_doc_type', 0, 'warning', '', 'IQC', '1', '2026-03-26 13:01:09', '1', '2026-03-26 13:01:09', 0);
INSERT INTO public.system_dict_data VALUES (3387, 3, '生产报工', '304', 'mes_qc_source_doc_type', 0, 'success', '', 'IPQC', '1', '2026-03-26 13:01:09', '1', '2026-03-26 13:01:09', 0);
INSERT INTO public.system_dict_data VALUES (3388, 4, '销售出库单', '118', 'mes_qc_source_doc_type', 0, 'info', '', 'OQC', '1', '2026-03-26 13:01:09', '1', '2026-03-26 13:01:09', 0);
INSERT INTO public.system_dict_data VALUES (3389, 5, '生产退料单', '116', 'mes_qc_source_doc_type', 0, 'danger', '', 'RQC', '1', '2026-03-26 13:01:09', '1', '2026-03-26 13:01:09', 0);
INSERT INTO public.system_dict_data VALUES (3390, 6, '销售退货单', '119', 'mes_qc_source_doc_type', 0, 'default', '', 'RQC', '1', '2026-03-26 13:01:09', '1', '2026-03-26 13:01:09', 0);
INSERT INTO public.system_dict_data VALUES (3397, 2, '待检测', '1', 'mes_wm_product_sales_status', 0, 'warning', '', 'OQC 检验中', '1', '2026-03-27 11:44:48', '1', '2026-03-27 11:44:48', 0);
INSERT INTO public.system_dict_data VALUES (3398, 0, '草稿', '0', 'mes_wm_return_vendor_status', 0, 'info', '', NULL, '', '2026-03-29 13:49:57', '', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3399, 1, '待拣货', '2', 'mes_wm_return_vendor_status', 0, 'primary', '', NULL, '', '2026-03-29 13:49:57', '', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3400, 2, '待执行退货', '3', 'mes_wm_return_vendor_status', 0, 'warning', '', NULL, '', '2026-03-29 13:49:57', '', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3401, 3, '已完成', '4', 'mes_wm_return_vendor_status', 0, 'success', '', NULL, '', '2026-03-29 13:49:57', '', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3402, 4, '已取消', '5', 'mes_wm_return_vendor_status', 0, 'danger', '', NULL, '', '2026-03-29 13:49:57', '', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3403, 1, '草稿', '0', 'mes_wm_sales_notice_status', 0, 'info', '', '草稿状态，可以修改和删除', '1', '2026-03-30 08:54:30', '1', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3404, 2, '待出库', '3', 'mes_wm_sales_notice_status', 0, 'success', '', '已提交状态，不可修改和删除', '1', '2026-03-30 08:54:30', '1', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3405, 3, '已完成', '4', 'mes_wm_sales_notice_status', 0, '', '', NULL, '1', '2026-03-30 10:02:10', '1', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3406, 1, '草稿', '0', 'mes_wm_misc_issue_status', 0, 'info', '', '草稿状态', '1', '2026-03-30 15:00:18', '1', '2026-03-30 15:00:18', 0);
INSERT INTO public.system_dict_data VALUES (3407, 2, '待出库', '3', 'mes_wm_misc_issue_status', 0, 'warning', '', '待出库状态', '1', '2026-03-30 15:00:18', '1', '2026-03-30 15:00:18', 0);
INSERT INTO public.system_dict_data VALUES (3408, 3, '已完成', '4', 'mes_wm_misc_issue_status', 0, 'success', '', '执行出库后的状态', '1', '2026-03-30 15:00:18', '1', '2026-03-30 15:00:18', 0);
INSERT INTO public.system_dict_data VALUES (3409, 4, '已取消', '5', 'mes_wm_misc_issue_status', 0, 'danger', '', '已取消状态', '1', '2026-03-30 15:00:18', '1', '2026-03-30 15:00:18', 0);
INSERT INTO public.system_dict_data VALUES (3415, 1, '注塑', '1', 'mes_cal_calendar_type', 0, 'primary', '', '', '1', '2026-04-01 15:23:14', '1', '2026-04-01 16:08:31', 0);
INSERT INTO public.system_dict_data VALUES (3416, 2, '机加工', '2', 'mes_cal_calendar_type', 0, 'success', '', '', '1', '2026-04-01 15:23:14', '1', '2026-04-01 16:08:32', 0);
INSERT INTO public.system_dict_data VALUES (3417, 3, '组装', '3', 'mes_cal_calendar_type', 0, 'warning', '', '', '1', '2026-04-01 15:23:14', '1', '2026-04-01 16:08:33', 0);
INSERT INTO public.system_dict_data VALUES (3418, 4, '仓库', '4', 'mes_cal_calendar_type', 0, 'danger', '', '', '1', '2026-04-01 15:23:14', '1', '2026-04-01 16:08:34', 0);
INSERT INTO public.system_dict_data VALUES (3419, 0, '草稿', '0', 'mes_dv_repair_status', 0, 'info', '', '', '1', '2026-04-03 17:20:23', '1', '2026-04-03 17:20:23', 0);
INSERT INTO public.system_dict_data VALUES (3420, 1, '维修中', '1', 'mes_dv_repair_status', 0, 'primary', '', '', '1', '2026-04-03 17:20:23', '1', '2026-04-03 17:20:23', 0);
INSERT INTO public.system_dict_data VALUES (3421, 2, '待验收', '2', 'mes_dv_repair_status', 0, 'warning', '', '', '1', '2026-04-03 17:20:23', '1', '2026-04-03 17:20:23', 0);
INSERT INTO public.system_dict_data VALUES (3422, 3, '已确认', '4', 'mes_dv_repair_status', 0, 'success', '', '', '1', '2026-04-03 17:20:23', '1', '2026-04-03 17:20:23', 0);
INSERT INTO public.system_dict_data VALUES (3423, 0, '草稿', '0', 'mes_wm_return_sales_status', 0, 'info', '', '', '1', '2026-04-03 17:20:25', '1', '2026-04-03 17:20:25', 0);
INSERT INTO public.system_dict_data VALUES (3424, 1, '待检验', '1', 'mes_wm_return_sales_status', 0, 'warning', '', '', '1', '2026-04-03 17:20:25', '1', '2026-04-03 17:20:25', 0);
INSERT INTO public.system_dict_data VALUES (3425, 2, '待执行', '2', 'mes_wm_return_sales_status', 0, 'warning', '', '', '1', '2026-04-03 17:20:25', '1', '2026-04-03 17:20:25', 0);
INSERT INTO public.system_dict_data VALUES (3426, 3, '待上架', '3', 'mes_wm_return_sales_status', 0, 'primary', '', '', '1', '2026-04-03 17:20:25', '1', '2026-04-03 17:20:25', 0);
INSERT INTO public.system_dict_data VALUES (3427, 4, '已完成', '4', 'mes_wm_return_sales_status', 0, 'success', '', '', '1', '2026-04-03 17:20:25', '1', '2026-04-03 17:20:25', 0);
INSERT INTO public.system_dict_data VALUES (3428, 5, '已取消', '5', 'mes_wm_return_sales_status', 0, 'danger', '', '', '1', '2026-04-03 17:20:25', '1', '2026-04-03 17:20:25', 0);
INSERT INTO public.system_dict_data VALUES (3429, 1, '尺寸', '1', 'mes_defect_type', 0, '', '', '', '1', '2026-04-04 12:49:51', '1', '2026-04-09 15:03:20', 0);
INSERT INTO public.system_dict_data VALUES (3430, 2, '外观', '2', 'mes_defect_type', 0, '', '', '', '1', '2026-04-04 12:49:51', '1', '2026-04-09 15:03:20', 0);
INSERT INTO public.system_dict_data VALUES (3431, 3, '重量', '3', 'mes_defect_type', 0, '', '', '', '1', '2026-04-04 12:49:51', '1', '2026-04-09 15:03:20', 0);
INSERT INTO public.system_dict_data VALUES (3432, 4, '性能', '4', 'mes_defect_type', 0, '', '', '', '1', '2026-04-04 12:49:51', '1', '2026-04-09 15:03:20', 0);
INSERT INTO public.system_dict_data VALUES (3433, 5, '成分', '5', 'mes_defect_type', 0, '', '', '', '1', '2026-04-04 12:49:51', '1', '2026-04-09 15:03:20', 0);
INSERT INTO public.system_dict_data VALUES (3436, 1, '上工', '1', 'mes_pro_work_record_type', 0, 'success', '', '', '1', '2026-04-05 14:07:27', '1', '2026-04-05 14:07:27', 0);
INSERT INTO public.system_dict_data VALUES (3437, 2, '下工', '2', 'mes_pro_work_record_type', 0, 'danger', '', '', '1', '2026-04-05 14:07:27', '1', '2026-04-05 14:07:27', 0);
INSERT INTO public.system_dict_data VALUES (3443, 1, '草稿', '0', 'mes_wm_product_produce_status', 0, 'info', '', '草稿状态', '1', '2026-04-05 15:53:46', '1', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3444, 2, '已完成', '4', 'mes_wm_product_produce_status', 0, 'success', '', '已完成状态', '1', '2026-04-05 15:53:46', '1', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3445, 3, '已取消', '5', 'mes_wm_product_produce_status', 0, 'danger', '', '已取消状态', '1', '2026-04-05 15:53:46', '1', '2026-04-05 15:53:46', 0);
INSERT INTO public.system_dict_data VALUES (3446, 0, '草稿', '0', 'mes_pro_task_status', 0, '', '', NULL, '1', '2026-04-16 09:47:00', '1', '2026-04-16 09:47:00', 0);
INSERT INTO public.system_dict_data VALUES (3447, 1, '已完成', '4', 'mes_pro_task_status', 0, '', '', NULL, '1', '2026-04-16 09:47:00', '1', '2026-04-16 09:47:00', 0);
INSERT INTO public.system_dict_data VALUES (3448, 2, '已取消', '5', 'mes_pro_task_status', 0, '', '', NULL, '1', '2026-04-16 09:47:00', '1', '2026-04-16 09:47:00', 0);


--
-- Data for Name: system_dict_type; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_dict_type VALUES (1, '用户性别', 'system_user_sex', 0, NULL, 'admin', '2021-01-05 17:03:48', '1', '2022-05-16 20:29:32', 0, NULL);
INSERT INTO public.system_dict_type VALUES (6, '参数类型', 'infra_config_type', 0, NULL, 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:36:54', 0, NULL);
INSERT INTO public.system_dict_type VALUES (7, '通知类型', 'system_notice_type', 0, NULL, 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:35:26', 0, NULL);
INSERT INTO public.system_dict_type VALUES (9, '操作类型', 'infra_operate_type', 0, NULL, 'admin', '2021-01-05 17:03:48', '1', '2024-03-14 12:44:01', 0, NULL);
INSERT INTO public.system_dict_type VALUES (10, '系统状态', 'common_status', 0, NULL, 'admin', '2021-01-05 17:03:48', '', '2022-02-01 16:21:28', 0, NULL);
INSERT INTO public.system_dict_type VALUES (11, 'Boolean 是否类型', 'infra_boolean_string', 0, 'boolean 转是否', '', '2021-01-19 03:20:08', '', '2022-02-01 16:37:10', 0, NULL);
INSERT INTO public.system_dict_type VALUES (104, '登陆结果', 'system_login_result', 0, '登陆结果', '', '2021-01-18 06:17:11', '', '2022-02-01 16:36:00', 0, NULL);
INSERT INTO public.system_dict_type VALUES (106, '代码生成模板类型', 'infra_codegen_template_type', 0, NULL, '', '2021-02-05 07:08:06', '1', '2022-05-16 20:26:50', 0, NULL);
INSERT INTO public.system_dict_type VALUES (107, '定时任务状态', 'infra_job_status', 0, NULL, '', '2021-02-07 07:44:16', '', '2022-02-01 16:51:11', 0, NULL);
INSERT INTO public.system_dict_type VALUES (108, '定时任务日志状态', 'infra_job_log_status', 0, NULL, '', '2021-02-08 10:03:51', '', '2022-02-01 16:50:43', 0, NULL);
INSERT INTO public.system_dict_type VALUES (109, '用户类型', 'user_type', 0, NULL, '', '2021-02-26 00:15:51', '', '2021-02-26 00:15:51', 0, NULL);
INSERT INTO public.system_dict_type VALUES (110, 'API 异常数据的处理状态', 'infra_api_error_log_process_status', 0, NULL, '', '2021-02-26 07:07:01', '', '2022-02-01 16:50:53', 0, NULL);
INSERT INTO public.system_dict_type VALUES (111, '短信渠道编码', 'system_sms_channel_code', 0, NULL, '1', '2021-04-05 01:04:50', '1', '2022-02-16 02:09:08', 0, NULL);
INSERT INTO public.system_dict_type VALUES (112, '短信模板的类型', 'system_sms_template_type', 0, NULL, '1', '2021-04-05 21:50:43', '1', '2022-02-01 16:35:06', 0, NULL);
INSERT INTO public.system_dict_type VALUES (113, '短信发送状态', 'system_sms_send_status', 0, NULL, '1', '2021-04-11 20:18:03', '1', '2022-02-01 16:35:09', 0, NULL);
INSERT INTO public.system_dict_type VALUES (114, '短信接收状态', 'system_sms_receive_status', 0, NULL, '1', '2021-04-11 20:27:14', '1', '2022-02-01 16:35:14', 0, NULL);
INSERT INTO public.system_dict_type VALUES (116, '登陆日志的类型', 'system_login_type', 0, '登陆日志的类型', '1', '2021-10-06 00:50:46', '1', '2022-02-01 16:35:56', 0, NULL);
INSERT INTO public.system_dict_type VALUES (117, 'OA 请假类型', 'bpm_oa_leave_type', 0, NULL, '1', '2021-09-21 22:34:33', '1', '2022-01-22 10:41:37', 0, NULL);
INSERT INTO public.system_dict_type VALUES (130, '支付渠道编码类型', 'pay_channel_code', 0, '支付渠道的编码', '1', '2021-12-03 10:35:08', '1', '2023-07-10 10:11:39', 0, NULL);
INSERT INTO public.system_dict_type VALUES (131, '支付回调状态', 'pay_notify_status', 0, '支付回调状态（包括退款回调）', '1', '2021-12-03 10:53:29', '1', '2023-07-19 18:09:43', 0, NULL);
INSERT INTO public.system_dict_type VALUES (132, '支付订单状态', 'pay_order_status', 0, '支付订单状态', '1', '2021-12-03 11:17:50', '1', '2021-12-03 11:17:50', 0, NULL);
INSERT INTO public.system_dict_type VALUES (134, '退款订单状态', 'pay_refund_status', 0, '退款订单状态', '1', '2021-12-10 16:42:50', '1', '2023-07-19 10:13:17', 0, NULL);
INSERT INTO public.system_dict_type VALUES (139, '流程实例的状态', 'bpm_process_instance_status', 0, '流程实例的状态', '1', '2022-01-07 23:46:42', '1', '2022-01-07 23:46:42', 0, NULL);
INSERT INTO public.system_dict_type VALUES (140, '流程实例的结果', 'bpm_task_status', 0, '流程实例的结果', '1', '2022-01-07 23:48:10', '1', '2024-03-08 22:42:03', 0, NULL);
INSERT INTO public.system_dict_type VALUES (141, '流程的表单类型', 'bpm_model_form_type', 0, '流程的表单类型', '103', '2022-01-11 23:50:45', '103', '2022-01-11 23:50:45', 0, NULL);
INSERT INTO public.system_dict_type VALUES (142, '任务分配规则的类型', 'bpm_task_candidate_strategy', 0, 'BPM 任务的候选人的策略', '103', '2022-01-12 23:21:04', '103', '2024-03-06 02:53:59', 0, NULL);
INSERT INTO public.system_dict_type VALUES (144, '代码生成的场景枚举', 'infra_codegen_scene', 0, '代码生成的场景枚举', '1', '2022-02-02 13:14:45', '1', '2022-03-10 16:33:46', 0, NULL);
INSERT INTO public.system_dict_type VALUES (145, '角色类型', 'system_role_type', 0, '角色类型', '1', '2022-02-16 13:01:46', '1', '2022-02-16 13:01:46', 0, NULL);
INSERT INTO public.system_dict_type VALUES (146, '文件存储器', 'infra_file_storage', 0, '文件存储器', '1', '2022-03-15 00:24:38', '1', '2022-03-15 00:24:38', 0, NULL);
INSERT INTO public.system_dict_type VALUES (147, 'OAuth 2.0 授权类型', 'system_oauth2_grant_type', 0, 'OAuth 2.0 授权类型（模式）', '1', '2022-05-12 00:20:52', '1', '2022-05-11 16:25:49', 0, NULL);
INSERT INTO public.system_dict_type VALUES (149, '商品 SPU 状态', 'product_spu_status', 0, '商品 SPU 状态', '1', '2022-10-24 21:19:04', '1', '2022-10-24 21:19:08', 0, NULL);
INSERT INTO public.system_dict_type VALUES (150, '优惠类型', 'promotion_discount_type', 0, '优惠类型', '1', '2022-11-01 12:46:06', '1', '2022-11-01 12:46:06', 0, NULL);
INSERT INTO public.system_dict_type VALUES (151, '优惠劵模板的有限期类型', 'promotion_coupon_template_validity_type', 0, '优惠劵模板的有限期类型', '1', '2022-11-02 00:06:20', '1', '2022-11-04 00:08:26', 0, NULL);
INSERT INTO public.system_dict_type VALUES (152, '营销的商品范围', 'promotion_product_scope', 0, '营销的商品范围', '1', '2022-11-02 00:28:01', '1', '2022-11-02 00:28:01', 0, NULL);
INSERT INTO public.system_dict_type VALUES (153, '优惠劵的状态', 'promotion_coupon_status', 0, '优惠劵的状态', '1', '2022-11-04 00:14:49', '1', '2022-11-04 00:14:49', 0, NULL);
INSERT INTO public.system_dict_type VALUES (154, '优惠劵的领取方式', 'promotion_coupon_take_type', 0, '优惠劵的领取方式', '1', '2022-11-04 19:12:27', '1', '2022-11-04 19:12:27', 0, NULL);
INSERT INTO public.system_dict_type VALUES (155, '促销活动的状态', 'promotion_activity_status', 0, '促销活动的状态', '1', '2022-11-04 22:54:23', '1', '2022-11-04 22:54:23', 0, NULL);
INSERT INTO public.system_dict_type VALUES (156, '营销的条件类型', 'promotion_condition_type', 0, '营销的条件类型', '1', '2022-11-04 22:59:23', '1', '2022-11-04 22:59:23', 0, NULL);
INSERT INTO public.system_dict_type VALUES (157, '交易售后状态', 'trade_after_sale_status', 0, '交易售后状态', '1', '2022-11-19 20:52:56', '1', '2022-11-19 20:52:56', 0, NULL);
INSERT INTO public.system_dict_type VALUES (158, '交易售后的类型', 'trade_after_sale_type', 0, '交易售后的类型', '1', '2022-11-19 21:04:09', '1', '2022-11-19 21:04:09', 0, NULL);
INSERT INTO public.system_dict_type VALUES (159, '交易售后的方式', 'trade_after_sale_way', 0, '交易售后的方式', '1', '2022-11-19 21:39:04', '1', '2022-11-19 21:39:04', 0, NULL);
INSERT INTO public.system_dict_type VALUES (160, '终端', 'terminal', 0, '终端', '1', '2022-12-10 10:50:50', '1', '2022-12-10 10:53:11', 0, NULL);
INSERT INTO public.system_dict_type VALUES (161, '交易订单的类型', 'trade_order_type', 0, '交易订单的类型', '1', '2022-12-10 16:33:54', '1', '2022-12-10 16:33:54', 0, NULL);
INSERT INTO public.system_dict_type VALUES (162, '交易订单的状态', 'trade_order_status', 0, '交易订单的状态', '1', '2022-12-10 16:48:44', '1', '2022-12-10 16:48:44', 0, NULL);
INSERT INTO public.system_dict_type VALUES (163, '交易订单项的售后状态', 'trade_order_item_after_sale_status', 0, '交易订单项的售后状态', '1', '2022-12-10 20:58:08', '1', '2022-12-10 20:58:08', 0, NULL);
INSERT INTO public.system_dict_type VALUES (164, '公众号自动回复的请求关键字匹配模式', 'mp_auto_reply_request_match', 0, '公众号自动回复的请求关键字匹配模式', '1', '2023-01-16 23:29:56', '1', '2023-01-16 23:29:56', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (165, '公众号的消息类型', 'mp_message_type', 0, '公众号的消息类型', '1', '2023-01-17 22:17:09', '1', '2023-01-17 22:17:09', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (166, '邮件发送状态', 'system_mail_send_status', 0, '邮件发送状态', '1', '2023-01-26 09:53:13', '1', '2023-01-26 09:53:13', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (167, '站内信模版的类型', 'system_notify_template_type', 0, '站内信模版的类型', '1', '2023-01-28 10:35:10', '1', '2023-01-28 10:35:10', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (168, '代码生成的前端类型', 'infra_codegen_front_type', 0, '', '1', '2023-04-12 23:57:52', '1', '2023-04-12 23:57:52', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (170, '快递计费方式', 'trade_delivery_express_charge_mode', 0, '用于商城交易模块配送管理', '1', '2023-05-21 22:45:03', '1', '2023-05-21 22:45:03', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (171, '积分业务类型', 'member_point_biz_type', 0, '', '1', '2023-06-10 12:15:00', '1', '2023-06-28 13:48:20', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (173, '支付通知类型', 'pay_notify_type', 0, NULL, '1', '2023-07-20 12:23:03', '1', '2023-07-20 12:23:03', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (174, '会员经验业务类型', 'member_experience_biz_type', 0, NULL, '', '2023-08-22 12:41:01', '', '2023-08-22 12:41:01', 0, NULL);
INSERT INTO public.system_dict_type VALUES (175, '交易配送类型', 'trade_delivery_type', 0, '', '1', '2023-08-23 00:03:14', '1', '2023-08-23 00:03:14', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (176, '分佣模式', 'brokerage_enabled_condition', 0, NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0, NULL);
INSERT INTO public.system_dict_type VALUES (177, '分销关系绑定模式', 'brokerage_bind_mode', 0, NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0, NULL);
INSERT INTO public.system_dict_type VALUES (178, '佣金提现类型', 'brokerage_withdraw_type', 0, NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0, NULL);
INSERT INTO public.system_dict_type VALUES (179, '佣金记录业务类型', 'brokerage_record_biz_type', 0, NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0, NULL);
INSERT INTO public.system_dict_type VALUES (180, '佣金记录状态', 'brokerage_record_status', 0, NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0, NULL);
INSERT INTO public.system_dict_type VALUES (181, '佣金提现状态', 'brokerage_withdraw_status', 0, NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0, NULL);
INSERT INTO public.system_dict_type VALUES (182, '佣金提现银行', 'brokerage_bank_name', 0, NULL, '', '2023-09-28 02:46:05', '', '2023-09-28 02:46:05', 0, NULL);
INSERT INTO public.system_dict_type VALUES (183, '砍价记录的状态', 'promotion_bargain_record_status', 0, '', '1', '2023-10-05 10:41:08', '1', '2023-10-05 10:41:08', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (184, '拼团记录的状态', 'promotion_combination_record_status', 0, '', '1', '2023-10-08 07:24:25', '1', '2023-10-08 07:24:25', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (185, '回款-回款方式', 'crm_receivable_return_type', 0, '回款-回款方式', '1', '2023-10-18 21:54:10', '1', '2023-10-18 21:54:10', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (186, 'CRM 客户行业', 'crm_customer_industry', 0, 'CRM 客户所属行业', '1', '2023-10-28 22:57:07', '1', '2024-02-18 23:30:22', 0, NULL);
INSERT INTO public.system_dict_type VALUES (187, '客户等级', 'crm_customer_level', 0, 'CRM 客户等级', '1', '2023-10-28 22:59:12', '1', '2023-10-28 15:11:16', 0, NULL);
INSERT INTO public.system_dict_type VALUES (188, '客户来源', 'crm_customer_source', 0, 'CRM 客户来源', '1', '2023-10-28 23:00:34', '1', '2023-10-28 15:11:16', 0, NULL);
INSERT INTO public.system_dict_type VALUES (600, 'Banner 位置', 'promotion_banner_position', 0, '', '1', '2023-10-08 07:24:25', '1', '2023-11-04 13:04:02', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (601, '社交类型', 'system_social_type', 0, '', '1', '2023-11-04 13:03:54', '1', '2023-11-04 13:03:54', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (604, '产品状态', 'crm_product_status', 0, '', '1', '2023-10-30 21:47:59', '1', '2023-10-30 21:48:45', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (605, 'CRM 数据权限的级别', 'crm_permission_level', 0, '', '1', '2023-11-30 09:51:59', '1', '2023-11-30 09:51:59', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (606, 'CRM 审批状态', 'crm_audit_status', 0, '', '1', '2023-11-30 18:56:23', '1', '2023-11-30 18:56:23', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (607, 'CRM 产品单位', 'crm_product_unit', 0, '', '1', '2023-12-05 23:01:51', '1', '2023-12-05 23:01:51', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (608, 'CRM 跟进方式', 'crm_follow_up_type', 0, '', '1', '2024-01-15 20:48:05', '1', '2024-01-15 20:48:05', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (610, '转账订单状态', 'pay_transfer_status', 0, '', '1', '2023-10-28 16:18:32', '1', '2023-10-28 16:18:32', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (611, 'ERP 库存明细的业务类型', 'erp_stock_record_biz_type', 0, 'ERP 库存明细的业务类型', '1', '2024-02-05 18:07:02', '1', '2024-02-05 18:07:02', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (612, 'ERP 审批状态', 'erp_audit_status', 0, '', '1', '2024-02-06 00:00:07', '1', '2024-02-06 00:00:07', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (613, 'BPM 监听器类型', 'bpm_process_listener_type', 0, '', '1', '2024-03-23 12:52:24', '1', '2024-03-09 15:54:28', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (615, 'BPM 监听器值类型', 'bpm_process_listener_value_type', 0, '', '1', '2024-03-23 13:00:31', '1', '2024-03-23 13:00:31', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (616, '时间间隔', 'date_interval', 0, '', '1', '2024-03-29 22:50:09', '1', '2024-03-29 22:50:09', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (619, 'CRM 商机结束状态类型', 'crm_business_end_status_type', 0, '', '1', '2024-04-13 23:23:00', '1', '2024-04-13 23:23:00', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (620, 'AI 模型平台', 'ai_platform', 0, '', '1', '2024-05-09 22:27:38', '1', '2024-05-09 22:27:38', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (621, 'AI 绘画状态', 'ai_image_status', 0, '', '1', '2024-06-26 20:51:23', '1', '2024-06-26 20:51:23', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (622, 'AI 音乐状态', 'ai_music_status', 0, '', '1', '2024-06-27 22:45:07', '1', '2024-06-28 00:56:27', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (623, 'AI 音乐生成模式', 'ai_generate_mode', 0, '', '1', '2024-06-27 22:46:21', '1', '2024-06-28 01:22:29', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (624, '写作语气', 'ai_write_tone', 0, '', '1', '2024-07-07 15:19:02', '1', '2024-07-07 15:19:02', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (625, '写作语言', 'ai_write_language', 0, '', '1', '2024-07-07 15:18:52', '1', '2024-07-07 15:18:52', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (626, '写作长度', 'ai_write_length', 0, '', '1', '2024-07-07 15:18:41', '1', '2024-07-07 15:18:41', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (627, '写作格式', 'ai_write_format', 0, '', '1', '2024-07-07 15:14:34', '1', '2024-07-07 15:14:34', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (628, 'AI 写作类型', 'ai_write_type', 0, '', '1', '2024-07-10 21:25:29', '1', '2024-07-10 21:25:29', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (629, 'BPM 流程模型类型', 'bpm_model_type', 0, '', '1', '2024-08-26 15:21:43', '1', '2024-08-26 15:21:43', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (640, 'AI 模型类型', 'ai_model_type', 0, '', '1', '2025-03-03 12:24:07', '1', '2025-03-03 12:24:07', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1001, 'IoT 产品设备类型', 'iot_product_device_type', 0, '', '1', '2024-08-10 11:54:30', '1', '2025-03-17 09:25:08', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1002, 'IoT 产品状态', 'iot_product_status', 0, '', '1', '2024-08-10 12:06:09', '1', '2025-03-17 09:25:10', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1004, 'IoT 联网方式', 'iot_net_type', 0, '', '1', '2024-09-06 22:04:13', '1', '2025-03-17 09:25:14', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1006, 'IoT 设备状态', 'iot_device_state', 0, '', '1', '2024-09-21 08:12:55', '1', '2025-03-17 09:25:19', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1007, 'IoT 物模型功能类型', 'iot_thing_model_type', 0, '', '1', '2024-09-29 20:02:36', '1', '2025-03-17 09:25:24', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1011, 'IoT 物模型单位', 'iot_thing_model_unit', 0, '', '1', '2024-12-25 17:36:46', '1', '2025-03-17 09:25:35', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1013, 'IoT 数据流转目的的类型枚举', 'iot_data_sink_type_enum', 0, '', '1', '2025-03-09 12:39:36', '1', '2025-06-24 12:45:24', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1014, 'IoT 场景流转的触发类型枚举', 'iot_rule_scene_trigger_type_enum', 0, '', '1', '2025-03-20 14:59:44', '1', '2025-03-20 14:59:44', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1015, 'IoT 设备消息类型枚举', 'iot_device_message_type_enum', 0, '', '1', '2025-03-20 15:01:15', '1', '2025-03-20 15:01:15', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1016, 'IoT 规则场景的触发类型枚举', 'iot_rule_scene_action_type_enum', 0, '', '1', '2025-03-28 15:26:54', '1', '2025-03-28 15:29:13', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (1017, 'MES 物料消耗记录状态', 'mes_wm_item_consume_status', 0, 'MES 物料消耗记录状态', '1', '2026-03-19 15:06:23', '1', '2026-03-19 15:06:23', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2001, 'IoT 告警级别', 'iot_alert_level', 0, '', '1', '2025-06-27 20:30:57', '1', '2025-06-27 20:30:57', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (2002, 'IoT 告警', 'iot_alert_receive_type', 0, '', '1', '2025-06-27 22:49:19', '1', '2025-06-27 22:49:19', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (2003, 'IoT 固件设备范围', 'iot_ota_task_device_scope', 0, '', '1', '2025-07-02 09:42:49', '1', '2025-07-02 09:42:49', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (2004, 'IoT 固件升级任务状态', 'iot_ota_task_status', 0, '', '1', '2025-07-02 09:43:43', '1', '2025-07-02 09:43:43', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (2005, 'IoT 固件升级记录状态', 'iot_ota_task_record_status', 0, '', '1', '2025-07-02 09:45:02', '1', '2025-07-02 09:45:02', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (2007, 'AI MCP 客户端名字', 'ai_mcp_client_name', 0, '', '1', '2025-08-28 13:57:40', '1', '2025-08-28 13:57:40', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (2008, 'IoT 协议类型', 'iot_protocol_type', 0, 'IoT 设备接入协议类型', '1', '2026-02-04 00:31:33', '1', '2026-02-04 00:31:33', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (2009, 'IoT 序列化类型', 'iot_serialize_type', 0, 'IoT 设备消息序列化类型', '1', '2026-02-04 00:33:16', '1', '2026-02-04 00:33:16', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (2010, 'IoT Modbus 工作模式', 'iot_modbus_mode', 0, 'Modbus 设备数据采集模式', '1', '2025-06-12 22:55:46', '1', '2025-06-12 22:55:46', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (2011, 'IoT Modbus 帧格式', 'iot_modbus_frame_format', 0, 'Modbus 数据帧协议格式', '1', '2025-06-12 22:55:46', '1', '2025-06-12 22:55:46', 0, '1970-01-01 00:00:00');
INSERT INTO public.system_dict_type VALUES (2012, 'MES 客户类型', 'mes_client_type', 0, '', '1', '2026-02-15 14:38:25', '1', '2026-02-15 14:38:25', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2013, 'MES 供应商级别', 'mes_vendor_level', 0, '', '1', '2026-02-15 15:59:15', '1', '2026-02-15 15:59:15', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2014, 'MES 假期类型', 'mes_cal_holiday_type', 0, 'MES 日历排班 - 假期类型（HOLIDAY=假期，WORKDAY=工作日）', '1', '2026-02-16 07:35:58', '1', '2026-02-16 07:35:58', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2015, 'MES 工具状态', 'mes_tm_tool_status', 0, 'MES 工具管理 - 工具状态（1=在库，2=领用中，3=维修中，4=报废）', '1', '2026-02-16 11:10:55', '1', '2026-02-16 11:10:55', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2016, 'MES 保养维护类型', 'mes_tm_mainten_type', 0, 'MES 工具管理 - 保养维护类型（1=定期维护，2=按使用次数维护）', '1', '2026-02-16 11:10:55', '1', '2026-02-16 11:10:55', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2017, 'MES 设备状态', 'mes_dv_machinery_status', 0, 'MES 设备管理 - 设备状态（1=运行中，2=停机，3=故障）', '1', '2026-02-17 01:00:06', '1', '2026-02-17 01:00:06', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2018, 'MES 检测项类型', 'mes_indicator_type', 0, '', '1', '2026-02-17 02:16:22', '1', '2026-02-21 15:25:04', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2019, 'MES 缺陷等级', 'mes_defect_level', 0, '', '1', '2026-02-17 02:16:22', '1', '2026-02-17 02:16:22', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2020, 'MES 轮班方式', 'mes_cal_shift_type', 0, 'MES 日历排班 - 轮班方式', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2021, 'MES 倒班方式', 'mes_cal_shift_method', 0, 'MES 日历排班 - 倒班方式', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2022, 'MES 班组类型', 'mes_cal_calendar_type', 0, 'MES 日历排班 - 班组类型', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2023, 'MES 排班计划状态', 'mes_cal_plan_status', 0, 'MES 日历排班 - 排班计划状态', '1', '2026-02-17 03:40:09', '1', '2026-02-17 03:40:09', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2026, 'MES 检测种类', 'mes_qc_type', 0, 'IQC/IPQC/OQC/RQC', '1', '2026-02-17 08:34:40', '1', '2026-02-17 08:34:40', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2027, 'MES 生产工单状态', 'mes_pro_work_order_status', 0, 'MES 生产管理 - 工单状态（0=草稿，1=已确认，2=已完成，3=已取消）', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2028, 'MES 工单来源类型', 'mes_pro_work_order_source_type', 0, 'MES 生产管理 - 工单来源类型（1=客户订单，2=库存备货）', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2029, 'MES 工单类型', 'mes_pro_work_order_type', 0, 'MES 生产管理 - 工单类型（1=自行生产，2=代工，3=采购）', '1', '2026-02-17 11:43:47', '1', '2026-02-17 11:43:47', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2036, 'MES 工序关系类型', 'mes_pro_link_type', 0, '工艺路线中工序之间的关系类型', '1', '2026-02-19 04:24:53', '1', '2026-04-05 15:05:07', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2037, 'MES 时间单位', 'mes_time_unit_type', 0, '生产时间的计量单位', '1', '2026-02-19 04:24:53', '1', '2026-04-05 15:04:57', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2038, 'MES 生产任务状态', 'mes_pro_task_status', 0, 'MES 生产管理 - 任务状态（0=草稿，1=进行中，2=暂停，3=已完成，4=已取消）', '1', '2026-02-19 15:25:27', '1', '2026-02-19 15:25:27', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2039, 'MES 点检保养项目类型', 'mes_dv_subject_type', 0, 'MES 设备管理 - 点检保养项目类型（1=设备点检，2=设备保养）', '1', '2026-02-20 01:42:58', '1', '2026-02-20 01:42:58', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2040, 'MES 保养记录状态', 'mes_mainten_record_status', 0, NULL, 'admin', '2026-02-20 02:59:55', 'admin', '2026-02-20 02:59:55', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2041, 'MES 保养结果', 'mes_mainten_status', 0, NULL, 'admin', '2026-02-20 02:59:55', 'admin', '2026-02-20 02:59:55', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2042, 'MES 点检保养周期类型', 'mes_dv_cycle_type', 0, 'MES 设备管理 - 点检保养周期类型（1=天，2=周，3=月，4=年）', '1', '2026-02-20 07:11:43', '1', '2026-02-20 07:11:43', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2043, 'MES 点检保养方案状态', 'mes_dv_check_plan_status', 0, 'MES 设备管理 - 点检保养方案状态（0=草稿，1=已启用）', '1', '2026-02-20 07:11:43', '1', '2026-02-20 07:11:43', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2044, 'MES 点检记录状态', 'mes_dv_check_record_status', 0, NULL, 'admin', '2026-02-20 09:46:19', 'admin', '2026-02-20 09:46:19', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2045, 'MES 点检结果', 'mes_dv_check_result', 0, NULL, 'admin', '2026-02-20 09:46:19', 'admin', '2026-02-20 09:46:19', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2046, 'MES 维修工单状态', 'mes_dv_repair_status', 0, 'MES 设备管理 - 维修工单状态（10=待维修，20=维修中，30=已完成，40=已验收）', '1', '2026-02-20 10:56:24', '1', '2026-02-20 10:56:24', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2047, 'MES 维修结果', 'mes_dv_repair_result', 0, 'MES 设备管理 - 维修结果（1=修复成功，2=报废）', '1', '2026-02-20 10:56:24', '1', '2026-02-20 10:56:24', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2049, 'MES 检测结果', 'mes_qc_check_result', 0, '来料检验的最终结果判定', '1', '2026-02-20 11:23:35', '1', '2026-02-20 11:23:35', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2050, 'MES 来源单据类型', 'mes_qc_source_doc_type', 0, 'IQC 来料检验的来源单据类型', '1', '2026-02-20 11:23:35', '1', '2026-02-20 11:23:35', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2051, 'MES 安灯处置状态', 'mes_pro_andon_status', 0, 'MES 生产管理 - 安灯处置状态（0=未处置，1=已处置）', '1', '2026-02-21 00:08:38', '1', '2026-02-21 00:08:38', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2052, 'MES 安灯级别', 'mes_pro_andon_level', 0, 'MES 生产管理 - 安灯级别（1=一级，2=二级，3=三级）', '1', '2026-02-21 00:08:38', '1', '2026-02-21 00:08:38', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2053, 'MES 生产报工状态', 'mes_pro_feedback_status', 0, 'MES 生产管理 - 报工状态（0=草稿，1=审批中，2=待检验，3=已完成，4=已取消）', '1', '2026-02-21 00:50:32', '1', '2026-02-21 00:50:32', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2054, 'MES 生产报工类型', 'mes_pro_feedback_type', 0, 'MES 生产管理 - 报工类型（1=自行报工，2=统一报工）', '1', '2026-02-21 00:50:32', '1', '2026-02-21 00:50:32', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2055, 'MES 生产报工途径', 'mes_pro_feedback_channel', 0, 'MES 生产管理 - 报工途径（PC/APP/PDA）', '1', '2026-02-21 00:50:32', '1', '2026-02-21 00:50:32', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2056, 'MES 质检值类型', 'mes_qc_result_type', 0, '检验结果明细的值类型：浮点/整数/文本/字典/文件', '1', '2026-02-21 13:37:17', '1', '2026-02-21 13:37:17', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2057, 'MES 退货检验类型', 'mes_rqc_type', 0, 'MES 退货检验类型', '1', '2026-02-22 06:43:18', '1', '2026-02-22 06:43:18', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2062, 'MES IPQC 检验类型', 'mes_ipqc_type', 0, 'IPQC 过程检验的检验类型', '1', '2026-02-22 07:01:04', '1', '2026-02-22 07:01:04', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2066, 'MES 到货通知单状态', 'mes_wm_arrival_notice_status', 0, 'MES 到货通知单状态', '1', '2026-02-22 14:53:18', '1', '2026-02-22 14:53:18', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2067, 'MES 采购入库单状态', 'mes_wm_item_receipt_status', 0, 'MES 采购入库单状态', '1', '2026-02-22 14:54:05', '1', '2026-02-22 14:54:05', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2068, 'MES 单据状态', 'mes_order_status', 0, '', '1', '2026-02-23 21:16:03', '1', '2026-02-23 21:17:37', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2069, 'MES 领料出库单状态', 'mes_wm_product_issue_status', 0, 'MES 领料出库单状态', '1', '2026-02-26 16:39:44', '1', '2026-04-05 15:05:11', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2073, 'MES 生产退料单状态', 'mes_wm_return_issue_status', 0, 'MES 生产退料单状态', '1', '2026-02-28 14:11:09', '1', '2026-04-05 15:05:14', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2074, 'MES 生产退料类型', 'mes_wm_return_issue_type', 0, 'MES 生产退料类型', '1', '2026-02-28 14:11:09', '1', '2026-04-05 15:05:16', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2075, 'MES 质量状态', 'mes_wm_quality_status', 0, 'MES 质量状态（待检/合格/不合格）', '1', '2026-02-28 15:00:53', '1', '2026-02-28 15:00:53', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2100, 'MES 产品入库单状态', 'mes_wm_product_receipt_status', 0, 'MES 产品入库单状态', '1', '2026-03-01 06:03:04', '1', '2026-04-05 15:05:49', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2102, 'MES 销售出库单状态', 'mes_wm_product_sales_status', 0, 'MES 销售出库单状态', '1', '2026-03-02 08:55:11', '1', '2026-04-05 15:05:18', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2105, 'MES 杂项入库类型', 'mes_wm_misc_receipt_type', 0, '杂项入库类型', '1', '2026-03-03 07:18:12', '1', '2026-04-05 15:05:23', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2106, 'MES 杂项入库状态', 'mes_wm_misc_receipt_status', 0, '杂项入库状态', '1', '2026-03-03 07:18:12', '1', '2026-04-05 15:05:25', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2109, 'MES 杂项出库类型', 'mes_wm_misc_issue_type', 0, 'MES 杂项出库类型', '1', '2026-03-03 07:34:33', '1', '2026-03-03 07:34:33', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2110, 'MES 外协入库单状态', 'mes_wm_outsource_receipt_status', 0, 'MES 外协入库单状态', '1', '2026-03-03 14:03:20', '1', '2026-03-03 14:03:20', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2112, 'MES 外协发料单状态', 'mes_wm_outsource_issue_status', 0, 'MES 外协发料单状态', '1', '2026-03-03 16:30:56', '1', '2026-04-05 15:05:47', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2113, 'MES 编码规则分段类型', 'mes_md_auto_code_part_type', 0, 'MES 编码规则分段类型', '1', '2026-03-04 14:45:46', '1', '2026-03-04 15:24:40', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2115, 'MES 编码规则补齐方式', 'mes_md_auto_code_padded_method', 0, 'MES 编码规则补齐方式', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2116, 'MES 编码规则循环方式', 'mes_md_auto_code_cycle_method', 0, 'MES 编码规则循环方式', '1', '2026-03-04 14:46:22', '1', '2026-03-04 15:24:40', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2117, 'MES 条码格式', 'mes_wm_barcode_format', 0, 'MES 条码格式', '1', '2026-03-05 14:37:20', '1', '2026-04-05 15:05:27', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2118, 'MES 条码业务类型', 'mes_wm_barcode_biz_type', 0, 'MES 条码业务类型', '1', '2026-03-05 14:37:20', '1', '2026-04-05 15:05:29', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2121, 'MES 装箱单状态', 'mes_wm_package_status', 0, 'MES 装箱单状态', '1', '2026-03-08 02:05:46', '1', '2026-04-05 15:05:35', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2122, 'MES 调拨单状态', 'mes_wm_transfer_status', 0, 'MES 调拨单状态', '1', '2026-03-08 11:55:25', '1', '2026-03-08 11:55:25', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2123, 'MES 调拨类型', 'mes_wm_transfer_type', 0, 'MES 调拨类型', '1', '2026-03-08 11:55:25', '1', '2026-03-08 11:55:25', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2124, 'MES 盘点类型', 'mes_wm_stock_taking_type', 0, 'MES 盘点类型', '1', '2026-03-09 00:00:00', '1', '2026-03-09 00:00:00', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2125, 'MES 盘点方案参数类型', 'mes_wm_stock_taking_plan_param_type', 0, 'MES 盘点方案参数类型', '1', '2026-03-09 00:00:00', '1', '2026-03-09 00:00:00', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2126, 'MES 盘点任务状态', 'mes_wm_stock_taking_task_status', 0, 'MES 盘点任务状态', '1', '2026-03-09 00:00:00', '1', '2026-03-09 00:00:00', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2127, 'MES 盘点任务行状态', 'mes_wm_stock_taking_task_line_status', 0, 'MES 盘点任务行状态', '1', '2026-03-09 00:00:00', '1', '2026-04-05 15:02:18', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2129, 'MES 物料产品标识', 'mes_md_item_or_product', 0, '物料分类：物料(ITEM) / 产品(PRODUCT)', '1', '2026-03-15 01:55:06', '1', '2026-03-15 01:55:06', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2130, 'MES 供应商退货单状态', 'mes_wm_return_vendor_status', 0, '采购退货单状态', '', '2026-03-29 13:49:57', '', '2026-04-05 15:53:46', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2131, 'MES 发货通知单状态', 'mes_wm_sales_notice_status', 0, 'MES 发货通知单状态', '1', '2026-03-30 08:54:30', '1', '2026-04-05 15:53:46', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2132, 'MES 杂项出库单状态', 'mes_wm_misc_issue_status', 0, '杂项出库单状态', '1', '2026-03-30 15:00:18', '1', '2026-04-05 15:05:41', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2133, 'MES 销售退货单状态', 'mes_wm_return_sales_status', 0, 'MES 销售退货单状态枚举', '1', '2026-04-03 17:20:25', '1', '2026-04-05 15:05:39', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2134, 'MES 缺陷检测项类型', 'mes_defect_type', 0, '缺陷模块的检测项类型字典', '1', '2026-04-04 12:49:51', '1', '2026-04-04 12:49:51', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2135, 'MES 上下工状态类型', 'mes_pro_work_record_type', 0, 'MES 上下工状态类型', '1', '2026-04-05 14:07:27', '1', '2026-04-05 14:07:27', 0, NULL);
INSERT INTO public.system_dict_type VALUES (2138, 'MES 生产入库单状态', 'mes_wm_product_produce_status', 0, 'MES 生产入库单状态', '1', '2026-04-05 15:53:46', '1', '2026-04-05 15:53:46', 0, '1970-01-01 00:00:00');


--
-- Data for Name: system_login_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_mail_account; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_mail_account VALUES (1, '7684413@qq.com', '7684413@qq.com', '', '127.0.0.1', 8080, false, false, '1', '2023-01-25 17:39:52', '1', '2026-07-16 07:29:32.31865', 0);
INSERT INTO public.system_mail_account VALUES (2, 'ydym_test@163.com', 'ydym_test@163.com', '', 'smtp.163.com', 465, true, false, '1', '2023-01-26 01:26:03', '1', '2026-07-16 07:29:32.31865', 0);
INSERT INTO public.system_mail_account VALUES (3, '76854114@qq.com', '3335', '', 'yunai1.cn', 466, false, false, '1', '2023-01-27 15:06:38', '1', '2026-07-16 07:29:32.31865', 1);
INSERT INTO public.system_mail_account VALUES (4, '7685413x@qq.com', '2', '', '4', 5, true, false, '1', '2023-04-12 23:05:06', '1', '2026-07-16 07:29:32.31865', 1);


--
-- Data for Name: system_mail_log; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_mail_log VALUES (2, NULL, 2, 'nobody@example.com', NULL, NULL, 2, 'ydym_test@163.com', 14, 'test_01', '芋艿', '一个标题', '<p>你是 A 吗？</p><p><br></p><p>是的话，赶紧 B 一下！</p>', '{"key01":"A","key02":"B"}', 30, '2026-07-16 07:29:59.563274', NULL, 'mail provider is not configured', 'admin', '2026-07-16 07:29:59.563274', 'admin', '2026-07-16 07:29:59.563274', 0);
INSERT INTO public.system_mail_log VALUES (3, NULL, 2, 'test@example.com', NULL, NULL, 1, '7684413@qq.com', 13, 'admin-sms-login', '奥特曼', '你猜我猜', '<p>您的验证码是{code}，名字是Codex</p>', '{"name":"Codex"}', 30, '2026-07-16 07:41:03.257612', NULL, 'mail provider is not configured', 'admin', '2026-07-16 07:41:03.257612', 'admin', '2026-07-16 07:41:03.257612', 0);


--
-- Data for Name: system_mail_template; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_mail_template VALUES (13, '后台用户短信登录', 'admin-sms-login', 1, '奥特曼', '你猜我猜', '<p>您的验证码是{code}，名字是{name}</p>', '["code","name"]', 0, '3', '1', '2021-10-11 08:10:00', '1', '2023-12-02 19:51:14', 0);
INSERT INTO public.system_mail_template VALUES (14, '测试模版', 'test_01', 2, '芋艿', '一个标题', '<p>你是 {key01} 吗？</p><p><br></p><p>是的话，赶紧 {key02} 一下！</p>', '["key01","key02"]', 0, NULL, '1', '2023-01-26 01:27:40', '1', '2025-07-26 21:48:45', 0);
INSERT INTO public.system_mail_template VALUES (15, '3', '2', 2, '7', '4', '<p>45</p>', '[]', 1, '80', '1', '2023-01-27 15:50:35', '1', '2025-07-26 21:47:49', 1);


--
-- Data for Name: system_menu; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_menu VALUES (1, '系统管理', '', 1, 10, 0, '/system', 'ep:tools', NULL, NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2025-03-15 21:30:27', 0);
INSERT INTO public.system_menu VALUES (2, '基础设施', '', 1, 20, 0, '/infra', 'ep:monitor', NULL, NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-03-01 08:28:40', 0);
INSERT INTO public.system_menu VALUES (5, 'OA 示例', '', 1, 40, 1185, 'oa', 'fa:road', NULL, NULL, 0, true, true, true, 'admin', '2021-09-20 16:26:19', '1', '2024-02-29 12:38:13', 0);
INSERT INTO public.system_menu VALUES (100, '用户管理', 'system:user:list', 2, 1, 1, 'user', 'ep:avatar', 'system/user/index', 'SystemUser', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2026-01-01 18:43:01', 0);
INSERT INTO public.system_menu VALUES (101, '角色管理', '', 2, 2, 1, 'role', 'ep:user', 'system/role/index', 'SystemRole', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2026-01-05 19:30:33', 0);
INSERT INTO public.system_menu VALUES (102, '菜单管理', '', 2, 3, 1, 'menu', 'ep:menu', 'system/menu/index', 'SystemMenu', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 01:03:50', 0);
INSERT INTO public.system_menu VALUES (103, '部门管理', '', 2, 4, 1, 'dept', 'fa:address-card', 'system/dept/index', 'SystemDept', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 01:06:28', 0);
INSERT INTO public.system_menu VALUES (104, '岗位管理', '', 2, 5, 1, 'post', 'fa:address-book-o', 'system/post/index', 'SystemPost', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 01:06:39', 0);
INSERT INTO public.system_menu VALUES (105, '字典管理', '', 2, 6, 1, 'dict', 'ep:collection', 'system/dict/index', 'SystemDictType', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 01:07:12', 0);
INSERT INTO public.system_menu VALUES (106, '配置管理', '', 2, 8, 2, 'config', 'fa:connectdevelop', 'infra/config/index', 'InfraConfig', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-04-23 00:02:45', 0);
INSERT INTO public.system_menu VALUES (107, '通知公告', '', 2, 4, 2739, 'notice', 'ep:takeaway-box', 'system/notice/index', 'SystemNotice', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-04-22 23:56:17', 0);
INSERT INTO public.system_menu VALUES (108, '审计日志', '', 1, 9, 1, 'log', 'ep:document-copy', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 01:08:30', 0);
INSERT INTO public.system_menu VALUES (109, '令牌管理', '', 2, 2, 1261, 'token', 'fa:key', 'system/oauth2/token/index', 'SystemTokenClient', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 01:13:48', 0);
INSERT INTO public.system_menu VALUES (110, '定时任务', '', 2, 7, 2, 'job', 'fa-solid:tasks', 'infra/job/index', 'InfraJob', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 08:57:36', 0);
INSERT INTO public.system_menu VALUES (111, 'MySQL 监控', '', 2, 1, 2740, 'druid', 'fa-solid:box', 'infra/druid/index', 'InfraDruid', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-04-23 00:05:58', 0);
INSERT INTO public.system_menu VALUES (112, 'Java 监控', '', 2, 3, 2740, 'admin-server', 'ep:coffee-cup', 'infra/server/index', 'InfraAdminServer', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-04-23 00:06:57', 0);
INSERT INTO public.system_menu VALUES (113, 'Redis 监控', '', 2, 2, 2740, 'redis', 'fa:reddit-square', 'infra/redis/index', 'InfraRedis', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-04-23 00:06:09', 0);
INSERT INTO public.system_menu VALUES (114, '表单构建', 'infra:build:list', 2, 2, 2, 'build', 'fa:wpforms', 'infra/build/index', 'InfraBuild', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 08:51:35', 0);
INSERT INTO public.system_menu VALUES (115, '代码生成', 'infra:codegen:query', 2, 1, 2, 'codegen', 'ep:document-copy', 'infra/codegen/index', 'InfraCodegen', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 08:51:06', 0);
INSERT INTO public.system_menu VALUES (116, 'API 接口', 'infra:swagger:list', 2, 3, 2, 'swagger', 'fa:fighter-jet', 'infra/swagger/index', 'InfraSwagger', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-04-23 00:01:24', 0);
INSERT INTO public.system_menu VALUES (500, '操作日志', '', 2, 1, 108, 'operate-log', 'ep:position', 'system/operatelog/index', 'SystemOperateLog', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 01:09:59', 0);
INSERT INTO public.system_menu VALUES (501, '登录日志', '', 2, 2, 108, 'login-log', 'ep:promotion', 'system/loginlog/index', 'SystemLoginLog', 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2024-02-29 01:10:29', 0);
INSERT INTO public.system_menu VALUES (1001, '用户查询', 'system:user:query', 3, 1, 100, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1002, '用户新增', 'system:user:create', 3, 2, 100, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1003, '用户修改', 'system:user:update', 3, 3, 100, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1004, '用户删除', 'system:user:delete', 3, 4, 100, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1005, '用户导出', 'system:user:export', 3, 5, 100, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1006, '用户导入', 'system:user:import', 3, 6, 100, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1007, '重置密码', 'system:user:update-password', 3, 7, 100, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1008, '角色查询', 'system:role:query', 3, 1, 101, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1009, '角色新增', 'system:role:create', 3, 2, 101, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1010, '角色修改', 'system:role:update', 3, 3, 101, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1011, '角色删除', 'system:role:delete', 3, 4, 101, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1012, '角色导出', 'system:role:export', 3, 5, 101, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1013, '菜单查询', 'system:menu:query', 3, 1, 102, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1014, '菜单新增', 'system:menu:create', 3, 2, 102, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1015, '菜单修改', 'system:menu:update', 3, 3, 102, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1016, '菜单删除', 'system:menu:delete', 3, 4, 102, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1017, '部门查询', 'system:dept:query', 3, 1, 103, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1018, '部门新增', 'system:dept:create', 3, 2, 103, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1019, '部门修改', 'system:dept:update', 3, 3, 103, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1020, '部门删除', 'system:dept:delete', 3, 4, 103, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1021, '岗位查询', 'system:post:query', 3, 1, 104, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1022, '岗位新增', 'system:post:create', 3, 2, 104, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1023, '岗位修改', 'system:post:update', 3, 3, 104, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1024, '岗位删除', 'system:post:delete', 3, 4, 104, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1025, '岗位导出', 'system:post:export', 3, 5, 104, '', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1026, '字典查询', 'system:dict:query', 3, 1, 105, '#', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1027, '字典新增', 'system:dict:create', 3, 2, 105, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1028, '字典修改', 'system:dict:update', 3, 3, 105, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1029, '字典删除', 'system:dict:delete', 3, 4, 105, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1030, '字典导出', 'system:dict:export', 3, 5, 105, '#', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1031, '配置查询', 'infra:config:query', 3, 1, 106, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1032, '配置新增', 'infra:config:create', 3, 2, 106, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1033, '配置修改', 'infra:config:update', 3, 3, 106, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1034, '配置删除', 'infra:config:delete', 3, 4, 106, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1035, '配置导出', 'infra:config:export', 3, 5, 106, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1036, '公告查询', 'system:notice:query', 3, 1, 107, '#', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1037, '公告新增', 'system:notice:create', 3, 2, 107, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1038, '公告修改', 'system:notice:update', 3, 3, 107, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1039, '公告删除', 'system:notice:delete', 3, 4, 107, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1040, '操作查询', 'system:operate-log:query', 3, 1, 500, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1042, '日志导出', 'system:operate-log:export', 3, 2, 500, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1043, '登录查询', 'system:login-log:query', 3, 1, 501, '#', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1045, '日志导出', 'system:login-log:export', 3, 3, 501, '#', '#', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1046, '令牌列表', 'system:oauth2-token:page', 3, 1, 109, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-05-09 23:54:42', 0);
INSERT INTO public.system_menu VALUES (1048, '令牌删除', 'system:oauth2-token:delete', 3, 2, 109, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-05-09 23:54:53', 0);
INSERT INTO public.system_menu VALUES (1050, '任务新增', 'infra:job:create', 3, 2, 110, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1051, '任务修改', 'infra:job:update', 3, 3, 110, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1052, '任务删除', 'infra:job:delete', 3, 4, 110, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1053, '状态修改', 'infra:job:update', 3, 5, 110, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1054, '任务导出', 'infra:job:export', 3, 7, 110, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1056, '生成修改', 'infra:codegen:update', 3, 2, 115, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1057, '生成删除', 'infra:codegen:delete', 3, 3, 115, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1058, '导入代码', 'infra:codegen:create', 3, 2, 115, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1059, '预览代码', 'infra:codegen:preview', 3, 4, 115, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1060, '生成代码', 'infra:codegen:download', 3, 5, 115, '', '', '', NULL, 0, true, true, true, 'admin', '2021-01-05 17:03:48', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1063, '设置角色菜单权限', 'system:permission:assign-role-menu', 3, 6, 101, '', '', '', NULL, 0, true, true, true, '', '2021-01-06 17:53:44', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1064, '设置角色数据权限', 'system:permission:assign-role-data-scope', 3, 7, 101, '', '', '', NULL, 0, true, true, true, '', '2021-01-06 17:56:31', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1065, '设置用户角色', 'system:permission:assign-user-role', 3, 8, 101, '', '', '', NULL, 0, true, true, true, '', '2021-01-07 10:23:28', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1066, '获得 Redis 监控信息', 'infra:redis:get-monitor-info', 3, 1, 113, '', '', '', NULL, 0, true, true, true, '', '2021-01-26 01:02:31', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1067, '获得 Redis Key 列表', 'infra:redis:get-key-list', 3, 2, 113, '', '', '', NULL, 0, true, true, true, '', '2021-01-26 01:02:52', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1070, '代码生成案例', '', 1, 1, 2, 'demo', 'ep:aim', 'infra/testDemo/index', NULL, 0, true, true, true, '', '2021-02-06 12:42:49', '1', '2023-11-15 23:45:53', 0);
INSERT INTO public.system_menu VALUES (1075, '任务触发', 'infra:job:trigger', 3, 8, 110, '', '', '', NULL, 0, true, true, true, '', '2021-02-07 13:03:10', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1077, '链路追踪', '', 2, 4, 2740, 'skywalking', 'fa:eye', 'infra/skywalking/index', 'InfraSkyWalking', 0, true, true, true, '', '2021-02-08 20:41:31', '1', '2024-04-23 00:07:15', 0);
INSERT INTO public.system_menu VALUES (1078, '访问日志', '', 2, 1, 1083, 'api-access-log', 'ep:place', 'infra/apiAccessLog/index', 'InfraApiAccessLog', 0, true, true, true, '', '2021-02-26 01:32:59', '1', '2024-02-29 08:54:57', 0);
INSERT INTO public.system_menu VALUES (1082, '日志导出', 'infra:api-access-log:export', 3, 2, 1078, '', '', '', NULL, 0, true, true, true, '', '2021-02-26 01:32:59', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1083, 'API 日志', '', 2, 4, 2, 'log', 'fa:tasks', NULL, NULL, 0, true, true, true, '', '2021-02-26 02:18:24', '1', '2024-04-22 23:58:36', 0);
INSERT INTO public.system_menu VALUES (1084, '错误日志', 'infra:api-error-log:query', 2, 2, 1083, 'api-error-log', 'ep:warning-filled', 'infra/apiErrorLog/index', 'InfraApiErrorLog', 0, true, true, true, '', '2021-02-26 07:53:20', '1', '2024-02-29 08:55:17', 0);
INSERT INTO public.system_menu VALUES (1085, '日志处理', 'infra:api-error-log:update-status', 3, 2, 1084, '', '', '', NULL, 0, true, true, true, '', '2021-02-26 07:53:20', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1086, '日志导出', 'infra:api-error-log:export', 3, 3, 1084, '', '', '', NULL, 0, true, true, true, '', '2021-02-26 07:53:20', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1087, '任务查询', 'infra:job:query', 3, 1, 110, '', '', '', NULL, 0, true, true, true, '1', '2021-03-10 01:26:19', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1088, '日志查询', 'infra:api-access-log:query', 3, 1, 1078, '', '', '', NULL, 0, true, true, true, '1', '2021-03-10 01:28:04', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1089, '日志查询', 'infra:api-error-log:query', 3, 1, 1084, '', '', '', NULL, 0, true, true, true, '1', '2021-03-10 01:29:09', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1090, '文件列表', '', 2, 5, 1243, 'file', 'ep:upload-filled', 'infra/file/index', 'InfraFile', 0, true, true, true, '', '2021-03-12 20:16:20', '1', '2024-02-29 08:53:02', 0);
INSERT INTO public.system_menu VALUES (1091, '文件查询', 'infra:file:query', 3, 1, 1090, '', '', '', NULL, 0, true, true, true, '', '2021-03-12 20:16:20', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1092, '文件删除', 'infra:file:delete', 3, 4, 1090, '', '', '', NULL, 0, true, true, true, '', '2021-03-12 20:16:20', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1093, '短信管理', '', 1, 1, 2739, 'sms', 'ep:message', NULL, NULL, 0, true, true, true, '1', '2021-04-05 01:10:16', '1', '2024-04-22 23:56:03', 0);
INSERT INTO public.system_menu VALUES (1094, '短信渠道', '', 2, 0, 1093, 'sms-channel', 'fa:stack-exchange', 'system/sms/channel/index', 'SystemSmsChannel', 0, true, true, true, '', '2021-04-01 11:07:15', '1', '2024-02-29 01:15:54', 0);
INSERT INTO public.system_menu VALUES (1095, '短信渠道查询', 'system:sms-channel:query', 3, 1, 1094, '', '', '', NULL, 0, true, true, true, '', '2021-04-01 11:07:15', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1096, '短信渠道创建', 'system:sms-channel:create', 3, 2, 1094, '', '', '', NULL, 0, true, true, true, '', '2021-04-01 11:07:15', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1097, '短信渠道更新', 'system:sms-channel:update', 3, 3, 1094, '', '', '', NULL, 0, true, true, true, '', '2021-04-01 11:07:15', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1098, '短信渠道删除', 'system:sms-channel:delete', 3, 4, 1094, '', '', '', NULL, 0, true, true, true, '', '2021-04-01 11:07:15', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1100, '短信模板', '', 2, 1, 1093, 'sms-template', 'ep:connection', 'system/sms/template/index', 'SystemSmsTemplate', 0, true, true, true, '', '2021-04-01 17:35:17', '1', '2024-02-29 01:16:18', 0);
INSERT INTO public.system_menu VALUES (1101, '短信模板查询', 'system:sms-template:query', 3, 1, 1100, '', '', '', NULL, 0, true, true, true, '', '2021-04-01 17:35:17', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1102, '短信模板创建', 'system:sms-template:create', 3, 2, 1100, '', '', '', NULL, 0, true, true, true, '', '2021-04-01 17:35:17', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1103, '短信模板更新', 'system:sms-template:update', 3, 3, 1100, '', '', '', NULL, 0, true, true, true, '', '2021-04-01 17:35:17', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1104, '短信模板删除', 'system:sms-template:delete', 3, 4, 1100, '', '', '', NULL, 0, true, true, true, '', '2021-04-01 17:35:17', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1105, '短信模板导出', 'system:sms-template:export', 3, 5, 1100, '', '', '', NULL, 0, true, true, true, '', '2021-04-01 17:35:17', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1106, '发送测试短信', 'system:sms-template:send-sms', 3, 6, 1100, '', '', '', NULL, 0, true, true, true, '1', '2021-04-11 00:26:40', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1107, '短信日志', '', 2, 2, 1093, 'sms-log', 'fa:edit', 'system/sms/log/index', 'SystemSmsLog', 0, true, true, true, '', '2021-04-11 08:37:05', '1', '2024-02-29 08:49:02', 0);
INSERT INTO public.system_menu VALUES (1108, '短信日志查询', 'system:sms-log:query', 3, 1, 1107, '', '', '', NULL, 0, true, true, true, '', '2021-04-11 08:37:05', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1109, '短信日志导出', 'system:sms-log:export', 3, 5, 1107, '', '', '', NULL, 0, true, true, true, '', '2021-04-11 08:37:05', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1118, '请假查询', '', 2, 0, 5, 'leave', 'fa:leanpub', 'bpm/oa/leave/index', 'BpmOALeave', 0, true, true, true, '', '2021-09-20 08:51:03', '1', '2024-02-29 12:38:21', 0);
INSERT INTO public.system_menu VALUES (1119, '请假申请查询', 'bpm:oa-leave:query', 3, 1, 1118, '', '', '', NULL, 0, true, true, true, '', '2021-09-20 08:51:03', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1120, '请假申请创建', 'bpm:oa-leave:create', 3, 2, 1118, '', '', '', NULL, 0, true, true, true, '', '2021-09-20 08:51:03', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (6100, '招标管理', '', 1, 20, 0, '/bid', 'ant-design:solution-outlined', NULL, NULL, 0, true, true, true, 'system', '2026-07-14 06:07:11.723882', 'system', '2026-07-15 10:45:40.087609', 0);
INSERT INTO public.system_menu VALUES (6101, '招标公告', 'bid:notice:query', 2, 1, 6100, 'notice', 'ant-design:notification-outlined', 'bid/notice/index', 'BidNotice', 0, true, true, true, 'system', '2026-07-14 06:07:11.723882', 'system', '2026-07-15 10:45:40.087609', 0);
INSERT INTO public.system_menu VALUES (6102, '投标商机', 'bid:opportunity:query', 2, 2, 6100, 'opportunity', 'ant-design:bulb-outlined', 'bid/opportunity/index', 'BidOpportunity', 0, true, true, true, 'system', '2026-07-14 06:07:11.723882', 'system', '2026-07-15 10:45:40.087609', 0);
INSERT INTO public.system_menu VALUES (1138, '租户列表', '', 2, 0, 1224, 'list', 'ep:house', 'system/tenant/index', 'SystemTenant', 0, true, true, true, '', '2021-12-14 12:31:43', '1', '2024-02-29 01:01:10', 0);
INSERT INTO public.system_menu VALUES (1139, '租户查询', 'system:tenant:query', 3, 1, 1138, '', '', '', NULL, 0, true, true, true, '', '2021-12-14 12:31:44', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1140, '租户创建', 'system:tenant:create', 3, 2, 1138, '', '', '', NULL, 0, true, true, true, '', '2021-12-14 12:31:44', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1141, '租户更新', 'system:tenant:update', 3, 3, 1138, '', '', '', NULL, 0, true, true, true, '', '2021-12-14 12:31:44', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1142, '租户删除', 'system:tenant:delete', 3, 4, 1138, '', '', '', NULL, 0, true, true, true, '', '2021-12-14 12:31:44', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1143, '租户导出', 'system:tenant:export', 3, 5, 1138, '', '', '', NULL, 0, true, true, true, '', '2021-12-14 12:31:44', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (6103, '投标项目', 'bid:project:query', 2, 3, 6100, 'project', 'ant-design:project-outlined', 'bid/project/index', 'BidProject', 0, true, true, true, 'system', '2026-07-14 06:07:11.723882', 'system', '2026-07-15 10:45:40.087609', 0);
INSERT INTO public.system_menu VALUES (6124, '商机跟进', 'bid:opportunity:follow', 3, 4, 6102, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-14 08:22:10.528054', 'system', '2026-07-15 10:45:40.120637', 0);
INSERT INTO public.system_menu VALUES (6125, '商机转项目', 'bid:opportunity:convert', 3, 5, 6102, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-14 08:22:10.528054', 'system', '2026-07-15 10:45:40.120637', 0);
INSERT INTO public.system_menu VALUES (6131, '项目修改', 'bid:project:update', 3, 1, 6103, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-14 08:22:10.528054', 'system', '2026-07-15 10:45:40.120637', 0);
INSERT INTO public.system_menu VALUES (1185, '工作流程', '', 1, 50, 0, '/bpm', 'fa:medium', NULL, NULL, 0, true, true, true, '1', '2021-12-30 20:26:36', '1', '2024-02-29 12:43:43', 0);
INSERT INTO public.system_menu VALUES (1186, '流程管理', '', 1, 10, 1185, 'manager', 'fa:dedent', NULL, NULL, 0, true, true, true, '1', '2021-12-30 20:28:30', '1', '2024-02-29 12:36:02', 0);
INSERT INTO public.system_menu VALUES (1187, '流程表单', '', 2, 2, 1186, 'form', 'fa:hdd-o', 'bpm/form/index', 'BpmForm', 0, true, true, true, '', '2021-12-30 12:38:22', '1', '2024-03-19 12:25:25', 0);
INSERT INTO public.system_menu VALUES (1188, '表单查询', 'bpm:form:query', 3, 1, 1187, '', '', '', NULL, 0, true, true, true, '', '2021-12-30 12:38:22', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1189, '表单创建', 'bpm:form:create', 3, 2, 1187, '', '', '', NULL, 0, true, true, true, '', '2021-12-30 12:38:22', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1190, '表单更新', 'bpm:form:update', 3, 3, 1187, '', '', '', NULL, 0, true, true, true, '', '2021-12-30 12:38:22', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1191, '表单删除', 'bpm:form:delete', 3, 4, 1187, '', '', '', NULL, 0, true, true, true, '', '2021-12-30 12:38:22', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1192, '表单导出', 'bpm:form:export', 3, 5, 1187, '', '', '', NULL, 0, true, true, true, '', '2021-12-30 12:38:22', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1193, '流程模型', '', 2, 1, 1186, 'model', 'fa-solid:project-diagram', 'bpm/model/index', 'BpmModel', 0, true, true, true, '1', '2021-12-31 23:24:58', '1', '2024-03-19 12:25:19', 0);
INSERT INTO public.system_menu VALUES (1194, '模型查询', 'bpm:model:query', 3, 1, 1193, '', '', '', NULL, 0, true, true, true, '1', '2022-01-03 19:01:10', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1195, '模型创建', 'bpm:model:create', 3, 2, 1193, '', '', '', NULL, 0, true, true, true, '1', '2022-01-03 19:01:24', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1197, '模型更新', 'bpm:model:update', 3, 4, 1193, '', '', '', NULL, 0, true, true, true, '1', '2022-01-03 19:02:28', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1198, '模型删除', 'bpm:model:delete', 3, 5, 1193, '', '', '', NULL, 0, true, true, true, '1', '2022-01-03 19:02:43', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1199, '模型发布', 'bpm:model:deploy', 3, 6, 1193, '', '', '', NULL, 0, true, true, true, '1', '2022-01-03 19:03:24', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1200, '审批中心', '', 2, 20, 1185, 'task', 'fa:tasks', NULL, NULL, 0, true, true, true, '1', '2022-01-07 23:51:48', '1', '2024-03-21 00:33:15', 0);
INSERT INTO public.system_menu VALUES (1201, '我的流程', '', 2, 1, 1200, 'my', 'fa-solid:book', 'bpm/processInstance/index', 'BpmProcessInstanceMy', 0, true, true, true, '', '2022-01-07 15:53:44', '1', '2024-03-21 23:52:12', 0);
INSERT INTO public.system_menu VALUES (1202, '流程实例的查询', 'bpm:process-instance:query', 3, 1, 1201, '', '', '', NULL, 0, true, true, true, '', '2022-01-07 15:53:44', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1207, '待办任务', '', 2, 10, 1200, 'todo', 'fa:slack', 'bpm/task/todo/index', 'BpmTodoTask', 0, true, true, true, '1', '2022-01-08 10:33:37', '1', '2024-02-29 12:37:39', 0);
INSERT INTO public.system_menu VALUES (1208, '已办任务', '', 2, 20, 1200, 'done', 'fa:delicious', 'bpm/task/done/index', 'BpmDoneTask', 0, true, true, true, '1', '2022-01-08 10:34:13', '1', '2024-02-29 12:37:54', 0);
INSERT INTO public.system_menu VALUES (1209, '用户分组', '', 2, 4, 1186, 'user-group', 'fa:user-secret', 'bpm/group/index', 'BpmUserGroup', 0, true, true, true, '', '2022-01-14 02:14:20', '1', '2024-03-21 23:55:29', 0);
INSERT INTO public.system_menu VALUES (1210, '用户组查询', 'bpm:user-group:query', 3, 1, 1209, '', '', '', NULL, 0, true, true, true, '', '2022-01-14 02:14:20', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (6104, '爬虫管理', 'bid:crawler:query', 2, 4, 6100, 'crawler', 'ant-design:bug-outlined', 'bid/crawler/index', 'BidCrawler', 0, true, true, true, 'system', '2026-07-15 00:40:22.525741', 'system', '2026-07-15 10:45:40.148945', 0);
INSERT INTO public.system_menu VALUES (6141, '爬虫查询', 'bid:crawler:query', 3, 1, 6104, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 00:40:22.525741', 'system', '2026-07-15 10:45:40.148945', 0);
INSERT INTO public.system_menu VALUES (6142, '爬虫任务创建', 'bid:crawler:create', 3, 2, 6104, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 00:40:22.525741', 'system', '2026-07-15 10:45:40.148945', 0);
INSERT INTO public.system_menu VALUES (6143, '爬虫任务重试', 'bid:crawler:retry', 3, 3, 6104, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 00:40:22.525741', 'system', '2026-07-15 10:45:40.148945', 0);
INSERT INTO public.system_menu VALUES (6144, '爬虫调度管理', 'bid:crawler:schedule', 3, 4, 6104, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 00:40:22.525741', 'system', '2026-07-15 10:45:40.148945', 0);
INSERT INTO public.system_menu VALUES (6105, '订阅预警', 'bid:subscription:query', 2, 5, 6100, 'subscription', 'ant-design:bell-outlined', 'bid/subscription/index', 'BidSubscription', 0, true, true, true, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0);
INSERT INTO public.system_menu VALUES (6147, '订阅预警查询', 'bid:subscription:query', 3, 1, 6105, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0);
INSERT INTO public.system_menu VALUES (6148, '订阅规则创建', 'bid:subscription:create', 3, 2, 6105, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0);
INSERT INTO public.system_menu VALUES (6149, '订阅规则修改', 'bid:subscription:update', 3, 3, 6105, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0);
INSERT INTO public.system_menu VALUES (6150, '订阅规则删除', 'bid:subscription:delete', 3, 4, 6105, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0);
INSERT INTO public.system_menu VALUES (1211, '用户组创建', 'bpm:user-group:create', 3, 2, 1209, '', '', '', NULL, 0, true, true, true, '', '2022-01-14 02:14:20', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1212, '用户组更新', 'bpm:user-group:update', 3, 3, 1209, '', '', '', NULL, 0, true, true, true, '', '2022-01-14 02:14:20', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1213, '用户组删除', 'bpm:user-group:delete', 3, 4, 1209, '', '', '', NULL, 0, true, true, true, '', '2022-01-14 02:14:20', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1215, '流程定义查询', 'bpm:process-definition:query', 3, 10, 1193, '', '', '', NULL, 0, true, true, true, '1', '2022-01-23 00:21:43', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1216, '流程任务分配规则查询', 'bpm:task-assign-rule:query', 3, 20, 1193, '', '', '', NULL, 0, true, true, true, '1', '2022-01-23 00:26:53', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1217, '流程任务分配规则创建', 'bpm:task-assign-rule:create', 3, 21, 1193, '', '', '', NULL, 0, true, true, true, '1', '2022-01-23 00:28:15', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1218, '流程任务分配规则更新', 'bpm:task-assign-rule:update', 3, 22, 1193, '', '', '', NULL, 0, true, true, true, '1', '2022-01-23 00:28:41', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1219, '流程实例的创建', 'bpm:process-instance:create', 3, 2, 1201, '', '', '', NULL, 0, true, true, true, '1', '2022-01-23 00:36:15', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1220, '流程实例的取消', 'bpm:process-instance:cancel', 3, 3, 1201, '', '', '', NULL, 0, true, true, true, '1', '2022-01-23 00:36:33', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1221, '流程任务的查询', 'bpm:task:query', 3, 1, 1207, '', '', '', NULL, 0, true, true, true, '1', '2022-01-23 00:38:52', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1222, '流程任务的更新', 'bpm:task:update', 3, 2, 1207, '', '', '', NULL, 0, true, true, true, '1', '2022-01-23 00:39:24', '1', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1224, '租户管理', '', 2, 0, 1, 'tenant', 'fa-solid:house-user', NULL, NULL, 0, true, true, true, '1', '2022-02-20 01:41:13', '1', '2024-02-29 00:59:29', 0);
INSERT INTO public.system_menu VALUES (1225, '租户套餐', '', 2, 0, 1224, 'package', 'fa:bars', 'system/tenantPackage/index', 'SystemTenantPackage', 0, true, true, true, '', '2022-02-19 17:44:06', '1', '2024-02-29 01:01:43', 0);
INSERT INTO public.system_menu VALUES (1226, '租户套餐查询', 'system:tenant-package:query', 3, 1, 1225, '', '', '', NULL, 0, true, true, true, '', '2022-02-19 17:44:06', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1227, '租户套餐创建', 'system:tenant-package:create', 3, 2, 1225, '', '', '', NULL, 0, true, true, true, '', '2022-02-19 17:44:06', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1228, '租户套餐更新', 'system:tenant-package:update', 3, 3, 1225, '', '', '', NULL, 0, true, true, true, '', '2022-02-19 17:44:06', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1229, '租户套餐删除', 'system:tenant-package:delete', 3, 4, 1225, '', '', '', NULL, 0, true, true, true, '', '2022-02-19 17:44:06', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1237, '文件配置', '', 2, 0, 1243, 'file-config', 'fa-solid:file-signature', 'infra/fileConfig/index', 'InfraFileConfig', 0, true, true, true, '', '2022-03-15 14:35:28', '1', '2024-02-29 08:52:54', 0);
INSERT INTO public.system_menu VALUES (1238, '文件配置查询', 'infra:file-config:query', 3, 1, 1237, '', '', '', NULL, 0, true, true, true, '', '2022-03-15 14:35:28', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1239, '文件配置创建', 'infra:file-config:create', 3, 2, 1237, '', '', '', NULL, 0, true, true, true, '', '2022-03-15 14:35:28', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1240, '文件配置更新', 'infra:file-config:update', 3, 3, 1237, '', '', '', NULL, 0, true, true, true, '', '2022-03-15 14:35:28', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1241, '文件配置删除', 'infra:file-config:delete', 3, 4, 1237, '', '', '', NULL, 0, true, true, true, '', '2022-03-15 14:35:28', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1242, '文件配置导出', 'infra:file-config:export', 3, 5, 1237, '', '', '', NULL, 0, true, true, true, '', '2022-03-15 14:35:28', '', '2022-04-20 17:03:10', 0);
INSERT INTO public.system_menu VALUES (1243, '文件管理', '', 2, 6, 2, 'file', 'ep:files', NULL, '', 0, true, true, true, '1', '2022-03-16 23:47:40', '1', '2024-04-23 00:02:11', 0);
INSERT INTO public.system_menu VALUES (1255, '数据源配置', '', 2, 1, 2, 'data-source-config', 'ep:data-analysis', 'infra/dataSourceConfig/index', 'InfraDataSourceConfig', 0, true, true, true, '', '2022-04-27 14:37:32', '1', '2024-02-29 08:51:25', 0);
INSERT INTO public.system_menu VALUES (1256, '数据源配置查询', 'infra:data-source-config:query', 3, 1, 1255, '', '', '', NULL, 0, true, true, true, '', '2022-04-27 14:37:32', '', '2022-04-27 14:37:32', 0);
INSERT INTO public.system_menu VALUES (1257, '数据源配置创建', 'infra:data-source-config:create', 3, 2, 1255, '', '', '', NULL, 0, true, true, true, '', '2022-04-27 14:37:32', '', '2022-04-27 14:37:32', 0);
INSERT INTO public.system_menu VALUES (1258, '数据源配置更新', 'infra:data-source-config:update', 3, 3, 1255, '', '', '', NULL, 0, true, true, true, '', '2022-04-27 14:37:32', '', '2022-04-27 14:37:32', 0);
INSERT INTO public.system_menu VALUES (1259, '数据源配置删除', 'infra:data-source-config:delete', 3, 4, 1255, '', '', '', NULL, 0, true, true, true, '', '2022-04-27 14:37:32', '', '2022-04-27 14:37:32', 0);
INSERT INTO public.system_menu VALUES (1260, '数据源配置导出', 'infra:data-source-config:export', 3, 5, 1255, '', '', '', NULL, 0, true, true, true, '', '2022-04-27 14:37:32', '', '2022-04-27 14:37:32', 0);
INSERT INTO public.system_menu VALUES (1261, 'OAuth 2.0', '', 2, 10, 1, 'oauth2', 'fa:dashcube', NULL, NULL, 0, true, true, true, '1', '2022-05-09 23:38:17', '1', '2024-02-29 01:12:08', 0);
INSERT INTO public.system_menu VALUES (1263, '应用管理', '', 2, 0, 1261, 'oauth2/application', 'fa:hdd-o', 'system/oauth2/client/index', 'SystemOAuth2Client', 0, true, true, true, '', '2022-05-10 16:26:33', '1', '2024-02-29 01:13:14', 0);
INSERT INTO public.system_menu VALUES (1264, '客户端查询', 'system:oauth2-client:query', 3, 1, 1263, '', '', '', NULL, 0, true, true, true, '', '2022-05-10 16:26:33', '1', '2022-05-11 00:31:06', 0);
INSERT INTO public.system_menu VALUES (1265, '客户端创建', 'system:oauth2-client:create', 3, 2, 1263, '', '', '', NULL, 0, true, true, true, '', '2022-05-10 16:26:33', '1', '2022-05-11 00:31:23', 0);
INSERT INTO public.system_menu VALUES (1266, '客户端更新', 'system:oauth2-client:update', 3, 3, 1263, '', '', '', NULL, 0, true, true, true, '', '2022-05-10 16:26:33', '1', '2022-05-11 00:31:28', 0);
INSERT INTO public.system_menu VALUES (1267, '客户端删除', 'system:oauth2-client:delete', 3, 4, 1263, '', '', '', NULL, 0, true, true, true, '', '2022-05-10 16:26:33', '1', '2022-05-11 00:31:33', 0);
INSERT INTO public.system_menu VALUES (6145, '爬虫配置管理', 'bid:crawler:config', 3, 5, 6104, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 00:57:21.707523', 'system', '2026-07-15 10:45:40.196521', 0);
INSERT INTO public.system_menu VALUES (6151, '预警处理', 'bid:subscription:process', 3, 5, 6105, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0);
INSERT INTO public.system_menu VALUES (6111, '公告新增', 'bid:notice:create', 3, 1, 6101, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-14 08:22:10.528054', 'system', '2026-07-15 10:45:40.120637', 0);
INSERT INTO public.system_menu VALUES (6112, '公告修改', 'bid:notice:update', 3, 2, 6101, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-14 08:22:10.528054', 'system', '2026-07-15 10:45:40.120637', 0);
INSERT INTO public.system_menu VALUES (6113, '公告删除', 'bid:notice:delete', 3, 3, 6101, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-14 08:22:10.528054', 'system', '2026-07-15 10:45:40.120637', 0);
INSERT INTO public.system_menu VALUES (6121, '商机新增', 'bid:opportunity:create', 3, 1, 6102, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-14 08:22:10.528054', 'system', '2026-07-15 10:45:40.120637', 0);
INSERT INTO public.system_menu VALUES (6122, '商机指派', 'bid:opportunity:assign', 3, 2, 6102, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-14 08:22:10.528054', 'system', '2026-07-15 10:45:40.120637', 0);
INSERT INTO public.system_menu VALUES (6123, '商机决策', 'bid:opportunity:decision', 3, 3, 6102, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-14 08:22:10.528054', 'system', '2026-07-15 10:45:40.120637', 0);
INSERT INTO public.system_menu VALUES (6146, '爬虫登录态管理', 'bid:crawler:login', 3, 6, 6104, '', '', '', NULL, 0, true, true, true, 'system', '2026-07-15 01:11:30.159654', 'system', '2026-07-15 10:45:40.221885', 0);
INSERT INTO public.system_menu VALUES (2083, '地区管理', '', 2, 14, 1, 'area', 'fa:map-marker', 'system/area/index', 'SystemArea', 0, true, true, true, '1', '2022-12-23 17:35:05', '1', '2024-02-29 08:50:28', 0);
INSERT INTO public.system_menu VALUES (2130, '邮箱管理', '', 2, 2, 2739, 'mail', 'fa-solid:mail-bulk', NULL, NULL, 0, true, true, true, '1', '2023-01-25 17:27:44', '1', '2024-04-22 23:56:08', 0);
INSERT INTO public.system_menu VALUES (2131, '邮箱账号', '', 2, 0, 2130, 'mail-account', 'fa:universal-access', 'system/mail/account/index', 'SystemMailAccount', 0, true, true, true, '', '2023-01-25 09:33:48', '1', '2024-02-29 08:48:16', 0);
INSERT INTO public.system_menu VALUES (2132, '账号查询', 'system:mail-account:query', 3, 1, 2131, '', '', '', NULL, 0, true, true, true, '', '2023-01-25 09:33:48', '', '2023-01-25 09:33:48', 0);
INSERT INTO public.system_menu VALUES (2133, '账号创建', 'system:mail-account:create', 3, 2, 2131, '', '', '', NULL, 0, true, true, true, '', '2023-01-25 09:33:48', '', '2023-01-25 09:33:48', 0);
INSERT INTO public.system_menu VALUES (2134, '账号更新', 'system:mail-account:update', 3, 3, 2131, '', '', '', NULL, 0, true, true, true, '', '2023-01-25 09:33:48', '', '2023-01-25 09:33:48', 0);
INSERT INTO public.system_menu VALUES (2135, '账号删除', 'system:mail-account:delete', 3, 4, 2131, '', '', '', NULL, 0, true, true, true, '', '2023-01-25 09:33:48', '', '2023-01-25 09:33:48', 0);
INSERT INTO public.system_menu VALUES (2136, '邮件模版', '', 2, 0, 2130, 'mail-template', 'fa:tag', 'system/mail/template/index', 'SystemMailTemplate', 0, true, true, true, '', '2023-01-25 12:05:31', '1', '2024-02-29 08:48:41', 0);
INSERT INTO public.system_menu VALUES (2137, '模版查询', 'system:mail-template:query', 3, 1, 2136, '', '', '', NULL, 0, true, true, true, '', '2023-01-25 12:05:31', '', '2023-01-25 12:05:31', 0);
INSERT INTO public.system_menu VALUES (2138, '模版创建', 'system:mail-template:create', 3, 2, 2136, '', '', '', NULL, 0, true, true, true, '', '2023-01-25 12:05:31', '', '2023-01-25 12:05:31', 0);
INSERT INTO public.system_menu VALUES (2139, '模版更新', 'system:mail-template:update', 3, 3, 2136, '', '', '', NULL, 0, true, true, true, '', '2023-01-25 12:05:31', '', '2023-01-25 12:05:31', 0);
INSERT INTO public.system_menu VALUES (2140, '模版删除', 'system:mail-template:delete', 3, 4, 2136, '', '', '', NULL, 0, true, true, true, '', '2023-01-25 12:05:31', '', '2023-01-25 12:05:31', 0);
INSERT INTO public.system_menu VALUES (2141, '邮件记录', '', 2, 0, 2130, 'mail-log', 'fa:edit', 'system/mail/log/index', 'SystemMailLog', 0, true, true, true, '', '2023-01-26 02:16:50', '1', '2024-02-29 08:48:51', 0);
INSERT INTO public.system_menu VALUES (2142, '日志查询', 'system:mail-log:query', 3, 1, 2141, '', '', '', NULL, 0, true, true, true, '', '2023-01-26 02:16:50', '', '2023-01-26 02:16:50', 0);
INSERT INTO public.system_menu VALUES (2143, '发送测试邮件', 'system:mail-template:send-mail', 3, 5, 2136, '', '', '', NULL, 0, true, true, true, '1', '2023-01-26 23:29:15', '1', '2023-01-26 23:29:15', 0);
INSERT INTO public.system_menu VALUES (2144, '站内信管理', '', 1, 3, 2739, 'notify', 'ep:message-box', NULL, NULL, 0, true, true, true, '1', '2023-01-28 10:25:18', '1', '2024-04-22 23:56:12', 0);
INSERT INTO public.system_menu VALUES (2145, '模板管理', '', 2, 0, 2144, 'notify-template', 'fa:archive', 'system/notify/template/index', 'SystemNotifyTemplate', 0, true, true, true, '', '2023-01-28 02:26:42', '1', '2024-02-29 08:49:14', 0);
INSERT INTO public.system_menu VALUES (2146, '站内信模板查询', 'system:notify-template:query', 3, 1, 2145, '', '', '', NULL, 0, true, true, true, '', '2023-01-28 02:26:42', '', '2023-01-28 02:26:42', 0);
INSERT INTO public.system_menu VALUES (2147, '站内信模板创建', 'system:notify-template:create', 3, 2, 2145, '', '', '', NULL, 0, true, true, true, '', '2023-01-28 02:26:42', '', '2023-01-28 02:26:42', 0);
INSERT INTO public.system_menu VALUES (2148, '站内信模板更新', 'system:notify-template:update', 3, 3, 2145, '', '', '', NULL, 0, true, true, true, '', '2023-01-28 02:26:42', '', '2023-01-28 02:26:42', 0);
INSERT INTO public.system_menu VALUES (2149, '站内信模板删除', 'system:notify-template:delete', 3, 4, 2145, '', '', '', NULL, 0, true, true, true, '', '2023-01-28 02:26:42', '', '2023-01-28 02:26:42', 0);
INSERT INTO public.system_menu VALUES (2150, '发送测试站内信', 'system:notify-template:send-notify', 3, 5, 2145, '', '', '', NULL, 0, true, true, true, '1', '2023-01-28 10:54:43', '1', '2023-01-28 10:54:43', 0);
INSERT INTO public.system_menu VALUES (2151, '消息记录', '', 2, 0, 2144, 'notify-message', 'fa:edit', 'system/notify/message/index', 'SystemNotifyMessage', 0, true, true, true, '', '2023-01-28 04:28:22', '1', '2024-02-29 08:49:22', 0);
INSERT INTO public.system_menu VALUES (2152, '站内信消息查询', 'system:notify-message:query', 3, 1, 2151, '', '', '', NULL, 0, true, true, true, '', '2023-01-28 04:28:22', '', '2023-01-28 04:28:22', 0);
INSERT INTO public.system_menu VALUES (2447, '三方登录', '', 1, 10, 1, 'social', 'fa:rocket', '', '', 0, true, true, true, '1', '2023-11-04 12:12:01', '1', '2024-02-29 01:14:05', 0);
INSERT INTO public.system_menu VALUES (2448, '三方应用', '', 2, 1, 2447, 'client', 'ep:set-up', 'system/social/client/index.vue', 'SocialClient', 0, true, true, true, '1', '2023-11-04 12:17:19', '1', '2024-05-04 19:09:54', 0);
INSERT INTO public.system_menu VALUES (2449, '三方应用查询', 'system:social-client:query', 3, 1, 2448, '', '', '', '', 0, true, true, true, '1', '2023-11-04 12:43:12', '1', '2023-11-04 12:43:33', 0);
INSERT INTO public.system_menu VALUES (2450, '三方应用创建', 'system:social-client:create', 3, 2, 2448, '', '', '', '', 0, true, true, true, '1', '2023-11-04 12:43:58', '1', '2023-11-04 12:43:58', 0);
INSERT INTO public.system_menu VALUES (2451, '三方应用更新', 'system:social-client:update', 3, 3, 2448, '', '', '', '', 0, true, true, true, '1', '2023-11-04 12:44:27', '1', '2023-11-04 12:44:27', 0);
INSERT INTO public.system_menu VALUES (2452, '三方应用删除', 'system:social-client:delete', 3, 4, 2448, '', '', '', '', 0, true, true, true, '1', '2023-11-04 12:44:43', '1', '2023-11-04 12:44:43', 0);
INSERT INTO public.system_menu VALUES (2453, '三方用户', 'system:social-user:query', 2, 2, 2447, 'user', 'ep:avatar', 'system/social/user/index.vue', 'SocialUser', 0, true, true, true, '1', '2023-11-04 14:01:05', '1', '2023-11-04 14:01:05', 0);
INSERT INTO public.system_menu VALUES (2472, '主子表（内嵌）', '', 2, 12, 1070, 'demo03-inner', 'fa:power-off', 'infra/demo/demo03/inner/index', 'Demo03StudentInner', 0, true, true, true, '', '2023-11-13 04:39:51', '1', '2023-11-16 23:53:46', 0);
INSERT INTO public.system_menu VALUES (2478, '单表（增删改查）', '', 2, 1, 1070, 'demo01-contact', 'ep:bicycle', 'infra/demo/demo01/index', 'Demo01Contact', 0, true, true, true, '', '2023-11-15 14:42:30', '1', '2023-11-16 20:34:40', 0);
INSERT INTO public.system_menu VALUES (2479, '示例联系人查询', 'infra:demo01-contact:query', 3, 1, 2478, '', '', '', NULL, 0, true, true, true, '', '2023-11-15 14:42:30', '', '2023-11-15 14:42:30', 0);
INSERT INTO public.system_menu VALUES (2480, '示例联系人创建', 'infra:demo01-contact:create', 3, 2, 2478, '', '', '', NULL, 0, true, true, true, '', '2023-11-15 14:42:30', '', '2023-11-15 14:42:30', 0);
INSERT INTO public.system_menu VALUES (2481, '示例联系人更新', 'infra:demo01-contact:update', 3, 3, 2478, '', '', '', NULL, 0, true, true, true, '', '2023-11-15 14:42:30', '', '2023-11-15 14:42:30', 0);
INSERT INTO public.system_menu VALUES (2482, '示例联系人删除', 'infra:demo01-contact:delete', 3, 4, 2478, '', '', '', NULL, 0, true, true, true, '', '2023-11-15 14:42:30', '', '2023-11-15 14:42:30', 0);
INSERT INTO public.system_menu VALUES (2483, '示例联系人导出', 'infra:demo01-contact:export', 3, 5, 2478, '', '', '', NULL, 0, true, true, true, '', '2023-11-15 14:42:30', '', '2023-11-15 14:42:30', 0);
INSERT INTO public.system_menu VALUES (2484, '树表（增删改查）', '', 2, 2, 1070, 'demo02-category', 'fa:tree', 'infra/demo/demo02/index', 'Demo02Category', 0, true, true, true, '', '2023-11-16 12:18:27', '1', '2023-11-16 20:35:01', 0);
INSERT INTO public.system_menu VALUES (2485, '示例分类查询', 'infra:demo02-category:query', 3, 1, 2484, '', '', '', NULL, 0, true, true, true, '', '2023-11-16 12:18:27', '', '2023-11-16 12:18:27', 0);
INSERT INTO public.system_menu VALUES (2486, '示例分类创建', 'infra:demo02-category:create', 3, 2, 2484, '', '', '', NULL, 0, true, true, true, '', '2023-11-16 12:18:27', '', '2023-11-16 12:18:27', 0);
INSERT INTO public.system_menu VALUES (2487, '示例分类更新', 'infra:demo02-category:update', 3, 3, 2484, '', '', '', NULL, 0, true, true, true, '', '2023-11-16 12:18:27', '', '2023-11-16 12:18:27', 0);
INSERT INTO public.system_menu VALUES (2488, '示例分类删除', 'infra:demo02-category:delete', 3, 4, 2484, '', '', '', NULL, 0, true, true, true, '', '2023-11-16 12:18:27', '', '2023-11-16 12:18:27', 0);
INSERT INTO public.system_menu VALUES (2489, '示例分类导出', 'infra:demo02-category:export', 3, 5, 2484, '', '', '', NULL, 0, true, true, true, '', '2023-11-16 12:18:27', '', '2023-11-16 12:18:27', 0);
INSERT INTO public.system_menu VALUES (2490, '主子表（标准）', '', 2, 10, 1070, 'demo03-normal', 'fa:battery-3', 'infra/demo/demo03/normal/index', 'Demo03StudentNormal', 0, true, true, true, '', '2023-11-16 12:53:37', '1', '2023-11-16 23:10:03', 0);
INSERT INTO public.system_menu VALUES (2491, '学生查询', 'infra:demo03-student:query', 3, 1, 2490, '', '', '', NULL, 0, true, true, true, '', '2023-11-16 12:53:37', '', '2023-11-16 12:53:37', 0);
INSERT INTO public.system_menu VALUES (2492, '学生创建', 'infra:demo03-student:create', 3, 2, 2490, '', '', '', NULL, 0, true, true, true, '', '2023-11-16 12:53:37', '', '2023-11-16 12:53:37', 0);
INSERT INTO public.system_menu VALUES (2493, '学生更新', 'infra:demo03-student:update', 3, 3, 2490, '', '', '', NULL, 0, true, true, true, '', '2023-11-16 12:53:37', '', '2023-11-16 12:53:37', 0);
INSERT INTO public.system_menu VALUES (2494, '学生删除', 'infra:demo03-student:delete', 3, 4, 2490, '', '', '', NULL, 0, true, true, true, '', '2023-11-16 12:53:37', '', '2023-11-16 12:53:37', 0);
INSERT INTO public.system_menu VALUES (2495, '学生导出', 'infra:demo03-student:export', 3, 5, 2490, '', '', '', NULL, 0, true, true, true, '', '2023-11-16 12:53:37', '', '2023-11-16 12:53:37', 0);
INSERT INTO public.system_menu VALUES (2497, '主子表（ERP）', '', 2, 11, 1070, 'demo03-erp', 'ep:calendar', 'infra/demo/demo03/erp/index', 'Demo03StudentERP', 0, true, true, true, '', '2023-11-16 15:50:59', '1', '2023-11-17 13:19:56', 0);
INSERT INTO public.system_menu VALUES (2525, 'WebSocket', '', 2, 5, 2, 'websocket', 'ep:connection', 'infra/webSocket/index', 'InfraWebSocket', 0, true, true, true, '1', '2023-11-23 19:41:55', '1', '2024-04-23 00:02:00', 0);
INSERT INTO public.system_menu VALUES (2713, '抄送我的', 'bpm:process-instance-cc:query', 2, 30, 1200, 'copy', 'ep:copy-document', 'bpm/task/copy/index', 'BpmProcessInstanceCopy', 0, true, true, true, '1', '2024-03-17 21:50:23', '1', '2024-04-24 19:55:12', 0);
INSERT INTO public.system_menu VALUES (2714, '流程分类', '', 2, 3, 1186, 'category', 'fa:object-ungroup', 'bpm/category/index', 'BpmCategory', 0, true, true, true, '', '2024-03-08 02:00:51', '1', '2024-03-21 23:51:18', 0);
INSERT INTO public.system_menu VALUES (2715, '分类查询', 'bpm:category:query', 3, 1, 2714, '', '', '', '', 0, true, true, true, '', '2024-03-08 02:00:51', '1', '2024-03-19 14:36:25', 0);
INSERT INTO public.system_menu VALUES (2716, '分类创建', 'bpm:category:create', 3, 2, 2714, '', '', '', '', 0, true, true, true, '', '2024-03-08 02:00:51', '1', '2024-03-19 14:36:31', 0);
INSERT INTO public.system_menu VALUES (2717, '分类更新', 'bpm:category:update', 3, 3, 2714, '', '', '', '', 0, true, true, true, '', '2024-03-08 02:00:51', '1', '2024-03-19 14:36:35', 0);
INSERT INTO public.system_menu VALUES (2718, '分类删除', 'bpm:category:delete', 3, 4, 2714, '', '', '', '', 0, true, true, true, '', '2024-03-08 02:00:51', '1', '2024-03-19 14:36:41', 0);
INSERT INTO public.system_menu VALUES (2720, '发起流程', '', 2, 0, 1200, 'create', 'fa-solid:grin-stars', 'bpm/processInstance/create/index', 'BpmProcessInstanceCreate', 0, true, false, true, '1', '2024-03-19 19:46:05', '1', '2024-03-23 19:03:42', 0);
INSERT INTO public.system_menu VALUES (2721, '流程实例', '', 2, 10, 1186, 'process-instance/manager', 'fa:square', 'bpm/processInstance/manager/index', 'BpmProcessInstanceManager', 0, true, true, true, '1', '2024-03-21 23:57:30', '1', '2024-03-21 23:57:30', 0);
INSERT INTO public.system_menu VALUES (2722, '流程实例的查询（管理员）', 'bpm:process-instance:manager-query', 3, 1, 2721, '', '', '', '', 0, true, true, true, '1', '2024-03-22 08:18:27', '1', '2024-03-22 08:19:05', 0);
INSERT INTO public.system_menu VALUES (2723, '流程实例的取消（管理员）', 'bpm:process-instance:cancel-by-admin', 3, 2, 2721, '', '', '', '', 0, true, true, true, '1', '2024-03-22 08:19:25', '1', '2024-03-22 08:19:25', 0);
INSERT INTO public.system_menu VALUES (2724, '流程任务', '', 2, 11, 1186, 'process-tasnk', 'ep:collection-tag', 'bpm/task/manager/index', 'BpmManagerTask', 0, true, true, true, '1', '2024-03-22 08:43:22', '1', '2024-03-22 08:43:27', 0);
INSERT INTO public.system_menu VALUES (2725, '流程任务的查询（管理员）', 'bpm:task:manager-query', 3, 1, 2724, '', '', '', '', 0, true, true, true, '1', '2024-03-22 08:43:49', '1', '2025-12-23 23:04:44', 0);
INSERT INTO public.system_menu VALUES (2726, '流程监听器', '', 2, 5, 1186, 'process-listener', 'fa:assistive-listening-systems', 'bpm/processListener/index', 'BpmProcessListener', 0, true, true, true, '', '2024-03-09 16:05:34', '1', '2024-03-23 13:13:38', 0);
INSERT INTO public.system_menu VALUES (2727, '流程监听器查询', 'bpm:process-listener:query', 3, 1, 2726, '', '', '', NULL, 0, true, true, true, '', '2024-03-09 16:05:34', '', '2024-03-09 16:05:34', 0);
INSERT INTO public.system_menu VALUES (2728, '流程监听器创建', 'bpm:process-listener:create', 3, 2, 2726, '', '', '', NULL, 0, true, true, true, '', '2024-03-09 16:05:34', '', '2024-03-09 16:05:34', 0);
INSERT INTO public.system_menu VALUES (2729, '流程监听器更新', 'bpm:process-listener:update', 3, 3, 2726, '', '', '', NULL, 0, true, true, true, '', '2024-03-09 16:05:34', '', '2024-03-09 16:05:34', 0);
INSERT INTO public.system_menu VALUES (2730, '流程监听器删除', 'bpm:process-listener:delete', 3, 4, 2726, '', '', '', NULL, 0, true, true, true, '', '2024-03-09 16:05:34', '', '2024-03-09 16:05:34', 0);
INSERT INTO public.system_menu VALUES (2731, '流程表达式', '', 2, 6, 1186, 'process-expression', 'fa:wpexplorer', 'bpm/processExpression/index', 'BpmProcessExpression', 0, true, true, true, '', '2024-03-09 22:35:08', '1', '2024-03-23 19:43:05', 0);
INSERT INTO public.system_menu VALUES (2732, '流程表达式查询', 'bpm:process-expression:query', 3, 1, 2731, '', '', '', NULL, 0, true, true, true, '', '2024-03-09 22:35:08', '', '2024-03-09 22:35:08', 0);
INSERT INTO public.system_menu VALUES (2733, '流程表达式创建', 'bpm:process-expression:create', 3, 2, 2731, '', '', '', NULL, 0, true, true, true, '', '2024-03-09 22:35:08', '', '2024-03-09 22:35:08', 0);
INSERT INTO public.system_menu VALUES (2734, '流程表达式更新', 'bpm:process-expression:update', 3, 3, 2731, '', '', '', NULL, 0, true, true, true, '', '2024-03-09 22:35:08', '', '2024-03-09 22:35:08', 0);
INSERT INTO public.system_menu VALUES (2735, '流程表达式删除', 'bpm:process-expression:delete', 3, 4, 2731, '', '', '', NULL, 0, true, true, true, '', '2024-03-09 22:35:08', '', '2024-03-09 22:35:08', 0);
INSERT INTO public.system_menu VALUES (2739, '消息中心', '', 1, 7, 1, 'messages', 'ep:chat-dot-round', '', '', 0, true, true, true, '1', '2024-04-22 23:54:30', '1', '2024-04-23 09:36:35', 0);
INSERT INTO public.system_menu VALUES (2740, '监控中心', '', 1, 10, 2, 'monitors', 'ep:monitor', '', '', 0, true, true, true, '1', '2024-04-23 00:04:44', '1', '2024-04-23 00:04:44', 0);
INSERT INTO public.system_menu VALUES (2758, 'AI 大模型', '', 1, 400, 0, '/ai', 'tabler:ai', '', '', 0, true, true, true, '1', '2024-05-07 15:07:56', '1', '2025-04-19 18:57:05', 0);
INSERT INTO public.system_menu VALUES (2759, 'AI 对话', '', 2, 1, 2758, 'chat', 'ep:message', 'ai/chat/index/index.vue', 'AiChat', 0, true, true, true, '1', '2024-05-07 15:09:14', '1', '2024-07-07 17:15:36', 0);
INSERT INTO public.system_menu VALUES (2760, '控制台', '', 1, 100, 2758, 'console', 'ep:setting', '', '', 0, true, true, true, '1', '2024-05-09 22:39:09', '1', '2024-05-24 23:34:21', 0);
INSERT INTO public.system_menu VALUES (2761, 'API 密钥', '', 2, 0, 2760, 'api-key', 'ep:key', 'ai/model/apiKey/index.vue', 'AiApiKey', 0, true, true, true, '', '2024-05-09 14:52:56', '1', '2024-05-10 22:44:08', 0);
INSERT INTO public.system_menu VALUES (2762, 'API 密钥查询', 'ai:api-key:query', 3, 1, 2761, '', '', '', '', 0, true, true, true, '', '2024-05-09 14:52:56', '1', '2024-05-13 20:36:32', 0);
INSERT INTO public.system_menu VALUES (2763, 'API 密钥创建', 'ai:api-key:create', 3, 2, 2761, '', '', '', '', 0, true, true, true, '', '2024-05-09 14:52:56', '1', '2024-05-13 20:36:26', 0);
INSERT INTO public.system_menu VALUES (2764, 'API 密钥更新', 'ai:api-key:update', 3, 3, 2761, '', '', '', '', 0, true, true, true, '', '2024-05-09 14:52:56', '1', '2024-05-13 20:36:42', 0);
INSERT INTO public.system_menu VALUES (2765, 'API 密钥删除', 'ai:api-key:delete', 3, 4, 2761, '', '', '', '', 0, true, true, true, '', '2024-05-09 14:52:56', '1', '2024-05-13 20:36:48', 0);
INSERT INTO public.system_menu VALUES (2767, '模型配置', '', 2, 0, 2760, 'model', 'fa-solid:abacus', 'ai/model/model/index.vue', 'AiModel', 0, true, true, true, '', '2024-05-10 14:42:48', '1', '2025-03-03 09:57:41', 0);
INSERT INTO public.system_menu VALUES (2768, '聊天模型查询', 'ai:model:query', 3, 1, 2767, '', '', '', '', 0, true, true, true, '', '2024-05-10 14:42:48', '1', '2025-03-03 09:19:46', 0);
INSERT INTO public.system_menu VALUES (2769, '聊天模型创建', 'ai:model:create', 3, 2, 2767, '', '', '', '', 0, true, true, true, '', '2024-05-10 14:42:48', '1', '2025-03-03 09:20:10', 0);
INSERT INTO public.system_menu VALUES (2770, '聊天模型更新', 'ai:model:update', 3, 3, 2767, '', '', '', '', 0, true, true, true, '', '2024-05-10 14:42:48', '1', '2025-03-03 09:20:14', 0);
INSERT INTO public.system_menu VALUES (2771, '聊天模型删除', 'ai:model:delete', 3, 4, 2767, '', '', '', '', 0, true, true, true, '', '2024-05-10 14:42:48', '1', '2025-03-03 09:20:27', 0);
INSERT INTO public.system_menu VALUES (2773, '聊天角色', '', 2, 0, 2760, 'chat-role', 'fa:user-secret', 'ai/model/chatRole/index.vue', 'AiChatRole', 0, true, true, true, '', '2024-05-13 12:39:28', '1', '2024-05-13 20:41:45', 0);
INSERT INTO public.system_menu VALUES (2774, '聊天角色查询', 'ai:chat-role:query', 3, 1, 2773, '', '', '', NULL, 0, true, true, true, '', '2024-05-13 12:39:28', '', '2024-05-13 12:39:28', 0);
INSERT INTO public.system_menu VALUES (2775, '聊天角色创建', 'ai:chat-role:create', 3, 2, 2773, '', '', '', NULL, 0, true, true, true, '', '2024-05-13 12:39:28', '', '2024-05-13 12:39:28', 0);
INSERT INTO public.system_menu VALUES (2776, '聊天角色更新', 'ai:chat-role:update', 3, 3, 2773, '', '', '', NULL, 0, true, true, true, '', '2024-05-13 12:39:28', '', '2024-05-13 12:39:28', 0);
INSERT INTO public.system_menu VALUES (2777, '聊天角色删除', 'ai:chat-role:delete', 3, 4, 2773, '', '', '', '', 0, true, true, true, '1', '2024-05-13 21:43:38', '1', '2024-05-13 21:43:38', 0);
INSERT INTO public.system_menu VALUES (2778, '聊天管理', '', 2, 10, 2760, 'chat-conversation', 'ep:chat-square', 'ai/chat/manager/index.vue', 'AiChatManager', 0, true, true, true, '', '2024-05-24 15:39:18', '1', '2024-06-26 21:36:56', 0);
INSERT INTO public.system_menu VALUES (2779, '会话查询', 'ai:chat-conversation:query', 3, 1, 2778, '', '', '', '', 0, true, true, true, '', '2024-05-24 15:39:18', '1', '2024-05-25 08:38:30', 0);
INSERT INTO public.system_menu VALUES (2780, '会话删除', 'ai:chat-conversation:delete', 3, 2, 2778, '', '', '', '', 0, true, true, true, '', '2024-05-24 15:39:18', '1', '2024-05-25 08:38:40', 0);
INSERT INTO public.system_menu VALUES (2781, '消息查询', 'ai:chat-message:query', 3, 11, 2778, '', '', '', '', 0, true, true, true, '1', '2024-05-25 08:38:56', '1', '2024-05-25 08:38:56', 0);
INSERT INTO public.system_menu VALUES (2782, '消息删除', 'ai:chat-message:delete', 3, 12, 2778, '', '', '', '', 0, true, true, true, '1', '2024-05-25 08:39:10', '1', '2024-05-25 08:39:10', 0);
INSERT INTO public.system_menu VALUES (2783, 'AI 绘画', '', 2, 2, 2758, 'image', 'ep:picture-rounded', 'ai/image/index/index.vue', 'AiImage', 0, true, true, true, '1', '2024-05-26 11:45:17', '1', '2024-07-07 17:18:59', 0);
INSERT INTO public.system_menu VALUES (2784, '绘画管理', '', 2, 11, 2760, 'image', 'fa:file-image-o', 'ai/image/manager/index.vue', 'AiImageManager', 0, true, true, true, '', '2024-06-26 13:32:31', '1', '2024-06-26 21:37:13', 0);
INSERT INTO public.system_menu VALUES (2785, '绘画查询', 'ai:image:query', 3, 1, 2784, '', '', '', '', 0, true, true, true, '', '2024-06-26 13:32:31', '1', '2024-06-26 22:21:57', 0);
INSERT INTO public.system_menu VALUES (2786, '绘画删除', 'ai:image:delete', 3, 4, 2784, '', '', '', '', 0, true, true, true, '', '2024-06-26 13:32:31', '1', '2024-06-26 22:22:08', 0);
INSERT INTO public.system_menu VALUES (2787, '绘图更新', 'ai:image:update', 3, 2, 2784, '', '', '', '', 0, true, true, true, '1', '2024-06-26 22:47:56', '1', '2024-08-31 09:21:35', 0);
INSERT INTO public.system_menu VALUES (2788, '音乐管理', '', 2, 12, 2760, 'music', 'fa:music', 'ai/music/manager/index.vue', 'AiMusicManager', 0, true, true, true, '', '2024-06-27 15:03:33', '1', '2024-06-27 23:04:19', 0);
INSERT INTO public.system_menu VALUES (2789, '音乐查询', 'ai:music:query', 3, 1, 2788, '', '', '', NULL, 0, true, true, true, '', '2024-06-27 15:03:33', '', '2024-06-27 15:03:33', 0);
INSERT INTO public.system_menu VALUES (2790, '音乐更新', 'ai:music:update', 3, 3, 2788, '', '', '', NULL, 0, true, true, true, '', '2024-06-27 15:03:33', '', '2024-06-27 15:03:33', 0);
INSERT INTO public.system_menu VALUES (2791, '音乐删除', 'ai:music:delete', 3, 4, 2788, '', '', '', NULL, 0, true, true, true, '', '2024-06-27 15:03:33', '', '2024-06-27 15:03:33', 0);
INSERT INTO public.system_menu VALUES (2792, 'AI 写作', '', 2, 3, 2758, 'write', 'fa-solid:book-reader', 'ai/write/index/index.vue', 'AiWrite', 0, true, true, true, '1', '2024-07-08 09:26:44', '1', '2024-07-16 13:03:06', 0);
INSERT INTO public.system_menu VALUES (2793, '写作管理', '', 2, 13, 2760, 'write', 'fa:bookmark-o', 'ai/write/manager/index.vue', 'AiWriteManager', 0, true, true, true, '', '2024-07-10 13:24:34', '1', '2024-07-10 21:31:59', 0);
INSERT INTO public.system_menu VALUES (2794, 'AI 写作查询', 'ai:write:query', 3, 1, 2793, '', '', '', NULL, 0, true, true, true, '', '2024-07-10 13:24:34', '', '2024-07-10 13:24:34', 0);
INSERT INTO public.system_menu VALUES (2795, 'AI 写作删除', 'ai:write:delete', 3, 4, 2793, '', '', '', NULL, 0, true, true, true, '', '2024-07-10 13:24:34', '', '2024-07-10 13:24:34', 0);
INSERT INTO public.system_menu VALUES (2796, 'AI 音乐', '', 2, 4, 2758, 'music', 'fa:music', 'ai/music/index/index.vue', 'AiMusic', 0, true, true, true, '1', '2024-07-17 09:21:12', '1', '2024-07-29 21:11:52', 0);
INSERT INTO public.system_menu VALUES (2798, 'AI 思维导图', '', 2, 6, 2758, 'mind-map', 'fa:sitemap', 'ai/mindmap/index/index.vue', 'AiMindMap', 0, true, true, true, '1', '2024-07-29 21:31:59', '1', '2025-03-02 18:57:31', 0);
INSERT INTO public.system_menu VALUES (2799, '导图管理', '', 2, 14, 2760, 'mind-map', 'fa:map', 'ai/mindmap/manager/index', 'AiMindMapManager', 0, true, true, true, '', '2024-08-10 09:15:09', '1', '2024-08-10 17:24:28', 0);
INSERT INTO public.system_menu VALUES (2800, '思维导图查询', 'ai:mind-map:query', 3, 1, 2799, '', '', '', NULL, 0, true, true, true, '', '2024-08-10 09:15:09', '', '2024-08-10 09:15:09', 0);
INSERT INTO public.system_menu VALUES (2801, '思维导图删除', 'ai:mind-map:delete', 3, 4, 2799, '', '', '', NULL, 0, true, true, true, '', '2024-08-10 09:15:09', '', '2024-08-10 09:15:09', 0);
INSERT INTO public.system_menu VALUES (2913, '流程清理', 'bpm:model:clean', 3, 7, 1193, '', '', '', '', 0, true, true, true, '1', '2025-01-17 19:32:06', '1', '2025-01-17 19:32:06', 0);
INSERT INTO public.system_menu VALUES (2915, 'AI 知识库', '', 2, 5, 2758, 'knowledge', 'ep:notebook', 'ai/knowledge/knowledge/index', 'AiKnowledge', 0, true, true, true, '', '2025-02-28 07:04:21', '1', '2025-03-02 18:58:37', 0);
INSERT INTO public.system_menu VALUES (2916, 'AI 知识库查询', 'ai:knowledge:query', 3, 1, 2915, '', '', '', NULL, 0, true, true, true, '', '2025-02-28 07:04:21', '', '2025-02-28 07:04:21', 0);
INSERT INTO public.system_menu VALUES (2917, 'AI 知识库创建', 'ai:knowledge:create', 3, 2, 2915, '', '', '', NULL, 0, true, true, true, '', '2025-02-28 07:04:21', '', '2025-02-28 07:04:21', 0);
INSERT INTO public.system_menu VALUES (2918, 'AI 知识库更新', 'ai:knowledge:update', 3, 3, 2915, '', '', '', NULL, 0, true, true, true, '', '2025-02-28 07:04:21', '', '2025-02-28 07:04:21', 0);
INSERT INTO public.system_menu VALUES (2919, 'AI 知识库删除', 'ai:knowledge:delete', 3, 4, 2915, '', '', '', NULL, 0, true, true, true, '', '2025-02-28 07:04:21', '', '2025-02-28 07:04:21', 0);
INSERT INTO public.system_menu VALUES (2920, '工具管理', '', 2, 0, 2760, 'tool', 'fa-solid:tools', 'ai/model/tool/index.vue', 'AiTool', 0, true, true, true, '', '2025-03-14 11:19:29', '1', '2025-03-14 19:20:18', 0);
INSERT INTO public.system_menu VALUES (2921, '工具查询', 'ai:tool:query', 3, 1, 2920, '', '', '', NULL, 0, true, true, true, '', '2025-03-14 11:19:29', '', '2025-03-14 11:19:29', 0);
INSERT INTO public.system_menu VALUES (2922, '工具创建', 'ai:tool:create', 3, 2, 2920, '', '', '', NULL, 0, true, true, true, '', '2025-03-14 11:19:29', '', '2025-03-14 11:19:29', 0);
INSERT INTO public.system_menu VALUES (2923, '工具更新', 'ai:tool:update', 3, 3, 2920, '', '', '', NULL, 0, true, true, true, '', '2025-03-14 11:19:29', '', '2025-03-14 11:19:29', 0);
INSERT INTO public.system_menu VALUES (2924, '工具删除', 'ai:tool:delete', 3, 4, 2920, '', '', '', NULL, 0, true, true, true, '', '2025-03-14 11:19:29', '', '2025-03-14 11:19:29', 0);
INSERT INTO public.system_menu VALUES (5000, 'AI 工作流', '', 2, 5, 2758, 'workflow', 'fa:hand-grab-o', 'ai/workflow/index.vue', 'AiWorkflow', 0, true, true, true, '1', '2025-03-25 09:50:27', '1', '2025-05-03 18:55:12', 0);
INSERT INTO public.system_menu VALUES (5001, 'AI 工作流查询', 'ai:workflow:query', 3, 1, 5000, '', '', '', '', 0, true, true, true, '1', '2025-03-25 09:51:11', '1', '2025-03-25 09:51:11', 0);
INSERT INTO public.system_menu VALUES (5002, 'AI 工作流创建', 'ai:workflow:create', 3, 2, 5000, '', '', '', '', 0, true, true, true, '1', '2025-03-25 09:51:28', '1', '2025-03-25 09:51:28', 0);
INSERT INTO public.system_menu VALUES (5003, 'AI 工作流更新', 'ai:workflow:update', 3, 3, 5000, '', '', '', '', 0, true, true, true, '1', '2025-03-25 09:51:42', '1', '2025-03-25 09:51:42', 0);
INSERT INTO public.system_menu VALUES (5004, 'AI 工作流删除', 'ai:workflow:delete', 3, 4, 5000, '', '', '', '', 0, true, true, true, '1', '2025-03-25 09:51:55', '1', '2025-03-25 09:52:03', 0);
INSERT INTO public.system_menu VALUES (5005, 'AI 工作流测试', 'ai:workflow:test', 3, 5, 5000, '', '', '', '', 0, true, true, true, '1', '2025-03-30 10:29:41', '1', '2025-03-30 10:29:41', 0);
INSERT INTO public.system_menu VALUES (5010, '租户切换', 'system:tenant:visit', 3, 999, 1138, '', '', '', '', 0, true, true, true, '1', '2025-05-05 15:25:32', '1', '2025-05-05 15:25:32', 0);
INSERT INTO public.system_menu VALUES (20010, '项目创建', 'toon:project:create', 3, 1, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20011, '项目更新', 'toon:project:update', 3, 2, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20012, '项目删除', 'toon:project:delete', 3, 3, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20013, '剧本读取', 'toon:episode:read', 3, 4, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20014, '剧本创建', 'toon:episode:create', 3, 5, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20015, '剧本更新', 'toon:episode:update', 3, 6, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20016, '剧本删除', 'toon:episode:delete', 3, 7, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20017, '分镜读取', 'toon:scene:read', 3, 8, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20018, '分镜创建', 'toon:scene:create', 3, 9, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20019, '分镜更新', 'toon:scene:update', 3, 10, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20020, '分镜删除', 'toon:scene:delete', 3, 11, 20001, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.423799', 0);
INSERT INTO public.system_menu VALUES (20000, '短剧工厂', '', 1, 30, 0, '/toonflow', 'lucide:clapperboard', '', 'Toonflow', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.487306', 0);
INSERT INTO public.system_menu VALUES (20001, '项目工作台', 'toon:project:read', 2, 1, 20000, 'projects', 'lucide:layout-dashboard', 'toonflow/projects/index', 'ToonflowProjects', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.487306', 0);
INSERT INTO public.system_menu VALUES (30000, 'AI 大模型', '', 1, 40, 0, '/ai', 'tabler:ai', '', 'Ai', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 08:12:35.316268', 1);
INSERT INTO public.system_menu VALUES (30001, 'AI 对话', '', 2, 1, 30000, 'chat', 'lucide:message-circle', 'ai/chat/index/index', 'AiChat', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 08:12:35.316268', 1);
INSERT INTO public.system_menu VALUES (30002, 'AI 绘图', '', 2, 2, 30000, 'image', 'lucide:image', 'ai/image/index/index', 'AiImage', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 08:12:35.316268', 1);
INSERT INTO public.system_menu VALUES (30003, 'AI 写作', '', 2, 3, 30000, 'write', 'lucide:pen-line', 'ai/write/index/index', 'AiWrite', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 08:12:35.316268', 1);
INSERT INTO public.system_menu VALUES (20006, '项目详情', 'toon:project:read', 2, 6, 20000, 'projects/:id', 'lucide:file-stack', 'toonflow/projects/detail', 'ToonflowProjectDetail', 0, false, false, false, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.487306', 0);
INSERT INTO public.system_menu VALUES (20007, '创作手册', 'toon:project:read', 2, 2, 20000, 'manuals', 'lucide:notebook-tabs', 'toonflow/manuals/index', 'ToonflowManuals', 0, true, true, true, 'system', '2026-07-16 05:03:23.546161', 'system', '2026-07-16 05:03:23.546161', 0);
INSERT INTO public.system_menu VALUES (20002, '风格库', 'toon:project:read', 2, 3, 20000, 'styles', 'lucide:palette', 'toonflow/styles/index', 'ToonflowStyles', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.55964', 0);
INSERT INTO public.system_menu VALUES (20003, '任务中心', 'toon:project:read', 2, 4, 20000, 'tasks', 'lucide:list-checks', 'toonflow/tasks/index', 'ToonflowTasks', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.55964', 0);
INSERT INTO public.system_menu VALUES (20004, '提示词与 Skill', 'toon:project:read', 2, 5, 20000, 'prompts', 'lucide:wand-sparkles', 'toonflow/prompts/index', 'ToonflowPrompts', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.55964', 0);
INSERT INTO public.system_menu VALUES (20005, '模型与 Agent', 'toon:project:read', 2, 6, 20000, 'settings', 'lucide:bot', 'toonflow/settings/index', 'ToonflowSettings', 0, true, true, true, 'system', '2026-07-16 05:03:23.423799', 'system', '2026-07-16 05:03:23.55964', 0);
INSERT INTO public.system_menu VALUES (30101, '模型查询', 'ai:model:query', 3, 1, 30006, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30102, '模型创建', 'ai:model:create', 3, 2, 30006, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30103, '模型更新', 'ai:model:update', 3, 3, 30006, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30104, '模型删除', 'ai:model:delete', 3, 4, 30006, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30111, '知识库创建', 'ai:knowledge:create', 3, 1, 30005, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30112, '知识库更新', 'ai:knowledge:update', 3, 2, 30005, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30113, '知识库删除', 'ai:knowledge:delete', 3, 3, 30005, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30121, '角色创建', 'ai:chat-role:create', 3, 1, 30007, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30122, '角色更新', 'ai:chat-role:update', 3, 2, 30007, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30123, '角色删除', 'ai:chat-role:delete', 3, 3, 30007, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30131, '工具创建', 'ai:tool:create', 3, 1, 30008, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30132, '工具更新', 'ai:tool:update', 3, 2, 30008, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30133, '工具删除', 'ai:tool:delete', 3, 3, 30008, '', '', '', '', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 05:03:23.711366', 0);
INSERT INTO public.system_menu VALUES (30004, 'AI 音乐', '', 2, 4, 30000, 'music', 'lucide:music', 'ai/music/index/index', 'AiMusic', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 08:12:35.316268', 1);
INSERT INTO public.system_menu VALUES (30005, '知识库', 'ai:knowledge:query', 2, 5, 30000, 'knowledge', 'lucide:database', 'ai/knowledge/knowledge/index', 'AiKnowledge', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 08:12:35.316268', 1);
INSERT INTO public.system_menu VALUES (30006, '模型管理', 'ai:model:query', 2, 6, 30000, 'model', 'lucide:brain-circuit', 'ai/model/model/index', 'AiModel', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 08:12:35.316268', 1);
INSERT INTO public.system_menu VALUES (30007, '聊天角色', 'ai:chat-role:query', 2, 7, 30000, 'model/chat-role', 'lucide:bot', 'ai/model/chatRole/index', 'AiModelChatRole', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 08:12:35.316268', 1);
INSERT INTO public.system_menu VALUES (30008, '工具管理', 'ai:tool:query', 2, 8, 30000, 'model/tool', 'lucide:wrench', 'ai/model/tool/index', 'AiModelTool', 0, true, true, true, 'system', '2026-07-16 05:03:23.711366', 'system', '2026-07-16 08:12:35.316268', 1);


--
-- Data for Name: system_notice; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_notice VALUES (1, '芋道的公众', '<p>新版本内容133222</p>', 1, 0, 'admin', '2021-01-05 17:03:48', '"1"', '2025-08-31 09:38:22', 0, 1);
INSERT INTO public.system_notice VALUES (2, '维护通知：2018-07-01 系统凌晨维护', '<p><img src="http://test.yudao.iocoder.cn/b7cb3cf49b4b3258bf7309a09dd2f4e5.jpg" alt="" data-href="">11112222<img src="http://test.yudao.iocoder.cn/fe44fc7bdb82ca421184b2eebbaee9e2148d4a1827479a4eb4521e11d2a062ba.png" alt="image" data-href="http://test.yudao.iocoder.cn/fe44fc7bdb82ca421184b2eebbaee9e2148d4a1827479a4eb4521e11d2a062ba.png">3333</p>', 2, 1, 'admin', '2021-01-05 17:03:48', '1', '2025-04-18 23:56:40', 0, 1);
INSERT INTO public.system_notice VALUES (4, '我是测试标题', '<p>哈哈哈哈123</p>', 1, 0, '110', '2022-02-22 01:01:25', '110', '2022-02-22 01:01:46', 0, 121);


--
-- Data for Name: system_notify_message; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_notify_template; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_notify_template VALUES (2, 'Codex测试', 'codex_test_1784183375', '系统消息', '你好，{name}', 2, '["name"]', 0, 'codex verify', '', '2026-07-16 06:29:35.400788', '', '2026-07-16 06:29:35.400788', 0);


--
-- Data for Name: system_oauth2_access_token; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_oauth2_approve; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_oauth2_client; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_oauth2_client VALUES (1, 'default', '', '芋道源码', 'http://test.yudao.iocoder.cn/20250502/sort2_1746189740718.png', '我是描述', 0, 1800, 2592000, '["https://www.iocoder.cn","https://doc.iocoder.cn"]', '["password","authorization_code","implicit","refresh_token","client_credentials"]', '["user.read","user.write"]', '[]', '["user.read","user.write"]', '[]', '{}', '1', '2022-05-11 21:47:12', '1', '2025-12-07 20:07:09', 0);
INSERT INTO public.system_oauth2_client VALUES (40, 'test', '', 'biubiu', 'http://test.yudao.iocoder.cn/20251227/javayuanma_1766829882970.jpg', '啦啦啦啦', 0, 1800, 43200, '["https://www.iocoder.cn"]', '["password","authorization_code","implicit"]', '["user_info","projects"]', '["user_info"]', '[]', '[]', '{}', '1', '2022-05-12 00:28:20', '1', '2025-12-27 18:04:44', 0);
INSERT INTO public.system_oauth2_client VALUES (41, 'yudao-sso-demo-by-code', '', '基于授权码模式，如何实现 SSO 单点登录？', 'http://test.yudao.iocoder.cn/it/20250502/sign_1746181948685.png', NULL, 0, 1800, 43200, '["http://127.0.0.1:18080"]', '["authorization_code","refresh_token"]', '["user.read","user.write"]', '[]', '[]', '[]', NULL, '1', '2022-09-29 13:28:31', '1', '2025-05-02 18:32:30', 0);
INSERT INTO public.system_oauth2_client VALUES (42, 'yudao-sso-demo-by-password', '', '基于密码模式，如何实现 SSO 单点登录？', 'http://test.yudao.iocoder.cn/20251025/images (3)_1761360515810.jpeg', NULL, 0, 1800, 43200, '["http://127.0.0.1:18080"]', '["password","refresh_token"]', '["user.read","user.write"]', '[]', '[]', '[]', NULL, '1', '2022-10-04 17:40:16', '1', '2025-10-25 10:49:40', 0);


--
-- Data for Name: system_oauth2_code; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_oauth2_refresh_token; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_operate_log; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_post; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_post VALUES (2, 'se', '项目经理', 2, 0, '', 'admin', '2021-01-05 17:03:48', '1', '2025-12-15 22:38:43', 0, 1);
INSERT INTO public.system_post VALUES (4, 'user', '普通员工', 4, 0, '111222', 'admin', '2021-01-05 17:03:48', '1', '2025-03-24 21:32:40', 0, 1);
INSERT INTO public.system_post VALUES (5, 'HR', '人力资源', 5, 0, '`', '1', '2024-03-24 20:45:40', '1', '2025-03-29 19:08:10', 0, 1);
INSERT INTO public.system_post VALUES (7, 'test', '测试', 10, 0, NULL, '1', '2025-09-02 08:45:57', '1', '2025-09-02 08:45:57', 0, 1);


--
-- Data for Name: system_role; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_role VALUES (1, '超级管理员', 'super_admin', 1, 1, '', 0, 1, '超级管理员', 'admin', '2021-01-05 17:03:48', '', '2022-02-22 05:08:21', 0, 1);
INSERT INTO public.system_role VALUES (2, '普通角色', 'common', 2, 2, '', 0, 1, '普通角色', 'admin', '2021-01-05 17:03:48', '', '2022-02-22 05:08:20', 0, 1);
INSERT INTO public.system_role VALUES (3, 'CRM 管理员', 'crm_admin', 2, 1, '', 0, 1, 'CRM 专属角色', '1', '2024-02-24 10:51:13', '1', '2024-02-24 02:51:32', 0, 1);
INSERT INTO public.system_role VALUES (109, '租户管理员', 'tenant_admin', 0, 1, '', 0, 1, '系统自动生成', '1', '2022-02-22 00:56:14', '1', '2022-02-22 00:56:14', 0, 121);
INSERT INTO public.system_role VALUES (111, '租户管理员', 'tenant_admin', 0, 1, '', 0, 1, '系统自动生成', '1', '2022-03-07 21:37:58', '1', '2022-03-07 21:37:58', 0, 122);
INSERT INTO public.system_role VALUES (155, '测试数据权限1', 'test-dp', 4, 2, '[112,100,102,103,104,105,107,108]', 0, 2, '1111', '1', '2025-03-31 14:58:06', '1', '2025-12-04 23:29:40', 0, 1);


--
-- Data for Name: system_role_menu; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_role_menu VALUES (263, 109, 1, '1', '2022-02-22 00:56:14', '1', '2022-02-22 00:56:14', 0, 121);
INSERT INTO public.system_role_menu VALUES (434, 2, 1, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (454, 2, 1093, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (455, 2, 1094, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (460, 2, 1100, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (467, 2, 1107, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (6367, 1, 6143, 'system', '2026-07-15 00:40:28.757045', 'system', '2026-07-15 00:40:28.757045', 0, 1);
INSERT INTO public.system_role_menu VALUES (477, 2, 100, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (478, 2, 101, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (479, 2, 102, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (6368, 1, 6144, 'system', '2026-07-15 00:40:28.757045', 'system', '2026-07-15 00:40:28.757045', 0, 1);
INSERT INTO public.system_role_menu VALUES (481, 2, 103, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (483, 2, 104, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (485, 2, 105, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (488, 2, 107, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (490, 2, 108, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (492, 2, 109, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (498, 2, 1138, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (523, 2, 1224, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (524, 2, 1225, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (541, 2, 500, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (543, 2, 501, '1', '2022-02-22 13:09:12', '1', '2022-02-22 13:09:12', 0, 1);
INSERT INTO public.system_role_menu VALUES (675, 2, 2, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (689, 2, 1077, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (690, 2, 1078, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (692, 2, 1083, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (693, 2, 1084, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (699, 2, 1090, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (703, 2, 106, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (704, 2, 110, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (705, 2, 111, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (706, 2, 112, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (707, 2, 113, '1', '2022-02-22 13:16:57', '1', '2022-02-22 13:16:57', 0, 1);
INSERT INTO public.system_role_menu VALUES (1296, 110, 1, '110', '2022-02-23 00:23:55', '110', '2022-02-23 00:23:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1578, 111, 1, '1', '2022-03-07 21:37:58', '1', '2022-03-07 21:37:58', 0, 122);
INSERT INTO public.system_role_menu VALUES (1729, 109, 100, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1730, 109, 101, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1731, 109, 1063, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1732, 109, 1064, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1733, 109, 1001, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1734, 109, 1065, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1735, 109, 1002, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1736, 109, 1003, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1737, 109, 1004, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1738, 109, 1005, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1739, 109, 1006, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1740, 109, 1007, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1741, 109, 1008, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1742, 109, 1009, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1743, 109, 1010, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1744, 109, 1011, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1745, 109, 1012, '1', '2022-09-21 22:08:51', '1', '2022-09-21 22:08:51', 0, 121);
INSERT INTO public.system_role_menu VALUES (1746, 111, 100, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1747, 111, 101, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1748, 111, 1063, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1749, 111, 1064, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1750, 111, 1001, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1751, 111, 1065, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1752, 111, 1002, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1753, 111, 1003, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1754, 111, 1004, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1755, 111, 1005, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1756, 111, 1006, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1757, 111, 1007, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1758, 111, 1008, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1759, 111, 1009, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1760, 111, 1010, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1761, 111, 1011, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1762, 111, 1012, '1', '2022-09-21 22:08:52', '1', '2022-09-21 22:08:52', 0, 122);
INSERT INTO public.system_role_menu VALUES (1763, 109, 100, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1764, 109, 101, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1765, 109, 1063, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1766, 109, 1064, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1767, 109, 1001, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1768, 109, 1065, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1769, 109, 1002, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1770, 109, 1003, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1771, 109, 1004, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1772, 109, 1005, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1773, 109, 1006, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1774, 109, 1007, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1775, 109, 1008, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1776, 109, 1009, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1777, 109, 1010, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1778, 109, 1011, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1779, 109, 1012, '1', '2022-09-21 22:08:53', '1', '2022-09-21 22:08:53', 0, 121);
INSERT INTO public.system_role_menu VALUES (1780, 111, 100, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1781, 111, 101, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1782, 111, 1063, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1783, 111, 1064, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1784, 111, 1001, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1785, 111, 1065, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1786, 111, 1002, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1787, 111, 1003, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1788, 111, 1004, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1789, 111, 1005, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1790, 111, 1006, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1791, 111, 1007, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1792, 111, 1008, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1793, 111, 1009, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1794, 111, 1010, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1795, 111, 1011, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1796, 111, 1012, '1', '2022-09-21 22:08:54', '1', '2022-09-21 22:08:54', 0, 122);
INSERT INTO public.system_role_menu VALUES (1797, 109, 100, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1798, 109, 101, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1799, 109, 1063, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1800, 109, 1064, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1801, 109, 1001, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1802, 109, 1065, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1803, 109, 1002, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1804, 109, 1003, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1805, 109, 1004, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1806, 109, 1005, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1807, 109, 1006, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1808, 109, 1007, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1809, 109, 1008, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1810, 109, 1009, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1811, 109, 1010, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1812, 109, 1011, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1813, 109, 1012, '1', '2022-09-21 22:08:55', '1', '2022-09-21 22:08:55', 0, 121);
INSERT INTO public.system_role_menu VALUES (1814, 111, 100, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1815, 111, 101, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1816, 111, 1063, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1817, 111, 1064, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1818, 111, 1001, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1819, 111, 1065, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1820, 111, 1002, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1821, 111, 1003, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1822, 111, 1004, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1823, 111, 1005, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1824, 111, 1006, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1825, 111, 1007, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1826, 111, 1008, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1827, 111, 1009, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1828, 111, 1010, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1829, 111, 1011, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1830, 111, 1012, '1', '2022-09-21 22:08:56', '1', '2022-09-21 22:08:56', 0, 122);
INSERT INTO public.system_role_menu VALUES (1831, 109, 103, '1', '2022-09-21 22:43:23', '1', '2022-09-21 22:43:23', 0, 121);
INSERT INTO public.system_role_menu VALUES (1832, 109, 1017, '1', '2022-09-21 22:43:23', '1', '2022-09-21 22:43:23', 0, 121);
INSERT INTO public.system_role_menu VALUES (1833, 109, 1018, '1', '2022-09-21 22:43:23', '1', '2022-09-21 22:43:23', 0, 121);
INSERT INTO public.system_role_menu VALUES (1834, 109, 1019, '1', '2022-09-21 22:43:23', '1', '2022-09-21 22:43:23', 0, 121);
INSERT INTO public.system_role_menu VALUES (1835, 109, 1020, '1', '2022-09-21 22:43:23', '1', '2022-09-21 22:43:23', 0, 121);
INSERT INTO public.system_role_menu VALUES (1836, 111, 103, '1', '2022-09-21 22:43:24', '1', '2022-09-21 22:43:24', 0, 122);
INSERT INTO public.system_role_menu VALUES (1837, 111, 1017, '1', '2022-09-21 22:43:24', '1', '2022-09-21 22:43:24', 0, 122);
INSERT INTO public.system_role_menu VALUES (1838, 111, 1018, '1', '2022-09-21 22:43:24', '1', '2022-09-21 22:43:24', 0, 122);
INSERT INTO public.system_role_menu VALUES (1839, 111, 1019, '1', '2022-09-21 22:43:24', '1', '2022-09-21 22:43:24', 0, 122);
INSERT INTO public.system_role_menu VALUES (1840, 111, 1020, '1', '2022-09-21 22:43:24', '1', '2022-09-21 22:43:24', 0, 122);
INSERT INTO public.system_role_menu VALUES (1841, 109, 1036, '1', '2022-09-21 22:48:13', '1', '2022-09-21 22:48:13', 0, 121);
INSERT INTO public.system_role_menu VALUES (1842, 109, 1037, '1', '2022-09-21 22:48:13', '1', '2022-09-21 22:48:13', 0, 121);
INSERT INTO public.system_role_menu VALUES (1843, 109, 1038, '1', '2022-09-21 22:48:13', '1', '2022-09-21 22:48:13', 0, 121);
INSERT INTO public.system_role_menu VALUES (1844, 109, 1039, '1', '2022-09-21 22:48:13', '1', '2022-09-21 22:48:13', 0, 121);
INSERT INTO public.system_role_menu VALUES (1845, 109, 107, '1', '2022-09-21 22:48:13', '1', '2022-09-21 22:48:13', 0, 121);
INSERT INTO public.system_role_menu VALUES (1846, 111, 1036, '1', '2022-09-21 22:48:13', '1', '2022-09-21 22:48:13', 0, 122);
INSERT INTO public.system_role_menu VALUES (1847, 111, 1037, '1', '2022-09-21 22:48:13', '1', '2022-09-21 22:48:13', 0, 122);
INSERT INTO public.system_role_menu VALUES (1848, 111, 1038, '1', '2022-09-21 22:48:13', '1', '2022-09-21 22:48:13', 0, 122);
INSERT INTO public.system_role_menu VALUES (1849, 111, 1039, '1', '2022-09-21 22:48:13', '1', '2022-09-21 22:48:13', 0, 122);
INSERT INTO public.system_role_menu VALUES (1850, 111, 107, '1', '2022-09-21 22:48:13', '1', '2022-09-21 22:48:13', 0, 122);
INSERT INTO public.system_role_menu VALUES (1991, 2, 1024, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (1992, 2, 1025, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (1993, 2, 1026, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (1994, 2, 1027, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (1995, 2, 1028, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (1996, 2, 1029, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (1997, 2, 1030, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (1998, 2, 1031, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (1999, 2, 1032, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2000, 2, 1033, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2001, 2, 1034, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2002, 2, 1035, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2003, 2, 1036, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2004, 2, 1037, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2005, 2, 1038, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2006, 2, 1039, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2007, 2, 1040, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2008, 2, 1042, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2009, 2, 1043, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2010, 2, 1045, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2011, 2, 1046, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2012, 2, 1048, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2013, 2, 1050, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2014, 2, 1051, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2015, 2, 1052, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2016, 2, 1053, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2017, 2, 1054, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2018, 2, 1056, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2019, 2, 1057, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2020, 2, 1058, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2021, 2, 2083, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2022, 2, 1059, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2023, 2, 1060, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2024, 2, 1063, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2025, 2, 1064, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2026, 2, 1065, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2027, 2, 1066, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2028, 2, 1067, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2029, 2, 1070, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2034, 2, 1075, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2036, 2, 1082, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2037, 2, 1085, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2038, 2, 1086, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2039, 2, 1087, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2040, 2, 1088, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2041, 2, 1089, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2042, 2, 1091, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2043, 2, 1092, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2044, 2, 1095, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2045, 2, 1096, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2046, 2, 1097, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2047, 2, 1098, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2048, 2, 1101, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2049, 2, 1102, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2050, 2, 1103, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2051, 2, 1104, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2052, 2, 1105, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2053, 2, 1106, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2054, 2, 1108, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2055, 2, 1109, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (6369, 1, 6142, 'system', '2026-07-15 00:40:28.757045', 'system', '2026-07-15 00:40:28.757045', 0, 1);
INSERT INTO public.system_role_menu VALUES (6370, 1, 6104, 'system', '2026-07-15 00:40:28.757045', 'system', '2026-07-15 00:40:28.757045', 0, 1);
INSERT INTO public.system_role_menu VALUES (6371, 1, 6100, 'system', '2026-07-15 00:40:28.757045', 'system', '2026-07-15 00:40:28.757045', 0, 1);
INSERT INTO public.system_role_menu VALUES (6372, 1, 6141, 'system', '2026-07-15 00:40:28.757045', 'system', '2026-07-15 00:40:28.757045', 0, 1);
INSERT INTO public.system_role_menu VALUES (2072, 2, 114, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2073, 2, 1139, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2074, 2, 115, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2075, 2, 1140, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2076, 2, 116, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2077, 2, 1141, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2078, 2, 1142, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2079, 2, 1143, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2099, 2, 1226, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2100, 2, 1227, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2101, 2, 1228, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2102, 2, 1229, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2103, 2, 1237, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2104, 2, 1238, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2105, 2, 1239, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2106, 2, 1240, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2107, 2, 1241, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2108, 2, 1242, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2109, 2, 1243, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2117, 2, 1255, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2118, 2, 1256, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2119, 2, 1257, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2120, 2, 1258, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2121, 2, 1259, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2122, 2, 1260, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2123, 2, 1261, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2124, 2, 1263, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2125, 2, 1264, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2126, 2, 1265, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2127, 2, 1266, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2128, 2, 1267, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2129, 2, 1001, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2130, 2, 1002, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2131, 2, 1003, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2132, 2, 1004, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2133, 2, 1005, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2134, 2, 1006, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2135, 2, 1007, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2136, 2, 1008, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2137, 2, 1009, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2138, 2, 1010, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2139, 2, 1011, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2140, 2, 1012, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2141, 2, 1013, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2143, 2, 1015, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2145, 2, 1017, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2146, 2, 1018, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2147, 2, 1019, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2148, 2, 1020, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2149, 2, 1021, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2150, 2, 1022, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (2151, 2, 1023, '1', '2023-01-25 08:42:52', '1', '2023-01-25 08:42:52', 0, 1);
INSERT INTO public.system_role_menu VALUES (6373, 1, 6145, 'system', '2026-07-15 00:57:21.724071', 'system', '2026-07-15 00:57:21.724071', 0, 1);
INSERT INTO public.system_role_menu VALUES (6375, 1, 6151, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0, 1);
INSERT INTO public.system_role_menu VALUES (6376, 1, 6148, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0, 1);
INSERT INTO public.system_role_menu VALUES (6377, 1, 6147, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0, 1);
INSERT INTO public.system_role_menu VALUES (6378, 1, 6105, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0, 1);
INSERT INTO public.system_role_menu VALUES (6379, 1, 6149, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0, 1);
INSERT INTO public.system_role_menu VALUES (6380, 1, 6150, 'system', '2026-07-15 10:45:40.244018', 'system', '2026-07-15 10:45:40.244018', 0, 1);
INSERT INTO public.system_role_menu VALUES (2929, 109, 1224, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2930, 109, 1225, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2931, 109, 1226, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2932, 109, 1227, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2933, 109, 1228, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2934, 109, 1229, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2935, 109, 1138, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2936, 109, 1139, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2937, 109, 1140, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2938, 109, 1141, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2939, 109, 1142, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2940, 109, 1143, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 121);
INSERT INTO public.system_role_menu VALUES (2941, 111, 1224, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2942, 111, 1225, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2943, 111, 1226, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2944, 111, 1227, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2945, 111, 1228, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2946, 111, 1229, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2947, 111, 1138, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2948, 111, 1139, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2949, 111, 1140, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2950, 111, 1141, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2951, 111, 1142, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2952, 111, 1143, '1', '2023-12-02 23:19:40', '1', '2023-12-02 23:19:40', 0, 122);
INSERT INTO public.system_role_menu VALUES (2993, 109, 2, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (2994, 109, 1031, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (2995, 109, 1032, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (2996, 109, 1033, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (2997, 109, 1034, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (2998, 109, 1035, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (2999, 109, 1050, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3000, 109, 1051, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3001, 109, 1052, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3002, 109, 1053, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3003, 109, 1054, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3004, 109, 1056, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3005, 109, 1057, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3006, 109, 1058, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3007, 109, 1059, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3008, 109, 1060, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3009, 109, 1066, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3010, 109, 1067, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3011, 109, 1070, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3012, 109, 1075, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3014, 109, 1077, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3015, 109, 1078, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3016, 109, 1082, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3017, 109, 1083, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3018, 109, 1084, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3019, 109, 1085, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3020, 109, 1086, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3021, 109, 1087, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3022, 109, 1088, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3023, 109, 1089, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3024, 109, 1090, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3025, 109, 1091, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3026, 109, 1092, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3027, 109, 106, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3028, 109, 110, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3029, 109, 111, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3030, 109, 112, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3031, 109, 113, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3032, 109, 114, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3033, 109, 115, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3034, 109, 116, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3035, 109, 2472, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3036, 109, 2478, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3037, 109, 2479, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3038, 109, 2480, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3039, 109, 2481, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3040, 109, 2482, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3041, 109, 2483, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3042, 109, 2484, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3043, 109, 2485, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3044, 109, 2486, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3045, 109, 2487, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3046, 109, 2488, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3047, 109, 2489, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3048, 109, 2490, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3049, 109, 2491, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3050, 109, 2492, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3051, 109, 2493, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3052, 109, 2494, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3053, 109, 2495, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3054, 109, 2497, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3055, 109, 1237, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3056, 109, 1238, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3057, 109, 1239, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3058, 109, 1240, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3059, 109, 1241, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3060, 109, 1242, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3061, 109, 1243, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3062, 109, 2525, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3063, 109, 1255, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3064, 109, 1256, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3065, 109, 1257, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3066, 109, 1258, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3067, 109, 1259, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3068, 109, 1260, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 121);
INSERT INTO public.system_role_menu VALUES (3069, 111, 2, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3070, 111, 1031, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3071, 111, 1032, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3072, 111, 1033, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3073, 111, 1034, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3074, 111, 1035, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3075, 111, 1050, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3076, 111, 1051, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3077, 111, 1052, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3078, 111, 1053, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3079, 111, 1054, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3080, 111, 1056, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3081, 111, 1057, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3082, 111, 1058, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3083, 111, 1059, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3084, 111, 1060, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3085, 111, 1066, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3086, 111, 1067, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3087, 111, 1070, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3088, 111, 1075, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3090, 111, 1077, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3091, 111, 1078, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3092, 111, 1082, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3093, 111, 1083, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3094, 111, 1084, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3095, 111, 1085, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3096, 111, 1086, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3097, 111, 1087, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3098, 111, 1088, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3099, 111, 1089, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3100, 111, 1090, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3101, 111, 1091, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3102, 111, 1092, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3103, 111, 106, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3104, 111, 110, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3105, 111, 111, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3106, 111, 112, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3107, 111, 113, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3108, 111, 114, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3109, 111, 115, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3110, 111, 116, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3111, 111, 2472, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3112, 111, 2478, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3113, 111, 2479, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3114, 111, 2480, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3115, 111, 2481, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3116, 111, 2482, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3117, 111, 2483, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3118, 111, 2484, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3119, 111, 2485, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3120, 111, 2486, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3121, 111, 2487, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3122, 111, 2488, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3123, 111, 2489, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3124, 111, 2490, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3125, 111, 2491, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3126, 111, 2492, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3127, 111, 2493, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3128, 111, 2494, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3129, 111, 2495, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3130, 111, 2497, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3131, 111, 1237, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3132, 111, 1238, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3133, 111, 1239, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3134, 111, 1240, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3135, 111, 1241, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3136, 111, 1242, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3137, 111, 1243, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3138, 111, 2525, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3139, 111, 1255, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3140, 111, 1256, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3141, 111, 1257, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3142, 111, 1258, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3143, 111, 1259, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3144, 111, 1260, '1', '2023-12-02 23:41:02', '1', '2023-12-02 23:41:02', 0, 122);
INSERT INTO public.system_role_menu VALUES (3221, 109, 102, '1', '2023-12-30 11:42:36', '1', '2023-12-30 11:42:36', 0, 121);
INSERT INTO public.system_role_menu VALUES (3222, 109, 1013, '1', '2023-12-30 11:42:36', '1', '2023-12-30 11:42:36', 0, 121);
INSERT INTO public.system_role_menu VALUES (3223, 109, 1014, '1', '2023-12-30 11:42:36', '1', '2023-12-30 11:42:36', 0, 121);
INSERT INTO public.system_role_menu VALUES (3224, 109, 1015, '1', '2023-12-30 11:42:36', '1', '2023-12-30 11:42:36', 0, 121);
INSERT INTO public.system_role_menu VALUES (3225, 109, 1016, '1', '2023-12-30 11:42:36', '1', '2023-12-30 11:42:36', 0, 121);
INSERT INTO public.system_role_menu VALUES (3226, 111, 102, '1', '2023-12-30 11:42:36', '1', '2023-12-30 11:42:36', 0, 122);
INSERT INTO public.system_role_menu VALUES (3227, 111, 1013, '1', '2023-12-30 11:42:36', '1', '2023-12-30 11:42:36', 0, 122);
INSERT INTO public.system_role_menu VALUES (3228, 111, 1014, '1', '2023-12-30 11:42:36', '1', '2023-12-30 11:42:36', 0, 122);
INSERT INTO public.system_role_menu VALUES (3229, 111, 1015, '1', '2023-12-30 11:42:36', '1', '2023-12-30 11:42:36', 0, 122);
INSERT INTO public.system_role_menu VALUES (3230, 111, 1016, '1', '2023-12-30 11:42:36', '1', '2023-12-30 11:42:36', 0, 122);
INSERT INTO public.system_role_menu VALUES (4163, 109, 5, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4164, 109, 1118, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4165, 109, 1119, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4166, 109, 1120, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4167, 109, 2713, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4168, 109, 2714, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4169, 109, 2715, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4170, 109, 2716, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4171, 109, 2717, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4172, 109, 2718, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4173, 109, 2720, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4174, 109, 1185, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4175, 109, 2721, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4176, 109, 1186, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4177, 109, 2722, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4178, 109, 1187, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4179, 109, 2723, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4180, 109, 1188, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4181, 109, 2724, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4182, 109, 1189, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4183, 109, 2725, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4184, 109, 1190, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4185, 109, 2726, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4186, 109, 1191, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4187, 109, 2727, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4188, 109, 1192, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4189, 109, 2728, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4190, 109, 1193, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4191, 109, 2729, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4192, 109, 1194, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4193, 109, 2730, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4194, 109, 1195, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4195, 109, 2731, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4197, 109, 2732, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4198, 109, 1197, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4199, 109, 2733, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4200, 109, 1198, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4201, 109, 2734, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4202, 109, 1199, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4203, 109, 2735, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4204, 109, 1200, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4205, 109, 1201, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4206, 109, 1202, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4207, 109, 1207, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4208, 109, 1208, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4209, 109, 1209, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4210, 109, 1210, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4211, 109, 1211, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4212, 109, 1212, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4213, 109, 1213, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4214, 109, 1215, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4215, 109, 1216, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4216, 109, 1217, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4217, 109, 1218, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4218, 109, 1219, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4219, 109, 1220, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4220, 109, 1221, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4221, 109, 1222, '1', '2024-03-30 17:53:17', '1', '2024-03-30 17:53:17', 0, 121);
INSERT INTO public.system_role_menu VALUES (4222, 111, 5, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4223, 111, 1118, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4224, 111, 1119, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4225, 111, 1120, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4226, 111, 2713, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4227, 111, 2714, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4228, 111, 2715, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4229, 111, 2716, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4230, 111, 2717, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4231, 111, 2718, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4232, 111, 2720, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4233, 111, 1185, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4234, 111, 2721, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4235, 111, 1186, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4236, 111, 2722, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4237, 111, 1187, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4238, 111, 2723, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4239, 111, 1188, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4240, 111, 2724, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4241, 111, 1189, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4242, 111, 2725, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4243, 111, 1190, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4244, 111, 2726, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4245, 111, 1191, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4246, 111, 2727, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4247, 111, 1192, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4248, 111, 2728, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4249, 111, 1193, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4250, 111, 2729, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4251, 111, 1194, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4252, 111, 2730, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4253, 111, 1195, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4254, 111, 2731, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4256, 111, 2732, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4257, 111, 1197, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4258, 111, 2733, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4259, 111, 1198, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4260, 111, 2734, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4261, 111, 1199, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4262, 111, 2735, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4263, 111, 1200, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4264, 111, 1201, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4265, 111, 1202, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4266, 111, 1207, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4267, 111, 1208, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4268, 111, 1209, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4269, 111, 1210, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4270, 111, 1211, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4271, 111, 1212, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4272, 111, 1213, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4273, 111, 1215, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4274, 111, 1216, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4275, 111, 1217, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4276, 111, 1218, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4277, 111, 1219, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4278, 111, 1220, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4279, 111, 1221, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (4280, 111, 1222, '1', '2024-03-30 17:53:18', '1', '2024-03-30 17:53:18', 0, 122);
INSERT INTO public.system_role_menu VALUES (5779, 2, 2739, '1', '2024-07-07 20:39:38', '1', '2024-07-07 20:39:38', 0, 1);
INSERT INTO public.system_role_menu VALUES (5780, 2, 2740, '1', '2024-07-07 20:39:38', '1', '2024-07-07 20:39:38', 0, 1);
INSERT INTO public.system_role_menu VALUES (5781, 2, 2758, '1', '2024-07-07 20:39:38', '1', '2024-07-07 20:39:38', 0, 1);
INSERT INTO public.system_role_menu VALUES (5782, 2, 2759, '1', '2024-07-07 20:39:38', '1', '2024-07-07 20:39:38', 0, 1);
INSERT INTO public.system_role_menu VALUES (6374, 1, 6146, 'system', '2026-07-15 01:11:30.173694', 'system', '2026-07-15 01:11:30.173694', 0, 1);
INSERT INTO public.system_role_menu VALUES (5789, 109, 2739, '1', '2024-07-13 22:37:24', '1', '2024-07-13 22:37:24', 0, 121);
INSERT INTO public.system_role_menu VALUES (5790, 109, 2740, '1', '2024-07-13 22:37:24', '1', '2024-07-13 22:37:24', 0, 121);
INSERT INTO public.system_role_menu VALUES (5791, 111, 2739, '1', '2024-07-13 22:37:24', '1', '2024-07-13 22:37:24', 0, 122);
INSERT INTO public.system_role_menu VALUES (5792, 111, 2740, '1', '2024-07-13 22:37:24', '1', '2024-07-13 22:37:24', 0, 122);
INSERT INTO public.system_role_menu VALUES (6293, 2, 5, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6294, 2, 1118, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6295, 2, 1119, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6296, 2, 1120, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6297, 2, 2713, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6298, 2, 2714, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6299, 2, 2715, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6300, 2, 2716, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6301, 2, 2717, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6302, 2, 2718, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6303, 2, 2720, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6304, 2, 1185, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6305, 2, 2721, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6306, 2, 1186, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6307, 2, 2722, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6308, 2, 1187, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6309, 2, 2723, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6310, 2, 1188, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6311, 2, 2724, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6312, 2, 1189, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6313, 2, 2725, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6314, 2, 1190, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6315, 2, 2726, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6316, 2, 1191, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6317, 2, 2727, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6318, 2, 1192, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6319, 2, 2728, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6320, 2, 1193, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6321, 2, 2729, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6322, 2, 1194, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6323, 2, 2730, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6324, 2, 1195, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6325, 2, 2731, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6326, 2, 2732, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6327, 2, 1197, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6328, 2, 2733, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6329, 2, 1198, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6330, 2, 2734, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6331, 2, 1199, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6332, 2, 2735, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6333, 2, 1200, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6334, 2, 1201, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6335, 2, 1202, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6336, 2, 1207, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6337, 2, 1208, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6338, 2, 1209, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6339, 2, 1210, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6340, 2, 1211, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6341, 2, 1212, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6342, 2, 1213, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6343, 2, 1215, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6344, 2, 1216, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6345, 2, 1217, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6346, 2, 1218, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6347, 2, 1219, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6348, 2, 1220, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6349, 2, 1221, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6350, 2, 1222, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (6351, 2, 2913, '1', '2026-01-04 18:09:41', '1', '2026-01-04 18:09:41', 0, 1);
INSERT INTO public.system_role_menu VALUES (220000, 1, 20000, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220001, 1, 20001, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220002, 1, 20002, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220003, 1, 20003, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220004, 1, 20004, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220005, 1, 20005, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220006, 1, 20006, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220010, 1, 20010, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220011, 1, 20011, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220012, 1, 20012, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220013, 1, 20013, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220014, 1, 20014, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220015, 1, 20015, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220016, 1, 20016, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220017, 1, 20017, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220018, 1, 20018, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220019, 1, 20019, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220020, 1, 20020, 'system', '2026-07-16 05:03:23.445758', 'system', '2026-07-16 05:03:23.445758', 0, 1);
INSERT INTO public.system_role_menu VALUES (220007, 1, 20007, 'system', '2026-07-16 05:03:23.574036', 'system', '2026-07-16 05:03:23.574036', 0, 1);
INSERT INTO public.system_role_menu VALUES (330000, 1, 30000, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330001, 1, 30001, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330002, 1, 30002, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330003, 1, 30003, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330004, 1, 30004, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330005, 1, 30005, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330006, 1, 30006, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330007, 1, 30007, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330008, 1, 30008, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330101, 1, 30101, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330102, 1, 30102, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330103, 1, 30103, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330104, 1, 30104, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330111, 1, 30111, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330112, 1, 30112, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330113, 1, 30113, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330121, 1, 30121, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330122, 1, 30122, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330123, 1, 30123, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330131, 1, 30131, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330132, 1, 30132, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);
INSERT INTO public.system_role_menu VALUES (330133, 1, 30133, 'system', '2026-07-16 05:03:23.720981', 'system', '2026-07-16 05:03:23.720981', 0, 1);


--
-- Data for Name: system_sms_channel; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_sms_channel VALUES (2, 'Ballcat', 'ALIYUN', 0, '你要改哦，只有我可以用！！！！', 'enc:v1:REDACTED', 'enc:v1:REDACTED', NULL, '', '2021-03-31 11:53:10', '1', '2026-07-16 07:29:32.31865', 0);
INSERT INTO public.system_sms_channel VALUES (4, '测试渠道', 'DEBUG_DING_TALK', 0, '123', 'enc:v1:REDACTED', 'enc:v1:REDACTED', NULL, '1', '2021-04-13 00:23:14', '1', '2026-07-16 07:29:32.31865', 0);
INSERT INTO public.system_sms_channel VALUES (7, 'mock腾讯云', 'TENCENT', 0, '123', 'enc:v1:REDACTED', 'enc:v1:REDACTED', '', '1', '2024-09-30 08:53:45', '1', '2026-07-16 07:29:32.31865', 0);


--
-- Data for Name: system_sms_code; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_sms_log; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_sms_log VALUES (2, 4, 'DEBUG_DING_TALK', 2, 'test_01', 1, '正在进行登录操作login，您的验证码是1234', '{"code":"1234","operation":"login"}', '4383920', '13800138000', NULL, 2, 30, '2026-07-16 07:29:59.682171', 'NOT_CONFIGURED', 'sms provider is not configured', NULL, NULL, 0, NULL, NULL, NULL, 'admin', '2026-07-16 07:29:59.682171', 'admin', '2026-07-16 07:29:59.682171', 0);
INSERT INTO public.system_sms_log VALUES (3, 4, 'DEBUG_DING_TALK', 2, 'test_01', 1, '正在进行登录操作{operation}，您的验证码是123456', '{"code":"123456"}', '4383920', '13800138000', NULL, 2, 30, '2026-07-16 07:41:03.365878', 'NOT_CONFIGURED', 'sms provider is not configured', NULL, NULL, 0, NULL, NULL, NULL, 'admin', '2026-07-16 07:41:03.365878', 'admin', '2026-07-16 07:41:03.365878', 0);


--
-- Data for Name: system_sms_template; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_sms_template VALUES (2, 1, 0, 'test_01', '测试验证码短信', '正在进行登录操作{operation}，您的验证码是{code}', '["operation","code"]', '测试备注', '4383920', 4, 'DEBUG_DING_TALK', '', '2021-03-31 10:49:38', '1', '2024-08-18 11:57:18', 0);
INSERT INTO public.system_sms_template VALUES (3, 1, 0, 'test_02', '公告通知', '您的验证码{code}，该验证码5分钟内有效，请勿泄漏于他人！', '["code"]', NULL, 'SMS_207945135', 2, 'ALIYUN', '', '2021-03-31 11:56:30', '1', '2021-04-10 01:22:02', 0);
INSERT INTO public.system_sms_template VALUES (6, 3, 0, 'test-01', '测试模板', '哈哈哈 {name}', '["name"]', 'f哈哈哈', '4383920', 4, 'DEBUG_DING_TALK', '1', '2021-04-10 01:07:21', '1', '2024-08-18 11:57:07', 0);
INSERT INTO public.system_sms_template VALUES (7, 3, 0, 'test-04', '测试下', '老鸡{name}，牛逼{code}', '["name","code"]', '哈哈哈哈', 'suibian', 7, 'DEBUG_DING_TALK', '1', '2021-04-13 00:29:53', '1', '2024-09-30 00:56:24', 0);
INSERT INTO public.system_sms_template VALUES (8, 1, 0, 'user-sms-login', '前台用户短信登录', '您的验证码是{code}', '["code"]', NULL, '4372216', 4, 'DEBUG_DING_TALK', '1', '2021-10-11 08:10:00', '1', '2024-08-18 11:57:06', 0);
INSERT INTO public.system_sms_template VALUES (9, 2, 0, 'bpm_task_assigned', '【工作流】任务被分配', '您收到了一条新的待办任务：{processInstanceName}-{taskName}，申请人：{startUserNickname}，处理链接：{detailUrl}', '["processInstanceName","taskName","startUserNickname","detailUrl"]', NULL, 'suibian', 4, 'DEBUG_DING_TALK', '1', '2022-01-21 22:31:19', '1', '2022-01-22 00:03:36', 0);
INSERT INTO public.system_sms_template VALUES (10, 2, 0, 'bpm_process_instance_reject', '【工作流】流程被不通过', '您的流程被审批不通过：{processInstanceName}，原因：{reason}，查看链接：{detailUrl}', '["processInstanceName","reason","detailUrl"]', NULL, 'suibian', 4, 'DEBUG_DING_TALK', '1', '2022-01-22 00:03:31', '1', '2022-05-01 12:33:14', 0);
INSERT INTO public.system_sms_template VALUES (11, 2, 0, 'bpm_process_instance_approve', '【工作流】流程被通过', '您的流程被审批通过：{processInstanceName}，查看链接：{detailUrl}', '["processInstanceName","detailUrl"]', NULL, 'suibian', 4, 'DEBUG_DING_TALK', '1', '2022-01-22 00:04:31', '1', '2022-03-27 20:32:21', 0);
INSERT INTO public.system_sms_template VALUES (12, 2, 0, 'demo', '演示模板', '我就是测试一下下', '[]', NULL, 'biubiubiu', 4, 'DEBUG_DING_TALK', '1', '2022-04-10 23:22:49', '1', '2024-08-18 11:57:04', 0);
INSERT INTO public.system_sms_template VALUES (14, 1, 0, 'user-update-mobile', '会员用户 - 修改手机', '您的验证码{code}，该验证码 5 分钟内有效，请勿泄漏于他人！', '["code"]', '', 'null', 4, 'DEBUG_DING_TALK', '1', '2023-08-19 18:58:01', '1', '2023-08-19 11:34:04', 0);
INSERT INTO public.system_sms_template VALUES (15, 1, 0, 'user-update-password', '会员用户 - 修改密码', '您的验证码{code}，该验证码 5 分钟内有效，请勿泄漏于他人！', '["code"]', '', 'null', 4, 'DEBUG_DING_TALK', '1', '2023-08-19 18:58:01', '1', '2023-08-19 11:34:18', 0);
INSERT INTO public.system_sms_template VALUES (16, 1, 0, 'user-reset-password', '会员用户 - 重置密码', '您的验证码{code}，该验证码 5 分钟内有效，请勿泄漏于他人！', '["code"]', '', 'null', 4, 'DEBUG_DING_TALK', '1', '2023-08-19 18:58:01', '1', '2023-12-02 22:35:27', 0);
INSERT INTO public.system_sms_template VALUES (17, 2, 0, 'bpm_task_timeout', '【工作流】任务审批超时', '您收到了一条超时的待办任务：{processInstanceName}-{taskName}，处理链接：{detailUrl}', '["processInstanceName","taskName","detailUrl"]', '', 'X', 4, 'DEBUG_DING_TALK', '1', '2024-08-16 21:59:15', '1', '2024-08-16 21:59:34', 0);
INSERT INTO public.system_sms_template VALUES (18, 1, 0, 'admin-reset-password', '后台用户 - 忘记密码', '您的验证码{code}，该验证码 5 分钟内有效，请勿泄漏于他人！', '["code"]', '', 'null', 4, 'DEBUG_DING_TALK', '1', '2025-03-16 14:19:34', '1', '2025-03-16 14:19:45', 0);
INSERT INTO public.system_sms_template VALUES (19, 1, 0, 'admin-sms-login', '后台用户短信登录', '您的验证码是{code}', '["code"]', '', '4372216', 4, 'DEBUG_DING_TALK', '1', '2025-04-08 09:36:03', '1', '2025-04-08 09:36:17', 0);


--
-- Data for Name: system_social_client; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_social_client VALUES (1, '钉钉', 20, 2, 'dingvrnreaje3yqvzhxg', '', NULL, NULL, 0, '', '2023-10-18 11:21:18', '1', '2023-12-20 21:28:26', 1, 1);
INSERT INTO public.system_social_client VALUES (2, '钉钉（王土豆）', 20, 2, 'dingtsu9hpepjkbmthhw', '', NULL, NULL, 0, '', '2023-10-18 11:21:18', '', '2023-12-20 21:28:26', 1, 121);
INSERT INTO public.system_social_client VALUES (3, '微信公众号', 31, 1, 'wx5b23ba7a5589ecbb', '', NULL, NULL, 0, '', '2023-10-18 16:07:46', '1', '2023-12-20 21:28:23', 1, 1);
INSERT INTO public.system_social_client VALUES (43, '微信小程序', 34, 1, 'wx63c280fe3248a3e7', '', NULL, NULL, 0, '', '2023-10-19 13:37:41', '1', '2023-12-20 21:28:25', 1, 1);
INSERT INTO public.system_social_client VALUES (44, '1', 10, 1, '2', '', NULL, NULL, 0, '1', '2025-04-06 20:36:28', '1', '2025-04-06 20:43:12', 1, 1);
INSERT INTO public.system_social_client VALUES (45, '1', 10, 1, '2', '', NULL, NULL, 1, '1', '2025-09-06 20:26:15', '1', '2025-09-06 20:27:55', 1, 1);
INSERT INTO public.system_social_client VALUES (46, '1', 10, 1, '2', '', NULL, NULL, 0, '1', '2025-11-29 16:04:23', '1', '2025-11-29 16:04:26', 1, 1);
INSERT INTO public.system_social_client VALUES (47, '123', 10, 1, '1', '', '3', NULL, 0, '1', '2025-12-21 10:27:02', '1', '2025-12-21 10:27:20', 1, 1);


--
-- Data for Name: system_social_user; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_social_user_bind; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_tenant; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_tenant VALUES (1, '芋道源码', NULL, '芋艿', '17321315478', 0, 'www.iocoder.cn,127.0.0.1:3000,wxc4598c446f8a9cb3', 0, '2099-02-19 17:14:16', 9999, '1', '2021-01-05 17:03:47', '1', '2025-08-19 05:18:41', 0);
INSERT INTO public.system_tenant VALUES (121, '小租户', 110, '小王2', '15601691300', 0, 'zsxq.iocoder.cn,123321', 111, '2026-07-10 00:00:00', 30, '1', '2022-02-22 00:56:14', '1', '2025-08-19 21:19:29', 0);
INSERT INTO public.system_tenant VALUES (122, '测试租户', 113, '芋道', '15601691300', 0, 'test.iocoder.cn,222,333', 111, '2023-04-29 00:00:00', 50, '1', '2022-03-07 21:37:58', '1', '2025-12-21 09:50:00', 0);


--
-- Data for Name: system_tenant_package; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_tenant_package VALUES (111, '普通套餐', 0, '小功能', '[1,2,5,1031,1032,1033,1034,1035,1036,1037,1038,1039,1050,1051,1052,1053,1054,1056,1057,1058,1059,1060,1063,1064,1065,1066,1067,1070,1075,1077,1078,1082,1083,1084,1085,1086,1087,1088,1089,1090,1091,1092,1117,1118,1119,1120,100,101,102,1126,103,1127,1128,1129,106,1130,107,1132,1133,110,1134,111,1135,112,1136,113,1137,2161,114,1138,1139,115,1140,116,1141,1142,1143,1150,1161,1162,1166,1173,1174,2713,2714,1178,2715,2716,2717,2718,2720,2721,1185,2722,1186,1187,2723,1188,2724,1189,2725,1190,2726,1191,2727,1192,2728,2729,1193,1194,2730,1195,2731,2732,1197,2733,1198,2734,1199,2735,1200,1201,1202,2739,2740,1207,1208,1209,2745,1210,2746,1211,2747,1212,2748,1213,1215,1216,1217,1218,1219,1220,2756,1221,2757,1222,1224,1225,1226,1227,1228,1229,1237,1238,2262,1239,1240,1241,1242,1243,2275,2276,2277,1255,1256,1257,2281,1258,2282,1259,2283,1260,2284,2285,2287,2288,2293,2294,2297,2300,2301,2302,2317,2318,2319,2320,2321,2322,2323,2324,2325,2326,2327,2328,2329,2330,2331,2332,2333,2334,2335,2363,2364,5011,5012,2472,2478,2479,2480,2481,2482,2483,2484,2485,2486,2487,2488,2489,2490,2491,2492,2493,2494,2495,2497,2525,1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012,1013,2549,1014,2550,1015,2551,1016,2552,1017,2553,1018,2554,1019,2555,1020,2556,2557,2558,2559]', '1', '2022-02-22 00:54:00', '1', '2025-09-06 20:52:25', 0);


--
-- Data for Name: system_user_post; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_user_post VALUES (112, 1, 1, 'admin', '2022-05-02 07:25:24', 'admin', '2022-05-02 07:25:24', 0, 1);
INSERT INTO public.system_user_post VALUES (113, 100, 1, 'admin', '2022-05-02 07:25:24', 'admin', '2022-05-02 07:25:24', 0, 1);
INSERT INTO public.system_user_post VALUES (115, 104, 1, '1', '2022-05-16 19:36:28', '1', '2022-05-16 19:36:28', 0, 1);
INSERT INTO public.system_user_post VALUES (116, 117, 2, '1', '2022-07-09 17:40:26', '1', '2022-07-09 17:40:26', 0, 1);
INSERT INTO public.system_user_post VALUES (117, 118, 1, '1', '2022-07-09 17:44:44', '1', '2022-07-09 17:44:44', 0, 1);
INSERT INTO public.system_user_post VALUES (119, 114, 5, '1', '2024-03-24 20:45:51', '1', '2024-03-24 20:45:51', 0, 1);
INSERT INTO public.system_user_post VALUES (123, 115, 1, '1', '2024-04-04 09:37:14', '1', '2024-04-04 09:37:14', 0, 1);
INSERT INTO public.system_user_post VALUES (124, 115, 2, '1', '2024-04-04 09:37:14', '1', '2024-04-04 09:37:14', 0, 1);
INSERT INTO public.system_user_post VALUES (125, 1, 2, '1', '2024-07-13 22:31:39', '1', '2024-07-13 22:31:39', 0, 1);
INSERT INTO public.system_user_post VALUES (128, 139, 2, '1', '2025-12-05 21:43:27', '1', '2025-12-05 21:43:27', 0, 1);
INSERT INTO public.system_user_post VALUES (129, 139, 4, '1', '2025-12-05 21:43:27', '1', '2025-12-05 21:43:27', 0, 1);
INSERT INTO public.system_user_post VALUES (130, 104, 2, '', '2026-07-16 06:02:21.121236', '', '2026-07-16 06:02:21.121236', 0, 1);


--
-- Data for Name: system_user_role; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_user_role VALUES (1, 1, 1, '', '2022-01-11 13:19:45', '', '2022-05-12 12:35:17', 0, 1);
INSERT INTO public.system_user_role VALUES (2, 2, 2, '', '2022-01-11 13:19:45', '', '2022-05-12 12:35:13', 0, 1);
INSERT INTO public.system_user_role VALUES (5, 100, 1, '', '2022-01-11 13:19:45', '', '2022-05-12 12:35:12', 0, 1);
INSERT INTO public.system_user_role VALUES (6, 100, 2, '', '2022-01-11 13:19:45', '', '2022-05-12 12:35:11', 0, 1);
INSERT INTO public.system_user_role VALUES (10, 103, 1, '1', '2022-01-11 13:19:45', '1', '2022-01-11 13:19:45', 0, 1);
INSERT INTO public.system_user_role VALUES (14, 110, 109, '1', '2022-02-22 00:56:14', '1', '2022-02-22 00:56:14', 0, 121);
INSERT INTO public.system_user_role VALUES (15, 111, 110, '110', '2022-02-23 13:14:38', '110', '2022-02-23 13:14:38', 0, 121);
INSERT INTO public.system_user_role VALUES (16, 113, 111, '1', '2022-03-07 21:37:58', '1', '2022-03-07 21:37:58', 0, 122);
INSERT INTO public.system_user_role VALUES (18, 1, 2, '1', '2022-05-12 20:39:29', '1', '2022-05-12 20:39:29', 0, 1);
INSERT INTO public.system_user_role VALUES (22, 115, 2, '1', '2022-07-21 22:08:30', '1', '2022-07-21 22:08:30', 0, 1);
INSERT INTO public.system_user_role VALUES (35, 112, 1, '1', '2024-03-15 20:00:24', '1', '2024-03-15 20:00:24', 0, 1);
INSERT INTO public.system_user_role VALUES (36, 118, 1, '1', '2024-03-17 09:12:08', '1', '2024-03-17 09:12:08', 0, 1);
INSERT INTO public.system_user_role VALUES (46, 117, 1, '1', '2024-10-02 10:16:11', '1', '2024-10-02 10:16:11', 0, 1);
INSERT INTO public.system_user_role VALUES (47, 104, 2, '1', '2025-01-04 10:40:33', '1', '2025-01-04 10:40:33', 0, 1);
INSERT INTO public.system_user_role VALUES (48, 100, 155, '1', '2025-04-04 10:41:14', '1', '2025-04-04 10:41:14', 0, 1);
INSERT INTO public.system_user_role VALUES (49, 142, 1, '1', '2025-07-23 09:11:42', '1', '2025-07-23 09:11:42', 0, 1);
INSERT INTO public.system_user_role VALUES (50, 142, 2, '1', '2025-10-07 20:50:37', '1', '2025-10-07 20:50:37', 0, 1);
INSERT INTO public.system_user_role VALUES (51, 139, 1, '1', '2025-12-05 22:36:57', '1', '2025-12-05 22:36:57', 0, 1);
INSERT INTO public.system_user_role VALUES (52, 139, 2, '1', '2025-12-05 22:37:00', '1', '2025-12-05 22:37:00', 0, 1);
INSERT INTO public.system_user_role VALUES (53, 114, 2, '1', '2026-01-04 18:15:40', '1', '2026-01-04 18:15:40', 0, 1);
INSERT INTO public.system_user_role VALUES (54, 114, 3, '1', '2026-01-04 18:16:19', '1', '2026-01-04 18:16:19', 0, 1);


--
-- Data for Name: system_users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.system_users VALUES (107, 'admin107', '$2a$10$dYOOBKMO93v/.ReCqzyFg.o67Tqk.bbc2bhrpyBGkIw9aypCtr2pm', '芋艿', NULL, NULL, NULL, '', '15601691300', 0, NULL, 0, '', NULL, '1', '2022-02-20 22:59:33', '1', '2025-04-21 14:23:08', 0, 118);
INSERT INTO public.system_users VALUES (108, 'admin108', '$2a$10$y6mfvKoNYL1GXWak8nYwVOH.kCWqjactkzdoIDgiKl93WN3Ejg.Lu', '芋艿', NULL, NULL, NULL, '', '15601691300', 0, NULL, 0, '', NULL, '1', '2022-02-20 23:00:50', '1', '2025-04-21 14:23:08', 0, 119);
INSERT INTO public.system_users VALUES (109, 'admin109', '$2a$10$JAqvH0tEc0I7dfDVBI7zyuB4E3j.uH6daIjV53.vUS6PknFkDJkuK', '芋艿', NULL, NULL, NULL, '', '15601691300', 0, NULL, 0, '', NULL, '1', '2022-02-20 23:11:50', '1', '2025-04-21 14:23:08', 0, 120);
INSERT INTO public.system_users VALUES (115, 'aotemane', '$2a$04$GcyP0Vyzb2F2Yni5PuIK9ueGxM0tkZGMtDwVRwrNbtMvorzbpNsV2', '阿呆', '11222', 102, '[1,2]', '7648@qq.com', '15601691229', 2, NULL, 0, '', NULL, '1', '2022-04-30 02:55:43', '1', '2025-04-21 14:23:08', 0, 1);
INSERT INTO public.system_users VALUES (1, 'admin', '$2a$04$.vd8nPeLwxt6hnSzmAoAyul8BOLX7Cib6QhcxRe30rfvrIPQHH1OG', '芋道源码', '管理员', 103, '[1,2]', '13aoteman@126.com', '18818260272', 1, '', 0, '', NULL, 'admin', '2021-01-05 17:03:47', NULL, '2026-07-17 00:52:52.922132', 0, 1);
INSERT INTO public.system_users VALUES (103, 'yuanma', '$2a$04$fUBSmjKCPYAUmnMzOb6qE.eZCGPhHi1JmAKclODbfS/O7fHOl2bH6', '源码', NULL, 106, NULL, 'yuanma@iocoder.cn', '15601701300', 0, NULL, 0, '', NULL, '', '2021-01-13 23:50:35', '1', '2025-07-09 23:41:58', 0, 1);
INSERT INTO public.system_users VALUES (104, 'test', '$2a$04$BrwaYn303hjA/6TnXqdGoOLhyHOAA0bVrAFu6.1dJKycqKUnIoRz2', '测试号', NULL, 107, '[1,2]', '111@qq.com', '15601691200', 1, NULL, 0, '', NULL, '', '2021-01-21 02:13:53', NULL, '2026-01-04 18:09:54', 0, 1);
INSERT INTO public.system_users VALUES (112, 'newobject', '$2a$04$dB0z8Q819fJWz0hbaLe6B.VfHCjYgWx6LFfET5lyz3JwcqlyCkQ4C', '新对象', NULL, 100, '[]', '', '15601691235', 1, NULL, 0, '', NULL, '1', '2022-02-23 19:08:03', NULL, '2025-04-21 14:23:08', 0, 1);
INSERT INTO public.system_users VALUES (113, 'aoteman', '$2a$10$0acJOIk2D25/oC87nyclE..0lzeu9DtQ/n3geP4fkun/zIVRhHJIO', '芋道1', NULL, NULL, NULL, '', '15601691300', 0, NULL, 0, '', NULL, '1', '2022-03-07 21:37:58', '1', '2025-05-05 15:30:53', 0, 122);
INSERT INTO public.system_users VALUES (114, 'hrmgr', '$2a$10$TR4eybBioGRhBmDBWkqWLO6NIh3mzYa8KBKDDB5woiGYFVlRAi.fu', 'hr 小姐姐', NULL, NULL, '[5]', '', '15601691236', 1, NULL, 0, '', NULL, '1', '2022-03-19 21:50:58', NULL, '2026-01-04 18:16:01', 0, 1);
INSERT INTO public.system_users VALUES (117, 'admin123', '$2a$04$sEtimsHu9YCkYY4/oqElHem2Ijc9ld20eYO6lN.g/21NfLUTDLB9W', '测试号02', '1111', 100, '[2]', '', '15601691234', 1, NULL, 0, '', NULL, '1', '2022-07-09 17:40:26', '1', '2025-05-14 09:56:04', 0, 1);
INSERT INTO public.system_users VALUES (118, 'goudan', '$2a$04$3suGZjnA6rM5bErf38u1felbgqbsPHGdRG3l9NkxPCEt2ah9Y6aJi', '狗蛋', NULL, 103, '[1]', '', '15601691239', 1, NULL, 0, '', NULL, '1', '2022-07-09 17:44:43', NULL, '2025-11-23 15:28:25', 0, 1);
INSERT INTO public.system_users VALUES (139, 'wwbwwb', '$2a$04$FJLIyg8lbPytP29pbZaiU.LesJvCsYfEaHqQfB0pGQhK3e9BeZmLy', '小秃头', '123', 108, '[2,4]', '', '', 1, NULL, 0, '', NULL, NULL, '2024-09-10 21:03:58', '1', '2025-12-15 22:38:15', 0, 1);
INSERT INTO public.system_users VALUES (141, 'admin1', '$2a$04$oj6F6d7HrZ70kYVD3TNzEu.m3TPUzajOVuC66zdKna8KRerK1FmVa', '新用户', NULL, NULL, NULL, '', '', 0, '', 0, '', NULL, '1', '2025-04-08 13:09:07', '1', '2025-05-14 19:11:48', 0, 1);
INSERT INTO public.system_users VALUES (142, 'test01', '$2a$04$4bCYWZkjxxOC4QE0LY2M9uEEKWeJbLfs489NFtQoyidL5I0FndRaO', 'test01', '', NULL, '[]', '', '19021719925', 1, '', 0, '', NULL, '1', '2025-07-09 21:07:10', NULL, '2025-12-02 13:23:11', 0, 1);
INSERT INTO public.system_users VALUES (143, 'a00001', '$2a$04$GhVHFviOw/SsTmiQtifHJesDYFlHMeGK7OWh7aGCCjGGVCmbHVAwa', 'a00001', NULL, 104, NULL, '', '', 0, '', 0, '', NULL, NULL, '2025-12-01 16:10:13', '1', '2025-12-05 21:34:05', 0, 1);
INSERT INTO public.system_users VALUES (144, 'aoteman001', '$2a$04$omQOmhz8OyUFBKw77nr8KOtMp6xdvoQ1gWStjk9r8.OYT3Bv6oEYe', 'aoteman001', NULL, 116, NULL, '', '', 0, '', 1, '', NULL, '1', '2025-12-01 17:05:27', '1', '2025-12-15 15:55:54', 0, 1);
INSERT INTO public.system_users VALUES (110, 'admin110', '$2a$10$mRMIYLDtRHlf6.9ipiqH1.Z.bh/R9dO9d5iHiGYPigi6r5KOoR2Wm', '小王', NULL, NULL, NULL, '', '15601691300', 0, NULL, 0, '', NULL, '1', '2022-02-22 00:56:14', NULL, '2026-07-16 06:25:39.039366', 0, 121);
INSERT INTO public.system_users VALUES (100, 'yudao', '$2a$04$h.aaPKgO.odHepnk5PCsWeEwKdojFWdTItxGKfx1r0e1CSeBzsTJ6', '芋道', '不要吓我', 104, '[1]', 'yudao@iocoder.cn', '15601691300', 1, NULL, 0, '', NULL, '', '2021-01-07 09:07:17', NULL, '2026-07-16 05:30:28.709765', 0, 1);
INSERT INTO public.system_users VALUES (111, 'test', '$2a$10$mRMIYLDtRHlf6.9ipiqH1.Z.bh/R9dO9d5iHiGYPigi6r5KOoR2Wm', '测试用户', NULL, NULL, '[]', '', '', 0, NULL, 0, '', NULL, '110', '2022-02-23 13:14:33', NULL, '2026-07-16 06:12:57.86539', 0, 121);


--
-- Data for Name: yudao_demo01_contact; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: yudao_demo02_category; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: yudao_demo03_course; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: yudao_demo03_grade; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: yudao_demo03_student; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: episodes; Type: TABLE DATA; Schema: toon; Owner: -
--



--
-- Data for Name: projects; Type: TABLE DATA; Schema: toon; Owner: -
--



--
-- Data for Name: publications; Type: TABLE DATA; Schema: toon; Owner: -
--



--
-- Data for Name: scenes; Type: TABLE DATA; Schema: toon; Owner: -
--



--
-- Data for Name: agent_deployments; Type: TABLE DATA; Schema: toonflow; Owner: -
--

INSERT INTO toonflow.agent_deployments VALUES (1, 'scriptAgent', '用于读取原文生成故事骨架、改编策略，建议使用具备强大文本理解和生成能力的模型', '剧本Agent', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (2, 'productionAgent', '对工作流进行调度和管理，建议使用具备较强的逻辑推理和任务管理能力的模型', '生产Agent', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (3, 'universalAi', '用于小说事件提取、资产提示词生成、台词提取等边缘功能，建议使用具备较强文本处理能力的模型', '通用AI', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (4, 'ttsDubbing', '根据剧本内容生成角色配音，支持多种声音风格和情绪', 'TTS配音', 1, 0, true, NULL);
INSERT INTO toonflow.agent_deployments VALUES (5, 'scriptAgent:decisionAgent', '决策层', '剧本Agent:决策层', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (6, 'scriptAgent:supervisionAgent', '监督层', '剧本Agent:监督层', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (7, 'scriptAgent:storySkeletonAgent', '故事骨架生成', '剧本Agent:故事骨架', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (8, 'scriptAgent:adaptationStrategyAgent', '改编策略生成', '剧本Agent:改编策略', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (9, 'scriptAgent:scriptAgent', '剧本生成', '剧本Agent:剧本生成', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (10, 'productionAgent:decisionAgent', '决策层', '生产Agent:决策层', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (11, 'productionAgent:supervisionAgent', '监督层', '生产Agent:监督层', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (12, 'productionAgent:deriveAssetsAgent', '衍生资产', '生产Agent:衍生资产', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (13, 'productionAgent:generateAssetsAgent', '生成资产', '生产Agent:生成资产', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (14, 'productionAgent:directorPlanAgent', '导演规划', '生产Agent:导演规划', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (15, 'productionAgent:storyboardGenAgent', '分镜生成', '生产Agent:分镜生成', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (16, 'productionAgent:storyboardPanelAgent', '分镜面板生成', '生产Agent:分镜面板', 1, 0, false, NULL);
INSERT INTO toonflow.agent_deployments VALUES (17, 'productionAgent:storyboardTableAgent', '分镜表格生成', '生产Agent:分镜表格', 1, 0, false, NULL);


--
-- Data for Name: agent_memories; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: agent_run_events; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: agent_runs; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: agent_tool_calls; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: agent_work_data; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: art_styles; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: asset_audio_bindings; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: assets; Type: TABLE DATA; Schema: toonflow; Owner: -
--

INSERT INTO toonflow.assets VALUES (1784192560472, '烟测素材', '', NULL, 'clip', '', NULL, 1784192560473, NULL, 1784192560334, NULL, 1784192560472, NULL, NULL, NULL);


--
-- Data for Name: assets_storyboards; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: creative_manuals; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: event_chapters; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: events; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: image_flows; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: images; Type: TABLE DATA; Schema: toonflow; Owner: -
--

INSERT INTO toonflow.images VALUES (1784192560473, '/upload/toonflow/1784192560334/assets/1784192560472_2f840a35-6ab6-4b8b-873b-f3c7f34ea491.png', 'clip', 1784192560472, NULL, NULL, '已完成', NULL);


--
-- Data for Name: novels; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: projects; Type: TABLE DATA; Schema: toonflow; Owner: -
--

INSERT INTO toonflow.projects VALUES (1784192560334, 'series', NULL, '1024x1024', NULL, '材料接口烟测', '', '', '', '', 'text', '16:9', 'fdf9b377-c8a9-96ce-6366-fbbf85faff12', 1784192560334, 1784192560334);


--
-- Data for Name: prompts; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: script_assets; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: scripts; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: settings; Type: TABLE DATA; Schema: toonflow; Owner: -
--

INSERT INTO toonflow.settings VALUES ('messagesPerSummary', '10');
INSERT INTO toonflow.settings VALUES ('shortTermLimit', '5');
INSERT INTO toonflow.settings VALUES ('summaryMaxLength', '500');
INSERT INTO toonflow.settings VALUES ('summaryLimit', '10');
INSERT INTO toonflow.settings VALUES ('ragLimit', '3');
INSERT INTO toonflow.settings VALUES ('deepRetrieveSummaryLimit', '5');
INSERT INTO toonflow.settings VALUES ('modelOnnxFile', '["all-MiniLM-L6-v2", "onnx", "model_fp16.onnx"]');
INSERT INTO toonflow.settings VALUES ('modelDtype', 'fp16');
INSERT INTO toonflow.settings VALUES ('switchAiDevTool', '0');


--
-- Data for Name: skill_list; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: storyboards; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: tasks; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: video_tracks; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Data for Name: videos; Type: TABLE DATA; Schema: toonflow; Owner: -
--



--
-- Name: infra_api_access_log_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.infra_api_access_log_seq', 1, false);


--
-- Name: infra_api_error_log_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.infra_api_error_log_seq', 1, false);


--
-- Name: infra_codegen_column_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.infra_codegen_column_seq', 26, true);


--
-- Name: infra_codegen_table_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.infra_codegen_table_seq', 1, true);


--
-- Name: infra_config_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.infra_config_seq', 2, true);


--
-- Name: infra_data_source_config_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.infra_data_source_config_seq', 2, true);


--
-- Name: infra_file_config_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.infra_file_config_seq', 3, true);


--
-- Name: infra_file_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.infra_file_seq', 3, true);


--
-- Name: infra_job_log_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.infra_job_log_seq', 2, true);


--
-- Name: infra_job_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.infra_job_seq', 3, true);


--
-- Name: system_dept_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_dept_seq', 118, true);


--
-- Name: system_dict_data_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_dict_data_seq', 3449, true);


--
-- Name: system_dict_type_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_dict_type_seq', 2139, true);


--
-- Name: system_login_log_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_login_log_seq', 111, true);


--
-- Name: system_mail_account_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_mail_account_seq', 5, true);


--
-- Name: system_mail_log_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_mail_log_seq', 3, true);


--
-- Name: system_mail_template_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_mail_template_seq', 16, true);


--
-- Name: system_menu_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_menu_seq', 30133, true);


--
-- Name: system_notice_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_notice_seq', 5, true);


--
-- Name: system_notify_message_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_notify_message_seq', 12, true);


--
-- Name: system_notify_template_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_notify_template_seq', 2, true);


--
-- Name: system_oauth2_access_token_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_oauth2_access_token_seq', 150, true);


--
-- Name: system_oauth2_approve_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_oauth2_approve_seq', 1, true);


--
-- Name: system_oauth2_client_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_oauth2_client_seq', 43, true);


--
-- Name: system_oauth2_code_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_oauth2_code_seq', 1, true);


--
-- Name: system_oauth2_refresh_token_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_oauth2_refresh_token_seq', 134, true);


--
-- Name: system_operate_log_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_operate_log_seq', 36, true);


--
-- Name: system_post_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_post_seq', 8, true);


--
-- Name: system_role_menu_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_role_menu_seq', 330133, true);


--
-- Name: system_role_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_role_seq', 156, true);


--
-- Name: system_sms_channel_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_sms_channel_seq', 8, true);


--
-- Name: system_sms_code_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_sms_code_seq', 1, true);


--
-- Name: system_sms_log_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_sms_log_seq', 3, true);


--
-- Name: system_sms_template_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_sms_template_seq', 20, true);


--
-- Name: system_social_client_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_social_client_seq', 48, true);


--
-- Name: system_social_user_bind_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_social_user_bind_seq', 1, true);


--
-- Name: system_social_user_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_social_user_seq', 1, true);


--
-- Name: system_tenant_package_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_tenant_package_seq', 112, true);


--
-- Name: system_tenant_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_tenant_seq', 123, true);


--
-- Name: system_user_post_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_user_post_seq', 132, true);


--
-- Name: system_user_role_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_user_role_seq', 57, true);


--
-- Name: system_users_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.system_users_seq', 146, true);


--
-- Name: yudao_demo01_contact_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.yudao_demo01_contact_seq', 1, false);


--
-- Name: yudao_demo02_category_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.yudao_demo02_category_seq', 1, false);


--
-- Name: yudao_demo03_course_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.yudao_demo03_course_seq', 1, false);


--
-- Name: yudao_demo03_grade_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.yudao_demo03_grade_seq', 1, false);


--
-- Name: yudao_demo03_student_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.yudao_demo03_student_seq', 1, false);


--
-- Name: agent_deployments_id_seq; Type: SEQUENCE SET; Schema: toonflow; Owner: -
--

SELECT pg_catalog.setval('toonflow.agent_deployments_id_seq', 17, true);


--
-- Name: agent_run_events_id_seq; Type: SEQUENCE SET; Schema: toonflow; Owner: -
--

SELECT pg_catalog.setval('toonflow.agent_run_events_id_seq', 1, false);


--
-- Name: agent_work_data_id_seq; Type: SEQUENCE SET; Schema: toonflow; Owner: -
--

SELECT pg_catalog.setval('toonflow.agent_work_data_id_seq', 3, true);


--
-- Name: creative_manuals_id_seq; Type: SEQUENCE SET; Schema: toonflow; Owner: -
--

SELECT pg_catalog.setval('toonflow.creative_manuals_id_seq', 1, false);


--
-- Name: event_chapters_id_seq; Type: SEQUENCE SET; Schema: toonflow; Owner: -
--

SELECT pg_catalog.setval('toonflow.event_chapters_id_seq', 1, false);


--
-- Name: prompts_id_seq; Type: SEQUENCE SET; Schema: toonflow; Owner: -
--

SELECT pg_catalog.setval('toonflow.prompts_id_seq', 1, false);


--
-- Name: chat_conversations chat_conversations_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.chat_conversations
    ADD CONSTRAINT chat_conversations_pkey PRIMARY KEY (id);


--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- Name: chat_roles chat_roles_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.chat_roles
    ADD CONSTRAINT chat_roles_pkey PRIMARY KEY (id);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: knowledge_bases knowledge_bases_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.knowledge_bases
    ADD CONSTRAINT knowledge_bases_pkey PRIMARY KEY (id);


--
-- Name: knowledge_documents knowledge_documents_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.knowledge_documents
    ADD CONSTRAINT knowledge_documents_pkey PRIMARY KEY (id);


--
-- Name: knowledge_segments knowledge_segments_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.knowledge_segments
    ADD CONSTRAINT knowledge_segments_pkey PRIMARY KEY (id);


--
-- Name: model_catalog model_catalog_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.model_catalog
    ADD CONSTRAINT model_catalog_pkey PRIMARY KEY (platform, model);


--
-- Name: model_configs model_configs_key_key; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.model_configs
    ADD CONSTRAINT model_configs_key_key UNIQUE (key);


--
-- Name: model_configs model_configs_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.model_configs
    ADD CONSTRAINT model_configs_pkey PRIMARY KEY (id);


--
-- Name: model_platforms model_platforms_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.model_platforms
    ADD CONSTRAINT model_platforms_pkey PRIMARY KEY (platform);


--
-- Name: music music_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.music
    ADD CONSTRAINT music_pkey PRIMARY KEY (id);


--
-- Name: tools tools_name_key; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.tools
    ADD CONSTRAINT tools_name_key UNIQUE (name);


--
-- Name: tools tools_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.tools
    ADD CONSTRAINT tools_pkey PRIMARY KEY (id);


--
-- Name: writes writes_pkey; Type: CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.writes
    ADD CONSTRAINT writes_pkey PRIMARY KEY (id);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: media; Owner: -
--

ALTER TABLE ONLY media.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: _sqlx_migrations _sqlx_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public._sqlx_migrations
    ADD CONSTRAINT _sqlx_migrations_pkey PRIMARY KEY (version);


--
-- Name: infra_api_access_log infra_api_access_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.infra_api_access_log
    ADD CONSTRAINT infra_api_access_log_pkey PRIMARY KEY (id);


--
-- Name: infra_api_error_log infra_api_error_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.infra_api_error_log
    ADD CONSTRAINT infra_api_error_log_pkey PRIMARY KEY (id);


--
-- Name: infra_codegen_column infra_codegen_column_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.infra_codegen_column
    ADD CONSTRAINT infra_codegen_column_pkey PRIMARY KEY (id);


--
-- Name: infra_codegen_table infra_codegen_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.infra_codegen_table
    ADD CONSTRAINT infra_codegen_table_pkey PRIMARY KEY (id);


--
-- Name: infra_config infra_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.infra_config
    ADD CONSTRAINT infra_config_pkey PRIMARY KEY (id);


--
-- Name: infra_data_source_config infra_data_source_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.infra_data_source_config
    ADD CONSTRAINT infra_data_source_config_pkey PRIMARY KEY (id);


--
-- Name: infra_file_config infra_file_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.infra_file_config
    ADD CONSTRAINT infra_file_config_pkey PRIMARY KEY (id);


--
-- Name: infra_file infra_file_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.infra_file
    ADD CONSTRAINT infra_file_pkey PRIMARY KEY (id);


--
-- Name: infra_job_log infra_job_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.infra_job_log
    ADD CONSTRAINT infra_job_log_pkey PRIMARY KEY (id);


--
-- Name: infra_job infra_job_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.infra_job
    ADD CONSTRAINT infra_job_pkey PRIMARY KEY (id);


--
-- Name: system_dept pk_system_dept; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_dept
    ADD CONSTRAINT pk_system_dept PRIMARY KEY (id);


--
-- Name: system_dict_data pk_system_dict_data; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_dict_data
    ADD CONSTRAINT pk_system_dict_data PRIMARY KEY (id);


--
-- Name: system_dict_type pk_system_dict_type; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_dict_type
    ADD CONSTRAINT pk_system_dict_type PRIMARY KEY (id);


--
-- Name: system_login_log pk_system_login_log; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_login_log
    ADD CONSTRAINT pk_system_login_log PRIMARY KEY (id);


--
-- Name: system_mail_account pk_system_mail_account; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_mail_account
    ADD CONSTRAINT pk_system_mail_account PRIMARY KEY (id);


--
-- Name: system_mail_log pk_system_mail_log; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_mail_log
    ADD CONSTRAINT pk_system_mail_log PRIMARY KEY (id);


--
-- Name: system_mail_template pk_system_mail_template; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_mail_template
    ADD CONSTRAINT pk_system_mail_template PRIMARY KEY (id);


--
-- Name: system_menu pk_system_menu; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_menu
    ADD CONSTRAINT pk_system_menu PRIMARY KEY (id);


--
-- Name: system_notice pk_system_notice; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_notice
    ADD CONSTRAINT pk_system_notice PRIMARY KEY (id);


--
-- Name: system_notify_message pk_system_notify_message; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_notify_message
    ADD CONSTRAINT pk_system_notify_message PRIMARY KEY (id);


--
-- Name: system_notify_template pk_system_notify_template; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_notify_template
    ADD CONSTRAINT pk_system_notify_template PRIMARY KEY (id);


--
-- Name: system_oauth2_access_token pk_system_oauth2_access_token; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_oauth2_access_token
    ADD CONSTRAINT pk_system_oauth2_access_token PRIMARY KEY (id);


--
-- Name: system_oauth2_approve pk_system_oauth2_approve; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_oauth2_approve
    ADD CONSTRAINT pk_system_oauth2_approve PRIMARY KEY (id);


--
-- Name: system_oauth2_client pk_system_oauth2_client; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_oauth2_client
    ADD CONSTRAINT pk_system_oauth2_client PRIMARY KEY (id);


--
-- Name: system_oauth2_code pk_system_oauth2_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_oauth2_code
    ADD CONSTRAINT pk_system_oauth2_code PRIMARY KEY (id);


--
-- Name: system_oauth2_refresh_token pk_system_oauth2_refresh_token; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_oauth2_refresh_token
    ADD CONSTRAINT pk_system_oauth2_refresh_token PRIMARY KEY (id);


--
-- Name: system_operate_log pk_system_operate_log; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_operate_log
    ADD CONSTRAINT pk_system_operate_log PRIMARY KEY (id);


--
-- Name: system_post pk_system_post; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_post
    ADD CONSTRAINT pk_system_post PRIMARY KEY (id);


--
-- Name: system_role pk_system_role; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_role
    ADD CONSTRAINT pk_system_role PRIMARY KEY (id);


--
-- Name: system_role_menu pk_system_role_menu; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_role_menu
    ADD CONSTRAINT pk_system_role_menu PRIMARY KEY (id);


--
-- Name: system_sms_channel pk_system_sms_channel; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_sms_channel
    ADD CONSTRAINT pk_system_sms_channel PRIMARY KEY (id);


--
-- Name: system_sms_code pk_system_sms_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_sms_code
    ADD CONSTRAINT pk_system_sms_code PRIMARY KEY (id);


--
-- Name: system_sms_log pk_system_sms_log; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_sms_log
    ADD CONSTRAINT pk_system_sms_log PRIMARY KEY (id);


--
-- Name: system_sms_template pk_system_sms_template; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_sms_template
    ADD CONSTRAINT pk_system_sms_template PRIMARY KEY (id);


--
-- Name: system_social_client pk_system_social_client; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_social_client
    ADD CONSTRAINT pk_system_social_client PRIMARY KEY (id);


--
-- Name: system_social_user pk_system_social_user; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_social_user
    ADD CONSTRAINT pk_system_social_user PRIMARY KEY (id);


--
-- Name: system_social_user_bind pk_system_social_user_bind; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_social_user_bind
    ADD CONSTRAINT pk_system_social_user_bind PRIMARY KEY (id);


--
-- Name: system_tenant pk_system_tenant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_tenant
    ADD CONSTRAINT pk_system_tenant PRIMARY KEY (id);


--
-- Name: system_tenant_package pk_system_tenant_package; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_tenant_package
    ADD CONSTRAINT pk_system_tenant_package PRIMARY KEY (id);


--
-- Name: system_user_post pk_system_user_post; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_user_post
    ADD CONSTRAINT pk_system_user_post PRIMARY KEY (id);


--
-- Name: system_user_role pk_system_user_role; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_user_role
    ADD CONSTRAINT pk_system_user_role PRIMARY KEY (id);


--
-- Name: system_users pk_system_users; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_users
    ADD CONSTRAINT pk_system_users PRIMARY KEY (id);


--
-- Name: yudao_demo01_contact yudao_demo01_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.yudao_demo01_contact
    ADD CONSTRAINT yudao_demo01_contact_pkey PRIMARY KEY (id);


--
-- Name: yudao_demo02_category yudao_demo02_category_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.yudao_demo02_category
    ADD CONSTRAINT yudao_demo02_category_pkey PRIMARY KEY (id);


--
-- Name: yudao_demo03_course yudao_demo03_course_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.yudao_demo03_course
    ADD CONSTRAINT yudao_demo03_course_pkey PRIMARY KEY (id);


--
-- Name: yudao_demo03_grade yudao_demo03_grade_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.yudao_demo03_grade
    ADD CONSTRAINT yudao_demo03_grade_pkey PRIMARY KEY (id);


--
-- Name: yudao_demo03_student yudao_demo03_student_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.yudao_demo03_student
    ADD CONSTRAINT yudao_demo03_student_pkey PRIMARY KEY (id);


--
-- Name: episodes episodes_pkey; Type: CONSTRAINT; Schema: toon; Owner: -
--

ALTER TABLE ONLY toon.episodes
    ADD CONSTRAINT episodes_pkey PRIMARY KEY (id);


--
-- Name: episodes episodes_project_id_episode_no_key; Type: CONSTRAINT; Schema: toon; Owner: -
--

ALTER TABLE ONLY toon.episodes
    ADD CONSTRAINT episodes_project_id_episode_no_key UNIQUE (project_id, episode_no);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: toon; Owner: -
--

ALTER TABLE ONLY toon.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: publications publications_pkey; Type: CONSTRAINT; Schema: toon; Owner: -
--

ALTER TABLE ONLY toon.publications
    ADD CONSTRAINT publications_pkey PRIMARY KEY (id);


--
-- Name: scenes scenes_episode_id_scene_no_key; Type: CONSTRAINT; Schema: toon; Owner: -
--

ALTER TABLE ONLY toon.scenes
    ADD CONSTRAINT scenes_episode_id_scene_no_key UNIQUE (episode_id, scene_no);


--
-- Name: scenes scenes_pkey; Type: CONSTRAINT; Schema: toon; Owner: -
--

ALTER TABLE ONLY toon.scenes
    ADD CONSTRAINT scenes_pkey PRIMARY KEY (id);


--
-- Name: agent_deployments agent_deployments_key_key; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_deployments
    ADD CONSTRAINT agent_deployments_key_key UNIQUE (key);


--
-- Name: agent_deployments agent_deployments_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_deployments
    ADD CONSTRAINT agent_deployments_pkey PRIMARY KEY (id);


--
-- Name: agent_memories agent_memories_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_memories
    ADD CONSTRAINT agent_memories_pkey PRIMARY KEY (id);


--
-- Name: agent_run_events agent_run_events_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_run_events
    ADD CONSTRAINT agent_run_events_pkey PRIMARY KEY (id);


--
-- Name: agent_runs agent_runs_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_runs
    ADD CONSTRAINT agent_runs_pkey PRIMARY KEY (id);


--
-- Name: agent_tool_calls agent_tool_calls_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_tool_calls
    ADD CONSTRAINT agent_tool_calls_pkey PRIMARY KEY (id);


--
-- Name: agent_work_data agent_work_data_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_work_data
    ADD CONSTRAINT agent_work_data_pkey PRIMARY KEY (id);


--
-- Name: agent_work_data agent_work_data_project_id_episodes_id_key_key; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_work_data
    ADD CONSTRAINT agent_work_data_project_id_episodes_id_key_key UNIQUE (project_id, episodes_id, key);


--
-- Name: art_styles art_styles_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.art_styles
    ADD CONSTRAINT art_styles_pkey PRIMARY KEY (id);


--
-- Name: asset_audio_bindings asset_audio_bindings_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.asset_audio_bindings
    ADD CONSTRAINT asset_audio_bindings_pkey PRIMARY KEY (asset_role_id, asset_audio_id);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: assets_storyboards assets_storyboards_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.assets_storyboards
    ADD CONSTRAINT assets_storyboards_pkey PRIMARY KEY (storyboard_id, asset_id);


--
-- Name: creative_manuals creative_manuals_kind_path_key; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.creative_manuals
    ADD CONSTRAINT creative_manuals_kind_path_key UNIQUE (kind, path);


--
-- Name: creative_manuals creative_manuals_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.creative_manuals
    ADD CONSTRAINT creative_manuals_pkey PRIMARY KEY (id);


--
-- Name: event_chapters event_chapters_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.event_chapters
    ADD CONSTRAINT event_chapters_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: image_flows image_flows_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.image_flows
    ADD CONSTRAINT image_flows_pkey PRIMARY KEY (id);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: novels novels_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.novels
    ADD CONSTRAINT novels_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: prompts prompts_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.prompts
    ADD CONSTRAINT prompts_pkey PRIMARY KEY (id);


--
-- Name: script_assets script_assets_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.script_assets
    ADD CONSTRAINT script_assets_pkey PRIMARY KEY (script_id, asset_id);


--
-- Name: scripts scripts_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.scripts
    ADD CONSTRAINT scripts_pkey PRIMARY KEY (id);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (key);


--
-- Name: skill_list skill_list_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.skill_list
    ADD CONSTRAINT skill_list_pkey PRIMARY KEY (id);


--
-- Name: storyboards storyboards_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.storyboards
    ADD CONSTRAINT storyboards_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: video_tracks video_tracks_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.video_tracks
    ADD CONSTRAINT video_tracks_pkey PRIMARY KEY (id);


--
-- Name: videos videos_pkey; Type: CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.videos
    ADD CONSTRAINT videos_pkey PRIMARY KEY (id);


--
-- Name: idx_ai_chat_conversation_knowledge_ids; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_chat_conversation_knowledge_ids ON ai.chat_conversations USING gin (knowledge_ids);


--
-- Name: idx_ai_chat_conversation_user; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_chat_conversation_user ON ai.chat_conversations USING btree (user_id, pinned DESC, update_time DESC);


--
-- Name: idx_ai_chat_message_conversation; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_chat_message_conversation ON ai.chat_messages USING btree (conversation_id, id);


--
-- Name: idx_ai_chat_roles_public; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_chat_roles_public ON ai.chat_roles USING btree (public_status, status, sort, id DESC);


--
-- Name: idx_ai_chat_roles_user; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_chat_roles_user ON ai.chat_roles USING btree (user_id, id DESC);


--
-- Name: idx_ai_images_pending_task; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_images_pending_task ON ai.images USING btree (COALESCE(last_poll_time, (0)::bigint), id) WHERE ((status = 10) AND (task_id IS NOT NULL));


--
-- Name: idx_ai_images_user; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_images_user ON ai.images USING btree (user_id, id DESC);


--
-- Name: idx_ai_knowledge_segment_base; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_knowledge_segment_base ON ai.knowledge_segments USING btree (knowledge_id, status);


--
-- Name: idx_ai_model_catalog_type; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_model_catalog_type ON ai.model_catalog USING btree (platform, type, active);


--
-- Name: idx_ai_model_platform_type; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_model_platform_type ON ai.model_configs USING btree (platform, type, status);


--
-- Name: idx_ai_music_pending; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_music_pending ON ai.music USING btree (status, last_poll_time) WHERE (status = 10);


--
-- Name: idx_ai_music_user_status; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_music_user_status ON ai.music USING btree (user_id, status, id DESC);


--
-- Name: idx_ai_tools_status_name; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_tools_status_name ON ai.tools USING btree (status, name);


--
-- Name: idx_ai_writes_user_time; Type: INDEX; Schema: ai; Owner: -
--

CREATE INDEX idx_ai_writes_user_time ON ai.writes USING btree (user_id, id DESC);


--
-- Name: idx_media_assets_owner; Type: INDEX; Schema: media; Owner: -
--

CREATE INDEX idx_media_assets_owner ON media.assets USING btree (owner_user_id);


--
-- Name: idx_infra_api_access_log_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_infra_api_access_log_time ON public.infra_api_access_log USING btree (create_time DESC) WHERE (deleted = 0);


--
-- Name: idx_infra_api_error_log_status_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_infra_api_error_log_status_time ON public.infra_api_error_log USING btree (process_status, create_time DESC) WHERE (deleted = 0);


--
-- Name: idx_infra_codegen_column_table; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_infra_codegen_column_table ON public.infra_codegen_column USING btree (table_id, ordinal_position, id) WHERE (deleted = 0);


--
-- Name: idx_infra_job_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_infra_job_active ON public.infra_job USING btree (status, id) WHERE (deleted = 0);


--
-- Name: idx_infra_job_log_job_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_infra_job_log_job_time ON public.infra_job_log USING btree (job_id, create_time DESC) WHERE (deleted = 0);


--
-- Name: idx_system_login_log_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_login_log_01 ON public.system_login_log USING btree (username);


--
-- Name: idx_system_login_log_02; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_login_log_02 ON public.system_login_log USING btree (create_time);


--
-- Name: idx_system_menu_tree_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_menu_tree_active ON public.system_menu USING btree (parent_id, sort, id) WHERE ((deleted = 0) AND (status = 0));


--
-- Name: idx_system_notify_message_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_notify_message_01 ON public.system_notify_message USING btree (user_id, user_type, read_status);


--
-- Name: idx_system_oauth2_access_token_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_oauth2_access_token_01 ON public.system_oauth2_access_token USING btree (md5(access_token));


--
-- Name: idx_system_oauth2_access_token_02; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_oauth2_access_token_02 ON public.system_oauth2_access_token USING btree (refresh_token);


--
-- Name: idx_system_oauth2_access_token_active_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_oauth2_access_token_active_user ON public.system_oauth2_access_token USING btree (user_id, deleted, expires_time);


--
-- Name: idx_system_oauth2_approve_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_oauth2_approve_01 ON public.system_oauth2_approve USING btree (user_id, user_type, client_id);


--
-- Name: idx_system_oauth2_client_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_oauth2_client_01 ON public.system_oauth2_client USING btree (client_id);


--
-- Name: idx_system_oauth2_code_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_oauth2_code_01 ON public.system_oauth2_code USING btree (code);


--
-- Name: idx_system_oauth2_refresh_token_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_oauth2_refresh_token_01 ON public.system_oauth2_refresh_token USING btree (refresh_token);


--
-- Name: idx_system_operate_log_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_operate_log_01 ON public.system_operate_log USING btree (user_id);


--
-- Name: idx_system_operate_log_02; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_operate_log_02 ON public.system_operate_log USING btree (create_time);


--
-- Name: idx_system_role_menu_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_role_menu_01 ON public.system_role_menu USING btree (role_id);


--
-- Name: idx_system_role_menu_active_menu; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_role_menu_active_menu ON public.system_role_menu USING btree (menu_id, role_id) WHERE (deleted = 0);


--
-- Name: idx_system_role_tenant_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_role_tenant_active ON public.system_role USING btree (tenant_id, status, id) WHERE (deleted = 0);


--
-- Name: idx_system_sms_code_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_sms_code_01 ON public.system_sms_code USING btree (mobile);


--
-- Name: idx_system_social_user_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_social_user_01 ON public.system_social_user USING btree (type, openid);


--
-- Name: idx_system_social_user_02; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_social_user_02 ON public.system_social_user USING btree (type, code, state);


--
-- Name: idx_system_social_user_bind_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_social_user_bind_01 ON public.system_social_user_bind USING btree (user_type, social_user_id);


--
-- Name: idx_system_user_role_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_user_role_01 ON public.system_user_role USING btree (user_id);


--
-- Name: idx_system_user_role_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_user_role_role ON public.system_user_role USING btree (role_id, user_id) WHERE (deleted = 0);


--
-- Name: idx_system_users_01; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_users_01 ON public.system_users USING btree (username);


--
-- Name: idx_system_users_02; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_users_02 ON public.system_users USING btree (mobile);


--
-- Name: idx_system_users_03; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_users_03 ON public.system_users USING btree (email);


--
-- Name: idx_system_users_04; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_users_04 ON public.system_users USING btree (dept_id);


--
-- Name: idx_episodes_project; Type: INDEX; Schema: toon; Owner: -
--

CREATE INDEX idx_episodes_project ON toon.episodes USING btree (project_id);


--
-- Name: idx_publications_project; Type: INDEX; Schema: toon; Owner: -
--

CREATE INDEX idx_publications_project ON toon.publications USING btree (project_id);


--
-- Name: idx_scenes_episode; Type: INDEX; Schema: toon; Owner: -
--

CREATE INDEX idx_scenes_episode ON toon.scenes USING btree (episode_id);


--
-- Name: idx_toonflow_agent_memories_session; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_agent_memories_session ON toonflow.agent_memories USING btree (agent_type, isolation_key, create_time DESC);


--
-- Name: idx_toonflow_agent_model_config; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_agent_model_config ON toonflow.agent_deployments USING btree (model_config_id);


--
-- Name: idx_toonflow_agent_run_events_cursor; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_agent_run_events_cursor ON toonflow.agent_run_events USING btree (run_id, id);


--
-- Name: idx_toonflow_agent_runs_session; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_agent_runs_session ON toonflow.agent_runs USING btree (agent_type, isolation_key, start_time DESC);


--
-- Name: idx_toonflow_assets_project; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_assets_project ON toonflow.assets USING btree (project_id);


--
-- Name: idx_toonflow_assets_project_type; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_assets_project_type ON toonflow.assets USING btree (project_id, type, id DESC);


--
-- Name: idx_toonflow_audio_binding_audio; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_audio_binding_audio ON toonflow.asset_audio_bindings USING btree (asset_audio_id);


--
-- Name: idx_toonflow_novels_project; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_novels_project ON toonflow.novels USING btree (project_id, chapter_index);


--
-- Name: idx_toonflow_projects_user; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_projects_user ON toonflow.projects USING btree (user_id);


--
-- Name: idx_toonflow_scripts_project; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_scripts_project ON toonflow.scripts USING btree (project_id);


--
-- Name: idx_toonflow_storyboards_script; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_storyboards_script ON toonflow.storyboards USING btree (script_id, index);


--
-- Name: idx_toonflow_tasks_project; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_tasks_project ON toonflow.tasks USING btree (project_id);


--
-- Name: idx_toonflow_tasks_state_time; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_tasks_state_time ON toonflow.tasks USING btree (state, start_time DESC, id DESC);


--
-- Name: idx_toonflow_video_tracks_order; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE INDEX idx_toonflow_video_tracks_order ON toonflow.video_tracks USING btree (project_id, script_id, sort_order, id);


--
-- Name: uq_toonflow_agent_project_data; Type: INDEX; Schema: toonflow; Owner: -
--

CREATE UNIQUE INDEX uq_toonflow_agent_project_data ON toonflow.agent_work_data USING btree (project_id, key) WHERE (episodes_id IS NULL);


--
-- Name: chat_conversations chat_conversations_model_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.chat_conversations
    ADD CONSTRAINT chat_conversations_model_id_fkey FOREIGN KEY (model_id) REFERENCES ai.model_configs(id);


--
-- Name: chat_messages chat_messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.chat_messages
    ADD CONSTRAINT chat_messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES ai.chat_conversations(id) ON DELETE CASCADE;


--
-- Name: chat_messages chat_messages_model_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.chat_messages
    ADD CONSTRAINT chat_messages_model_id_fkey FOREIGN KEY (model_id) REFERENCES ai.model_configs(id);


--
-- Name: chat_roles chat_roles_model_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.chat_roles
    ADD CONSTRAINT chat_roles_model_id_fkey FOREIGN KEY (model_id) REFERENCES ai.model_configs(id);


--
-- Name: images images_model_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.images
    ADD CONSTRAINT images_model_id_fkey FOREIGN KEY (model_id) REFERENCES ai.model_configs(id);


--
-- Name: images images_parent_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.images
    ADD CONSTRAINT images_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES ai.images(id) ON DELETE SET NULL;


--
-- Name: knowledge_bases knowledge_bases_embedding_model_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.knowledge_bases
    ADD CONSTRAINT knowledge_bases_embedding_model_id_fkey FOREIGN KEY (embedding_model_id) REFERENCES ai.model_configs(id);


--
-- Name: knowledge_documents knowledge_documents_knowledge_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.knowledge_documents
    ADD CONSTRAINT knowledge_documents_knowledge_id_fkey FOREIGN KEY (knowledge_id) REFERENCES ai.knowledge_bases(id) ON DELETE CASCADE;


--
-- Name: knowledge_segments knowledge_segments_document_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.knowledge_segments
    ADD CONSTRAINT knowledge_segments_document_id_fkey FOREIGN KEY (document_id) REFERENCES ai.knowledge_documents(id) ON DELETE CASCADE;


--
-- Name: knowledge_segments knowledge_segments_knowledge_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.knowledge_segments
    ADD CONSTRAINT knowledge_segments_knowledge_id_fkey FOREIGN KEY (knowledge_id) REFERENCES ai.knowledge_bases(id) ON DELETE CASCADE;


--
-- Name: model_catalog model_catalog_platform_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.model_catalog
    ADD CONSTRAINT model_catalog_platform_fkey FOREIGN KEY (platform) REFERENCES ai.model_platforms(platform) ON DELETE CASCADE;


--
-- Name: music music_model_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.music
    ADD CONSTRAINT music_model_id_fkey FOREIGN KEY (model_id) REFERENCES ai.model_configs(id);


--
-- Name: writes writes_model_id_fkey; Type: FK CONSTRAINT; Schema: ai; Owner: -
--

ALTER TABLE ONLY ai.writes
    ADD CONSTRAINT writes_model_id_fkey FOREIGN KEY (model_id) REFERENCES ai.model_configs(id);


--
-- Name: episodes episodes_project_id_fkey; Type: FK CONSTRAINT; Schema: toon; Owner: -
--

ALTER TABLE ONLY toon.episodes
    ADD CONSTRAINT episodes_project_id_fkey FOREIGN KEY (project_id) REFERENCES toon.projects(id) ON DELETE CASCADE;


--
-- Name: publications publications_project_id_fkey; Type: FK CONSTRAINT; Schema: toon; Owner: -
--

ALTER TABLE ONLY toon.publications
    ADD CONSTRAINT publications_project_id_fkey FOREIGN KEY (project_id) REFERENCES toon.projects(id) ON DELETE CASCADE;


--
-- Name: scenes scenes_episode_id_fkey; Type: FK CONSTRAINT; Schema: toon; Owner: -
--

ALTER TABLE ONLY toon.scenes
    ADD CONSTRAINT scenes_episode_id_fkey FOREIGN KEY (episode_id) REFERENCES toon.episodes(id) ON DELETE CASCADE;


--
-- Name: agent_deployments agent_deployments_model_config_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_deployments
    ADD CONSTRAINT agent_deployments_model_config_id_fkey FOREIGN KEY (model_config_id) REFERENCES ai.model_configs(id) ON DELETE SET NULL;


--
-- Name: agent_run_events agent_run_events_run_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_run_events
    ADD CONSTRAINT agent_run_events_run_id_fkey FOREIGN KEY (run_id) REFERENCES toonflow.agent_runs(id) ON DELETE CASCADE;


--
-- Name: agent_runs agent_runs_project_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_runs
    ADD CONSTRAINT agent_runs_project_id_fkey FOREIGN KEY (project_id) REFERENCES toonflow.projects(id) ON DELETE CASCADE;


--
-- Name: agent_runs agent_runs_script_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_runs
    ADD CONSTRAINT agent_runs_script_id_fkey FOREIGN KEY (script_id) REFERENCES toonflow.scripts(id) ON DELETE CASCADE;


--
-- Name: agent_tool_calls agent_tool_calls_run_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_tool_calls
    ADD CONSTRAINT agent_tool_calls_run_id_fkey FOREIGN KEY (run_id) REFERENCES toonflow.agent_runs(id) ON DELETE CASCADE;


--
-- Name: agent_work_data agent_work_data_episodes_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_work_data
    ADD CONSTRAINT agent_work_data_episodes_id_fkey FOREIGN KEY (episodes_id) REFERENCES toonflow.scripts(id) ON DELETE CASCADE;


--
-- Name: agent_work_data agent_work_data_project_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.agent_work_data
    ADD CONSTRAINT agent_work_data_project_id_fkey FOREIGN KEY (project_id) REFERENCES toonflow.projects(id) ON DELETE CASCADE;


--
-- Name: asset_audio_bindings asset_audio_bindings_asset_audio_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.asset_audio_bindings
    ADD CONSTRAINT asset_audio_bindings_asset_audio_id_fkey FOREIGN KEY (asset_audio_id) REFERENCES toonflow.assets(id) ON DELETE CASCADE;


--
-- Name: asset_audio_bindings asset_audio_bindings_asset_role_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.asset_audio_bindings
    ADD CONSTRAINT asset_audio_bindings_asset_role_id_fkey FOREIGN KEY (asset_role_id) REFERENCES toonflow.assets(id) ON DELETE CASCADE;


--
-- Name: assets assets_project_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.assets
    ADD CONSTRAINT assets_project_id_fkey FOREIGN KEY (project_id) REFERENCES toonflow.projects(id) ON DELETE CASCADE;


--
-- Name: assets_storyboards assets_storyboards_asset_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.assets_storyboards
    ADD CONSTRAINT assets_storyboards_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES toonflow.assets(id) ON DELETE CASCADE;


--
-- Name: assets_storyboards assets_storyboards_storyboard_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.assets_storyboards
    ADD CONSTRAINT assets_storyboards_storyboard_id_fkey FOREIGN KEY (storyboard_id) REFERENCES toonflow.storyboards(id) ON DELETE CASCADE;


--
-- Name: event_chapters event_chapters_event_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.event_chapters
    ADD CONSTRAINT event_chapters_event_id_fkey FOREIGN KEY (event_id) REFERENCES toonflow.events(id) ON DELETE CASCADE;


--
-- Name: event_chapters event_chapters_novel_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.event_chapters
    ADD CONSTRAINT event_chapters_novel_id_fkey FOREIGN KEY (novel_id) REFERENCES toonflow.novels(id) ON DELETE CASCADE;


--
-- Name: assets fk_toonflow_assets_image; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.assets
    ADD CONSTRAINT fk_toonflow_assets_image FOREIGN KEY (image_id) REFERENCES toonflow.images(id) ON DELETE SET NULL;


--
-- Name: projects fk_toonflow_project_image_model; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.projects
    ADD CONSTRAINT fk_toonflow_project_image_model FOREIGN KEY (image_model) REFERENCES ai.model_configs(id);


--
-- Name: projects fk_toonflow_project_video_model; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.projects
    ADD CONSTRAINT fk_toonflow_project_video_model FOREIGN KEY (video_model) REFERENCES ai.model_configs(id);


--
-- Name: images images_assets_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.images
    ADD CONSTRAINT images_assets_id_fkey FOREIGN KEY (assets_id) REFERENCES toonflow.assets(id) ON DELETE CASCADE;


--
-- Name: novels novels_project_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.novels
    ADD CONSTRAINT novels_project_id_fkey FOREIGN KEY (project_id) REFERENCES toonflow.projects(id) ON DELETE CASCADE;


--
-- Name: script_assets script_assets_asset_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.script_assets
    ADD CONSTRAINT script_assets_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES toonflow.assets(id) ON DELETE CASCADE;


--
-- Name: script_assets script_assets_script_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.script_assets
    ADD CONSTRAINT script_assets_script_id_fkey FOREIGN KEY (script_id) REFERENCES toonflow.scripts(id) ON DELETE CASCADE;


--
-- Name: scripts scripts_project_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.scripts
    ADD CONSTRAINT scripts_project_id_fkey FOREIGN KEY (project_id) REFERENCES toonflow.projects(id) ON DELETE CASCADE;


--
-- Name: storyboards storyboards_flow_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.storyboards
    ADD CONSTRAINT storyboards_flow_id_fkey FOREIGN KEY (flow_id) REFERENCES toonflow.image_flows(id) ON DELETE SET NULL;


--
-- Name: storyboards storyboards_project_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.storyboards
    ADD CONSTRAINT storyboards_project_id_fkey FOREIGN KEY (project_id) REFERENCES toonflow.projects(id) ON DELETE CASCADE;


--
-- Name: storyboards storyboards_script_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.storyboards
    ADD CONSTRAINT storyboards_script_id_fkey FOREIGN KEY (script_id) REFERENCES toonflow.scripts(id) ON DELETE CASCADE;


--
-- Name: storyboards storyboards_track_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.storyboards
    ADD CONSTRAINT storyboards_track_id_fkey FOREIGN KEY (track_id) REFERENCES toonflow.video_tracks(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_project_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.tasks
    ADD CONSTRAINT tasks_project_id_fkey FOREIGN KEY (project_id) REFERENCES toonflow.projects(id) ON DELETE CASCADE;


--
-- Name: video_tracks video_tracks_project_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.video_tracks
    ADD CONSTRAINT video_tracks_project_id_fkey FOREIGN KEY (project_id) REFERENCES toonflow.projects(id) ON DELETE CASCADE;


--
-- Name: video_tracks video_tracks_script_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.video_tracks
    ADD CONSTRAINT video_tracks_script_id_fkey FOREIGN KEY (script_id) REFERENCES toonflow.scripts(id) ON DELETE CASCADE;


--
-- Name: videos videos_project_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.videos
    ADD CONSTRAINT videos_project_id_fkey FOREIGN KEY (project_id) REFERENCES toonflow.projects(id) ON DELETE CASCADE;


--
-- Name: videos videos_script_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.videos
    ADD CONSTRAINT videos_script_id_fkey FOREIGN KEY (script_id) REFERENCES toonflow.scripts(id) ON DELETE CASCADE;


--
-- Name: videos videos_video_track_id_fkey; Type: FK CONSTRAINT; Schema: toonflow; Owner: -
--

ALTER TABLE ONLY toonflow.videos
    ADD CONSTRAINT videos_video_track_id_fkey FOREIGN KEY (video_track_id) REFERENCES toonflow.video_tracks(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

-- pg_dump clears search_path for restore safety. Restore the application
-- default because the gateway uses unqualified Yudao table names.
SELECT pg_catalog.set_config('search_path', 'public', false);
