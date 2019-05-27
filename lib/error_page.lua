--- Error pages.
--
-- This module provides an improved version of the default WebKit error page,
-- and allows other Lua modules to show error pages as necessary, with a
-- consistent theme. User customization of the error page and its visual style
-- is also supported.
--
-- @module error_page
-- @copyright 2016 Aidan Holm

local window = require("window")
local webview = require("webview")
local lousy = require("lousy")
local history = require("history")

local _M = {}

local error_page_wm = require_web_module("error_page_wm")

--- HTML template for error page content.
-- @type string
-- @readwrite
_M.html_template = [==[
    <html>
        <head>
            <title>{title}</title>
            <link rel="icon" type="image/png" href="luakit://resources/icons/tab-icon-{error_icon}.png" />
            <style type="text/css">
                {style}
            </style>
        </head>
    <body>
        <div id="errorContainer">
            <h1>{heading}</h1>
            {content}
            {buttons}
        </div>
    </body>
    </html>
]==]

--- CSS applied to error pages.
-- @type string
-- @readwrite
_M.style = [===[
    body {
        margin: 0;
        padding: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        background: repeating-linear-gradient(
            45deg,
            #ddd,
            #ddd 10px,
            #dadada 10px,
            #dadada 20px
        );
    }

    #errorContainer {
        background: #fff;
        min-width: 35em;
        max-width: 35em;
        padding: 2.5em;
        border: 2px solid #aaa;
        -webkit-border-radius: 5px;
    }

    #errorContainer > h1 {
        font-size: 120%;
        font-weight: bold;
        margin-top: 0;
    }

    #errorContainer > p {
        font-size: 90%;
        word-wrap: break-word;
    }

    form {
        margin: 1em 0 0;
    }
]===]

--- CSS applied to certificate error pages.
-- @type string
-- @readwrite
_M.cert_style = [===[
    body {
        background: repeating-linear-gradient(
            45deg,
            #bf5959,
            #bf5959 10px,
            #b55 10px,
            #b55 20px
        );
    }
    #errorContainer {
        border: 2px solid #666;
    }
]===]

local function false_cb() return false end
local function true_cb() return true end

local view_state = setmetatable({}, { __mode = "k" })

-- Not fired if the error page is just closed
local function on_navigate_away(v, status)
    if status ~= "provisional" then return end
    v:remove_signal("load-status", on_navigate_away)
    view_state[v].is_error_page = nil
    -- Remove userscripts, stylesheet, javascript overrides
    v:remove_signal("enable-styles", false_cb)
    v:remove_signal("enable-scripts", true_cb)
    v:remove_signal("enable-userscripts", false_cb)
end

-- Clean up only when error page has finished since sometimes multiple
-- load-status provisional signals are dispatched
local function on_finish(v, status)
    if status ~= "finished" then return end
    local vs = view_state[v]

    -- Skip the appropriate number of signals
    assert(type(vs.finished) == "number")
    vs.finished = vs.finished - 1
    if vs.finished > 0 then return end
    vs.finished = nil
    v:remove_signal("load-status", on_finish)

    history.frozen[v] = false
    -- Start listening for button clicks
    error_page_wm:emit_signal(v, "listen")
    -- Mark current history index as showing an error page
    vs.history[v.history.index] = true
    -- Listen for a page navigation away from the error page
    v:add_signal("load-status", on_navigate_away)
end

local error_views = setmetatable({}, { __mode = "k" })
error_page_wm:add_signal("click", function (_, view_id, button_idx)
    -- Get error_views entry with matching view_id
    local view
    for _, w in pairs(window.bywidget) do
        if w.view.id == view_id then view = w.view end
    end
    if not view then return end
    if not error_views[view] then return end

    -- Call button callback
    error_views[view].buttons[button_idx].callback(view)
end)

local function make_button_html(v, buttons)
    local html = ""
    local tmpl = '<input type="button" class="{class}" value="{label}" />'

    if #buttons == 0 then return "" end

    for _, button in ipairs(buttons) do
        assert(button.label)
        assert(button.callback)
        button.class = button.class or ""
        html = html .. string.gsub(tmpl, "{(%w+)}", button)
    end

    error_views[v] = { buttons = buttons }

    local function error_page_on_navigation_request(vv)
        error_views[vv] = nil
        vv:remove_signal("navigation-request", error_page_on_navigation_request)
    end
    v:add_signal("navigation-request", error_page_on_navigation_request)

    return '<form name="bl">' .. html .. '</form>'
end

local function attach_error_page_signals(v, skip_count)
    assert(skip_count == 1 or skip_count == 2)

    if view_state[v] and view_state[v].finished then
        -- View is still loading an error page...
        -- HACK: force early cleanup of the error page by calling the
        -- load-status signal handler directly; it detaches everything so it
        -- cannot be called again in response to the actual signal.
        view_state[v].finished = 0
        on_finish(v, "finished")
    end

    view_state[v] = view_state[v] or { history = {} }
    view_state[v].is_error_page = true
    view_state[v].finished = skip_count

    v:add_signal("enable-styles", false_cb)
    v:add_signal("enable-scripts", true_cb)
    v:add_signal("enable-userscripts", false_cb)
    v:add_signal("load-status", on_finish)
end

local function load_error_page(v, error_page_info)
    -- Set default values
    local defaults = {
        title = "Error",
        error_icon = "error",
        heading = "Unable to load page",
        content = [==[
            <p>A problem occurred while loading the URL <code>{uri}</code></p>
            {msg}
        ]==],
        style = _M.style,
        buttons = {{
            label = "Try again",
            callback = function(vv)
                vv:reload()
            end
        }},
    }

    if error_page_info.style then
        error_page_info.style = _M.style .. error_page_info.style
    end
    error_page_info = lousy.util.table.join(defaults, error_page_info)
    error_page_info.buttons = make_button_html(v, error_page_info.buttons)

    -- Make msg html
    if error_page_info.msg then
        local msg = error_page_info.msg
        if type(msg) == "string" then msg = {msg} end
        error_page_info.msg = "<p>" .. table.concat(msg, "</p><p>") .. "</p>"
    end

    -- Substitute values recursively
    local html, nsub = _M.html_template
    repeat
        html, nsub = string.gsub(html, "{([%w_]+)}", error_page_info)
    until nsub == 0

    -- If v.is_loading = true then the load will first be stopped, causing a finish
    -- event to fire. The error page will then be loaded; so the _second_ finish
    -- event to fire indicates that the error page has finished loading.
    -- If v.is_loading = false, then there is no ongoing load to stop and so the
    -- subsequent load finish event will be caused by the error page finishing.
    --
    -- The above doesn't hold if we're given a request to finish(). If that's
    -- the case, the first finish event to fire indicates the load has finished.
    local skip_count = (v.is_loading and not error_page_info.request) and 2 or 1
    attach_error_page_signals(v, skip_count)
    history.frozen[v] = true
    if error_page_info.request then
        error_page_info.request:finish(html)
    else
        v:load_string(html, error_page_info.uri)
    end
end

local function get_cert_error_desc(err)
    local strings = {
        ["unknown-ca"] = "The signing certificate authority is not known.",
        ["bad-identity"] = "The certificate does not match the expected identity of the"
            .. " site that it was retrieved from.",
        ["not-activated"] = "The certificate's activation time is still in the future.",
        expired = "The certificate has expired.",
        insecure = "The certificate has been revoked.",
        ["generic-error"] = "Error not specified.",
    }

    local msg = err.message .. ": "
    for _, e in ipairs(err.certificate_flags) do
        local emsg = strings[e] or ("Unknown error code " .. e)
        msg = msg .. emsg .. " "
    end
    msg = msg

    return msg
end

local function handle_error(v, uri, err)
    local error_category_lut = {
        ["WebKitNetworkError-302"] = "ignore", -- Load request cancelled
        ["WebKitPluginError-204"] = "ignore", -- Plugin will handle load
        ["WebKitPolicyError-102"] = "ignore", -- Frame load was interrupted
        ["LuakitError-0"] = "security", -- Unacceptable TLS certificate
        ["crash"] = "crash",
    }
    local category = error_category_lut[err.code] or "generic"
    msg.verbose("showing error page for error '%s', code '%s', category '%s'",
        err.message, err.code, category)

    if category == "ignore" then return end

    local error_page_info
    if category == "generic" then
        error_page_info = {
            msg = err.message,
        }
        -- Add proxy info on generic pages
        local p = soup.proxy_uri
        if p ~= "no_proxy" then
            p = p == "default" and "system default" or "<code>" .. p .. "</code>"
            error_page_info.msg = {error_page_info.msg, "Proxy in use: " .. p}
        end
    elseif category == "security" then
        local cert = v.certificate

        error_page_info = {
            title = "Security Error",
            error_icon = "security-error",
            msg = get_cert_error_desc(err),
            style = _M.cert_style,
            heading = "Your connection may be insecure!",
            buttons = {{
                label = "Ignore danger",
                callback = function(vv)
                    local host = lousy.uri.parse(vv.uri).host
                    vv:allow_certificate(host, cert)
                    vv:reload()
                end,
            }},
        }
    elseif category == "crash" then
        error_page_info = {
            title = "Web Process Crashed",
            error_icon = "crash",
            heading = "Web process crashed",
            content = [==[
                <div class="errorMessage">
                    <p>Reload the page to continue</p>
                </div>
            ]==],
            buttons = {{
                label = "Reload page",
                callback = function(vv)
                    vv:reload()
                end
            }},
        }
    end
    error_page_info.uri = uri

    load_error_page(v, error_page_info)
end

--- Replace the current contents of a webview with an error page.
-- @tparam widget v The webview in which to show an error page.
-- @tparam table error_page_info A table of options specifying the error page
-- content.
_M.show_error_page = function(v, error_page_info)
    assert(type(v) == "widget" and v.type == "webview")
    assert(type(error_page_info) == "table")
    assert(type(error_page_info.request) == "request")
    if not error_page_info.uri then
        error_page_info.uri = v.uri
    end
    load_error_page(v, error_page_info)
end

webview.add_signal("init", function (view)
    view:add_signal("load-status", function (v, status, ...)
        if status == "finished" then
            -- Update view history table
            local vs = view_state[v]
            if vs and not vs.is_error_page then
                vs.history[v.history.index] = nil
            end
        elseif status == "failed" then
            handle_error(v, ...)
            return true
        end
    end)
    view:add_signal("crashed", function(v)
        handle_error(v, v.uri, { code = "crash", message = "Web process crashed" })
    end)
    view:add_signal("go-back-forward", function (v, n)
        local vs = view_state[v]
        if vs and vs.history[v.history.index + n] then
            attach_error_page_signals(v, 1)
        end
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
