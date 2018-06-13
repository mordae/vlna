--
-- PostgreSQL database dump
--

-- Dumped from database version 10.4
-- Dumped by pg_dump version 10.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
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


--
-- Name: campaign_state; Type: TYPE; Schema: public; Owner: vlna
--

CREATE TYPE public.campaign_state AS ENUM (
    'draft',
    'sent'
);


ALTER TYPE public.campaign_state OWNER TO vlna;

--
-- Name: clear_user(); Type: FUNCTION; Schema: public; Owner: vlna
--

CREATE FUNCTION public.clear_user() RETURNS void
    LANGUAGE sql
    AS $$
drop function if exists pg_temp.get_user();
$$;


ALTER FUNCTION public.clear_user() OWNER TO vlna;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: user; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public."user" (
    name character varying NOT NULL,
    email character varying NOT NULL,
    display_name character varying NOT NULL
);


ALTER TABLE public."user" OWNER TO vlna;

--
-- Name: get_user(); Type: FUNCTION; Schema: public; Owner: vlna
--

CREATE FUNCTION public.get_user() RETURNS SETOF public."user"
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

CREATE FUNCTION public.set_user(name character varying) RETURNS void
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

CREATE SEQUENCE public.channel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.channel_id_seq OWNER TO vlna;

--
-- Name: channel; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public.channel (
    id bigint DEFAULT nextval('public.channel_id_seq'::regclass) NOT NULL,
    name character varying NOT NULL,
    public boolean NOT NULL,
    template character varying NOT NULL
);


ALTER TABLE public.channel OWNER TO vlna;

--
-- Name: base; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW public.base AS
 SELECT u.name AS "user",
    u.email,
    u.display_name,
    c.id AS channel,
    c.name,
    c.public
   FROM public."user" u,
    public.channel c;


ALTER TABLE public.base OWNER TO vlna;

--
-- Name: campaign; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public.campaign (
    id bigint NOT NULL,
    subject character varying NOT NULL,
    channel bigint NOT NULL,
    state public.campaign_state DEFAULT 'draft'::public.campaign_state NOT NULL,
    content text NOT NULL
);


ALTER TABLE public.campaign OWNER TO vlna;

--
-- Name: campaign_id_seq; Type: SEQUENCE; Schema: public; Owner: vlna
--

CREATE SEQUENCE public.campaign_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.campaign_id_seq OWNER TO vlna;

--
-- Name: campaign_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vlna
--

ALTER SEQUENCE public.campaign_id_seq OWNED BY public.campaign.id;


--
-- Name: group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public."group" (
    name character varying NOT NULL,
    label character varying NOT NULL
);


ALTER TABLE public."group" OWNER TO vlna;

--
-- Name: member; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public.member (
    "user" character varying NOT NULL,
    "group" character varying NOT NULL
);


ALTER TABLE public.member OWNER TO vlna;

--
-- Name: recipient_group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public.recipient_group (
    "group" character varying NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE public.recipient_group OWNER TO vlna;

--
-- Name: group_recipients; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW public.group_recipients AS
 SELECT DISTINCT u.name AS "user",
    rg.channel
   FROM ((public."user" u
     JOIN public.member m ON (((m."user")::text = (u.name)::text)))
     JOIN public.recipient_group rg ON (((rg."group")::text = (m."group")::text)));


ALTER TABLE public.group_recipients OWNER TO vlna;

--
-- Name: message; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public.message (
    id bigint NOT NULL,
    msgid character varying NOT NULL,
    campaign bigint NOT NULL
);


ALTER TABLE public.message OWNER TO vlna;

--
-- Name: message_id_seq; Type: SEQUENCE; Schema: public; Owner: vlna
--

CREATE SEQUENCE public.message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.message_id_seq OWNER TO vlna;

--
-- Name: message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vlna
--

ALTER SEQUENCE public.message_id_seq OWNED BY public.message.id;


--
-- Name: sender_group; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public.sender_group (
    "group" character varying NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE public.sender_group OWNER TO vlna;

--
-- Name: my_channels; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW public.my_channels AS
 SELECT DISTINCT c.id,
    c.name,
    c.public,
    c.template
   FROM (((public.get_user() u(name, email, display_name)
     JOIN public.member m ON (((m."user")::text = (u.name)::text)))
     JOIN public.sender_group sg ON (((sg."group")::text = (m."group")::text)))
     JOIN public.channel c ON ((c.id = sg.channel)))
  ORDER BY c.id;


ALTER TABLE public.my_channels OWNER TO vlna;

--
-- Name: my_campaigns; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW public.my_campaigns AS
 SELECT ca.id,
    ca.subject,
    ca.channel,
    ca.state,
    ca.content
   FROM (public.campaign ca
     JOIN public.my_channels ch ON ((ch.id = ca.channel)));


ALTER TABLE public.my_campaigns OWNER TO vlna;

--
-- Name: opt_in; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public.opt_in (
    "user" character varying NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE public.opt_in OWNER TO vlna;

--
-- Name: opt_out; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public.opt_out (
    "user" character varying NOT NULL,
    channel bigint NOT NULL
);


ALTER TABLE public.opt_out OWNER TO vlna;

--
-- Name: my_subscriptions; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW public.my_subscriptions AS
 SELECT c.id,
    c.name,
    c.public,
    c.template,
    (oi."user" IS NOT NULL) AS opt_in,
    (gr."user" IS NOT NULL) AS "group",
    (ou."user" IS NOT NULL) AS opt_out,
    ((c.public AND (oi."user" IS NOT NULL)) OR ((gr."user" IS NOT NULL) AND (ou."user" IS NULL))) AS active
   FROM ((((public.channel c
     JOIN public.get_user() u(name, email, display_name) ON ((1 = 1)))
     LEFT JOIN public.opt_in oi ON ((((oi."user")::text = (u.name)::text) AND (oi.channel = c.id))))
     LEFT JOIN public.group_recipients gr ON ((((gr."user")::text = (u.name)::text) AND (gr.channel = c.id))))
     LEFT JOIN public.opt_out ou ON ((((ou."user")::text = (u.name)::text) AND (ou.channel = c.id))))
  WHERE (c.public OR (gr."user" IS NOT NULL))
  ORDER BY c.id;


ALTER TABLE public.my_subscriptions OWNER TO vlna;

--
-- Name: recipients; Type: VIEW; Schema: public; Owner: vlna
--

CREATE VIEW public.recipients AS
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
   FROM (((public.base b
     LEFT JOIN public.opt_in oi ON ((((oi."user")::text = (b."user")::text) AND (oi.channel = b.channel))))
     LEFT JOIN public.group_recipients gr ON ((((gr."user")::text = (b."user")::text) AND (gr.channel = b.channel))))
     LEFT JOIN public.opt_out ou ON ((((ou."user")::text = (b."user")::text) AND (ou.channel = b.channel))))
  WHERE (b.public OR (gr."user" IS NOT NULL));


ALTER TABLE public.recipients OWNER TO vlna;

--
-- Name: template; Type: TABLE; Schema: public; Owner: vlna
--

CREATE TABLE public.template (
    name character varying NOT NULL,
    body text NOT NULL
);


ALTER TABLE public.template OWNER TO vlna;

--
-- Name: campaign id; Type: DEFAULT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.campaign ALTER COLUMN id SET DEFAULT nextval('public.campaign_id_seq'::regclass);


--
-- Name: message id; Type: DEFAULT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.message ALTER COLUMN id SET DEFAULT nextval('public.message_id_seq'::regclass);


--
-- Data for Name: campaign; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public.campaign (id, subject, channel, state, content) FROM stdin;
1	Rikša na Libeňáku	1	draft	# Rikša na Libeňáku\r\n\r\nPrávě začínáme naší propagační mega-akci a vozíme důchodce a maminky s dětmi přes Libeňský most v Pirátské rikše. Přijďte si také zajezdit!
\.


--
-- Data for Name: channel; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public.channel (id, name, public, template) FROM stdin;
1	Stranický oběžník	f	obeznik
2	Poslanecká vlna	f	snemovna
3	Tiskové zprávy	t	tiskovka
\.


--
-- Data for Name: group; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public."group" (name, label) FROM stdin;
poslanci	Poslanci
clenove	Členové
priznivci	Příznivci
\.


--
-- Data for Name: member; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public.member ("user", "group") FROM stdin;
poslanec	poslanci
poslanec	clenove
priznivec	priznivci
clen	clenove
\.


--
-- Data for Name: message; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public.message (id, msgid, campaign) FROM stdin;
\.


--
-- Data for Name: opt_in; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public.opt_in ("user", channel) FROM stdin;
\.


--
-- Data for Name: opt_out; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public.opt_out ("user", channel) FROM stdin;
\.


--
-- Data for Name: recipient_group; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public.recipient_group ("group", channel) FROM stdin;
poslanci	2
clenove	1
poslanci	1
\.


--
-- Data for Name: sender_group; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public.sender_group ("group", channel) FROM stdin;
poslanci	2
poslanci	1
poslanci	3
clenove	1
\.


--
-- Data for Name: template; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public.template (name, body) FROM stdin;
obeznik	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">\n<html xmlns="http://www.w3.org/1999/xhtml">\n <head>\n  <meta name="viewport" content="width=device-width" />\n  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />\n  <title>{{subject}}</title>\n  <style media="all" type="text/css">\n  </style>\n </head>\n <body itemscope itemtype="http://schema.org/EmailMessage">\n  <table class="body-wrap">\n   <tr>\n    <td></td>\n    <td class="container" width="600">\n     <div class="content">\n      <table class="main" width="100%" cellpadding="0" cellspacing="0" itemprop="action" itemscope itemtype="http://schema.org/ConfirmAction">\n       <tr>\n        <td class="content-wrap">\n         <meta itemprop="name" content="{{subject}}"/>\n         <table width="100%" cellpadding="0" cellspacing="0">\n          <tr>\n           <!-- TODO: Implement template attachments.\n           <td class="content-block">\n            <img src="cid:logo.png" style="max-width:600px;" id="headerImage"  />\n           </td>\n           -->\n          </tr>\n          <tr>\n           <td class="content-block">\n            {{content}}\n           </td>\n          </tr>\n         </table>\n        </td>\n       </tr>\n      </table>\n      <div class="footer">\n       <table width="100%">\n        <tr>\n         <td class="content-block">\n          <p><a href="https://{{domain}}/">Mailing Preferences / Nastavení odběru</a></p>\n         </td>\n        </tr>\n       </table>\n      </div>\n     </div>\n    </td>\n    <td></td>\n   </tr>\n  </table>\n </body>\n</html>
snemovna	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">\n<html xmlns="http://www.w3.org/1999/xhtml">\n <head>\n  <meta name="viewport" content="width=device-width" />\n  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />\n  <title>{{subject}}</title>\n  <style media="all" type="text/css">\n  </style>\n </head>\n <body itemscope itemtype="http://schema.org/EmailMessage">\n  <table class="body-wrap">\n   <tr>\n    <td></td>\n    <td class="container" width="600">\n     <div class="content">\n      <table class="main" width="100%" cellpadding="0" cellspacing="0" itemprop="action" itemscope itemtype="http://schema.org/ConfirmAction">\n       <tr>\n        <td class="content-wrap">\n         <meta itemprop="name" content="{{subject}}"/>\n         <table width="100%" cellpadding="0" cellspacing="0">\n          <tr>\n           <!-- TODO: Implement template attachments.\n           <td class="content-block">\n            <img src="cid:logo.png" style="max-width:600px;" id="headerImage"  />\n           </td>\n           -->\n          </tr>\n          <tr>\n           <td class="content-block">\n            {{content}}\n           </td>\n          </tr>\n         </table>\n        </td>\n       </tr>\n      </table>\n      <div class="footer">\n       <table width="100%">\n        <tr>\n         <td class="content-block">\n          <p><a href="https://{{domain}}/">Mailing Preferences / Nastavení odběru</a></p>\n         </td>\n        </tr>\n       </table>\n      </div>\n     </div>\n    </td>\n    <td></td>\n   </tr>\n  </table>\n </body>\n</html>
tiskovka	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">\n<html xmlns="http://www.w3.org/1999/xhtml">\n <head>\n  <meta name="viewport" content="width=device-width" />\n  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />\n  <title>{{subject}}</title>\n  <style media="all" type="text/css">\n  </style>\n </head>\n <body itemscope itemtype="http://schema.org/EmailMessage">\n  <table class="body-wrap">\n   <tr>\n    <td></td>\n    <td class="container" width="600">\n     <div class="content">\n      <table class="main" width="100%" cellpadding="0" cellspacing="0" itemprop="action" itemscope itemtype="http://schema.org/ConfirmAction">\n       <tr>\n        <td class="content-wrap">\n         <meta itemprop="name" content="{{subject}}"/>\n         <table width="100%" cellpadding="0" cellspacing="0">\n          <tr>\n           <!-- TODO: Implement template attachments.\n           <td class="content-block">\n            <img src="cid:logo.png" style="max-width:600px;" id="headerImage"  />\n           </td>\n           -->\n          </tr>\n          <tr>\n           <td class="content-block">\n            {{content}}\n           </td>\n          </tr>\n         </table>\n        </td>\n       </tr>\n      </table>\n      <div class="footer">\n       <table width="100%">\n        <tr>\n         <td class="content-block">\n          <p><a href="https://{{domain}}/">Mailing Preferences / Nastavení odběru</a></p>\n         </td>\n        </tr>\n       </table>\n      </div>\n     </div>\n    </td>\n    <td></td>\n   </tr>\n  </table>\n </body>\n</html>
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: public; Owner: vlna
--

COPY public."user" (name, email, display_name) FROM stdin;
poslanec	poslanec@mailinator.com	Pan Poslanec
priznivec	priznivec@mailinator.com	Velký Příznivec
clen	clen@mailinator.com	Klíčový člen
novinar	novinar@mailinator.com	Věhlasný novinář
\.


--
-- Name: campaign_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vlna
--

SELECT pg_catalog.setval('public.campaign_id_seq', 1, true);


--
-- Name: channel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vlna
--

SELECT pg_catalog.setval('public.channel_id_seq', 3, true);


--
-- Name: message_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vlna
--

SELECT pg_catalog.setval('public.message_id_seq', 1, false);


--
-- Name: campaign campaign_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.campaign
    ADD CONSTRAINT campaign_pkey PRIMARY KEY (id);


--
-- Name: channel channel_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.channel
    ADD CONSTRAINT channel_pkey PRIMARY KEY (id);


--
-- Name: group group_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public."group"
    ADD CONSTRAINT group_pkey PRIMARY KEY (name);


--
-- Name: member member_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_pkey PRIMARY KEY ("user", "group");


--
-- Name: message message_msgid_key; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_msgid_key UNIQUE (msgid);


--
-- Name: message message_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);


--
-- Name: opt_in opt_in_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.opt_in
    ADD CONSTRAINT opt_in_pkey PRIMARY KEY ("user", channel);


--
-- Name: opt_out opt_out_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.opt_out
    ADD CONSTRAINT opt_out_pkey PRIMARY KEY ("user", channel);


--
-- Name: recipient_group recipient_group_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.recipient_group
    ADD CONSTRAINT recipient_group_pkey PRIMARY KEY ("group", channel);


--
-- Name: sender_group sender_group_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.sender_group
    ADD CONSTRAINT sender_group_pkey PRIMARY KEY ("group", channel);


--
-- Name: template template_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.template
    ADD CONSTRAINT template_pkey PRIMARY KEY (name);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (name);


--
-- Name: channel_public_idx; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX channel_public_idx ON public.channel USING btree (public);


--
-- Name: fki_campaign_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_campaign_channel_fkey ON public.campaign USING btree (channel);


--
-- Name: fki_channel_template_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_channel_template_fkey ON public.channel USING btree (template);


--
-- Name: fki_member_group_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_member_group_fkey ON public.member USING btree ("group");


--
-- Name: fki_message_campaign_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_message_campaign_fkey ON public.message USING btree (campaign);


--
-- Name: fki_opt_in_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_opt_in_channel_fkey ON public.opt_in USING btree (channel);


--
-- Name: fki_opt_out_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_opt_out_channel_fkey ON public.opt_out USING btree (channel);


--
-- Name: fki_recipient_group_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_recipient_group_channel_fkey ON public.recipient_group USING btree (channel);


--
-- Name: fki_sender_group_channel_fkey; Type: INDEX; Schema: public; Owner: vlna
--

CREATE INDEX fki_sender_group_channel_fkey ON public.sender_group USING btree (channel);


--
-- Name: campaign campaign_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.campaign
    ADD CONSTRAINT campaign_channel_fkey FOREIGN KEY (channel) REFERENCES public.channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: channel channel_template_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.channel
    ADD CONSTRAINT channel_template_fkey FOREIGN KEY (template) REFERENCES public.template(name) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: member member_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_group_fkey FOREIGN KEY ("group") REFERENCES public."group"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: member member_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_user_fkey FOREIGN KEY ("user") REFERENCES public."user"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: message message_campaign_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.message
    ADD CONSTRAINT message_campaign_fkey FOREIGN KEY (campaign) REFERENCES public.campaign(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_in opt_in_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.opt_in
    ADD CONSTRAINT opt_in_channel_fkey FOREIGN KEY (channel) REFERENCES public.channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_in opt_in_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.opt_in
    ADD CONSTRAINT opt_in_user_fkey FOREIGN KEY ("user") REFERENCES public."user"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_out opt_out_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.opt_out
    ADD CONSTRAINT opt_out_channel_fkey FOREIGN KEY (channel) REFERENCES public.channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: opt_out opt_out_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.opt_out
    ADD CONSTRAINT opt_out_user_fkey FOREIGN KEY ("user") REFERENCES public."user"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: recipient_group recipient_group_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.recipient_group
    ADD CONSTRAINT recipient_group_channel_fkey FOREIGN KEY (channel) REFERENCES public.channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: recipient_group recipient_group_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.recipient_group
    ADD CONSTRAINT recipient_group_group_fkey FOREIGN KEY ("group") REFERENCES public."group"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sender_group sender_group_channel_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.sender_group
    ADD CONSTRAINT sender_group_channel_fkey FOREIGN KEY (channel) REFERENCES public.channel(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: sender_group sender_group_group_fkey; Type: FK CONSTRAINT; Schema: public; Owner: vlna
--

ALTER TABLE ONLY public.sender_group
    ADD CONSTRAINT sender_group_group_fkey FOREIGN KEY ("group") REFERENCES public."group"(name) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

