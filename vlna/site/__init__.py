#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

from os import urandom, environ
from os.path import realpath
from functools import wraps
from logging import getLogger, NullHandler

from flask import Flask, request, g, render_template, redirect, flash, url_for
from flask_menu import Menu, current_menu, register_menu
from flask_menu.classy import register_flaskview
from flask_babel import Babel, gettext, lazy_gettext as _
from werkzeug.exceptions import Forbidden, NotFound

from sqlsoup import SQLSoup
from sqlalchemy import text

from vlna.exn import InvalidUsage
from vlna.util import map_view, make_csrf_token, csrf_token_valid
from vlna.mailgun import Mailgun


__all__ = ['site', 'db', 'mailer', 'require_role']


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
    'MAILGUN_DOMAIN': 'your-domain.tld',
    'MAILGUN_APIKEY': 'generate-some-key-please',
    'MAILGUN_SENDER': 'sender@your-domain.tld',
})

if 'VLNA_SETTINGS' in environ:
    # Load rest from a configuration file specified in the environment.
    # Set by the --config option when run using the `vlnad` command.
    site.config.from_envvar('VLNA_SETTINGS')

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

#
# Initialize the mailer backend.
#
mailer = Mailgun(site.config['MAILGUN_DOMAIN'],
                 site.config['MAILGUN_APIKEY'],
                 site.config['MAILGUN_SENDER'])


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
    return make_csrf_token()


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
map_view(db, 'my_subscriptions', ['id'])
map_view(db, 'my_channels', ['id'])
map_view(db, 'my_campaigns', ['id'])
map_view(db, 'recipients', ['user', 'channel'])

# Specify automatic row relations.
db.campaign.relate('Channel', db.channel)

db.my_campaigns.relate('Channel', db.channel,
                       primaryjoin=(db.channel.c.id == db.my_campaigns.c.channel),
                       foreign_keys=[db.my_campaigns.c.channel])

db.channel.relate('Template', db.template)

db.my_channels.relate('Template', db.template,
                      primaryjoin=(db.template.c.name == db.my_channels.c.template),
                      foreign_keys=[db.my_channels.c.template])


@site.teardown_request
def teardown_request(_exn=None):
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

    db.connection() \
        .execute(text('select set_user(:name)'), name=login)

    g.roles = set(request.headers.get('X-Roles', '').split(';'))
    g.roles.discard('')


@site.before_request
def csrf_protect():
    if request.method == 'POST':
        token = request.form.get('token', '')

        if not csrf_token_valid(token):
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
def forbidden(_exn):
    return render_template('forbidden.html')


@site.errorhandler(InvalidUsage)
def invalid_usage(exn):
    log.error('Exception: %s, data=%r', exn, exn.data)
    return render_template('invalid-usage.html', exn=exn), exn.status


@site.route('/')
def index():
    return redirect(url_for('SubView:index'))


from vlna.site.sub import SubView
from vlna.site.trn import TrnView
from vlna.site.chan import ChanView

SubView.register(site)
register_flaskview(site, SubView)

TrnView.register(site)
register_flaskview(site, TrnView)

ChanView.register(site)
register_flaskview(site, ChanView)


# vim:set sw=4 ts=4 et:
