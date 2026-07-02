FROM i386/ubuntu:devel

# FreeType version must match the headers bundled in include/freetype/
ARG FREETYPE_VERSION=2.13.2
ARG FREETYPE_SHA256=12991c4e55c506dd7f9b765933e62fd2be2e06d421505d7950a132e4f1bb484d

RUN apt-get -y update
RUN apt-get install -y libx11-dev \
	libxext-dev \
	libc6-dev \
	gcc \
	curl \
	xz-utils

# if on i386 there's no need for multilib
#RUN apt-get install -y libc6-dev-i386
#RUN apt-get install -y libx11-6:i386, libxext-dev:i386
#RUN apt-get install -y gcc-multilib

ENV INFERNO=/usr/inferno
COPY . $INFERNO
WORKDIR $INFERNO

# Download FreeType source into libfreetype/libfreetype/.
# The libfreetype/mkfile expects sources at libfreetype/src/... and headers
# at libfreetype/include/ (relative to the libfreetype/ build directory),
# which resolve to libfreetype/libfreetype/src/... and
# libfreetype/libfreetype/include/ respectively.
#
# After extraction, override FreeType's default config headers with Inferno's
# custom versions.  The mkfile prepends -Ilibfreetype/include to CFLAGS, so
# FreeType's own include directory takes priority over include/.  Without this
# override, FreeType 2.13.2's default ftmodule.h registers BDF/SDF/SVG modules
# and its default ftoption.h enables LZW and GX-variable-font support — all of
# which reference symbols that are not compiled by the Inferno mkfile, causing
# linker errors (bdf_driver_class, ft_sdf_renderer_class, FT_Stream_OpenLZW,
# FT_Set_Named_Instance, etc.).  Copying Inferno's custom config files over the
# downloaded ones ensures the build only references the modules that are
# actually compiled.
RUN curl -L "https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz" \
        -o /tmp/freetype.tar.xz \
    && echo "${FREETYPE_SHA256}  /tmp/freetype.tar.xz" | sha256sum -c - \
    && tar xf /tmp/freetype.tar.xz -C libfreetype \
    && mv "libfreetype/freetype-${FREETYPE_VERSION}" libfreetype/libfreetype \
    && cp include/freetype/config/ftoption.h  libfreetype/libfreetype/include/freetype/config/ftoption.h \
    && cp include/freetype/config/ftmodule.h  libfreetype/libfreetype/include/freetype/config/ftmodule.h \
    && rm /tmp/freetype.tar.xz

# setup a custom mkconfig
RUN echo > mkconfig ROOT=$INFERNO
RUN echo >>mkconfig TKSTYLE=std
RUN echo >>mkconfig SYSHOST=Linux
RUN echo >>mkconfig SYSTARG=Linux
RUN echo >>mkconfig OBJTYPE=386

RUN echo >>mkconfig 'OBJDIR=$SYSTARG/$OBJTYPE'
RUN echo >>mkconfig '<$ROOT/mkfiles/mkhost-$SYSHOST'
RUN echo >>mkconfig '<$ROOT/mkfiles/mkfile-$SYSTARG-$OBJTYPE'

# build code
RUN ./makemk.sh
ENV PATH="$INFERNO/Linux/386/bin:${PATH}"
RUN mk nuke
RUN mk install

CMD ["emu", "-c1",  "wm/wm"]

