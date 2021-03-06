#! /bin/sh
#
# Shell script to integrate madwifi sources into a Linux
# source tree so it can be built statically.  Typically this
# is done to simplify debugging with tools like kgdb.
#

set -e

die()
{
	echo "FATAL ERROR: $1" >&2
	exit 1
}

SRC=..
KERNEL_VERSION=$(uname -r)

if test -n "$1"; then
	KERNEL_PATH="$1"
else if test -e /lib/modules/${KERNEL_VERSION}/source; then
	KERNEL_PATH="/lib/modules/${KERNEL_VERSION}/source"
else if test -e /lib/modules/${KERNEL_VERSION}/build; then
	KERNEL_PATH="/lib/modules/${KERNEL_VERSION}/build"
else
	die "Cannot guess kernel source location"
fi
fi
fi

test -d ${KERNEL_PATH} || die "No kernel directory ${KERNEL_PATH}"

PATCH()
{
	patch -N $1 < $2
}

#
# Location of various pieces.  These mimic what is in Makefile.inc
# and can be overridden from the environment.
#
SRC_HAL=${HAL:-${SRC}/ath_hal}
test -d ${SRC_HAL} || die "No ath_hal directory ${SRC_HAL}"
SRC_NET80211=${WLAN:-${SRC}/net80211}
test -d ${SRC_NET80211} || die "No net80211 directory ${SRC_NET80211}"
SRC_ATH=${ATH:-${SRC}/ath}
test -d ${SRC_ATH} || die "No ath directory ${SRC_ATH}"
SRC_ATH_RATE=${SRC}/ath_rate
test -d ${SRC_ATH_RATE} ||
	die "No rate control algorithm directory ${SRC_ATH_RATE}"
SRC_COMPAT=${SRC}/include
test -d ${SRC_COMPAT} || die "No compat directory ${SRC_COMPAT}"

WIRELESS=${KERNEL_PATH}/drivers/net/wireless
test -d ${WIRELESS} || die "No wireless directory ${WIRELESS}"

echo "Copying top-level files"
MADWIFI=${WIRELESS}/madwifi
rm -rf ${MADWIFI}
mkdir -p ${MADWIFI}
cp -f ${SRC}/BuildCaps.inc ${SRC}/release.h ${MADWIFI}


echo "Copying source files"
FILES=$(cd ${SRC} && find ath ath_hal ath_rate include net80211 -name '*.[ch]')
FILES="$FILES $(cd ${SRC} && find ath_hal -name '*.ini')"
for f in $FILES; do
	case $f in
		*.mod.c) continue;;
	esac
	mkdir -p $(dirname ${MADWIFI}/$f)
	cp -f ${SRC}/$f ${MADWIFI}/$f
done

echo "Copying makefiles"
FILES=$(cd ${SRC} && find . -name Makefile.kernel)
for f in $FILES; do
	cp -f ${SRC}/$f $(dirname ${MADWIFI}/$f)/Makefile
done


echo "Patching the build system"
cp -f Kconfig ${MADWIFI}
sed -i '/madwifi/d;/^endmenu/i\
source "drivers/net/wireless/madwifi/Kconfig"' ${WIRELESS}/Kconfig
sed -i '$a\
obj-$(CONFIG_ATHEROS) += madwifi/
/madwifi/d;' ${WIRELESS}/Makefile

echo "Done"
