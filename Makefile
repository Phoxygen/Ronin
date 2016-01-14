mkfile_dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

##### Variables used
# (can be overriden using command line args to make)
# Paths used in build.
BUILD_DIR?=$(abspath ${mkfile_dir}/build)
GECKO_SOURCE_DIR?=$(abspath ${mkfile_dir}/gecko-dev)
GAIA_SOURCE_DIR?=$(abspath ${mkfile_dir}/gaia)
WETTY_SOURCE_DIR?=$(abspath ${mkfile_dir}/wetty)
# Used to increment .deb package version
DATETIME?=$(shell date +%d%m%y%H%M)
GECKO_VERSION?=46
CUSTOM_MOZCONFIG?=
RESOLUTION?=800x600
B2G_PROFILE_PATH?=${HOME}/.mozilla/b2g/xsession.profile
XKB_LAYOUT?=$(strip $(shell setxkbmap -query|grep layout|cut -d: -f2))
XKB_VARIANT?=$(strip $(shell setxkbmap -query|grep variant|cut -d: -f2))
PACKAGE_VERSION?=${GECKO_VERSION}.${DATETIME}
PACKAGE_DIR?=${BUILD_DIR}/package/ronin-${PACKAGE_VERSION}
######

##### Git repo validity check
# gecko/gaia must have the Ronin root commit
GECKO_RONIN_COMMIT=4b1114685cac9b758e923071eff5bf4350400ebd
GAIA_RONIN_COMMIT=64cf0c8cf0cf2bf15f6fef5a8e6a1eeb40e18c95
# Simple helper command to check that the current branch has a commit.
git_has_commit = $(shell cd $(1) && git merge-base --is-ancestor $(2) HEAD && echo "yes" || echo "no")

##### Default make goal
.DEFAULT_GOAL=build


help:
	@echo "Usage: make [command]"
	@echo ""
	@echo "Useful commands:"
	@echo ""
	@echo "\tbuild: builds Ronin (default command)"
	@echo "\trun: run Ronin in a nested X server"
	@echo "\tpackage: builds an installable .deb package"
	@echo "\tclean: delete build folders/files"
	@echo ""
	@echo "Advanced usage commands:"
	@echo ""
	@echo "\tbuild-gaia: build gaia"
	@echo "\tbuild-gecko: build gecko"
	@echo ""
	@echo "Variables affecting build process:"
	@echo ""
	@echo "\tBUILD_DIR: absolute path to build output (default: $(abspath ${mkfile_dir}/build))"
	@echo "\tGECKO_SOURCE_DIR: gecko git repository (default: $(abspath ${mkfile_dir}/gecko-dev))"
	@echo "\tGAIA_SOURCE_DIR: gaia git repository (default: $(abspath ${mkfile_dir}/gaia))"
	@echo "\tCUSTOM_MOZCONFIG: extends supplied mozconfig with user parameters (e.g: |mk_add_options MOZ_MAKE_FLAGS="-j3 -s"|)"
	@echo ""

${BUILD_DIR}:
	mkdir -p ${BUILD_DIR}

##### Install build dependencies
${BUILD_DIR}/.build_deps_ready: ${BUILD_DIR}
	python ${mkfile_dir}/bootstrap.py --application-choice desktop
	sudo apt-get install libgstreamer-plugins-bad1.0-dev \
		libgstreamer-plugins-base0.10-dev libgstreamer-plugins-base1.0-dev \
		libgstreamer1.0-dev dh-make devscripts dh-systemd
	touch ${BUILD_DIR}/.build_deps_ready

##### Install runtime dependencies
${BUILD_DIR}/.runtime_deps_ready:
	sudo apt-get install xserver-xephyr
	touch ${BUILD_DIR}/.runtime_deps_ready

##### Clone gecko source if missing
${GECKO_SOURCE_DIR}:
	git clone -b ronin \
		https://github.com/Phoxygen/gecko-dev ${GECKO_SOURCE_DIR}

gecko-sources: ${GECKO_SOURCE_DIR}
	@if [ "no" = "$(call git_has_commit,${GECKO_SOURCE_DIR},${GECKO_RONIN_COMMIT})" ]; then \
		echo "Invalid gecko repository at ${GECKO_SOURCE_DIR}. Ronin root commit is missing"; \
		exit 1; \
	fi

##### Clone gaia source if missing
${GAIA_SOURCE_DIR}:
	git clone -b ronin \
		https://github.com/Phoxygen/gaia ${GAIA_SOURCE_DIR}

gaia-sources: ${GAIA_SOURCE_DIR}
	@if [ "no" = "$(call git_has_commit,${GAIA_SOURCE_DIR},${GAIA_RONIN_COMMIT})" ]; then \
		echo "Invalid gaia repository at ${GAIA_SOURCE_DIR}. Ronin root commit is missing"; \
		exit 1; \
	fi

${WETTY_SOURCE_DIR}:
	git clone https://github.com/Phoxygen/wetty

wetty-sources: ${WETTY_SOURCE_DIR}

sources: gecko-sources gaia-sources wetty-sources

build-wetty: ${WETTY_SOURCE_DIR}
	cd ${WETTY_SOURCE_DIR} && npm install

##### Build gaia profile
# (The built profile lives in ${BUILD_DIR}/profile)
build-gaia: gaia-sources
	if [ ! -d ${BUILD_DIR}/gaia/profile ]; then mkdir -p ${BUILD_DIR}/gaia/profile; fi
	cd ${GAIA_SOURCE_DIR} && \
	DEVICE_DEBUG=1 GAIA_DEVICE_TYPE=phone DESKTOP_SHIMS=1 NOFTU=1 GAIA_DISTRIBUTION_DIR=distros/ronin PROFILE_DIR=${BUILD_DIR}/gaia/profile make

${BUILD_DIR}/gaia/profile:
	$(MAKE) build-gaia

##### Prepare gecko build
# Copy mozconfig to source dir, and append custom_mozconfig if existing
# Note: 
${GECKO_SOURCE_DIR}/mozconfig: ${mkfile_dir}/mozconfig ${CUSTOM_MOZCONFIG}
	cp -v ${mkfile_dir}/mozconfig ${GECKO_SOURCE_DIR}/mozconfig
ifdef CUSTOM_MOZCONFIG
	cat ${CUSTOM_MOZCONFIG} >> ${GECKO_SOURCE_DIR}/mozconfig;
endif

###### Build gecko
build-gecko: ${BUILD_DIR}/.build_deps_ready gecko-sources ${GECKO_SOURCE_DIR}/mozconfig
	mkdir -p ${BUILD_DIR}/gecko && \
	cd ${GECKO_SOURCE_DIR} && \
	MOZ_OBJDIR=${BUILD_DIR}/gecko ./mach build && \
	MOZ_OBJDIR=${BUILD_DIR}/gecko ./mach package

${BUILD_DIR}/gecko/dist/b2g:
	$(MAKE) build-gecko

###### Build meta-goal
build: ${BUILD_DIR}/.build_deps_ready sources build-gaia build-gecko build-wetty

${B2G_PROFILE_PATH}:
	mkdir -p ${B2G_PROFILE_PATH}

###### Run b2g
# Uses Xephyr to ease testing.
# It doesn't depend on the build goal, instead it only relies on
# build outputs (b2g dist folder and gaia profile). Otherwise 
# running |make run| takes too much time.
# b2g depends on ~/.mozilla/b2g/xsession.profile so we need to copy
# gaia profile there
run: ${BUILD_DIR}/.runtime_deps_ready ${BUILD_DIR}/gecko/dist/b2g ${B2G_PROFILE_PATH} ${BUILD_DIR}/gaia/profile
	cp -aT ${BUILD_DIR}/gaia/profile ${B2G_PROFILE_PATH}
	cd ${BUILD_DIR}/gecko/dist/b2g/ && \
	startx ./b2g -no-remote -profile ${B2G_PROFILE_PATH} --screen ${RESOLUTION} -- /usr/bin/Xephyr \
        -title "RoninOS" -ac -br -noreset -screen ${RESOLUTION} \
                -keybd ephyr,xkbmodel=evdev,xkblayout=${XKB_LAYOUT},xkbvariant=${XKB_VARIANT}
	
${BUILD_DIR}/gaia/profile.tar.bz2: ${BUILD_DIR}/gaia/profile
	cd ${BUILD_DIR} && \
	tar --directory gaia/profile -cjf  ${BUILD_DIR}/gaia/profile.tar.bz2 `ls gaia/profile`
		

clean-package:
	if [ -d ${BUILD_DIR}/package ]; then rm -rf ${BUILD_DIR}/package; fi

###### Build deb package
# We need gaia profile, gecko build and a few scripts
package: clean-package ${BUILD_DIR}/gaia/profile.tar.bz2 ${BUILD_DIR}/gecko/dist/b2g
	if [ ! -d ${PACKAGE_DIR} ]; then mkdir -p ${PACKAGE_DIR}; fi
	if [ ! -d ${PACKAGE_DIR}/wetty ]; then mkdir -p ${PACKAGE_DIR}/wetty; fi
	
	# Prepare package dir
	tar --directory ${PACKAGE_DIR} -xjf ${BUILD_DIR}/gecko/dist/b2g-${GECKO_VERSION}.0a1.en-US.linux-x86_64.tar.bz2
	cp ${BUILD_DIR}/gaia/profile.tar.bz2 ${PACKAGE_DIR} 
	cp ${mkfile_dir}/launch.sh ${PACKAGE_DIR}
	cp ${mkfile_dir}/session.sh ${PACKAGE_DIR}
	cp ${mkfile_dir}/ronin.desktop ${PACKAGE_DIR}

	cd ${WETTY_SOURCE_DIR} && cp -r app.js package.json public ${PACKAGE_DIR}/wetty

	# Generate ${PACKAGE_DIR}/debian folder
	cd ${PACKAGE_DIR} && dh_make -n -s -y -e tech@phoxygen.com

	# Add systemd file. Unit names must match package name
	# so use ronin.* for now
	cd ${WETTY_SOURCE_DIR}/systemd && \
		cp wetty.service ${PACKAGE_DIR}/debian/ronin.service && \
		cp wetty.socket ${PACKAGE_DIR}/debian/ronin.socket
	cd ${WETTY_SOURCE_DIR}/upstart && \
		cp wetty.conf ${PACKAGE_DIR}/debian/ronin.upstart

	# Fixup generated debian folder
	cp ${mkfile_dir}/debian/install ${PACKAGE_DIR}/debian
	cp ${mkfile_dir}/debian/postinst ${PACKAGE_DIR}/debian
	cp ${mkfile_dir}/debian/prerm ${PACKAGE_DIR}/debian
	sed -i '/^Build-Depends:/ s/$$/, dh-systemd/' ${PACKAGE_DIR}/debian/control
	# sed -i '/^Depends:/ s/$$/, nodejs, npm/' ${PACKAGE_DIR}/debian/control
	head -n -2  ${PACKAGE_DIR}/debian/control | tee ${PACKAGE_DIR}/debian/control
	sed -i '/^\tdh/ s/$$/--with=systemd/' ${PACKAGE_DIR}/debian/rules
	cat ${mkfile_dir}/debian/control >> ${PACKAGE_DIR}/debian/control

	# Build package
	cd ${PACKAGE_DIR} && debuild -us -uc -b

clean:
	if [ -d ${BUILD_DIR} ]; then rm -rfI ${BUILD_DIR}; fi
	if [ -f ${GECKO_SOURCE_DIR}/mozconfig ]; then rm ${GECKO_SOURCE_DIR}/mozconfig; fi
