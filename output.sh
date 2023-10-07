#!/bin/sh
echo 1 stderr >&2
sleep 1
echo 2 stdout
sleep 1
echo 3 stderr >&2
sleep 1
echo 4 stdout