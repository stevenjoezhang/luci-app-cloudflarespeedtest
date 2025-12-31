--[[
   patch_tar_file.lua
   -------------------------------------------------
   Patch tar headers produced by old GNU / "old tar" format
   into standard ustar headers (magic = "ustar\0", version = "00").

   This fixes tar archives that BusyBox tar on OpenWrt (without
   ENABLE_FEATURE_TAR_OLDGNU_COMPATIBILITY) cannot recognize.

   Depends only on the default OpenWrt Lua environment (io, os,
   string, math).
   -------------------------------------------------
   Usage:
    lua patch_tar_file.lua <tar-file>
--]]

local BLOCK_SIZE = 512
local MAGIC_OFF  = 257
local MAGIC_LEN  = 6   -- "ustar\0"
local VER_OFF    = 263
local VER_LEN    = 2   -- "00"
local CHKSUM_OFF = 148
local CHKSUM_LEN = 8

-----------------------------------------------------------------
-- Compute the tar checksum for a 512-byte header
--  * Treat the checksum field (8 bytes) as filled with spaces (0x20)
--    when computing the sum.
-----------------------------------------------------------------
local function compute_checksum(header)
    -- header must be a 512-byte string
    assert(#header == BLOCK_SIZE)

    -- Replace the checksum field with spaces
    local chk = header:sub(1, CHKSUM_OFF) ..
                string.rep(" ", CHKSUM_LEN) ..
                header:sub(CHKSUM_OFF + CHKSUM_LEN + 1)

    local sum = 0
    for i = 1, #chk do
        sum = sum + chk:byte(i)
    end
    return sum
end

-----------------------------------------------------------------
-- Write the integer checksum back into the header (8 bytes,
-- octal, zero-padded, followed by NUL+space).
-----------------------------------------------------------------
local function write_checksum(header, sum)
    -- 6-digit octal + NUL + space = 8 bytes
    local chk_str = string.format("%06o", sum) .. "\0 "
    assert(#chk_str == CHKSUM_LEN)

    return header:sub(1, CHKSUM_OFF) ..
           chk_str ..
           header:sub(CHKSUM_OFF + CHKSUM_LEN + 1)
end

-----------------------------------------------------------------
-- Parse the size field (an octal string) into a number.
-----------------------------------------------------------------
local function parse_size(sizefield)
    -- The size field is 12 bytes, possibly padded with NUL or spaces.
    local s = sizefield:gsub("[\0%s]+$", "")   -- strip right padding
    if s == "" then return 0 end
    local num = tonumber(s, 8)
    return num or 0
end

-----------------------------------------------------------------
-- Main function: patch the given tar file replacing old-tar headers
-- with ustar headers where needed.
-----------------------------------------------------------------
local function patch_tar_file(fname)
    print(string.format("patch file: %s", fname))

    local f, err = io.open(fname, "r+b")
    if not f then
        io.stderr:write(string.format("Error: cannot open %s (%s)\n", fname, err))
        return
    end

    -- Ensure file has at least one full block
    f:seek("end", 0)
    local sz = f:seek()
    if sz < BLOCK_SIZE then
        io.stderr:write(string.format("Error: file too small (<%d bytes): %s\n", BLOCK_SIZE, fname))
        f:close()
        return
    end
    f:seek("set", 0)

    local zero_blocks = 0      -- consecutive all-zero block counter
    local block_index = 0      -- processed block index (starting at 0)

    while true do
        local pos = f:seek()
        local blk = f:read(BLOCK_SIZE)
        if not blk or #blk < BLOCK_SIZE then break end

        -- Check whether block is all zeros
        local all_zero = true
        for i = 1, BLOCK_SIZE do
            if blk:byte(i) ~= 0 then
                all_zero = false
                break
            end
        end

        if all_zero then
            zero_blocks = zero_blocks + 1
            if zero_blocks >= 2 then
                -- Two consecutive zero blocks -> end of archive
                break
            end
            block_index = block_index + 1
        else
            zero_blocks = 0

            -- parse header
            local name   = blk:sub(1, 100):gsub("\0+$", "")
            local magic  = blk:sub(MAGIC_OFF + 1, MAGIC_OFF + MAGIC_LEN)   -- Lua string indices start at 1
            local need_patch = false

            if magic:sub(1,5) ~= "ustar" then
                -- old-tar: magic is all NUL (0x00) and name is non-empty
                if magic == string.rep("\0", MAGIC_LEN) and #name > 0 then
                    need_patch = true
                end
            end

            if need_patch then
                -- write ustar magic + version
                local hdr = blk
                hdr = hdr:sub(1, MAGIC_OFF) ..
                      "ustar\0" ..
                      hdr:sub(MAGIC_OFF + MAGIC_LEN + 1)

                hdr = hdr:sub(1, VER_OFF) ..
                      "00" ..
                      hdr:sub(VER_OFF + VER_LEN + 1)

                -- recompute and write checksum
                local chksum = compute_checksum(hdr)
                hdr = write_checksum(hdr, chksum)

                -- Write back to file
                f:seek("set", pos)
                f:write(hdr)
                f:flush()
                print(string.format("patched header at block %d (offset %d)", block_index, pos))
            end

            -- skip file data blocks
            local size_field = blk:sub(124 + 1, 124 + 12)   -- size occupies 12 bytes
            local sz_val = parse_size(size_field)
            local data_blocks = math.floor((sz_val + BLOCK_SIZE - 1) / BLOCK_SIZE)

            if data_blocks > 0 then
                f:seek("cur", data_blocks * BLOCK_SIZE)
                block_index = block_index + 1 + data_blocks
            else
                block_index = block_index + 1
            end

        end
    end

    f:close()
    print(string.format("finished scanning %s", fname))
end

local function main()
    if #arg < 1 then
        io.stderr:write(string.format("Usage: lua %s <tar-file>\n", arg[0] or "script"))
        os.exit(1)
    end
    patch_tar_file(arg[1])
end

main()
