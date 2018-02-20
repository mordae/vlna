#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

from flask import request, g, render_template, redirect, url_for, flash
from flask_classy import FlaskView, route
from flask_menu.classy import classy_menu_item
from flask_babel import lazy_gettext as _

from vlna.exn import InvalidUsage
from vlna.site import db, require_role


__all__ = ['TrnView']


class TrnView(FlaskView):
    route_base = '/trn/'


    @classy_menu_item('trn', _('Transmissions'),
                      visible_when=lambda: 'sender' in g.roles)
    @require_role('sender')
    def index(self):
        trns = db.my_campaigns \
                .order_by(db.my_campaigns.c.id.desc()) \
                .limit(10) \
                .all()

        chans = db.my_channels.order_by('name').all()

        return render_template('trn/list.html', trns=trns, chans=chans)


    @route('/chan/<int:id>/')
    @require_role('sender')
    def chan(self, id):
        chan = db.my_channels.get(id)

        if chan is None:
            raise NotFound(gettext('No such channel'))

        # TODO: Implement paging and search, probably using DataTables.

        trns = db.my_campaigns \
                .filter_by(channel=id) \
                .order_by(db.my_campaigns.c.id.desc()) \
                .all()

        return render_template('trn/chan-list.html', chan=chan, trns=trns)


    @route('/all/')
    @require_role('sender')
    def all(self):
        # TODO: Implement paging and search, probably using DataTables.

        trns = db.my_campaigns \
                .order_by(db.my_campaigns.c.id.desc()) \
                .all()

        return render_template('trn/full-list.html', trns=trns)


    @route('/edit/<int:id>')
    @require_role('sender')
    def edit(self, id):
        trn = db.my_campaigns.get(id)

        if trn is None:
            raise NotFound(gettext('No such transmission'))

        if trn.state == 'sent':
            raise InvalidUsage(_('Cannot edit sent transmission.'))

        chans = db.my_channels.order_by('name').all()

        return render_template('trn/edit.html', trn=trn, chans=chans)


    @route('/update/<int:id>', methods=['POST'])
    @require_role('sender')
    def update(self, id):
        trn = db.my_campaigns.get(id)

        if trn is None:
            raise NotFound(_('No such transmission'))

        if trn.state == 'sent':
            raise InvalidUsage(_('Cannot edit sent transmission.'))

        action = request.form.get('action')
        subject = request.form.get('subject', trn.subject)
        channel = request.form.get('channel', trn.channel)
        content = request.form.get('content', trn.content)

        chan = db.my_channels.get(request.form.get('channel'))

        if chan is None:
            raise InvalidUsage(_('Invalid channel specified.'), {
                'channel': request.form.get('channel'),
            })

        if action not in ('test', 'save', 'send'):
            raise InvalidUsage(gettext('Invalid action.'), {'action': action})

        camp = db.campaign.get(id)
        camp.subject = subject
        camp.channel = channel
        camp.content = content

        db.commit()

        if trn.subject != camp.subject or \
           trn.channel != camp.channel or \
           trn.content != camp.content:
            flash(gettext('Modifications successfully saved.'), 'success')

        if action == 'save':
            pass

        elif action == 'test':
            mailer.send(g.user, camp)

            msg = gettext('Trial message sent to {}.').format(g.user.email)
            flash(msg, 'success')

            return redirect(url_for('transmission_edit', id=id))

        else:
            recs = db.recipients \
                    .filter_by(channel=camp.channel, active=True) \
                    .all()

            mailer.send_many(recs, camp)

            camp.state = 'sent'
            db.commit()

            msg = gettext('Message sent through the channel.')
            flash(msg, 'success')

        return redirect(url_for('transmissions'))


# vim:set sw=4 ts=4 et:
