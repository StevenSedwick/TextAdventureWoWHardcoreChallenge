---@diagnostic disable: undefined-global

function TA_RegisterEconomyCommandHandlers(exactHandlers, addPatternHandler)
  if TA.economyCommandHandlersRegistered then
    return
  end

  exactHandlers["lootpreview"] = function() ReportLootWindowPreview() end
  exactHandlers["loot preview"] = function() ReportLootWindowPreview() end
  exactHandlers["money"] = function() ReportMoney() end
  exactHandlers["gold"] = function() ReportMoney() end
  exactHandlers["coins"] = function() ReportMoney() end
  exactHandlers["inventory"] = function() ReportInventory() end
  exactHandlers["bags"] = function() ReportInventory() end
  exactHandlers["gear"] = function() ReportEquipment() end
  exactHandlers["equipment"] = function() ReportEquipment() end
  exactHandlers["vendor"] = function() ReportVendorItems() end
  exactHandlers["shop"] = function() ReportVendorItems() end
  exactHandlers["vendorinfo"] = function() AddLine("system", "Usage: vendorinfo <index>") end
  exactHandlers["shopinfo"] = function() AddLine("system", "Usage: shopinfo <index>") end
  exactHandlers["iteminfo"] = function() AddLine("system", "Usage: iteminfo <index> (while vendor is open)") end
  exactHandlers["buycheck"] = function() AddLine("system", "Usage: buycheck <index> [qty]") end
  exactHandlers["readitem"] = function()
    if ItemTextFrame and ItemTextFrame:IsShown() then
      TA_ReportOpenItemText(true)
    else
      AddLine("system", "Usage: readitem <bag> <slot> (or open a readable item first, then use readitem).")
    end
  end

  addPatternHandler("^buy%s+(%d+)$", function(idx) BuyVendorItem(tonumber(idx), 1) end)
  addPatternHandler("^buy%s+(%d+)%s+(%d+)$", function(idx, qty) BuyVendorItem(tonumber(idx), tonumber(qty)) end)
  addPatternHandler("^buycheck%s+(%d+)$", function(idx) TA_CheckVendorPurchase(tonumber(idx), 1) end)
  addPatternHandler("^buycheck%s+(%d+)%s+(%d+)$", function(idx, qty) TA_CheckVendorPurchase(tonumber(idx), tonumber(qty)) end)
  addPatternHandler("^sell%s+(%d+)%s+(%d+)$", function(bag, slot) SellBagItem(tonumber(bag), tonumber(slot)) end)
  addPatternHandler("^destroy%s+(%d+)%s+(%d+)$", function(bag, slot) DestroyBagItem(tonumber(bag), tonumber(slot)) end)
  addPatternHandler("^vendorinfo%s+(%d+)$", function(idx) TA_ReportVendorItemDetails(tonumber(idx)) end)
  addPatternHandler("^shopinfo%s+(%d+)$", function(idx) TA_ReportVendorItemDetails(tonumber(idx)) end)
  addPatternHandler("^iteminfo%s+(%d+)$", function(idx) TA_ReportVendorItemDetails(tonumber(idx)) end)
  addPatternHandler("^readitem%s+(-?%d+)%s+(%d+)$", function(bag, slot) TA_ReadBagItemText(tonumber(bag), tonumber(slot)) end)

  TA.economyCommandHandlersRegistered = true
end

function TA_HandleEconomyInputCommand(lower, msg)
  if lower == "repair" then
    TA_RepairVendorGear(false)
    return true
  elseif lower == "repair guild" then
    TA_RepairVendorGear(true)
    return true
  elseif lower == "repairstatus" then
    TA_ReportRepairStatus()
    return true
  elseif lower == "selljunk" then
    TA_SellJunk()
    return true
  elseif lower == "restock" then
    AddLine("system", "Usage: restock <item name> <count>")
    return true
  end

  local restockItemName, restockCount = lower:match("^restock%s+(.+)%s+(%d+)$")
  if restockItemName and restockCount then
    TA_RestockVendorItem(restockItemName, tonumber(restockCount))
    return true
  end

  if lower == "buyback" then
    TA_ReportVendorBuybackItems()
    return true
  end

  local buybackIndex = lower:match("^buyback%s+(%d+)$")
  if buybackIndex then
    TA_BuybackVendorItem(tonumber(buybackIndex))
    return true
  end

  return false
end

if TA and TA.EXACT_INPUT_HANDLERS and TA_AddPatternInputHandler then
  TA_RegisterEconomyCommandHandlers(TA.EXACT_INPUT_HANDLERS, TA_AddPatternInputHandler)
end
