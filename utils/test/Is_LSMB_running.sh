#!/bin/bash

source utils/test/sysexits.shlib

HELP() {
    E=${1:-$EX_USAGE}; shift;
    cat <<-EOF
	$@
	Script Is_LSMB_running.sh
	    Checks that Starman/Plack is running
	    and that the static html for setup.pl hasn't changed significantly.
	    Significant changes could indicate an error page instead of setup.pl
	
	USAGE:
	    utils/test/Is_LSMB_running.sh [--help]
	    utils/test/Is_LSMB_running.sh [--update] [MaxDiff]
	
	          --help : This Help message
	        --update : update the reference file 't/data/Is_LSMB_running.html'
	         MaxDiff : Maximum number of lines the Current setup.pl
	                     and 't/data/Is_LSMB_running.html' may differ by
	                   This should always be a number greater than 1 to allow for
	                     variations in the list of available db admin users
	
	
	EOF
    exit $E;
}

if [[ $1 == '--help' ]]; then HELP $EX_OK; shift; fi
if [[ $1 == '--update' ]]; then UPDATE=true; shift; else UPDATE=false; fi
if (( ${#@} >1 )); then shift; HELP $EX_USAGE "unknown argument $@"; fi # we should have zero or one arguments left at this point.
MaxDiff=${1:-1};    # maximum number of added or removed lines in the setup.pl static html
                    # Must always be greater than 1 to allow for site variations in admin users
if [[ $MaxDiff =~ "^[0-9]+$" ]]; then HELP $EX_USAGE "Final Argument 'MaxDiff' ($MaxDiff) must be a number $MaxDiff"; fi # MaxDiff Must be an integer
if (( MaxDiff < 1 )); then HELP $EX_USAGE "Final Argument 'MaxDiff' ($MaxDiff) must be greater than 0"; fi # MaxDiff Must be greater than zero

src='t/data/Is_LSMB_running.html'
current='/tmp/Is_LSMB_running.html'

DIE() {
    E=$1; shift;
    T=$1; shift
    echo '=============================================';
    echo "$T";
    echo '=============================================';
    echo "$@";
    echo '=============================================';
    exit $E;
}

DUMPfile() {
    echo "== $1";
    if [[ -r "$1" ]]; then
        cat -v "$1";
    fi
    echo '=============================';
}

if curl --progress-bar localhost:5001/setup.pl 2>/tmp/Is_LSMB_running.log >/tmp/Is_LSMB_running.html ; then
    echo "Starman/Plack is Running";
else    # fail early if starman is not running
    E=$?;
    echo '=============================';
    echo "  Starman/plack Not running";
    echo '=============================';
    DUMPfile /tmp/Is_LSMB_running.log
    DUMPfile /tmp/Is_LSMB_running.html
    DUMPfile /tmp/plackup-error.log;
    exit $E;
fi

if $UPDATE; then
    echo 'Capturing new version of setup.pl'
    cp $current $src
fi

# fail if the static html generated by setup.pl has changed by more than $MaxDiff Lines
DIFF=`diff -u0 $src $current`
CNTadd=`echo -e "$DIFF" | grep -c '^[+][^+].*$'`
CNTdel=`echo -e "$DIFF" | grep -c '^[-][^-].*$'`
if (( CNTadd > MaxDiff )); then DIE $EX_DATAERR "Added too many Lines ($CNTadd) to setup.pl.html" "$DIFF"; fi
if (( CNTdel > MaxDiff )); then DIE $EX_DATAERR "Removed too many Lines ($CNTdel) from setup.pl.html" "$DIFF"; fi

