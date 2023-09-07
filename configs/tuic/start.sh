#!/bin/bash

ls /root/config.json | entr -nr bash -c "sleep 1 && cp /root/config.json && /root/tuic -c /root/config.json && echo 'users updated'"
