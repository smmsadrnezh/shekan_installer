#!/bin/bash

ls /root/config.json | entr -nr bash -c "cat /root/config.json && /root/tuic -c /root/config.json && echo 'users updated'"
