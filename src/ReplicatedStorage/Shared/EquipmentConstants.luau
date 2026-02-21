return {
	REMOTE_EVENT_NAME = "RequestEquipSkateboard",
	REMOTE_PURCHASE_NAME = "RequestPurchaseSkateboard",
	
	-- Player Attributes
	ATTR_IS_EQUIPPED = "SkateboardEquipped", -- boolean
	ATTR_EQUIPPED_ID = "EquippedSkateboard", -- string
	ATTR_UNLOCKED_PREFIX = "ItemUnlocked_",  -- boolean (e.g. ItemUnlocked_Skateboard2)
	
	-- Model Names
	DEFAULT_BOARD_NAME = "Skateboard",
	EQUIPPED_INSTANCE_NAME = "EquippedSkateboard",
	
	-- ボードリスト（複数ボード対応）
	BOARD_LIST = {
		{ id = "Skateboard",  displayName = "Skateboard",  templateName = "SkateboardTemplate",  price = 0, scoreMultiplier = 1.0 },
		{ id = "Skateboard2", displayName = "Skateboard2", templateName = "SkateboardTemplate2", price = 100, scoreMultiplier = 1.2 },
		{ id = "Skateboard_Green", displayName = "Skateboard (Green)", templateName = "SkateboardTemplate_Green", price = 300, scoreMultiplier = 1.5 },
		{ id = "Skateboard_Blue", displayName = "Skateboard (Blue)", templateName = "SkateboardTemplate_Blue", price = 500, scoreMultiplier = 1.8 },
		{ id = "Skateboard_Yellow", displayName = "Skateboard (Yellow)", templateName = "SkateboardTemplate_Yellow", price = 1000, scoreMultiplier = 2.5 },
	},
}
