#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

from os import urandom, environ
from os.path import realpath

from flask import Flask, request, g, render_template, redirect, flash
from flask_menu import Menu, current_menu, register_menu
from flask_babel import Babel, gettext, lazy_gettext as _
from werkzeug.exceptions import Forbidden, NotFound

from sqlsoup import SQLSoup
from sqlalchemy import text

from functools import wraps
from logging import getLogger, NullHandler

from vlna.exn import InvalidUsage
from vlna.util import map_view, make_csrf_token, csrf_token_valid


__all__ = ['site', 'db']


log = getLogger(__name__)
log.addHandler(NullHandler())

site = Flask(__name__)
site.secret_key = urandom(16)

# Default configuration options.
site.config.from_mapping({
    'HOST': '::',
    'PORT': 5000,
    'DEBUG': False,
    'BABEL_DEFAULT_LOCALE': 'cs',
    'SQLSOUP_DATABASE_URI': 'postgresql://vlna:vlna@localhost/vlna',
    'MAX_CONTENT_LENGTH': 32 * 1024 * 1024,
    'DATA_PATH': 'data',
})

if 'VLNA_SETTINGS' in environ:
    # Load rest from a configuration file specified in the environment.
    # Set by the --config option when run using the `vlnad` command.
    site.config.from_envvar('VLNA_SETTINGS')

# Make sure to use absolute path to the data directory.
site.config['DATA_PATH'] = realpath(site.config['DATA_PATH'])

#
# Initialize the l18n module.
#
# See the translations/ directory located alongside this file for strings
# to translate. Run `make lang` to update the translation files.
#
babel = Babel(site)

#
# Initialize the automatic menu generation.
#
# Decorators on particular endpoints provide the actual menu structure
# the base template then makes use of. Make sure to use `lazy_gettext`
# when defining the menu labels so that all works correctly.
#
menu = Menu(site)


@site.template_global('get_locale')
@babel.localeselector
def get_locale():
    """
    Return currently selected locale.
    """

    if 'lang' in request.args:
        return request.args['lang']

    locale = site.config['BABEL_DEFAULT_LOCALE']
    return request.cookies.get('lang', locale)


@site.template_global('make_token')
def make_token():
    return make_csrf_token(site)


@site.after_request
def insert_lang_cookie(response):
    """
    Make user locale selection persistent using a cookie.
    """

    if 'lang' in request.args:
        response.set_cookie('lang', request.args['lang'])

    return response


# Use SQLSoup for database access.
db = SQLSoup(site.config['SQLSOUP_DATABASE_URI'])

# Specify primary keys for SQLSoup to allow us to work with views.
map_view(db, 'my_subscriptions', ['channel'])
map_view(db, 'my_channels', ['channel'])

# Specify automatic row relations.
db.campaign.relate('Author', db.user)
db.campaign.relate('Channel', db.channel)


@site.teardown_request
def teardown_request(exn=None):
    """
    Rolls back current session at the end of every request.
    """

    try:
        db.session.rollback()
    except Exception as subexn:
        # Teardown callbacks may not raise exceptions.
        log.exception(subexn)


@site.context_processor
def inject_env():
    """
    Injects site configuration and other globals to templates.
    """

    return dict(site.config, current_menu=current_menu)


@site.before_request
def extract_auth_info():
    """
    Extract user identification from the ``X-Login`` request header and
    store the corresponding user object in ``g.user``. Then parse the
    ``X-Roles`` header and store user roles in ``g.roles``.
    """

    assert 'X-Login' in request.headers, \
           'Your web server must pass along the X-Login header.'

    login = request.headers['X-Login']
    g.user = db.user.get(login)

    if g.user is None:
        msg = _('There is no user account for you, contact administrator.')
        raise InvalidUsage(msg, data={'login': login})

    r = db.connection() \
        .execute(text('select set_user(:name)'), name=login)

    g.roles = set(request.headers.get('X-Roles', '').split(';'))
    g.roles.discard('')


@site.before_request
def csrf_protect():
    if request.method == 'POST':
        token = request.form.get('token', '')

        if not csrf_token_valid(site, token):
            raise InvalidUsage(_('Invalid CSRF token. Return and try again.'))


def require_role(role):
    """
    Require that the user has specified role and deny them access otherwise.
    """

    def make_wrapper(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            if not role in g.roles:
                raise Forbidden('RBAC Forbidden')

            return fn(*args, **kwargs)

        return wrapper
    return make_wrapper


@site.errorhandler(Forbidden.code)
def forbidden(exn):
    return render_template('forbidden.html')


@site.errorhandler(InvalidUsage)
def invalid_usage(exn):
    return render_template('invalid-usage.html', exn=exn), exn.status


@site.route('/')
@register_menu(site, 'sub', _('Subscriptions'))
def subscriptions():
    subs = db.my_subscriptions.all()

    return render_template('sub.html', subs=subs)


@site.route('/sub/update', methods=['POST'])
def update_subscriptions():
    # Extract the requested channel ids.
    ids = request.form.getlist('sub', type=int)

    # Go by the valid subscriptions to prevent users subscribing to
    # something they are not actually allowed to receive.
    subs = db.my_subscriptions.all()

    for sub in subs:
        if sub.channel in ids and not sub.active:
            # User wants to newly subscribe to this channel.

            if sub.group and sub.opt_out:
                db.opt_out \
                    .filter_by(user=g.user.name, channel=sub.channel) \
                    .delete()

            elif sub.public and not sub.opt_in:
                db.opt_in.insert(user=g.user.name, channel=sub.channel)

        elif sub.channel not in ids and sub.active:
            # User no longer wants to be subscribed to this channel.

            # Note that we use two independent if statements to clear
            # both group-based subscriptions and opt-ins if user happens
            # to have both, which is possible.

            if sub.public and sub.opt_in:
                db.opt_in \
                    .filter_by(user=g.user.name, channel=sub.channel) \
                    .delete()

            if sub.group and not sub.opt_out:
                db.opt_out.insert(user=g.user.name, channel=sub.channel)

    db.commit()
    flash(gettext('Subscription preferences have been saved.'), 'success')

    return redirect('/')



@site.route('/trn/')
@register_menu(site, 'trn', _('Transmissions'),
               visible_when=lambda: 'sender' in g.roles)
@require_role('sender')
def transmissions():
    trns = db.campaign \
            .order_by(db.campaign.c.id.desc()) \
            .limit(10) \
            .all()

    chans = db.my_channels.order_by('name').all()

    return render_template('trn/list.html', trns=trns, chans=chans)


@site.route('/chan/')
@register_menu(site, 'chan', _('Channels'),
               visible_when=lambda: 'admin' in g.roles)
@require_role('admin')
def channels():
    chans = db.channel.order_by('name').all()

    return render_template('chan/list.html', chans=chans)


@site.route('/chan/edit/<int:id>')
@require_role('admin')
def edit_channel(id):
    chan = db.channel.get(id)

    if chan is None:
        raise NotFound('No such channel')

    return render_template('chan/edit.html', chan=chan)


# vim:set sw=4 ts=4 et:
