/*
 * clib/download.h - WebKitDownload wrapper header
 *
 * Copyright © 2011 Fabian Streitel <karottenreibe@gmail.com>
 * Copyright © 2011 Mason Larobina <mason.larobina@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#ifndef LUAKIT_CLIB_DOWNLOAD_H
#define LUAKIT_CLIB_DOWNLOAD_H

#include <lua.h>
#include <webkit2/webkit2.h>

void download_class_setup(lua_State*);
gint luaH_download_push(lua_State*, WebKitDownload*);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
