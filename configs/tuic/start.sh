#!/bin/bash

ls /root/config.json | entr -nr bash -c "ls /root/tuic && /root/tuic -c /root/config.json && echo 'users updated'"
