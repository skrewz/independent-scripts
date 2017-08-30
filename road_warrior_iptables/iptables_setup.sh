#!/bin/bash
# Insist that traffic from human accounts goes through $tunneldev.
#
# This is meant for e.g. public wifi's, where you would rather have
# user-generated traffic not be sent than egress through the insecure wifi.

tunneldev="tun0"

# Configured user accounts to limit:
users=( "skrewz" "debian-tor")
# (A nice TODO here might be to have a group control this: membership of it
# means you would be limited.)


set -o errexit -o nounset -o pipefail
trap 'echo "Error occured in subcommand @ ${BASH_SOURCE[0]}:$LINENO."; exit 1;' ERR


function ipt ()
{ # {{{
  # simple redirect shorthand:
  /sbin/iptables "$@"
} # }}}
function remove_temporary_safety_disable ()
{ # {{{
  # re-enable traffic after setting up specific rules:
  ipt -P OUTPUT ACCEPT
  # Certain kinds of traffic will be disallowed, but outbound-to-loopback will
  # always be considered okay:
  ipt -I OUTPUT -o lo -j ACCEPT

  ipt -A INPUT -i lo -j ACCEPT
  ipt -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ipt -A INPUT -m tcp -p tcp --dport 22 -j ACCEPT
} # }}}
function cleanup_and_safety_disable ()
{ # {{{

  # Disable output traffic while script runs:
  ipt -P OUTPUT DROP
  ipt -F OUTPUT

  ipt -P INPUT DROP
  ipt -F INPUT

  for user in "${users[@]}"; do
    chain="output-for-$user"

    # squelched; may not exist
    ipt -F "$chain" &>/dev/null || true
    ipt -X "$chain" &>/dev/null || true
  done
} # }}}
function set_up_user_based_traffic_rejection()
{ # {{{
  # clear anything that might be set up:

  for user in "${users[@]}"; do
    chain="output-for-$user"

    # route outbound traffic for $user to $chain:
    ipt -N "$chain"
    ipt -A OUTPUT -m owner --uid-owner "$user" -j "$chain"

    # reasons for traffic to be allowed: (could be ACCEPT if OUTPUT policy is reject)
    ipt -A "$chain" -o "$tunneldev" -j RETURN

    # if not allowed, reject and log
    ipt -A "$chain" -j LOG --log-prefix "Disallowed $user egress: "
    ipt -A "$chain" -j REJECT

  done
} # }}}
function set_up_ingress_restrictions()
{ # {{{
  # clear anything that might be set up:
  ipt -P INPUT DROP
  ipt -F INPUT

} # }}}


cleanup_and_safety_disable

if [ "$#" -lt 1 ] || [ "--disable" != "$1" ]; then
  set_up_user_based_traffic_rejection
fi

set_up_ingress_restrictions

remove_temporary_safety_disable

# vim: fdm=marker fml=1
