-- assign a dns address to each thread using a simple round robin approach
-- based on https://github.com/wg/wrk/blob/next/scripts/addr.lua

local counter = 0
local addrs = nil

function setup(thread)
   if not addrs then
      addrs = wrk.lookup(wrk.host, wrk.port or "http")
      for i = #addrs, 1, -1 do
         if not wrk.connect(addrs[i]) then
            table.remove(addrs, i)
         end
      end
   end

   local index = (counter % #addrs) + 1 -- lua arrays start at 1
   thread.addr = addrs[index]
   thread:set("id", counter + 1)
   counter = counter + 1
end

function init(args)
   local msg = "thread %d addr: %s"
   print(msg:format(wrk.thread:get("id"), wrk.thread.addr))
end