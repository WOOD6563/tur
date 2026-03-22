TERMUX_PKG_HOMEPAGE=https://www.mesa3d.org
TERMUX_PKG_DESCRIPTION="An open-source implementation of the OpenGL specification"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_LICENSE_FILE="docs/license.rst"
TERMUX_PKG_MAINTAINER="@termux-user-repository"
TERMUX_PKG_VERSION=23.0.4
TERMUX_PKG_REVISION=5
TERMUX_PKG_SRCURL=https://archive.mesa3d.org/mesa-${TERMUX_PKG_VERSION}.tar.xz
TERMUX_PKG_SHA256=ee7f2cad1c58f943ea3048e59871908900b0a656ebdcf6a309e60af4270792f6
TERMUX_PKG_DEPENDS="libandroid-shmem, libc++, libdrm, libexpat, libglvnd, libx11, libxext, libxfixes, libxshmfence, libxxf86vm, ncurses, vulkan-loader, xorg-xrandr, zlib, zstd"
TERMUX_PKG_SUGGESTS="mesa-zink-dev"
TERMUX_PKG_BUILD_DEPENDS="libllvm-11-static, libglvnd-dev, xorgproto, vulkan-headers"
TERMUX_PKG_CONFLICTS="libmesa, ndk-sysroot (<< 23b-6), mesa"
TERMUX_PKG_REPLACES="libmesa, mesa"
TERMUX_PKG_PROVIDES="mesa"

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--cmake-prefix-path $TERMUX_PREFIX/opt/libllvm-11;$TERMUX_PREFIX
-Dgbm=false
-Degl=enabled
-Dgles1=disabled
-Dgles2=enabled
-Ddri3=enabled
-Dllvm=false
-Dshared-llvm=disabled
-Dglx=dri
-Dcpp_rtti=true
-Dplatforms=x11
-Ddri-drivers=
-Dgallium-drivers=panfrost,zink,virgl
-Dvulkan-drivers=panfrost
-Dglvnd=true
-Dgallium-nine=false
-Dgallium-opencl=disabled
-Dosmesa=false
"

termux_step_pre_configure() {
	termux_setup_cmake
	termux_setup_meson

	CPPFLAGS+=" -D__USE_GNU"
	LDFLAGS+=" -landroid-shmem -ltinfo"
	LDFLAGS+=" -Wl,--undefined-version"

	_WRAPPER_BIN=$TERMUX_PKG_BUILDDIR/_wrapper/bin
	mkdir -p $_WRAPPER_BIN
	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		sed 's|@CMAKE@|'"$(command -v cmake)"'|g' \
			$TERMUX_PKG_BUILDER_DIR/cmake-wrapper.in \
			> $_WRAPPER_BIN/cmake
		chmod 0700 $_WRAPPER_BIN/cmake
	fi
	export PATH=$_WRAPPER_BIN:$PATH

	# Revert this commit on meson as it breaks custom llvm
	(cat $TERMUX_PKG_BUILDER_DIR/9999-meson-89146e84c9eab649d3847af101d61047cac45765.diff | patch -d $(dirname $TERMUX_MESON) -p1 -R) || true
}

termux_step_post_configure() {
	rm -f $_WRAPPER_BIN/cmake
}

termux_step_post_make_install() {
	# Avoid hard links
	local f1
	for f1 in $TERMUX_PREFIX/lib/dri/*; do
		if [ ! -f "${f1}" ]; then
			continue
		fi
		local f2
		for f2 in $TERMUX_PREFIX/lib/dri/*; do
			if [ -f "${f2}" ] && [ "${f1}" != "${f2}" ]; then
				local s1=$(stat -c "%i" "${f1}")
				local s2=$(stat -c "%i" "${f2}")
				if [ "${s1}" = "${s2}" ]; then
					ln -sfr "${f1}" "${f2}"
				fi
			fi
		done
	done

	# Create symlinks
	ln -sf libEGL_mesa.so ${TERMUX_PREFIX}/lib/libEGL_mesa.so.0
	ln -sf libGLX_mesa.so ${TERMUX_PREFIX}/lib/libGLX_mesa.so.0
}
