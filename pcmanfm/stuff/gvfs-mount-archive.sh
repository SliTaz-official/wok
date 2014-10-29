#!/bin/sh
# gvfs-mount-archive: simple wrapper for PCManFM action "Mount archive"

gvfs-mount "archive://$(echo "$1" | sed 's|:|%3A|g;s|/|%2F|g')"
