#!/bin/sh
sed -r -i "s/kubernetes.ip\:\s+'(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b'"/"kubernetes.ip\: '$(kubectl config view --minify | grep server | cut -f 3 -d ":" | tr -d "/")'"/ demo-app-config-map.yml
