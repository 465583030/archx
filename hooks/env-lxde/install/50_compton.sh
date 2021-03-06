install_pkg compton

# comp switch script
echo '
#!/bin/bash
BACKEND=xrender

PROG=compton
STATUS=`ps nc -C $PROG | wc -l`
BENCH=""
TIME=""

if [ "x$1" == "xon" ]; then
    STATUS="1"
elif [ "x$1" == "xtest" ]; then
    STATUS="1"
    BENCH="--benchmark 400"
    TIME="time"
elif [ "x$1" == "xoff" ]; then
    STATUS="0"
elif [ -n "$1" ]; then
    echo "Options:"
    echo "on: enable composition"
    echo "off: disable composition"
    echo "test: run benchmark"
    exit 1
fi

# unredir may cause flicker, optimize fullscreen displays

if [ $STATUS = "1" ]; then
       echo "Turning xcompmgr ON"
       pkill $PROG
       $TIME $PROG $BENCH --config ~/.config/awesome/compton.cfg $OPTIONS &
       PID=$!
       if [ -n "$TIME" ] ; then
           wait $PID
       fi
else
       echo "Turning xcompmgr OFF"
       pkill $PROG &
fi

exit 0
' | $SUDO dd "of=$R/bin/comp-swich" 2>/dev/null
$SUDO chmod 755 "$R/bin/comp-swich"


