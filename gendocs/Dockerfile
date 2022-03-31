FROM alpine:edge AS builder

RUN apk add --no-cache git build-base cmake automake autoconf libtool pkgconf coreutils curl unzip gettext-tiny-dev

RUN git clone --depth 1 https://github.com/nvim-lua/plenary.nvim /plenary.nvim

RUN git clone --depth 1 https://github.com/tjdevries/tree-sitter-lua /tree-sitter-lua
WORKDIR /tree-sitter-lua
RUN mkdir parser
RUN cc -o parser/lua.so -Isrc src/parser.c src/scanner.cc -shared -Os -lstdc++ -fPIC

RUN git clone --depth 1 https://github.com/neovim/neovim /neovim
WORKDIR /neovim
RUN make -j4
RUN make install

FROM alpine:edge

COPY --from=builder /usr/lib/libgcc_s.so.1 /usr/lib/libstdc++.so.6 /usr/lib
COPY --from=builder /usr/local/share/nvim /usr/local/share/nvim
COPY --from=builder /usr/local/bin/nvim /usr/local/bin/nvim

COPY --from=builder /plenary.nvim /plenary.nvim
COPY --from=builder /tree-sitter-lua /tree-sitter-lua

RUN mkdir /gendocs
COPY ./init.vim ./gendocs.lua /gendocs

ENTRYPOINT ["/usr/local/bin/nvim", "--headless", "--noplugin", "-u", "/gendocs/init.vim", "-c", "luafile /gendocs/gendocs.lua", "-c", "qa"]

