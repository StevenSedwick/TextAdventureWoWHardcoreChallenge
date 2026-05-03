function TA_FormatTaxiCost(copper)
  if not copper or copper == 0 then return "free" end
  return TA_FormatMoneyString and TA_FormatMoneyString(copper) or (copper .. "c")
end

function TA_ReportTaxiNodes()
  local n = NumTaxiNodes and NumTaxiNodes() or 0
  if n == 0 then
    AddLine("system", "No flight master is open. Speak to one first.")
    return
  end
  AddLine("place", string.format("Flight paths available: %d", n))
  for i = 1, n do
    local name = TaxiNodeName and TaxiNodeName(i) or ("Node " .. i)
    local nodeType = TaxiNodeGetType and TaxiNodeGetType(i) or "REACHABLE"
    local cost = TaxiNodeCost and TaxiNodeCost(i) or 0
    local marker = "  "
    if nodeType == "CURRENT" then marker = "* "
    elseif nodeType == "UNREACHABLE" then marker = "x "
    end
    if nodeType == "REACHABLE" then
      AddLine("place", string.format("  %d. %s%s [%s]", i, marker, name, TA_FormatTaxiCost(cost)))
    elseif nodeType == "CURRENT" then
      AddLine("place", string.format("  %d. %s%s (you are here)", i, marker, name))
    else
      AddLine("place", string.format("  %d. %s%s (undiscovered)", i, marker, name))
    end
  end
  AddLine("system", "Type 'fly <n>' or 'taxi <n>' to take flight.")
end

function TA_TakeTaxiNode(index)
  index = tonumber(index)
  if not index then
    AddLine("system", "Usage: fly <n> (use 'taxi' to list nodes)")
    return
  end
  local n = NumTaxiNodes and NumTaxiNodes() or 0
  if n == 0 then
    AddLine("system", "No flight master is open.")
    return
  end
  if index < 1 or index > n then
    AddLine("system", string.format("No flight node at slot %d (range 1-%d).", index, n))
    return
  end
  local name = TaxiNodeName and TaxiNodeName(index) or "destination"
  local nodeType = TaxiNodeGetType and TaxiNodeGetType(index) or "REACHABLE"
  if nodeType ~= "REACHABLE" then
    AddLine("system", string.format("That destination (%s) is not reachable.", name))
    return
  end
  if TakeTaxiNode then
    TakeTaxiNode(index)
    AddLine("place", string.format("You take flight toward %s.", name))
  end
end

function TA_RegisterTaxiCommandHandlers(exactHandlers, addPatternHandler)
  if TA.taxiCommandHandlersRegistered then return end

  exactHandlers["taxi"] = function() TA_ReportTaxiNodes() end
  exactHandlers["fly"] = function() TA_ReportTaxiNodes() end
  exactHandlers["flightpaths"] = function() TA_ReportTaxiNodes() end
  exactHandlers["flight paths"] = function() TA_ReportTaxiNodes() end

  addPatternHandler("^fly%s+(%d+)$", function(n) TA_TakeTaxiNode(tonumber(n)) end)
  addPatternHandler("^taxi%s+(%d+)$", function(n) TA_TakeTaxiNode(tonumber(n)) end)

  TA.taxiCommandHandlersRegistered = true
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterTaxiCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
