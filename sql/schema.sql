--
-- PostgreSQL database dump
--

-- Dumped from database version 10.1
-- Dumped by pg_dump version 10.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: und-x-icu; Type: COLLATION; Schema: public; Owner: vlna
--

CREATE COLLATION "und-x-icu" (provider = icu, locale = 'und-x-icu');


ALTER COLLATION "und-x-icu" OWNER TO vlna;

--
-- Name: campaign_state; Type: TYPE; Schema: public; Owner: vlna
--

CREATE TYPE campaign_state AS ENUM (
    'draft',
    'sent'
);


ALTER TYPE campaign_state OWNER TO vlna;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: user; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE "user" (
    name character varying COLLATE public."und-x-icu" NOT NULL,
    email character varying COLLATE public."und-x-icu" NOT NULL,
    display_name character varying COLLATE public."und-x-icu" NOT NULL
);


ALTER TABLE "user" OWNER TO vlna;

--
-- Name: clear_user(); Type: FUNCTION; Schema: public; Owner: vlna
--

CREATE FUNCTION clear_user() RETURNS void
    LANGUAGE sql
    AS $$
drop function if exists pg_temp.get_user();
$$;


ALTER FUNCTION public.clear_user() OWNER TO vlna;

--
-- Name: get_user(); Type: FUNCTION; Schema: public; Owner: vlna
--

CREATE FUNCTION get_user() RETURNS SETOF "user"
    LANGUAGE plpgsql
    AS $$
begin
   return query select * from pg_temp.get_user();
exception when others then
end;
$$;


ALTER FUNCTION public.get_user() OWNER TO vlna;

--
-- Name: set_user(character varying); Type: FUNCTION; Schema: public; Owner: vlna
--

CREATE FUNCTION set_user(name character varying) RETURNS void
    LANGUAGE plpgsql
    AS $_$begin
    execute format($$
        drop function if exists pg_temp.get_user();
        create function pg_temp.get_user() returns setof "user" as $fn$
            select * from "user" where "name" = %L;
        $fn$ language sql;
    $$, $1);
end;

$_$;


ALTER FUNCTION public.set_user(name character varying) OWNER TO vlna;

--
-- Name: channel_id_seq; Type: SEQUENCE; Schema: public; Owner: vlna
--

CREATE SEQUENCE channel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE channel_id_seq OWNER TO vlna;

--
-- Name: channel; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE channel (
    id bigint DEFAULT nextval('channel_id_seq'::regclass) NOT NULL,
    name character varying COLLATE public."und-x-icu" NOT NULL,
    public boolean NOT NULL,
    template character varying COLLATE public."und-x-icu" NOT NULL
);


ALTER TABLE channel OWNER TO vlna;

--
-- Name: base; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW base AS
 SELECT u.name AS "user",
    u.email,
    u.display_name,
    c.id AS channel,
    c.name,
    c.public
   FROM "user" u,
    channel c;


ALTER TABLE base OWNER TO vlna;

--
-- Name: campaign; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE campaign (
    id bigint NOT NULL,
    subject character varying COLLATE public."und-x-icu" NOT NULL,
    channel bigint NOT NULL,
    state campaign_state DEFAULT 'draft'::campaign_state NOT NULL,
    content text COLLATE public."und-x-icu" NOT NULL
);


ALTER TABLE campaign OWNER TO vlna;

--
-- Name: campaign_id_seq; Type: SEQUENCE; Schema: public; Owner: vlna
--

CREATE SEQUENCE campaign_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE campaign_id_seq OWNER TO vlna;

--
-- Name: campaign_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vlna
--

ALTER SEQUENCE campaign_id_seq OWNED BY campaign.id;


--
-- Name: event; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE event (
    id bigint NOT NULL,
    evid character varying COLLATE public."und-x-icu" NOT NULL,
    ts timestamp with time zone NOT NULL,
    event character varying COLLATE public."und-x-icu" NOT NULL,
    message bigint NOT NULL,
    "user" character varying COLLATE public."und-x-icu"
);


ALTER TABLE event OWNER TO vlna;

--
-- Name: event_id_seq; Type: SEQUENCE; Schema: public; Owner: vlna
--

CREATE SEQUENCE event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE event_id_seq OWNER TO vlna;

--
-- Name: event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vlna
--

ALTER SEQUENCE event_id_seq OWNED BY event.id;


--
-- Name: group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE "group" (
    name character varying COLLATE public."und-x-icu" NOT NULL,
    label character varying COLLATE public."und-x-icu" NOT NULL
);


ALTER TABLE "group" OWNER TO vlna;

--
-- Name: member; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE member (
    "user" character varying COLLATE public."und-x-icu" NOT NULL,
    "group" character varying COLLATE public."und-x-icu" NOT NULL
);


ALTER TABLE member OWNER TO vlna;

--
-- Name: recipient_group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE recipient_group (
    "group" character varying COLLATE public."und-x-icu" NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE recipient_group OWNER TO vlna;

--
-- Name: group_recipients; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW group_recipients AS
 SELECT DISTINCT u.name AS "user",
    rg.channel
   FROM (("user" u
     JOIN member m ON (((m."user")::text = (u.name)::text)))
     JOIN recipient_group rg ON (((rg."group")::text = (m."group")::text)));


ALTER TABLE group_recipients OWNER TO vlna;

--
-- Name: message; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE message (
    id bigint NOT NULL,
    msgid character varying COLLATE public."und-x-icu" NOT NULL,
    campaign bigint NOT NULL
);


ALTER TABLE message OWNER TO vlna;

--
-- Name: message_id_seq; Type: SEQUENCE; Schema: public; Owner: vlna
--

CREATE SEQUENCE message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE message_id_seq OWNER TO vlna;

--
-- Name: message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vlna
--

ALTER SEQUENCE message_id_seq OWNED BY message.id;


--
-- Name: sender_group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE sender_group (
    "group" character varying COLLATE public."und-x-icu" NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE sender_group OWNER TO vlna;

--
-- Name: my_channels; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW my_channels AS
 SELECT DISTINCT c.id,
    c.name,
    c.public,
    c.template
   FROM (((get_user() u(name, email, display_name)
     JOIN member m ON (((m."user")::text = (u.name)::text)))
     JOIN sender_group sg ON (((sg."group")::text = (m."group")::text)))
     JOIN channel c ON ((c.id = sg.channel)))
  ORDER BY c.id;


ALTER TABLE my_channels OWNER TO vlna;

--
-- Name: my_campaigns; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW my_campaigns AS
 SELECT ca.id,
    ca.subject,
    ca.channel,
    ca.state,
    ca.content
   FROM (campaign ca
     JOIN my_channels ch ON ((ch.id = ca.channel)));


ALTER TABLE my_campaigns OWNER TO vlna;

--
-- Name: opt_in; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE opt_in (
    "user" character varying COLLATE public."und-x-icu" NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE opt_in OWNER TO vlna;

--
-- Name: opt_out; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE opt_out (
    "user" character varying COLLATE public."und-x-icu" NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE opt_out OWNER TO vlna;

--
-- Name: my_subscriptions; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW my_subscriptions AS
 SELECT c.id,
    c.name,
    c.public,
    c.template,
    (oi."user" IS NOT NULL) AS opt_in,
    (gr."user" IS NOT NULL) AS "group",
    (ou."user" IS NOT NULL) AS opt_out,
    ((c.public AND (oi."user" IS NOT NULL)) OR ((gr."user" IS NOT NULL) AND (ou."user" IS NULL))) AS active
   FROM ((((channel c
     JOIN get_user() u(name, email, display_name) ON ((1 = 1)))
     LEFT JOIN opt_in oi ON ((((oi."user")::text = (u.name)::text) AND (oi.channel = c.id))))
     LEFT JOIN group_recipients gr ON ((((gr."user")::text = (u.name)::text) AND (gr.channel = c.id))))
     LEFT JOIN opt_out ou ON ((((ou."user")::text = (u.name)::text) AND (ou.channel = c.id))))
  WHERE (c.public OR (gr."user" IS NOT NULL))
  ORDER BY c.id;


ALTER TABLE my_subscriptions OWNER TO vlna;

--
-- Name: template; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE template (
    name character varying COLLATE public."und-x-icu" NOT NULL,
    body text COLLATE public."und-x-icu" NOT NULL
);


ALTER TABLE template OWNER TO vlna;

--
-- Name: campaign id; Type: DEFAULT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY campaign ALTER COLUMN id SET DEFAULT nextval('campaign_id_seq'::regclass);


--
-- Name: event id; Type: DEFAULT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY event ALTER COLUMN id SET DEFAULT nextval('event_id_seq'::regclass);


--
-- Name: message id; Type: DEFAULT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY message ALTER COLUMN id SET DEFAULT nextval('message_id_seq'::regclass);


--
-- Name: campaign campaign_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY campaign
    ADD CONSTRAINT campaign_pkey PRIMARY KEY (id);


--
-- Name: channel channel_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY channel
    ADD CONSTRAINT channel_pkey PRIMARY KEY (id);


--
-- Name: event event_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_pkey PRIMARY KEY (id);


--
-- Name: group group_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY "group"
    ADD CONSTRAINT group_pkey PRIMARY KEY (name);


--
-- Name: member member_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY member
    ADD CONSTRAINT member_pkey PRIMARY KEY ("user", "group");


--
-- Name: message message_msgid_key; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY message
    ADD CONSTRAINT message_msgid_key UNIQUE (msgid);


--
-- Name: message message_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);


--
-- Name: opt_in opt_in_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY opt_in
    ADD CONSTRAINT opt_in_pkey PRIMARY KEY ("user", channel);


--
-- Name: opt_out opt_out_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY opt_out
    ADD CONSTRAINT opt_out_pkey PRIMARY KEY ("user", channel);


--
-- Name: recipient_group recipient_group_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY recipient_group
    ADD CONSTRAINT recipient_group_pkey PRIMARY KEY ("group", channel);


--
-- Name: sender_group sender_group_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY sender_group
    ADD CONSTRAINT sender_group_pkey PRIMARY KEY ("group", channel);


--
-- Name: template template_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY template
    ADD CONSTRAINT template_pkey PRIMARY KEY (name);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY "user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (name);


--
-- Name: channel_public_idx; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX channel_public_idx ON channel USING btree (public);


--
-- Name: fki_campaign_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_campaign_channel_fkey ON campaign USING btree (channel);


--
-- Name: fki_channel_template_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_channel_template_fkey ON channel USING btree (template);


--
-- Name: fki_event_message_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_event_message_fkey ON event USING btree (message);


--
-- Name: fki_event_user_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_event_user_fkey ON event USING btree ("user");


--
-- Name: fki_member_group_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_member_group_fkey ON member USING btree ("group");


--
-- Name: fki_message_campaign_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_message_campaign_fkey ON message USING btree (campaign);


--
-- Name: fki_opt_in_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_opt_in_channel_fkey ON opt_in USING btree (channel);


--
-- Name: fki_opt_out_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_opt_out_channel_fkey ON opt_out USING btree (channel);


--
-- Name: fki_recipient_group_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_recipient_group_channel_fkey ON recipient_group USING btree (channel);


--
-- Name: fki_sender_group_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_sender_group_channel_fkey ON sender_group USING btree (channel);


--
-- Name: campaign campaign_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY campaign
    ADD CONSTRAINT campaign_channel_fkey FOREIGN KEY (channel) REFERENCES channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: channel channel_template_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY channel
    ADD CONSTRAINT channel_template_fkey FOREIGN KEY (template) REFERENCES template(name) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: event event_message_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_message_fkey FOREIGN KEY (message) REFERENCES message(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: event event_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_user_fkey FOREIGN KEY ("user") REFERENCES "user"(name) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: member member_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY member
    ADD CONSTRAINT member_group_fkey FOREIGN KEY ("group") REFERENCES "group"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: member member_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY member
    ADD CONSTRAINT member_user_fkey FOREIGN KEY ("user") REFERENCES "user"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: message message_campaign_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY message
    ADD CONSTRAINT message_campaign_fkey FOREIGN KEY (campaign) REFERENCES campaign(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_in opt_in_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY opt_in
    ADD CONSTRAINT opt_in_channel_fkey FOREIGN KEY (channel) REFERENCES channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_in opt_in_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY opt_in
    ADD CONSTRAINT opt_in_user_fkey FOREIGN KEY ("user") REFERENCES "user"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_out opt_out_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY opt_out
    ADD CONSTRAINT opt_out_channel_fkey FOREIGN KEY (channel) REFERENCES channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_out opt_out_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY opt_out
    ADD CONSTRAINT opt_out_user_fkey FOREIGN KEY ("user") REFERENCES "user"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: recipient_group recipient_group_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY recipient_group
    ADD CONSTRAINT recipient_group_channel_fkey FOREIGN KEY (channel) REFERENCES channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: recipient_group recipient_group_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY recipient_group
    ADD CONSTRAINT recipient_group_group_fkey FOREIGN KEY ("group") REFERENCES "group"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sender_group sender_group_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY sender_group
    ADD CONSTRAINT sender_group_channel_fkey FOREIGN KEY (channel) REFERENCES channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sender_group sender_group_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY sender_group
    ADD CONSTRAINT sender_group_group_fkey FOREIGN KEY ("group") REFERENCES "group"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

