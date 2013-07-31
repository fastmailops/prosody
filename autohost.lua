local log = require "util.logger".init("autohost");
local httpdb = require "httpdb"

local refresh = 300

local domains = {}


-- XXX handle domain map rhs properly
local function load_domains ()
    log("debug", "loading domain map")
    httpdb.get_domain_map(function (status, data)
        if status ~= "OK" then
            log("warn", "couldn't get domain map: %s %s", status, data.Error)
            return
        end
        log("debug", "domain map loaded")
        domains = data.DomainMap
        require "util.timer".add_task(refresh, load_domains)
    end)
end

local function hook_hosts_table ()
    setmetatable(prosody.hosts, {
        __index = function (hosts, hostname)
            if not hostname or hostname == "*" or string.find(hostname, "@") then return end
            if not domains[hostname] then return end
            log("debug", "creating virtual host config for %s", hostname)
            hostmanager.activate(hostname)
            return rawget(hosts, hostname)
        end
    })
end

prosody.events.add_handler("server-starting", load_domains, 1)
prosody.events.add_handler("server-starting", hook_hosts_table, 1);
