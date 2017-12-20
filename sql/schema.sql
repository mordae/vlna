--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.5
-- Dumped by pg_dump version 9.6.5

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

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: campaign; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE campaign (
    id bigint NOT NULL,
    name character varying NOT NULL,
    author character varying,
    channel character varying NOT NULL,
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
-- Name: channel; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE channel (
    name character varying NOT NULL,
    public boolean NOT NULL,
    template character varying NOT NULL
);


ALTER TABLE channel OWNER TO vlna;

--
-- Name: group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE "group" (
    name character varying NOT NULL
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
-- Name: opt_in; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE opt_in (
    "user" character varying NOT NULL,
    channel character varying NOT NULL
);


ALTER TABLE opt_in OWNER TO vlna;

--
-- Name: opt_out; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE opt_out (
    "user" character varying NOT NULL,
    channel character varying NOT NULL
);


ALTER TABLE opt_out OWNER TO vlna;

--
-- Name: recipient_group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE recipient_group (
    "group" character varying NOT NULL,
    channel character varying NOT NULL
);


ALTER TABLE recipient_group OWNER TO vlna;

--
-- Name: sender_group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE sender_group (
    "group" character varying NOT NULL,
    channel character varying NOT NULL
);


ALTER TABLE sender_group OWNER TO vlna;

--
-- Name: user; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE "user" (
    login character varying NOT NULL,
    email character varying NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE "user" OWNER TO vlna;

--
-- Name: subscription; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW subscription AS
 WITH base AS (
         SELECT u.login AS "user",
            c.name AS channel,
            c.public
           FROM "user" u,
            channel c
        ), group_subs AS (
         SELECT DISTINCT m."user",
            rg.channel
           FROM (member m
             JOIN recipient_group rg ON (((rg."group")::text = (m."group")::text)))
        )
 SELECT b."user",
    b.channel,
    b.public,
    (i."user" IS NOT NULL) AS opt_in,
    (g."user" IS NOT NULL) AS "group",
    (o."user" IS NOT NULL) AS opt_out
   FROM (((base b
     LEFT JOIN opt_in i ON ((((i."user")::text = (b."user")::text) AND ((i.channel)::text = (b.channel)::text))))
     LEFT JOIN group_subs g ON ((((g."user")::text = (b."user")::text) AND ((g.channel)::text = (b.channel)::text))))
     LEFT JOIN opt_out o ON ((((o."user")::text = (b."user")::text) AND ((o.channel)::text = (b.channel)::text))))
  WHERE (b.public OR (g."user" IS NOT NULL));


ALTER TABLE subscription OWNER TO vlna;

--
-- Name: VIEW subscription; Type: COMMENT; Schema: public; Owner: vlna
--

COMMENT ON VIEW subscription IS 'TODO: Inefficient, rewrite using joins only.';


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
    ADD CONSTRAINT channel_pkey PRIMARY KEY (name);


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
    ADD CONSTRAINT user_pkey PRIMARY KEY (login);


--
-- Name: campaign campaign_author_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY campaign
    ADD CONSTRAINT campaign_author_fkey FOREIGN KEY (author) REFERENCES "user"(login) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: campaign campaign_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY campaign
    ADD CONSTRAINT campaign_channel_fkey FOREIGN KEY (channel) REFERENCES channel(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: member member_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY member
    ADD CONSTRAINT member_group_fkey FOREIGN KEY ("group") REFERENCES "group"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: member member_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY member
    ADD CONSTRAINT member_user_fkey FOREIGN KEY ("user") REFERENCES "user"(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_in opt_in_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY opt_in
    ADD CONSTRAINT opt_in_channel_fkey FOREIGN KEY (channel) REFERENCES channel(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_in opt_in_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY opt_in
    ADD CONSTRAINT opt_in_user_fkey FOREIGN KEY ("user") REFERENCES "user"(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_out opt_out_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY opt_out
    ADD CONSTRAINT opt_out_channel_fkey FOREIGN KEY (channel) REFERENCES "group"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_out opt_out_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY opt_out
    ADD CONSTRAINT opt_out_user_fkey FOREIGN KEY ("user") REFERENCES "user"(login) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: recipient_group recipient_group_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY recipient_group
    ADD CONSTRAINT recipient_group_channel_fkey FOREIGN KEY (channel) REFERENCES channel(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: recipient_group recipient_group_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY recipient_group
    ADD CONSTRAINT recipient_group_group_fkey FOREIGN KEY ("group") REFERENCES "group"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sender_group sender_group_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY sender_group
    ADD CONSTRAINT sender_group_channel_fkey FOREIGN KEY (channel) REFERENCES channel(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sender_group sender_group_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY sender_group
    ADD CONSTRAINT sender_group_group_fkey FOREIGN KEY ("group") REFERENCES "group"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: vlna
--

REVOKE ALL ON SCHEMA public FROM postgres;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO vlna;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

