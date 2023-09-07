#!/bin/bash

ls /root/config-org.json | entr -nr bash -c "sleep 4 && cat /root/config-org.json && cp /root/config-org.json /root/config.json && /root/tuic -c /root/config.json && echo 'users updated'"
