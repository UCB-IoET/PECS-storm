require "cord"
require "svcd"
NQC = require "nqclient"
sh = require "stormsh"

SVC_ID = 0x3008
FAN_ATTR = 0x400f
HEATER_ATTR = 0x4010
OCCUPANCY_ATTR = 0x4011

chair_port = 60004
-- chair_ip = "2001:0470:4956:0002:0012:6d02:0000:beef"
chair_ip = "ff02:beef"

nqcl = NQC:new(chair_port)

local fan_state_map = {
  "OFF",
  "LOW",
  "MEDIUM",
  "HIGH"
}
local heater_state_map = {
  "OFF",
  "ON", 
  "TOGGLE"
}

local send_message = function (cmd)
  nqcl:sendMessage(cmd, chair_ip, chair_port, nil, nil, function () 
    print("Trying to send")
  end, function (payload, address, port)
    print("Received response")
  end)
end

SVCD.init("chair_proxy", function ()
  print "starting"
  SVCD.add_service(SVC_ID)
  SVCD.add_attribute(SVC_ID, FAN_ATTR, function(pay, srcip, srcport)
    local ps = storm.array.fromstr(pay)
    local state = ps:get(1)  -- 0 or 1
    local cmd = {fans=fan_state_map[state]}
    send_message(cmd)
  end)
  SVCD.add_attribute(SVC_ID, HEATER_ATTR, function(pay, srcip, srcport)
    local ps = storm.array.fromstr(pay)
    local state = ps:get(1)  -- 0 or 1
    local cmd = {heaters=heater_state_map[state]}
    send_message(cmd)
  end)
  SVCD.add_attribute(SVC_ID, OCCUPANCY_ATTR, function() end)
  storm.os.invokePeriodically(3*storm.os.SECOND, function()
    print "Getting occupancy state"
    local cmd = {occupancy=1}
    nqcl:sendMessage(cmd, chair_ip, chair_port, nil, nil, function () 
      print "Trying to get occupancy status"
    end, function (payload, address, port)
      print("Received response: ")
      print("Occupancy", payload.occupancy)
      local msg = storm.array.create(1, storm.array.UINT8)
      if payload.occupancy == true then
        msg:set(1, 1)
      else
        msg:set(1, 0)
      end
      SVCD.notify(SVC_ID, OCCUPANCY_ATTR, msg:as_str())
    end)
  end)
end)

sh.start()

cord.enter_loop()
