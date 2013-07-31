-- XXX once offline storage is properly hooked up to the storage manager we can
--     go back to using the stock offline module

local httpdb = require "httpdb";

local st = require "util.stanza";
local datetime = require "util.datetime";
local ipairs = ipairs;
local jid_split = require "util.jid".split;

local log = module._log

module:add_feature("msgoffline");

module:hook("message/offline/handle", function(event)
    local origin, stanza = event.origin, event.stanza;
    local to = stanza.attr.to;
    local node, host;
    if to then
        node, host = jid_split(to)
    else
        node, host = origin.username, origin.host;
    end

    log("debug", "storing offline message from %s to %s@%s", stanza.attr.from, node, host)

    stanza.attr.stamp, stanza.attr.stamp_legacy = datetime.datetime(), datetime.legacy();
    httpdb.store_offline_message (node.."@"..host, st.preserialize(stanza), function () end)
    stanza.attr.stamp, stanza.attr.stamp_legacy = nil, nil;

    return true
end);

module:hook("message/offline/broadcast", function(event)
    local origin = event.origin;
    local username, host = origin.username, origin.host;

	log("debug", "loading offline messages for %s", origin.full_jid)

    httpdb.load_offline_messages(username.."@"..host,
        function (status, data)
			if status ~= "OK" then
				log("info", "%s@%s offline messages get failed: %s %s", username, host, status, data.Error)
				return
			end
			local ids = {}
			for _,message in ipairs(data.content) do
				table.insert(ids, message.id)
				if not message.packet.type then -- XXX temp protection against djabberd messages
					local stanza = st.deserialize(message.packet);
					stanza:tag("delay", {xmlns = "urn:xmpp:delay", from = host, stamp = stanza.attr.stamp}):up(); -- XEP-0203
					stanza:tag("x", {xmlns = "jabber:x:delay", from = host, stamp = stanza.attr.stamp_legacy}):up(); -- XEP-0091 (deprecated)
					stanza.attr.stamp, stanza.attr.stamp_legacy = nil, nil;
					origin.send(stanza);
				end
			end
			log("debug", "%d messages delivered, deleting", #ids)
			for _,id in ipairs(ids) do
				httpdb.delete_offline_message(username.."@"..host, id, function () end)
			end
			log("debug", "%s@%s offline load done", username, host)
		end
	)

	return true
end);
