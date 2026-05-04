-- Tickers.lua
-- TA_EnsureRuntimeTickers / TA_StopRuntimeTickers / TA_RestartRuntimeTickers.
-- Closures call many globals (CheckMovement, CheckSwingTimer, TA_UpdateDFMode, etc.).
-- Loaded near the end of the .toc so all referenced helpers are already loaded; tickers
-- are only started when TA_EnsureRuntimeTickers() is invoked from PLAYER_ENTERING_WORLD,
-- which fires after every module is loaded.

function TA_EnsureRuntimeTickers()
  if not TA.moveTicker then
    TA.moveTicker = C_Timer.NewTicker(TA.tickerIntervals.move or 0.01, function()
      TA:ProfileStart("moveTicker")
      CheckMovement()
      CheckFallState()
      CheckWallHeuristic()
      CheckSwingTimer()
      TA:ProfileEnd("moveTicker")
    end)
  end
  if not TA.awarenessNearbyTicker then
    TA.awarenessNearbyTicker = C_Timer.NewTicker(TA.tickerIntervals.nearby or 0.01, function()
      TA:ProfileStart("awarenessNearbyTicker")
      local now = GetTime()
      local fallbackInterval = tonumber(TA.awarenessFallbackInterval) or 0.75
      if TA.awarenessDirty or (now - (TA.awarenessLastRunAt or 0)) >= fallbackInterval then
        TA_RequestAwarenessRefresh(false)
      end
      TA:ProfileEnd("awarenessNearbyTicker")
    end)
  end
  if not TA.awarenessMemoryTicker then
    TA.awarenessMemoryTicker = C_Timer.NewTicker(TA.tickerIntervals.memory or 0.01, function()
      TA:ProfileStart("awarenessMemoryTicker")
      UpdateExplorationMemory()
      UpdateRecentPath()
      ReportExplorationMemory(false)
      ReportPathMemory(false)
      TA_ReportAsciiMap(false, false)
      UpdateMapCellOverlay()
      -- Track recent cells for DF mode
      local mapID, cellX, cellY = GetPlayerMapCell()
      if mapID and cellX and cellY then
        TA.dfModeRecentCells[0] = TA.dfModeRecentCells[0] or {}
        TA.dfModeRecentCells[0][0] = true
        for dy = -1, 1 do
          if not TA.dfModeRecentCells[dy] then TA.dfModeRecentCells[dy] = {} end
          for dx = -1, 1 do
            TA.dfModeRecentCells[dy][dx] = true
          end
        end
      end

      -- Keep quest-route candidate refresh out of DF render loop.
      if TA_GetQuestRouterStore and TA_BuildQuestRouteCandidates then
        local qstore = TA_GetQuestRouterStore()
        if qstore and qstore.enabled ~= false then
          local qnow = GetTime()
          if not TA.questRouteOverlay or (qnow - (TA.questRouteLastAt or 0)) > 3 then
            TA_BuildQuestRouteCandidates(1)
          end
        else
          TA.questRouteOverlay = nil
        end
      end
      TA:ProfileEnd("awarenessMemoryTicker")
    end)
  end
  if not TA.dfModeTicker then
    TA.dfModeTicker = C_Timer.NewTicker(TA.tickerIntervals.df or 0.1, function()
      TA:ProfileStart("dfModeTicker")
      TA_UpdateDFMode()
      TA:ProfileEnd("dfModeTicker")
    end)
  end
  if not TA.warlockPromptTicker then
    TA.warlockPromptTicker = C_Timer.NewTicker(TA.tickerIntervals.warlockPrompt or 0.75, function()
      if TA_MaybeAutoWarlockPrompt then
        TA_MaybeAutoWarlockPrompt()
      end
    end)
  end
  if not TA.warriorPromptTicker then
    TA.warriorPromptTicker = C_Timer.NewTicker(TA.tickerIntervals.warriorPrompt or 0.75, function()
      if TA_MaybeAutoWarriorPrompt then
        TA_MaybeAutoWarriorPrompt()
      end
    end)
  end
end

function TA_StopRuntimeTickers()
  if TA.moveTicker then TA.moveTicker:Cancel(); TA.moveTicker = nil end
  if TA.awarenessNearbyTicker then TA.awarenessNearbyTicker:Cancel(); TA.awarenessNearbyTicker = nil end
  if TA.awarenessMemoryTicker then TA.awarenessMemoryTicker:Cancel(); TA.awarenessMemoryTicker = nil end
  if TA.dfModeTicker then TA.dfModeTicker:Cancel(); TA.dfModeTicker = nil end
  if TA.warlockPromptTicker then TA.warlockPromptTicker:Cancel(); TA.warlockPromptTicker = nil end
  if TA.warriorPromptTicker then TA.warriorPromptTicker:Cancel(); TA.warriorPromptTicker = nil end
end

function TA_RestartRuntimeTickers()
  TA_StopRuntimeTickers()
  TA_EnsureRuntimeTickers()
end
