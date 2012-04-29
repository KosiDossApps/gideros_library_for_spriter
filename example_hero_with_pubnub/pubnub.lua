require "Json"
--require "crypto"

pubnub      = {}
local LIMIT = 1700

function pubnub.new(init)
    local self          = init
    local subscriptions = {}

    -- SSL ENABLED?
    if self.ssl then 
        self.origin = "https://" .. self.origin
    else
        self.origin = "http://" .. self.origin
    end

    function self:publish(args)
        local callback = args.callback or function() end

        if not (args.channel and args.message) then
            return callback({ nil, "Missing Channel and/or Message" })
        end

        local channel   = args.channel
        local message   = Json.Encode(args.message)
        local signature = "0"

        -- SIGN PUBLISHED MESSAGE?
        if self.secret_key then
            signature = crypto.digest( crypto.md5, table.concat( {
                self.publish_key,
                self.subscribe_key,
                self.secret_key,
                channel,
                message
            }, "/" ) )
        end

        -- MESSAGE TOO LONG?
        if string.len(message) > LIMIT then
            return callback({ nil, "Message Too Long (" .. LIMIT .. ")" })
        end

        -- PUBLISH MESSAGE
        self:_request({
            callback = function(response)
                if not response then
                    return callback({ nil, "Connection Lost" })
                end
                callback(response)
            end,
            request  = {
                "publish",
                self.publish_key,
                self.subscribe_key,
                signature,
                self:_encode(channel),
                "0",
                self:_encode(message)
            }
        })
    end

    function self:subscribe(args)
        local channel   = args.channel
        local callback  = callback or args.callback
        local errorback = args['errorback'] or function() end
        local timetoken = 0

        if not channel then return print("Missing Channel") end
        if not callback then return print("Missing Callback") end

        -- NEW CHANNEL?
        if not subscriptions[channel] then
            subscriptions[channel] = {}
        end

        -- ENSURE SINGLE CONNECTION
        if (subscriptions[channel].connected) then
            return print("Already Connected")
        end

        subscriptions[channel].connected = 1

        -- SUBSCRIPTION RECURSION 
        local function substabizel()
            -- STOP CONNECTION?
            if not subscriptions[channel].connected then return end

            -- CONNECT TO PUBNUB SUBSCRIBE SERVERS
            self:_request({
                callback = function(response)
                    -- STOP CONNECTION?
                    if not subscriptions[channel].connected then return end

                    -- PROBLEM?
                    if not response then
                        -- ENSURE CONNECTED
                        return self:time({
                            callback = function(time)
                                if not time then
                                   local timer = Timer.new(1000,1)
                                   timer:addEventListener(Event.TIMER, substabizel)
                                   timer:start()
                                   return errorback("Lost Network Connection")
                                end
				local timer = Timer.new(10,1)
                                timer:addEventListener(Event.TIMER, substabizel)
                                timer:start()
                            end
                        })
                    end

                    timetoken = response[2]
                    local timer = Timer.new(1, 1)
                    timer:addEventListener(Event.TIMER, substabizel)
                    timer:start()
					
                    for i, message in ipairs(response[1]) do
                        callback(message)
                    end
                end,
                request = {
                    "subscribe",
                    self.subscribe_key,
                    self:_encode(channel),
                    "0",
                    timetoken
                }
            })
        end

        -- BEGIN SUBSCRIPTION (LISTEN FOR MESSAGES)
        substabizel()
        
    end

    function self:unsubscribe(args)
        local channel = args.channel
        if not subscriptions[channel] then return nil end

        -- DISCONNECT
        subscriptions[channel].connected = nil
    end

    function self:history(args)
        if not (args.callback and args.channel) then
            return print("Missing History Callback and/or Channel")
        end

        limit    = args.limit
        channel  = args.channel
        callback = args.callback

        if not limit then limit = 10 end

        self:_request({
            callback = callback,
            request  = {
                'history',
                self.subscribe_key,
                self:_encode(channel),
                '0',
                limit
            }
        })
    end

    function self:time(args)
        if not args.callback then
            return print("Missing Time Callback")
        end

        self:_request({
            request  = { "time", "0" },
            callback = function(response)
                if response then
                    return args.callback(response[1])
                end
                args.callback(nil)
            end
        })
    end

    function self:_request(args)
        -- APPEND PUBNUB CLOUD ORIGIN 
        table.insert( args.request, 1, self.origin )

        local url = table.concat( args.request, "/" )

		local loader = UrlLoader.new(url, UrlLoader.GET)
		loader:addEventListener(Event.COMPLETE, function(event)
		    status, message = pcall( Json.Decode, event.data )
            if status then
                return args.callback(message)
            else
                return args.callback(nil)
            end
		end)
		loader:addEventListener(Event.ERROR, function() return args.callback(nil) end)
    end

    function self:_encode(str)
        str = string.gsub( str, "([^%w])", function(c)
            return string.format( "%%%02X", string.byte(c) )
        end )
        return str
    end

    function self:_map( func, array )
        local new_array = {}
        for i,v in ipairs(array) do
            new_array[i] = func(v)
        end
        return new_array
    end

    -- RETURN NEW PUBNUB OBJECT
    return self
end
