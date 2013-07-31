local sasl_new = require "util.sasl".new;
local httpdb = require "httpdb"

local log = module._log;
local host = module.host;

local provider = {};
log("debug", "initializing fastmail authentication provider for %s", host);

function provider.test_password(username, password)
    log("debug", "test_password %s@%s", username, host)
    local status, data = httpdb.check_login(username.."@"..host, password, "127.0.0.1") -- XXX IP
    if status == "OK" then
        log("info", "%s@%s auth succeeded", username, host)
        return true
    end
    log("info", "%s@%s auth failed: %s %s", username, host, status, data.Error)
    return nil, "Auth failed. Invalid username or password."
end

function provider.get_password(username)
    log("debug", "get_password %s@%s")
    return nil, "Password retrieve not available."
end

function provider.set_password(username, password)
    log("debug", "set_password %s@%s", username, host)
    return nil, "Password set not available."
end

function provider.user_exists(username)
    log("debug", "user_exists %s@%s", username, host)
    local status, data = httpdb.check_exists(username.."@"..host)
    if status == "OK" then
        log("debug", "%s@%s exists", username, host)
        return true
    end
    log("debug", "%s@%s doesn't exist: %s %s", username, host, status, data.Error)
    return nil, "Auth failed. Invalid username or password."
end

function provider.users()
    log("debug", "users %s", host)
    return {}
end

function provider.create_user(username, password)
    log("debug", "create_user %s@%s", username, host)
    return nil, "Create user not available."
end

function provider.delete_user(username)
    log("debug", "delete_user %s@%s %s", username, host)
    return nil, "Delete user not available."
end

function provider.get_sasl_handler()
    log("debug", "get_sasl_handler %s", host)
    local profile = {
        plain_test = function(sasl, username, password, realm)
            log("debug", "plain_test %s@%s %s realm %s", username, host, password, realm)
            return provider.test_password(username, password) and true, true or false
        end
    };
    return sasl_new(host, profile);
end

module:provides("auth", provider);
