-- InputBoxLayout.lua
-- Owns the warningFrame (TextAdventurerWarningFrame) child of the main panel,
-- ShowWarningMessage helper, and TA_UpdateInputBoxLayout (resizes the input box as the
-- player types). ShowWarningMessage is global because main-file event handlers and
-- StatusReports call it. The initial layout pass uses _G.TextAdventurerPanel.inputBox
-- since this module loads after main.

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
