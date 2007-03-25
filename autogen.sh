#! /bin/sh
cd $(dirname $0)

if test "$1" = "clean"; then
	UNAME=$(uname)
	if test $UNAME = OpenBSD || test $UNAME = Darwin ; then
		ARGS="-0"
	else
		ARGS="-r0"
	fi

	find . -name Makefile.in -print0 | xargs $ARGS rm -f
	find . -name '*~' -type f -print0 | xargs $ARGS rm -f
	find . -name '*.rej' -type f -print0 | xargs $ARGS rm -f
	find . -name '*.orig' -type f -print0 | xargs $ARGS rm -f
	rm -f aclocal.m4 build-stamp changelog-stamp config.cache config.log \
		  config.status configure configure-stamp install-sh libtool missing \
		  mkinstalldirs quakeforge-config quakeforge.lsm
	rm -f compile config.guess config.sub depcomp ltmain.sh
	rm -rf autom4te.cache

	cd -
	find . -name Makefile -print0 | xargs $ARGS rm -f
	find . -name '*.o' -type f -print0 | xargs $ARGS rm -f
	find . -name '*.lo' -type f -print0 | xargs $ARGS rm -f
	find . -name '.libs' -type d -print0 | xargs $ARGS rm -rf
	find . -name '.deps' -type d -print0 | xargs $ARGS rm -rf
	find . -name '*.a' -type f -print0 | xargs $ARGS rm -f
	exit 0
fi
# Check libtoolize version, fix for Debian/Woody
if test x$(uname) = xDarwin ; then
	libtoolize=glibtoolize
else
	libtoolize=libtoolize
fi
lt=$(which $libtoolize)
if test -n "$lt" ; then
	if test -x "$lt" ; then
		LTIZE_VER=$($libtoolize --version | head -1 | sed 's/.* \([1-9][0-9]*\(\.[1-9][0-9]*\)\(\.[1-9][0-9]*\)*\).*/\1/')
		LTIZE_VER_MAJOR=$(echo $LTIZE_VER | cut -f1 -d'.')
		LTIZE_VER_MINOR=$(echo $LTIZE_VER | cut -f2 -d'.' | sed -e 's/[^0-9]//g')

		if test "$LTIZE_VER_MAJOR" -lt "1"; then
			echo "Libtool 1.4 or greater needed to build configure."
			exit 1
		fi
		if test "$LTIZE_VER_MAJOR" -eq "1" -a "$LTIZE_VER_MINOR" -lt "4" ; then
			echo "Libtool 1.4 or greater needed to build configure."
			exit 1
		fi
	fi
else
	echo Libtool not found. Sidestep SVN requires libtool to bootstrap itself.
	exit 1
fi

# Check Autoconf version
ac=$(which autoconf)
if test -n "$ac" ; then
	if test -x "$ac" ; then
		AC_VER=$(autoconf --version | head -1 | sed 's/^[^0-9]*//')
		AC_VER_MAJOR=$(echo $AC_VER | cut -f1 -d'.')
		AC_VER_MINOR=$(echo $AC_VER | cut -f2 -d'.' | sed 's/[^0-9]*$//')

		if test "$AC_VER_MAJOR" -lt "2" ; then
			echo "Autoconf 2.52 or greater needed to build configure."
			exit 1
		fi

		if test "$AC_VER_MAJOR" -eq "2" -a "$AC_VER_MINOR" -lt "52" ; then
			echo "Autoconf 2.52 or greater needed to build configure."
			exit 1
		fi
	fi
else
	echo Autoconf not found. Sidestep SVN requires autoconf to bootstrap itself.
	exit 1
fi

am=$(which automake)
if test -n "$am" ; then
	if test -x "$am" ; then
		AM_VER=$(automake --version | head -1 | sed -e 's/automake (GNU automake) //' -e 's/\-p.*$//')
		AM_VER_MAJOR=$(echo $AM_VER | cut -f1 -d.)
		AM_VER_MINOR=$(echo $AM_VER | cut -f2 -d.)
		if test "$AM_VER_MAJOR" -lt "1"; then
			echo "Automake 1.6 or greater needed to build makefiles."
			exit 1
		fi
		if test "$AM_VER_MAJOR" -eq "1" -a "$AM_VER_MINOR" -lt "6"; then
			echo "Automake 1.6 or greater needed to build makefiles."
			exit 1
		fi
	fi
else
	echo Automake not found. Sidestep SVN requires automake to bootstrap itself.
	exit 1
fi

aclocal && autoheader && $libtoolize --copy --automake && automake --foreign --add-missing --copy && autoconf
