log = require "common.log"

function log.raw(data)
    io.stdout:write(data)
    io.stdout:write "\n"
end

print = log.info

return log
