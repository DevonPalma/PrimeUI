-- PrimeUI by JackMacWindows
-- Public domain/CC0

local expect = require "cc.expect".expect

-- Initialization code
local PrimeUI = {}
do
    local coros = {}
    local restoreCursor

    --- Adds a task to run in the main loop.
    ---@param func function The function to run, usually an `os.pullEvent` loop
    function PrimeUI.addTask(func)
        expect(1, func, "function")
        coros[#coros+1] = {coro = coroutine.create(func)}
    end

    --- Sends the provided arguments to the run loop, where they will be returned.
    ---@param ... any The parameters to send
    function PrimeUI.resolve(...)
        coroutine.yield(coros, ...)
    end

    --- Clears the screen and resets all components. Do not use any previously
    --- created components after calling this function.
    function PrimeUI.clear()
        -- Reset the screen.
        term.setCursorPos(1, 1)
        term.setCursorBlink(false)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        -- Reset the task list and cursor restore function.
        coros = {}
        restoreCursor = nil
    end

    --- Sets or clears the window that holds where the cursor should be.
    ---@param win window|nil The window to set as the active window
    function PrimeUI.setCursorWindow(win)
        expect(1, win, "table", "nil")
        restoreCursor = win and win.restoreCursor
    end

    --- Checks if an absolute position is seen by a window
    ---@param win window The window to check
    ---@param x number The absolute X position of the point
    ---@param y number The absolute Y position of the point
    ---@return boolean Whether the point is in the window
    function PrimeUI.inVisibleRegion(win, x, y)
        if win == term then
            local w, h = win.getSize()
            return x >= 1 and y >= 1 and x <= w and y <= h
        end

        -- Retrieve nested windows
        local parentWindows = {}
        while win ~= term.native() and win ~= term.current() do
            table.insert(parentWindows, win)
            _, win = debug.getupvalue(select(2, debug.getupvalue(win.isColor, 1)), 1) -- gets the parent window through an upvalue
        end

        -- Starting from root, check if absolute point is within
        -- each subsequenct window's bounds
        for i = #parentWindows, 1, -1 do
            if (not parentWindows[i].isVisible()) then return false end
            local winX, winY = parentWindows[i].getPosition()
            local winW, winH = parentWindows[i].getSize()
            if x >= winX and y >= winY and x <= winX + winW - 1 and y <= winY + winH - 1 then
                -- Translate point to be relative to the next window
                x, y = x - winX + 1, y - winY + 1
            else
                return false
            end
        end

        return true
    end

    --- Runs the main loop, returning information on an action.
    ---@return any ... The result of the coroutine that exited
    function PrimeUI.run()
        while true do
            -- Restore the cursor and wait for the next event.
            if restoreCursor then restoreCursor() end
            local ev = table.pack(os.pullEvent())
            -- Run all coroutines.
            for _, v in ipairs(coros) do
                if v.filter == nil or v.filter == ev[1] then
                    -- Resume the coroutine, passing the current event.
                    local res = table.pack(coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)))
                    -- If the call failed, bail out. Coroutines should never exit.
                    if not res[1] then error(res[2], 2) end
                    -- If the coroutine resolved, return its values.
                    if res[2] == coros then return table.unpack(res, 3, res.n) end
                    -- Set the next event filter.
                    v.filter = res[2]
                end
            end
        end
    end
end

-- DO NOT COPY THIS LINE
return PrimeUI