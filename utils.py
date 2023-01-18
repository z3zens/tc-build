#!/usr/bin/env python3
# Description: Common helper functions

import re
import subprocess
import sys


def create_gitignore(folder):
    """
    Create a gitignore that ignores all files in a folder. Some folders are not
    known until the script is run so they can't be added to the root .gitignore
    :param folder: Folder to create the gitignore in
    """
    folder.joinpath('gitignore').write_text('*\n', encoding='utf-8')


def flush_std_err_out():
    sys.stderr.flush()
    sys.stdout.flush()


def libc_is_musl():
    """
    Returns whether or not the current libc is musl or not.
    """
    # musl's ldd does not appear to support '--version' directly, as its return
    # code is 1 and it prints all text to stderr. However, it does print the
    # version information so it is good enough. Just 'check=False' it and move
    # on.
    ldd_out = subprocess.run(['ldd', '--version'],
                             capture_output=True,
                             check=False,
                             text=True)
    if re.search('musl', ldd_out.stderr if ldd_out.stderr else ldd_out.stdout):
        return True
    return False


def print_header(string):
    """
    Prints a fancy header
    :param string: String to print inside the header
    """
    # Use bold cyan for the header so that the headers
    # are not intepreted as success (green) or failed (red)
    print("\033[01;36m")
    for _ in range(0, len(string) + 6):
        print("=", end="")
    print(f"\n== {string} ==")
    for _ in range(0, len(string) + 6):
        print("=", end="")
    # \033[0m resets the color back to the user's default
    print("\n\033[0m")
    flush_std_err_out()


def print_error(string):
    """
    Prints a error in bold red
    :param string: String to print
    """
    # Use bold red for error
    print(f"\033[01;31m{string}\n\033[0m", flush=True)


def print_warning(string):
    """
    Prints a error in bold yellow
    :param string: String to print
    """
    # Use bold yellow for error
    print(f"\033[01;33m{string}\n\033[0m", flush=True)
