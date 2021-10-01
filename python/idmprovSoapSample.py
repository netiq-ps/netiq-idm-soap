#!/usr/bin/env python

""" idmprovSoapSample.py: How to access the IDMProv SOAP API in Python using Zeep """

from argparse import ArgumentParser

import logging.config

from requests import Session
from requests.auth import HTTPBasicAuth

from zeep import Client
from zeep.transports import Transport

__author__ = "Norbert Klasen"
__copyright__ = "Copyright 2018, Micro Focus"
__license__ = "MIT"

def main(args):
    """Runs program and handles command line options"""

    logging.config.dictConfig({
        'version': 1,
        'formatters': {
            'verbose': {
                'format': '%(name)s: %(message)s'
            }
        },
        'handlers': {
            'console': {
                'level': 'DEBUG',
                'class': 'logging.StreamHandler',
                'formatter': 'verbose',
            },
        },
        'loggers': {
            'zeep.transports': {
                'level': args.loglevel,
                'propagate': True,
                'handlers': ['console'],
            },
        }
    })

    session = Session()
    session.auth = HTTPBasicAuth(args.username, args.password)
    transport = Transport(session=session)
    client = Client(args.wsdl, transport=transport)

    # show supported operations
    print('supported operations: {}'.format(
        ', '.join(sorted(client.service._operations.keys()))))

    # get version
    print(f'version: {client.service.getVersion()}')


if __name__ == '__main__': # code to execute if called from command-line
    parser = ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-v', '--verbose', help='Verbose (debug) logging', action='store_const', const=logging.DEBUG,
                       dest='loglevel')
    group.add_argument('-q', '--quiet', help='Silent mode, only log warnings', action='store_const',
                       const=logging.WARN, dest='loglevel')
    parser.add_argument('-w', '--wsdl', help='WSDL URL',
                        metavar='URL', required=True)
    parser.add_argument(
        '-u', '--username', help='Username, defaults to uaadmin', default="uaadmin")
    parser.add_argument('-p', '--password', help='Password',
                        metavar='PASSWORD', required=True)
    args = parser.parse_args()
    main(args)
