#!/bin/bash

ls /root/configs/config.json | entr -nr bash -c "sleep 4 && cat /root/configs/config.json && cp /root/configs/config.json /root/config.json && /root/tuic -c /root/config.json"
