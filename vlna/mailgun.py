#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

"""
Interface for the cloud service Mailgun.
"""

from logging import getLogger, NullHandler
from urllib.parse import urljoin
from email.utils import formataddr

from requests import post
from simplejson import dumps

from vlna.exn import RemoteError
from vlna.render import render_html


__all__ = ['Mailgun']


API = 'https://api.mailgun.net/v3/'

log = getLogger(__name__)
log.addHandler(NullHandler())


class MailgunError(RemoteError):
    """Mailgun-related error"""


class Mailgun:
    """Mailgun service proxy object."""

    def __init__(self, domain, apikey, sender, testmode=False):
        self.domain = domain
        self.apikey = apikey
        self.sender = sender
        self.testmode = testmode

    def post(self, url, **kw):
        """Perform a general POST request."""

        full_url = urljoin(API, self.domain + '/' + url)
        r = post(full_url, auth=('api', self.apikey), **kw)

        if 200 <= r.status_code < 300:
            return r.json()

        try:
            msg = r.json().get('message', 'Unknown reason.')
            raise MailgunError(msg, {'response': r.json()})

        except:
            raise MailgunError('Cannot parse.', {'response': r.text})

    def send(self, recipient, trn):
        """Send message to a single recipient."""
        return self.send_many([recipient], trn)

    def send_many(self, recipients, trn):
        """
        Send message to many recipients.
        """

        groups = [recipients[i : i + 1000]
                  for i in range(0, len(recipients), 1000)]

        for recs in groups:
            tos = [formataddr((r.display_name, r.email)) for r in recs]
            rvs = {r.email: {} for r in recs}

            return self.post('messages', data={
                'from': self.sender,
                'to': ', '.join(tos),
                'subject': trn.subject,
                'text': trn.content,
                'html': render_html(trn),
                'o:testmode': 'yes' if self.testmode else 'no',
                'recipient-variables': dumps(rvs),
            })


# vim:set sw=4 ts=4 et:
