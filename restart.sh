#!/bin/bash
./stop.sh "$1"
sleep 2
./start.sh "$1"