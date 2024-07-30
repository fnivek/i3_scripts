#!/usr/bin/env python3

import click
import i3ipc

# TODO(Kevin): Get these files from nix or make in /var /etc somewhere.
workspace_file = "/home/kdfrench/.config/i3/resources/workspaces.txt"
last_pose_in_workspace_file = "/home/kdfrench/.config/i3/resources/last_pose_in_workspace.txt"


def get_ws_second_key(ws):
    key = 0
    try:
        key = int(ws.name.split(':')[1])
    except (ValueError, IndexError):
        pass
    return key


def get_ws_third_key(ws):
    key = ''
    try:
        key = ws.name.split(':')[2]
    except IndexError:
        pass
    return key

def read_last_workspace():
    last_workspace = {}
    with open(last_pose_in_workspace_file) as file:
        last_workspace = {workspace: int(num) for workspace, num in [line.strip().split(':') for line in file]}
    return last_workspace

def write_last_workspace(last_workspace):
    with open(last_pose_in_workspace_file, 'w') as file:
        for key, value in last_workspace.items():
            file.write(f'{key}:{value}\n')

@click.command()
@click.argument('workspace', type=str)
@click.option('-m', '--move', is_flag=True, help='Move the focus window')
@click.option('-f', '--follow', is_flag=True,
                        help='If moving then follow the moved window')
def main(workspace, move, follow):
    """WORKSPACE to go to.
    
    WORKSPACE [up, down - move to the next/prev workspace set |
    next, prev - move to the next/prev number in current workspace set |
    #]
    """

    # I3 interface
    i3 = i3ipc.Connection()

    # Workspace files
    named_workspaces = []
    with open(workspace_file) as file:
        named_workspaces = [line.strip() for line in file]
    last_workspace = read_last_workspace()

    # Get workspaces and sort them
    offset = 1000
    workspaces = i3.get_workspaces()
    workspaces.sort(key=lambda ws: (ws.num, get_ws_second_key(ws)))
    current_workspace = next(filter(lambda ws: ws.focused, workspaces))
    current_ws_name = get_ws_third_key(current_workspace)
    try:
        name_index = named_workspaces.index(current_ws_name)
    except (IndexError, ValueError):
        name_index = 0
    current_named_workspaces = list(filter(lambda ws: get_ws_third_key(ws) == current_ws_name, workspaces))
    index = current_named_workspaces.index(current_workspace)

    # Handle previous
    to_name = current_workspace.name
    if workspace == 'prev':
        to_name = current_named_workspaces[index - 1].name
    # Handle next
    elif workspace == 'next':
        to_name = current_named_workspaces[(index + 1) % len(current_named_workspaces)].name
    # Handle up
    if workspace == 'up':
        index = (name_index - 1) % len(named_workspaces)
        name = named_workspaces[index]
        try:
            key2 = last_workspace[name]
        except KeyError:
            key2 = get_ws_second_key(current_workspace)
        to_name = '{}:{}:{}'.format(index * offset + key2, key2, name)
    # Handle down
    if workspace == 'down':
        index = (name_index + 1) % len(named_workspaces)
        name = named_workspaces[index]
        try:
            key2 = last_workspace[name]
        except KeyError:
            key2 = get_ws_second_key(current_workspace)
        to_name = '{}:{}:{}'.format(index * offset + key2, key2, name)
    # Handle number
    else:
        try:
            num = int(workspace)
            to_name = '{}:{}:{}'.format(name_index * offset + num,
                                        num,
                                        current_ws_name)
        except ValueError:
            pass

    # Save last workspace
    _, num, name = to_name.split(':')
    last_workspace[name] = num
    write_last_workspace(last_workspace)

    # Move
    if move:
        i3.command('move container to workspace {}'.format(to_name))
        if follow:
            i3.command('workspace {}'.format(to_name))
    else:
        # Switch workspace
        i3.command('workspace {}'.format(to_name))


if __name__ == '__main__':
    main()
