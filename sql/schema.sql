--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.6
-- Dumped by pg_dump version 9.6.6

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
-- Name: state; Type: TYPE; Schema: public; Owner: vlna
--

CREATE TYPE state AS ENUM (
    'draft',
    'pending',
    'sent'
);


ALTER TYPE state OWNER TO vlna;

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

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: channel; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE channel (
    id bigint DEFAULT nextval('channel_id_seq'::regclass) NOT NULL,
    name character varying NOT NULL,
    public boolean NOT NULL,
    template character varying NOT NULL
);


ALTER TABLE channel OWNER TO vlna;

--
-- Name: user; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE "user" (
    name character varying NOT NULL,
    email character varying NOT NULL,
    display_name character varying NOT NULL
);


ALTER TABLE "user" OWNER TO vlna;

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
    name character varying NOT NULL,
    author character varying,
    channel bigint NOT NULL,
    state state DEFAULT 'draft'::state NOT NULL,
    start timestamp with time zone NOT NULL,
    content text NOT NULL
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
-- Name: group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE "group" (
    name character varying NOT NULL,
    label character varying NOT NULL
);


ALTER TABLE "group" OWNER TO vlna;

--
-- Name: member; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE member (
    "user" character varying NOT NULL,
    "group" character varying NOT NULL
);


ALTER TABLE member OWNER TO vlna;

--
-- Name: recipient_group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE recipient_group (
    "group" character varying NOT NULL,
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
-- Name: opt_in; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE opt_in (
    "user" character varying NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE opt_in OWNER TO vlna;

--
-- Name: opt_out; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE opt_out (
    "user" character varying NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE opt_out OWNER TO vlna;

--
-- Name: recipients; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW recipients AS
 SELECT b."user",
    b.email,
    b.display_name,
    b.channel,
    b.name,
    b.public,
    (oi."user" IS NOT NULL) AS opt_in,
    (gr."user" IS NOT NULL) AS "group",
    (ou."user" IS NOT NULL) AS opt_out,
    ((b.public AND (oi."user" IS NOT NULL)) OR ((gr."user" IS NOT NULL) AND (ou."user" IS NULL))) AS active
   FROM (((base b
     LEFT JOIN opt_in oi ON ((((oi."user")::text = (b."user")::text) AND (oi.channel = b.channel))))
     LEFT JOIN group_recipients gr ON ((((gr."user")::text = (b."user")::text) AND (gr.channel = b.channel))))
     LEFT JOIN opt_out ou ON ((((ou."user")::text = (b."user")::text) AND (ou.channel = b.channel))))
  WHERE (b.public OR (gr."user" IS NOT NULL));


ALTER TABLE recipients OWNER TO vlna;

--
-- Name: sender_group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE sender_group (
    "group" character varying NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE sender_group OWNER TO vlna;

--
-- Name: senders; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW senders AS
 SELECT DISTINCT u.name AS "user",
    u.email,
    u.display_name,
    sg.channel,
    c.name,
    c.public
   FROM ((("user" u
     JOIN member m ON (((m."user")::text = (u.name)::text)))
     JOIN sender_group sg ON (((sg."group")::text = (m."group")::text)))
     JOIN channel c ON ((c.id = sg.channel)));


ALTER TABLE senders OWNER TO vlna;

--
-- Name: campaign id; Type: DEFAULT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY campaign ALTER COLUMN id SET DEFAULT nextval('campaign_id_seq'::regclass);


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
-- Name: user user_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY "user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (name);


--
-- Name: channel_public_idx; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX channel_public_idx ON channel USING btree (public);


--
-- Name: fki_campaign_author_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_campaign_author_fkey ON campaign USING btree (author);


--
-- Name: fki_campaign_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_campaign_channel_fkey ON campaign USING btree (channel);


--
-- Name: fki_member_group_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_member_group_fkey ON member USING btree ("group");


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
-- Name: campaign campaign_author_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY campaign
    ADD CONSTRAINT campaign_author_fkey FOREIGN KEY (author) REFERENCES "user"(name) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: campaign campaign_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY campaign
    ADD CONSTRAINT campaign_channel_fkey FOREIGN KEY (channel) REFERENCES channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


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
-- Name: public; Type: ACL; Schema: -; Owner: vlna
--

GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

