#!/bin/bash

. $LKP_SRC/lib/debug.sh

# ffmpeg only support max 64 threads
fixup_ffmpeg()
{
	[[ -n "$environment_directory" ]] || return
	local target=${environment_directory}/pts/ffmpeg-2.5.0/ffmpeg
	if [[ -z $(grep -w 'NUM_CPU_CORES=64' $target) ]]; then
		sed "2a[ \$NUM_CPU_CORES -gt 64 ] && export NUM_CPU_CORES=64" -i "$target"
	fi
}

# add --allow-run-as-root to open-porous-media-1.3.1
fixup_open_porous_media()
{
	[[ -n "$environment_directory" ]] || return
	local target=${environment_directory}/pts/open-porous-media-1.3.1/open-porous-media
	sed -i 's/nice mpirun -np/nice mpirun --allow-run-as-root -np/' "$target"
}

# rebuild hpcc and add --allow-run-as-root to hpcc
# the test needs more than 2 hours
fixup_hpcc()
{
	[[ -n "$environment_directory" ]] || return

	[ -d "/usr/lib/x86_64-linux-gnu/openmpi" ] && {
		export MPI_PATH=/usr/lib/x86_64-linux-gnu/openmpi
		export MPI_INCLUDE=/usr/lib/x86_64-linux-gnu/openmpi/include
		export MPI_LIBS=/usr/lib/x86_64-linux-gnu/openmpi/lib/libmpi.so
		export MPI_CC=/usr/bin/mpicc.openmpi
		export MPI_VERSION=`$MPI_CC -showme:version 2>&1 | grep MPI | cut -d "(" -f1  | cut -d ":" -f2`
		phoronix-test-suite force-install pts/hpcc-1.2.1
	}

	local target=${environment_directory}/pts/hpcc-1.2.1/hpcc
	sed -i 's/mpirun -np/mpirun --allow-run-as-root -np/' "$target"
}

# add --allow-run-as-root to lammps
fixup_lammps()
{
	[[ -n "$environment_directory" ]] || return
	local target=${environment_directory}/pts/lammps-1.0.1/lammps
	sed -i 's/mpirun -np/mpirun --allow-run-as-root -np/' "$target"
}

# add --allow-run-as-root to npb
fixup_npb()
{
	[[ -n "$environment_directory" ]] || return
	local target=${environment_directory}/pts/npb-1.2.4/npb
	sed -i 's/mpiexec -np/mpiexec --allow-run-as-root -np/' "$target"
}

# start nginx and disable ipv6
fixup_nginx()
{
	[[ -n "$environment_directory" ]] || return
	sed -i 's/^::1/#::1/' /etc/hosts
	${environment_directory}/pts/nginx-1.1.0/nginx_/sbin/nginx
	sleep 5
}

# default to test 1m
fixup_fio()
{
	[[ -n "$environment_directory" ]] || return
	mount_partition || die "mount partition failed"
	mount --bind $mnt ${environment_directory}/pts/fio-1.8.2/ || die "failed to mount fio directory"

	phoronix-test-suite force-install pts/fio-1.8.2
	local target=${environment_directory}/pts/fio-1.8.2/fio-run
	sed -i 's,#!/bin/sh,#!/bin/dash,' "$target"

	# Choose
	# 1: Sequential Write
	# 2: Libaio
	# 3: Test All Options
	# 4: Test All Options
	# 5: 1MB
	# 6: Default Test Directory
	# 7: Test All Options
	test_opt="\n4\n3\n3\n3\n9\n1\n3\nn"
}

# change to use dash to bullet
fixup_bullet()
{
	[[ -n "$environment_directory" ]] || return
	phoronix-test-suite force-install pts/bullet-1.2.2
	local target=${environment_directory}/pts/bullet-1.2.2/bullet
	sed -i 's,#!/bin/sh,#!/bin/dash,' "$target"
}

# add bookpath option
fixup_crafty()
{
	[[ -n "$environment_directory" ]] || return
	local target=${environment_directory}/pts/crafty-1.3.1/crafty
	sed -i 's,crafty $@,crafty bookpath=/usr/share/crafty/ $@,' "$target"
}

run_test()
{
	local test=$1
	case $test in
		systester-[0-9]*)
			# Choose
			# 1: Gauss-Legendre algorithm [Recommended.]
			# 2: 16 Million Digits [This Test could take a while to finish.]
			# 3: 4 threads [2+ Cores Recommended]
			# todo: select different test according to testbox's hardware
			test_opt="\n1\n2\n3\nn"
			;;
		iozone-1.9.0)
			# Choose
			# 1: 1MB
			# 2: 2GB
			# 3: Test All Options
			test_opt="\n3\n2\n3\nn"
			;;
		ut2004-demo-1.2.0)
			# Choose
			# 1: ONS-Torlan Botmatch
			# 2: 800 x 600
			test_opt="\n6\n1\nn"
			export DISPLAY=:0
			;;
		nginx-1.1.0)
			fixup_nginx || die "failed to fixup test nginx"
                        ;;
		ffmpeg-2.5.0)
			fixup_ffmpeg || die "failed to fixup test ffmpeg"
			;;
		lammps-1.0.1)
			fixup_lammps || die "failed to fixup test lammps"
			;;
		npb-1.2.4)
			fixup_npb || die "failed to fixup test npb"
			;;
		bullet-1.2.2)
			fixup_bullet || die "failed to fixup test bullet"
			;;
		fio-1.8.2)
			fixup_fio || die "failed to fixup test fio"
			;;
		hpcc-1.2.1)
			fixup_hpcc || die "failed to fixup test hpcc"
			;;
		open-porous-media-1.3.1)
			fixup_open_porous_media || die "failed to fixup test open-porous-media"
			;;
		crafty-1.3.1)
			fixup_crafty || die "failed to fixup crafty"
			;;
		glmark2-1.1.0|openarena-1.5.3|gputest-1.3.1|supertuxkart-1.3.0)
			export DISPLAY=:0
			;;
	esac

	export PTS_SILENT_MODE=1
	echo PTS_SILENT_MODE=$PTS_SILENT_MODE

	## this is to avoid to write the tmp "test-results" to disk
	mount -t tmpfs tmpfs /var/lib/phoronix-test-suite/test-results || die "failed to mount tmpfs"

	if [ "$test_opt" ]; then
		echo -e "$test_opt" | log_cmd phoronix-test-suite run $test
	else
		echo n | log_cmd phoronix-test-suite default-run $test
	fi
}
