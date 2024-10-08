#!/usr/bin/env python3

from argparse import ArgumentParser
from i3_focus.tools import Sockets

def main():
    parser = ArgumentParser(prog='i3-app-focus.py',
                            description='''
            i3-app-focus.py is dmenu-based script for creating dynamic app switcher.
            '''
    )
    parser.add_argument('--socket-file', default='/tmp/i3-app-focus.socket', help='Socket file path')
    (args, _) = parser.parse_known_args()

    sockets = Sockets(args.socket_file)
    sockets.next()


if __name__ == '__main__':
    main()
