#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

from flask import request, g, render_template, redirect, url_for, flash
from flask_classy import FlaskView, route
from flask_menu.classy import classy_menu_item
from flask_babel import lazy_gettext as _

from vlna.exn import InvalidUsage
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


    @route('/edit/<int:id>')
    @require_role('admin')
    def edit(self, id):
        chan = db.channel.get(id)

        if chan is None:
            raise NotFound(gettext('No such channel'))

        return render_template('chan/edit.html', chan=chan)


# vim:set sw=4 ts=4 et:
