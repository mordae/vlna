#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

from sqlsoup import SQLSoup
from sqlalchemy import Table, Column


__all__ = ['map_view']


def map_view(db, name, keys):
    """
    Map view as a table with specified primary keys.
    Otherwise ``SQLSoup`` will not cooperate.
    """

    columns = [Column(key, primary_key=True) for key in keys]
    table = Table(name, db._metadata, *columns, autoload=True)
    db.map_to(name, selectable=table)


# vim:set sw=4 ts=4 et:
