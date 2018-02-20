#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

from flask import g, render_template
from flask_classy import FlaskView, route
from flask_menu.classy import classy_menu_item
from flask_babel import gettext, lazy_gettext as _
from werkzeug.exceptions import NotFound

from vlna.site import db, require_role


__all__ = ['ChanView']


class ChanView(FlaskView):
    route_base = '/chan/'

    @classy_menu_item('chan', _('Channels'),
                      visible_when=lambda: 'admin' in g.roles)
    @require_role('admin')
    def index(self):
        chans = db.channel.order_by('name').all()

        return render_template('chan/list.html', chans=chans)


    @route('/add')
    @require_role('admin')
    def add(self):
        return 'TODO', 500


    @route('/edit/<int:id>')
    @require_role('admin')
    def edit(self, id):
        chan = db.channel.get(id)

        if chan is None:
            raise NotFound(gettext('No such channel'))

        return render_template('chan/edit.html', chan=chan)


# vim:set sw=4 ts=4 et:
