#!/bin/bash
# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and

# Env says we're using SSL
if [ -n "${ENABLE_SSL+1}" ] && [ "${ENABLE_SSL,,}" = "true" ]; then
  echo "Enabling SSL..."
  cp /usr/src/proxy_ssl.conf /etc/nginx/conf.d/proxy.conf
else
  # No SSL
  cp /usr/src/proxy_nossl.conf /etc/nginx/conf.d/proxy.conf
fi

# If an htpasswd file is provided, download and configure nginx
if [ -n "${ENABLE_BASIC_AUTH+1}" ] && [ "${ENABLE_BASIC_AUTH,,}" = "true" ]; then
  echo "Enabling basic auth..."
  sed -i "s/#auth_basic/auth_basic/g;" /etc/nginx/conf.d/proxy.conf
fi

# If an INCLUDE file is provided, include it
if [ -n "${INCLUDE+1}" ]; then
  echo "Enabling include..."
  sed -i "s/#include/include/g;" /etc/nginx/conf.d/proxy.conf
  sed -i "s/{{INCLUDE}}/${INCLUDE}/g;" /etc/nginx/conf.d/proxy.conf
fi

# Allow intranet and deny all other
if [ -n "${ALLOW_INTRANET+1}" ] && [ "${ALLOW_INTRANET,,}" = "true" ]; then
  echo "Allowing access for intranet..."
  sed -i "s/#intranet-allow/allow/g;" /etc/nginx/conf.d/proxy.conf
  ALLOW_DENY_FALLBACK='deny'
fi

# Trust internal proxies to define user ip
if [ -n "${SET_REAL_IP_FROM_INTRANET+1}" ] && [ "${SET_REAL_IP_FROM_INTRANET,,}" = "true" ]; then
  echo "Using intranet proxies to find user ip..."
  sed -i "s/#intranet-set_real_ip_from/set_real_ip_from/g;" /etc/nginx/conf.d/proxy.conf
fi

# Trust proxy to define user ip
if [ -n "${SET_REAL_IP_FROM+1}" ]; then
  echo "Setting trustable proxy..."
  sed -i "s/#set_real_ip_from/set_real_ip_from/g;" /etc/nginx/conf.d/proxy.conf
  sed -i "s/{{SET_REAL_IP_FROM}}/${SET_REAL_IP_FROM}/g;" /etc/nginx/conf.d/proxy.conf
fi

# Setting header name to read user ip from
if [ -n "${REAL_IP_HEADER+1}" ]; then
  echo "Setting header name to read user ip from..."
  sed -i "s/#real_ip_header/real_ip_header/g;" /etc/nginx/conf.d/proxy.conf
  sed -i "s/{{REAL_IP_HEADER}}/${REAL_IP_HEADER}/g;" /etc/nginx/conf.d/proxy.conf
fi

# Trust proxies recursive to define user ip
if [ -n "${REAL_IP_RECURSIVE+1}" ]; then
  echo "Trusting proxies recursive..."
  sed -i "s/#real_ip_recursive/real_ip_recursive/g;" /etc/nginx/conf.d/proxy.conf
  sed -i "s/{{REAL_IP_RECURSIVE}}/${REAL_IP_RECURSIVE}/g;" /etc/nginx/conf.d/proxy.conf
fi

# Allow access via ip or account
if [ -n "${SATISFY_ANY+1}" ] && [ "${SATISFY_ANY,,}" = "true" ]; then
  echo "Allowing access for ip based or login authenticated users..."
  sed -i "s/#satisfy-any/satisfy/g;" /etc/nginx/conf.d/proxy.conf
fi

# Allowing access
if [ -n "${ALLOW+1}" ]; then
  echo "Allowing defined ip..."
  sed -i "s/#allow/allow/g;" /etc/nginx/conf.d/proxy.conf
  sed -i "s/{{ALLOW}}/${ALLOW}/g;" /etc/nginx/conf.d/proxy.conf
fi

# Denying access
if [ -n "${DENY+1}" ]; then
  echo "Denying defined ip..."
  sed -i "s/#deny/deny/g;" /etc/nginx/conf.d/proxy.conf
  sed -i "s/{{DENY}}/${DENY}/g;" /etc/nginx/conf.d/proxy.conf
fi

# allow/deny default behavior
if [ -n "${ALLOW_DENY_FALLBACK+1}" ]; then
  echo "Setting up default allow/deny behavior..."
  sed -i "s/#{{ALLOW_DENY_FALLBACK}}/${ALLOW_DENY_FALLBACK}/g;" /etc/nginx/conf.d/proxy.conf
fi

# If the SERVICE_HOST_ENV_NAME and SERVICE_PORT_ENV_NAME vars are provided,
# there are two options:
#  - Option 1:
# they point to the env vars set by Kubernetes that contain the actual
# target address and port. Override the default with them.
#  - Option 2:
# they point to a host and port accessible from the container, respectively,
# as in a multi-container pod scenario in Kubernetes.
# E.g.
#    - SERVICE_HOST_ENV_NAME=localhost
#    - SERVICE_PORT_ENV_NAME=8080
if [ -n "${SERVICE_HOST_ENV_NAME+1}" ]; then
  # get value of the env variable in SERVICE_HOST_ENV_NAME as host, if that's not set,
  # SERVICE_HOST_ENV_NAME has the host value
  TARGET_SERVICE=${!SERVICE_HOST_ENV_NAME:=$SERVICE_HOST_ENV_NAME}
fi
if [ -n "${SERVICE_PORT_ENV_NAME+1}" ]; then
  # get value of the env variable in SERVICE_PORT_ENV_NAME as port, if that's not set,
  # SERVICE_PORT_ENV_NAME has the port value
  TARGET_SERVICE="$TARGET_SERVICE:${!SERVICE_PORT_ENV_NAME:=$SERVICE_PORT_ENV_NAME}"
fi

# Tell nginx the address and port of the service to proxy to
sed -i "s/{{TARGET_SERVICE}}/${TARGET_SERVICE}/g;" /etc/nginx/conf.d/proxy.conf

echo "Starting nginx..."
nginx -g 'daemon off;'
