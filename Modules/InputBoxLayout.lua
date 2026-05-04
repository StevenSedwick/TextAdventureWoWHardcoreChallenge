-- InputBoxLayout.lua
-- Owns the warningFrame (TextAdventurerWarningFrame) child of the main panel,
-- ShowWarningMessage helper, and TA_UpdateInputBoxLayout (resizes the input box as the
-- player types). ShowWarningMessage is global because main-file event handlers and
-- StatusReports call it. The initial layout pass uses _G.TextAdventurerPanel.inputBox
-- since this module loads after main.

local panel = _G.TextAdventurerPanel

local warningFrame = CreateFrame("Frame", "TextAdventurerWarningFrame", _G.TextAdventurerPanel, "BackdropTemplate")
warningFrame:SetSize(860, 50)
warningFrame:SetPoint("TOP", _G.TextAdventurerPanel, "TOP", 0, -40)
warningFrame:SetFrameStrata("HIGH")
warningFrame:SetFrameLevel(11001)
warningFrame:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
warningFrame:SetBackdropColor(0.25, 0, 0, 0.85)
warningFrame:Hide()

warningFrame.text = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
warningFrame.text:SetPoint("CENTER", warningFrame, "CENTER", 0, 0)
warningFrame.text:SetJustifyH("CENTER")
warningFrame.text:SetTextColor(1, 0.4, 0.4)

function ShowWarningMessage(msg)
  if not msg or msg == "" then return end
  warningFrame.text:SetText(msg)
  warningFrame:Show()
  C_Timer.After(3, function()
    if warningFrame and warningFrame:IsShown() then
      warningFrame:Hide()
    end
  end)
end

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText("Text Adventurer")

local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("TOPRIGHT", -14, -16)
subtitle:SetText("/ta help")

local text = CreateFrame("ScrollingMessageFrame", nil, panel)
text:SetSize(864, 472)
text:SetPoint("TOPLEFT", 18, -42)
text:SetFontObject(GameFontHighlightHuge)
text:SetJustifyH("LEFT")
text:SetFading(false)
text:SetMaxLines(TA.lineLimit or 400)
text:SetInsertMode("BOTTOM")
text:SetIndentedWordWrap(true)
text:EnableMouseWheel(true)
text:SetScript("OnMouseWheel", function(self, delta)
  if delta > 0 then
    self:ScrollUp()
  else
    self:ScrollDown()
  end
end)

-- Subtle bottom flash on new lines (no buffering, no event delay).
text.newLineFlash = text:CreateTexture(nil, "OVERLAY")
text.newLineFlash:SetPoint("BOTTOMLEFT", text, "BOTTOMLEFT", 0, 0)
text.newLineFlash:SetPoint("BOTTOMRIGHT", text, "BOTTOMRIGHT", 0, 0)
text.newLineFlash:SetHeight(18)
text.newLineFlash:SetColorTexture(0.82, 0.90, 1.0, 0)

text.flashAnim = text.newLineFlash:CreateAnimationGroup()
local flashIn = text.flashAnim:CreateAnimation("Alpha")
flashIn:SetOrder(1)
flashIn:SetDuration(0.02)
flashIn:SetFromAlpha(0.0)
flashIn:SetToAlpha(0.20)
local flashOut = text.flashAnim:CreateAnimation("Alpha")
flashOut:SetOrder(2)
flashOut:SetDuration(0.14)
flashOut:SetFromAlpha(0.20)
flashOut:SetToAlpha(0.0)

panel.text = text

TA.INPUTBOX_LAYOUT = TA.INPUTBOX_LAYOUT or {
  baseHeight = 24,
  lineHeight = 14,
  minLines = 1,
  maxLines = 6,
  x = 18,
  baseY = 16,
  insetLeft = 8,
  insetRight = 8,
  insetTop = 6,
  insetBottom = 6,
}

local inputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
inputBox:SetSize(840, TA.INPUTBOX_LAYOUT.baseHeight)
inputBox:SetPoint("BOTTOMLEFT", TA.INPUTBOX_LAYOUT.x, TA.INPUTBOX_LAYOUT.baseY)
inputBox:SetAutoFocus(false)
inputBox:SetMaxLetters(200)
inputBox:SetMultiLine(true)
inputBox:SetFontObject(ChatFontNormal)
inputBox:SetTextColor(1, 1, 1, 1)
inputBox:SetJustifyH("LEFT")
inputBox:SetJustifyV("TOP")
inputBox:SetTextInsets(TA.INPUTBOX_LAYOUT.insetLeft, TA.INPUTBOX_LAYOUT.insetRight, TA.INPUTBOX_LAYOUT.insetTop, TA.INPUTBOX_LAYOUT.insetBottom)
if inputBox.SetBlinkSpeed then
  inputBox:SetBlinkSpeed(0.5)
end
inputBox.customCaret = inputBox:CreateTexture(nil, "OVERLAY")
inputBox.customCaret:SetColorTexture(0.90, 1.00, 0.85, 0.90)
inputBox.customCaret:SetSize(2, 14)
inputBox.customCaret:Hide()
inputBox.customCaretFlash = inputBox.customCaret:CreateAnimationGroup()
inputBox.customCaretFlash:SetLooping("REPEAT")
inputBox.customCaretFlashA = inputBox.customCaretFlash:CreateAnimation("Alpha")
inputBox.customCaretFlashA:SetOrder(1)
inputBox.customCaretFlashA:SetDuration(0.50)
inputBox.customCaretFlashA:SetFromAlpha(0.95)
inputBox.customCaretFlashA:SetToAlpha(0.05)
inputBox.customCaretFlashB = inputBox.customCaretFlash:CreateAnimation("Alpha")
inputBox.customCaretFlashB:SetOrder(2)
inputBox.customCaretFlashB:SetDuration(0.50)
inputBox.customCaretFlashB:SetFromAlpha(0.05)
inputBox.customCaretFlashB:SetToAlpha(0.95)
inputBox:Hide()
panel.inputBox = inputBox

function TA_UpdateInputBoxLayout(editBox)
  local textValue = editBox:GetText() or ""
  local lineCount = 1
  for _ in textValue:gmatch("\n") do
    lineCount = lineCount + 1
  end
  lineCount = math.max(TA.INPUTBOX_LAYOUT.minLines, math.min(TA.INPUTBOX_LAYOUT.maxLines, lineCount))

  local height = TA.INPUTBOX_LAYOUT.baseHeight + ((lineCount - 1) * TA.INPUTBOX_LAYOUT.lineHeight)
  editBox:SetHeight(height)
  -- Keep top edge stable and grow downward so multiline input doesn't cover log text.
  editBox:ClearAllPoints()
  editBox:SetPoint("BOTTOMLEFT", TA.INPUTBOX_LAYOUT.x, TA.INPUTBOX_LAYOUT.baseY - (height - TA.INPUTBOX_LAYOUT.baseHeight))
end

if _G.TextAdventurerPanel and _G.TextAdventurerPanel.inputBox then
  TA_UpdateInputBoxLayout(_G.TextAdventurerPanel.inputBox)
end

-- Input-box behavior bindings (moved from main file at file scope so they
-- run after inputBox creation above).
panel.inputBox:EnableKeyboard(true)
panel.inputBox:SetScript("OnEditFocusGained", function(self)
  self:SetCursorPosition((self:GetText() and #self:GetText()) or 0)
  if self.customCaret then
    self.customCaret:Show()
    if self.customCaretFlash and not self.customCaretFlash:IsPlaying() then
      self.customCaretFlash:Play()
    end
  end
end)
panel.inputBox:SetScript("OnEditFocusLost", function(self)
  if self.customCaretFlash and self.customCaretFlash:IsPlaying() then
    self.customCaretFlash:Stop()
  end
  if self.customCaret then
    self.customCaret:Hide()
  end
end)
panel.inputBox:SetScript("OnCursorChanged", function(self, x, y, w, h)
  if not self.customCaret then
    return
  end
  self.customCaret:ClearAllPoints()
  self.customCaret:SetPoint("TOPLEFT", self, "TOPLEFT", (x or 0) + (TA.INPUTBOX_LAYOUT.insetLeft or 8), (y or 0) - (TA.INPUTBOX_LAYOUT.insetTop or 6))
  if h and h > 0 then
    self.customCaret:SetHeight(h)
  end
end)
panel.inputBox:SetScript("OnTextChanged", function(self)
  TA_UpdateInputBoxLayout(self)
end)
panel.inputBox:SetScript("OnEnterPressed", function(self)
  if IsShiftKeyDown and IsShiftKeyDown() then
    local text = self:GetText() or ""
    local cursor = self:GetCursorPosition() or #text
    local before = text:sub(1, cursor)
    local after = text:sub(cursor + 1)
    local combined = before .. "\n" .. after
    self:SetText(combined)
    self:SetCursorPosition(cursor + 1)
    return
  end

  local msg = self:GetText()
  local lines = {}
  if msg and msg ~= "" then
    for line in msg:gmatch("[^\r\n]+") do
      local trimmed = line:match("^%s*(.-)%s*$")
      if trimmed ~= "" and not trimmed:match("^#") then
        table.insert(lines, trimmed)
      end
    end
    if #lines == 0 then
      local trimmed = msg:match("^%s*(.-)%s*$")
      if trimmed ~= "" and not trimmed:match("^#") then
        table.insert(lines, trimmed)
      end
    end
  end

  self:SetText("")
  local shouldBlur = TA_ExecuteTerminalInputLines(lines, { recordLastBlock = true })
  if TA.deferTerminalRefocus then
    self:ClearFocus()
    return
  end
  if shouldBlur then
    self:ClearFocus()
    return
  end
  self:SetFocus()
end)
panel.inputBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
panel.inputBox:SetScript("OnKeyDown", function(self, key)
  if key == "UP" then
    if TA.inputHistoryPos == 0 then
      TA.inputDraft = self:GetText()
    end
    local newPos = math.min(TA.inputHistoryPos + 1, #TA.inputHistory)
    if newPos ~= TA.inputHistoryPos and #TA.inputHistory > 0 then
      TA.inputHistoryPos = newPos
      self:SetText(TA.inputHistory[#TA.inputHistory - newPos + 1])
      self:SetCursorPosition(#self:GetText())
    end
  elseif key == "DOWN" then
    if TA.inputHistoryPos > 0 then
      TA.inputHistoryPos = TA.inputHistoryPos - 1
      if TA.inputHistoryPos == 0 then
        self:SetText(TA.inputDraft or "")
      else
        self:SetText(TA.inputHistory[#TA.inputHistory - TA.inputHistoryPos + 1])
      end
      self:SetCursorPosition(#self:GetText())
    end
  elseif key == "TAB" then
    local partial = (self:GetText() or ""):match("^%s*(.-)%s*$")
    if partial == "" then return end
    local partialLower = partial:lower()

    -- Collect candidates from exact handlers + a static prefix list
    local candidates = {}
    local seen = {}
    if TA.EXACT_INPUT_HANDLERS then
      for cmd in pairs(TA.EXACT_INPUT_HANDLERS) do
        if not seen[cmd] and cmd:sub(1, #partialLower) == partialLower then
          seen[cmd] = true
          table.insert(candidates, cmd)
        end
      end
    end
    -- Also include known prefix commands not fully in EXACT_INPUT_HANDLERS
    local prefixCmds = {
      "equip ", "binditem ", "moveitem ", "bind ", "bindmacro ",
      "actions ", "bars ", "sell ", "destroy ", "use ",
      "mark ", "unmark ", "renamemark ", "goto ", "route ",
      "ml xp ", "ml xp warrior ", "ml xp set ", "ml xp mode ",
      "recipes ", "recipes search", "recipes makeable",
      "bug show ", "bug copy ",
      "df ", "df size ", "df grid ", "df cell ", "df markradius ",
      "df rotation ", "df orientation ", "df square ",
      "df profile ", "df view ", "df hue ", "df legend ", "df calibrate ",
      "memory ", "focus ", "castfocus ", "macro ", "macroinfo ",
      "skills weapons", "skills professions", "skills defense",
      "help ", "help advanced", "help combat", "help economy",
      "help navigation", "help social", "help quests",
      "swingtimer ",
    }
    for _, cmd in ipairs(prefixCmds) do
      local cmdLower = cmd:lower()
      if not seen[cmdLower] and cmdLower:sub(1, #partialLower) == partialLower then
        seen[cmdLower] = true
        table.insert(candidates, cmd)
      end
    end

    if #candidates == 0 then return end

    table.sort(candidates)

    if #candidates == 1 then
      -- Unique match: complete it
      self:SetText(candidates[1])
      self:SetCursorPosition(#candidates[1])
    else
      -- Multiple matches: find longest common prefix then show list
      local common = candidates[1]
      for i = 2, #candidates do
        local c = candidates[i]
        local newCommon = ""
        for j = 1, math.min(#common, #c) do
          if common:sub(j, j):lower() == c:sub(j, j):lower() then
            newCommon = newCommon .. common:sub(j, j)
          else
            break
          end
        end
        common = newCommon
      end
      if #common > #partial then
        self:SetText(common)
        self:SetCursorPosition(#common)
      end
      -- Print candidates to terminal
      local MAX_SHOW = 12
      local display = {}
      for i = 1, math.min(#candidates, MAX_SHOW) do
        table.insert(display, candidates[i])
      end
      local suffix = #candidates > MAX_SHOW and string.format(" (+%d more)", #candidates - MAX_SHOW) or ""
      AddLine("system", "  " .. table.concat(display, "  |  ") .. suffix)
    end
  end
end)

