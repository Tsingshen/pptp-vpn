#!/bin/bash
docker run -d --privileged --net=host -v /root/pptp_secrets:/etc/ppp/chap-secrets mobtitude/vpn-pptp
