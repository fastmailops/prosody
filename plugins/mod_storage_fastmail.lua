local httpdb = require "httpdb"
local xml = require "util.xml"

local log = module._log
local host = module.host;


local adapters = {
    roster = {},
    vcard = {},
}


function adapters.roster:get (username)
    log("debug", "roster:get %s@%s", username, host)

    local status, data = httpdb.get_roster(username.."@"..host)
    if status ~= "OK" then
        log("info", "%s@%s roster get failed: %s %s", username, host, status, data.Error)
        return nil, "Internal error"
    end

    local roster = {}

    for i = 1,#data.roster do
        local orig = data.roster[i]
        local item = {}

        item.name = orig.name

        -- XXX might need to handle pending subscriptions here, not sure if
        -- djabberd even stores the higher bits
        item.subscription =
            orig.subscription == 1 and "to" or
            orig.subscription == 2 and "from" or
            orig.subscription == 3 and "both" or
                                       "none"

        item.groups = {}
        for j = 1,#orig.groups do
            item.groups[orig.groups[j]] = true
        end

        roster[orig.jid] = item
    end

    log("debug", "%s@%s roster get returning %d items", username, host, #data.roster)

    return roster
end


function adapters.vcard:get (username)
    log("debug", "vcard:get %s@%s", username, host)

    local status, data = httpdb.get_vcard(username.."@"..host)

    if status ~= "OK" then
        log("info", "%s@%s vcard get failed: %s %s", username, host, status, data.Error)
        return nil, "Internal error"
    end

    if not data.vcard then
        log("debug", "%s@%s vcard not found", username, host)
        return
    end

    log("debug", "%s@%s returning stored vcard");

    return xml.parse(data.vcard)
end


local driver = {};
log("debug", "initializing fastmail storage provider for %s", host)

function driver:open(store, typ)
    log("debug", "open %s store %s type %s", host, store, typ and typ or "[nil]")

    local adapter = adapters[store]
    if adapter and not typ then
        return adapter
    end

    return nil, "unsupported-store"
end

module:provides("storage", driver);
