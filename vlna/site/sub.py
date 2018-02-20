#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

from flask import request, g, render_template, redirect, url_for, flash
from flask_classy import FlaskView, route
from flask_menu.classy import classy_menu_item
from flask_babel import gettext, lazy_gettext as _

from vlna.site import db


__all__ = ['SubView']


class SubView(FlaskView):
    route_base = '/sub/'

    @classy_menu_item('sub', _('Subscriptions'))
    def index(self):
        subs = db.my_subscriptions.all()

        return render_template('sub.html', subs=subs)


    @route('/update', methods=['POST'])
    def update(self):
        # Extract the requested channel ids.
        ids = request.form.getlist('sub', type=int)

        # Go by the valid subscriptions to prevent users subscribing to
        # something they are not actually allowed to receive.
        subs = db.my_subscriptions.all()

        for sub in subs:
            if sub.id in ids and not sub.active:
                # User wants to newly subscribe to this channel.

                if sub.group and sub.opt_out:
                    db.opt_out \
                        .filter_by(user=g.user.name, channel=sub.id) \
                        .delete()

                elif sub.public and not sub.opt_in:
                    db.opt_in.insert(user=g.user.name, channel=sub.id)

            elif sub.id not in ids and sub.active:
                # User no longer wants to be subscribed to this channel.

                # Note that we use two independent if statements to clear
                # both group-based subscriptions and opt-ins if user happens
                # to have both, which is possible.

                if sub.public and sub.opt_in:
                    db.opt_in \
                        .filter_by(user=g.user.name, channel=sub.id) \
                        .delete()

                if sub.group and not sub.opt_out:
                    db.opt_out.insert(user=g.user.name, channel=sub.id)

        db.commit()
        flash(gettext('Subscription preferences have been saved.'), 'success')

        return redirect(url_for('SubView:index'))


# vim:set sw=4 ts=4 et:
