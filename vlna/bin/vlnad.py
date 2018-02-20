#!/usr/bin/python3 -tt
# -*- coding: utf-8 -*-

import os

from os.path import realpath
from logging import DEBUG, INFO
from logging import getLogger, NullHandler, StreamHandler, Formatter, root

import click

from aiohttp.web import Application, run_app
from aiohttp_wsgi import WSGIHandler


__all__ = ['cli']

# For module-specific logging.
log = getLogger('vlnad')
log.addHandler(NullHandler())

# To pass command line options around.
pass_opts = click.make_pass_decorator(dict)

@click.command()
@click.option('--config', '-c', envvar='VLNA_SETTINGS',
              default='/dev/null', metavar='PATH',
              help='Load a configuration file.')

@click.option('--debug', '-d', default=False, is_flag=True,
              help='Enable debug logging.')

@click.version_option('0.1.0')
def cli(config, debug):
    # Load site & configuration.
    os.environ['VLNA_SETTINGS'] = realpath(config)
    from vlna.site import site

    # Enable debugging if specified on the commmand line.
    site.config['DEBUG'] = site.config['DEBUG'] or debug

    # Get relevant configuration options.
    debug = site.config.get('DEBUG', False)
    host = site.config.get('HOST', '::')
    port = int(site.config.get('PORT', 5000))

    # Set up the logging.
    level = DEBUG if debug else INFO
    handler = StreamHandler()
    handler.setLevel(level)
    handler.setFormatter(Formatter('%(levelname)s: [%(name)s] %(message)s'))
    root.addHandler(handler)
    root.setLevel(level)

    # Dump current configuration to the log.
    log.debug('Configuration:')
    for key, value in sorted(site.config.items()):
        log.debug('  %s = %r', key, value)

    # Prepare WSGI handler for the web site.
    handler = WSGIHandler(site)
    app = Application(debug=debug)
    app.router.add_route('*', '/{path_info:.*}', handler)

    # Run the web server / asyncio loop.
    run_app(app, host=host, port=port)


if __name__ == '__main__':
    cli()


# vim:set sw=4 ts=4 et:
