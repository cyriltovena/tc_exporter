#! /bin/sh

IFACE="$2"

# (Ethernet) Interface Speed
ETH_RATE="1000000"
# Internet Line Rate
INET_MAX="$3"

TC="/sbin/tc"
PY="/usr/bin/python3"

QOS_RATIO_C2="0.95" # Maximum internet speed
  QOS_RATIO_C11="0.4" # Priority 1
  QOS_RATIO_C12="0.4" # Priority 2
  QOS_RATIO_C13="0.2" # Other
    QOS_RATIO_C21="0.70" # tcp/80, tcp/443, tcp/21
      QOS_RATIO_C31="0.7" # Browsing
      QOS_RATIO_C32="0.3" # Downloading
    QOS_RATIO_C22="0.10" # Thrash
    QOS_RATIO_C23="0.20" # Crew
QOS_RATIO_C3="0.2" # Reserved for interface communication (e.g. L2, routing protocols)

tc_flush() {
  $TC qdisc del dev ${IFACE} root
  return 0
}

tc_commit() {

while [ ! -e /sys/class/net/${IFACE}/operstate ]; do
  sleep 1
done

if [ -z "$INET_MAX" ]; then
  echo "Target rate is not specified, aborting."
  exit 1
fi

RATE_C1=${ETH_RATE} # Maximum interface speed
  RATE_C2=`$PY -c 'from math import ceil; print("%.0f" % ceil('${INET_MAX}' * '${QOS_RATIO_C2}'))'` # Maximum internet speed
    RATE_C11=`$PY -c 'from math import ceil; print("%.0f" % ceil('${RATE_C2}' * '${QOS_RATIO_C11}'))'` # Priority 1
    RATE_C12=`$PY -c 'from math import ceil; print("%.0f" % ceil('${RATE_C2}' * '${QOS_RATIO_C12}'))'` # Priority 2
    RATE_C13=`$PY -c 'from math import ceil; print("%.0f" % ceil('${RATE_C2}' * '${QOS_RATIO_C13}'))'` # Other
      RATE_C21=`$PY -c 'from math import ceil; print("%.0f" % ceil('${RATE_C13}' * '${QOS_RATIO_C21}'))'` # tcp/80, tcp/443, tcp/21
        RATE_C31=`$PY -c 'from math import ceil; print("%.0f" % ceil('${RATE_C21}' * '${QOS_RATIO_C31}'))'` # Browsing
        RATE_C32=`$PY -c 'from math import ceil; print("%.0f" % ceil('${RATE_C21}' * '${QOS_RATIO_C32}'))'` # Downloading
      RATE_C22=`$PY -c 'from math import ceil; print("%.0f" % ceil('${RATE_C13}' * '${QOS_RATIO_C22}'))'` # Thrash
      RATE_C23=`$PY -c 'from math import ceil; print("%.0f" % ceil('${RATE_C13}' * '${QOS_RATIO_C23}'))'` # Crew
  RATE_C3=`$PY -c 'from math import ceil; print("%.0f" % ceil('${ETH_RATE}' * '${QOS_RATIO_C3}'))'` # Reserved for interface communication (e.g. L2, routing protocols)

  echo ${RATE_C1}' | Maximum interface speed'
  echo '   '${RATE_C2}' | Maximum internet speed'
  echo '        '${RATE_C11}' | Priority 1 | DSCP AF41'
  echo '        '${RATE_C12}' | Priority 2 | DSCP AF42'
  echo '        '${RATE_C13}' | Other'
  echo '            '${RATE_C21}' | tcp/80, tcp/443, tcp/21'
  echo '                '${RATE_C31}' | Browsing | DSCP AF31'
  echo '                '${RATE_C32}' | Downloading | DSCP AF32'
  echo '            '${RATE_C22}' | Trash | DSCP Best Effort'
  echo '            '${RATE_C23}' | Crew | DSCP AF21'
  echo '   '${RATE_C3}' | Reserved for interface communication'

  $TC qdisc add dev ${IFACE} stab linklayer ethernet mtu 1500 root handle 1: hfsc default 3
  $TC class add dev ${IFACE} parent 1: classid 1:1 hfsc sc rate ${RATE_C1}kbit ul rate ${RATE_C1}kbit
  $TC class add dev ${IFACE} parent 1:1 classid 1:2 hfsc sc rate ${RATE_C2}kbit ul rate ${RATE_C2}kbit
    $TC class add dev ${IFACE} parent 1:2 classid 1:11 hfsc sc rate ${RATE_C11}kbit
      $TC qdisc add dev ${IFACE} parent 1:11 handle 11: fq_codel noecn limit 1200 flows 65535 target 5ms
    $TC class add dev ${IFACE} parent 1:2 classid 1:12 hfsc sc dmax 60ms rate ${RATE_C12}kbit
      $TC qdisc add dev ${IFACE} parent 1:12 handle 12: fq_codel noecn limit 1200 flows 65535 target 5ms
    $TC class add dev ${IFACE} parent 1:2 classid 1:13 hfsc ls dmax 100ms rate ${RATE_C13}kbit
      $TC class add dev ${IFACE} parent 1:13 classid 1:21 hfsc ls rate ${RATE_C21}kbit
        $TC class add dev ${IFACE} parent 1:21 classid 1:31 hfsc sc rate ${RATE_C31}kbit
          $TC qdisc add dev ${IFACE} parent 1:31 handle 31: fq_codel noecn limit 1200 flows 65535 target 5ms
        $TC class add dev ${IFACE} parent 1:21 classid 1:32 hfsc ls dmax 10ms rate ${RATE_C32}kbit
          $TC qdisc add dev ${IFACE} parent 1:32 handle 32: fq_codel noecn limit 1200 flows 65535 target 5ms
      $TC class add dev ${IFACE} parent 1:13 classid 1:22 hfsc ls dmax 50ms rate ${RATE_C22}kbit
        $TC qdisc add dev ${IFACE} parent 1:22 handle 22: fq_codel noecn limit 1200 flows 65535 target 5ms
      $TC class add dev ${IFACE} parent 1:13 classid 1:23 hfsc ls rate ${RATE_C23}kbit
        $TC qdisc add dev ${IFACE} parent 1:23 handle 23: fq_codel noecn limit 1200 flows 65535 target 5ms
  $TC class add dev ${IFACE} parent 1:1 classid 1:3 hfsc ls rate ${RATE_C3}kbit
    $TC qdisc add dev ${IFACE} parent 1:3 handle 3: fq_codel noecn limit 1200 flows 65535 target 5ms

  $TC filter add dev ${IFACE} parent 1: protocol arp basic classid 1:3
  $TC filter add dev ${IFACE} parent 1: u32 match mark 0x1 0xf classid 1:11 # DSCP AF41
  $TC filter add dev ${IFACE} parent 1: u32 match mark 0x2 0xf classid 1:12 # DSCP AF42
  $TC filter add dev ${IFACE} parent 1: u32 match mark 0x3 0xf classid 1:31 # DSCP AF31
  $TC filter add dev ${IFACE} parent 1: u32 match mark 0x4 0xf classid 1:32 # DSCP AF32
  $TC filter add dev ${IFACE} parent 1: u32 match mark 0x5 0xf classid 1:23 # DSCP AF21
  $TC filter add dev ${IFACE} parent 1: u32 match mark 0x6 0xf classid 1:22 # DSCP Best Effort
  $TC filter add dev ${IFACE} parent 1: handle 13 fw classid 1:3

  return 0
}

case "$1" in
  start)
    echo "Committing TC ruleset for $IFACE"
    if tc_commit; then
      echo "Successfully committed ruleset for $IFACE"
      exit 0
    else
      echo "Error committing ruleset for $IFACE" >&2
      exit 1
    fi
    ;;
  stop)
    echo "Flushing TC rules for $IFACE"
    if tc_flush; then
      echo "Successfully flushed ruleset for $IFACE"
      exit 0
    else
      echo "Error flushing ruleset for $IFACE" >&2
      exit 1
    fi
    ;;

  *)
    echo "Usage: $0 {start|stop} [interface] [speed(kbit)]"
    exit 1
esac

exit 0
