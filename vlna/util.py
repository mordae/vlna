#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

"""
Common utilities that did not fit anywhere else.
"""

from time import time
from collections import OrderedDict
from hmac import new as HMAC, compare_digest

from simplejson import loads, dumps
from sqlalchemy import Table, Column


__all__ = [
    'map_view',
    'make_csrf_token',
    'csrf_token_valid',
    'hmac_sign',
    'hmac_verify',
]


def map_view(db, name, keys):
    """
    Map view as a table with specified primary keys.
    Otherwise ``SQLSoup`` will not cooperate.
    """

    columns = [Column(key, primary_key=True) for key in keys]
    table = Table(name, db._metadata, *columns, autoload=True)
    db.map_to(name, selectable=table)


def make_csrf_token():
    """
    Generate an anti-CSRF token.
    """

    return dumps(hmac_sign(OrderedDict([
        ('type', 'csrf'),
        ('time', int(time())),
    ])))


def csrf_token_valid(token, validity=3600):
    """
    Verify that the specified token is valid and not older than allowed.
    """

    try:
        payload = loads(token, object_pairs_hook=OrderedDict)
        payload = hmac_verify(payload)

        if payload.get('type') != 'csrf':
            return False

        if payload.get('time', -validity) + validity < time():
            return False

    except:
        return False

    return True


def hmac_sign(payload):
    """
    Sign the payload dictionary using site secret.
    """

    from vlna.site import site

    algo = site.config.get('HMAC_HASH_ALGORITHM', 'sha256')
    datum = dumps(payload).encode('utf8')
    payload['$digest'] = HMAC(site.secret_key, datum, algo).hexdigest()
    return payload


def hmac_verify(payload):
    """
    Verify payload dictionary using site secret.
    """

    if not '$digest' in payload:
        raise ValueError('Missing HMAC digest')

    digest = payload.pop('$digest')
    control = hmac_sign(payload).pop('$digest')

    if not compare_digest(digest, control):
        raise ValueError('Invalid HMAC digest')

    return payload


# vim:set sw=4 ts=4 et:
