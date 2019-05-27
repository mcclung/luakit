/*
 * clib/msg.h - Lua logging interface
 *
 * Copyright © 2016 Aidan Holm <aidanholm@gmail.com>
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

#ifndef LUAKIT_CLIB_MSG_H
#define LUAKIT_CLIB_MSG_H

#include <lua.h>
#include "common/luaclass.h"

void msg_lib_setup(lua_State *L);
lua_class_t * msg_lib_get_msg_class(void);

#endif

// vim: ft=c:et:sw=4:ts=8:sts=4:tw=80
