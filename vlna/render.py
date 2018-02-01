#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

from premailer import Premailer
from markdown2 import markdown
from jinja2 import Template


__all__ = ['render_html']


def render_html(campaign):
    """
    Render campaign to HTML with inlined styles.
    """

    from vlna.site import site

    content = markdown(campaign.content)
    template = Template(campaign.Channel.Template.body)

    html = template.render(subject=campaign.subject,
                           content=content,
                           domain=site.config['MAILGUN_DOMAIN'])

    return Premailer(html).transform()


# vim:set sw=4 ts=4 et:
