#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

from sqlsoup import SQLSoup
from sqlalchemy import Table, Column

from collections import OrderedDict
from simplejson import loads, dumps

from time import time
from hmac import new as HMAC, compare_digest


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


def make_csrf_token(site):
    """
    Generate an anti-CSRF token.
    """

    return dumps(hmac_sign(site, OrderedDict([
        ('type', 'csrf'),
        ('time', int(time())),
    ])))


def csrf_token_valid(site, token, validity=3600):
    """
    Verify that the specified token is valid and not older than allowed.
    """

    try:
        payload = loads(token, object_pairs_hook=OrderedDict)
        payload = hmac_verify(site, payload)

        if payload.get('type') != 'csrf':
            return False

        if payload.get('time', -validity) + validity < time():
            return False

    except:
        return False

    return True


def hmac_sign(site, payload):
    algo = site.config.get('HMAC_HASH_ALGORITHM', 'sha256')
    datum = dumps(payload).encode('utf8')
    payload['$digest'] = HMAC(site.secret_key, datum, algo).hexdigest()
    return payload


def hmac_verify(site, payload):
    if not '$digest' in payload:
        raise ValueError('Missing HMAC digest')

    digest = payload.pop('$digest')
    control = hmac_sign(site, payload).pop('$digest')

    if not compare_digest(digest, control):
        raise ValueError('Invalid HMAC digest')

    return payload


# vim:set sw=4 ts=4 et:
