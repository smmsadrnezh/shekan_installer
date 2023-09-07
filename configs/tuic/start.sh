#!/bin/bash

ls /root/config.json | entr -nr bash -c "sleep 1 && /root/tuic -c /root/config.json && echo 'users updated'"
