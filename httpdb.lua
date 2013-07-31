local json = require "util.json"
local shttp = require "socket.http"
local ltn12 = require "ltn12"
local nhttp = require "net.http"

local url = "http://httpdb.nyi.mail.srv.osa/jabber"

local log = require "util.logger".init("httpdb");

local function prepare_call (data)
    local body = json.encode(data)

    local headers = {}
    headers["Content-Type"]   = "application/json"
    headers["Content-Length"] = string.len(body)
    headers["Connection"]     = "close"

    return body, headers
end

local function prepare_response (req, body, code, status)
    status = status or "[no status]"

    if code ~= 200 then
        log("warn", "%s failed: %d %s", req.Action, code, status)
        return "ERROR", { Error = string.format("backend error: %d %s", code, status) }
    end

    local res = json.decode(body)
    if res.Error == json.null then res.Error = "[null]" end
    return res.Status, res
end

local function sync_call (data)
    local body, headers = prepare_call(data)

    local rest = {}
    local reqt = {
        url = url,
        method = "POST",
        headers = headers,
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(rest),
    }

    log("debug", "httpdb sync request %s", body)

    local code, headers, status = socket.skip(1, shttp.request(reqt))

    return prepare_response(data, table.concat(rest), code, status)
end

local function async_call (data, callback)
    local body, headers = prepare_call(data)

    log("debug", "httpdb async request %s", body)

    local req = nhttp.request(
        url,
        {
            method = "POST",
            headers = headers,
            body = body,
        },
        function (content, code, response, request)
            callback(prepare_response(data, content, code))
        end
    )
end

local function call (data, callback)
    if callback then return async_call(data, callback) end
    return sync_call(data)
end


local httpdb = {}

function httpdb.get_domain_map (callback)
    return call({ Action = "GetDomainMap" }, callback)
end

function httpdb.check_login (username, password, ip, ssl, callback)
    return call({ Action = "CheckLogin", username = username, password = password, ip = ip, ssl = ssl }, callback)
end

function httpdb.check_exists (username, callback)
    return call({ Action = "CheckExists", username = username }, callback)
end

function httpdb.get_roster (jid, callback)
    return call({ Action = "GetRoster", jid = jid }, callback)
end

function httpdb.get_vcard (jid, callback)
    return call({ Action = "GetVCard", jid = jid }, callback)
end

function httpdb.load_offline_messages (jid, callback)
    return call({ Action = "LoadOfflineMessages", jid = jid }, callback)
end

function httpdb.delete_offline_message (jid, id, callback)
    return call({ Action = "DeleteOfflineMessage", jid = jid, id = id }, callback)
end

function httpdb.store_offline_message (jid, packet, callback)
    return call({ Action = "StoreOfflineMessage", jid = jid, packet = packet }, callback)
end
    
return httpdb
