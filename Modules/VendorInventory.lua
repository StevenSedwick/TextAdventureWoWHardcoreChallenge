-- Modules/VendorInventory.lua
-- Vendor browsing, buyback, repair, junk-sell, restock, item details, and
-- bag/equip helpers for TextAdventurer.
--
-- Extracted from textadventurer.lua. This module owns:
--   * Vendor reporting + buyback: ReportVendorItems (was local, now global),
--     TA_ReportVendorBuybackItems, TA_BuybackVendorItem.
--   * Repair: TA_RepairVendorGear, TA_ReportRepairStatus.
--   * Junk-sell pipeline: TA_SellJunk, TA_ProcessSellJunkQueue.
--   * Merchant pagination workaround: TA_PrimeMerchantPageForIndex.
--   * Restock + item details: TA_RestockVendorItem, TA_ReportVendorItemDetails,
--     TA_ReportBagItemDetails.
--   * Buying + equip: BuyVendorItem (was local, now global),
--     TA_CheckVendorPurchase, TA_EquipBagItem, TA_EquipItemByQuery.
--   * Weapon buff appliers: TA_ApplyWeaponBuff, TA_ApplyWeaponBuffByQuery.
--   * Bag actions: SellBagItem and DestroyBagItem (both were local, now
--     global so EconomyCommands.lua can reach them).
--   * Dead helper SellCurrentTarget kept module-local.
--
-- Must load AFTER textadventurer.lua (depends on TA, AddLine, ChatPrintf,
-- BagLabel, FormatMoney, ReportMoney, GetMoney, MerchantFrame globals,
-- C_Container.* shims, TA.vendorOpen, TA.sellJunkState, etc.). Must load
-- BEFORE Modules/EconomyCommands.lua and Modules/Commands.lua which bind
-- many of these functions to slash commands. See TextAdventurer.toc.

local TA = _G.TA
if not TA then
  TA = {}
  _G.TA = TA
end

-- ---- moved from textadventurer.lua lines 4892-4980 ----
function ReportVendorItems()
  if not GetMerchantNumItems then
    AddLine("system", "Merchant API unavailable.")
    return
  end
  local num = GetMerchantNumItems() or 0
  if num <= 0 then
    AddLine("loot", "The merchant has nothing for sale right now.")
    return
  end
  -- Prime every page so GetMerchantItemInfo returns full data for items past
  -- page 1. Without this the immersive (hidden MerchantFrame) mode lists
  -- nothing but the first page's items.
  if TA_PrimeMerchantPageForIndex then
    local perPage = tonumber(MERCHANT_ITEMS_PER_PAGE) or 10
    for p = 1, math.ceil(num / perPage) do
      TA_PrimeMerchantPageForIndex(((p - 1) * perPage) + 1)
    end
  end
  for i = 1, num do
    local name, texture, price, quantity, numAvail, isUsable, extendedCost = GetMerchantItemInfo(i)
    if name then
      local priceText = price and price > 0 and FormatMoney(price) or "free"
      local stockText = (numAvail and numAvail >= 0) and string.format(", %d in stock", numAvail) or ""
      local qtyText   = (quantity and quantity > 1) and string.format(" (x%d)", quantity) or ""
      AddLine("loot", string.format("[%d] %s%s - %s%s", i, name, qtyText, priceText, stockText))
    end
  end
end

function TA_ReportVendorBuybackItems()
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not GetNumBuybackItems or not GetBuybackItemInfo then
    AddLine("system", "Buyback API unavailable.")
    return
  end

  local num = GetNumBuybackItems() or 0
  if num <= 0 then
    AddLine("loot", "Buyback list is empty.")
    return
  end

  AddLine("loot", string.format("Buyback items (%d):", num))
  for i = 1, num do
    local name, _, price, quantity = GetBuybackItemInfo(i)
    if name then
      local qtyText = (quantity and quantity > 1) and string.format(" (x%d)", quantity) or ""
      local priceText = (price and price > 0) and FormatMoney(price) or "free"
      AddLine("loot", string.format("[%d] %s%s - %s", i, name, qtyText, priceText))
    end
  end
end

function TA_BuybackVendorItem(index)
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not GetNumBuybackItems or not GetBuybackItemInfo or not BuybackItem then
    AddLine("system", "Buyback API unavailable.")
    return
  end

  local num = GetNumBuybackItems() or 0
  if not index or index < 1 or index > num then
    AddLine("system", string.format("Invalid buyback index. Buyback list has %d item(s).", num))
    return
  end

  local name, _, price = GetBuybackItemInfo(index)
  if not name then
    AddLine("system", "Could not read that buyback item.")
    return
  end

  local money = GetMoney and (GetMoney() or 0) or 0
  local cost = tonumber(price) or 0
  if cost > money then
    AddLine("system", string.format("You cannot afford to buy back %s (cost %s, have %s).", name, FormatMoney(cost), FormatMoney(money)))
    return
  end

  BuybackItem(index)
  AddLine("loot", string.format("Attempted buyback: [%d] %s for %s.", index, name, FormatMoney(cost)))
end

-- ---- moved from textadventurer.lua lines 5050-5261 ----
function TA_RepairVendorGear(useGuild)
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not CanMerchantRepair or not RepairAllItems or not GetRepairAllCost then
    AddLine("system", "Repair API unavailable.")
    return
  end
  if not CanMerchantRepair() then
    AddLine("system", "This merchant cannot repair gear.")
    return
  end

  local cost, canRepairNow = GetRepairAllCost()
  cost = tonumber(cost) or 0
  if cost <= 0 then
    AddLine("loot", "Your gear does not need repairs.")
    return
  end
  if not canRepairNow then
    AddLine("system", string.format("You cannot afford repairs (%s needed).", FormatMoney(cost)))
    return
  end

  local usedGuild = false
  if useGuild and CanGuildBankRepair and CanGuildBankRepair() then
    RepairAllItems(true)
    usedGuild = true
  else
    RepairAllItems()
  end

  if usedGuild then
    AddLine("loot", string.format("Attempted repairs using guild funds (up to %s).", FormatMoney(cost)))
  else
    if useGuild then
      AddLine("system", "Guild bank repair unavailable; using personal funds.")
    end
    AddLine("loot", string.format("Attempted repairs for %s.", FormatMoney(cost)))
  end
end

function TA_ReportRepairStatus()
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not CanMerchantRepair or not GetRepairAllCost then
    AddLine("system", "Repair API unavailable.")
    return
  end
  if not CanMerchantRepair() then
    AddLine("system", "This merchant cannot repair gear.")
    return
  end

  local cost, canRepairNow = GetRepairAllCost()
  cost = tonumber(cost) or 0
  if cost <= 0 then
    AddLine("loot", "Your gear does not need repairs.")
    return
  end

  local money = GetMoney and (GetMoney() or 0) or 0
  AddLine("loot", string.format("Repair cost: %s | You have: %s", FormatMoney(cost), FormatMoney(money)))
  if canRepairNow then
    AddLine("status", "You can afford repairs.")
  else
    AddLine("system", string.format("You cannot afford repairs yet (need %s more).", FormatMoney(cost - money)))
  end
  if CanGuildBankRepair and CanGuildBankRepair() then
    AddLine("status", "Guild bank repair is available here (use: repair guild).")
  end
end

function TA_SellJunk()
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    AddLine("system", "You cannot sell items while in combat.")
    return
  end
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo and C_Container.UseContainerItem) then
    AddLine("system", "Container API unavailable.")
    return
  end

  if TA.sellJunkState and TA.sellJunkState.active then
    AddLine("system", "selljunk is already in progress.")
    return
  end

  local queue = {}
  local queuedUnits = 0
  local estimatedValue = 0
  local maxBag = tonumber(NUM_BAG_SLOTS) or 4

  for bag = 0, maxBag do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (info.hyperlink or info.itemID) then
        local quality = info.quality
        local itemRef = info.hyperlink or info.itemID
        local stackCount = tonumber(info.stackCount) or 1
        local _, _, itemQuality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemRef)
        if quality == nil then
          quality = itemQuality
        end
        if quality == 0 then
          table.insert(queue, {
            bag = bag,
            slot = slot,
            itemRef = itemRef,
            stackCount = stackCount,
          })
          queuedUnits = queuedUnits + stackCount
          estimatedValue = estimatedValue + ((tonumber(sellPrice) or 0) * stackCount)
        end
      end
    end
  end

  if #queue == 0 then
    AddLine("loot", "No junk-quality items found to sell.")
  else
    TA.sellJunkState = {
      active = true,
      queue = queue,
      index = 1,
      soldStacks = 0,
      soldUnits = 0,
      totalValue = 0,
      queuedStacks = #queue,
      queuedUnits = queuedUnits,
      estimatedValue = estimatedValue,
      waitingForBagUpdate = false,
      moneyChanged = false,
      lastActionAt = 0,
      warnedCombat = false,
    }
    AddLine("loot", string.format("Selling junk (%d stack(s), %d item(s), est. %s)...", #queue, queuedUnits, FormatMoney(estimatedValue)))
    TA_ProcessSellJunkQueue("start")
  end
end

function TA_ProcessSellJunkQueue(trigger)
  local state = TA.sellJunkState
  if not state or not state.active then
    return
  end

  if not TA.vendorOpen then
    AddLine("system", "Stopped selljunk: merchant window is no longer open.")
    TA.sellJunkState = nil
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    if not state.warnedCombat then
      AddLine("system", "Paused selljunk: you are in combat.")
      state.warnedCombat = true
    end
    return
  end
  state.warnedCombat = false

  local now = GetTime()
  if state.waitingForBagUpdate and trigger ~= "bagupdate" then
    if (now - (state.lastActionAt or 0)) < 0.40 then
      return
    end
    state.waitingForBagUpdate = false
  end

  while state.index <= #state.queue do
    local entry = state.queue[state.index]
    state.index = state.index + 1

    local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
    if info and (info.hyperlink or info.itemID) then
      local quality = info.quality
      local itemRef = info.hyperlink or info.itemID
      local stackCount = tonumber(info.stackCount) or tonumber(entry.stackCount) or 1
      local _, _, itemQuality, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemRef)
      if quality == nil then
        quality = itemQuality
      end
      if quality == 0 then
        C_Container.UseContainerItem(entry.bag, entry.slot)
        state.soldStacks = state.soldStacks + 1
        state.soldUnits = state.soldUnits + stackCount
        state.totalValue = state.totalValue + ((tonumber(sellPrice) or 0) * stackCount)
        state.waitingForBagUpdate = true
        state.lastActionAt = now
        C_Timer.After(0.45, function()
          TA_ProcessSellJunkQueue("timeout")
        end)
        return
      end
    end
  end

  AddLine("loot", string.format("Sold junk: %d/%d stack(s), %d item(s), estimated value %s.", state.soldStacks, state.queuedStacks, state.soldUnits, FormatMoney(state.totalValue)))
  if state.moneyChanged then
    ReportMoney()
  end
  TA.sellJunkState = nil
end

-- ---- moved from textadventurer.lua lines 5288-5964 ----

-- In Classic Era the default MerchantFrame is paginated (10 items per page) and
-- only "primes" item data for the page that has been rendered at least once.
-- When immersive mode hides the MerchantFrame, pages beyond 1 are never
-- rendered, so GetMerchantItemInfo(i) returns nil and BuyMerchantItem(i, n)
-- silently fails for indexes 11+. We work around this by forcing
-- MerchantFrame.page to the page containing `index` and calling
-- MerchantFrame_Update so the client reads each slot at least once.
function TA_PrimeMerchantPageForIndex(index)
  index = tonumber(index)
  if not index or index < 1 then return end
  local perPage = tonumber(MERCHANT_ITEMS_PER_PAGE) or 10
  local page = math.floor((index - 1) / perPage) + 1
  if MerchantFrame and MerchantFrame_Update then
    local prevPage = MerchantFrame.page or 1
    if MerchantFrame.page ~= page then
      MerchantFrame.page = page
    end
    -- MerchantFrame_Update reads slot data for the current page even when the
    -- frame itself is not visible, which is enough to populate name/price for
    -- GetMerchantItemInfo and BuyMerchantItem.
    pcall(MerchantFrame_Update)
    -- Restore the page so the user's default UI (if they ever Esc to it) is
    -- not yanked around.
    if MerchantFrame.page ~= prevPage then
      MerchantFrame.page = prevPage
      pcall(MerchantFrame_Update)
    end
  end
end

function TA_RestockVendorItem(itemQuery, desiredCount)
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if not itemQuery or itemQuery == "" or not desiredCount then
    AddLine("system", "Usage: restock <item name> <count>")
    return
  end
  if not GetMerchantNumItems or not GetMerchantItemInfo or not BuyMerchantItem then
    AddLine("system", "Merchant API unavailable.")
    return
  end

  desiredCount = math.max(1, math.floor(tonumber(desiredCount) or 0))
  local queryLower = itemQuery:lower()
  local num = GetMerchantNumItems() or 0
  if num <= 0 then
    AddLine("system", "Merchant has no items to restock.")
    return
  end

  -- Prime every page so name lookups succeed for items past page 1.
  if TA_PrimeMerchantPageForIndex then
    local perPage = tonumber(MERCHANT_ITEMS_PER_PAGE) or 10
    for p = 1, math.ceil(num / perPage) do
      TA_PrimeMerchantPageForIndex(((p - 1) * perPage) + 1)
    end
  end

  local merchantIndex = nil
  local merchantName = nil
  local partialIndex = nil
  local partialName = nil
  for i = 1, num do
    local name = GetMerchantItemInfo(i)
    if name then
      local lowerName = name:lower()
      if lowerName == queryLower then
        merchantIndex = i
        merchantName = name
        break
      end
      if not partialIndex and lowerName:find(queryLower, 1, true) then
        partialIndex = i
        partialName = name
      end
    end
  end
  if not merchantIndex and partialIndex then
    merchantIndex = partialIndex
    merchantName = partialName
  end
  if not merchantIndex or not merchantName then
    AddLine("system", string.format("No vendor item matched '%s'.", itemQuery))
    return
  end

  local haveCount = 0
  if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
    local maxBag = tonumber(NUM_BAG_SLOTS) or 4
    local merchantNameLower = merchantName:lower()
    for bag = 0, maxBag do
      local numSlots = C_Container.GetContainerNumSlots(bag) or 0
      for slot = 1, numSlots do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
          local bagItemName = info.itemName
          if not bagItemName then
            bagItemName = GetItemInfo(info.hyperlink or info.itemID)
          end
          if bagItemName and bagItemName:lower() == merchantNameLower then
            haveCount = haveCount + (tonumber(info.stackCount) or 1)
          end
        end
      end
    end
  end

  local needed = desiredCount - haveCount
  if needed <= 0 then
    AddLine("loot", string.format("Already stocked: %s x%d (target %d).", merchantName, haveCount, desiredCount))
    return
  end

  local _, _, price, stackSize, numAvail = GetMerchantItemInfo(merchantIndex)
  local unitsPerBuy = math.max(1, tonumber(stackSize) or 1)
  if numAvail and numAvail >= 0 and numAvail <= 0 then
    AddLine("system", string.format("%s is out of stock.", merchantName))
    return
  end

  local plannedUnits = needed
  if numAvail and numAvail >= 0 and plannedUnits > numAvail then
    plannedUnits = numAvail
  end
  local purchases = math.max(1, math.ceil(plannedUnits / unitsPerBuy))

  local unitCost = tonumber(price) or 0
  if unitCost > 0 then
    local money = GetMoney() or 0
    local totalCost = unitCost * purchases
    if money < totalCost then
      purchases = math.floor(money / unitCost)
      if purchases < 1 then
        AddLine("system", string.format("Not enough money to restock %s.", merchantName))
        return
      end
      totalCost = unitCost * purchases
      AddLine("system", string.format("Partial restock due to funds: buying %d purchase(s) for %s.", purchases, FormatMoney(totalCost)))
    end
  end

  BuyMerchantItem(merchantIndex, purchases)
  local approxUnits = purchases * unitsPerBuy
  AddLine("loot", string.format("Restock: bought %d purchase(s) of %s (about %d item(s)).", purchases, merchantName, approxUnits))
end

function TA_ReportVendorItemDetails(index)
  if not GetMerchantNumItems then
    AddLine("system", "Merchant API unavailable.")
    return
  end
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  local num = GetMerchantNumItems() or 0
  if index < 1 or index > num then
    AddLine("system", string.format("Invalid item index. Merchant has %d items.", num))
    return
  end

  if TA_PrimeMerchantPageForIndex then TA_PrimeMerchantPageForIndex(index) end
  local name, _, price, quantity, numAvail = GetMerchantItemInfo(index)
  if not name then
    AddLine("system", "Could not read that merchant item.")
    return
  end

  local priceText = price and price > 0 and FormatMoney(price) or "free"
  local stockText = (numAvail and numAvail >= 0) and string.format("%d in stock", numAvail) or "unlimited stock"
  local stackText = (quantity and quantity > 1) and string.format("sells in stacks of %d", quantity) or "single item"
  AddLine("loot", string.format("[%d] %s - %s (%s, %s)", index, name, priceText, stackText, stockText))

  local link = GetMerchantItemLink and GetMerchantItemLink(index)
  if link and GetItemInfo then
    local _, _, quality, itemLevel, reqLevel, className, subClassName, _, equipLoc, _, sellPrice = GetItemInfo(link)
    if quality ~= nil then
      AddLine("loot", string.format("Quality: %d", quality))
    end
    if itemLevel and itemLevel > 0 then
      AddLine("loot", string.format("Item level: %d", itemLevel))
    end
    if reqLevel and reqLevel > 0 then
      AddLine("loot", string.format("Requires level: %d", reqLevel))
    end
    if className or subClassName then
      AddLine("loot", string.format("Type: %s%s", className or "unknown", subClassName and (" - " .. subClassName) or ""))
    end
    if equipLoc and equipLoc ~= "" then
      AddLine("loot", string.format("Equip slot: %s", equipLoc))
    end
    if sellPrice and sellPrice > 0 then
      AddLine("loot", string.format("Vendor sell value: %s", FormatMoney(sellPrice)))
    end
  end

  if not CreateFrame or not UIParent then
    return
  end
  if not TA.vendorInspectTooltip then
    TA.vendorInspectTooltip = CreateFrame("GameTooltip", "TextAdventurerVendorInspectTooltip", UIParent, "GameTooltipTemplate")
  end
  local tip = TA.vendorInspectTooltip
  if not tip or not tip.SetMerchantItem or not tip.NumLines or not tip.GetName then
    return
  end

  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  tip:SetMerchantItem(index)

  local tipName = tip:GetName()
  local shown = 0
  local maxLines = 14
  for i = 2, tip:NumLines() do
    local left = _G[tipName .. "TextLeft" .. i]
    local right = _G[tipName .. "TextRight" .. i]
    local leftText = left and left:GetText() or ""
    local rightText = right and right:GetText() or ""
    if leftText ~= "" or rightText ~= "" then
      local lineText = leftText
      if rightText ~= "" then
        if lineText ~= "" then
          lineText = lineText .. "  " .. rightText
        else
          lineText = rightText
        end
      end
      AddLine("loot", lineText)
      shown = shown + 1
      if shown >= maxLines then
        AddLine("loot", "(Additional item details truncated.)")
        break
      end
    end
  end
  tip:Hide()
end

function TA_ReportBagItemDetails(bag, slot)
  bag = tonumber(bag)
  slot = tonumber(slot)
  if bag == nil or slot == nil then
    AddLine("system", "Usage: baginfo <bag> <slot>")
    return
  end
  if not (C_Container and C_Container.GetContainerItemInfo) then
    AddLine("system", "Bag API unavailable on this client.")
    return
  end

  local info = C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    AddLine("system", string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end

  local itemRef = info.hyperlink or info.itemID
  local name = info.itemName or (GetItemInfo and GetItemInfo(itemRef)) or tostring(itemRef or "item")
  local stackCount = tonumber(info.stackCount) or 1
  AddLine("loot", string.format("%s slot %d: %s x%d", BagLabel(bag), slot, tostring(name), stackCount))

  if itemRef and GetItemInfo then
    local _, _, quality, itemLevel, reqLevel, className, subClassName, _, equipLoc, _, sellPrice = GetItemInfo(itemRef)
    if quality ~= nil then
      AddLine("loot", string.format("Quality: %d", quality))
    end
    if itemLevel and itemLevel > 0 then
      AddLine("loot", string.format("Item level: %d", itemLevel))
    end
    if reqLevel and reqLevel > 0 then
      AddLine("loot", string.format("Requires level: %d", reqLevel))
    end
    if className or subClassName then
      AddLine("loot", string.format("Type: %s%s", className or "unknown", subClassName and (" - " .. subClassName) or ""))
    end
    if equipLoc and equipLoc ~= "" then
      AddLine("loot", string.format("Equip slot: %s", equipLoc))
    end
    if sellPrice and sellPrice > 0 then
      AddLine("loot", string.format("Vendor sell value: %s", FormatMoney(sellPrice)))
    end
  end

  if not CreateFrame or not UIParent then
    return
  end
  if not TA.bagInspectTooltip then
    TA.bagInspectTooltip = CreateFrame("GameTooltip", "TextAdventurerBagInspectTooltip", UIParent, "GameTooltipTemplate")
  end
  local tip = TA.bagInspectTooltip
  if not tip or not tip.NumLines or not tip.GetName then
    return
  end

  tip:SetOwner(UIParent, "ANCHOR_NONE")
  tip:ClearLines()
  if tip.SetBagItem then
    tip:SetBagItem(bag, slot)
  elseif itemRef and tip.SetHyperlink then
    tip:SetHyperlink(itemRef)
  else
    tip:Hide()
    return
  end

  local tipName = tip:GetName()
  local shown = 0
  local maxLines = 14
  for i = 2, tip:NumLines() do
    local left = _G[tipName .. "TextLeft" .. i]
    local right = _G[tipName .. "TextRight" .. i]
    local leftText = left and left:GetText() or ""
    local rightText = right and right:GetText() or ""
    if leftText ~= "" or rightText ~= "" then
      local lineText = leftText
      if rightText ~= "" then
        if lineText ~= "" then
          lineText = lineText .. "  " .. rightText
        else
          lineText = rightText
        end
      end
      AddLine("loot", lineText)
      shown = shown + 1
      if shown >= maxLines then
        AddLine("loot", "(Additional item details truncated.)")
        break
      end
    end
  end
  tip:Hide()
end

function BuyVendorItem(index, quantity)
  if not GetMerchantNumItems then
    AddLine("system", "Merchant API unavailable.")
    return
  end
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  local num = GetMerchantNumItems() or 0
  if index < 1 or index > num then
    AddLine("system", string.format("Invalid item index. Merchant has %d items.", num))
    return
  end
  if TA_PrimeMerchantPageForIndex then TA_PrimeMerchantPageForIndex(index) end
  local name, _, price, stackSize = GetMerchantItemInfo(index)
  if not name then
    AddLine("system", "Could not read that merchant item.")
    return
  end
  quantity = quantity or 1
  local copper = GetMoney() or 0
  local totalCost = price * quantity
  if copper < totalCost then
    AddLine("system", string.format("You cannot afford %dx %s. Need %s, have %s.", quantity, name, FormatMoney(totalCost), FormatMoney(copper)))
    return
  end
  BuyMerchantItem(index, quantity)
  AddLine("loot", string.format("You purchase %dx %s for %s.", quantity, name, FormatMoney(totalCost)))
end

function TA_CheckVendorPurchase(index, quantity)
  if not GetMerchantNumItems then
    AddLine("system", "Merchant API unavailable.")
    return
  end
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end

  local num = GetMerchantNumItems() or 0
  if index < 1 or index > num then
    AddLine("system", string.format("Invalid item index. Merchant has %d items.", num))
    return
  end

  if TA_PrimeMerchantPageForIndex then TA_PrimeMerchantPageForIndex(index) end
  local name, _, price, stackSize, numAvail = GetMerchantItemInfo(index)
  if not name then
    AddLine("system", "Could not read that merchant item.")
    return
  end

  quantity = quantity or 1
  quantity = math.max(1, math.floor(quantity))
  local totalCost = (price or 0) * quantity
  local copper = GetMoney() or 0
  local remaining = copper - totalCost

  local stockText = (numAvail and numAvail >= 0) and tostring(numAvail) or "unlimited"
  local perPurchaseText = (stackSize and stackSize > 1) and string.format("%d per buy", stackSize) or "1 per buy"
  AddLine("loot", string.format("Buy check [%d] %s x%d (%s, stock %s):", index, name, quantity, perPurchaseText, stockText))
  AddLine("loot", string.format("Cost: %s | You have: %s", FormatMoney(totalCost), FormatMoney(copper)))

  if remaining >= 0 then
    AddLine("status", string.format("Affordable. You would have %s left.", FormatMoney(remaining)))
  else
    AddLine("system", string.format("Not affordable. You need %s more.", FormatMoney(-remaining)))
  end
end

local function SellCurrentTarget()
  -- Sells the item currently moused-over or last opened via merchant; WoW Classic
  -- exposes this via merchant sell slot â€” we instead sell by item link from bags.
  AddLine("system", "To sell an item, use /ta sell <bag> <slot>. Example: /ta sell 0 3")
end

function TA_EquipBagItem(bag, slot)
  local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    AddLine("system", string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end

  if not (C_Container and C_Container.UseContainerItem) then
    AddLine("system", "Container use API unavailable on this client.")
    return
  end

  C_Container.UseContainerItem(bag, slot)
  AddLine("loot", string.format("Attempting to equip %s from %s slot %d.", info.hyperlink or info.itemID or "item", BagLabel(bag), slot))
end

function TA_EquipItemByQuery(query)
  local itemName = (query or ""):match("^%s*(.-)%s*$")
  if itemName == "" then
    AddLine("system", "Usage: equip <item name> or equip <bag> <slot>")
    return
  end

  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo and C_Container.UseContainerItem) then
    AddLine("system", "Container API unavailable on this client.")
    return
  end

  local queryLower = itemName:lower()
  local exactBag, exactSlot = nil, nil
  local partialBag, partialSlot = nil, nil
  local maxBag = tonumber(NUM_BAG_SLOTS) or 4

  for bag = 0, maxBag do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and (info.hyperlink or info.itemID) then
        local bagItemName = info.itemName
        if not bagItemName and GetItemInfo then
          bagItemName = GetItemInfo(info.hyperlink or info.itemID)
        end

        if bagItemName then
          local bagItemLower = bagItemName:lower()
          if bagItemLower == queryLower then
            exactBag, exactSlot = bag, slot
            break
          end
          if not partialBag and bagItemLower:find(queryLower, 1, true) then
            partialBag, partialSlot = bag, slot
          end
        end
      end
    end
    if exactBag then break end
  end

  if exactBag then
    TA_EquipBagItem(exactBag, exactSlot)
    return
  end
  if partialBag then
    TA_EquipBagItem(partialBag, partialSlot)
    return
  end

  AddLine("system", string.format("No bag item matched '%s'.", itemName))
end

-- INVSLOT 16 = MainHandSlot, 17 = SecondaryHandSlot (off-hand)
TA.WEAPON_SLOT_IDS = TA.WEAPON_SLOT_IDS or { mainhand = 16, offhand = 17, main = 16, off = 17, mh = 16, oh = 17 }

function TA_ApplyWeaponBuff(bag, slot, weaponSlotArg)
  local function Feedback(msg, ch) AddLine(ch or "system", msg) end

  if InCombatLockdown and InCombatLockdown() then
    Feedback("Cannot apply weapon buffs while in combat.")
    return
  end

  local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    Feedback(string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end
  local itemRef = info.hyperlink or tostring(info.itemID or "item")

  -- Guard against accidentally trying to equip non-consumables to weapon slots.
  if GetItemInfoInstant then
    local _, _, _, _, _, itemClassID = GetItemInfoInstant(info.hyperlink or info.itemID)
    local consumableClassID = LE_ITEM_CLASS_CONSUMABLE or 0
    if itemClassID ~= nil and itemClassID ~= consumableClassID then
      Feedback("That item is not a consumable weapon buff (stone/oil/poison).")
      return
    end
  end

  local targetSlotID = nil
  if weaponSlotArg then
    targetSlotID = TA.WEAPON_SLOT_IDS[weaponSlotArg:lower()]
    if not targetSlotID then
      Feedback(string.format("Unknown weapon slot '%s'. Use: mainhand, offhand, mh, oh.", weaponSlotArg))
      return
    end
  end

  -- Pick up the buff item from the bag onto the cursor.
  ClearCursor()
  if C_Container and C_Container.PickupContainerItem then
    C_Container.PickupContainerItem(bag, slot)
  elseif PickupContainerItem then
    PickupContainerItem(bag, slot)
  else
    Feedback("Container pickup API unavailable.")
    return
  end

  local cursorType = GetCursorInfo and GetCursorInfo() or nil
  if cursorType ~= "item" then
    ClearCursor()
    Feedback(string.format("Could not pick up %s — may be on cooldown or already in use.", itemRef))
    return
  end

  if not targetSlotID then
    -- UseContainerItem opens a protected Blizzard dialog and cannot be called from addon code.
    ClearCursor()
    Feedback("Weapon slot required. Usage: wbuff <bag> <slot> mainhand|offhand", "error")
    return
  end

  -- Apply to the specified weapon slot via EquipCursorItem (safe outside combat).
  if EquipCursorItem then
    EquipCursorItem(targetSlotID)

    -- If the cursor still holds the same item, the use/apply attempt failed.
    local postCursorType = GetCursorInfo and GetCursorInfo() or nil
    if postCursorType == "item" then
      ClearCursor()
      Feedback("Could not apply that buff to the selected weapon slot.")
      return
    end

    local slotName = (targetSlotID == 16) and "Main Hand" or "Off Hand"
    Feedback(string.format("Applied %s to %s.", itemRef, slotName), "loot")
  else
    ClearCursor()
    Feedback("EquipCursorItem API unavailable.")
  end
end

function TA_ApplyWeaponBuffByQuery(query, weaponSlotArg)
  local itemName = (query or ""):match("^%s*(.-)%s*$")
  if itemName == "" then
    AddLine("system", "Usage: wbuff <item name> <mainhand|offhand>")
    return
  end
  if not weaponSlotArg then
    AddLine("system", "Usage: wbuff <item name> <mainhand|offhand>")
    return
  end
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then
    AddLine("system", "Container API unavailable.")
    return
  end

  local queryLower = itemName:lower()
  local maxBag = tonumber(NUM_BAG_SLOTS) or 4
  local exactBag, exactSlot, partialBag, partialSlot = nil, nil, nil, nil

  for bag = 0, maxBag do
    local numSlots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info then
        local name = info.itemName
        if not name and GetItemInfo then name = GetItemInfo(info.hyperlink or info.itemID) end
        if name then
          local nameLower = name:lower()
          if nameLower == queryLower then exactBag, exactSlot = bag, slot; break end
          if not partialBag and nameLower:find(queryLower, 1, true) then partialBag, partialSlot = bag, slot end
        end
      end
    end
    if exactBag then break end
  end

  local foundBag = exactBag or partialBag
  local foundSlot = exactSlot or partialSlot
  if foundBag then
    TA_ApplyWeaponBuff(foundBag, foundSlot, weaponSlotArg)
  else
    AddLine("system", string.format("No bag item matched '%s'.", itemName))
  end
end

function SellBagItem(bag, slot)
  if not TA.vendorOpen then
    AddLine("system", "No merchant window is open.")
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    AddLine("system", "You cannot sell items while in combat.")
    return
  end
  local info = C_Container and C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    AddLine("system", string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end
  C_Container.UseContainerItem(bag, slot)
  AddLine("loot", string.format("You sell %s from %s slot %d.", info.hyperlink or info.itemID or "item", BagLabel(bag), slot))
end

function DestroyBagItem(bag, slot)
  local info = C_Container and C_Container.GetContainerItemInfo(bag, slot)
  if not info then
    AddLine("system", string.format("No item found in %s slot %d.", BagLabel(bag), slot))
    return
  end

  local quality = info.quality
  if quality == nil and GetItemInfo then
    local _, _, itemQuality = GetItemInfo(info.hyperlink or info.itemID)
    quality = itemQuality
  end
  if quality == nil then
    AddLine("system", "Could not determine item quality yet. Try again in a moment.")
    return
  end
  if quality > 1 then
    AddLine("system", string.format("Refusing to destroy %s. Only gray or white items can be destroyed.", info.hyperlink or info.itemID or "item"))
    return
  end

  if not DeleteCursorItem then
    AddLine("system", "Item destruction API unavailable.")
    return
  end

  ClearCursor()
  if C_Container and C_Container.PickupContainerItem then
    C_Container.PickupContainerItem(bag, slot)
  elseif PickupContainerItem then
    PickupContainerItem(bag, slot)
  else
    AddLine("system", "Container pickup API unavailable.")
    return
  end

  local cursorType = GetCursorInfo()
  if cursorType ~= "item" then
    ClearCursor()
    AddLine("system", "Could not pick up that item to destroy it.")
    return
  end

  DeleteCursorItem()
  ClearCursor()
  AddLine("loot", string.format("Destroyed %s from %s slot %d.", info.hyperlink or info.itemID or "item", BagLabel(bag), slot))
end

