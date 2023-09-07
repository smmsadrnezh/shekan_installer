#!/bin/bash

ls /root/configs/config-org.json | entr -nr bash -c "sleep 4 && cat /root/configs/config-org.json && cp /root/configs/config-org.json /root/config.json && /root/tuic -c /root/config.json"
