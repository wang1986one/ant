local msg_process = {}

msg_process.__index = msg_process

local client_cmd = {}
for _, cmd in ipairs({"fw.clientcommand"}) do
    local s = require(cmd)
    for cmd, func in pairs(s) do
        assert(client_cmd[cmd] == nil)
        print("client cmd: ",cmd)
        client_cmd[cmd] = func
    end
end

local DbgIO = {}
function DbgIO:event_in(f)
    msg_process:register_command("dbg", function(data_table)
        print("[DbgRecv]", data_table[2])
        f(data_table[2])
    end)
end
function DbgIO:update()
end
function DbgIO:send(data)
    print("[DbgSend]", data)
    msg_process:send_pkg({"dbg", data})
end
function DbgIO:close()
end
local DbgMaster

function msg_process.new(init_linda, pkg_dir, sb_dir)
    DbgMaster = require 'debugger'.start_master(DbgIO)
    return setmetatable({linda = init_linda}, msg_process)
end

function msg_process:mainloop()
    if DbgMaster then
        DbgMaster()
    end
    self:CollectRequest()   --request from game thread
    self:HandleRecv()       --receive from io thread
end

--local logic_request = {}

--if get cmd in transmit_cmd, just send the pkg with linda and do nothing
local transmit_cmd = {}

local max_screenshot_pack = 63*1024
function msg_process:CollectRequest()
    --this if for client request
    while true do
        local key, value = self.linda:receive(0.001, "screenshot", "RegisterTransmit")
        if key == "screenshot" then
            --after compression, only have name and data string
            --value[2] is data
            local name = value[1]
            local size = #value[2]
            --print("recv ss", name, size, width, height,pitch)

            local offset = 0
            while offset < size do
                --print("add a pack", offset)
                local rest_size = size - offset
                local pack_data_size = math.min(rest_size, max_screenshot_pack)
                local pack_str = string.sub(value[2], offset + 1, pack_data_size + offset)

                offset = offset + pack_data_size
                --table.insert(self.sending, pack.pack({"SCREENSHOT", name, size, offset, pack_str}))
                if self.current_connect then
                    --self.io:Send(self.current_connect, {"SCREENSHOT", name, size, offset, pack_str})
                    self.linda:send("io_send", {"SCREENSHOT", name, size, offset, pack_str})
                end
            end
            --[[
        elseif key == "vfs_open" then
            print("try open: ", value, self.vfs)
            local file, hash, f_n = self.vfs:open(value)
            print("vfs open res:", file, hash, f_n)
            if file then file:close() end
            --FILE can't send through linda
            self.linda:send("vfs_open_res", {f_n, hash})
--]]
        elseif key == "RegisterTransmit" then
            transmit_cmd[value] = true
        else
            break
        end
    end
end

function msg_process:HandleRecv()
    while true do
        local key, value = self.linda:receive(0.001, "io_recv")
        if value then
            print("recv io package", table.unpack(value))
            local cmd = value[1]

            local func = client_cmd[cmd]
            if not func then
                if transmit_cmd[cmd] then
                    print("get transmit cmd", cmd)
                    self.linda:send(cmd, value)
                else
                    print("unknown command", cmd)
                end
            else
                func(value, self)
            end
        else
            break
        end
    end
end

function msg_process:register_command(cmd, func)
    --register command from other files
    client_cmd[cmd] = func
end

function msg_process:send_pkg(pkg)
    self.linda:send("io_send", pkg)
end

return msg_process