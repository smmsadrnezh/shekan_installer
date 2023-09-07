#!/bin/bash

ls /root/config.json | entr -nr bash -c "/root/tuic -c /root/config.json && echo 'users updated'"
