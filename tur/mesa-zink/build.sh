TERMUX_PKG_HOMEPAGE=https://www.mesa3d.org
TERMUX_PKG_DESCRIPTION="An open-source implementation of the OpenGL specification"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_LICENSE_FILE="docs/license.rst"
TERMUX_PKG_MAINTAINER="@termux-user-repository"
TERMUX_PKG_VERSION=22.0.5
TERMUX_PKG_REVISION=5
TERMUX_PKG_SRCURL=https://github.com/WOOD6563/Baka/releases/download/Mesa/mesa-25.1.4.tar.xz
TERMUX_PKG_SHA256=ffbbc6e1417805c9336cec8ed5b6bcce8eeddccae7476e829665b824ac442649
TERMUX_PKG_DEPENDS="libandroid-shmem, libc++, libdrm, libexpat, libglvnd, libx11, libxext, libxfixes, libxshmfence, libxxf86vm, ncurses, vulkan-loader, xorg-xrandr, zlib, zstd"
TERMUX_PKG_SUGGESTS="mesa-zink-dev"
TERMUX_PKG_BUILD_DEPENDS="libllvm-11-static, libglvnd-dev, xorgproto, vulkan-headers"
TERMUX_PKG_CONFLICTS="libmesa, ndk-sysroot (<< 23b-6), mesa"
TERMUX_PKG_REPLACES="libmesa, mesa"
TERMUX_PKG_PROVIDES="mesa"

TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--cmake-prefix-path $TERMUX_PREFIX
-Dcpp_rtti=true
-Dgbm=enabled
-Dopengl=true
-Degl=enabled
-Degl-native-platform=x11
-Dgles1=disabled
-Dgles2=enabled
-Dglx=dri
-Dllvm=enabled
-Dshared-llvm=disabled
-Dplatforms=x11
-Dgallium-drivers=swrast,virgl,zink
-Dglvnd=enabled
-Dxmlconfig=disabled
"

termux_pkg_auto_update() {
	read -r latest < <(curl -fsSL "https://archive.mesa3d.org/" | sed -rn 's/.*mesa-([0-9]+(\.[0-9]+)*).*/\1/p' | sort -Vr);
	termux_pkg_upgrade_version "${latest}"
}

termux_step_post_get_source() {
	# Do not use meson wrap projects
	rm -rf subprojects
}

termux_step_pre_configure() {
	termux_setup_cmake

	CPPFLAGS+=" -D__USE_GNU"
	LDFLAGS+=" -landroid-shmem"

	_WRAPPER_BIN=$TERMUX_PKG_BUILDDIR/_wrapper/bin
	mkdir -p $_WRAPPER_BIN
	if [ "$TERMUX_ON_DEVICE_BUILD" = "false" ]; then
		sed 's|@CMAKE@|'"$(command -v cmake)"'|g' \
			$TERMUX_PKG_BUILDER_DIR/cmake-wrapper.in \
			> $_WRAPPER_BIN/cmake
		chmod 0700 $_WRAPPER_BIN/cmake
		termux_setup_wayland_cross_pkg_config_wrapper
		export LLVM_CONFIG="$TERMUX_PREFIX/bin/llvm-config"
	fi
	export PATH="$_WRAPPER_BIN:$PATH"

	local _vk_drivers="swrast"
	if [ $TERMUX_ARCH = "arm" ] || [ $TERMUX_ARCH = "aarch64" ]; then
		_vk_drivers+=",freedreno"
		TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -Dfreedreno-kmds=msm,kgsl"
	fi
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -Dvulkan-drivers=$_vk_drivers"
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
