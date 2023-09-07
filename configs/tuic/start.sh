#!/bin/bash

ls /root/configs/config.json | entr -nr bash -c "cp /root/configs/config.json /root/config.json && /root/tuic -c /root/config.json && echo 'config updated'"
