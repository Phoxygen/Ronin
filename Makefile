mkfile_dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

##### Variables used
# (can be overriden using command line args to make)
# Paths used in build.
BUILD_DIR:=$(abspath ${mkfile_dir}/../build)
GECKO_SOURCE_DIR=$(abspath ${mkfile_dir}/../gecko-dev)
GAIA_SOURCE_DIR=$(abspath ${mkfile_dir}/../gaia)
# Used to increment .deb package version
DATETIME=$(shell date +%d%m%y%H%M)
GECKO_VERSION=46
CUSTOM_MOZCONFIG?=
RESOLUTION=800x600
B2G_PROFILE_PATH=~/.mozilla/b2g/xsession.profile
######

##### Git repo validity check
# gecko/gaia must have the Ronin root commit
GECKO_RONIN_COMMIT=4b1114685cac9b758e923071eff5bf4350400ebd
GAIA_RONIN_COMMIT=64cf0c8cf0cf2bf15f6fef5a8e6a1eeb40e18c95
# Nice attempt but doesn't work sadly...
git_has_commit = $(shell cd $(1) && git merge-base --is-ancestor $(2) HEAD && exit 0 || exit 1)

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
	@echo "\tBUILD_DIR: absolute path to build output (default: $(abspath ${mkfile_dir}/../build))"
	@echo "\tGECKO_SOURCE_DIR: gecko git repository (default: $(abspath ${mkfile_dir}/../gecko-dev))"
	@echo "\tGAIA_SOURCE_DIR: gaia git repository (default: $(abspath ${mkfile_dir}/../gaia))"
	@echo "\tCUSTOM_MOZCONFIG: extends supplied mozconfig with user parameters (e.g: |mk_add_options MOZ_MAKE_FLAGS="-j3 -s"|)"
	@echo ""

${BUILD_DIR}:
	mkdir -p ${BUILD_DIR}

##### Install build dependencies
${BUILD_DIR}/.build_deps_ready: ${BUILD_DIR}
	python ${mkfile_dir}/bootstrap.py --application-choice desktop
	sudo apt-get install libgstreamer-plugins-bad1.0-dev \
		libgstreamer-plugins-base0.10-dev libgstreamer-plugins-base1.0-dev \
		libgstreamer1.0-dev
	touch ${BUILD_DIR}/.build_deps_ready

##### Install runtime dependencies
${BUILD_DIR}/.runtime_deps_ready:
	sudo apt install xserver-xephyr

##### Clone gecko source if missing
${GECKO_SOURCE_DIR}:
	git clone -b ronin \
		https://github.com/Phoxygen/gecko-dev ${GECKO_SOURCE_DIR}

# (Todo: check that Ronin root commit is an ancestor of the active branch)
gecko-sources: ${GECKO_SOURCE_DIR}

##### Clone gaia source if missing
${GAIA_SOURCE_DIR}:
	git clone -b ronin \
		https://github.com/Phoxygen/gaia ${GAIA_SOURCE_DIR}

# Todo: check that Ronin root commit is an ancestor of the active branch)
gaia-sources: ${GAIA_SOURCE_DIR}

sources: gecko-sources gaia-sources

##### Build gaia profile
# (The built profile lives in ${BUILD_DIR}/profile)
build-gaia:
	if [ ! -d ${BUILD_DIR}/gaia/profile ]; then mkdir -p ${BUILD_DIR}/gaia/profile; fi
	cd ${GAIA_SOURCE_DIR} && \
	DEVICE_DEBUG=1 GAIA_DEVICE_TYPE=phone DESKTOP_SHIMS=1 NOFTU=1 PROFILE_DIR=${BUILD_DIR}/gaia/profile make

${BUILD_DIR}/gaia/profile:
	$(MAKE) build-gaia

##### Prepare gecko build
# Copy mozconfig to source dir, and append custom_mozconfig if existing
# Note: 
${GECKO_SOURCE_DIR}/mozconfig: ${mkfile_dir}/mozconfig ${CUSTOM_MOZCONFIG}
	cp -v ${mkfile_dir}/mozconfig ${GECKO_SOURCE_DIR}/mozconfig
	@if [ -n "${CUSTOM_MOZCONFIG}" ]; then \
		cat ${CUSTOM_MOZCONFIG} >> ${GECKO_SOURCE_DIR}/mozconfig; \
	fi

###### Build gecko
build-gecko: ${BUILD_DIR}/.build_deps_ready ${GECKO_SOURCE_DIR}/mozconfig
	mkdir -p ${BUILD_DIR}/gecko && \
	cd ${GECKO_SOURCE_DIR} && \
	MOZ_OBJDIR=${BUILD_DIR}/gecko ./mach build && \
	MOZ_OBJDIR=${BUILD_DIR}/gecko ./mach package

${BUILD_DIR}/gecko/dist/b2g:
	$(MAKE) build-gecko

###### Build meta-goal
build: ${BUILD_DIR}/.build_deps_ready sources build-gaia build-gecko

${B2G_PROFILE_PATH}:
	mkdir -p ${B2G_PROFILE_PATH}

###### Run b2g
# Uses Xephyr to ease testing.
# It doens't depend on the build goal, instead it only relies on
# build outputs (b2g dist folder and gaia profile). Otherwise 
# running |make run| takes too much time.
# b2g depends on ~/.mozilla/b2g/xsession.profile so we need to copy
# gaia profile there
run: ${BUILD_DIR}/.runtime_deps_ready ${BUILD_DIR}/gecko/dist/b2g ${B2G_PROFILE_PATH} ${BUILD_DIR}/gaia/profile
	cp -r ${BUILD_DIR}/gaia/profile ${B2G_PROFILE_PATH}
	(Xephyr -ac -br -noreset -screen ${RESOLUTION} :2 &) && \
	cd ${BUILD_DIR}/gecko/dist/b2g/ && \
	DISPLAY=:2 ./b2g -no-remote -profile /home/pierre-eric/.mozilla/b2g/xsession.profile --screen=${RESOLUTION}

${BUILD_DIR}/gaia/profile.tar.bz2: ${BUILD_DIR}/gaia/profile
	cd ${BUILD_DIR} && \
	tar --directory gaia/profile -cjf  ${BUILD_DIR}/gaia/profile.tar.bz2 `ls gaia/profile`
		
###### Build deb package
# We need gaia profile, gecko build and a few scripts
package: build ${BUILD_DIR}/gaia/profile.tar.bz2
	if [ ! -d ${BUILD_DIR}/package/opt/b2g ]; then mkdir -p ${BUILD_DIR}/package/opt/b2g; fi
	if [ ! -d ${BUILD_DIR}/package/DEBIAN ]; then mkdir -p ${BUILD_DIR}/package/DEBIAN; fi
	if [ ! -d ${BUILD_DIR}/package/usr/share/xsessions ]; then mkdir -p ${BUILD_DIR}/package/usr/share/xsessions; fi

	cp ${BUILD_DIR}/gaia/profile.tar.bz2 ${BUILD_DIR}/package/opt/b2g/ 
	tar --directory ${BUILD_DIR}/package/opt/b2g -xjf ${BUILD_DIR}/gecko/dist/b2g-${GECKO_VERSION}.0a1.en-US.linux-x86_64.tar.bz2
	cp ${mkfile_dir}/launch.sh ${BUILD_DIR}/package/opt/b2g/
	cp ${mkfile_dir}/session.sh ${BUILD_DIR}/package/opt/b2g/
	cp ${mkfile_dir}/b2g.desktop ${BUILD_DIR}/package/usr/share/xsessions/
	sed 's/DATETIME/${DATETIME}/' ${mkfile_dir}/control > ${BUILD_DIR}/package/DEBIAN/control
	cd ${BUILD_DIR} && \
	fakeroot dpkg-checkbuilddeps package/DEBIAN/control && \
	fakeroot dpkg-deb -b package b2g_${GECKO_VERSION}.0a1-${DATETIME}_amd64.deb

clean:
	if [ -d ${BUILD_DIR} ]; then rm -rfI ${BUILD_DIR}; fi
	if [ -f ${GECKO_SOURCE_DIR}/mozconfig ]; then rm ${GECKO_SOURCE_DIR}/mozconfig; fi
